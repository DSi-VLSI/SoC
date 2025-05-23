`include "axi/typedef.svh"

package ariane_axi_pkg;

  // used in axi_adapter.sv
  typedef enum logic {
    SINGLE_REQ,
    CACHE_LINE_REQ
  } ad_req_t;

  // 4 is recommended by AXI standard, so lets stick to it, do not change
  localparam int IdWidth = 4;
  localparam int AddrWidth = 64;
  localparam int DataWidth = 64;
  localparam int StrbWidth = DataWidth / 8;
  localparam int UserWidth = 1;

  `AXI_TYPEDEF_ALL(m, logic [AddrWidth-1:0], logic [IdWidth-1:0], logic [DataWidth-1:0],
                   logic [StrbWidth-1:0], logic [UserWidth-1:0])

endpackage
