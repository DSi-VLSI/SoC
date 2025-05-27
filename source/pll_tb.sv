module pll_tb;

  localparam int REF_DEV_WIDTH = 4;
  localparam int FB_DEV_WIDTH = 8;

  logic                     arst_ni;
  logic                     clk_ref_i;
  logic [REF_DEV_WIDTH-1:0] refdiv_i;
  logic [ FB_DEV_WIDTH-1:0] fbdiv_i;
  logic                     clk_o;
  logic                     locked_o;

  pll #(
      .REF_DEV_WIDTH(4),
      .FB_DEV_WIDTH (8)
  ) u_pll (
      .arst_ni,
      .clk_ref_i,
      .refdiv_i,
      .fbdiv_i,
      .clk_o,
      .locked_o
  );

  initial begin

    $dumpfile("pll_tb.vcd");
    $dumpvars(0, pll_tb);

    #100ns;

    arst_ni   <= '0;
    clk_ref_i <= '0;
    refdiv_i  <= '0;
    fbdiv_i   <= '0;

    #100ns;

    arst_ni <= '1;

    #100ns;

    fork
      forever begin
        clk_ref_i <= ~clk_ref_i;
        #5ns;
      end
    join_none

    #4us;

    refdiv_i <= 2;

    #4us;

    fbdiv_i <= 2;

    #4us;

    fbdiv_i <= 4;

    #4us;

    refdiv_i <= 1;

    #4us;

    $finish;

  end

endmodule
