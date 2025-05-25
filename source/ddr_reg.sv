module ddr_reg #(
    parameter int DATA_WIDTH = 8
) (
    input  logic                  clk_i,
    input  logic                  arst_ni,
    input  logic                  en_i,
    input  logic [DATA_WIDTH-1:0] data_in_i,
    output logic [DATA_WIDTH-1:0] data_out_o
);

  logic [DATA_WIDTH-1:0] pos_edge_data_q;
  logic [DATA_WIDTH-1:0] neg_edge_data_q;

  always_ff @(posedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      pos_edge_data_q <= '0;
    end else if (en_i) begin
      pos_edge_data_q <= data_in_i;
    end else begin
      pos_edge_data_q <= neg_edge_data_q;
    end
  end

  always_ff @(negedge clk_i or negedge arst_ni) begin
    if (!arst_ni) begin
      neg_edge_data_q <= '0;
    end else if (en_i) begin
      neg_edge_data_q <= data_in_i;
    end else begin
      neg_edge_data_q <= pos_edge_data_q;
    end
  end

  assign data_out_o = clk_i ? pos_edge_data_q : neg_edge_data_q;

endmodule
