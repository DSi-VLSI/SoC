import ariane_pkg::*;module alu (
    input  logic            clk_i,            
    input  logic            rst_ni,           
    input  fu_data_t        fu_data_i,
    output logic     [63:0] result_o,
    output logic            alu_branch_res_o
);

  logic [63:0] operand_a_rev;
  logic [31:0] operand_a_rev32;
  logic [64:0] operand_b_neg;
  logic [65:0] adder_result_ext_o;
  logic        less;  

  generate
    genvar k;
    for (k = 0; k < 64; k++) assign operand_a_rev[k] = fu_data_i.operand_a[63-k];

    for (k = 0; k < 32; k++) assign operand_a_rev32[k] = fu_data_i.operand_a[31-k];
  endgenerate

  logic adder_op_b_negate;
  logic adder_z_flag;
  logic [64:0] adder_in_a, adder_in_b;
  logic [63:0] adder_result;

  always_comb begin
    adder_op_b_negate = 1'b0;

    unique case (fu_data_i.operator)

      EQ, NE, SUB, SUBW: adder_op_b_negate = 1'b1;

      default: ;
    endcase
  end

  assign adder_in_a         = {fu_data_i.operand_a, 1'b1};

  assign operand_b_neg      = {fu_data_i.operand_b, 1'b0} ^ {65{adder_op_b_negate}};
  assign adder_in_b         = operand_b_neg;

  assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
  assign adder_result       = adder_result_ext_o[64:1];
  assign adder_z_flag       = ~|adder_result;

  always_comb begin : branch_resolve

    alu_branch_res_o = 1'b1;
    case (fu_data_i.operator)
      EQ:       alu_branch_res_o = adder_z_flag;
      NE:       alu_branch_res_o = ~adder_z_flag;
      LTS, LTU: alu_branch_res_o = less;
      GES, GEU: alu_branch_res_o = ~less;
      default:  alu_branch_res_o = 1'b1;
    endcase
  end

  logic        shift_left;  
  logic        shift_arithmetic;

  logic [63:0] shift_amt;  
  logic [63:0] shift_op_a;  
  logic [31:0] shift_op_a32;  

  logic [63:0] shift_result;
  logic [31:0] shift_result32;

  logic [64:0] shift_right_result;
  logic [32:0] shift_right_result32;

  logic [63:0] shift_left_result;
  logic [31:0] shift_left_result32;

  assign shift_amt = fu_data_i.operand_b;

  assign shift_left = (fu_data_i.operator == SLL) | (fu_data_i.operator == SLLW);

  assign shift_arithmetic = (fu_data_i.operator == SRA) | (fu_data_i.operator == SRAW);

  logic [64:0] shift_op_a_64;
  logic [32:0] shift_op_a_32;

  assign shift_op_a           = shift_left ? operand_a_rev : fu_data_i.operand_a;
  assign shift_op_a32         = shift_left ? operand_a_rev32 : fu_data_i.operand_a[31:0];

  assign shift_op_a_64        = {shift_arithmetic & shift_op_a[63], shift_op_a};
  assign shift_op_a_32        = {shift_arithmetic & shift_op_a[31], shift_op_a32};

  assign shift_right_result   = $unsigned($signed(shift_op_a_64) >>> shift_amt[5:0]);

  assign shift_right_result32 = $unsigned($signed(shift_op_a_32) >>> shift_amt[4:0]);

  genvar j;
  generate
    for (j = 0; j < 64; j++) assign shift_left_result[j] = shift_right_result[63-j];

    for (j = 0; j < 32; j++) assign shift_left_result32[j] = shift_right_result32[31-j];

  endgenerate

  assign shift_result   = shift_left ? shift_left_result : shift_right_result[63:0];
  assign shift_result32 = shift_left ? shift_left_result32 : shift_right_result32[31:0];

  always_comb begin
    logic sgn;
    sgn = 1'b0;

    if ((fu_data_i.operator == SLTS) || (fu_data_i.operator == LTS) || (fu_data_i.operator == GES))
      sgn = 1'b1;

    less = ($signed({sgn & fu_data_i.operand_a[63], fu_data_i.operand_a}) <
            $signed({sgn & fu_data_i.operand_b[63], fu_data_i.operand_b}));
  end

  always_comb begin
    result_o = '0;

    unique case (fu_data_i.operator)

      ANDL: result_o = fu_data_i.operand_a & fu_data_i.operand_b;
      ORL:  result_o = fu_data_i.operand_a | fu_data_i.operand_b;
      XORL: result_o = fu_data_i.operand_a ^ fu_data_i.operand_b;

      ADD, SUB: result_o = adder_result;

      ADDW, SUBW: result_o = {{32{adder_result[31]}}, adder_result[31:0]};

      SLL, SRL, SRA: result_o = shift_result;

      SLLW, SRLW, SRAW: result_o = {{32{shift_result32[31]}}, shift_result32[31:0]};

      SLTS, SLTU: result_o = {63'b0, less};

      default: ;  
    endcase
  end
endmodule
