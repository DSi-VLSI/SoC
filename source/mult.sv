import ariane_pkg::*;module mult (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     flush_i,
    input  fu_data_t                 fu_data_i,
    input  logic                     mult_valid_i,
    output logic [63:0]              result_o,
    output logic                     mult_valid_o,
    output logic                     mult_ready_o,
    output logic [TRANS_ID_BITS-1:0] mult_trans_id_o
);
    logic                     mul_valid;
    logic                     div_valid;
    logic                     div_ready_i; 
    logic [TRANS_ID_BITS-1:0] mul_trans_id;
    logic [TRANS_ID_BITS-1:0] div_trans_id;
    logic [63:0]              mul_result;
    logic [63:0]              div_result;

    logic                     div_valid_op;
    logic                     mul_valid_op;

    assign mul_valid_op = ~flush_i && mult_valid_i && (fu_data_i.operator inside { MUL, MULH, MULHU, MULHSU, MULW });
    assign div_valid_op = ~flush_i && mult_valid_i && (fu_data_i.operator inside { DIV, DIVU, DIVW, DIVUW, REM, REMU, REMW, REMUW });

    assign div_ready_i      = (mul_valid) ? 1'b0         : 1'b1;
    assign mult_trans_id_o  = (mul_valid) ? mul_trans_id : div_trans_id;
    assign result_o         = (mul_valid) ? mul_result   : div_result;
    assign mult_valid_o     = div_valid | mul_valid;

    multiplier i_multiplier (
        .clk_i,
        .rst_ni,
        .trans_id_i        ( fu_data_i.trans_id  ),
        .operator_i        ( fu_data_i.operator  ),
        .operand_a_i       ( fu_data_i.operand_a ),
        .operand_b_i       ( fu_data_i.operand_b ),
        .result_o          ( mul_result   ),
        .mult_valid_i      ( mul_valid_op ),
        .mult_valid_o      ( mul_valid    ),
        .mult_trans_id_o   ( mul_trans_id ),
        .mult_ready_o      (              ) 
    );

    logic [63:0] operand_b, operand_a;  
    logic [63:0] result;                

    logic        div_signed;            
    logic        rem;                   
    logic        word_op_d, word_op_q;  

    assign div_signed = fu_data_i.operator inside {DIV, DIVW, REM, REMW};

    assign rem        = fu_data_i.operator inside {REM, REMU, REMW, REMUW};

    always_comb begin

        operand_a   = '0;
        operand_b   = '0;

        word_op_d   = word_op_q;

        if (mult_valid_i && fu_data_i.operator inside {DIV, DIVU, DIVW, DIVUW, REM, REMU, REMW, REMUW}) begin

            if (fu_data_i.operator inside {DIVW, DIVUW, REMW, REMUW}) begin

                if (div_signed) begin
                    operand_a = sext32(fu_data_i.operand_a[31:0]);
                    operand_b = sext32(fu_data_i.operand_b[31:0]);
                end else begin
                    operand_a = fu_data_i.operand_a[31:0];
                    operand_b = fu_data_i.operand_b[31:0];
                end

                word_op_d = 1'b1;
            end else begin

                operand_a = fu_data_i.operand_a;
                operand_b = fu_data_i.operand_b;
                word_op_d = 1'b0;
            end
        end
    end

    serdiv #(
        .WIDTH       ( 64 )
    ) i_div (
        .clk_i       ( clk_i                ),
        .rst_ni      ( rst_ni               ),
        .id_i        ( fu_data_i.trans_id   ),
        .op_a_i      ( operand_a            ),
        .op_b_i      ( operand_b            ),
        .opcode_i    ( {rem, div_signed}    ), 
        .in_vld_i    ( div_valid_op         ),
        .in_rdy_o    ( mult_ready_o         ),
        .flush_i     ( flush_i              ),
        .out_vld_o   ( div_valid            ),
        .out_rdy_i   ( div_ready_i          ),
        .id_o        ( div_trans_id         ),
        .res_o       ( result               )
    );

    assign div_result = (word_op_q) ? sext32(result) : result;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            word_op_q <= '0;
        end else begin
            word_op_q <= word_op_d;
        end
    end
endmodule
