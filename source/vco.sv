module vco (
    input  logic arst_ni,      // Asynchronous active low reset
    input  logic freq_incr_i,  // increase frequency
    input  logic freq_decr_i,  // decrease frequency
    input  logic stable_cfg,   // stable configuration signal
    output logic clk_o,        // output clock signal
    output logic locked_o      // output locked signal
);

  localparam realtime MIN_CLK_HALF_PERIOD = 50ps;
  localparam realtime MAX_CLK_HALF_PERIOD = 0.5ms;

  realtime clk_half_period;
  realtime last_clk_tick;

  bit incr_ok;
  bit decr_ok;

  event update;

  logic locked_internal;

  logic [15:0] locked_array;

  always @(posedge freq_incr_i) begin
    realtime time_record;
    if (arst_ni) begin
      time_record = $realtime;
      @(negedge freq_incr_i);
      time_record = $realtime - time_record;
      if (time_record < MIN_CLK_HALF_PERIOD) begin
        incr_ok = '1;
      end else begin
        incr_ok = '0;
      end
    end
  end

  always @(posedge freq_decr_i) begin
    realtime time_record;
    if (arst_ni) begin
      time_record = $realtime;
      @(negedge freq_decr_i);
      time_record = $realtime - time_record;
      if (time_record < MIN_CLK_HALF_PERIOD) begin
        decr_ok = '1;
      end else begin
        decr_ok = '0;
      end
    end
  end

  always @(negedge arst_ni) begin
    ->update;
  end

  always #10ps begin
    ->update;
  end

  always @(update) begin
    if (~arst_ni) begin
      incr_ok = '0;
      decr_ok = '0;
      clk_o <= '0;
      last_clk_tick <= $realtime;
      clk_half_period <= 1us;
    end else begin
      if (freq_incr_i & ~freq_decr_i) clk_half_period = clk_half_period - 10ps;
      if (freq_decr_i & ~freq_incr_i) clk_half_period = clk_half_period + 10ps;
      if (clk_half_period < MIN_CLK_HALF_PERIOD) clk_half_period = MIN_CLK_HALF_PERIOD;
      if (clk_half_period > MAX_CLK_HALF_PERIOD) clk_half_period = MAX_CLK_HALF_PERIOD;
      if (($realtime) >= (last_clk_tick + clk_half_period)) begin
        clk_o <= ~clk_o;
        last_clk_tick <= $realtime;
      end
    end
  end

  assign locked_internal = arst_ni & decr_ok & incr_ok & stable_cfg;

  always_ff @(posedge clk_o or negedge locked_internal) begin
    if (~locked_internal) begin
      locked_array <= '0;
    end else begin
      locked_array <= {locked_array[14:0], 1'b1};
    end
  end

  assign locked_o = locked_array[15];

endmodule
