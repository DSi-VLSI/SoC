
import defs_div_sqrt_mvp::*;

module nrbd_nrsc_mvp (
    input logic                 Clk_CI,
    input logic                 Rst_RBI,
    input logic                 Div_start_SI,
    input logic                 Sqrt_start_SI,
    input logic                 Start_SI,
    input logic                 Kill_SI,
    input logic                 Special_case_SBI,
    input logic                 Special_case_dly_SBI,
    input logic [     C_PC-1:0] Precision_ctl_SI,
    input logic [          1:0] Format_sel_SI,
    input logic [C_MANT_FP64:0] Mant_a_DI,
    input logic [C_MANT_FP64:0] Mant_b_DI,
    input logic [ C_EXP_FP64:0] Exp_a_DI,
    input logic [ C_EXP_FP64:0] Exp_b_DI,

    output logic Div_enable_SO,
    output logic Sqrt_enable_SO,

    output logic                   Full_precision_SO,
    output logic                   FP32_SO,
    output logic                   FP64_SO,
    output logic                   FP16_SO,
    output logic                   FP16ALT_SO,
    output logic                   Ready_SO,
    output logic                   Done_SO,
    output logic [C_MANT_FP64+4:0] Mant_z_DO,
    output logic [ C_EXP_FP64+1:0] Exp_z_DO
);
  logic Div_start_dly_S, Sqrt_start_dly_S;
  control_mvp control_U0 (
      .Clk_CI                (Clk_CI),
      .Rst_RBI               (Rst_RBI),
      .Div_start_SI          (Div_start_SI),
      .Sqrt_start_SI         (Sqrt_start_SI),
      .Start_SI              (Start_SI),
      .Kill_SI               (Kill_SI),
      .Special_case_SBI      (Special_case_SBI),
      .Special_case_dly_SBI  (Special_case_dly_SBI),
      .Precision_ctl_SI      (Precision_ctl_SI),
      .Format_sel_SI         (Format_sel_SI),
      .Numerator_DI          (Mant_a_DI),
      .Exp_num_DI            (Exp_a_DI),
      .Denominator_DI        (Mant_b_DI),
      .Exp_den_DI            (Exp_b_DI),
      .Div_start_dly_SO      (Div_start_dly_S),
      .Sqrt_start_dly_SO     (Sqrt_start_dly_S),
      .Div_enable_SO         (Div_enable_SO),
      .Sqrt_enable_SO        (Sqrt_enable_SO),
      .Full_precision_SO     (Full_precision_SO),
      .FP32_SO               (FP32_SO),
      .FP64_SO               (FP64_SO),
      .FP16_SO               (FP16_SO),
      .FP16ALT_SO            (FP16ALT_SO),
      .Ready_SO              (Ready_SO),
      .Done_SO               (Done_SO),
      .Mant_result_prenorm_DO(Mant_z_DO),
      .Exp_result_prenorm_DO (Exp_z_DO)
  );
endmodule
