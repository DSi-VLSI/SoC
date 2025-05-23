import ariane_pkg::*;module scoreboard #(
    parameter int unsigned NR_ENTRIES = 8,
    parameter int unsigned NR_WB_PORTS = 1,
    parameter int unsigned NR_COMMIT_PORTS = 2
) (
    input  logic                      clk_i,                   
    input  logic                      rst_ni,                  
    output logic                      sb_full_o,
    input  logic                      flush_unissued_instr_i,  
    input  logic                      flush_i,                 
    input  logic                      unresolved_branch_i,     

    output fu_t  [2**REG_ADDR_SIZE:0] rd_clobber_gpr_o,
    output fu_t  [2**REG_ADDR_SIZE:0] rd_clobber_fpr_o,

    input  logic [REG_ADDR_SIZE-1:0] rs1_i,
    output logic [             63:0] rs1_o,
    output logic                     rs1_valid_o,

    input  logic [REG_ADDR_SIZE-1:0] rs2_i,
    output logic [             63:0] rs2_o,
    output logic                     rs2_valid_o,

    input  logic [REG_ADDR_SIZE-1:0] rs3_i,
    output logic [         FLEN-1:0] rs3_o,
    output logic                     rs3_valid_o,

    output scoreboard_entry_t [NR_COMMIT_PORTS-1:0] commit_instr_o,
    input  logic              [NR_COMMIT_PORTS-1:0] commit_ack_i,

    input  scoreboard_entry_t decoded_instr_i,
    input  logic              decoded_instr_valid_i,
    output logic              decoded_instr_ack_o,

    output scoreboard_entry_t issue_instr_o,
    output logic              issue_instr_valid_o,
    input  logic              issue_ack_i,

    input branchpredict_t resolved_branch_i,
    input logic [NR_WB_PORTS-1:0][TRANS_ID_BITS-1:0]  trans_id_i,  
    input logic [NR_WB_PORTS-1:0][63:0] wbdata_i,  
    input exception_t [NR_WB_PORTS-1:0]               ex_i,        
    input logic [NR_WB_PORTS-1:0] wb_valid_i  
);
  localparam int unsigned BITS_ENTRIES = $clog2(NR_ENTRIES);

  typedef struct packed {
    logic issued;  
    scoreboard_entry_t sbe;  
  } mem_t;

  mem_t mem_q[NR_ENTRIES-1:0];
  mem_t mem_n[NR_ENTRIES-1:0];

  logic [BITS_ENTRIES-1:0] issue_cnt_n, issue_cnt_q;
  logic [BITS_ENTRIES-1:0] issue_pointer_n, issue_pointer_q;
  logic [BITS_ENTRIES-1:0] commit_pointer_n, commit_pointer_q;
  logic issue_full;

  assign issue_full = (issue_cnt_q == NR_ENTRIES - 1);

  assign sb_full_o  = issue_full;

  always_comb begin : commit_ports
    for (logic [BITS_ENTRIES-1:0] i = 0; i < NR_COMMIT_PORTS; i++)
    commit_instr_o[i] = mem_q[commit_pointer_q+i].sbe;
  end

  always_comb begin
    issue_instr_o          = decoded_instr_i;

    issue_instr_o.trans_id = issue_pointer_q;

    issue_instr_valid_o    = decoded_instr_valid_i && !unresolved_branch_i && !issue_full;
    decoded_instr_ack_o    = issue_ack_i && !issue_full;
  end

  always_comb begin : issue_fifo
    automatic logic [BITS_ENTRIES-1:0] issue_cnt;
    automatic logic [BITS_ENTRIES-1:0] commit_pointer;

    commit_pointer  = commit_pointer_q;
    issue_cnt       = issue_cnt_q;

    mem_n           = mem_q;
    issue_pointer_n = issue_pointer_q;

    if (decoded_instr_valid_i && decoded_instr_ack_o && !flush_unissued_instr_i) begin

      issue_cnt++;
      mem_n[issue_pointer_q] = {1'b1, decoded_instr_i};

      issue_pointer_n = issue_pointer_q + 1'b1;
    end

    for (int unsigned i = 0; i < NR_WB_PORTS; i++) begin

      if (wb_valid_i[i] && mem_n[trans_id_i[i]].issued) begin
        mem_n[trans_id_i[i]].sbe.valid = 1'b1;
        mem_n[trans_id_i[i]].sbe.result = wbdata_i[i];

        mem_n[trans_id_i[i]].sbe.bp.predict_address = resolved_branch_i.target_address;

        if (ex_i[i].valid) mem_n[trans_id_i[i]].sbe.ex = ex_i[i];

        else if (mem_n[trans_id_i[i]].sbe.fu inside {FPU, FPU_VEC})
          mem_n[trans_id_i[i]].sbe.ex.cause = ex_i[i].cause;
      end
    end

    for (logic [BITS_ENTRIES-1:0] i = 0; i < NR_COMMIT_PORTS; i++) begin
      if (commit_ack_i[i]) begin

        issue_cnt--;

        mem_n[commit_pointer_q + i].issued    = 1'b0;
        mem_n[commit_pointer_q + i].sbe.valid = 1'b0;

        commit_pointer++;
      end
    end

    if (flush_i) begin
      for (int unsigned i = 0; i < NR_ENTRIES; i++) begin

        mem_n[i].issued       = 1'b0;
        mem_n[i].sbe.valid    = 1'b0;
        mem_n[i].sbe.ex.valid = 1'b0;

        issue_cnt             = '0;
        issue_pointer_n       = '0;
        commit_pointer        = '0;
      end
    end

    issue_cnt_n      = issue_cnt;

    commit_pointer_n = commit_pointer;
  end

  always_comb begin : clobber_output
    rd_clobber_gpr_o = '{default: NONE};
    rd_clobber_fpr_o = '{default: NONE};

    for (int unsigned i = 0; i < NR_ENTRIES; i++) begin
      if (mem_q[i].issued) begin

        if (is_rd_fpr(mem_q[i].sbe.op)) rd_clobber_fpr_o[mem_q[i].sbe.rd] = mem_q[i].sbe.fu;
        else rd_clobber_gpr_o[mem_q[i].sbe.rd] = mem_q[i].sbe.fu;
      end
    end

    rd_clobber_gpr_o[0] = NONE;
  end

  always_comb begin : read_operands
    rs1_o       = 64'b0;
    rs2_o       = 64'b0;
    rs3_o       = '0;
    rs1_valid_o = 1'b0;
    rs2_valid_o = 1'b0;
    rs3_valid_o = 1'b0;

    for (int unsigned i = 0; i < NR_ENTRIES; i++) begin

      if (mem_q[i].issued) begin

        if ((mem_q[i].sbe.rd == rs1_i) && (is_rd_fpr(
                mem_q[i].sbe.op
            ) == is_rs1_fpr(
                issue_instr_o.op
            ))) begin
          rs1_o       = mem_q[i].sbe.result;
          rs1_valid_o = mem_q[i].sbe.valid;
        end else if ((mem_q[i].sbe.rd == rs2_i) && (is_rd_fpr(
                mem_q[i].sbe.op
            ) == is_rs2_fpr(
                issue_instr_o.op
            ))) begin
          rs2_o       = mem_q[i].sbe.result;
          rs2_valid_o = mem_q[i].sbe.valid;
        end else if ((mem_q[i].sbe.rd == rs3_i) && (is_rd_fpr(
                mem_q[i].sbe.op
            ) == is_imm_fpr(
                issue_instr_o.op
            ))) begin
          rs3_o       = mem_q[i].sbe.result;
          rs3_valid_o = mem_q[i].sbe.valid;
        end
      end
    end

    for (int unsigned j = 0; j < NR_WB_PORTS; j++) begin
      if (mem_q[trans_id_i[j]].sbe.rd == rs1_i && wb_valid_i[j] && ~ex_i[j].valid && (is_rd_fpr(
              mem_q[trans_id_i[j]].sbe.op
          ) == is_rs1_fpr(
              issue_instr_o.op
          ))) begin
        rs1_o = wbdata_i[j];
        rs1_valid_o = wb_valid_i[j];
        break;
      end
      if (mem_q[trans_id_i[j]].sbe.rd == rs2_i && wb_valid_i[j] && ~ex_i[j].valid && (is_rd_fpr(
              mem_q[trans_id_i[j]].sbe.op
          ) == is_rs2_fpr(
              issue_instr_o.op
          ))) begin
        rs2_o = wbdata_i[j];
        rs2_valid_o = wb_valid_i[j];
        break;
      end
      if (mem_q[trans_id_i[j]].sbe.rd == rs3_i && wb_valid_i[j] && ~ex_i[j].valid && (is_rd_fpr(
              mem_q[trans_id_i[j]].sbe.op
          ) == is_imm_fpr(
              issue_instr_o.op
          ))) begin
        rs3_o = wbdata_i[j];
        rs3_valid_o = wb_valid_i[j];
        break;
      end
    end

    if (rs1_i == '0 && ~is_rs1_fpr(issue_instr_o.op))  
      rs1_valid_o = 1'b0;
    if (rs2_i == '0 && ~is_rs2_fpr(issue_instr_o.op))  
      rs2_valid_o = 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      foreach (mem_q[i]) mem_q[i] <= mem_t'(0);
      issue_cnt_q      <= '0;
      commit_pointer_q <= '0;
      issue_pointer_q  <= '0;
    end else begin
      issue_cnt_q      <= issue_cnt_n;
      issue_pointer_q  <= issue_pointer_n;
      mem_q            <= mem_n;
      commit_pointer_q <= commit_pointer_n;
    end
  end

endmodule
