import ariane_pkg::*;module ptw #(
        parameter int ASID_WIDTH = 1
    )(
    input  logic                    clk_i,                  
    input  logic                    rst_ni,                 
    input  logic                    flush_i,                

    output logic                    ptw_active_o,
    output logic                    walking_instr_o,        
    output logic                    ptw_error_o,            
    input  logic                    enable_translation_i,   
    input  logic                    en_ld_st_translation_i, 

    input  logic                    lsu_is_store_i,         

    input  dcache_req_o_t           req_port_i,
    output dcache_req_i_t           req_port_o,

    output tlb_update_t             itlb_update_o,
    output tlb_update_t             dtlb_update_o,

    output logic [38:0]             update_vaddr_o,

    input  logic [ASID_WIDTH-1:0]   asid_i,

    input  logic                    itlb_access_i,
    input  logic                    itlb_hit_i,
    input  logic [63:0]             itlb_vaddr_i,

    input  logic                    dtlb_access_i,
    input  logic                    dtlb_hit_i,
    input  logic [63:0]             dtlb_vaddr_i,

    input  logic [43:0]             satp_ppn_i, 
    input  logic                    mxr_i,

    output logic                    itlb_miss_o,
    output logic                    dtlb_miss_o

);

    logic data_rvalid_q;
    logic [63:0] data_rdata_q;

    riscv_pkg::pte_t pte;
    assign pte = riscv_pkg::pte_t'(data_rdata_q);

    enum logic[2:0] {
      IDLE,
      WAIT_GRANT,
      PTE_LOOKUP,
      WAIT_RVALID,
      PROPAGATE_ERROR
    } state_q, state_d;

    enum logic [1:0] {
        LVL1, LVL2, LVL3
    } ptw_lvl_q, ptw_lvl_n;

    logic is_instr_ptw_q,   is_instr_ptw_n;
    logic global_mapping_q, global_mapping_n;

    logic tag_valid_n,      tag_valid_q;

    logic [ASID_WIDTH-1:0]  tlb_update_asid_q, tlb_update_asid_n;

    logic [63:0] vaddr_q,   vaddr_n;

    logic[55:0] ptw_pptr_q, ptw_pptr_n;

    assign update_vaddr_o  = vaddr_q;

    assign ptw_active_o    = (state_q != IDLE);
    assign walking_instr_o = is_instr_ptw_q;

    assign req_port_o.address_index = ptw_pptr_q[DCACHE_INDEX_WIDTH-1:0];
    assign req_port_o.address_tag   = ptw_pptr_q[DCACHE_INDEX_WIDTH+DCACHE_TAG_WIDTH-1:DCACHE_INDEX_WIDTH];

    assign req_port_o.kill_req      = '0;

    assign req_port_o.data_wdata    = 64'b0;

    assign itlb_update_o.vpn = vaddr_q[38:12];
    assign dtlb_update_o.vpn = vaddr_q[38:12];

    assign itlb_update_o.is_2M = (ptw_lvl_q == LVL2);
    assign itlb_update_o.is_1G = (ptw_lvl_q == LVL1);
    assign dtlb_update_o.is_2M = (ptw_lvl_q == LVL2);
    assign dtlb_update_o.is_1G = (ptw_lvl_q == LVL1);

    assign itlb_update_o.asid = tlb_update_asid_q;
    assign dtlb_update_o.asid = tlb_update_asid_q;

    assign itlb_update_o.content = pte | (global_mapping_q << 5);
    assign dtlb_update_o.content = pte | (global_mapping_q << 5);

    assign req_port_o.tag_valid      = tag_valid_q;

    always_comb begin : ptw

        tag_valid_n           = 1'b0;
        req_port_o.data_req   = 1'b0;
        req_port_o.data_be    = 8'hFF;
        req_port_o.data_size  = 2'b11;
        req_port_o.data_we    = 1'b0;
        ptw_error_o           = 1'b0;
        itlb_update_o.valid   = 1'b0;
        dtlb_update_o.valid   = 1'b0;
        is_instr_ptw_n        = is_instr_ptw_q;
        ptw_lvl_n             = ptw_lvl_q;
        ptw_pptr_n            = ptw_pptr_q;
        state_d               = state_q;
        global_mapping_n      = global_mapping_q;

        tlb_update_asid_n     = tlb_update_asid_q;
        vaddr_n               = vaddr_q;

        itlb_miss_o           = 1'b0;
        dtlb_miss_o           = 1'b0;

        case (state_q)

            IDLE: begin

                ptw_lvl_n        = LVL1;
                global_mapping_n = 1'b0;
                is_instr_ptw_n   = 1'b0;

                if (enable_translation_i & itlb_access_i & ~itlb_hit_i & ~dtlb_access_i) begin
                    ptw_pptr_n          = {satp_ppn_i, itlb_vaddr_i[38:30], 3'b0};
                    is_instr_ptw_n      = 1'b1;
                    tlb_update_asid_n   = asid_i;
                    vaddr_n             = itlb_vaddr_i;
                    state_d             = WAIT_GRANT;
                    itlb_miss_o         = 1'b1;

                end else if (en_ld_st_translation_i & dtlb_access_i & ~dtlb_hit_i) begin
                    ptw_pptr_n          = {satp_ppn_i, dtlb_vaddr_i[38:30], 3'b0};
                    tlb_update_asid_n   = asid_i;
                    vaddr_n             = dtlb_vaddr_i;
                    state_d             = WAIT_GRANT;
                    dtlb_miss_o         = 1'b1;
                end
            end

            WAIT_GRANT: begin

                req_port_o.data_req = 1'b1;

                if (req_port_i.data_gnt) begin

                    tag_valid_n = 1'b1;
                    state_d     = PTE_LOOKUP;
                end
            end

            PTE_LOOKUP: begin

                if (data_rvalid_q) begin

                    if (pte.g)
                        global_mapping_n = 1'b1;

                    if (!pte.v || (!pte.r && pte.w))
                        state_d = PROPAGATE_ERROR;

                    else begin
                        state_d = IDLE;

                        if (pte.r || pte.x) begin

                            if (is_instr_ptw_q) begin

                                if (!pte.x || !pte.a)
                                  state_d = PROPAGATE_ERROR;
                                else
                                  itlb_update_o.valid = 1'b1;

                            end else begin

                                if (pte.a && (pte.r || (pte.x && mxr_i))) begin
                                  dtlb_update_o.valid = 1'b1;
                                end else begin
                                  state_d   = PROPAGATE_ERROR;
                                end

                                if (lsu_is_store_i && (!pte.w || !pte.d)) begin
                                    dtlb_update_o.valid = 1'b0;
                                    state_d   = PROPAGATE_ERROR;
                                end
                            end

                            if (ptw_lvl_q == LVL1 && pte.ppn[17:0] != '0) begin
                                state_d             = PROPAGATE_ERROR;
                                dtlb_update_o.valid = 1'b0;
                                itlb_update_o.valid = 1'b0;
                            end else if (ptw_lvl_q == LVL2 && pte.ppn[8:0] != '0) begin
                                state_d             = PROPAGATE_ERROR;
                                dtlb_update_o.valid = 1'b0;
                                itlb_update_o.valid = 1'b0;
                            end

                        end else begin

                            if (ptw_lvl_q == LVL1) begin

                                ptw_lvl_n  = LVL2;
                                ptw_pptr_n = {pte.ppn, vaddr_q[29:21], 3'b0};
                            end

                            if (ptw_lvl_q == LVL2) begin

                                ptw_lvl_n  = LVL3;
                                ptw_pptr_n = {pte.ppn, vaddr_q[20:12], 3'b0};
                            end

                            state_d = WAIT_GRANT;

                            if (ptw_lvl_q == LVL3) begin

                              ptw_lvl_n   = LVL3;
                              state_d = PROPAGATE_ERROR;
                            end
                        end
                    end
                end

            end

            PROPAGATE_ERROR: begin
                state_d     = IDLE;
                ptw_error_o = 1'b1;
            end

            WAIT_RVALID: begin
                if (data_rvalid_q)
                    state_d = IDLE;
            end
            default: begin
                state_d = IDLE;
            end
        endcase

        if (flush_i) begin

            if ((state_q == PTE_LOOKUP && !data_rvalid_q) || ((state_q == WAIT_GRANT) && req_port_i.data_gnt))
                state_d = WAIT_RVALID;
            else
                state_d = IDLE;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q            <= IDLE;
            is_instr_ptw_q     <= 1'b0;
            ptw_lvl_q          <= LVL1;
            tag_valid_q        <= 1'b0;
            tlb_update_asid_q  <= '0;
            vaddr_q            <= '0;
            ptw_pptr_q         <= '0;
            global_mapping_q   <= 1'b0;
            data_rdata_q       <= '0;
            data_rvalid_q      <= 1'b0;
        end else begin
            state_q            <= state_d;
            ptw_pptr_q         <= ptw_pptr_n;
            is_instr_ptw_q     <= is_instr_ptw_n;
            ptw_lvl_q          <= ptw_lvl_n;
            tag_valid_q        <= tag_valid_n;
            tlb_update_asid_q  <= tlb_update_asid_n;
            vaddr_q            <= vaddr_n;
            global_mapping_q   <= global_mapping_n;
            data_rdata_q       <= req_port_i.data_rdata;
            data_rvalid_q      <= req_port_i.data_rvalid;
        end
    end

endmodule
