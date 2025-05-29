module sr_latch (
    input  logic s_ni,
    input  logic r_ni,
    output logic q_o,
    output logic q_no
);

  always_comb q_o = ~(s_ni & q_no);
  always_comb q_no = ~(r_ni & q_o);

endmodule
