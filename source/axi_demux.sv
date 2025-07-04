`include "common_cells/registers.svh"

module axi_demux #(
    parameter int unsigned AxiIdWidth  = 32'd0,
    parameter bit          AtopSupport = 1'b1,
    parameter type         aw_chan_t   = logic,
    parameter type         w_chan_t    = logic,
    parameter type         b_chan_t    = logic,
    parameter type         ar_chan_t   = logic,
    parameter type         r_chan_t    = logic,
    parameter type         axi_req_t   = logic,
    parameter type         axi_resp_t  = logic,
    parameter int unsigned NoMstPorts  = 32'd0,
    parameter int unsigned MaxTrans    = 32'd8,
    parameter int unsigned AxiLookBits = 32'd3,
    parameter bit          UniqueIds   = 1'b0,
    parameter bit          SpillAw     = 1'b1,
    parameter bit          SpillW      = 1'b0,
    parameter bit          SpillB      = 1'b0,
    parameter bit          SpillAr     = 1'b1,
    parameter bit          SpillR      = 1'b0,

    parameter int unsigned SelectWidth = (NoMstPorts > 32'd1) ? $clog2(NoMstPorts) : 32'd1,
    parameter type select_t = logic [SelectWidth-1:0]
) (
    input logic clk_i,
    input logic rst_ni,
    input logic test_i,

    input  axi_req_t  slv_req_i,
    input  select_t   slv_aw_select_i,
    input  select_t   slv_ar_select_i,
    output axi_resp_t slv_resp_o,

    output axi_req_t  [NoMstPorts-1:0] mst_reqs_o,
    input  axi_resp_t [NoMstPorts-1:0] mst_resps_i
);

  axi_req_t  slv_req_cut;
  axi_resp_t slv_resp_cut;

  logic slv_aw_ready_chan, slv_aw_ready_sel;
  logic slv_aw_valid_chan, slv_aw_valid_sel;

  logic slv_ar_ready_chan, slv_ar_ready_sel;
  logic slv_ar_valid_chan, slv_ar_valid_sel;

  select_t slv_aw_select, slv_ar_select;

  spill_register #(
      .T     (aw_chan_t),
      .Bypass(~SpillAw)
  ) i_aw_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_req_i.aw_valid),
      .ready_o(slv_aw_ready_chan),
      .data_i (slv_req_i.aw),
      .valid_o(slv_aw_valid_chan),
      .ready_i(slv_resp_cut.aw_ready),
      .data_o (slv_req_cut.aw)
  );
  spill_register #(
      .T     (select_t),
      .Bypass(~SpillAw)
  ) i_aw_select_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_req_i.aw_valid),
      .ready_o(slv_aw_ready_sel),
      .data_i (slv_aw_select_i),
      .valid_o(slv_aw_valid_sel),
      .ready_i(slv_resp_cut.aw_ready),
      .data_o (slv_aw_select)
  );

  assign slv_resp_o.aw_ready  = slv_aw_ready_chan & slv_aw_ready_sel;
  assign slv_req_cut.aw_valid = slv_aw_valid_chan & slv_aw_valid_sel;

  spill_register #(
      .T     (w_chan_t),
      .Bypass(~SpillW)
  ) i_w_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_req_i.w_valid),
      .ready_o(slv_resp_o.w_ready),
      .data_i (slv_req_i.w),
      .valid_o(slv_req_cut.w_valid),
      .ready_i(slv_resp_cut.w_ready),
      .data_o (slv_req_cut.w)
  );
  spill_register #(
      .T     (ar_chan_t),
      .Bypass(~SpillAr)
  ) i_ar_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_req_i.ar_valid),
      .ready_o(slv_ar_ready_chan),
      .data_i (slv_req_i.ar),
      .valid_o(slv_ar_valid_chan),
      .ready_i(slv_resp_cut.ar_ready),
      .data_o (slv_req_cut.ar)
  );
  spill_register #(
      .T     (select_t),
      .Bypass(~SpillAr)
  ) i_ar_sel_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_req_i.ar_valid),
      .ready_o(slv_ar_ready_sel),
      .data_i (slv_ar_select_i),
      .valid_o(slv_ar_valid_sel),
      .ready_i(slv_resp_cut.ar_ready),
      .data_o (slv_ar_select)
  );

  assign slv_resp_o.ar_ready  = slv_ar_ready_chan & slv_ar_ready_sel;
  assign slv_req_cut.ar_valid = slv_ar_valid_chan & slv_ar_valid_sel;

  spill_register #(
      .T     (b_chan_t),
      .Bypass(~SpillB)
  ) i_b_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_resp_cut.b_valid),
      .ready_o(slv_req_cut.b_ready),
      .data_i (slv_resp_cut.b),
      .valid_o(slv_resp_o.b_valid),
      .ready_i(slv_req_i.b_ready),
      .data_o (slv_resp_o.b)
  );
  spill_register #(
      .T     (r_chan_t),
      .Bypass(~SpillR)
  ) i_r_spill_reg (
      .clk_i,
      .rst_ni,
      .valid_i(slv_resp_cut.r_valid),
      .ready_o(slv_req_cut.r_ready),
      .data_i (slv_resp_cut.r),
      .valid_o(slv_resp_o.r_valid),
      .ready_i(slv_req_i.r_ready),
      .data_o (slv_resp_o.r)
  );

  axi_demux_simple #(
      .AxiIdWidth (AxiIdWidth),
      .AtopSupport(AtopSupport),
      .axi_req_t  (axi_req_t),
      .axi_resp_t (axi_resp_t),
      .NoMstPorts (NoMstPorts),
      .MaxTrans   (MaxTrans),
      .AxiLookBits(AxiLookBits),
      .UniqueIds  (UniqueIds)
  ) i_demux_simple (
      .clk_i,
      .rst_ni,
      .test_i,

      .slv_req_i      (slv_req_cut),
      .slv_aw_select_i(slv_aw_select),
      .slv_ar_select_i(slv_ar_select),
      .slv_resp_o     (slv_resp_cut),
      .mst_reqs_o     (mst_reqs_o),
      .mst_resps_i    (mst_resps_i)
  );

endmodule
