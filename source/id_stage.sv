import ariane_pkg::*;module id_stage (
    input  logic                  clk_i,     
    input  logic                  rst_ni,    

    input  logic                  flush_i,

    input  frontend_fetch_t       fetch_entry_i,
    input  logic                  fetch_entry_valid_i,
    output logic                  decoded_instr_ack_o, 

    output scoreboard_entry_t     issue_entry_o,       
    output logic                  issue_entry_valid_o, 
    output logic                  is_ctrl_flow_o,      
    input  logic                  issue_instr_ack_i,   

    input  riscv_pkg::priv_lvl_t      priv_lvl_i,          
    input  riscv_pkg::xs_t            fs_i,                
    input  logic [2:0]            frm_i,               

    input  logic                  debug_mode_i,        
    input  logic                  tvm_i,
    input  logic                  tw_i,
    input  logic                  tsr_i
);

    struct packed {
        logic              valid;
        scoreboard_entry_t sbe;
        logic              is_ctrl_flow;
    } issue_n, issue_q;

    logic                is_control_flow_instr;
    scoreboard_entry_t   decoded_instruction;

    fetch_entry_t        fetch_entry;
    logic                is_illegal;
    logic                [31:0] instruction;
    logic                is_compressed;
    logic                fetch_ack_i;
    logic                fetch_entry_valid;

    instr_realigner instr_realigner_i (
        .fetch_entry_i           ( fetch_entry_i               ),
        .fetch_entry_valid_i     ( fetch_entry_valid_i         ),
        .fetch_ack_o             ( decoded_instr_ack_o         ),

        .fetch_entry_o           ( fetch_entry                 ),
        .fetch_entry_valid_o     ( fetch_entry_valid           ),
        .fetch_ack_i             ( fetch_ack_i                 ),
        .*
    );

    compressed_decoder compressed_decoder_i (
        .instr_i                 ( fetch_entry.instruction     ),
        .instr_o                 ( instruction                 ),
        .illegal_instr_o         ( is_illegal                  ),
        .is_compressed_o         ( is_compressed               )

    );

    decoder decoder_i (
        .pc_i                    ( fetch_entry.address           ),
        .is_compressed_i         ( is_compressed                 ),
        .compressed_instr_i      ( fetch_entry.instruction[15:0] ),
        .instruction_i           ( instruction                   ),
        .branch_predict_i        ( fetch_entry.branch_predict    ),
        .is_illegal_i            ( is_illegal                    ),
        .ex_i                    ( fetch_entry.ex                ),
        .instruction_o           ( decoded_instruction           ),
        .is_control_flow_instr_o ( is_control_flow_instr         ),
        .fs_i,
        .frm_i,
        .*
    );

    assign issue_entry_o = issue_q.sbe;
    assign issue_entry_valid_o = issue_q.valid;
    assign is_ctrl_flow_o = issue_q.is_ctrl_flow;

    always_comb begin
        issue_n     = issue_q;
        fetch_ack_i = 1'b0;

        if (issue_instr_ack_i)
            issue_n.valid = 1'b0;

        if ((!issue_q.valid || issue_instr_ack_i) && fetch_entry_valid) begin
            fetch_ack_i = 1'b1;
            issue_n = {1'b1, decoded_instruction, is_control_flow_instr};
        end

        if (flush_i)
            issue_n.valid = 1'b0;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            issue_q <= '0;
        end else begin
            issue_q <= issue_n;
        end
    end

endmodule
