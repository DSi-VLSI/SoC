

module fpnew_opgroup_block #(
    parameter fpnew_pkg::opgroup_e OpGroup = fpnew_pkg::ADDMUL,

    parameter int unsigned                Width         = 32,
    parameter logic                       EnableVectors = 1'b1,
    parameter fpnew_pkg::fmt_logic_t      FpFmtMask     = '1,
    parameter fpnew_pkg::ifmt_logic_t     IntFmtMask    = '1,
    parameter fpnew_pkg::fmt_unsigned_t   FmtPipeRegs   = '{default: 0},
    parameter fpnew_pkg::fmt_unit_types_t FmtUnitTypes  = '{default: fpnew_pkg::PARALLEL},
    parameter fpnew_pkg::pipe_config_t    PipeConfig    = fpnew_pkg::BEFORE,
    parameter type                        TagType       = logic,
    parameter int unsigned                TrueSIMDClass = 0,

    localparam int unsigned NUM_FORMATS = fpnew_pkg::NUM_FP_FORMATS,
    localparam int unsigned NUM_OPERANDS = fpnew_pkg::num_operands(OpGroup),
    localparam int unsigned NUM_LANES = fpnew_pkg::max_num_lanes(Width, FpFmtMask, EnableVectors),
    localparam type MaskType = logic [NUM_LANES-1:0]
) (
    input logic clk_i,
    input logic rst_ni,

    input logic                   [NUM_OPERANDS-1:0][       Width-1:0] operands_i,
    input logic                   [ NUM_FORMATS-1:0][NUM_OPERANDS-1:0] is_boxed_i,
    input fpnew_pkg::roundmode_e                                       rnd_mode_i,
    input fpnew_pkg::operation_e                                       op_i,
    input logic                                                        op_mod_i,
    input fpnew_pkg::fp_format_e                                       src_fmt_i,
    input fpnew_pkg::fp_format_e                                       dst_fmt_i,
    input fpnew_pkg::int_format_e                                      int_fmt_i,
    input logic                                                        vectorial_op_i,
    input TagType                                                      tag_i,
    input MaskType                                                     simd_mask_i,

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

  typedef struct packed {
    logic [Width-1:0]   result;
    fpnew_pkg::status_t status;
    logic               ext_bit;
    TagType             tag;
  } output_t;

  logic [NUM_FORMATS-1:0] fmt_in_ready, fmt_out_valid, fmt_out_ready, fmt_busy;
  output_t [NUM_FORMATS-1:0] fmt_outputs;

  assign in_ready_o = in_valid_i & fmt_in_ready[dst_fmt_i];

  for (genvar fmt = 0; fmt < int'(NUM_FORMATS); fmt++) begin : gen_parallel_slices

    localparam logic ANY_MERGED = fpnew_pkg::any_enabled_multi(FmtUnitTypes, FpFmtMask);
    localparam logic IS_FIRST_MERGED = fpnew_pkg::is_first_enabled_multi(
        fpnew_pkg::fp_format_e'(fmt), FmtUnitTypes, FpFmtMask
    );

    if (FpFmtMask[fmt] && (FmtUnitTypes[fmt] == fpnew_pkg::PARALLEL)) begin : active_format

      logic in_valid;

      assign in_valid = in_valid_i & (dst_fmt_i == fmt);

      localparam int unsigned INTERNAL_LANES = fpnew_pkg::num_lanes(
          Width, fpnew_pkg::fp_format_e'(fmt), EnableVectors
      );
      logic [INTERNAL_LANES-1:0] mask_slice;
      always_comb
        for (int b = 0; b < INTERNAL_LANES; b++)
          mask_slice[b] = simd_mask_i[(NUM_LANES/INTERNAL_LANES)*b];

      fpnew_opgroup_fmt_slice #(
          .OpGroup      (OpGroup),
          .FpFormat     (fpnew_pkg::fp_format_e'(fmt)),
          .Width        (Width),
          .EnableVectors(EnableVectors),
          .NumPipeRegs  (FmtPipeRegs[fmt]),
          .PipeConfig   (PipeConfig),
          .TagType      (TagType),
          .TrueSIMDClass(TrueSIMDClass)
      ) i_fmt_slice (
          .clk_i,
          .rst_ni,
          .operands_i     (operands_i),
          .is_boxed_i     (is_boxed_i[fmt]),
          .rnd_mode_i,
          .op_i,
          .op_mod_i,
          .vectorial_op_i,
          .tag_i,
          .simd_mask_i    (mask_slice),
          .in_valid_i     (in_valid),
          .in_ready_o     (fmt_in_ready[fmt]),
          .flush_i,
          .result_o       (fmt_outputs[fmt].result),
          .status_o       (fmt_outputs[fmt].status),
          .extension_bit_o(fmt_outputs[fmt].ext_bit),
          .tag_o          (fmt_outputs[fmt].tag),
          .out_valid_o    (fmt_out_valid[fmt]),
          .out_ready_i    (fmt_out_ready[fmt]),
          .busy_o         (fmt_busy[fmt])
      );

    end else if (FpFmtMask[fmt] && ANY_MERGED && !IS_FIRST_MERGED) begin : merged_unused

      localparam FMT = fpnew_pkg::get_first_enabled_multi(FmtUnitTypes, FpFmtMask);

      assign fmt_in_ready[fmt]        = fmt_in_ready[int'(FMT)];

      assign fmt_out_valid[fmt]       = 1'b0;
      assign fmt_busy[fmt]            = 1'b0;

      assign fmt_outputs[fmt].result  = '{default: fpnew_pkg::DONT_CARE};
      assign fmt_outputs[fmt].status  = '{default: fpnew_pkg::DONT_CARE};
      assign fmt_outputs[fmt].ext_bit = fpnew_pkg::DONT_CARE;
      assign fmt_outputs[fmt].tag     = TagType'(fpnew_pkg::DONT_CARE);

    end else if (!FpFmtMask[fmt] || (FmtUnitTypes[fmt] == fpnew_pkg::DISABLED)) begin : disable_fmt
      assign fmt_in_ready[fmt]        = 1'b0;
      assign fmt_out_valid[fmt]       = 1'b0;
      assign fmt_busy[fmt]            = 1'b0;

      assign fmt_outputs[fmt].result  = '{default: fpnew_pkg::DONT_CARE};
      assign fmt_outputs[fmt].status  = '{default: fpnew_pkg::DONT_CARE};
      assign fmt_outputs[fmt].ext_bit = fpnew_pkg::DONT_CARE;
      assign fmt_outputs[fmt].tag     = TagType'(fpnew_pkg::DONT_CARE);
    end
  end

  if (fpnew_pkg::any_enabled_multi(FmtUnitTypes, FpFmtMask)) begin : gen_merged_slice

    localparam FMT = fpnew_pkg::get_first_enabled_multi(FmtUnitTypes, FpFmtMask);
    localparam REG = fpnew_pkg::get_num_regs_multi(FmtPipeRegs, FmtUnitTypes, FpFmtMask);

    logic in_valid;

    assign in_valid = in_valid_i & (FmtUnitTypes[dst_fmt_i] == fpnew_pkg::MERGED);

    fpnew_opgroup_multifmt_slice #(
        .OpGroup      (OpGroup),
        .Width        (Width),
        .FpFmtConfig  (FpFmtMask),
        .IntFmtConfig (IntFmtMask),
        .EnableVectors(EnableVectors),
        .NumPipeRegs  (REG),
        .PipeConfig   (PipeConfig),
        .TagType      (TagType)
    ) i_multifmt_slice (
        .clk_i,
        .rst_ni,
        .operands_i,
        .is_boxed_i,
        .rnd_mode_i,
        .op_i,
        .op_mod_i,
        .src_fmt_i,
        .dst_fmt_i,
        .int_fmt_i,
        .vectorial_op_i,
        .tag_i,
        .simd_mask_i    (simd_mask_i),
        .in_valid_i     (in_valid),
        .in_ready_o     (fmt_in_ready[FMT]),
        .flush_i,
        .result_o       (fmt_outputs[FMT].result),
        .status_o       (fmt_outputs[FMT].status),
        .extension_bit_o(fmt_outputs[FMT].ext_bit),
        .tag_o          (fmt_outputs[FMT].tag),
        .out_valid_o    (fmt_out_valid[FMT]),
        .out_ready_i    (fmt_out_ready[FMT]),
        .busy_o         (fmt_busy[FMT])
    );

  end

  output_t arbiter_output;

  rr_arb_tree #(
      .NumIn    (NUM_FORMATS),
      .DataType (output_t),
      .AxiVldRdy(1'b1)
  ) i_arbiter (
      .clk_i,
      .rst_ni,
      .flush_i,
      .rr_i  ('0),
      .req_i (fmt_out_valid),
      .gnt_o (fmt_out_ready),
      .data_i(fmt_outputs),
      .gnt_i (out_ready_i),
      .req_o (out_valid_o),
      .data_o(arbiter_output),
      .idx_o ()
  );

  assign result_o        = arbiter_output.result;
  assign status_o        = arbiter_output.status;
  assign extension_bit_o = arbiter_output.ext_bit;
  assign tag_o           = arbiter_output.tag;

  assign busy_o          = (|fmt_busy);

endmodule
