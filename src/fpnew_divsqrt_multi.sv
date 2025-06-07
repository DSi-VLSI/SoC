














`include "common_cells/registers.svh"

module fpnew_divsqrt_multi #(
  parameter fpnew_pkg::fmt_logic_t   FpFmtConfig  = '1,
  
  parameter int unsigned             NumPipeRegs = 0,
  parameter fpnew_pkg::pipe_config_t PipeConfig  = fpnew_pkg::AFTER,
  parameter type                     TagType     = logic,
  parameter type                     AuxType     = logic,
  
  localparam int unsigned WIDTH       = fpnew_pkg::max_fp_width(FpFmtConfig),
  localparam int unsigned NUM_FORMATS = fpnew_pkg::NUM_FP_FORMATS
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  
  input  logic [1:0][WIDTH-1:0]       operands_i, 
  input  logic [NUM_FORMATS-1:0][1:0] is_boxed_i, 
  input  fpnew_pkg::roundmode_e       rnd_mode_i,
  input  fpnew_pkg::operation_e       op_i,
  input  fpnew_pkg::fp_format_e       dst_fmt_i,
  input  TagType                      tag_i,
  input  logic                        mask_i,
  input  AuxType                      aux_i,
  
  input  logic                        in_valid_i,
  output logic                        in_ready_o,
  output logic                        divsqrt_done_o,
  input  logic                        simd_synch_done_i,
  output logic                        divsqrt_ready_o,
  input  logic                        simd_synch_rdy_i,
  input  logic                        flush_i,
  
  output logic [WIDTH-1:0]            result_o,
  output fpnew_pkg::status_t          status_o,
  output logic                        extension_bit_o,
  output TagType                      tag_o,
  output logic                        mask_o,
  output AuxType                      aux_o,
  
  output logic                        out_valid_o,
  input  logic                        out_ready_i,
  
  output logic                        busy_o
);

  
  
  
  
  localparam NUM_INP_REGS = (PipeConfig == fpnew_pkg::BEFORE)
                            ? NumPipeRegs
                            : (PipeConfig == fpnew_pkg::DISTRIBUTED
                               ? (NumPipeRegs / 2) 
                               : 0); 
  localparam NUM_OUT_REGS = (PipeConfig == fpnew_pkg::AFTER || PipeConfig == fpnew_pkg::INSIDE)
                            ? NumPipeRegs
                            : (PipeConfig == fpnew_pkg::DISTRIBUTED
                               ? ((NumPipeRegs + 1) / 2) 
                               : 0); 

  
  
  
  
  logic [1:0][WIDTH-1:0] operands_q;
  fpnew_pkg::roundmode_e rnd_mode_q;
  fpnew_pkg::operation_e op_q;
  fpnew_pkg::fp_format_e dst_fmt_q;
  logic                  in_valid_q;

  
  logic                  [0:NUM_INP_REGS][1:0][WIDTH-1:0]       inp_pipe_operands_q;
  fpnew_pkg::roundmode_e [0:NUM_INP_REGS]                       inp_pipe_rnd_mode_q;
  fpnew_pkg::operation_e [0:NUM_INP_REGS]                       inp_pipe_op_q;
  fpnew_pkg::fp_format_e [0:NUM_INP_REGS]                       inp_pipe_dst_fmt_q;
  TagType                [0:NUM_INP_REGS]                       inp_pipe_tag_q;
  logic                  [0:NUM_INP_REGS]                       inp_pipe_mask_q;
  AuxType                [0:NUM_INP_REGS]                       inp_pipe_aux_q;
  logic                  [0:NUM_INP_REGS]                       inp_pipe_valid_q;
  
  logic [0:NUM_INP_REGS] inp_pipe_ready;

  
  assign inp_pipe_operands_q[0] = operands_i;
  assign inp_pipe_rnd_mode_q[0] = rnd_mode_i;
  assign inp_pipe_op_q[0]       = op_i;
  assign inp_pipe_dst_fmt_q[0]  = dst_fmt_i;
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
    `FFL(inp_pipe_rnd_mode_q[i+1], inp_pipe_rnd_mode_q[i], reg_ena, fpnew_pkg::RNE)
    `FFL(inp_pipe_op_q[i+1],       inp_pipe_op_q[i],       reg_ena, fpnew_pkg::FMADD)
    `FFL(inp_pipe_dst_fmt_q[i+1],  inp_pipe_dst_fmt_q[i],  reg_ena, fpnew_pkg::fp_format_e'(0))
    `FFL(inp_pipe_tag_q[i+1],      inp_pipe_tag_q[i],      reg_ena, TagType'('0))
    `FFL(inp_pipe_mask_q[i+1],     inp_pipe_mask_q[i],     reg_ena, '0)
    `FFL(inp_pipe_aux_q[i+1],      inp_pipe_aux_q[i],      reg_ena, AuxType'('0))
  end
  
  assign operands_q = inp_pipe_operands_q[NUM_INP_REGS];
  assign rnd_mode_q = inp_pipe_rnd_mode_q[NUM_INP_REGS];
  assign op_q       = inp_pipe_op_q[NUM_INP_REGS];
  assign dst_fmt_q  = inp_pipe_dst_fmt_q[NUM_INP_REGS];
  assign in_valid_q = inp_pipe_valid_q[NUM_INP_REGS];

  
  
  
  logic [1:0]       divsqrt_fmt;
  logic [1:0][63:0] divsqrt_operands; 
  logic             input_is_fp8;

  
  always_comb begin : translate_fmt
    unique case (dst_fmt_q)
      fpnew_pkg::FP32:    divsqrt_fmt = 2'b00;
      fpnew_pkg::FP64:    divsqrt_fmt = 2'b01;
      fpnew_pkg::FP16:    divsqrt_fmt = 2'b10;
      fpnew_pkg::FP16ALT: divsqrt_fmt = 2'b11;
      default:            divsqrt_fmt = 2'b10; 
    endcase

    
    input_is_fp8 = FpFmtConfig[fpnew_pkg::FP8] & (dst_fmt_q == fpnew_pkg::FP8);

    
    divsqrt_operands[0] = input_is_fp8 ? operands_q[0] << 8 : operands_q[0];
    divsqrt_operands[1] = input_is_fp8 ? operands_q[1] << 8 : operands_q[1];
  end

  
  
  

  logic in_ready;               
  logic div_valid, sqrt_valid;  
  logic unit_ready, unit_done, unit_done_q;  
  logic op_starting;            
  logic out_valid, out_ready;   
  logic unit_busy;              
  
  typedef enum logic [1:0] {IDLE, BUSY, HOLD} fsm_state_e;
  fsm_state_e state_q, state_d;

  
  
  assign divsqrt_ready_o = in_ready;
  
  assign inp_pipe_ready[NUM_INP_REGS] = simd_synch_rdy_i;

  
  
  
  `FFLARNC(unit_done_q, unit_done, unit_done, simd_synch_done_i, 1'b0, clk_i, rst_ni);
  
  assign divsqrt_done_o = unit_done_q | unit_done;

  
  assign div_valid   = in_valid_q & (op_q == fpnew_pkg::DIV) & in_ready & ~flush_i;
  assign sqrt_valid  = in_valid_q & (op_q != fpnew_pkg::DIV) & in_ready & ~flush_i;
  assign op_starting = div_valid | sqrt_valid;

  
  always_comb begin : flag_fsm
    
    in_ready     = 1'b0;
    out_valid    = 1'b0;
    unit_busy    = 1'b0;
    state_d      = state_q;

    unique case (state_q)
      
      IDLE: begin
        in_ready = 1'b1; 
        if (in_valid_q && unit_ready) begin 
          state_d = BUSY; 
        end
      end
      
      BUSY: begin
        unit_busy = 1'b1; 
        
        if (simd_synch_done_i) begin
          out_valid = 1'b1; 
          
          if (out_ready) begin
            state_d = IDLE; 
            if (in_valid_q && unit_ready) begin 
              in_ready = 1'b1; 
              state_d  = BUSY; 
            end
          
          end else begin
            state_d     = HOLD; 
          end
        end
      end
      
      HOLD: begin
        unit_busy    = 1'b1; 
        out_valid    = 1'b1; 
        
        if (out_ready) begin
          state_d = IDLE; 
          if (in_valid_q && unit_ready) begin 
            in_ready = 1'b1; 
            state_d  = BUSY; 
          end
        end
      end
      
      default: state_d = IDLE;
    endcase

    
    if (flush_i) begin
      unit_busy = 1'b0; 
      out_valid = 1'b0; 
      state_d   = IDLE; 
    end
  end

  
  `FF(state_q, state_d, IDLE)

  
  logic result_is_fp8_q;
  TagType result_tag_q;
  logic result_mask_q;
  AuxType result_aux_q;

  
  `FFL(result_is_fp8_q, input_is_fp8,                 op_starting, '0)
  `FFL(result_tag_q,    inp_pipe_tag_q[NUM_INP_REGS], op_starting, '0)
  `FFL(result_mask_q,   inp_pipe_mask_q[NUM_INP_REGS],op_starting, '0)
  `FFL(result_aux_q,    inp_pipe_aux_q[NUM_INP_REGS], op_starting, '0)

  
  
  
  logic [63:0]        unit_result;
  logic [WIDTH-1:0]   adjusted_result, held_result_q;
  fpnew_pkg::status_t unit_status, held_status_q;
  logic               hold_en;

  div_sqrt_top_mvp i_divsqrt_lei (
   .Clk_CI           ( clk_i               ),
   .Rst_RBI          ( rst_ni              ),
   .Div_start_SI     ( div_valid           ),
   .Sqrt_start_SI    ( sqrt_valid          ),
   .Operand_a_DI     ( divsqrt_operands[0] ),
   .Operand_b_DI     ( divsqrt_operands[1] ),
   .RM_SI            ( rnd_mode_q          ),
   .Precision_ctl_SI ( '0                  ),
   .Format_sel_SI    ( divsqrt_fmt         ),
   .Kill_SI          ( flush_i             ),
   .Result_DO        ( unit_result         ),
   .Fflags_SO        ( unit_status         ),
   .Ready_SO         ( unit_ready          ),
   .Done_SO          ( unit_done           )
  );

  
  assign adjusted_result = result_is_fp8_q ? unit_result >> 8 : unit_result;

  
  
  assign hold_en = unit_done & (~simd_synch_done_i | ~out_ready);
  
  `FFLNR(held_result_q, adjusted_result, hold_en, clk_i)
  `FFLNR(held_status_q, unit_status,     hold_en, clk_i)

  
  
  
  logic [WIDTH-1:0]   result_d;
  fpnew_pkg::status_t status_d;
  
  assign result_d = unit_done_q ? held_result_q : adjusted_result;
  assign status_d = unit_done_q ? held_status_q : unit_status;

  
  
  
  
  logic               [0:NUM_OUT_REGS][WIDTH-1:0] out_pipe_result_q;
  fpnew_pkg::status_t [0:NUM_OUT_REGS]            out_pipe_status_q;
  TagType             [0:NUM_OUT_REGS]            out_pipe_tag_q;
  logic               [0:NUM_OUT_REGS]            out_pipe_mask_q;
  AuxType             [0:NUM_OUT_REGS]            out_pipe_aux_q;
  logic               [0:NUM_OUT_REGS]            out_pipe_valid_q;
  
  logic [0:NUM_OUT_REGS] out_pipe_ready;

  
  assign out_pipe_result_q[0] = result_d;
  assign out_pipe_status_q[0] = status_d;
  assign out_pipe_tag_q[0]    = result_tag_q;
  assign out_pipe_mask_q[0]   = result_mask_q;
  assign out_pipe_aux_q[0]    = result_aux_q;
  assign out_pipe_valid_q[0]  = out_valid;
  
  assign out_ready = out_pipe_ready[0];
  
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
  assign busy_o          = (| {inp_pipe_valid_q, unit_busy, out_pipe_valid_q});
endmodule
