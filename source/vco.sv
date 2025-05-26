module vco (
    input  logic arst_ni,    // Asynchronous active low reset
    input  logic freq_incr,  // increase frequency
    input  logic freq_decr,  // decrease frequency
    output logic clk_o       // output clock signal
);

  localparam realtime MIN_CLK_PERIOD_CYCLES = 100ps;
  localparam realtime MAX_CLK_PERIOD_CYCLES = 1ms;

endmodule
