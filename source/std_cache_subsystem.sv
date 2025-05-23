import ariane_pkg::*;
import std_cache_pkg::*;module std_cache_subsystem #(
  parameter logic [63:0] CACHE_START_ADDR = 64'h4000_0000
) (
    input logic                            clk_i,
    input logic                            rst_ni,
    input riscv_pkg::priv_lvl_t                priv_lvl_i,

    input  logic                           icache_en_i,            
    input  logic                           icache_flush_i,         
    output logic                           icache_miss_o,          

    input  icache_areq_i_t                 icache_areq_i,          
    output icache_areq_o_t                 icache_areq_o,

    input  icache_dreq_i_t                 icache_dreq_i,          
    output icache_dreq_o_t                 icache_dreq_o,

    input  amo_req_t                       amo_req_i,
    output amo_resp_t                      amo_resp_o,

    input  logic                           dcache_enable_i,        
    input  logic                           dcache_flush_i,         
    output logic                           dcache_flush_ack_o,     
    output logic                           dcache_miss_o,          
    output logic                           wbuffer_empty_o,        

    input  dcache_req_i_t   [2:0]          dcache_req_ports_i,     
    output dcache_req_o_t   [2:0]          dcache_req_ports_o,     

    output ariane_axi_pkg::m_req_t               axi_req_o,
    input  ariane_axi_pkg::m_resp_t              axi_resp_i
);

  assign wbuffer_empty_o = 1'b1;

    ariane_axi_pkg::m_req_t  axi_req_icache;
    ariane_axi_pkg::m_resp_t axi_resp_icache;
    ariane_axi_pkg::m_req_t  axi_req_bypass;
    ariane_axi_pkg::m_resp_t axi_resp_bypass;
    ariane_axi_pkg::m_req_t  axi_req_data;
    ariane_axi_pkg::m_resp_t axi_resp_data;

    std_icache i_icache (
        .clk_i      ( clk_i                 ),
        .rst_ni     ( rst_ni                ),
        .priv_lvl_i ( priv_lvl_i            ),
        .flush_i    ( icache_flush_i        ),
        .en_i       ( icache_en_i           ),
        .miss_o     ( icache_miss_o         ),
        .areq_i     ( icache_areq_i         ),
        .areq_o     ( icache_areq_o         ),
        .dreq_i     ( icache_dreq_i         ),
        .dreq_o     ( icache_dreq_o         ),
        .axi_req_o  ( axi_req_icache        ),
        .axi_resp_i ( axi_resp_icache       )
    );

   std_nbdcache #(
      .CACHE_START_ADDR ( CACHE_START_ADDR )
   ) i_nbdcache (
      .clk_i,
      .rst_ni,
      .enable_i     ( dcache_enable_i        ),
      .flush_i      ( dcache_flush_i         ),
      .flush_ack_o  ( dcache_flush_ack_o     ),
      .miss_o       ( dcache_miss_o          ),
      .axi_bypass_o ( axi_req_bypass         ),
      .axi_bypass_i ( axi_resp_bypass        ),
      .axi_data_o   ( axi_req_data           ),
      .axi_data_i   ( axi_resp_data          ),
      .req_ports_i  ( dcache_req_ports_i     ),
      .req_ports_o  ( dcache_req_ports_o     ),
      .amo_req_i,
      .amo_resp_o
   );

    logic [1:0] w_select, w_select_fifo, w_select_arbiter;
    logic w_fifo_empty;

    stream_arbiter #(
        .DATA_T ( ariane_axi_pkg::m_ar_chan_t ),
        .N_INP  ( 3                     )
    ) i_stream_arbiter_ar (
        .clk_i,
        .rst_ni,
        .inp_data_i  ( {axi_req_icache.ar, axi_req_bypass.ar, axi_req_data.ar} ),
        .inp_valid_i ( {axi_req_icache.ar_valid, axi_req_bypass.ar_valid, axi_req_data.ar_valid} ),
        .inp_ready_o ( {axi_resp_icache.ar_ready, axi_resp_bypass.ar_ready, axi_resp_data.ar_ready} ),
        .oup_data_o  ( axi_req_o.ar        ),
        .oup_valid_o ( axi_req_o.ar_valid  ),
        .oup_ready_i ( axi_resp_i.ar_ready )
    );

    stream_arbiter #(
        .DATA_T ( ariane_axi_pkg::m_aw_chan_t ),
        .N_INP  ( 3                     )
    ) i_stream_arbiter_aw (
        .clk_i,
        .rst_ni,
        .inp_data_i  ( {axi_req_icache.aw, axi_req_bypass.aw, axi_req_data.aw} ),
        .inp_valid_i ( {axi_req_icache.aw_valid, axi_req_bypass.aw_valid, axi_req_data.aw_valid} ),
        .inp_ready_o ( {axi_resp_icache.aw_ready, axi_resp_bypass.aw_ready, axi_resp_data.aw_ready} ),
        .oup_data_o  ( axi_req_o.aw        ),
        .oup_valid_o ( axi_req_o.aw_valid  ),
        .oup_ready_i ( axi_resp_i.aw_ready )
    );

    always_comb begin
        w_select = 0;
        unique case (axi_req_o.aw.id)
            4'b1100:                            w_select = 2; 
            4'b1000, 4'b1001, 4'b1010, 4'b1011: w_select = 1; 
            default:                            w_select = 0; 
        endcase
    end

    fifo_v3 #(
      .DATA_WIDTH   ( 2    ),

      .DEPTH        ( 4    )
    ) i_fifo_w_channel (
      .clk_i      ( clk_i           ),
      .rst_ni     ( rst_ni          ),
      .flush_i    ( 1'b0            ),
      .testmode_i ( 1'b0            ),
      .full_o     (                 ), 
      .empty_o    ( w_fifo_empty    ),
      .usage_o    (                 ), 
      .data_i     ( w_select        ),

      .push_i     ( axi_req_o.aw_valid & axi_resp_i.aw_ready ),

      .data_o     ( w_select_fifo   ),

      .pop_i      ( axi_req_o.w_valid & axi_resp_i.w_ready & axi_req_o.w.last )
    );

    assign w_select_arbiter = (w_fifo_empty) ? 0 : w_select_fifo;

    stream_mux #(
        .DATA_T ( ariane_axi_pkg::m_w_chan_t ),
        .N_INP  ( 3                    )
    ) i_stream_mux_w (
        .inp_data_i  ( {axi_req_data.w, axi_req_bypass.w, axi_req_icache.w} ),
        .inp_valid_i ( {axi_req_data.w_valid, axi_req_bypass.w_valid, axi_req_icache.w_valid} ),
        .inp_ready_o ( {axi_resp_data.w_ready, axi_resp_bypass.w_ready, axi_resp_icache.w_ready} ),
        .inp_sel_i   ( w_select_arbiter   ),
        .oup_data_o  ( axi_req_o.w        ),
        .oup_valid_o ( axi_req_o.w_valid  ),
        .oup_ready_i ( axi_resp_i.w_ready )
    );

    assign axi_resp_icache.r = axi_resp_i.r;
    assign axi_resp_bypass.r = axi_resp_i.r;
    assign axi_resp_data.r   = axi_resp_i.r;

    logic [1:0] r_select;

    always_comb begin
        r_select = 0;
        unique case (axi_resp_i.r.id)
            4'b1100:                            r_select = 0; 
            4'b1000, 4'b1001, 4'b1010, 4'b1011: r_select = 1; 
            4'b0000:                            r_select = 2; 
            default:                            r_select = 0;
        endcase
    end

    stream_demux #(
        .N_OUP ( 3 )
    ) i_stream_demux_r (
        .inp_valid_i ( axi_resp_i.r_valid ),
        .inp_ready_o ( axi_req_o.r_ready  ),
        .oup_sel_i   ( r_select           ),
        .oup_valid_o ( {axi_resp_icache.r_valid, axi_resp_bypass.r_valid, axi_resp_data.r_valid} ),
        .oup_ready_i ( {axi_req_icache.r_ready, axi_req_bypass.r_ready, axi_req_data.r_ready} )
    );

    logic [1:0] b_select;

    assign axi_resp_icache.b = axi_resp_i.b;
    assign axi_resp_bypass.b = axi_resp_i.b;
    assign axi_resp_data.b   = axi_resp_i.b;

    always_comb begin
        b_select = 0;
        unique case (axi_resp_i.b.id)
            4'b1100:                            b_select = 0; 
            4'b1000, 4'b1001, 4'b1010, 4'b1011: b_select = 1; 
            4'b0000:                            b_select = 2; 
            default:                            b_select = 0;
        endcase
    end

    stream_demux #(
        .N_OUP ( 3 )
    ) i_stream_demux_b (
        .inp_valid_i ( axi_resp_i.b_valid ),
        .inp_ready_o ( axi_req_o.b_ready  ),
        .oup_sel_i   ( b_select           ),
        .oup_valid_o ( {axi_resp_icache.b_valid, axi_resp_bypass.b_valid, axi_resp_data.b_valid} ),
        .oup_ready_i ( {axi_req_icache.b_ready, axi_req_bypass.b_ready, axi_req_data.b_ready} )
    );

endmodule 
