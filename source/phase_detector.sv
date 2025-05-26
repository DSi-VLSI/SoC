module phase_detector (
    input  logic clk_ref_i,
    input  logic clk_pll_i,
    input  logic arst_ni,
    output logic freq_p_o,
    output logic freq_n_o
);

  logic comb_arst_ni;

  always_ff @(posedge clk_ref_i or negedge comb_arst_ni) begin
    if (~comb_arst_ni) begin
      freq_p_o <= '0;
    end else begin
      freq_p_o <= '1;
    end
  end

  always_ff @(posedge clk_pll_i or negedge comb_arst_ni) begin
    if (~comb_arst_ni) begin
      freq_n_o <= '0;
    end else begin
      freq_n_o <= '1;
    end
  end

  always_comb comb_arst_ni = ~(freq_p_o & freq_n_o) & arst_ni;

endmodule
