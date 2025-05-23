import ariane_pkg::*;module controller (
    input  logic            clk_i,
    input  logic            rst_ni,
    output logic            set_pc_commit_o,        
    output logic            flush_if_o,             
    output logic            flush_unissued_instr_o, 
    output logic            flush_id_o,             
    output logic            flush_ex_o,             
    output logic            flush_icache_o,         
    output logic            flush_dcache_o,         
    input  logic            flush_dcache_ack_i,     
    output logic            flush_tlb_o,            

    input  logic            halt_csr_i,             
    output logic            halt_o,                 
    input  logic            eret_i,                 
    input  logic            ex_valid_i,             
    input  logic            set_debug_pc_i,         
    input  branchpredict_t  resolved_branch_i,      
    input  logic            flush_csr_i,            
    input  logic            fence_i_i,              
    input  logic            fence_i,                
    input  logic            sfence_vma_i,           
    input  logic            flush_commit_i          
);

    logic fence_active_d, fence_active_q;
    logic flush_dcache;

    always_comb begin : flush_ctrl
        fence_active_d         = fence_active_q;
        set_pc_commit_o        = 1'b0;
        flush_if_o             = 1'b0;
        flush_unissued_instr_o = 1'b0;
        flush_id_o             = 1'b0;
        flush_ex_o             = 1'b0;
        flush_dcache           = 1'b0;
        flush_icache_o         = 1'b0;
        flush_tlb_o            = 1'b0;

        if (resolved_branch_i.is_mispredict) begin

            flush_unissued_instr_o = 1'b1;

            flush_if_o             = 1'b1;
        end

        if (fence_i) begin

            set_pc_commit_o        = 1'b1;
            flush_if_o             = 1'b1;
            flush_unissued_instr_o = 1'b1;
            flush_id_o             = 1'b1;
            flush_ex_o             = 1'b1;

            flush_dcache           = 1'b1;
            fence_active_d         = 1'b1;
        end

        if (fence_i_i) begin
            set_pc_commit_o        = 1'b1;
            flush_if_o             = 1'b1;
            flush_unissued_instr_o = 1'b1;
            flush_id_o             = 1'b1;
            flush_ex_o             = 1'b1;
            flush_icache_o         = 1'b1;

            flush_dcache           = 1'b1;
            fence_active_d         = 1'b1;
        end

        if (flush_dcache_ack_i && fence_active_q) begin
            fence_active_d = 1'b0;

        end else if (fence_active_q) begin
            flush_dcache = 1'b1;
        end

        if (sfence_vma_i) begin
            set_pc_commit_o        = 1'b1;
            flush_if_o             = 1'b1;
            flush_unissued_instr_o = 1'b1;
            flush_id_o             = 1'b1;
            flush_ex_o             = 1'b1;

            flush_tlb_o            = 1'b1;
        end

        if (flush_csr_i || flush_commit_i) begin
            set_pc_commit_o        = 1'b1;
            flush_if_o             = 1'b1;
            flush_unissued_instr_o = 1'b1;
            flush_id_o             = 1'b1;
            flush_ex_o             = 1'b1;
        end

        if (ex_valid_i || eret_i || set_debug_pc_i) begin

            set_pc_commit_o        = 1'b0;
            flush_if_o             = 1'b1;
            flush_unissued_instr_o = 1'b1;
            flush_id_o             = 1'b1;
            flush_ex_o             = 1'b1;
        end
    end

    always_comb begin

        halt_o = halt_csr_i || fence_active_q;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            fence_active_q <= 1'b0;
            flush_dcache_o <= 1'b0;
        end else begin
            fence_active_q <= fence_active_d;

            flush_dcache_o <= flush_dcache;
        end
    end
endmodule
