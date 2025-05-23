module addr_decode_dync #(

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

    input  idx_t                default_idx_i,

    input  logic                config_ongoing_i
);

  logic [NoRules-1:0] matched_rules;  

  always_comb begin

    matched_rules = '0;
    dec_valid_o   = 1'b0;
    dec_error_o   = (en_default_idx_i) ? 1'b0 : 1'b1;
    idx_o         = (en_default_idx_i) ? default_idx_i : '0;

    for (int unsigned i = 0; i < NoRules; i++) begin
      if (
        !Napot && (addr_i >= addr_map_i[i].start_addr) &&
        ((addr_i < addr_map_i[i].end_addr) || (addr_map_i[i].end_addr == '0)) ||
        Napot && (addr_map_i[i].start_addr & addr_map_i[i].end_addr) ==
                 (addr_i & addr_map_i[i].end_addr)
      ) begin
        matched_rules[i] = ~config_ongoing_i;
        dec_valid_o      = ~config_ongoing_i;
        dec_error_o      = 1'b0;
        idx_o            = config_ongoing_i ? default_idx_i : idx_t'(addr_map_i[i].idx);
      end
    end
  end

endmodule
