module instr_scan (
    input  logic [31:0] instr_i,        
    output logic        is_rvc_o,
    output logic        rvi_return_o,
    output logic        rvi_call_o,
    output logic        rvi_branch_o,
    output logic        rvi_jalr_o,
    output logic        rvi_jump_o,
    output logic [63:0] rvi_imm_o,
    output logic        rvc_branch_o,
    output logic        rvc_jump_o,
    output logic        rvc_jr_o,
    output logic        rvc_return_o,
    output logic        rvc_jalr_o,
    output logic        rvc_call_o,
    output logic [63:0] rvc_imm_o
);
    assign is_rvc_o     = (instr_i[1:0] != 2'b11);

    assign rvi_return_o = rvi_jalr_o & ~instr_i[7] & ~instr_i[19] & ~instr_i[18] & ~instr_i[16] & instr_i[15];
    assign rvi_call_o   = (rvi_jalr_o | rvi_jump_o) & instr_i[7]; 

    assign rvi_imm_o    = (instr_i[3]) ? ariane_pkg::uj_imm(instr_i) : ariane_pkg::sb_imm(instr_i);
    assign rvi_branch_o = (instr_i[6:0] == riscv_pkg::OpcodeBranch) ? 1'b1 : 1'b0;
    assign rvi_jalr_o   = (instr_i[6:0] == riscv_pkg::OpcodeJalr)   ? 1'b1 : 1'b0;
    assign rvi_jump_o   = (instr_i[6:0] == riscv_pkg::OpcodeJal)    ? 1'b1 : 1'b0;

    assign rvc_jump_o   = (instr_i[15:13] == riscv_pkg::OpcodeC1J) & is_rvc_o & (instr_i[1:0] == riscv_pkg::OpcodeC1);

    assign rvc_jr_o     = (instr_i[15:13] == riscv_pkg::OpcodeC2JalrMvAdd)
                        & ~instr_i[12]
                        & (instr_i[6:2] == 5'b00000)
                        & (instr_i[1:0] == riscv_pkg::OpcodeC2)
                        & is_rvc_o;
    assign rvc_branch_o = ((instr_i[15:13] == riscv_pkg::OpcodeC1Beqz) | (instr_i[15:13] == riscv_pkg::OpcodeC1Bnez))
                        & (instr_i[1:0] == riscv_pkg::OpcodeC1)
                        & is_rvc_o;

    assign rvc_return_o = ~instr_i[11] & ~instr_i[10] & ~instr_i[8] & instr_i[7] & rvc_jr_o ;

    assign rvc_jalr_o   = (instr_i[15:13] == riscv_pkg::OpcodeC2JalrMvAdd)
                        & instr_i[12]
                        & (instr_i[6:2] == 5'b00000) & is_rvc_o;
    assign rvc_call_o   = rvc_jalr_o;

    assign rvc_imm_o    = (instr_i[14]) ? {{56{instr_i[12]}}, instr_i[6:5], instr_i[2], instr_i[11:10], instr_i[4:3], 1'b0}
                                       : {{53{instr_i[12]}}, instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], 1'b0};
endmodule
