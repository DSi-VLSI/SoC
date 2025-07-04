

module fpnew_classifier #(
    parameter fpnew_pkg::fp_format_e FpFormat    = fpnew_pkg::fp_format_e'(0),
    parameter int unsigned           NumOperands = 1,

    localparam int unsigned WIDTH = fpnew_pkg::fp_width(FpFormat)
) (
    input  logic                [NumOperands-1:0][WIDTH-1:0] operands_i,
    input  logic                [NumOperands-1:0]            is_boxed_i,
    output fpnew_pkg::fp_info_t [NumOperands-1:0]            info_o
);

  localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(FpFormat);
  localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(FpFormat);

  typedef struct packed {
    logic                sign;
    logic [EXP_BITS-1:0] exponent;
    logic [MAN_BITS-1:0] mantissa;
  } fp_t;

  for (genvar op = 0; op < int'(NumOperands); op++) begin : gen_num_values

    fp_t  value;
    logic is_boxed;
    logic is_normal;
    logic is_inf;
    logic is_nan;
    logic is_signalling;
    logic is_quiet;
    logic is_zero;
    logic is_subnormal;

    always_comb begin : classify_input
      value                    = operands_i[op];
      is_boxed                 = is_boxed_i[op];
      is_normal                = is_boxed && (value.exponent != '0) && (value.exponent != '1);
      is_zero                  = is_boxed && (value.exponent == '0) && (value.mantissa == '0);
      is_subnormal             = is_boxed && (value.exponent == '0) && !is_zero;
      is_inf                   = is_boxed && ((value.exponent == '1) && (value.mantissa == '0));
      is_nan                   = !is_boxed || ((value.exponent == '1) && (value.mantissa != '0));
      is_signalling            = is_boxed && is_nan && (value.mantissa[MAN_BITS-1] == 1'b0);
      is_quiet                 = is_nan && !is_signalling;

      info_o[op].is_normal     = is_normal;
      info_o[op].is_subnormal  = is_subnormal;
      info_o[op].is_zero       = is_zero;
      info_o[op].is_inf        = is_inf;
      info_o[op].is_nan        = is_nan;
      info_o[op].is_signalling = is_signalling;
      info_o[op].is_quiet      = is_quiet;
      info_o[op].is_boxed      = is_boxed;
    end
  end
endmodule
