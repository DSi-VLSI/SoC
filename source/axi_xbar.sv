module axi_xbar
import cf_math_pkg::idx_width;
#(

  parameter axi_pkg::xbar_cfg_t Cfg                                   = '0,

  parameter bit  ATOPs                                                = 1'b1,

  parameter bit [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts-1:0] Connectivity = '1,

  parameter type slv_aw_chan_t                                        = logic,

  parameter type mst_aw_chan_t                                        = logic,

  parameter type w_chan_t                                             = logic,

  parameter type slv_b_chan_t                                         = logic,

  parameter type mst_b_chan_t                                         = logic,

  parameter type slv_ar_chan_t                                        = logic,

  parameter type mst_ar_chan_t                                        = logic,

  parameter type slv_r_chan_t                                         = logic,

  parameter type mst_r_chan_t                                         = logic,

  parameter type slv_req_t                                            = logic,

  parameter type slv_resp_t                                           = logic,

  parameter type mst_req_t                                            = logic,

  parameter type mst_resp_t                                           = logic,

  parameter type rule_t                                               = axi_pkg::xbar_rule_64_t
) (

  input  logic                                                          clk_i,

  input  logic                                                          rst_ni,

  input  logic                                                          test_i,

  input  slv_req_t  [Cfg.NoSlvPorts-1:0]                                slv_ports_req_i,

  output slv_resp_t [Cfg.NoSlvPorts-1:0]                                slv_ports_resp_o,

  output mst_req_t  [Cfg.NoMstPorts-1:0]                                mst_ports_req_o,

  input  mst_resp_t [Cfg.NoMstPorts-1:0]                                mst_ports_resp_i,

  input  rule_t     [Cfg.NoAddrRules-1:0]                               addr_map_i,

  input  logic      [Cfg.NoSlvPorts-1:0]                                en_default_mst_port_i,

  input  logic      [Cfg.NoSlvPorts-1:0][idx_width(Cfg.NoMstPorts)-1:0] default_mst_port_i
);

  slv_req_t  [Cfg.NoMstPorts-1:0][Cfg.NoSlvPorts-1:0] mst_reqs;
  slv_resp_t [Cfg.NoMstPorts-1:0][Cfg.NoSlvPorts-1:0] mst_resps;

  axi_xbar_unmuxed #(
    .Cfg          (Cfg),
    .ATOPs        (ATOPs),
    .Connectivity (Connectivity),
    .aw_chan_t    (slv_aw_chan_t),
    .w_chan_t     (w_chan_t),
    .b_chan_t     (slv_b_chan_t),
    .ar_chan_t    (slv_ar_chan_t),
    .r_chan_t     (slv_r_chan_t),
    .req_t        (slv_req_t),
    .resp_t       (slv_resp_t),
    .rule_t       (rule_t)
  ) i_xbar_unmuxed (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_ports_req_i,
    .slv_ports_resp_o,
    .mst_ports_req_o  (mst_reqs),
    .mst_ports_resp_i (mst_resps),
    .addr_map_i,
    .en_default_mst_port_i,
    .default_mst_port_i
  );

  for (genvar i = 0; i < Cfg.NoMstPorts; i++) begin : gen_mst_port_mux
    axi_mux #(
      .SlvAxiIDWidth ( Cfg.AxiIdWidthSlvPorts ), 
      .slv_aw_chan_t ( slv_aw_chan_t          ), 
      .mst_aw_chan_t ( mst_aw_chan_t          ), 
      .w_chan_t      ( w_chan_t               ), 
      .slv_b_chan_t  ( slv_b_chan_t           ), 
      .mst_b_chan_t  ( mst_b_chan_t           ), 
      .slv_ar_chan_t ( slv_ar_chan_t          ), 
      .mst_ar_chan_t ( mst_ar_chan_t          ), 
      .slv_r_chan_t  ( slv_r_chan_t           ), 
      .mst_r_chan_t  ( mst_r_chan_t           ), 
      .slv_req_t     ( slv_req_t              ),
      .slv_resp_t    ( slv_resp_t             ),
      .mst_req_t     ( mst_req_t              ),
      .mst_resp_t    ( mst_resp_t             ),
      .NoSlvPorts    ( Cfg.NoSlvPorts         ), 
      .MaxWTrans     ( Cfg.MaxSlvTrans        ),
      .FallThrough   ( Cfg.FallThrough        ),
      .SpillAw       ( Cfg.LatencyMode[4]     ),
      .SpillW        ( Cfg.LatencyMode[3]     ),
      .SpillB        ( Cfg.LatencyMode[2]     ),
      .SpillAr       ( Cfg.LatencyMode[1]     ),
      .SpillR        ( Cfg.LatencyMode[0]     )
    ) i_axi_mux (
      .clk_i,   
      .rst_ni,  
      .test_i,  
      .slv_reqs_i  ( mst_reqs[i]         ),
      .slv_resps_o ( mst_resps[i]        ),
      .mst_req_o   ( mst_ports_req_o[i]  ),
      .mst_resp_i  ( mst_ports_resp_i[i] )
    );
  end

endmodule
