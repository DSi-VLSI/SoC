import ariane_pkg::*;module multiplier (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic [TRANS_ID_BITS-1:0] trans_id_i,
    input  logic                     mult_valid_i,
    input  fu_op                     operator_i,
    input  logic [63:0]              operand_a_i,
    input  logic [63:0]              operand_b_i,
    output logic [63:0]              result_o,
    output logic                     mult_valid_o,
    output logic                     mult_ready_o,
    output logic [TRANS_ID_BITS-1:0] mult_trans_id_o
);

    logic [TRANS_ID_BITS-1:0]    trans_id_q;
    logic                        mult_valid_q;
    fu_op                        operator_d, operator_q;
    logic [127:0] mult_result_d, mult_result_q;

    logic                       sign_a, sign_b;
    logic                       mult_valid;

    assign mult_valid_o    = mult_valid_q;
    assign mult_trans_id_o = trans_id_q;
    assign mult_ready_o    = 1'b1;

    assign mult_valid      = mult_valid_i && (operator_i inside {MUL, MULH, MULHU, MULHSU, MULW});

    logic [127:0] mult_result;
    assign mult_result   = $signed({operand_a_i[63] & sign_a, operand_a_i}) * $signed({operand_b_i[63] & sign_b, operand_b_i});

    always_comb begin
        sign_a = 1'b0;
        sign_b = 1'b0;

        if (operator_i == MULH) begin
            sign_a   = 1'b1;
            sign_b   = 1'b1;

        end else if (operator_i == MULHSU) begin
            sign_a   = 1'b1;

        end else begin
            sign_a   = 1'b0;
            sign_b   = 1'b0;
        end
    end

    assign mult_result_d   = $signed({operand_a_i[63] & sign_a, operand_a_i}) *
                             $signed({operand_b_i[63] & sign_b, operand_b_i});

    assign operator_d = operator_i;
    always_comb begin : p_selmux
        unique case (operator_q)
            MULH, MULHU, MULHSU: result_o = mult_result_q[127:64];
            MULW:                result_o = sext32(mult_result_q[31:0]);

            default:             result_o = mult_result_q[63:0];
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mult_valid_q    <= '0;
            trans_id_q      <= '0;
            operator_q      <=  MUL;
            mult_result_q   <= '0;
         end else begin

            trans_id_q   <= trans_id_i;

            mult_valid_q    <= mult_valid;
            operator_q      <= operator_d;
            mult_result_q   <= mult_result_d;
         end
    end
endmodule
