import ariane_pkg::*;module mmu #(
      parameter int unsigned INSTR_TLB_ENTRIES = 4,
      parameter int unsigned DATA_TLB_ENTRIES  = 4,
      parameter int unsigned ASID_WIDTH        = 1
)(
        input  logic                            clk_i,
        input  logic                            rst_ni,
        input  logic                            flush_i,
        input  logic                            enable_translation_i,
        input  logic                            en_ld_st_translation_i,   

        input  icache_areq_o_t                  icache_areq_i,
        output icache_areq_i_t                  icache_areq_o,

        input  exception_t                      misaligned_ex_i,
        input  logic                            lsu_req_i,        
        input  logic [63:0]                     lsu_vaddr_i,      
        input  logic                            lsu_is_store_i,   

        output logic                            lsu_dtlb_hit_o,   

        output logic                            lsu_valid_o,      
        output logic [63:0]                     lsu_paddr_o,      
        output exception_t                      lsu_exception_o,  

        input riscv_pkg::priv_lvl_t                 priv_lvl_i,
        input riscv_pkg::priv_lvl_t                 ld_st_priv_lvl_i,
        input logic                             sum_i,
        input logic                             mxr_i,

        input logic [43:0]                      satp_ppn_i,
        input logic [ASID_WIDTH-1:0]            asid_i,
        input logic                             flush_tlb_i,

        output logic                            itlb_miss_o,
        output logic                            dtlb_miss_o,

        input  dcache_req_o_t                   req_port_i,
        output dcache_req_i_t                   req_port_o
);

    logic        iaccess_err;   
    logic        daccess_err;   
    logic        ptw_active;    
    logic        walking_instr; 
    logic        ptw_error;     

    logic [38:0] update_vaddr;
    tlb_update_t update_ptw_itlb, update_ptw_dtlb;

    logic        itlb_lu_access;
    riscv_pkg::pte_t itlb_content;
    logic        itlb_is_2M;
    logic        itlb_is_1G;
    logic        itlb_lu_hit;

    logic        dtlb_lu_access;
    riscv_pkg::pte_t dtlb_content;
    logic        dtlb_is_2M;
    logic        dtlb_is_1G;
    logic        dtlb_lu_hit;

    assign itlb_lu_access = icache_areq_i.fetch_req;
    assign dtlb_lu_access = lsu_req_i;

    tlb #(
        .TLB_ENTRIES      ( INSTR_TLB_ENTRIES          ),
        .ASID_WIDTH       ( ASID_WIDTH                 )
    ) i_itlb (
        .clk_i            ( clk_i                      ),
        .rst_ni           ( rst_ni                     ),
        .flush_i          ( flush_tlb_i                ),

        .update_i         ( update_ptw_itlb            ),

        .lu_access_i      ( itlb_lu_access             ),
        .lu_asid_i        ( asid_i                     ),
        .lu_vaddr_i       ( icache_areq_i.fetch_vaddr              ),
        .lu_content_o     ( itlb_content               ),

        .lu_is_2M_o       ( itlb_is_2M                 ),
        .lu_is_1G_o       ( itlb_is_1G                 ),
        .lu_hit_o         ( itlb_lu_hit                )
    );

    tlb #(
        .TLB_ENTRIES     ( DATA_TLB_ENTRIES             ),
        .ASID_WIDTH      ( ASID_WIDTH                   )
    ) i_dtlb (
        .clk_i            ( clk_i                       ),
        .rst_ni           ( rst_ni                      ),
        .flush_i          ( flush_tlb_i                 ),

        .update_i         ( update_ptw_dtlb             ),

        .lu_access_i      ( dtlb_lu_access              ),
        .lu_asid_i        ( asid_i                      ),
        .lu_vaddr_i       ( lsu_vaddr_i                 ),
        .lu_content_o     ( dtlb_content                ),

        .lu_is_2M_o       ( dtlb_is_2M                  ),
        .lu_is_1G_o       ( dtlb_is_1G                  ),
        .lu_hit_o         ( dtlb_lu_hit                 )
    );

    ptw  #(
        .ASID_WIDTH             ( ASID_WIDTH            )
    ) i_ptw (
        .clk_i                  ( clk_i                 ),
        .rst_ni                 ( rst_ni                ),
        .ptw_active_o           ( ptw_active            ),
        .walking_instr_o        ( walking_instr         ),
        .ptw_error_o            ( ptw_error             ),
        .enable_translation_i   ( enable_translation_i  ),

        .update_vaddr_o         ( update_vaddr          ),
        .itlb_update_o          ( update_ptw_itlb       ),
        .dtlb_update_o          ( update_ptw_dtlb       ),

        .itlb_access_i          ( itlb_lu_access        ),
        .itlb_hit_i             ( itlb_lu_hit           ),
        .itlb_vaddr_i           ( icache_areq_i.fetch_vaddr         ),

        .dtlb_access_i          ( dtlb_lu_access        ),
        .dtlb_hit_i             ( dtlb_lu_hit           ),
        .dtlb_vaddr_i           ( lsu_vaddr_i           ),

        .req_port_i            ( req_port_i             ),
        .req_port_o            ( req_port_o             ),

        .*
     );

    always_comb begin : instr_interface

        icache_areq_o.fetch_valid  = icache_areq_i.fetch_req;
        icache_areq_o.fetch_paddr  = icache_areq_i.fetch_vaddr; 

        icache_areq_o.fetch_exception      = '0;

        iaccess_err   = icache_areq_i.fetch_req && (((priv_lvl_i == riscv_pkg::PRIV_LVL_U) && ~itlb_content.u)
                                                 || ((priv_lvl_i == riscv_pkg::PRIV_LVL_S) && itlb_content.u));

        if (enable_translation_i) begin

            if (icache_areq_i.fetch_req && !((&icache_areq_i.fetch_vaddr[63:38]) == 1'b1 || (|icache_areq_i.fetch_vaddr[63:38]) == 1'b0)) begin
                icache_areq_o.fetch_exception = {riscv_pkg::INSTR_ACCESS_FAULT, icache_areq_i.fetch_vaddr, 1'b1};
            end

            icache_areq_o.fetch_valid = 1'b0;

            icache_areq_o.fetch_paddr = {itlb_content.ppn, icache_areq_i.fetch_vaddr[11:0]};

            if (itlb_is_2M) begin
                icache_areq_o.fetch_paddr[20:12] = icache_areq_i.fetch_vaddr[20:12];
            end

            if (itlb_is_1G) begin
                icache_areq_o.fetch_paddr[29:12] = icache_areq_i.fetch_vaddr[29:12];
            end

            if (itlb_lu_hit) begin
                icache_areq_o.fetch_valid = icache_areq_i.fetch_req;

                if (iaccess_err) begin

                    icache_areq_o.fetch_exception = {riscv_pkg::INSTR_PAGE_FAULT, icache_areq_i.fetch_vaddr, 1'b1};
                end
            end else

            if (ptw_active && walking_instr) begin
                icache_areq_o.fetch_valid = ptw_error;
                icache_areq_o.fetch_exception = {riscv_pkg::INSTR_PAGE_FAULT, {25'b0, update_vaddr}, 1'b1};
            end
        end
    end

    logic [63:0] lsu_vaddr_n,     lsu_vaddr_q;
    riscv_pkg::pte_t dtlb_pte_n,      dtlb_pte_q;
    exception_t  misaligned_ex_n, misaligned_ex_q;
    logic        lsu_req_n,       lsu_req_q;
    logic        lsu_is_store_n,  lsu_is_store_q;
    logic        dtlb_hit_n,      dtlb_hit_q;
    logic        dtlb_is_2M_n,    dtlb_is_2M_q;
    logic        dtlb_is_1G_n,    dtlb_is_1G_q;

    assign lsu_dtlb_hit_o = (en_ld_st_translation_i) ? dtlb_lu_hit :  1'b1;

    always_comb begin : data_interface

        lsu_vaddr_n           = lsu_vaddr_i;
        lsu_req_n             = lsu_req_i;
        misaligned_ex_n       = misaligned_ex_i;
        dtlb_pte_n            = dtlb_content;
        dtlb_hit_n            = dtlb_lu_hit;
        lsu_is_store_n        = lsu_is_store_i;
        dtlb_is_2M_n          = dtlb_is_2M;
        dtlb_is_1G_n          = dtlb_is_1G;

        lsu_paddr_o           = lsu_vaddr_q;
        lsu_valid_o           = lsu_req_q;
        lsu_exception_o       = misaligned_ex_q;

        misaligned_ex_n.valid = misaligned_ex_i.valid & lsu_req_i;

        daccess_err = (ld_st_priv_lvl_i == riscv_pkg::PRIV_LVL_S && !sum_i && dtlb_pte_q.u) || 
                      (ld_st_priv_lvl_i == riscv_pkg::PRIV_LVL_U && !dtlb_pte_q.u);            

        if (en_ld_st_translation_i && !misaligned_ex_q.valid) begin
            lsu_valid_o = 1'b0;

            lsu_paddr_o = {dtlb_pte_q.ppn, lsu_vaddr_q[11:0]};

            if (dtlb_is_2M_q) begin
              lsu_paddr_o[20:12] = lsu_vaddr_q[20:12];
            end

            if (dtlb_is_1G_q) begin
                lsu_paddr_o[29:12] = lsu_vaddr_q[29:12];
            end

            if (dtlb_hit_q && lsu_req_q) begin
                lsu_valid_o = 1'b1;

                if (lsu_is_store_q) begin

                    if (!dtlb_pte_q.w || daccess_err || !dtlb_pte_q.d) begin
                        lsu_exception_o = {riscv_pkg::STORE_PAGE_FAULT, lsu_vaddr_q, 1'b1};
                    end

                end else if (daccess_err) begin
                    lsu_exception_o = {riscv_pkg::LOAD_PAGE_FAULT, lsu_vaddr_q, 1'b1};
                end
            end else

            if (ptw_active && !walking_instr) begin

                if (ptw_error) begin

                    lsu_valid_o = 1'b1;

                    if (lsu_is_store_q) begin
                        lsu_exception_o = {riscv_pkg::STORE_PAGE_FAULT, {25'b0, update_vaddr}, 1'b1};
                    end else begin
                        lsu_exception_o = {riscv_pkg::LOAD_PAGE_FAULT, {25'b0, update_vaddr}, 1'b1};
                    end
                end
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            lsu_vaddr_q      <= '0;
            lsu_req_q        <= '0;
            misaligned_ex_q  <= '0;
            dtlb_pte_q       <= '0;
            dtlb_hit_q       <= '0;
            lsu_is_store_q   <= '0;
            dtlb_is_2M_q     <= '0;
            dtlb_is_1G_q     <= '0;
        end else begin
            lsu_vaddr_q      <=  lsu_vaddr_n;
            lsu_req_q        <=  lsu_req_n;
            misaligned_ex_q  <=  misaligned_ex_n;
            dtlb_pte_q       <=  dtlb_pte_n;
            dtlb_hit_q       <=  dtlb_hit_n;
            lsu_is_store_q   <=  lsu_is_store_n;
            dtlb_is_2M_q     <=  dtlb_is_2M_n;
            dtlb_is_1G_q     <=  dtlb_is_1G_n;
        end
    end
endmodule
