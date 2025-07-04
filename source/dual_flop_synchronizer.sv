module dual_flop_synchronizer #(
    parameter bit FIRST_FF_EDGE_POSEDGED = 0,
    parameter bit LAST_FF_EDGE_POSEDGED  = 0
) (
    input  logic arst_ni,
    input  logic clk_i,
    input  logic en_i,
    input  logic d_i,
    output logic q_o
);

  logic dff0_clk_in;
  logic dff1_clk_in;
  logic en_intermediate;
  logic q_intermediate;

  assign dff0_clk_in = FIRST_FF_EDGE_POSEDGED ? clk_i : ~clk_i;
  assign dff1_clk_in = LAST_FF_EDGE_POSEDGED ? clk_i : ~clk_i;

  always @(posedge dff0_clk_in or negedge arst_ni) begin
    if (~arst_ni) begin
      en_intermediate <= '0;
      q_intermediate  <= '0;
    end else begin
      en_intermediate <= en_i;
      q_intermediate  <= d_i;
    end
  end

  always @(posedge dff1_clk_in or negedge arst_ni) begin
    if (~arst_ni) begin
      q_o <= '0;
    end else begin
      if (en_intermediate) q_o <= q_intermediate;
    end
  end

endmodule
