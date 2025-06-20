

module fpnew_opgroup_fmt_slice #(
    parameter fpnew_pkg::opgroup_e   OpGroup  = fpnew_pkg::ADDMUL,
    parameter fpnew_pkg::fp_format_e FpFormat = fpnew_pkg::fp_format_e'(0),

    parameter int unsigned             Width         = 32,
    parameter logic                    EnableVectors = 1'b1,
    parameter int unsigned             NumPipeRegs   = 0,
    parameter fpnew_pkg::pipe_config_t PipeConfig    = fpnew_pkg::BEFORE,
    parameter type                     TagType       = logic,
    parameter int unsigned             TrueSIMDClass = 0,

    localparam int unsigned NUM_OPERANDS = fpnew_pkg::num_operands(OpGroup),
    localparam int unsigned NUM_LANES = fpnew_pkg::num_lanes(Width, FpFormat, EnableVectors),
    localparam type MaskType = logic [NUM_LANES-1:0]
) (
    input logic clk_i,
    input logic rst_ni,

    input logic                  [NUM_OPERANDS-1:0][Width-1:0] operands_i,
    input logic                  [NUM_OPERANDS-1:0]            is_boxed_i,
    input fpnew_pkg::roundmode_e                               rnd_mode_i,
    input fpnew_pkg::operation_e                               op_i,
    input logic                                                op_mod_i,
    input logic                                                vectorial_op_i,
    input TagType                                              tag_i,
    input MaskType                                             simd_mask_i,

    input  logic in_valid_i,
    output logic in_ready_o,
    input  logic flush_i,

    output logic               [Width-1:0] result_o,
    output fpnew_pkg::status_t             status_o,
    output logic                           extension_bit_o,
    output TagType                         tag_o,

    output logic out_valid_o,
    input  logic out_ready_i,

    output logic busy_o
);

  localparam int unsigned FP_WIDTH = fpnew_pkg::fp_width(FpFormat);
  localparam int unsigned SIMD_WIDTH = unsigned'(Width / NUM_LANES);
  logic [NUM_LANES-1:0] lane_in_ready, lane_out_valid;
  logic                          vectorial_op;

  logic [NUM_LANES*FP_WIDTH-1:0] slice_result;
  logic [Width-1:0] slice_regular_result, slice_class_result, slice_vec_class_result;

  fpnew_pkg::status_t    [NUM_LANES-1:0] lane_status;
  logic                  [NUM_LANES-1:0] lane_ext_bit;
  fpnew_pkg::classmask_e [NUM_LANES-1:0] lane_class_mask;
  TagType                [NUM_LANES-1:0] lane_tags;
  logic                  [NUM_LANES-1:0] lane_masks;
  logic [NUM_LANES-1:0] lane_vectorial, lane_busy, lane_is_class;

  logic result_is_vector, result_is_class;

  assign in_ready_o   = lane_in_ready[0];
  assign vectorial_op = vectorial_op_i & EnableVectors;

  for (genvar lane = 0; lane < int'(NUM_LANES); lane++) begin : gen_num_lanes
    logic [FP_WIDTH-1:0] local_result;
    logic                local_sign;

    if ((lane == 0) || EnableVectors) begin : active_lane
      logic in_valid, out_valid, out_ready;

      logic               [NUM_OPERANDS-1:0][FP_WIDTH-1:0] local_operands;
      logic               [    FP_WIDTH-1:0]               op_result;
      fpnew_pkg::status_t                                  op_status;

      assign in_valid = in_valid_i & ((lane == 0) | vectorial_op);

      always_comb begin : prepare_input
        for (int i = 0; i < int'(NUM_OPERANDS); i++) begin
          local_operands[i] = operands_i[i][(unsigned'(lane)+1)*FP_WIDTH-1:unsigned'(lane)*FP_WIDTH];
        end
      end

      if (OpGroup == fpnew_pkg::ADDMUL) begin : lane_instance
        fpnew_fma #(
            .FpFormat   (FpFormat),
            .NumPipeRegs(NumPipeRegs),
            .PipeConfig (PipeConfig),
            .TagType    (TagType),
            .AuxType    (logic)
        ) i_fma (
            .clk_i,
            .rst_ni,
            .operands_i     (local_operands),
            .is_boxed_i     (is_boxed_i[NUM_OPERANDS-1:0]),
            .rnd_mode_i,
            .op_i,
            .op_mod_i,
            .tag_i,
            .mask_i         (simd_mask_i[lane]),
            .aux_i          (vectorial_op),
            .in_valid_i     (in_valid),
            .in_ready_o     (lane_in_ready[lane]),
            .flush_i,
            .result_o       (op_result),
            .status_o       (op_status),
            .extension_bit_o(lane_ext_bit[lane]),
            .tag_o          (lane_tags[lane]),
            .mask_o         (lane_masks[lane]),
            .aux_o          (lane_vectorial[lane]),
            .out_valid_o    (out_valid),
            .out_ready_i    (out_ready),
            .busy_o         (lane_busy[lane])
        );
        assign lane_is_class[lane]   = 1'b0;
        assign lane_class_mask[lane] = fpnew_pkg::NEGINF;
      end else
      if (OpGroup == fpnew_pkg::DIVSQRT) begin : lane_instance

      end else if (OpGroup == fpnew_pkg::NONCOMP) begin : lane_instance
        fpnew_noncomp #(
            .FpFormat   (FpFormat),
            .NumPipeRegs(NumPipeRegs),
            .PipeConfig (PipeConfig),
            .TagType    (TagType),
            .AuxType    (logic)
        ) i_noncomp (
            .clk_i,
            .rst_ni,
            .operands_i     (local_operands),
            .is_boxed_i     (is_boxed_i[NUM_OPERANDS-1:0]),
            .rnd_mode_i,
            .op_i,
            .op_mod_i,
            .tag_i,
            .mask_i         (simd_mask_i[lane]),
            .aux_i          (vectorial_op),
            .in_valid_i     (in_valid),
            .in_ready_o     (lane_in_ready[lane]),
            .flush_i,
            .result_o       (op_result),
            .status_o       (op_status),
            .extension_bit_o(lane_ext_bit[lane]),
            .class_mask_o   (lane_class_mask[lane]),
            .is_class_o     (lane_is_class[lane]),
            .tag_o          (lane_tags[lane]),
            .mask_o         (lane_masks[lane]),
            .aux_o          (lane_vectorial[lane]),
            .out_valid_o    (out_valid),
            .out_ready_i    (out_ready),
            .busy_o         (lane_busy[lane])
        );
      end

      assign out_ready            = out_ready_i & ((lane == 0) | result_is_vector);
      assign lane_out_valid[lane] = out_valid & ((lane == 0) | result_is_vector);

      assign local_result         = lane_out_valid[lane] ? op_result : '{default: lane_ext_bit[0]};
      assign lane_status[lane]    = lane_out_valid[lane] ? op_status : '0;

    end else begin
      assign lane_out_valid[lane] = 1'b0;
      assign lane_in_ready[lane]  = 1'b0;
      assign local_result         = '{default: lane_ext_bit[0]};
      assign lane_status[lane]    = '0;
      assign lane_busy[lane]      = 1'b0;
      assign lane_is_class[lane]  = 1'b0;
    end

    assign slice_result[(unsigned'(lane)+1)*FP_WIDTH-1:unsigned'(lane)*FP_WIDTH] = local_result;

    if (TrueSIMDClass && SIMD_WIDTH >= 10) begin : vectorial_true_class
      assign slice_vec_class_result[lane*SIMD_WIDTH+:10] = lane_class_mask[lane];
      assign slice_vec_class_result[(lane+1)*SIMD_WIDTH-1-:SIMD_WIDTH-10] = '0;
    end else if ((lane + 1) * 8 <= Width) begin : vectorial_class
      assign local_sign = (lane_class_mask[lane] == fpnew_pkg::NEGINF ||
                           lane_class_mask[lane] == fpnew_pkg::NEGNORM ||
                           lane_class_mask[lane] == fpnew_pkg::NEGSUBNORM ||
                           lane_class_mask[lane] == fpnew_pkg::NEGZERO);

      assign slice_vec_class_result[(lane+1)*8-1:lane*8] = {
        local_sign,
        ~local_sign,
        lane_class_mask[lane] == fpnew_pkg::QNAN,
        lane_class_mask[lane] == fpnew_pkg::SNAN,
        lane_class_mask[lane] == fpnew_pkg::POSZERO || lane_class_mask[lane] == fpnew_pkg::NEGZERO,
        lane_class_mask[lane] == fpnew_pkg::POSSUBNORM
            || lane_class_mask[lane] == fpnew_pkg::NEGSUBNORM,
        lane_class_mask[lane] == fpnew_pkg::POSNORM || lane_class_mask[lane] == fpnew_pkg::NEGNORM,
        lane_class_mask[lane] == fpnew_pkg::POSINF || lane_class_mask[lane] == fpnew_pkg::NEGINF
      };
    end
  end

  assign result_is_vector = lane_vectorial[0];
  assign result_is_class = lane_is_class[0];

  assign slice_regular_result = $signed({extension_bit_o, slice_result});

  localparam int unsigned CLASS_VEC_BITS = (NUM_LANES*8 > Width) ? 8 * (Width / 8) : NUM_LANES*8;

  if (!(TrueSIMDClass && SIMD_WIDTH >= 10)) begin
    if (CLASS_VEC_BITS < Width) begin : pad_vectorial_class
      assign slice_vec_class_result[Width-1:CLASS_VEC_BITS] = '0;
    end
  end

  assign slice_class_result = result_is_vector ? slice_vec_class_result : lane_class_mask[0];

  assign result_o           = result_is_class ? slice_class_result : slice_regular_result;

  assign extension_bit_o    = lane_ext_bit[0];
  assign tag_o              = lane_tags[0];
  assign busy_o             = (|lane_busy);
  assign out_valid_o        = lane_out_valid[0];

  always_comb begin : output_processing

    automatic fpnew_pkg::status_t temp_status;
    temp_status = '0;
    for (int i = 0; i < int'(NUM_LANES); i++) temp_status |= lane_status[i] & {5{lane_masks[i]}};
    status_o = temp_status;
  end
endmodule
