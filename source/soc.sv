module soc;

  localparam axi_pkg::xbar_cfg_t Cfg = '{
      NoSlvPorts : soc_pkg::NUM_MASTERS,
      NoMstPorts : soc_pkg::NUM_SLAVES,
      MaxMstTrans: 1,
      MaxSlvTrans: 1,
      FallThrough: 0,
      LatencyMode: axi_pkg::CUT_ALL_AX,
      PipelineStages: 1,
      AxiIdWidthSlvPorts: soc_pkg::NOC_M_ID_WIDTH,
      AxiIdUsedSlvPorts: soc_pkg::NOC_M_ID_WIDTH,
      UniqueIds: 1,
      AxiAddrWidth: soc_pkg::NOC_ADDR_WIDTH,
      AxiDataWidth: soc_pkg::NOC_DATA_WIDTH,
      NoAddrRules: soc_pkg::NumXbarRules
  };

  soc_pkg::m_req_t  [soc_pkg::NUM_MASTERS-1:0] m_req;
  soc_pkg::m_resp_t [soc_pkg::NUM_MASTERS-1:0] m_resp;
  soc_pkg::s_req_t  [ soc_pkg::NUM_SLAVES-1:0] s_req;
  soc_pkg::s_resp_t [ soc_pkg::NUM_SLAVES-1:0] s_resp;

  for (genvar core = 0; core < soc_pkg::NUM_CORE; core++) begin : g_cores
    ariane #(
        .DmBaseAddress(soc_pkg::DM_BASE_ADDR),
        .CachedAddrBeg(soc_pkg::CACHEABLE_ADDR_START)
    ) u_core_0 (
        .clk_i(),
        .rst_ni(),
        .boot_addr_i(),
        .hart_id_i(),
        .irq_i(),
        .ipi_i(),
        .time_irq_i(),
        .debug_req_i(),
        .axi_req_o(),
        .axi_resp_i()
    );
  end

  axi_ram #(
      .MEM_BASE(soc_pkg::RAM_BASE),
      .MEM_SIZE(soc_pkg::RAM_SIZE),
      .req_t   (soc_pkg::s_req_t),
      .resp_t  (soc_pkg::s_resp_t)
  ) u_ddr (
      .clk_i  (),
      .arst_ni(),
      .req_i  (),
      .resp_o ()
  );

  axi_xbar #(
      .Cfg          (Cfg),
      .ATOPs        (1'b1),
      .Connectivity ('1),
      .slv_aw_chan_t(soc_pkg::m_aw_chan_t),
      .mst_aw_chan_t(soc_pkg::s_aw_chan_t),
      .w_chan_t     (soc_pkg::m_w_chan_t),
      .slv_b_chan_t (soc_pkg::m_b_chan_t),
      .mst_b_chan_t (soc_pkg::s_b_chan_t),
      .slv_ar_chan_t(soc_pkg::m_ar_chan_t),
      .mst_ar_chan_t(soc_pkg::s_ar_chan_t),
      .slv_r_chan_t (soc_pkg::m_r_chan_t),
      .mst_r_chan_t (soc_pkg::s_r_chan_t),
      .slv_req_t    (soc_pkg::m_req_t),
      .slv_resp_t   (soc_pkg::m_resp_t),
      .mst_req_t    (soc_pkg::s_req_t),
      .mst_resp_t   (soc_pkg::s_resp_t),
      .rule_t       (axi_pkg::xbar_rule_64_t)
  ) u_xbar (
      .clk_i(),
      .rst_ni(),
      .test_i(),
      .slv_ports_req_i(m_req),
      .slv_ports_resp_o(m_resp),
      .mst_ports_req_o(s_req),
      .mst_ports_resp_i(s_resp),
      .addr_map_i(soc_pkg::XbarRule),
      .en_default_mst_port_i('0),
      .default_mst_port_i('0)
  );

endmodule
