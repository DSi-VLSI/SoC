module edge_detector_tb;

  logic signal_i;
  logic edge_o;

  edge_detector u_ed (
      .signal_i,
      .edge_o
  );

  initial begin
    $dumpfile("edge_detector_tb.vcd");
    $dumpvars;

    fork
      forever begin
        signal_i <= '1;
        #100ns;
        signal_i <= '0;
        #100ns;
      end
      forever begin
        @(posedge edge_o);
        $display("EDGE AT: %0t", $realtime);
      end
    join_none

    repeat (10) @(posedge signal_i);

    $finish;

  end

endmodule
