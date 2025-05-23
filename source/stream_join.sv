module stream_join #(

  parameter int unsigned N_INP = 32'd0 
) (

  input  logic  [N_INP-1:0] inp_valid_i,

  output logic  [N_INP-1:0] inp_ready_o,

  output logic              oup_valid_o,

  input  logic              oup_ready_i
);

  stream_join_dynamic #(
    .N_INP(N_INP)
  ) i_stream_join_dynamic (
    .inp_valid_i(inp_valid_i),
    .inp_ready_o(inp_ready_o),
    .sel_i      ({N_INP{1'b1}}),
    .oup_valid_o(oup_valid_o),
    .oup_ready_i(oup_ready_i)
  );

endmodule
