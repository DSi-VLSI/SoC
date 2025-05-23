module addr_decode #(

    parameter int unsigned NoIndices = 32'd0,

    parameter int unsigned NoRules   = 32'd0,

    parameter type         addr_t    = logic,

    parameter type         rule_t    = logic,

    parameter bit          Napot     = 0,

    parameter int unsigned IdxWidth  = cf_math_pkg::idx_width(NoIndices),

    parameter type         idx_t     = logic                             [IdxWidth-1:0]
) (

    input  addr_t               addr_i,

    input  rule_t [NoRules-1:0] addr_map_i,

    output idx_t                idx_o,

    output logic                dec_valid_o,

    output logic                dec_error_o,

    input  logic                en_default_idx_i,

    input  idx_t                default_idx_i
);

  addr_decode_dync #(
      .NoIndices(NoIndices),
      .NoRules  (NoRules),
      .addr_t   (addr_t),
      .rule_t   (rule_t),
      .Napot    (Napot)
  ) i_addr_decode_dync (
      .addr_i,
      .addr_map_i,
      .idx_o,
      .dec_valid_o,
      .dec_error_o,
      .en_default_idx_i,
      .default_idx_i,
      .config_ongoing_i(1'b0)
  );

endmodule
