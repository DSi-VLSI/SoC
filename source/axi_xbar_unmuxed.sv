module axi_xbar_unmuxed
import cf_math_pkg::idx_width;
#(

  parameter axi_pkg::xbar_cfg_t Cfg                                   = '0,

  parameter bit  ATOPs                                                = 1'b1,

  parameter bit [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts-1:0] Connectivity = '1,

  parameter type aw_chan_t                                            = logic,

  parameter type w_chan_t                                             = logic,

  parameter type b_chan_t                                             = logic,

  parameter type ar_chan_t                                            = logic,

  parameter type r_chan_t                                             = logic,

  parameter type req_t                                                = logic,

  parameter type resp_t                                               = logic,

  parameter type rule_t                                               = axi_pkg::xbar_rule_64_t
) (

  input  logic                                                          clk_i,

  input  logic                                                          rst_ni,

  input  logic                                                          test_i,

  input  req_t  [Cfg.NoSlvPorts-1:0]                                    slv_ports_req_i,

  output resp_t [Cfg.NoSlvPorts-1:0]                                    slv_ports_resp_o,

  output req_t  [Cfg.NoMstPorts-1:0][Cfg.NoSlvPorts-1:0]                mst_ports_req_o,

  input  resp_t [Cfg.NoMstPorts-1:0][Cfg.NoSlvPorts-1:0]                mst_ports_resp_i,

  input  rule_t     [Cfg.NoAddrRules-1:0]                               addr_map_i,

  input  logic      [Cfg.NoSlvPorts-1:0]                                en_default_mst_port_i,

  input  logic      [Cfg.NoSlvPorts-1:0][idx_width(Cfg.NoMstPorts)-1:0] default_mst_port_i
);

  typedef logic [Cfg.AxiAddrWidth-1:0] addr_t;

  typedef logic [idx_width(Cfg.NoMstPorts + 1)-1:0] mst_port_idx_t;

  req_t  [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts:0]  slv_reqs;
  resp_t [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts:0]  slv_resps;

  localparam int unsigned cfg_NoMstPorts = Cfg.NoMstPorts;

  for (genvar i = 0; i < Cfg.NoSlvPorts; i++) begin : gen_slv_port_demux
    logic [idx_width(Cfg.NoMstPorts)-1:0] dec_aw,        dec_ar;
    mst_port_idx_t                        slv_aw_select, slv_ar_select;
    logic                                 dec_aw_valid,  dec_aw_error;
    logic                                 dec_ar_valid,  dec_ar_error;

    addr_decode #(
      .NoIndices  ( Cfg.NoMstPorts  ),
      .NoRules    ( Cfg.NoAddrRules ),
      .addr_t     ( addr_t          ),
      .rule_t     ( rule_t          )
    ) i_axi_aw_decode (
      .addr_i           ( slv_ports_req_i[i].aw.addr ),
      .addr_map_i       ( addr_map_i                 ),
      .idx_o            ( dec_aw                     ),
      .dec_valid_o      ( dec_aw_valid               ),
      .dec_error_o      ( dec_aw_error               ),
      .en_default_idx_i ( en_default_mst_port_i[i]   ),
      .default_idx_i    ( default_mst_port_i[i]      )
    );

    addr_decode #(
      .NoIndices  ( Cfg.NoMstPorts  ),
      .addr_t     ( addr_t          ),
      .NoRules    ( Cfg.NoAddrRules ),
      .rule_t     ( rule_t          )
    ) i_axi_ar_decode (
      .addr_i           ( slv_ports_req_i[i].ar.addr ),
      .addr_map_i       ( addr_map_i                 ),
      .idx_o            ( dec_ar                     ),
      .dec_valid_o      ( dec_ar_valid               ),
      .dec_error_o      ( dec_ar_error               ),
      .en_default_idx_i ( en_default_mst_port_i[i]   ),
      .default_idx_i    ( default_mst_port_i[i]      )
    );

    assign slv_aw_select = (dec_aw_error) ?
        mst_port_idx_t'(Cfg.NoMstPorts) : mst_port_idx_t'(dec_aw);
    assign slv_ar_select = (dec_ar_error) ?
        mst_port_idx_t'(Cfg.NoMstPorts) : mst_port_idx_t'(dec_ar);

    axi_demux #(
      .AxiIdWidth     ( Cfg.AxiIdWidthSlvPorts ),  
      .AtopSupport    ( ATOPs                  ),
      .aw_chan_t      ( aw_chan_t              ),  
      .w_chan_t       ( w_chan_t               ),  
      .b_chan_t       ( b_chan_t               ),  
      .ar_chan_t      ( ar_chan_t              ),  
      .r_chan_t       ( r_chan_t               ),  
      .axi_req_t      ( req_t                  ),
      .axi_resp_t     ( resp_t                 ),
      .NoMstPorts     ( Cfg.NoMstPorts + 1     ),
      .MaxTrans       ( Cfg.MaxMstTrans        ),
      .AxiLookBits    ( Cfg.AxiIdUsedSlvPorts  ),
      .UniqueIds      ( Cfg.UniqueIds          ),
      .SpillAw        ( Cfg.LatencyMode[9]     ),
      .SpillW         ( Cfg.LatencyMode[8]     ),
      .SpillB         ( Cfg.LatencyMode[7]     ),
      .SpillAr        ( Cfg.LatencyMode[6]     ),
      .SpillR         ( Cfg.LatencyMode[5]     )
    ) i_axi_demux (
      .clk_i,   
      .rst_ni,  
      .test_i,  
      .slv_req_i       ( slv_ports_req_i[i]  ),
      .slv_aw_select_i ( slv_aw_select       ),
      .slv_ar_select_i ( slv_ar_select       ),
      .slv_resp_o      ( slv_ports_resp_o[i] ),
      .mst_reqs_o      ( slv_reqs[i]         ),
      .mst_resps_i     ( slv_resps[i]        )
    );

    axi_err_slv #(
      .AxiIdWidth  ( Cfg.AxiIdWidthSlvPorts ),
      .axi_req_t   ( req_t                  ),
      .axi_resp_t  ( resp_t                 ),
      .Resp        ( axi_pkg::RESP_DECERR   ),
      .ATOPs       ( ATOPs                  ),
      .MaxTrans    ( 4                      )   

    ) i_axi_err_slv (
      .clk_i,   
      .rst_ni,  
      .test_i,  

      .slv_req_i  ( slv_reqs[i][Cfg.NoMstPorts]   ),
      .slv_resp_o ( slv_resps[i][cfg_NoMstPorts]  )
    );
  end

  for (genvar i = 0; i < Cfg.NoSlvPorts; i++) begin : gen_xbar_slv_cross
    for (genvar j = 0; j < Cfg.NoMstPorts; j++) begin : gen_xbar_mst_cross
      if (Connectivity[i][j]) begin : gen_connection
        axi_multicut #(
          .NoCuts     ( Cfg.PipelineStages ),
          .aw_chan_t  ( aw_chan_t          ),
          .w_chan_t   ( w_chan_t           ),
          .b_chan_t   ( b_chan_t           ),
          .ar_chan_t  ( ar_chan_t          ),
          .r_chan_t   ( r_chan_t           ),
          .axi_req_t  ( req_t              ),
          .axi_resp_t ( resp_t             )
        ) i_axi_multicut_xbar_pipeline (
          .clk_i,
          .rst_ni,
          .slv_req_i  ( slv_reqs[i][j]         ),
          .slv_resp_o ( slv_resps[i][j]        ),
          .mst_req_o  ( mst_ports_req_o[j][i]  ),
          .mst_resp_i ( mst_ports_resp_i[j][i] )
        );

      end else begin : gen_no_connection
        assign mst_ports_req_o[j][i] = '0;
        axi_err_slv #(
          .AxiIdWidth ( Cfg.AxiIdWidthSlvPorts  ),
          .axi_req_t  ( req_t                   ),
          .axi_resp_t ( resp_t                  ),
          .Resp       ( axi_pkg::RESP_DECERR    ),
          .ATOPs      ( ATOPs                   ),
          .MaxTrans   ( 1                       )
        ) i_axi_err_slv (
          .clk_i,
          .rst_ni,
          .test_i,
          .slv_req_i  ( slv_reqs[i][j]  ),
          .slv_resp_o ( slv_resps[i][j] )
        );
      end
    end
  end

endmodule
