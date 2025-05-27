module pll #(
    parameter int REF_DEV_WIDTH = 4,  // Reference device width
    parameter int FB_DEV_WIDTH  = 8   // Feedback device width
) (
    input  logic                     arst_ni,    // Asynchronous active low reset
    input  logic                     clk_ref_i,  // Reference clock input
    input  logic [REF_DEV_WIDTH-1:0] refdiv_i,   // Reference clock input
    input  logic [ FB_DEV_WIDTH-1:0] fbdiv_i,    // Feedback clock input
    output logic                     clk_o,      // Output clock signal
    output logic                     locked_o    // Output locked signal
);

  logic divided_clk_ref;
  logic divided_clk_fb;

  logic freq_incr;
  logic freq_decr;

  logic stable_cfg;

  logic [REF_DEV_WIDTH-1:0] refdiv_q;
  logic [FB_DEV_WIDTH-1:0] fbdiv_q;

  always_ff @(negedge clk_o or negedge arst_ni) begin
    if (~arst_ni) begin
      refdiv_q <= '0;
      fbdiv_q  <= '0;
    end else begin
      refdiv_q <= refdiv_i;
      fbdiv_q  <= fbdiv_i;
    end
  end

  assign stable_cfg = (refdiv_q == refdiv_i) & (fbdiv_q == fbdiv_i);

  clk_div #(
      .DIV_WIDTH(REF_DEV_WIDTH)
  ) u_ref_dev (
      .arst_ni(arst_ni),
      .div_i  (refdiv_i),
      .clk_i  (clk_ref_i),
      .clk_o  (divided_clk_ref)
  );

  clk_div #(
      .DIV_WIDTH(FB_DEV_WIDTH)
  ) u_fb_dev (
      .arst_ni(arst_ni),
      .div_i  (fbdiv_i),
      .clk_i  (clk_o),
      .clk_o  (divided_clk_fb)
  );

  phase_detector u_pd (
      .arst_ni    (arst_ni),
      .clk_ref_i  (divided_clk_ref),
      .clk_pll_i  (divided_clk_fb),
      .freq_incr_o(freq_incr),
      .freq_decr_o(freq_decr)
  );

  vco u_vco (
      .arst_ni(arst_ni),
      .freq_incr_i(freq_incr),
      .freq_decr_i(freq_decr),
      .stable_cfg(stable_cfg),
      .clk_o(clk_o),
      .locked_o(locked_o)
  );

endmodule
