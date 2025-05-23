import ariane_pkg::*;module issue_read_operands #(
    parameter int unsigned NR_COMMIT_PORTS = 2
) (
    input logic clk_i,  
    input logic rst_ni,  

    input logic flush_i,

    input scoreboard_entry_t issue_instr_i,
    input logic issue_instr_valid_i,
    output logic issue_ack_o,

    output logic [REG_ADDR_SIZE-1:0] rs1_o,
    input logic [63:0] rs1_i,
    input logic rs1_valid_i,
    output logic [REG_ADDR_SIZE-1:0] rs2_o,
    input logic [63:0] rs2_i,
    input logic rs2_valid_i,
    output logic [REG_ADDR_SIZE-1:0] rs3_o,
    input logic [FLEN-1:0] rs3_i,
    input logic rs3_valid_i,

    input fu_t [2**REG_ADDR_SIZE:0] rd_clobber_gpr_i,
    input fu_t [2**REG_ADDR_SIZE:0] rd_clobber_fpr_i,

    output fu_data_t fu_data_o,
    output logic [63:0] pc_o,
    output logic is_compressed_instr_o,

    input logic flu_ready_i,  
    output logic alu_valid_o,  

    output logic branch_valid_o,  
    output branchpredict_sbe_t branch_predict_o,

    input logic lsu_ready_i,  
    output logic lsu_valid_o,  

    output logic mult_valid_o,  

    input logic fpu_ready_i,  
    output logic fpu_valid_o,  
    output logic [1:0] fpu_fmt_o,  
    output logic [2:0] fpu_rm_o,  

    output logic csr_valid_o,  

    input logic [NR_COMMIT_PORTS-1:0][4:0] waddr_i,
    input logic [NR_COMMIT_PORTS-1:0][63:0] wdata_i,
    input logic [NR_COMMIT_PORTS-1:0] we_gpr_i,
    input logic [NR_COMMIT_PORTS-1:0] we_fpr_i

);
  logic stall;  
  logic fu_busy;  
  logic [63:0] operand_a_regfile, operand_b_regfile;  
  logic [FLEN-1:0] operand_c_regfile;  

  logic [63:0] operand_a_n, operand_a_q, operand_b_n, operand_b_q, imm_n, imm_q;

  logic alu_valid_n, alu_valid_q;
  logic mult_valid_n, mult_valid_q;
  logic fpu_valid_n, fpu_valid_q;
  logic [1:0] fpu_fmt_n, fpu_fmt_q;
  logic [2:0] fpu_rm_n, fpu_rm_q;
  logic lsu_valid_n, lsu_valid_q;
  logic csr_valid_n, csr_valid_q;
  logic branch_valid_n, branch_valid_q;

  logic [TRANS_ID_BITS-1:0] trans_id_n, trans_id_q;
  fu_op operator_n, operator_q;  
  fu_t fu_n, fu_q;  

  logic forward_rs1, forward_rs2, forward_rs3;

  riscv_pkg::instruction_t orig_instr;
  assign orig_instr          = riscv_pkg::instruction_t'(issue_instr_i.ex.tval[31:0]);

  assign fu_data_o.operand_a = operand_a_q;
  assign fu_data_o.operand_b = operand_b_q;
  assign fu_data_o.fu        = fu_q;
  assign fu_data_o.operator  = operator_q;
  assign fu_data_o.trans_id  = trans_id_q;
  assign fu_data_o.imm       = imm_q;
  assign alu_valid_o         = alu_valid_q;
  assign branch_valid_o      = branch_valid_q;
  assign lsu_valid_o         = lsu_valid_q;
  assign csr_valid_o         = csr_valid_q;
  assign mult_valid_o        = mult_valid_q;
  assign fpu_valid_o         = fpu_valid_q;
  assign fpu_fmt_o           = fpu_fmt_q;
  assign fpu_rm_o            = fpu_rm_q;

  always_comb begin : unit_busy
    unique case (issue_instr_i.fu)
      NONE: fu_busy = 1'b0;
      ALU, CTRL_FLOW, CSR, MULT: fu_busy = ~flu_ready_i;
      FPU, FPU_VEC: fu_busy = ~fpu_ready_i;
      LOAD, STORE: fu_busy = ~lsu_ready_i;
      default: fu_busy = 1'b0;
    endcase
  end

  always_comb begin : operands_available
    stall = 1'b0;

    forward_rs1 = 1'b0;
    forward_rs2 = 1'b0;
    forward_rs3 = 1'b0;  

    rs1_o = issue_instr_i.rs1;
    rs2_o = issue_instr_i.rs2;
    rs3_o = issue_instr_i.result[REG_ADDR_SIZE-1:0];  

    if (~issue_instr_i.use_zimm && (is_rs1_fpr(
            issue_instr_i.op
        ) ? rd_clobber_fpr_i[issue_instr_i.rs1] != NONE :
            rd_clobber_gpr_i[issue_instr_i.rs1] != NONE)) begin

      if (rs1_valid_i && (is_rs1_fpr(
              issue_instr_i.op
          ) ? 1'b1 : rd_clobber_gpr_i[issue_instr_i.rs1] != CSR)) begin
        forward_rs1 = 1'b1;
      end else begin  
        stall = 1'b1;
      end
    end

    if (is_rs2_fpr(
            issue_instr_i.op
        ) ? rd_clobber_fpr_i[issue_instr_i.rs2] != NONE :
            rd_clobber_gpr_i[issue_instr_i.rs2] != NONE) begin

      if (rs2_valid_i && (is_rs2_fpr(
              issue_instr_i.op
          ) ? 1'b1 : rd_clobber_gpr_i[issue_instr_i.rs2] != CSR)) begin
        forward_rs2 = 1'b1;
      end else begin  
        stall = 1'b1;
      end
    end

    if (is_imm_fpr(
            issue_instr_i.op
        ) && rd_clobber_fpr_i[issue_instr_i.result[REG_ADDR_SIZE-1:0]] != NONE) begin

      if (rs3_valid_i) begin
        forward_rs3 = 1'b1;
      end else begin  
        stall = 1'b1;
      end
    end
  end

  always_comb begin : forwarding_operand_select

    operand_a_n = operand_a_regfile;
    operand_b_n = operand_b_regfile;

    imm_n       = is_imm_fpr(issue_instr_i.op) ? operand_c_regfile : issue_instr_i.result;
    trans_id_n  = issue_instr_i.trans_id;
    fu_n        = issue_instr_i.fu;
    operator_n  = issue_instr_i.op;

    if (forward_rs1) begin
      operand_a_n = rs1_i;
    end

    if (forward_rs2) begin
      operand_b_n = rs2_i;
    end

    if (forward_rs3) begin
      imm_n = rs3_i;
    end

    if (issue_instr_i.use_pc) begin
      operand_a_n = issue_instr_i.pc;
    end

    if (issue_instr_i.use_zimm) begin

      operand_a_n = {52'b0, issue_instr_i.rs1[4:0]};
    end

    if (issue_instr_i.use_imm && (issue_instr_i.fu != STORE) && (issue_instr_i.fu != CTRL_FLOW) && !is_rs2_fpr(
            issue_instr_i.op
        )) begin
      operand_b_n = issue_instr_i.result;
    end
  end

  always_comb begin : unit_valid
    alu_valid_n    = 1'b0;
    lsu_valid_n    = 1'b0;
    mult_valid_n   = 1'b0;
    fpu_valid_n    = 1'b0;
    fpu_fmt_n      = 2'b0;
    fpu_rm_n       = 3'b0;
    csr_valid_n    = 1'b0;
    branch_valid_n = 1'b0;

    if (~issue_instr_i.ex.valid && issue_instr_valid_i && issue_ack_o) begin
      case (issue_instr_i.fu)
        ALU:         alu_valid_n = 1'b1;
        CTRL_FLOW:   branch_valid_n = 1'b1;
        MULT:        mult_valid_n = 1'b1;
        FPU: begin
          fpu_valid_n = 1'b1;
          fpu_fmt_n   = orig_instr.rftype.fmt;  
          fpu_rm_n    = orig_instr.rftype.rm;  
        end
        FPU_VEC: begin
          fpu_valid_n = 1'b1;
          fpu_fmt_n   = orig_instr.rvftype.vfmt;  
          fpu_rm_n    = {2'b0, orig_instr.rvftype.repl};  
        end
        LOAD, STORE: lsu_valid_n = 1'b1;
        CSR:         csr_valid_n = 1'b1;
        default:     ;
      endcase
    end

    if (flush_i) begin
      alu_valid_n    = 1'b0;
      lsu_valid_n    = 1'b0;
      mult_valid_n   = 1'b0;
      fpu_valid_n    = 1'b0;
      csr_valid_n    = 1'b0;
      branch_valid_n = 1'b0;
    end
  end

  always_comb begin : issue_scoreboard

    issue_ack_o = 1'b0;

    if (issue_instr_valid_i) begin

      if (~stall && ~fu_busy) begin

        if (is_rd_fpr(
                issue_instr_i.op
            ) ? (rd_clobber_fpr_i[issue_instr_i.rd] == NONE) :
                (rd_clobber_gpr_i[issue_instr_i.rd] == NONE)) begin
          issue_ack_o = 1'b1;
        end

        for (int unsigned i = 0; i < NR_COMMIT_PORTS; i++)
        if (is_rd_fpr(
                issue_instr_i.op
            ) ? (we_fpr_i[i] && waddr_i[i] == issue_instr_i.rd) :
                (we_gpr_i[i] && waddr_i[i] == issue_instr_i.rd)) begin
          issue_ack_o = 1'b1;
        end
      end

      if (issue_instr_i.ex.valid) begin
        issue_ack_o = 1'b1;
      end

      if (issue_instr_i.fu == NONE) begin
        issue_ack_o = 1'b1;
      end
    end

    if (mult_valid_q && issue_instr_i.fu != MULT) begin
      issue_ack_o = 1'b0;
    end
  end

  logic [                1:0][63:0] rdata;
  logic [                1:0][ 4:0] raddr_pack;

  logic [NR_COMMIT_PORTS-1:0][ 4:0] waddr_pack;
  logic [NR_COMMIT_PORTS-1:0][63:0] wdata_pack;
  logic [NR_COMMIT_PORTS-1:0]       we_pack;
  assign raddr_pack = {issue_instr_i.rs2[4:0], issue_instr_i.rs1[4:0]};
  assign waddr_pack = {waddr_i[1],  waddr_i[0]};
  assign wdata_pack = {wdata_i[1],  wdata_i[0]};
  assign we_pack    = {we_gpr_i[1], we_gpr_i[0]};

  ariane_regfile #(
      .DATA_WIDTH    (64),
      .NR_READ_PORTS (2),
      .NR_WRITE_PORTS(NR_COMMIT_PORTS),
      .ZERO_REG_ZERO (1)
  ) i_ariane_regfile (
      .test_en_i(1'b0),
      .raddr_i  (raddr_pack),
      .rdata_o  (rdata),
      .waddr_i  (waddr_pack),
      .wdata_i  (wdata_pack),
      .we_i     (we_pack),
      .*
  );

  logic [2:0][FLEN-1:0] fprdata;

  logic [2:0][4:0] fp_raddr_pack;
  logic [NR_COMMIT_PORTS-1:0][63:0] fp_wdata_pack;

  generate
    if (FP_PRESENT) begin : float_regfile_gen
      assign fp_raddr_pack = {
        issue_instr_i.result[4:0], issue_instr_i.rs2[4:0], issue_instr_i.rs1[4:0]
      };
      assign fp_wdata_pack = {wdata_i[1][FLEN-1:0], wdata_i[0][FLEN-1:0]};

      ariane_regfile #(
          .DATA_WIDTH    (FLEN),
          .NR_READ_PORTS (3),
          .NR_WRITE_PORTS(NR_COMMIT_PORTS),
          .ZERO_REG_ZERO (0)
      ) i_ariane_fp_regfile (
          .test_en_i(1'b0),
          .raddr_i  (fp_raddr_pack),
          .rdata_o  (fprdata),
          .waddr_i  (waddr_pack),
          .wdata_i  (wdata_pack),
          .we_i     (we_fpr_i),
          .*
      );
    end else begin : no_fpr_gen
      assign fprdata = '{default: '0};
    end
  endgenerate

  assign operand_a_regfile = is_rs1_fpr(issue_instr_i.op) ? fprdata[0] : rdata[0];
  assign operand_b_regfile = is_rs2_fpr(issue_instr_i.op) ? fprdata[1] : rdata[1];
  assign operand_c_regfile = fprdata[2];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      operand_a_q           <= '{default: 0};
      operand_b_q           <= '{default: 0};
      imm_q                 <= 64'b0;
      alu_valid_q           <= 1'b0;
      branch_valid_q        <= 1'b0;
      mult_valid_q          <= 1'b0;
      fpu_valid_q           <= 1'b0;
      fpu_fmt_q             <= 2'b0;
      fpu_rm_q              <= 3'b0;
      lsu_valid_q           <= 1'b0;
      csr_valid_q           <= 1'b0;
      fu_q                  <= NONE;
      operator_q            <= ADD;
      trans_id_q            <= 5'b0;
      pc_o                  <= 64'b0;
      is_compressed_instr_o <= 1'b0;
      branch_predict_o      <= branchpredict_sbe_t'('0);
    end else begin
      operand_a_q           <= operand_a_n;
      operand_b_q           <= operand_b_n;
      imm_q                 <= imm_n;
      alu_valid_q           <= alu_valid_n;
      branch_valid_q        <= branch_valid_n;
      mult_valid_q          <= mult_valid_n;
      fpu_valid_q           <= fpu_valid_n;
      fpu_fmt_q             <= fpu_fmt_n;
      fpu_rm_q              <= fpu_rm_n;
      lsu_valid_q           <= lsu_valid_n;
      csr_valid_q           <= csr_valid_n;
      fu_q                  <= fu_n;
      operator_q            <= operator_n;
      trans_id_q            <= trans_id_n;
      pc_o                  <= issue_instr_i.pc;
      is_compressed_instr_o <= issue_instr_i.is_compressed;
      branch_predict_o      <= issue_instr_i.bp;
    end
  end

endmodule

