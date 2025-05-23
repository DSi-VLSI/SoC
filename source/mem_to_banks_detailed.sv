module mem_to_banks_detailed #(

  parameter int unsigned AddrWidth = 32'd0,

  parameter int unsigned DataWidth = 32'd0,

  parameter int unsigned WUserWidth = 32'd0,

  parameter int unsigned RUserWidth = 32'd0,

  parameter int unsigned NumBanks  = 32'd1,

  parameter bit          HideStrb  = 1'b0,

  parameter int unsigned MaxTrans  = 32'd1,

  parameter int unsigned FifoDepth = 32'd1,

  parameter  type wuser_t     = logic [WUserWidth-1:0],

  localparam type addr_t      = logic [AddrWidth-1:0],

  localparam type inp_data_t  = logic [DataWidth-1:0],

  localparam type inp_strb_t  = logic [DataWidth/8-1:0],

  localparam type inp_ruser_t = logic [NumBanks-1:0][RUserWidth-1:0],

  localparam type oup_data_t  = logic [DataWidth/NumBanks-1:0],

  localparam type oup_strb_t  = logic [DataWidth/NumBanks/8-1:0],

  localparam type oup_ruser_t = logic [RUserWidth-1:0]
) (

  input  logic                       clk_i,

  input  logic                       rst_ni,

  input  logic                       req_i,

  output logic                       gnt_o,

  input  addr_t                      addr_i,

  input  inp_data_t                  wdata_i,

  input  inp_strb_t                  strb_i,

  input  wuser_t                     wuser_i,

  input  logic                       we_i,

  output logic                       rvalid_o,

  output inp_data_t                  rdata_o,

  output inp_ruser_t                 ruser_o,

  output logic       [NumBanks-1:0]  bank_req_o,

  input  logic       [NumBanks-1:0]  bank_gnt_i,

  output addr_t      [NumBanks-1:0]  bank_addr_o,

  output oup_data_t  [NumBanks-1:0]  bank_wdata_o,

  output oup_strb_t  [NumBanks-1:0]  bank_strb_o,

  output wuser_t     [NumBanks-1:0]  bank_wuser_o,

  output logic       [NumBanks-1:0]  bank_we_o,

  input  logic       [NumBanks-1:0]  bank_rvalid_i,

  input  oup_data_t  [NumBanks-1:0]  bank_rdata_i,

  input  oup_ruser_t [NumBanks-1:0]  bank_ruser_i
);

  localparam int unsigned DataBytes    = $bits(inp_strb_t);
  localparam int unsigned BitsPerBank  = $bits(oup_data_t);
  localparam int unsigned BytesPerBank = $bits(oup_strb_t);

  typedef struct packed {
    addr_t     addr;
    oup_data_t wdata;
    oup_strb_t strb;
    wuser_t    wuser;
    logic      we;
  } req_t;

  logic                 req_valid;
  logic [NumBanks-1:0]              req_ready,
                        resp_valid, resp_ready;
  req_t [NumBanks-1:0]  bank_req,
                        bank_oup;
  logic [NumBanks-1:0]  bank_req_internal,
                        bank_gnt_internal,
                        zero_strobe,
                        dead_response,
                        dead_response_unmasked;
  logic                 dead_write_fifo_full,
                        dead_write_fifo_empty;

  function automatic addr_t align_addr(input addr_t addr);
    return (addr >> $clog2(DataBytes)) << $clog2(DataBytes);
  endfunction

  assign req_valid = req_i & gnt_o;
  for (genvar i = 0; unsigned'(i) < NumBanks; i++) begin : gen_reqs
    assign bank_req[i].addr  = align_addr(addr_i) + i * BytesPerBank;
    assign bank_req[i].wdata = wdata_i[i*BitsPerBank+:BitsPerBank];
    assign bank_req[i].strb  = strb_i[i*BytesPerBank+:BytesPerBank];
    assign bank_req[i].wuser = wuser_i;
    assign bank_req[i].we    = we_i;
    stream_fifo #(
      .FALL_THROUGH ( 1'b1         ),
      .DATA_WIDTH   ( $bits(req_t) ),
      .DEPTH        ( FifoDepth    ),
      .T            ( req_t        )
    ) i_ft_reg (
      .clk_i,
      .rst_ni,
      .flush_i    ( 1'b0          ),
      .testmode_i ( 1'b0          ),
      .usage_o    (),
      .data_i     ( bank_req[i]   ),
      .valid_i    ( req_valid     ),
      .ready_o    ( req_ready[i]  ),
      .data_o     ( bank_oup[i]   ),
      .valid_o    ( bank_req_internal[i] ),
      .ready_i    ( bank_gnt_internal[i] )
    );
    assign bank_addr_o[i]  = bank_oup[i].addr;
    assign bank_wdata_o[i] = bank_oup[i].wdata;
    assign bank_strb_o[i]  = bank_oup[i].strb;
    assign bank_wuser_o[i] = bank_oup[i].wuser;
    assign bank_we_o[i]    = bank_oup[i].we;

    assign zero_strobe[i] = (bank_req[i].strb == '0);

    if (HideStrb) begin : gen_hide_strb
      assign bank_req_o[i] = (bank_oup[i].we && (bank_oup[i].strb == '0)) ?
                               1'b0 : bank_req_internal[i];
      assign bank_gnt_internal[i] = (bank_oup[i].we && (bank_oup[i].strb == '0)) ?
                                      1'b1 : bank_gnt_i[i];
    end else begin : gen_legacy_strb
      assign bank_req_o[i] = bank_req_internal[i];
      assign bank_gnt_internal[i] = bank_gnt_i[i];
    end
  end

  assign gnt_o = (&req_ready) & (&resp_ready) & !dead_write_fifo_full;

  if (HideStrb) begin : gen_dead_write_fifo
    fifo_v3 #(
      .FALL_THROUGH ( 1'b0     ),
      .DEPTH        ( MaxTrans+1 ),
      .DATA_WIDTH   ( NumBanks )
    ) i_dead_write_fifo (
      .clk_i,
      .rst_ni,
      .flush_i    ( 1'b0                           ),
      .testmode_i ( 1'b0                           ),
      .full_o     ( dead_write_fifo_full           ),
      .empty_o    ( dead_write_fifo_empty          ),
      .usage_o    (),
      .data_i     ( {NumBanks{we_i}} & zero_strobe ),
      .push_i     ( req_i & gnt_o                  ),
      .data_o     ( dead_response_unmasked         ),
      .pop_i      ( rvalid_o                       )
    );
    assign dead_response = dead_response_unmasked & {NumBanks{~dead_write_fifo_empty}};
  end else begin : gen_no_dead_write_fifo
    assign dead_response_unmasked = '0;
    assign dead_response = '0;
    assign dead_write_fifo_full = 1'b0;
    assign dead_write_fifo_empty = 1'b1;
  end

  for (genvar i = 0; unsigned'(i) < NumBanks; i++) begin : gen_resp_regs
    stream_fifo #(
      .FALL_THROUGH ( 1'b1              ),
      .DATA_WIDTH   ( $bits(oup_data_t) + $bits(oup_ruser_t) ),
      .DEPTH        ( FifoDepth         )
    ) i_ft_reg (
      .clk_i,
      .rst_ni,
      .flush_i    ( 1'b0                                              ),
      .testmode_i ( 1'b0                                              ),
      .usage_o    (),
      .data_i     ( {bank_rdata_i[i], bank_ruser_i[i]}                ),
      .valid_i    ( bank_rvalid_i[i]                                  ),
      .ready_o    ( resp_ready[i]                                     ),
      .data_o     ( {rdata_o[i*BitsPerBank+:BitsPerBank], ruser_o[i]} ),
      .valid_o    ( resp_valid[i]                                     ),
      .ready_i    ( rvalid_o & !dead_response[i]                      )
    );
  end
  assign rvalid_o = &(resp_valid | dead_response);

endmodule
