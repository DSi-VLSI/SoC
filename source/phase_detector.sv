module phase_detector (
    input  logic arst_ni,
    input  logic clk_ref_i,
    input  logic clk_pll_i,
    output logic freq_incr_o,
    output logic freq_decr_o
);

  logic clk_ref_posedge;
  logic clk_ref_negedge;

  logic clk_pll_posedge;
  logic clk_pll_negedge;

  logic comb_arst_ni;

  `define PHASE_DETECTOR_FLIPFLOP_GENENRATOR(__CLK__, __EDGE__)                  \
  always_ff @(``__EDGE__``edge clk_``__CLK__``_i or negedge comb_arst_ni) begin  \
    if (~comb_arst_ni) begin                                                     \
      clk_``__CLK__``_``__EDGE__``edge <= '0;                                    \
    end else begin                                                               \
      clk_``__CLK__``_``__EDGE__``edge <= '1;                                    \
    end                                                                          \
  end                                                                            \


  `PHASE_DETECTOR_FLIPFLOP_GENENRATOR(ref, pos)
  `PHASE_DETECTOR_FLIPFLOP_GENENRATOR(ref, neg)
  `PHASE_DETECTOR_FLIPFLOP_GENENRATOR(pll, pos)
  `PHASE_DETECTOR_FLIPFLOP_GENENRATOR(pll, neg)


  `undef PHASE_DETECTOR_FLIPFLOP_GENENRATOR

  always_comb
    comb_arst_ni = arst_ni & (~(
                                (clk_ref_posedge & clk_pll_posedge) |
                                (clk_ref_negedge & clk_pll_negedge)
                              ));

  always_comb freq_incr_o = clk_ref_posedge | clk_ref_negedge;
  always_comb freq_decr_o = clk_pll_posedge | clk_pll_negedge;

endmodule
