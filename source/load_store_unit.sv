import ariane_pkg::*;
module load_store_unit #(
    parameter int unsigned ASID_WIDTH = 1
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    output logic no_st_pending_o,
    input  logic amo_valid_commit_i,

    input  fu_data_t fu_data_i,
    output logic     lsu_ready_o,
    input  logic     lsu_valid_i,

    output logic [TRANS_ID_BITS-1:0] load_trans_id_o,
    output logic [63:0] load_result_o,
    output logic load_valid_o,
    output exception_t load_exception_o,

    output logic [TRANS_ID_BITS-1:0] store_trans_id_o,
    output logic [63:0] store_result_o,
    output logic store_valid_o,
    output exception_t store_exception_o,

    input  logic commit_i,
    output logic commit_ready_o,

    input logic enable_translation_i,
    input logic en_ld_st_translation_i,

    input  icache_areq_o_t icache_areq_i,
    output icache_areq_i_t icache_areq_o,

    input riscv_pkg::priv_lvl_t                  priv_lvl_i,
    input riscv_pkg::priv_lvl_t                  ld_st_priv_lvl_i,
    input logic                                  sum_i,
    input logic                                  mxr_i,
    input logic                 [          43:0] satp_ppn_i,
    input logic                 [ASID_WIDTH-1:0] asid_i,
    input logic                                  flush_tlb_i,

    output logic itlb_miss_o,
    output logic dtlb_miss_o,

    input  dcache_req_o_t [2:0] dcache_req_ports_i,
    output dcache_req_i_t [2:0] dcache_req_ports_o,

    output amo_req_t  amo_req_o,
    input  amo_resp_t amo_resp_i
);

  logic             data_misaligned;

  lsu_ctrl_t        lsu_ctrl;

  logic             pop_st;
  logic             pop_ld;

  logic      [63:0] vaddr_i;
  logic      [ 7:0] be_i;

  assign vaddr_i = $unsigned($signed(fu_data_i.imm) + $signed(fu_data_i.operand_a));

  logic                           st_valid_i;
  logic                           ld_valid_i;
  logic                           ld_translation_req;
  logic                           st_translation_req;
  logic       [             63:0] ld_vaddr;
  logic       [             63:0] st_vaddr;
  logic                           translation_req;
  logic                           translation_valid;
  logic       [             63:0] mmu_vaddr;
  logic       [             63:0] mmu_paddr;
  exception_t                     mmu_exception;
  logic                           dtlb_hit;

  logic                           ld_valid;
  logic       [TRANS_ID_BITS-1:0] ld_trans_id;
  logic       [             63:0] ld_result;
  logic                           st_valid;
  logic       [TRANS_ID_BITS-1:0] st_trans_id;
  logic       [             63:0] st_result;

  logic       [             11:0] page_offset;
  logic                           page_offset_matches;

  exception_t                     misaligned_exception;
  exception_t                     ld_ex;
  exception_t                     st_ex;

  mmu #(
      .INSTR_TLB_ENTRIES(16),
      .DATA_TLB_ENTRIES (16),
      .ASID_WIDTH       (ASID_WIDTH)
  ) i_mmu (

      .misaligned_ex_i(misaligned_exception),
      .lsu_is_store_i (st_translation_req),
      .lsu_req_i      (translation_req),
      .lsu_vaddr_i    (mmu_vaddr),
      .lsu_valid_o    (translation_valid),
      .lsu_paddr_o    (mmu_paddr),
      .lsu_exception_o(mmu_exception),
      .lsu_dtlb_hit_o (dtlb_hit),

      .req_port_i(dcache_req_ports_i[0]),
      .req_port_o(dcache_req_ports_o[0]),

      .icache_areq_i(icache_areq_i),
      .icache_areq_o(icache_areq_o),
      .*
  );

  store_unit i_store_unit (
      .clk_i,
      .rst_ni,
      .flush_i,
      .no_st_pending_o,

      .valid_i   (st_valid_i),
      .lsu_ctrl_i(lsu_ctrl),
      .pop_st_o  (pop_st),
      .commit_i,
      .commit_ready_o,
      .amo_valid_commit_i,

      .valid_o   (st_valid),
      .trans_id_o(st_trans_id),
      .result_o  (st_result),
      .ex_o      (st_ex),

      .translation_req_o(st_translation_req),
      .vaddr_o          (st_vaddr),
      .paddr_i          (mmu_paddr),
      .ex_i             (mmu_exception),
      .dtlb_hit_i       (dtlb_hit),

      .page_offset_i        (page_offset),
      .page_offset_matches_o(page_offset_matches),

      .amo_req_o,
      .amo_resp_i,

      .req_port_i(dcache_req_ports_i[2]),
      .req_port_o(dcache_req_ports_o[2])
  );

  load_unit i_load_unit (
      .valid_i   (ld_valid_i),
      .lsu_ctrl_i(lsu_ctrl),
      .pop_ld_o  (pop_ld),

      .valid_o   (ld_valid),
      .trans_id_o(ld_trans_id),
      .result_o  (ld_result),
      .ex_o      (ld_ex),

      .translation_req_o(ld_translation_req),
      .vaddr_o          (ld_vaddr),
      .paddr_i          (mmu_paddr),
      .ex_i             (mmu_exception),
      .dtlb_hit_i       (dtlb_hit),

      .page_offset_o        (page_offset),
      .page_offset_matches_i(page_offset_matches),

      .req_port_i(dcache_req_ports_i[1]),
      .req_port_o(dcache_req_ports_o[1]),
      .*
  );

  pipe_reg_simple #(
      .dtype(logic [$bits(ld_valid) + $bits(ld_trans_id) + $bits(ld_result) + $bits(ld_ex) - 1:0]),
      .Depth(NR_LOAD_PIPE_REGS)
  ) i_pipe_reg_load (
      .clk_i,
      .rst_ni,
      .d_i({ld_valid, ld_trans_id, ld_result, ld_ex}),
      .d_o({load_valid_o, load_trans_id_o, load_result_o, load_exception_o})
  );

  pipe_reg_simple #(
      .dtype(logic [$bits(st_valid) + $bits(st_trans_id) + $bits(st_result) + $bits(st_ex) - 1:0]),
      .Depth(NR_STORE_PIPE_REGS)
  ) i_pipe_reg_store (
      .clk_i,
      .rst_ni,
      .d_i({st_valid, st_trans_id, st_result, st_ex}),
      .d_o({store_valid_o, store_trans_id_o, store_result_o, store_exception_o})
  );

  always_comb begin : which_op

    ld_valid_i      = 1'b0;
    st_valid_i      = 1'b0;

    translation_req = 1'b0;
    mmu_vaddr       = 64'b0;

    unique case (lsu_ctrl.fu)

      LOAD: begin
        ld_valid_i      = lsu_ctrl.valid;
        translation_req = ld_translation_req;
        mmu_vaddr       = ld_vaddr;
      end

      STORE: begin
        st_valid_i      = lsu_ctrl.valid;
        translation_req = st_translation_req;
        mmu_vaddr       = st_vaddr;
      end

      default: ;
    endcase
  end

  assign be_i = be_gen(vaddr_i[2:0], extract_transfer_size(fu_data_i.operator));

  always_comb begin : data_misaligned_detection

    misaligned_exception = {64'b0, 64'b0, 1'b0};

    data_misaligned = 1'b0;

    if (lsu_ctrl.valid) begin
      case (lsu_ctrl.operator)

        LD, SD, FLD, FSD,
                AMO_LRD, AMO_SCD,
                AMO_SWAPD, AMO_ADDD, AMO_ANDD, AMO_ORD,
                AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND,
                AMO_MINDU: begin
          if (lsu_ctrl.vaddr[2:0] != 3'b000) begin
            data_misaligned = 1'b1;
          end
        end

        LW, LWU, SW, FLW, FSW,
                AMO_LRW, AMO_SCW,
                AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW,
                AMO_XORW, AMO_MAXW, AMO_MAXWU, AMO_MINW,
                AMO_MINWU: begin
          if (lsu_ctrl.vaddr[1:0] != 2'b00) begin
            data_misaligned = 1'b1;
          end
        end

        LH, LHU, SH, FLH, FSH: begin
          if (lsu_ctrl.vaddr[0] != 1'b0) begin
            data_misaligned = 1'b1;
          end
        end

        default: ;
      endcase
    end

    if (data_misaligned) begin

      if (lsu_ctrl.fu == LOAD) begin
        misaligned_exception = {riscv_pkg::LD_ADDR_MISALIGNED, lsu_ctrl.vaddr, 1'b1};

      end else if (lsu_ctrl.fu == STORE) begin
        misaligned_exception = {riscv_pkg::ST_ADDR_MISALIGNED, lsu_ctrl.vaddr, 1'b1};
      end
    end

    if (en_ld_st_translation_i && !((&lsu_ctrl.vaddr[63:38]) == 1'b1 || (|lsu_ctrl.vaddr[63:38]) == 1'b0)) begin

      if (lsu_ctrl.fu == LOAD) begin
        misaligned_exception = {riscv_pkg::LD_ACCESS_FAULT, lsu_ctrl.vaddr, 1'b1};

      end else if (lsu_ctrl.fu == STORE) begin
        misaligned_exception = {riscv_pkg::ST_ACCESS_FAULT, lsu_ctrl.vaddr, 1'b1};
      end
    end
  end

  lsu_ctrl_t lsu_req_i;

  assign lsu_req_i = {
    lsu_valid_i,
    vaddr_i,
    fu_data_i.operand_b,
    be_i,
    fu_data_i.fu,
    fu_data_i.operator,
    fu_data_i.trans_id
  };

  lsu_bypass lsu_bypass_i (
      .lsu_req_i      (lsu_req_i),
      .lus_req_valid_i(lsu_valid_i),
      .pop_ld_i       (pop_ld),
      .pop_st_i       (pop_st),

      .lsu_ctrl_o(lsu_ctrl),
      .ready_o   (lsu_ready_o),
      .*
  );

endmodule

