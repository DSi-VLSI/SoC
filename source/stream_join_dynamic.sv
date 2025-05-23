module stream_join_dynamic #(

  parameter int unsigned N_INP = 32'd0 
) (

  input  logic [N_INP-1:0] inp_valid_i,

  output logic [N_INP-1:0] inp_ready_o,

  input  logic [N_INP-1:0] sel_i,

  output logic             oup_valid_o,

  input  logic             oup_ready_i
);

  assign oup_valid_o = &(inp_valid_i | ~sel_i) && |sel_i;
  for (genvar i = 0; i < N_INP; i++) begin : gen_inp_ready
    assign inp_ready_o[i] = oup_valid_o & oup_ready_i & sel_i[i];
  end

endmodule
