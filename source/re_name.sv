import ariane_pkg::*;module re_name (
    input  logic                                   clk_i,    
    input  logic                                   rst_ni,   
    input  logic                                   flush_i,  
    input  logic                                   flush_unissied_instr_i,

    input  scoreboard_entry_t                      issue_instr_i,
    input  logic                                   issue_instr_valid_i,
    output logic                                   issue_ack_o,

    output scoreboard_entry_t                      issue_instr_o,
    output logic                                   issue_instr_valid_o,
    input  logic                                   issue_ack_i
);

    assign issue_instr_valid_o = issue_instr_valid_i;
    assign issue_ack_o         = issue_ack_i;

    logic [31:0] re_name_table_gpr_n, re_name_table_gpr_q;
    logic [31:0] re_name_table_fpr_n, re_name_table_fpr_q;

    always_comb begin

        logic name_bit_rs1, name_bit_rs2, name_bit_rs3, name_bit_rd;

        re_name_table_gpr_n = re_name_table_gpr_q;
        re_name_table_fpr_n = re_name_table_fpr_q;
        issue_instr_o       = issue_instr_i;

        if (issue_ack_i && !flush_unissied_instr_i) begin

            if (is_rd_fpr(issue_instr_i.op))
                re_name_table_fpr_n[issue_instr_i.rd] = re_name_table_fpr_q[issue_instr_i.rd] ^ 1'b1;
            else
                re_name_table_gpr_n[issue_instr_i.rd] = re_name_table_gpr_q[issue_instr_i.rd] ^ 1'b1;
        end

        name_bit_rs1 = is_rs1_fpr(issue_instr_i.op) ? re_name_table_fpr_q[issue_instr_i.rs1]
                                                    : re_name_table_gpr_q[issue_instr_i.rs1];
        name_bit_rs2 = is_rs2_fpr(issue_instr_i.op) ? re_name_table_fpr_q[issue_instr_i.rs2]
                                                    : re_name_table_gpr_q[issue_instr_i.rs2];

        name_bit_rs3 = re_name_table_fpr_q[issue_instr_i.result[4:0]]; 

        name_bit_rd = is_rd_fpr(issue_instr_i.op) ? re_name_table_fpr_q[issue_instr_i.rd] ^ 1'b1
                                                  : re_name_table_gpr_q[issue_instr_i.rd] ^ (issue_instr_i.rd != '0); 

        issue_instr_o.rs1 = { ENABLE_RENAME & name_bit_rs1, issue_instr_i.rs1[4:0] };
        issue_instr_o.rs2 = { ENABLE_RENAME & name_bit_rs2, issue_instr_i.rs2[4:0] };

        if (is_imm_fpr(issue_instr_i.op))
            issue_instr_o.result = { ENABLE_RENAME & name_bit_rs3, issue_instr_i.result[4:0]};

        issue_instr_o.rd = { ENABLE_RENAME & name_bit_rd, issue_instr_i.rd[4:0] };

        re_name_table_gpr_n[0] = 1'b0;

        if (flush_i) begin
            re_name_table_gpr_n = '0;
            re_name_table_fpr_n = '0;
        end

    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            re_name_table_gpr_q <= '0;
            re_name_table_fpr_q <= '0;
        end else begin
            re_name_table_gpr_q <= re_name_table_gpr_n;
            re_name_table_fpr_q <= re_name_table_fpr_n;
        end
    end
endmodule
