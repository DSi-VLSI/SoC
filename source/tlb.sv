import ariane_pkg::*;module tlb #(
      parameter int unsigned TLB_ENTRIES = 4,
      parameter int unsigned ASID_WIDTH  = 1
  )(
    input  logic                    clk_i,    
    input  logic                    rst_ni,   
    input  logic                    flush_i,  

    input  tlb_update_t             update_i,

    input  logic                    lu_access_i,
    input  logic [ASID_WIDTH-1:0]   lu_asid_i,
    input  logic [63:0]             lu_vaddr_i,
    output riscv_pkg::pte_t             lu_content_o,
    output logic                    lu_is_2M_o,
    output logic                    lu_is_1G_o,
    output logic                    lu_hit_o
);

    struct packed {
      logic [ASID_WIDTH-1:0] asid;
      logic [8:0]            vpn2;
      logic [8:0]            vpn1;
      logic [8:0]            vpn0;
      logic                  is_2M;
      logic                  is_1G;
      logic                  valid;
    } [TLB_ENTRIES-1:0] tags_q, tags_n;

    riscv_pkg::pte_t [TLB_ENTRIES-1:0] content_q, content_n;
    logic [8:0] vpn0, vpn1, vpn2;
    logic [TLB_ENTRIES-1:0] lu_hit;     
    logic [TLB_ENTRIES-1:0] replace_en; 

    always_comb begin : translation
        vpn0 = lu_vaddr_i[20:12];
        vpn1 = lu_vaddr_i[29:21];
        vpn2 = lu_vaddr_i[38:30];

        lu_hit       = '{default: 0};
        lu_hit_o     = 1'b0;
        lu_content_o = '{default: 0};
        lu_is_1G_o   = 1'b0;
        lu_is_2M_o   = 1'b0;

        for (int unsigned i = 0; i < TLB_ENTRIES; i++) begin

            if (tags_q[i].valid && lu_asid_i == tags_q[i].asid && vpn2 == tags_q[i].vpn2) begin

                if (tags_q[i].is_1G) begin
                    lu_is_1G_o = 1'b1;
                    lu_content_o = content_q[i];
                    lu_hit_o   = 1'b1;
                    lu_hit[i]  = 1'b1;

                end else if (vpn1 == tags_q[i].vpn1) begin

                    if (tags_q[i].is_2M || vpn0 == tags_q[i].vpn0) begin
                        lu_is_2M_o   = tags_q[i].is_2M;
                        lu_content_o = content_q[i];
                        lu_hit_o     = 1'b1;
                        lu_hit[i]    = 1'b1;
                    end
                end
            end
        end
    end

    always_comb begin : update_flush
        tags_n    = tags_q;
        content_n = content_q;

        for (int unsigned i = 0; i < TLB_ENTRIES; i++) begin
            if (flush_i) begin

                if (lu_asid_i == 1'b0) 
                    tags_n[i].valid = 1'b0;
                else if (lu_asid_i == tags_q[i].asid) 
                    tags_n[i].valid = 1'b0;

            end else if (update_i.valid & replace_en[i]) begin

                tags_n[i] = '{
                    asid:  update_i.asid,
                    vpn2:  update_i.vpn [26:18],
                    vpn1:  update_i.vpn [17:9],
                    vpn0:  update_i.vpn [8:0],
                    is_1G: update_i.is_1G,
                    is_2M: update_i.is_2M,
                    valid: 1'b1
                };

                content_n[i] = update_i.content;
            end
        end
    end

    logic[2*(TLB_ENTRIES-1)-1:0] plru_tree_q, plru_tree_n;
    always_comb begin : plru_replacement
        plru_tree_n = plru_tree_q;

        for (int unsigned i = 0; i < TLB_ENTRIES; i++) begin
            automatic int unsigned idx_base, shift, new_index;

            if (lu_hit[i] & lu_access_i) begin

                for (int unsigned lvl = 0; lvl < $clog2(TLB_ENTRIES); lvl++) begin
                  idx_base = $unsigned((2**lvl)-1);

                  shift = $clog2(TLB_ENTRIES) - lvl;

                  new_index =  ~((i >> (shift-1)) & 32'b1);
                  plru_tree_n[idx_base + (i >> shift)] = new_index[0];
                end
            end
        end

        for (int unsigned i = 0; i < TLB_ENTRIES; i += 1) begin
            automatic logic en;
            automatic int unsigned idx_base, shift, new_index;
            en = 1'b1;
            for (int unsigned lvl = 0; lvl < $clog2(TLB_ENTRIES); lvl++) begin
                idx_base = $unsigned((2**lvl)-1);

                shift = $clog2(TLB_ENTRIES) - lvl;

                new_index =  (i >> (shift-1)) & 32'b1;
                if (new_index[0]) begin
                  en &= plru_tree_q[idx_base + (i>>shift)];
                end else begin
                  en &= ~plru_tree_q[idx_base + (i>>shift)];
                end
            end
            replace_en[i] = en;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            tags_q      <= '{default: 0};
            content_q   <= '{default: 0};
            plru_tree_q <= '{default: 0};
        end else begin
            tags_q      <= tags_n;
            content_q   <= content_n;
            plru_tree_q <= plru_tree_n;
        end
    end

endmodule
