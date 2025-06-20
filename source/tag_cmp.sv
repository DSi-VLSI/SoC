module tag_cmp #(
    parameter int unsigned NR_PORTS         = 3,
    parameter int unsigned ADDR_WIDTH       = 64,
    parameter type         l_data_t         = std_cache_pkg::cache_line_t,
    parameter type         l_be_t           = std_cache_pkg::cl_be_t,
    parameter int unsigned DCACHE_SET_ASSOC = 8
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic    [        NR_PORTS-1:0][            DCACHE_SET_ASSOC-1:0] req_i,
    output logic    [        NR_PORTS-1:0]                                   gnt_o,
    input  logic    [        NR_PORTS-1:0][                  ADDR_WIDTH-1:0] addr_i,
    input  l_data_t [        NR_PORTS-1:0]                                   wdata_i,
    input  logic    [        NR_PORTS-1:0]                                   we_i,
    input  l_be_t   [        NR_PORTS-1:0]                                   be_i,
    output l_data_t [DCACHE_SET_ASSOC-1:0]                                   rdata_o,
    input  logic    [        NR_PORTS-1:0][ariane_pkg::DCACHE_TAG_WIDTH-1:0] tag_i,
    output logic    [DCACHE_SET_ASSOC-1:0]                                   hit_way_o,

    output logic    [DCACHE_SET_ASSOC-1:0] req_o,
    output logic    [      ADDR_WIDTH-1:0] addr_o,
    output l_data_t                        wdata_o,
    output logic                           we_o,
    output l_be_t                          be_o,
    input  l_data_t [DCACHE_SET_ASSOC-1:0] rdata_i
);

  assign rdata_o = rdata_i;

  logic [NR_PORTS-1:0] id_d, id_q;
  logic [ariane_pkg::DCACHE_TAG_WIDTH-1:0] sel_tag;

  always_comb begin : tag_sel
    sel_tag = '0;
    for (int unsigned i = 0; i < NR_PORTS; i++) if (id_q[i]) sel_tag = tag_i[i];
  end

  for (genvar j = 0; j < DCACHE_SET_ASSOC; j++) begin : tag_cmp
    assign hit_way_o[j] = (sel_tag == rdata_i[j].tag) ? rdata_i[j].valid : 1'b0;
  end

  always_comb begin

    gnt_o   = '0;
    id_d    = '0;
    wdata_o = '0;
    req_o   = '0;
    addr_o  = '0;
    be_o    = '0;
    we_o    = '0;

    for (int unsigned i = 0; i < NR_PORTS; i++) begin
      req_o    = req_i[i];
      id_d     = (1'b1 << i);
      gnt_o[i] = 1'b1;
      addr_o   = addr_i[i];
      be_o     = be_i[i];
      we_o     = we_i[i];
      wdata_o  = wdata_i[i];

      if (req_i[i]) break;
    end

  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      id_q <= 0;
    end else begin
      id_q <= id_d;
    end
  end

endmodule
