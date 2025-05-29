module edge_detector (
    input  logic signal_i,
    output logic edge_o
);

  always @(signal_i) begin
    edge_o = '1;
    edge_o = '0;
  end

endmodule
