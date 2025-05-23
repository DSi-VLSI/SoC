`include "common_cells/registers.svh"

module axi_mux #(

  parameter int unsigned SlvAxiIDWidth = 32'd0, 
  parameter type         slv_aw_chan_t = logic, 
  parameter type         mst_aw_chan_t = logic, 
  parameter type         w_chan_t      = logic, 
  parameter type         slv_b_chan_t  = logic, 
  parameter type         mst_b_chan_t  = logic, 
  parameter type         slv_ar_chan_t = logic, 
  parameter type         mst_ar_chan_t = logic, 
  parameter type         slv_r_chan_t  = logic, 
  parameter type         mst_r_chan_t  = logic, 
  parameter type         slv_req_t     = logic, 
  parameter type         slv_resp_t    = logic, 
  parameter type         mst_req_t     = logic, 
  parameter type         mst_resp_t    = logic, 
  parameter int unsigned NoSlvPorts    = 32'd0, 

  parameter int unsigned MaxWTrans     = 32'd8,

  parameter bit          FallThrough   = 1'b0,

  parameter bit          SpillAw       = 1'b1,
  parameter bit          SpillW        = 1'b0,
  parameter bit          SpillB        = 1'b0,

  parameter bit          SpillAr       = 1'b1,
  parameter bit          SpillR        = 1'b0
) (
  input  logic                       clk_i,    
  input  logic                       rst_ni,   
  input  logic                       test_i,   

  input  slv_req_t  [NoSlvPorts-1:0] slv_reqs_i,
  output slv_resp_t [NoSlvPorts-1:0] slv_resps_o,

  output mst_req_t                   mst_req_o,
  input  mst_resp_t                  mst_resp_i
);

  localparam int unsigned MstIdxBits    = $clog2(NoSlvPorts);
  localparam int unsigned MstAxiIDWidth = SlvAxiIDWidth + MstIdxBits;

  if (NoSlvPorts == 32'h1) begin : gen_no_mux
    spill_register #(
      .T       ( mst_aw_chan_t ),
      .Bypass  ( ~SpillAw      )
    ) i_aw_spill_reg (
      .clk_i   ( clk_i                    ),
      .rst_ni  ( rst_ni                   ),
      .valid_i ( slv_reqs_i[0].aw_valid   ),
      .ready_o ( slv_resps_o[0].aw_ready  ),
      .data_i  ( slv_reqs_i[0].aw         ),
      .valid_o ( mst_req_o.aw_valid       ),
      .ready_i ( mst_resp_i.aw_ready      ),
      .data_o  ( mst_req_o.aw             )
    );
    spill_register #(
      .T       ( w_chan_t ),
      .Bypass  ( ~SpillW  )
    ) i_w_spill_reg (
      .clk_i   ( clk_i                   ),
      .rst_ni  ( rst_ni                  ),
      .valid_i ( slv_reqs_i[0].w_valid   ),
      .ready_o ( slv_resps_o[0].w_ready  ),
      .data_i  ( slv_reqs_i[0].w         ),
      .valid_o ( mst_req_o.w_valid       ),
      .ready_i ( mst_resp_i.w_ready      ),
      .data_o  ( mst_req_o.w             )
    );
    spill_register #(
      .T       ( mst_b_chan_t ),
      .Bypass  ( ~SpillB      )
    ) i_b_spill_reg (
      .clk_i   ( clk_i                  ),
      .rst_ni  ( rst_ni                 ),
      .valid_i ( mst_resp_i.b_valid     ),
      .ready_o ( mst_req_o.b_ready      ),
      .data_i  ( mst_resp_i.b           ),
      .valid_o ( slv_resps_o[0].b_valid ),
      .ready_i ( slv_reqs_i[0].b_ready  ),
      .data_o  ( slv_resps_o[0].b       )
    );
    spill_register #(
      .T       ( mst_ar_chan_t ),
      .Bypass  ( ~SpillAr      )
    ) i_ar_spill_reg (
      .clk_i   ( clk_i                    ),
      .rst_ni  ( rst_ni                   ),
      .valid_i ( slv_reqs_i[0].ar_valid   ),
      .ready_o ( slv_resps_o[0].ar_ready  ),
      .data_i  ( slv_reqs_i[0].ar         ),
      .valid_o ( mst_req_o.ar_valid       ),
      .ready_i ( mst_resp_i.ar_ready      ),
      .data_o  ( mst_req_o.ar             )
    );
    spill_register #(
      .T       ( mst_r_chan_t ),
      .Bypass  ( ~SpillR      )
    ) i_r_spill_reg (
      .clk_i   ( clk_i                  ),
      .rst_ni  ( rst_ni                 ),
      .valid_i ( mst_resp_i.r_valid     ),
      .ready_o ( mst_req_o.r_ready      ),
      .data_i  ( mst_resp_i.r           ),
      .valid_o ( slv_resps_o[0].r_valid ),
      .ready_i ( slv_reqs_i[0].r_ready  ),
      .data_o  ( slv_resps_o[0].r       )
    );

  end else begin : gen_mux

    typedef logic [MstIdxBits-1:0] switch_id_t;

    mst_aw_chan_t [NoSlvPorts-1:0] slv_aw_chans;
    logic         [NoSlvPorts-1:0] slv_aw_valids, slv_aw_readies;
    w_chan_t      [NoSlvPorts-1:0] slv_w_chans;
    logic         [NoSlvPorts-1:0] slv_w_valids,  slv_w_readies;
    mst_b_chan_t  [NoSlvPorts-1:0] slv_b_chans;
    logic         [NoSlvPorts-1:0] slv_b_valids,  slv_b_readies;
    mst_ar_chan_t [NoSlvPorts-1:0] slv_ar_chans;
    logic         [NoSlvPorts-1:0] slv_ar_valids, slv_ar_readies;
    mst_r_chan_t  [NoSlvPorts-1:0] slv_r_chans;
    logic         [NoSlvPorts-1:0] slv_r_valids,  slv_r_readies;

    mst_aw_chan_t   mst_aw_chan;
    logic           mst_aw_valid, mst_aw_ready;

    logic           aw_valid,     aw_ready;

    logic           lock_aw_valid_d, lock_aw_valid_q;
    logic           load_aw_lock;

    logic           w_fifo_full,  w_fifo_empty;
    logic           w_fifo_push,  w_fifo_pop;
    switch_id_t     w_fifo_data;

    w_chan_t        mst_w_chan;
    logic           mst_w_valid,  mst_w_ready;

    switch_id_t     switch_b_id;

    mst_b_chan_t    mst_b_chan;
    logic           mst_b_valid;

    mst_ar_chan_t   mst_ar_chan;
    logic           ar_valid,     ar_ready;

    switch_id_t     switch_r_id;

    mst_r_chan_t    mst_r_chan;
    logic           mst_r_valid;

    for (genvar i = 0; i < NoSlvPorts; i++) begin : gen_id_prepend
      axi_id_prepend #(
        .NoBus            ( 32'd1               ), 
        .AxiIdWidthSlvPort( SlvAxiIDWidth       ),
        .AxiIdWidthMstPort( MstAxiIDWidth       ),
        .slv_aw_chan_t    ( slv_aw_chan_t       ),
        .slv_w_chan_t     ( w_chan_t            ),
        .slv_b_chan_t     ( slv_b_chan_t        ),
        .slv_ar_chan_t    ( slv_ar_chan_t       ),
        .slv_r_chan_t     ( slv_r_chan_t        ),
        .mst_aw_chan_t    ( mst_aw_chan_t       ),
        .mst_w_chan_t     ( w_chan_t            ),
        .mst_b_chan_t     ( mst_b_chan_t        ),
        .mst_ar_chan_t    ( mst_ar_chan_t       ),
        .mst_r_chan_t     ( mst_r_chan_t        )
      ) i_id_prepend (
        .pre_id_i         ( switch_id_t'(i)         ),
        .slv_aw_chans_i   ( slv_reqs_i[i].aw        ),
        .slv_aw_valids_i  ( slv_reqs_i[i].aw_valid  ),
        .slv_aw_readies_o ( slv_resps_o[i].aw_ready ),
        .slv_w_chans_i    ( slv_reqs_i[i].w         ),
        .slv_w_valids_i   ( slv_reqs_i[i].w_valid   ),
        .slv_w_readies_o  ( slv_resps_o[i].w_ready  ),
        .slv_b_chans_o    ( slv_resps_o[i].b        ),
        .slv_b_valids_o   ( slv_resps_o[i].b_valid  ),
        .slv_b_readies_i  ( slv_reqs_i[i].b_ready   ),
        .slv_ar_chans_i   ( slv_reqs_i[i].ar        ),
        .slv_ar_valids_i  ( slv_reqs_i[i].ar_valid  ),
        .slv_ar_readies_o ( slv_resps_o[i].ar_ready ),
        .slv_r_chans_o    ( slv_resps_o[i].r        ),
        .slv_r_valids_o   ( slv_resps_o[i].r_valid  ),
        .slv_r_readies_i  ( slv_reqs_i[i].r_ready   ),
        .mst_aw_chans_o   ( slv_aw_chans[i]         ),
        .mst_aw_valids_o  ( slv_aw_valids[i]        ),
        .mst_aw_readies_i ( slv_aw_readies[i]       ),
        .mst_w_chans_o    ( slv_w_chans[i]          ),
        .mst_w_valids_o   ( slv_w_valids[i]         ),
        .mst_w_readies_i  ( slv_w_readies[i]        ),
        .mst_b_chans_i    ( slv_b_chans[i]          ),
        .mst_b_valids_i   ( slv_b_valids[i]         ),
        .mst_b_readies_o  ( slv_b_readies[i]        ),
        .mst_ar_chans_o   ( slv_ar_chans[i]         ),
        .mst_ar_valids_o  ( slv_ar_valids[i]        ),
        .mst_ar_readies_i ( slv_ar_readies[i]       ),
        .mst_r_chans_i    ( slv_r_chans[i]          ),
        .mst_r_valids_i   ( slv_r_valids[i]         ),
        .mst_r_readies_o  ( slv_r_readies[i]        )
      );
    end

    rr_arb_tree #(
      .NumIn    ( NoSlvPorts    ),
      .DataType ( mst_aw_chan_t ),
      .AxiVldRdy( 1'b1          ),
      .LockIn   ( 1'b1          )
    ) i_aw_arbiter (
      .clk_i  ( clk_i           ),
      .rst_ni ( rst_ni          ),
      .flush_i( 1'b0            ),
      .rr_i   ( '0              ),
      .req_i  ( slv_aw_valids   ),
      .gnt_o  ( slv_aw_readies  ),
      .data_i ( slv_aw_chans    ),
      .gnt_i  ( aw_ready        ),
      .req_o  ( aw_valid        ),
      .data_o ( mst_aw_chan     ),
      .idx_o  (                 )
    );

    always_comb begin

      lock_aw_valid_d = lock_aw_valid_q;
      load_aw_lock    = 1'b0;
      w_fifo_push     = 1'b0;
      mst_aw_valid    = 1'b0;
      aw_ready        = 1'b0;

      if (lock_aw_valid_q) begin
        mst_aw_valid = 1'b1;

        if (mst_aw_ready) begin
          aw_ready        = 1'b1;
          lock_aw_valid_d = 1'b0;
          load_aw_lock    = 1'b1;
        end
      end else begin
        if (!w_fifo_full && aw_valid) begin
          mst_aw_valid = 1'b1;
          w_fifo_push = 1'b1;
          if (mst_aw_ready) begin
            aw_ready = 1'b1;
          end else begin

            lock_aw_valid_d = 1'b1;
            load_aw_lock    = 1'b1;
          end
        end
      end
    end

    `FFLARN(lock_aw_valid_q, lock_aw_valid_d, load_aw_lock, '0, clk_i, rst_ni)

    fifo_v3 #(
      .FALL_THROUGH ( FallThrough ),
      .DEPTH        ( MaxWTrans   ),
      .dtype        ( switch_id_t )
    ) i_w_fifo (
      .clk_i     ( clk_i                                     ),
      .rst_ni    ( rst_ni                                    ),
      .flush_i   ( 1'b0                                      ),
      .testmode_i( test_i                                    ),
      .full_o    ( w_fifo_full                               ),
      .empty_o   ( w_fifo_empty                              ),
      .usage_o   (                                           ),
      .data_i    ( mst_aw_chan.id[SlvAxiIDWidth+:MstIdxBits] ),
      .push_i    ( w_fifo_push                               ),
      .data_o    ( w_fifo_data                               ),
      .pop_i     ( w_fifo_pop                                )
    );

    spill_register #(
      .T       ( mst_aw_chan_t ),
      .Bypass  ( ~SpillAw      ) 
    ) i_aw_spill_reg (
      .clk_i   ( clk_i               ),
      .rst_ni  ( rst_ni              ),
      .valid_i ( mst_aw_valid        ),
      .ready_o ( mst_aw_ready        ),
      .data_i  ( mst_aw_chan         ),
      .valid_o ( mst_req_o.aw_valid  ),
      .ready_i ( mst_resp_i.aw_ready ),
      .data_o  ( mst_req_o.aw        )
    );

    assign mst_w_chan = slv_w_chans[w_fifo_data];
    always_comb begin

      mst_w_valid   = 1'b0;
      slv_w_readies = '0;
      w_fifo_pop    = 1'b0;

      if (!w_fifo_empty) begin

        mst_w_valid                = slv_w_valids[w_fifo_data];
        slv_w_readies[w_fifo_data] = mst_w_ready;

        w_fifo_pop = slv_w_valids[w_fifo_data] & mst_w_ready & mst_w_chan.last;
      end
    end

    spill_register #(
      .T       ( w_chan_t ),
      .Bypass  ( ~SpillW  )
    ) i_w_spill_reg (
      .clk_i   ( clk_i              ),
      .rst_ni  ( rst_ni             ),
      .valid_i ( mst_w_valid        ),
      .ready_o ( mst_w_ready        ),
      .data_i  ( mst_w_chan         ),
      .valid_o ( mst_req_o.w_valid  ),
      .ready_i ( mst_resp_i.w_ready ),
      .data_o  ( mst_req_o.w        )
    );

    assign slv_b_chans  = {NoSlvPorts{mst_b_chan}};

    assign switch_b_id  = mst_b_chan.id[SlvAxiIDWidth+:MstIdxBits];
    assign slv_b_valids = (mst_b_valid) ? (1 << switch_b_id) : '0;

    spill_register #(
      .T       ( mst_b_chan_t ),
      .Bypass  ( ~SpillB      )
    ) i_b_spill_reg (
      .clk_i   ( clk_i                      ),
      .rst_ni  ( rst_ni                     ),
      .valid_i ( mst_resp_i.b_valid         ),
      .ready_o ( mst_req_o.b_ready          ),
      .data_i  ( mst_resp_i.b               ),
      .valid_o ( mst_b_valid                ),
      .ready_i ( slv_b_readies[switch_b_id] ),
      .data_o  ( mst_b_chan                 )
    );

    rr_arb_tree #(
      .NumIn    ( NoSlvPorts    ),
      .DataType ( mst_ar_chan_t ),
      .AxiVldRdy( 1'b1          ),
      .LockIn   ( 1'b1          )
    ) i_ar_arbiter (
      .clk_i  ( clk_i           ),
      .rst_ni ( rst_ni          ),
      .flush_i( 1'b0            ),
      .rr_i   ( '0              ),
      .req_i  ( slv_ar_valids   ),
      .gnt_o  ( slv_ar_readies  ),
      .data_i ( slv_ar_chans    ),
      .gnt_i  ( ar_ready        ),
      .req_o  ( ar_valid        ),
      .data_o ( mst_ar_chan     ),
      .idx_o  (                 )
    );

    spill_register #(
      .T       ( mst_ar_chan_t ),
      .Bypass  ( ~SpillAr      )
    ) i_ar_spill_reg (
      .clk_i   ( clk_i               ),
      .rst_ni  ( rst_ni              ),
      .valid_i ( ar_valid            ),
      .ready_o ( ar_ready            ),
      .data_i  ( mst_ar_chan         ),
      .valid_o ( mst_req_o.ar_valid  ),
      .ready_i ( mst_resp_i.ar_ready ),
      .data_o  ( mst_req_o.ar        )
    );

    assign slv_r_chans  = {NoSlvPorts{mst_r_chan}};

    assign switch_r_id  = mst_r_chan.id[SlvAxiIDWidth+:MstIdxBits];
    assign slv_r_valids = (mst_r_valid) ? (1 << switch_r_id) : '0;

    spill_register #(
      .T       ( mst_r_chan_t ),
      .Bypass  ( ~SpillR      )
    ) i_r_spill_reg (
      .clk_i   ( clk_i                      ),
      .rst_ni  ( rst_ni                     ),
      .valid_i ( mst_resp_i.r_valid         ),
      .ready_o ( mst_req_o.r_ready          ),
      .data_i  ( mst_resp_i.r               ),
      .valid_o ( mst_r_valid                ),
      .ready_i ( slv_r_readies[switch_r_id] ),
      .data_o  ( mst_r_chan                 )
    );
  end

endmodule
