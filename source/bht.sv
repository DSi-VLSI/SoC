module bht #(
    parameter int unsigned NR_ENTRIES = 1024
) (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,
    input logic debug_mode_i,

    input  logic                        [63:0] vpc_i,
    input  ariane_pkg::bht_update_t            bht_update_i,
    output ariane_pkg::bht_prediction_t        bht_prediction_o
);
  localparam OFFSET = 2;
  localparam ANTIALIAS_BITS = 8;

  localparam PREDICTION_BITS = $clog2(NR_ENTRIES) + OFFSET;

  struct packed {
    logic       valid;
    logic [1:0] saturation_counter;
  }
      bht_d[NR_ENTRIES-1:0], bht_q[NR_ENTRIES-1:0];

  logic [$clog2(NR_ENTRIES)-1:0] index, update_pc;
  logic [1:0] saturation_counter;

  assign index                           = vpc_i[PREDICTION_BITS-1:OFFSET];
  assign update_pc                       = bht_update_i.pc[PREDICTION_BITS-1:OFFSET];

  assign bht_prediction_o.valid          = bht_q[index].valid;
  assign bht_prediction_o.taken          = bht_q[index].saturation_counter == 2'b10;
  assign bht_prediction_o.strongly_taken = (bht_q[index].saturation_counter == 2'b11);
  always_comb begin : update_bht
    bht_d = bht_q;
    saturation_counter = bht_q[update_pc].saturation_counter;

    if (bht_update_i.valid && !debug_mode_i) begin
      bht_d[update_pc].valid = 1'b1;

      if (saturation_counter == 2'b11) begin

        if (~bht_update_i.taken) bht_d[update_pc].saturation_counter = saturation_counter - 1;

      end else if (saturation_counter == 2'b00) begin

        if (bht_update_i.taken) bht_d[update_pc].saturation_counter = saturation_counter + 1;
      end else begin
        if (bht_update_i.taken) bht_d[update_pc].saturation_counter = saturation_counter + 1;
        else bht_d[update_pc].saturation_counter = saturation_counter - 1;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      for (int unsigned i = 0; i < NR_ENTRIES; i++) bht_q[i] <= '0;
    end else begin

      if (flush_i) begin
        for (int i = 0; i < NR_ENTRIES; i++) begin
          bht_q[i].valid <= 1'b0;
          bht_q[i].saturation_counter <= 2'b10;
        end
      end else begin
        bht_q <= bht_d;
      end
    end
  end
endmodule
