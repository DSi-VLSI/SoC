module clk_div #(
    parameter int DIV_WIDTH = 4
) (
    input  logic                 arst_ni,
    input  logic [DIV_WIDTH-1:0] div_i,
    input  logic                 clk_i,
    output logic                 clk_o
);

  logic [DIV_WIDTH-1:0] counter_q;
  logic [DIV_WIDTH-1:0] counter_n;
  logic                 toggle_en;
  logic                 clk_no;

  always_comb toggle_en = (counter_q == '0);

  always_comb begin
    if (div_i == '0) begin
      counter_n = '0;
    end else begin
      counter_n = counter_q + 1;
      if (counter_n == div_i) begin
        counter_n = '0;
      end
    end
  end

  always @(clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      counter_q <= '0;
    end else begin
      counter_q <= counter_n;
    end
  end

  always @(clk_i or negedge arst_ni) begin
    if (~arst_ni) begin
      clk_o <= '0;
    end else begin
      if (toggle_en) begin
        clk_o <= ~clk_o;
      end
    end
  end

endmodule
