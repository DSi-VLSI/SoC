import ariane_pkg::*;
module frontend #(
    parameter logic [63:0] DmBaseAddress = 64'h0
) (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,
    input logic flush_bp_i,
    input logic debug_mode_i,

    input logic [63:0] boot_addr_i,

    input branchpredict_t resolved_branch_i,

    input logic        set_pc_commit_i,
    input logic [63:0] pc_commit_i,

    input logic [63:0] epc_i,
    input logic        eret_i,
    input logic [63:0] trap_vector_base_i,
    input logic        ex_valid_i,
    input logic        set_debug_pc_i,

    input  icache_dreq_o_t icache_dreq_i,
    output icache_dreq_i_t icache_dreq_o,

    output frontend_fetch_t fetch_entry_o,
    output logic            fetch_entry_valid_o,
    input  logic            fetch_ack_i
);

  logic            [               31:0] icache_data_q;
  logic                                  icache_valid_q;
  logic                                  icache_ex_valid_q;
  logic                                  instruction_valid;
  logic            [INSTR_PER_FETCH-1:0] instr_is_compressed;

  logic            [               63:0] icache_vaddr_q;

  bht_prediction_t                       bht_prediction;
  btb_prediction_t                       btb_prediction;
  ras_t                                  ras_predict;
  bht_update_t                           bht_update;
  btb_update_t                           btb_update;
  logic ras_push, ras_pop;
  logic [63:0] ras_update;

  logic        if_ready;
  logic [63:0] npc_d, npc_q;
  logic npc_rst_load_q;

  logic [INSTR_PER_FETCH-1:0] rvi_return, rvi_call, rvi_branch, rvi_jalr, rvi_jump;
  logic [INSTR_PER_FETCH-1:0][63:0] rvi_imm;

  logic [INSTR_PER_FETCH-1:0]       is_rvc;
  logic [INSTR_PER_FETCH-1:0] rvc_branch, rvc_jump, rvc_jr, rvc_return, rvc_jalr, rvc_call;
  logic               [INSTR_PER_FETCH-1:0][63:0] rvc_imm;

  logic               [INSTR_PER_FETCH-1:0][31:0] instr;
  logic               [INSTR_PER_FETCH-1:0][63:0] addr;

  logic               [               63:0]       bp_vaddr;
  logic                                           bp_valid;
  logic                                           is_mispredict;

  branchpredict_sbe_t                             bp_sbe;

  logic fifo_valid, fifo_ready, fifo_empty, fifo_pop;
  logic s2_eff_kill, issue_req, s2_in_flight_d, s2_in_flight_q;
  logic [$clog2(FETCH_FIFO_DEPTH):0] fifo_credits_d;
  logic [$clog2(FETCH_FIFO_DEPTH):0] fifo_credits_q;

  logic [15:0] unaligned_instr_d, unaligned_instr_q;

  logic unaligned_d, unaligned_q;

  logic [63:0] unaligned_address_d, unaligned_address_q;

  for (genvar i = 0; i < INSTR_PER_FETCH; i++) begin

    assign instr_is_compressed[i] = ~&icache_data_q[i*16+:2];
  end

  always_comb begin : re_align
    unaligned_d = unaligned_q;
    unaligned_address_d = unaligned_address_q;
    unaligned_instr_d = unaligned_instr_q;
    instruction_valid = icache_valid_q;

    instr[0] = icache_data_q;
    addr[0] = icache_vaddr_q;

    instr[1] = '0;
    addr[1] = {icache_vaddr_q[63:2], 2'b10};

    if (icache_valid_q) begin

      if (unaligned_q) begin
        instr[0] = {icache_data_q[15:0], unaligned_instr_q};
        addr[0] = unaligned_address_q;

        unaligned_address_d = {icache_vaddr_q[63:2], 2'b10};
        unaligned_instr_d = icache_data_q[31:16];

        if (instr_is_compressed[1]) begin
          unaligned_d = 1'b0;
          instr[1] = {16'b0, icache_data_q[31:16]};
        end
      end else if (instr_is_compressed[0]) begin

        if (instr_is_compressed[1]) begin
          instr[1] = {16'b0, icache_data_q[31:16]};
        end else begin
          unaligned_instr_d = icache_data_q[31:16];
          unaligned_address_d = {icache_vaddr_q[63:2], 2'b10};
          unaligned_d = 1'b1;
        end
      end
    end

    if (icache_valid_q && icache_vaddr_q[1] && !instr_is_compressed[1]) begin
      instruction_valid = 1'b0;
      unaligned_d = 1'b1;
      unaligned_address_d = {icache_vaddr_q[63:2], 2'b10};
      unaligned_instr_d = icache_data_q[31:16];
    end

    if (icache_dreq_o.kill_s2) begin
      unaligned_d = 1'b0;
    end
  end

  logic [INSTR_PER_FETCH:0] taken;

  always_comb begin : frontend_ctrl
    automatic logic take_rvi_cf;
    automatic logic take_rvc_cf;

    take_rvi_cf    = 1'b0;
    take_rvc_cf    = 1'b0;
    ras_pop        = 1'b0;
    ras_push       = 1'b0;
    ras_update     = '0;
    taken          = '0;
    take_rvi_cf    = 1'b0;

    bp_vaddr       = '0;
    bp_valid       = 1'b0;

    bp_sbe.cf_type = RAS;

    if (instruction_valid) begin

      for (int unsigned i = 0; i < INSTR_PER_FETCH; i++) begin

        if (!taken[i]) begin

          ras_push   = rvi_call[i] | rvc_call[i];
          ras_update = addr[i] + (rvc_call[i] ? 2 : 4);

          if (rvi_branch[i] || rvc_branch[i]) begin
            bp_sbe.cf_type = BHT;

            if (bht_prediction.valid) begin
              take_rvi_cf = rvi_branch[i] & (bht_prediction.taken | bht_prediction.strongly_taken);
              take_rvc_cf = rvc_branch[i] & (bht_prediction.taken | bht_prediction.strongly_taken);

            end else begin

              take_rvi_cf = rvi_branch[i] & rvi_imm[i][63];
              take_rvc_cf = rvc_branch[i] & rvc_imm[i][63];
            end
          end

          if (rvi_jump[i] || rvc_jump[i]) begin
            take_rvi_cf = rvi_jump[i];
            take_rvc_cf = rvc_jump[i];
          end

          if ((rvi_jalr[i] || rvc_jalr[i]) && ~(rvi_call[i] || rvc_call[i])) begin
            bp_sbe.cf_type = BTB;
            if (btb_prediction.valid) begin
              bp_vaddr   = btb_prediction.target_address;
              taken[i+1] = 1'b1;
            end
          end

          if ((rvi_return[i] || rvc_return[i]) && ras_predict.valid) begin
            bp_vaddr = ras_predict.ra;
            ras_pop = 1'b1;
            taken[i+1] = 1'b1;
            bp_sbe.cf_type = RAS;
          end

          if (take_rvi_cf) begin
            taken[i+1] = 1'b1;
            bp_vaddr   = addr[i] + rvi_imm[i];
          end

          if (take_rvc_cf) begin
            taken[i+1] = 1'b1;
            bp_vaddr   = addr[i] + rvc_imm[i];
          end

          if (icache_vaddr_q[1]) begin
            taken[1] = 1'b0;

            ras_pop  = 1'b0;
            ras_push = 1'b0;
          end
        end
      end
    end

    bp_valid = |taken;

    bp_sbe.valid = bp_valid;
    bp_sbe.predict_address = bp_vaddr;
    bp_sbe.predict_taken = bp_valid;
  end

  assign is_mispredict = resolved_branch_i.valid & resolved_branch_i.is_mispredict;

  assign icache_dreq_o.kill_s1 = is_mispredict | flush_i;

  assign icache_dreq_o.kill_s2 = icache_dreq_o.kill_s1 | bp_valid;
  assign fifo_valid = icache_valid_q;

  assign bht_update.valid = resolved_branch_i.valid & (resolved_branch_i.cf_type == BHT);
  assign bht_update.pc    = resolved_branch_i.pc;
  assign bht_update.mispredict = resolved_branch_i.is_mispredict;
  assign bht_update.taken = resolved_branch_i.is_taken;

  assign btb_update.valid = resolved_branch_i.valid & (resolved_branch_i.cf_type == BTB);
  assign btb_update.pc    = resolved_branch_i.pc;
  assign btb_update.target_address = resolved_branch_i.target_address;
  assign btb_update.clear = resolved_branch_i.clear;

  always_comb begin : npc_select
    automatic logic [63:0] fetch_address;

    if (npc_rst_load_q) begin
      npc_d         = boot_addr_i;
      fetch_address = boot_addr_i;
    end else begin
      fetch_address = npc_q;

      npc_d         = npc_q;
    end

    if (bp_valid) begin
      fetch_address = bp_vaddr;
      npc_d = bp_vaddr;
    end

    if (if_ready) begin
      npc_d = {fetch_address[63:2], 2'b0} + 'h4;
    end

    if (is_mispredict) begin
      npc_d = resolved_branch_i.target_address;
    end

    if (eret_i) begin
      npc_d = epc_i;
    end

    if (ex_valid_i) begin
      npc_d = trap_vector_base_i;
    end

    if (set_pc_commit_i) begin

      npc_d = pc_commit_i + 64'h4;
    end

    if (set_debug_pc_i) begin
      npc_d = DmBaseAddress + dm::HaltAddress;
    end

    icache_dreq_o.vaddr = fetch_address;
  end

  assign fifo_credits_d       =  (flush_i) ? FETCH_FIFO_DEPTH :
                                               fifo_credits_q + fifo_pop + s2_eff_kill - issue_req;

  assign s2_eff_kill = s2_in_flight_q & icache_dreq_o.kill_s2;
  assign s2_in_flight_d      = (flush_i)             ? 1'b0 :
                                 (issue_req)           ? 1'b1 :
                                 (icache_dreq_i.valid) ? 1'b0 :
                                                         s2_in_flight_q;

  assign issue_req = if_ready & (~icache_dreq_o.kill_s1);
  assign fifo_pop = fetch_ack_i & fetch_entry_valid_o;
  assign fifo_ready = (|fifo_credits_q);
  assign if_ready = icache_dreq_i.ready & fifo_ready;
  assign icache_dreq_o.req = fifo_ready;
  assign fetch_entry_valid_o = ~fifo_empty;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      npc_q               <= '0;
      npc_rst_load_q      <= 1'b1;
      icache_data_q       <= '0;
      icache_valid_q      <= 1'b0;
      icache_vaddr_q      <= 'b0;
      icache_ex_valid_q   <= 1'b0;
      unaligned_q         <= 1'b0;
      unaligned_address_q <= '0;
      unaligned_instr_q   <= '0;
      fifo_credits_q      <= FETCH_FIFO_DEPTH;
      s2_in_flight_q      <= 1'b0;
    end else begin
      npc_rst_load_q      <= 1'b0;
      npc_q               <= npc_d;
      icache_data_q       <= icache_dreq_i.data;
      icache_valid_q      <= icache_dreq_i.valid;
      icache_vaddr_q      <= icache_dreq_i.vaddr;
      icache_ex_valid_q   <= icache_dreq_i.ex.valid;
      unaligned_q         <= unaligned_d;
      unaligned_address_q <= unaligned_address_d;
      unaligned_instr_q   <= unaligned_instr_d;
      fifo_credits_q      <= fifo_credits_d;
      s2_in_flight_q      <= s2_in_flight_d;
    end
  end

  ras #(
      .DEPTH(RAS_DEPTH)
  ) i_ras (
      .push_i(ras_push),
      .pop_i (ras_pop),
      .data_i(ras_update),
      .data_o(ras_predict),
      .*
  );

  btb #(
      .NR_ENTRIES(BTB_ENTRIES)
  ) i_btb (
      .clk_i,
      .rst_ni,
      .flush_i         (flush_bp_i),
      .debug_mode_i,
      .vpc_i           (icache_vaddr_q),
      .btb_update_i    (btb_update),
      .btb_prediction_o(btb_prediction)
  );

  bht #(
      .NR_ENTRIES(BHT_ENTRIES)
  ) i_bht (
      .clk_i,
      .rst_ni,
      .flush_i         (flush_bp_i),
      .debug_mode_i,
      .vpc_i           (icache_vaddr_q),
      .bht_update_i    (bht_update),
      .bht_prediction_o(bht_prediction)
  );

  for (genvar i = 0; i < INSTR_PER_FETCH; i++) begin
    instr_scan i_instr_scan (
        .instr_i     (instr[i]),
        .is_rvc_o    (is_rvc[i]),
        .rvi_return_o(rvi_return[i]),
        .rvi_call_o  (rvi_call[i]),
        .rvi_branch_o(rvi_branch[i]),
        .rvi_jalr_o  (rvi_jalr[i]),
        .rvi_jump_o  (rvi_jump[i]),
        .rvi_imm_o   (rvi_imm[i]),
        .rvc_branch_o(rvc_branch[i]),
        .rvc_jump_o  (rvc_jump[i]),
        .rvc_jr_o    (rvc_jr[i]),
        .rvc_return_o(rvc_return[i]),
        .rvc_jalr_o  (rvc_jalr[i]),
        .rvc_call_o  (rvc_call[i]),
        .rvc_imm_o   (rvc_imm[i])
    );
  end

  fifo_v2 #(
      .DEPTH(8),
      .dtype(frontend_fetch_t)
  ) i_fetch_fifo (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .flush_i(flush_i),
      .testmode_i(1'b0),
      .full_o(),
      .empty_o(fifo_empty),
      .alm_full_o(),
      .alm_empty_o(),
      .data_i({icache_vaddr_q, icache_data_q, bp_sbe, taken[INSTR_PER_FETCH:1], icache_ex_valid_q}),
      .push_i(fifo_valid),
      .data_o(fetch_entry_o),
      .pop_i(fifo_pop)
  );

endmodule
