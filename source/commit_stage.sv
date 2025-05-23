import ariane_pkg::*;module commit_stage #(
    parameter int unsigned NR_COMMIT_PORTS = 2
)(
    input  logic                                    clk_i,
    input  logic                                    rst_ni,
    input  logic                                    halt_i,             
    input  logic                                    flush_dcache_i,     
    output exception_t                              exception_o,        
    output logic                                    dirty_fp_state_o,   
    input  logic                                    debug_mode_i,       
    input  logic                                    debug_req_i,        
    input  logic                                    single_step_i,      

    input  scoreboard_entry_t [NR_COMMIT_PORTS-1:0] commit_instr_i,     
    output logic [NR_COMMIT_PORTS-1:0]              commit_ack_o,       

    output  logic [NR_COMMIT_PORTS-1:0][4:0]        waddr_o,            
    output  logic [NR_COMMIT_PORTS-1:0][63:0]       wdata_o,            
    output  logic [NR_COMMIT_PORTS-1:0]             we_gpr_o,           
    output  logic [NR_COMMIT_PORTS-1:0]             we_fpr_o,           

    input  amo_resp_t                               amo_resp_i,         

    output logic [63:0]                             pc_o,

    output fu_op                                    csr_op_o,           
    output logic [63:0]                             csr_wdata_o,        
    input  logic [63:0]                             csr_rdata_i,        
    input  exception_t                              csr_exception_i,    
    output logic                                    csr_write_fflags_o, 

    output logic                                    commit_lsu_o,       
    input  logic                                    commit_lsu_ready_i, 
    output logic                                    amo_valid_commit_o, 
    input  logic                                    no_st_pending_i,    
    output logic                                    commit_csr_o,       
    output logic                                    fence_i_o,          
    output logic                                    fence_o,            
    output logic                                    flush_commit_o,     
    output logic                                    sfence_vma_o        
);

    assign waddr_o[0] = commit_instr_i[0].rd[4:0];
    assign waddr_o[1] = commit_instr_i[1].rd[4:0];

    assign pc_o       = commit_instr_i[0].pc;
    assign dirty_fp_state_o = |we_fpr_o;

    logic instr_0_is_amo;
    assign instr_0_is_amo = is_amo(commit_instr_i[0].op);

    always_comb begin : commit

        commit_ack_o[0]    = 1'b0;
        commit_ack_o[1]    = 1'b0;

        amo_valid_commit_o = 1'b0;

        we_gpr_o[0]        = 1'b0;
        we_gpr_o[1]        = 1'b0;
        we_fpr_o           = '{default: 1'b0};
        commit_lsu_o       = 1'b0;
        commit_csr_o       = 1'b0;

        wdata_o[0]      = (amo_resp_i.ack) ? amo_resp_i.result : commit_instr_i[0].result;
        wdata_o[1]      = commit_instr_i[1].result;
        csr_op_o        = ADD; 
        csr_wdata_o        = 64'b0;
        fence_i_o          = 1'b0;
        fence_o            = 1'b0;
        sfence_vma_o       = 1'b0;
        csr_write_fflags_o = 1'b0;
        flush_commit_o  = 1'b0;

        if (commit_instr_i[0].valid && !halt_i) begin

            if (!debug_req_i || debug_mode_i) begin
                commit_ack_o[0] = 1'b1;

                if (!exception_o.valid) begin

                    if (is_rd_fpr(commit_instr_i[0].op))
                        we_fpr_o[0] = 1'b1;
                    else
                        we_gpr_o[0] = 1'b1;

                    if (commit_instr_i[0].fu == STORE && !instr_0_is_amo) begin

                        if (commit_lsu_ready_i)
                            commit_lsu_o = 1'b1;
                        else 
                            commit_ack_o[0] = 1'b0;
                    end

                    if (commit_instr_i[0].fu inside {FPU, FPU_VEC}) begin

                        csr_wdata_o = {59'b0, commit_instr_i[0].ex.cause[4:0]};
                        csr_write_fflags_o = 1'b1;
                    end
                end

                if (commit_instr_i[0].fu == CSR) begin

                    commit_csr_o = 1'b1;
                    wdata_o[0]   = csr_rdata_i;
                    csr_op_o     = commit_instr_i[0].op;
                    csr_wdata_o  = commit_instr_i[0].result;
                end

                if (commit_instr_i[0].op == SFENCE_VMA) begin

                    sfence_vma_o = no_st_pending_i;

                    commit_ack_o[0] = no_st_pending_i;
                end

                if (commit_instr_i[0].op == FENCE_I || (flush_dcache_i && commit_instr_i[0].fu != STORE)) begin
                    commit_ack_o[0] = no_st_pending_i;

                    fence_i_o = no_st_pending_i;
                end

                if (commit_instr_i[0].op == FENCE) begin
                    commit_ack_o[0] = no_st_pending_i;

                    fence_o = no_st_pending_i;
                end
            end

            if (RVA && instr_0_is_amo && !commit_instr_i[0].ex.valid) begin

                commit_ack_o[0] = amo_resp_i.ack;

                flush_commit_o = amo_resp_i.ack;
                amo_valid_commit_o = 1'b1;
                we_gpr_o[0] = amo_resp_i.ack;
            end
        end

        if (commit_ack_o[0] && commit_instr_i[1].valid
                            && !halt_i
                            && !(commit_instr_i[0].fu inside {CSR})
                            && !flush_dcache_i
                            && !instr_0_is_amo
                            && !single_step_i) begin

            if (!exception_o.valid && !commit_instr_i[1].ex.valid
                                   && (commit_instr_i[1].fu inside {ALU, LOAD, CTRL_FLOW, MULT, FPU, FPU_VEC})) begin

                if (is_rd_fpr(commit_instr_i[1].op))
                    we_fpr_o[1] = 1'b1;
                else
                    we_gpr_o[1] = 1'b1;

                commit_ack_o[1] = 1'b1;

                if (commit_instr_i[1].fu inside {FPU, FPU_VEC}) begin
                    if (csr_write_fflags_o)
                        csr_wdata_o = {59'b0, (commit_instr_i[0].ex.cause[4:0] | commit_instr_i[1].ex.cause[4:0])};
                    else
                        csr_wdata_o = {59'b0, commit_instr_i[1].ex.cause[4:0]};

                    csr_write_fflags_o = 1'b1;
                end
            end
        end
    end

    always_comb begin : exception_handling

        exception_o.valid = 1'b0;
        exception_o.cause = 64'b0;
        exception_o.tval  = 64'b0;

        if (commit_instr_i[0].valid) begin

            if (csr_exception_i.valid && !csr_exception_i.cause[63]) begin
                exception_o      = csr_exception_i;

                exception_o.tval = commit_instr_i[0].ex.tval;
            end

            if (commit_instr_i[0].ex.valid) begin
                exception_o = commit_instr_i[0].ex;
            end

            if (csr_exception_i.valid && csr_exception_i.cause[63]
                                      && !amo_valid_commit_o
                                      && commit_instr_i[0].fu != CSR) begin
                exception_o = csr_exception_i;
                exception_o.tval = commit_instr_i[0].ex.tval;
            end
        end

        if (halt_i) begin
            exception_o.valid = 1'b0;
        end
    end

endmodule
