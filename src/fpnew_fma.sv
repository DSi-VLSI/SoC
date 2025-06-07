














`include "common_cells/registers.svh"

module fpnew_fma #(
  parameter fpnew_pkg::fp_format_e   FpFormat    = fpnew_pkg::fp_format_e'(0),
  parameter int unsigned             NumPipeRegs = 0,
  parameter fpnew_pkg::pipe_config_t PipeConfig  = fpnew_pkg::BEFORE,
  parameter type                     TagType     = logic,
  parameter type                     AuxType     = logic,

  localparam int unsigned WIDTH = fpnew_pkg::fp_width(FpFormat) 
) (
  input logic                      clk_i,
  input logic                      rst_ni,
  
  input logic [2:0][WIDTH-1:0]     operands_i, 
  input logic [2:0]                is_boxed_i, 
  input fpnew_pkg::roundmode_e     rnd_mode_i,
  input fpnew_pkg::operation_e     op_i,
  input logic                      op_mod_i,
  input TagType                    tag_i,
  input logic                      mask_i,
  input AuxType                    aux_i,
  
  input  logic                     in_valid_i,
  output logic                     in_ready_o,
  input  logic                     flush_i,
  
  output logic [WIDTH-1:0]         result_o,
  output fpnew_pkg::status_t       status_o,
  output logic                     extension_bit_o,
  output TagType                   tag_o,
  output logic                     mask_o,
  output AuxType                   aux_o,
  
  output logic                     out_valid_o,
  input  logic                     out_ready_i,
  
  output logic                     busy_o
);

  
  
  
  localparam int unsigned EXP_BITS = fpnew_pkg::exp_bits(FpFormat);
  localparam int unsigned MAN_BITS = fpnew_pkg::man_bits(FpFormat);
  localparam int unsigned BIAS     = fpnew_pkg::bias(FpFormat);
  
  localparam int unsigned PRECISION_BITS = MAN_BITS + 1;
  
  localparam int unsigned LOWER_SUM_WIDTH  = 2 * PRECISION_BITS + 3;
  localparam int unsigned LZC_RESULT_WIDTH = $clog2(LOWER_SUM_WIDTH);
  
  
  
  localparam int unsigned EXP_WIDTH = unsigned'(fpnew_pkg::maximum(EXP_BITS + 2, LZC_RESULT_WIDTH));
  
  localparam int unsigned SHIFT_AMOUNT_WIDTH = $clog2(3 * PRECISION_BITS + 5);
  
  localparam NUM_INP_REGS = PipeConfig == fpnew_pkg::BEFORE
                            ? NumPipeRegs
                            : (PipeConfig == fpnew_pkg::DISTRIBUTED
                               ? ((NumPipeRegs + 1) / 3) 
                               : 0); 
  localparam NUM_MID_REGS = PipeConfig == fpnew_pkg::INSIDE
                          ? NumPipeRegs
                          : (PipeConfig == fpnew_pkg::DISTRIBUTED
                             ? ((NumPipeRegs + 2) / 3) 
                             : 0); 
  localparam NUM_OUT_REGS = PipeConfig == fpnew_pkg::AFTER
                            ? NumPipeRegs
                            : (PipeConfig == fpnew_pkg::DISTRIBUTED
                               ? (NumPipeRegs / 3) 
                               : 0); 

  
  
  
  typedef struct packed {
    logic                sign;
    logic [EXP_BITS-1:0] exponent;
    logic [MAN_BITS-1:0] mantissa;
  } fp_t;

  
  
  
  
  logic                  [0:NUM_INP_REGS][2:0][WIDTH-1:0] inp_pipe_operands_q;
  logic                  [0:NUM_INP_REGS][2:0]            inp_pipe_is_boxed_q;
  fpnew_pkg::roundmode_e [0:NUM_INP_REGS]                 inp_pipe_rnd_mode_q;
  fpnew_pkg::operation_e [0:NUM_INP_REGS]                 inp_pipe_op_q;
  logic                  [0:NUM_INP_REGS]                 inp_pipe_op_mod_q;
  TagType                [0:NUM_INP_REGS]                 inp_pipe_tag_q;
  logic                  [0:NUM_INP_REGS]                 inp_pipe_mask_q;
  AuxType                [0:NUM_INP_REGS]                 inp_pipe_aux_q;
  logic                  [0:NUM_INP_REGS]                 inp_pipe_valid_q;
  
  logic [0:NUM_INP_REGS] inp_pipe_ready;

  
  assign inp_pipe_operands_q[0] = operands_i;
  assign inp_pipe_is_boxed_q[0] = is_boxed_i;
  assign inp_pipe_rnd_mode_q[0] = rnd_mode_i;
  assign inp_pipe_op_q[0]       = op_i;
  assign inp_pipe_op_mod_q[0]   = op_mod_i;
  assign inp_pipe_tag_q[0]      = tag_i;
  assign inp_pipe_mask_q[0]     = mask_i;
  assign inp_pipe_aux_q[0]      = aux_i;
  assign inp_pipe_valid_q[0]    = in_valid_i;
  
  assign in_ready_o = inp_pipe_ready[0];
  
  for (genvar i = 0; i < NUM_INP_REGS; i++) begin : gen_input_pipeline
    
    logic reg_ena;
    
    
    
    assign inp_pipe_ready[i] = inp_pipe_ready[i+1] | ~inp_pipe_valid_q[i+1];
    
    `FFLARNC(inp_pipe_valid_q[i+1], inp_pipe_valid_q[i], inp_pipe_ready[i], flush_i, 1'b0, clk_i, rst_ni)
    
    assign reg_ena = inp_pipe_ready[i] & inp_pipe_valid_q[i];
    
    `FFL(inp_pipe_operands_q[i+1], inp_pipe_operands_q[i], reg_ena, '0)
    `FFL(inp_pipe_is_boxed_q[i+1], inp_pipe_is_boxed_q[i], reg_ena, '0)
    `FFL(inp_pipe_rnd_mode_q[i+1], inp_pipe_rnd_mode_q[i], reg_ena, fpnew_pkg::RNE)
    `FFL(inp_pipe_op_q[i+1],       inp_pipe_op_q[i],       reg_ena, fpnew_pkg::FMADD)
    `FFL(inp_pipe_op_mod_q[i+1],   inp_pipe_op_mod_q[i],   reg_ena, '0)
    `FFL(inp_pipe_tag_q[i+1],      inp_pipe_tag_q[i],      reg_ena, TagType'('0))
    `FFL(inp_pipe_mask_q[i+1],     inp_pipe_mask_q[i],     reg_ena, '0)
    `FFL(inp_pipe_aux_q[i+1],      inp_pipe_aux_q[i],      reg_ena, AuxType'('0))
  end

  
  
  
  fpnew_pkg::fp_info_t [2:0] info_q;

  
  fpnew_classifier #(
    .FpFormat    ( FpFormat ),
    .NumOperands ( 3        )
    ) i_class_inputs (
    .operands_i ( inp_pipe_operands_q[NUM_INP_REGS] ),
    .is_boxed_i ( inp_pipe_is_boxed_q[NUM_INP_REGS] ),
    .info_o     ( info_q                            )
  );

  fp_t                 operand_a, operand_b, operand_c;
  fpnew_pkg::fp_info_t info_a,    info_b,    info_c;

  
  
  
  
  
  
  
  
  
  
  
  
  always_comb begin : op_select

    
    operand_a = inp_pipe_operands_q[NUM_INP_REGS][0];
    operand_b = inp_pipe_operands_q[NUM_INP_REGS][1];
    operand_c = inp_pipe_operands_q[NUM_INP_REGS][2];
    info_a    = info_q[0];
    info_b    = info_q[1];
    info_c    = info_q[2];

    
    operand_c.sign = operand_c.sign ^ inp_pipe_op_mod_q[NUM_INP_REGS];

    unique case (inp_pipe_op_q[NUM_INP_REGS])
      fpnew_pkg::FMADD:  ; 
      fpnew_pkg::FNMSUB: operand_a.sign = ~operand_a.sign; 
      fpnew_pkg::ADD: begin 
        operand_a = '{sign: 1'b0, exponent: BIAS, mantissa: '0};
        info_a    = '{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0}; 
      end
      fpnew_pkg::MUL: begin 
        if (inp_pipe_rnd_mode_q[NUM_INP_REGS] == fpnew_pkg::RDN)
          operand_c = '{sign: 1'b0, exponent: '0, mantissa: '0};
        else
          operand_c = '{sign: 1'b1, exponent: '0, mantissa: '0};
        info_c    = '{is_zero: 1'b1, is_boxed: 1'b1, default: 1'b0}; 
      end
      default: begin 
        operand_a  = '{default: fpnew_pkg::DONT_CARE};
        operand_b  = '{default: fpnew_pkg::DONT_CARE};
        operand_c  = '{default: fpnew_pkg::DONT_CARE};
        info_a     = '{default: fpnew_pkg::DONT_CARE};
        info_b     = '{default: fpnew_pkg::DONT_CARE};
        info_c     = '{default: fpnew_pkg::DONT_CARE};
      end
    endcase
  end

  
  
  
  logic any_operand_inf;
  logic any_operand_nan;
  logic signalling_nan;
  logic effective_subtraction;
  logic tentative_sign;

  
  assign any_operand_inf = (| {info_a.is_inf,        info_b.is_inf,        info_c.is_inf});
  assign any_operand_nan = (| {info_a.is_nan,        info_b.is_nan,        info_c.is_nan});
  assign signalling_nan  = (| {info_a.is_signalling, info_b.is_signalling, info_c.is_signalling});
  
  assign effective_subtraction = operand_a.sign ^ operand_b.sign ^ operand_c.sign;
  
  assign tentative_sign = operand_a.sign ^ operand_b.sign;

  
  
  
  fp_t                special_result;
  fpnew_pkg::status_t special_status;
  logic               result_is_special;

  always_comb begin : special_cases
    
    special_result    = '{sign: 1'b0, exponent: '1, mantissa: 2**(MAN_BITS-1)}; 
    special_status    = '0;
    result_is_special = 1'b0;

    
    
    
    
    if ((info_a.is_inf && info_b.is_zero) || (info_a.is_zero && info_b.is_inf)) begin
      result_is_special = 1'b1; 
      special_status.NV = 1'b1; 
    
    end else if (any_operand_nan) begin
      result_is_special = 1'b1;           
      special_status.NV = signalling_nan; 
    
    end else if (any_operand_inf) begin
      result_is_special = 1'b1; 
      
      if ((info_a.is_inf || info_b.is_inf) && info_c.is_inf && effective_subtraction)
        special_status.NV = 1'b1; 
      
      else if (info_a.is_inf || info_b.is_inf) begin
        
        special_result    = '{sign: operand_a.sign ^ operand_b.sign, exponent: '1, mantissa: '0};
      
      end else if (info_c.is_inf) begin
        
        special_result    = '{sign: operand_c.sign, exponent: '1, mantissa: '0};
      end
    end
  end

  
  
  
  logic signed [EXP_WIDTH-1:0] exponent_a, exponent_b, exponent_c;
  logic signed [EXP_WIDTH-1:0] exponent_addend, exponent_product, exponent_difference;
  logic signed [EXP_WIDTH-1:0] tentative_exponent;

  
  assign exponent_a = signed'({1'b0, operand_a.exponent});
  assign exponent_b = signed'({1'b0, operand_b.exponent});
  assign exponent_c = signed'({1'b0, operand_c.exponent});

  
  
  assign exponent_addend = signed'(exponent_c + $signed({1'b0, ~info_c.is_normal})); 
  
  assign exponent_product = (info_a.is_zero || info_b.is_zero)
                            ? 2 - signed'(BIAS) 
                            : signed'(exponent_a + info_a.is_subnormal
                                      + exponent_b + info_b.is_subnormal
                                      - signed'(BIAS));
  
  assign exponent_difference = exponent_addend - exponent_product;
  
  assign tentative_exponent = (exponent_difference > 0) ? exponent_addend : exponent_product;

  
  logic [SHIFT_AMOUNT_WIDTH-1:0] addend_shamt;

  always_comb begin : addend_shift_amount
    
    if (exponent_difference <= signed'(-2 * PRECISION_BITS - 1))
      addend_shamt = 3 * PRECISION_BITS + 4;
    
    else if (exponent_difference <= signed'(PRECISION_BITS + 2))
      addend_shamt = unsigned'(signed'(PRECISION_BITS) + 3 - exponent_difference);
    
    else
      addend_shamt = 0;
  end

  
  
  
  logic [PRECISION_BITS-1:0]   mantissa_a, mantissa_b, mantissa_c;
  logic [2*PRECISION_BITS-1:0] product;             
  logic [3*PRECISION_BITS+3:0] product_shifted;     

  
  assign mantissa_a = {info_a.is_normal, operand_a.mantissa};
  assign mantissa_b = {info_b.is_normal, operand_b.mantissa};
  assign mantissa_c = {info_c.is_normal, operand_c.mantissa};

  
  assign product = mantissa_a * mantissa_b;

  
  
  
  assign product_shifted = product << 2; 

  
  
  
  logic [3*PRECISION_BITS+3:0] addend_after_shift;  
  logic [PRECISION_BITS-1:0]   addend_sticky_bits;  
  logic                        sticky_before_add;   
  logic [3*PRECISION_BITS+3:0] addend_shifted;      
  logic                        inject_carry_in;     

  
  
  
  
  
  
  
  
  assign {addend_after_shift, addend_sticky_bits} =
      (mantissa_c << (3 * PRECISION_BITS + 4)) >> addend_shamt;

  assign sticky_before_add     = (| addend_sticky_bits);
  

  
  assign addend_shifted  = (effective_subtraction) ? ~addend_after_shift : addend_after_shift;
  assign inject_carry_in = effective_subtraction & ~sticky_before_add;

  
  
  
  logic [3*PRECISION_BITS+4:0] sum_raw;   
  logic                        sum_carry; 
  logic [3*PRECISION_BITS+3:0] sum;       
  logic                        final_sign;

  
  assign sum_raw = product_shifted + addend_shifted + inject_carry_in;
  assign sum_carry = sum_raw[3*PRECISION_BITS+4];

  
  assign sum        = (effective_subtraction && ~sum_carry) ? -sum_raw : sum_raw;

  
  assign final_sign = (effective_subtraction && (sum_carry == tentative_sign))
                      ? 1'b1
                      : (effective_subtraction ? 1'b0 : tentative_sign);

  
  
  
  
  logic                          effective_subtraction_q;
  logic signed [EXP_WIDTH-1:0]   exponent_product_q;
  logic signed [EXP_WIDTH-1:0]   exponent_difference_q;
  logic signed [EXP_WIDTH-1:0]   tentative_exponent_q;
  logic [SHIFT_AMOUNT_WIDTH-1:0] addend_shamt_q;
  logic                          sticky_before_add_q;
  logic [3*PRECISION_BITS+3:0]   sum_q;
  logic                          final_sign_q;
  fpnew_pkg::roundmode_e         rnd_mode_q;
  logic                          result_is_special_q;
  fp_t                           special_result_q;
  fpnew_pkg::status_t            special_status_q;
  
  logic                  [0:NUM_MID_REGS]                         mid_pipe_eff_sub_q;
  logic signed           [0:NUM_MID_REGS][EXP_WIDTH-1:0]          mid_pipe_exp_prod_q;
  logic signed           [0:NUM_MID_REGS][EXP_WIDTH-1:0]          mid_pipe_exp_diff_q;
  logic signed           [0:NUM_MID_REGS][EXP_WIDTH-1:0]          mid_pipe_tent_exp_q;
  logic                  [0:NUM_MID_REGS][SHIFT_AMOUNT_WIDTH-1:0] mid_pipe_add_shamt_q;
  logic                  [0:NUM_MID_REGS]                         mid_pipe_sticky_q;
  logic                  [0:NUM_MID_REGS][3*PRECISION_BITS+3:0]   mid_pipe_sum_q;
  logic                  [0:NUM_MID_REGS]                         mid_pipe_final_sign_q;
  fpnew_pkg::roundmode_e [0:NUM_MID_REGS]                         mid_pipe_rnd_mode_q;
  logic                  [0:NUM_MID_REGS]                         mid_pipe_res_is_spec_q;
  fp_t                   [0:NUM_MID_REGS]                         mid_pipe_spec_res_q;
  fpnew_pkg::status_t    [0:NUM_MID_REGS]                         mid_pipe_spec_stat_q;
  TagType                [0:NUM_MID_REGS]                         mid_pipe_tag_q;
  logic                  [0:NUM_MID_REGS]                         mid_pipe_mask_q;
  AuxType                [0:NUM_MID_REGS]                         mid_pipe_aux_q;
  logic                  [0:NUM_MID_REGS]                         mid_pipe_valid_q;
  
  logic [0:NUM_MID_REGS] mid_pipe_ready;

  
  assign mid_pipe_eff_sub_q[0]     = effective_subtraction;
  assign mid_pipe_exp_prod_q[0]    = exponent_product;
  assign mid_pipe_exp_diff_q[0]    = exponent_difference;
  assign mid_pipe_tent_exp_q[0]    = tentative_exponent;
  assign mid_pipe_add_shamt_q[0]   = addend_shamt;
  assign mid_pipe_sticky_q[0]      = sticky_before_add;
  assign mid_pipe_sum_q[0]         = sum;
  assign mid_pipe_final_sign_q[0]  = final_sign;
  assign mid_pipe_rnd_mode_q[0]    = inp_pipe_rnd_mode_q[NUM_INP_REGS];
  assign mid_pipe_res_is_spec_q[0] = result_is_special;
  assign mid_pipe_spec_res_q[0]    = special_result;
  assign mid_pipe_spec_stat_q[0]   = special_status;
  assign mid_pipe_tag_q[0]         = inp_pipe_tag_q[NUM_INP_REGS];
  assign mid_pipe_mask_q[0]        = inp_pipe_mask_q[NUM_INP_REGS];
  assign mid_pipe_aux_q[0]         = inp_pipe_aux_q[NUM_INP_REGS];
  assign mid_pipe_valid_q[0]       = inp_pipe_valid_q[NUM_INP_REGS];
  
  assign inp_pipe_ready[NUM_INP_REGS] = mid_pipe_ready[0];

  
  for (genvar i = 0; i < NUM_MID_REGS; i++) begin : gen_inside_pipeline
    
    logic reg_ena;
    
    
    
    assign mid_pipe_ready[i] = mid_pipe_ready[i+1] | ~mid_pipe_valid_q[i+1];
    
    `FFLARNC(mid_pipe_valid_q[i+1], mid_pipe_valid_q[i], mid_pipe_ready[i], flush_i, 1'b0, clk_i, rst_ni)
    
    assign reg_ena = mid_pipe_ready[i] & mid_pipe_valid_q[i];
    
    `FFL(mid_pipe_eff_sub_q[i+1],     mid_pipe_eff_sub_q[i],     reg_ena, '0)
    `FFL(mid_pipe_exp_prod_q[i+1],    mid_pipe_exp_prod_q[i],    reg_ena, '0)
    `FFL(mid_pipe_exp_diff_q[i+1],    mid_pipe_exp_diff_q[i],    reg_ena, '0)
    `FFL(mid_pipe_tent_exp_q[i+1],    mid_pipe_tent_exp_q[i],    reg_ena, '0)
    `FFL(mid_pipe_add_shamt_q[i+1],   mid_pipe_add_shamt_q[i],   reg_ena, '0)
    `FFL(mid_pipe_sticky_q[i+1],      mid_pipe_sticky_q[i],      reg_ena, '0)
    `FFL(mid_pipe_sum_q[i+1],         mid_pipe_sum_q[i],         reg_ena, '0)
    `FFL(mid_pipe_final_sign_q[i+1],  mid_pipe_final_sign_q[i],  reg_ena, '0)
    `FFL(mid_pipe_rnd_mode_q[i+1],    mid_pipe_rnd_mode_q[i],    reg_ena, fpnew_pkg::RNE)
    `FFL(mid_pipe_res_is_spec_q[i+1], mid_pipe_res_is_spec_q[i], reg_ena, '0)
    `FFL(mid_pipe_spec_res_q[i+1],    mid_pipe_spec_res_q[i],    reg_ena, '0)
    `FFL(mid_pipe_spec_stat_q[i+1],   mid_pipe_spec_stat_q[i],   reg_ena, '0)
    `FFL(mid_pipe_tag_q[i+1],         mid_pipe_tag_q[i],         reg_ena, TagType'('0))
    `FFL(mid_pipe_mask_q[i+1],        mid_pipe_mask_q[i],        reg_ena, '0)
    `FFL(mid_pipe_aux_q[i+1],         mid_pipe_aux_q[i],         reg_ena, AuxType'('0))
  end
  
  assign effective_subtraction_q = mid_pipe_eff_sub_q[NUM_MID_REGS];
  assign exponent_product_q      = mid_pipe_exp_prod_q[NUM_MID_REGS];
  assign exponent_difference_q   = mid_pipe_exp_diff_q[NUM_MID_REGS];
  assign tentative_exponent_q    = mid_pipe_tent_exp_q[NUM_MID_REGS];
  assign addend_shamt_q          = mid_pipe_add_shamt_q[NUM_MID_REGS];
  assign sticky_before_add_q     = mid_pipe_sticky_q[NUM_MID_REGS];
  assign sum_q                   = mid_pipe_sum_q[NUM_MID_REGS];
  assign final_sign_q            = mid_pipe_final_sign_q[NUM_MID_REGS];
  assign rnd_mode_q              = mid_pipe_rnd_mode_q[NUM_MID_REGS];
  assign result_is_special_q     = mid_pipe_res_is_spec_q[NUM_MID_REGS];
  assign special_result_q        = mid_pipe_spec_res_q[NUM_MID_REGS];
  assign special_status_q        = mid_pipe_spec_stat_q[NUM_MID_REGS];

  
  
  
  logic        [LOWER_SUM_WIDTH-1:0]  sum_lower;              
  logic        [LZC_RESULT_WIDTH-1:0] leading_zero_count;     
  logic signed [LZC_RESULT_WIDTH:0]   leading_zero_count_sgn; 
  logic                               lzc_zeroes;             

  logic        [SHIFT_AMOUNT_WIDTH-1:0] norm_shamt; 
  logic signed [EXP_WIDTH-1:0]          normalized_exponent;

  logic [3*PRECISION_BITS+4:0] sum_shifted;       
  logic [PRECISION_BITS:0]     final_mantissa;    
  logic [2*PRECISION_BITS+2:0] sum_sticky_bits;   
  logic                        sticky_after_norm; 

  logic signed [EXP_WIDTH-1:0] final_exponent;

  assign sum_lower = sum_q[LOWER_SUM_WIDTH-1:0];

  
  lzc #(
    .WIDTH ( LOWER_SUM_WIDTH ),
    .MODE  ( 1               ) 
  ) i_lzc (
    .in_i    ( sum_lower          ),
    .cnt_o   ( leading_zero_count ),
    .empty_o ( lzc_zeroes         )
  );

  assign leading_zero_count_sgn = signed'({1'b0, leading_zero_count});

  
  always_comb begin : norm_shift_amount
    
    if ((exponent_difference_q <= 0) || (effective_subtraction_q && (exponent_difference_q <= 2))) begin
      
      if ((exponent_product_q - leading_zero_count_sgn + 1 >= 0) && !lzc_zeroes) begin
        
        norm_shamt          = PRECISION_BITS + 2 + leading_zero_count;
        normalized_exponent = exponent_product_q - leading_zero_count_sgn + 1; 
      
      end else begin
        
        norm_shamt          = unsigned'(signed'(PRECISION_BITS) + 2 + exponent_product_q);
        normalized_exponent = 0; 
      end
    
    end else begin
      norm_shamt          = addend_shamt_q; 
      normalized_exponent = tentative_exponent_q;
    end
  end

  
  assign sum_shifted       = sum_q << norm_shamt;

  
  
  always_comb begin : small_norm
    
    {final_mantissa, sum_sticky_bits} = sum_shifted;
    final_exponent                    = normalized_exponent;

    
    if (sum_shifted[3*PRECISION_BITS+4]) begin 
      {final_mantissa, sum_sticky_bits} = sum_shifted >> 1;
      final_exponent                    = normalized_exponent + 1;
    
    end else if (sum_shifted[3*PRECISION_BITS+3]) begin 
      
    
    end else if (normalized_exponent > 1) begin
      {final_mantissa, sum_sticky_bits} = sum_shifted << 1;
      final_exponent                    = normalized_exponent - 1;
    
    end else begin
      final_exponent = '0;
    end
  end

  
  assign sticky_after_norm = (| {sum_sticky_bits}) | sticky_before_add_q;

  
  
  
  logic                         pre_round_sign;
  logic [EXP_BITS-1:0]          pre_round_exponent;
  logic [MAN_BITS-1:0]          pre_round_mantissa;
  logic [EXP_BITS+MAN_BITS-1:0] pre_round_abs; 
  logic [1:0]                   round_sticky_bits;

  logic of_before_round, of_after_round; 
  logic uf_before_round, uf_after_round; 
  logic result_zero;

  logic                         rounded_sign;
  logic [EXP_BITS+MAN_BITS-1:0] rounded_abs; 

  
  assign of_before_round = final_exponent >= 2**(EXP_BITS)-1; 
  assign uf_before_round = final_exponent == 0;               

  
  assign pre_round_sign     = final_sign_q;
  assign pre_round_exponent = (of_before_round) ? 2**EXP_BITS-2 : unsigned'(final_exponent[EXP_BITS-1:0]);
  assign pre_round_mantissa = (of_before_round) ? '1 : final_mantissa[MAN_BITS:1]; 
  assign pre_round_abs      = {pre_round_exponent, pre_round_mantissa};

  
  assign round_sticky_bits  = (of_before_round) ? 2'b11 : {final_mantissa[0], sticky_after_norm};

  
  fpnew_rounding #(
    .AbsWidth ( EXP_BITS + MAN_BITS )
  ) i_fpnew_rounding (
    .abs_value_i             ( pre_round_abs           ),
    .sign_i                  ( pre_round_sign          ),
    .round_sticky_bits_i     ( round_sticky_bits       ),
    .rnd_mode_i              ( rnd_mode_q              ),
    .effective_subtraction_i ( effective_subtraction_q ),
    .abs_rounded_o           ( rounded_abs             ),
    .sign_o                  ( rounded_sign            ),
    .exact_zero_o            ( result_zero             )
  );

  
  assign uf_after_round = rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '0; 
  assign of_after_round = rounded_abs[EXP_BITS+MAN_BITS-1:MAN_BITS] == '1; 

  
  
  
  logic [WIDTH-1:0]     regular_result;
  fpnew_pkg::status_t   regular_status;

  
  assign regular_result    = {rounded_sign, rounded_abs};
  assign regular_status.NV = 1'b0; 
  assign regular_status.DZ = 1'b0; 
  assign regular_status.OF = of_before_round | of_after_round;   
  assign regular_status.UF = uf_after_round & regular_status.NX; 
  assign regular_status.NX = (| round_sticky_bits) | of_before_round | of_after_round;

  
  fp_t                result_d;
  fpnew_pkg::status_t status_d;

  
  assign result_d = result_is_special_q ? special_result_q : regular_result;
  assign status_d = result_is_special_q ? special_status_q : regular_status;

  
  
  
  
  fp_t                [0:NUM_OUT_REGS] out_pipe_result_q;
  fpnew_pkg::status_t [0:NUM_OUT_REGS] out_pipe_status_q;
  TagType             [0:NUM_OUT_REGS] out_pipe_tag_q;
  logic               [0:NUM_OUT_REGS] out_pipe_mask_q;
  AuxType             [0:NUM_OUT_REGS] out_pipe_aux_q;
  logic               [0:NUM_OUT_REGS] out_pipe_valid_q;
  
  logic [0:NUM_OUT_REGS] out_pipe_ready;

  
  assign out_pipe_result_q[0] = result_d;
  assign out_pipe_status_q[0] = status_d;
  assign out_pipe_tag_q[0]    = mid_pipe_tag_q[NUM_MID_REGS];
  assign out_pipe_mask_q[0]   = mid_pipe_mask_q[NUM_MID_REGS];
  assign out_pipe_aux_q[0]    = mid_pipe_aux_q[NUM_MID_REGS];
  assign out_pipe_valid_q[0]  = mid_pipe_valid_q[NUM_MID_REGS];
  
  assign mid_pipe_ready[NUM_MID_REGS] = out_pipe_ready[0];
  
  for (genvar i = 0; i < NUM_OUT_REGS; i++) begin : gen_output_pipeline
    
    logic reg_ena;
    
    
    
    assign out_pipe_ready[i] = out_pipe_ready[i+1] | ~out_pipe_valid_q[i+1];
    
    `FFLARNC(out_pipe_valid_q[i+1], out_pipe_valid_q[i], out_pipe_ready[i], flush_i, 1'b0, clk_i, rst_ni)
    
    assign reg_ena = out_pipe_ready[i] & out_pipe_valid_q[i];
    
    `FFL(out_pipe_result_q[i+1], out_pipe_result_q[i], reg_ena, '0)
    `FFL(out_pipe_status_q[i+1], out_pipe_status_q[i], reg_ena, '0)
    `FFL(out_pipe_tag_q[i+1],    out_pipe_tag_q[i],    reg_ena, TagType'('0))
    `FFL(out_pipe_mask_q[i+1],   out_pipe_mask_q[i],   reg_ena, '0)
    `FFL(out_pipe_aux_q[i+1],    out_pipe_aux_q[i],    reg_ena, AuxType'('0))
  end
  
  assign out_pipe_ready[NUM_OUT_REGS] = out_ready_i;
  
  assign result_o        = out_pipe_result_q[NUM_OUT_REGS];
  assign status_o        = out_pipe_status_q[NUM_OUT_REGS];
  assign extension_bit_o = 1'b1; 
  assign tag_o           = out_pipe_tag_q[NUM_OUT_REGS];
  assign mask_o          = out_pipe_mask_q[NUM_OUT_REGS];
  assign aux_o           = out_pipe_aux_q[NUM_OUT_REGS];
  assign out_valid_o     = out_pipe_valid_q[NUM_OUT_REGS];
  assign busy_o          = (| {inp_pipe_valid_q, mid_pipe_valid_q, out_pipe_valid_q});
endmodule
