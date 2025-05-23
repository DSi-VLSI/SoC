`include "common_cells/registers.svh"

module stream_to_mem #(

  parameter type         mem_req_t  = logic,

  parameter type         mem_resp_t = logic,

  parameter int unsigned BufDepth   = 32'd1
) (

  input  logic      clk_i,

  input  logic      rst_ni,

  input  mem_req_t  req_i,

  input  logic      req_valid_i,

  output logic      req_ready_o,

  output mem_resp_t resp_o,

  output logic      resp_valid_o,

  input  logic      resp_ready_i,

  output mem_req_t  mem_req_o,

  output logic      mem_req_valid_o,

  input  logic      mem_req_ready_i,

  input  mem_resp_t mem_resp_i,

  input  logic      mem_resp_valid_i
);

  typedef logic [$clog2(BufDepth+1):0] cnt_t;

  cnt_t cnt_d, cnt_q;
  logic buf_ready,
        req_ready;

  if (BufDepth > 0) begin : gen_buf

    always_comb begin
      cnt_d = cnt_q;
      if (req_valid_i && req_ready_o) begin
        cnt_d++;
      end
      if (resp_valid_o && resp_ready_i) begin
        cnt_d--;
      end
    end

    assign req_ready = (cnt_q < BufDepth) | (resp_valid_o & resp_ready_i);

    assign req_ready_o = mem_req_ready_i & req_ready;
    assign mem_req_valid_o = req_valid_i & req_ready;

    stream_fifo #(
      .FALL_THROUGH ( 1'b1       ),
      .DEPTH        ( BufDepth   ),
      .T            ( mem_resp_t )
    ) i_resp_buf (
      .clk_i,
      .rst_ni,
      .flush_i    ( 1'b0             ),
      .testmode_i ( 1'b0             ),
      .data_i     ( mem_resp_i       ),
      .valid_i    ( mem_resp_valid_i ),
      .ready_o    ( buf_ready        ),
      .data_o     ( resp_o           ),
      .valid_o    ( resp_valid_o     ),
      .ready_i    ( resp_ready_i     ),
      .usage_o    (                  )
    );

    `FFARN(cnt_q, cnt_d, '0, clk_i, rst_ni)

  end else begin : gen_no_buf

    assign mem_req_valid_o = req_valid_i;
    assign resp_valid_o    = mem_req_valid_o & mem_req_ready_i & mem_resp_valid_i;
    assign req_ready_o     = resp_ready_i    & resp_valid_o;

    assign resp_o = mem_resp_i;
  end

  assign mem_req_o = req_i;

endmodule
