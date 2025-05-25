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
  always_comb clk_no = ~clk_o;

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

  ddr_reg #(
      .DATA_WIDTH(DIV_WIDTH)
  ) u_reg (
      .clk_i,
      .arst_ni,
      .en_i('1),
      .data_in_i(counter_n),
      .data_out_o(counter_q)
  );

  ddr_reg #(
      .DATA_WIDTH(1)
  ) clk_src (
      .clk_i,
      .arst_ni,
      .en_i(toggle_en),
      .data_in_i(clk_no),
      .data_out_o(clk_o)
  );

endmodule
