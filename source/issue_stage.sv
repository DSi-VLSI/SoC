import ariane_pkg::*;module issue_stage #(
    parameter int unsigned NR_ENTRIES = 8,
    parameter int unsigned NR_WB_PORTS = 4,
    parameter int unsigned NR_COMMIT_PORTS = 2
)(
    input  logic                                     clk_i,     
    input  logic                                     rst_ni,    

    output logic                                     sb_full_o,
    input  logic                                     flush_unissued_instr_i,
    input  logic                                     flush_i,

    input  scoreboard_entry_t                        decoded_instr_i,
    input  logic                                     decoded_instr_valid_i,
    input  logic                                     is_ctrl_flow_i,
    output logic                                     decoded_instr_ack_o,

    output fu_data_t                                 fu_data_o,
    output logic [63:0]                              pc_o,
    output logic                                     is_compressed_instr_o,
    input  logic                                     flu_ready_i,
    output logic                                     alu_valid_o,

    input  logic                                     resolve_branch_i,

    input  logic                                     lsu_ready_i,
    output logic                                     lsu_valid_o,

    output logic                                     branch_valid_o,   
    output branchpredict_sbe_t                       branch_predict_o, 

    output logic                                     mult_valid_o,

    input  logic                                     fpu_ready_i,
    output logic                                     fpu_valid_o,
    output logic [1:0]                               fpu_fmt_o,        
    output logic [2:0]                               fpu_rm_o,         

    output logic                                     csr_valid_o,

    input logic [NR_WB_PORTS-1:0][TRANS_ID_BITS-1:0] trans_id_i,
    input branchpredict_t                            resolved_branch_i,
    input logic [NR_WB_PORTS-1:0][63:0]              wbdata_i,
    input exception_t [NR_WB_PORTS-1:0]              ex_ex_i, 
    input logic [NR_WB_PORTS-1:0]                    wb_valid_i,

    input  logic [NR_COMMIT_PORTS-1:0][4:0]          waddr_i,
    input  logic [NR_COMMIT_PORTS-1:0][63:0]         wdata_i,
    input  logic [NR_COMMIT_PORTS-1:0]               we_gpr_i,
    input  logic [NR_COMMIT_PORTS-1:0]               we_fpr_i,

    output scoreboard_entry_t [NR_COMMIT_PORTS-1:0]  commit_instr_o,
    input  logic              [NR_COMMIT_PORTS-1:0]  commit_ack_i
);

    fu_t  [2**REG_ADDR_SIZE:0] rd_clobber_gpr_sb_iro;
    fu_t  [2**REG_ADDR_SIZE:0] rd_clobber_fpr_sb_iro;

    logic [REG_ADDR_SIZE-1:0]  rs1_iro_sb;
    logic [63:0]               rs1_sb_iro;
    logic                      rs1_valid_sb_iro;

    logic [REG_ADDR_SIZE-1:0]  rs2_iro_sb;
    logic [63:0]               rs2_sb_iro;
    logic                      rs2_valid_iro_sb;

    logic [REG_ADDR_SIZE-1:0]  rs3_iro_sb;
    logic [FLEN-1:0]           rs3_sb_iro;
    logic                      rs3_valid_iro_sb;

    scoreboard_entry_t         issue_instr_rename_sb;
    logic                      issue_instr_valid_rename_sb;
    logic                      issue_ack_sb_rename;

    scoreboard_entry_t         issue_instr_sb_iro;
    logic                      issue_instr_valid_sb_iro;
    logic                      issue_ack_iro_sb;

    re_name i_re_name (
        .clk_i                  ( clk_i                        ),
        .rst_ni                 ( rst_ni                       ),
        .flush_i                ( flush_i                      ),
        .flush_unissied_instr_i ( flush_unissued_instr_i       ),
        .issue_instr_i          ( decoded_instr_i              ),
        .issue_instr_valid_i    ( decoded_instr_valid_i        ),
        .issue_ack_o            ( decoded_instr_ack_o          ),
        .issue_instr_o          ( issue_instr_rename_sb        ),
        .issue_instr_valid_o    ( issue_instr_valid_rename_sb  ),
        .issue_ack_i            ( issue_ack_sb_rename          )
    );

    scoreboard #(
        .NR_ENTRIES (NR_ENTRIES ),
        .NR_WB_PORTS(NR_WB_PORTS)
    ) i_scoreboard (
        .sb_full_o             ( sb_full_o                                 ),
        .unresolved_branch_i   ( 1'b0                                      ),
        .rd_clobber_gpr_o      ( rd_clobber_gpr_sb_iro                     ),
        .rd_clobber_fpr_o      ( rd_clobber_fpr_sb_iro                     ),
        .rs1_i                 ( rs1_iro_sb                                ),
        .rs1_o                 ( rs1_sb_iro                                ),
        .rs1_valid_o           ( rs1_valid_sb_iro                          ),
        .rs2_i                 ( rs2_iro_sb                                ),
        .rs2_o                 ( rs2_sb_iro                                ),
        .rs2_valid_o           ( rs2_valid_iro_sb                          ),
        .rs3_i                 ( rs3_iro_sb                                ),
        .rs3_o                 ( rs3_sb_iro                                ),
        .rs3_valid_o           ( rs3_valid_iro_sb                          ),

        .decoded_instr_i       ( issue_instr_rename_sb                     ),
        .decoded_instr_valid_i ( issue_instr_valid_rename_sb               ),
        .decoded_instr_ack_o   ( issue_ack_sb_rename                       ),
        .issue_instr_o         ( issue_instr_sb_iro                        ),
        .issue_instr_valid_o   ( issue_instr_valid_sb_iro                  ),
        .issue_ack_i           ( issue_ack_iro_sb                          ),

        .resolved_branch_i     ( resolved_branch_i                         ),
        .trans_id_i            ( trans_id_i                                ),
        .wbdata_i              ( wbdata_i                                  ),
        .ex_i                  ( ex_ex_i                                   ),
        .*
    );

    issue_read_operands i_issue_read_operands  (
        .flush_i             ( flush_unissued_instr_i          ),
        .issue_instr_i       ( issue_instr_sb_iro              ),
        .issue_instr_valid_i ( issue_instr_valid_sb_iro        ),
        .issue_ack_o         ( issue_ack_iro_sb                ),
        .fu_data_o           ( fu_data_o                       ),
        .flu_ready_i         ( flu_ready_i                     ),
        .rs1_o               ( rs1_iro_sb                      ),
        .rs1_i               ( rs1_sb_iro                      ),
        .rs1_valid_i         ( rs1_valid_sb_iro                ),
        .rs2_o               ( rs2_iro_sb                      ),
        .rs2_i               ( rs2_sb_iro                      ),
        .rs2_valid_i         ( rs2_valid_iro_sb                ),
        .rs3_o               ( rs3_iro_sb                      ),
        .rs3_i               ( rs3_sb_iro                      ),
        .rs3_valid_i         ( rs3_valid_iro_sb                ),
        .rd_clobber_gpr_i    ( rd_clobber_gpr_sb_iro           ),
        .rd_clobber_fpr_i    ( rd_clobber_fpr_sb_iro           ),
        .alu_valid_o         ( alu_valid_o                     ),
        .branch_valid_o      ( branch_valid_o                  ),
        .csr_valid_o         ( csr_valid_o                     ),
        .mult_valid_o        ( mult_valid_o                    ),
        .*
    );

endmodule
