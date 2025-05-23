module amo_alu (

        input  ariane_pkg::amo_t  amo_op_i,
        input  logic [63:0]       amo_operand_a_i,
        input  logic [63:0]       amo_operand_b_i,
        output logic [63:0]       amo_result_o 
);

    logic [64:0] adder_sum;
    logic [64:0] adder_operand_a, adder_operand_b;

    assign adder_sum = adder_operand_a + adder_operand_b;

    always_comb begin

        adder_operand_a = $signed(amo_operand_a_i);
        adder_operand_b = $signed(amo_operand_b_i);

        amo_result_o = amo_operand_b_i;

        unique case (amo_op_i)

            ariane_pkg::AMO_SC:;
            ariane_pkg::AMO_SWAP:;
            ariane_pkg::AMO_ADD: amo_result_o = adder_sum[63:0];
            ariane_pkg::AMO_AND: amo_result_o = amo_operand_a_i & amo_operand_b_i;
            ariane_pkg::AMO_OR:  amo_result_o = amo_operand_a_i | amo_operand_b_i;
            ariane_pkg::AMO_XOR: amo_result_o = amo_operand_a_i ^ amo_operand_b_i;
            ariane_pkg::AMO_MAX: begin
                adder_operand_b = -$signed(amo_operand_b_i);
                amo_result_o = adder_sum[64] ? amo_operand_b_i : amo_operand_a_i;
            end
            ariane_pkg::AMO_MIN: begin
                adder_operand_b = -$signed(amo_operand_b_i);
                amo_result_o = adder_sum[64] ? amo_operand_a_i : amo_operand_b_i;
            end
            ariane_pkg::AMO_MAXU: begin
                adder_operand_a = $unsigned(amo_operand_a_i);
                adder_operand_b = -$unsigned(amo_operand_b_i);
                amo_result_o = adder_sum[64] ? amo_operand_b_i : amo_operand_a_i;
            end
            ariane_pkg::AMO_MINU: begin
                adder_operand_a = $unsigned(amo_operand_a_i);
                adder_operand_b = -$unsigned(amo_operand_b_i);
                amo_result_o = adder_sum[64] ? amo_operand_a_i : amo_operand_b_i;
            end
            default: amo_result_o = '0;
        endcase
    end
endmodule
