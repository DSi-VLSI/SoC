module arbiter #(
    parameter int unsigned NR_PORTS   = 3,
    parameter int unsigned DATA_WIDTH = 64
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [NR_PORTS-1:0] data_req_i,
    input logic [NR_PORTS-1:0][63:0] address_i,
    input logic [NR_PORTS-1:0][DATA_WIDTH-1:0] data_wdata_i,
    input logic [NR_PORTS-1:0] data_we_i,
    input logic [NR_PORTS-1:0][DATA_WIDTH/8-1:0] data_be_i,
    input logic [NR_PORTS-1:0][1:0] data_size_i,
    output logic [NR_PORTS-1:0] data_gnt_o,
    output logic [NR_PORTS-1:0] data_rvalid_o,
    output logic [NR_PORTS-1:0][DATA_WIDTH-1:0] data_rdata_o,

    input logic [$clog2(NR_PORTS)-1:0] id_i,
    output logic [$clog2(NR_PORTS)-1:0] id_o,
    input logic [$clog2(NR_PORTS)-1:0] gnt_id_i,
    output logic data_req_o,
    output logic [63:0] address_o,
    output logic [DATA_WIDTH-1:0] data_wdata_o,
    output logic data_we_o,
    output logic [DATA_WIDTH/8-1:0] data_be_o,
    output logic [1:0] data_size_o,
    input logic data_gnt_i,
    input logic data_rvalid_i,
    input logic [DATA_WIDTH-1:0] data_rdata_i
);

  typedef enum logic [1:0] {
    IDLE,
    REQ,
    SERVING
  } state_t;
  state_t state_d;
  state_t state_q;

  typedef struct packed {
    logic [$clog2(NR_PORTS)-1:0] id;
    logic [63:0]                 address;
    logic [63:0]                 data;
    logic [1:0]                  size;
    logic [DATA_WIDTH/8-1:0]     be;
    logic                        we;
  } req_t;
  req_t req_d;
  req_t req_q;

  always_comb begin
    automatic logic [$clog2(NR_PORTS)-1:0] request_index;
    request_index          = 0;

    state_d                = state_q;
    req_d                  = req_q;

    data_req_o             = 1'b0;
    address_o              = req_q.address;
    data_wdata_o           = req_q.data;
    data_be_o              = req_q.be;
    data_size_o            = req_q.size;
    data_we_o              = req_q.we;
    id_o                   = req_q.id;
    data_gnt_o             = '0;

    data_rvalid_o          = '0;
    data_rdata_o           = '0;
    data_rdata_o[req_q.id] = data_rdata_i;

    case (state_q)

      IDLE: begin

        for (int unsigned i = 0; i < NR_PORTS; i++) begin
          if (data_req_i[i] == 1'b1) begin
            data_req_o    = data_req_i[i];
            data_gnt_o[i] = data_req_i[i];
            request_index = i[$bits(request_index)-1:0];

            req_d.address = address_i[i];
            req_d.id = i[$bits(req_q.id)-1:0];
            req_d.data = data_wdata_i[i];
            req_d.size = data_size_i[i];
            req_d.be = data_be_i[i];
            req_d.we = data_we_i[i];
            state_d = SERVING;
            break;
          end
        end

        address_o    = address_i[request_index];
        data_wdata_o = data_wdata_i[request_index];
        data_be_o    = data_be_i[request_index];
        data_size_o  = data_size_i[request_index];
        data_we_o    = data_we_i[request_index];
        id_o         = request_index;
      end

      SERVING: begin
        data_req_o = 1'b1;
        if (data_rvalid_i) begin
          data_rvalid_o[req_q.id] = 1'b1;
          state_d = IDLE;
        end
      end

      default: begin
        state_d = IDLE;
      end
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= IDLE;
      req_q   <= '0;
    end else begin
      state_q <= state_d;
      req_q   <= req_d;
    end
  end

endmodule
