`include "common_cells/registers.svh"

module axi_to_mem #(

  parameter type         axi_req_t  = logic,

  parameter type         axi_resp_t = logic,

  parameter int unsigned AddrWidth  = 0,

  parameter int unsigned DataWidth  = 0,

  parameter int unsigned IdWidth    = 0,

  parameter int unsigned NumBanks   = 0,

  parameter int unsigned BufDepth   = 1,

  parameter bit          HideStrb   = 1'b0,

  parameter int unsigned OutFifoDepth = 1,

  localparam type addr_t     = logic [AddrWidth-1:0],

  localparam type mem_data_t = logic [DataWidth/NumBanks-1:0],

  localparam type mem_strb_t = logic [DataWidth/NumBanks/8-1:0]
) (

  input  logic                           clk_i,

  input  logic                           rst_ni,

  output logic                           busy_o,

  input  axi_req_t                       axi_req_i,

  output axi_resp_t                      axi_resp_o,

  output logic           [NumBanks-1:0]  mem_req_o,

  input  logic           [NumBanks-1:0]  mem_gnt_i,

  output addr_t          [NumBanks-1:0]  mem_addr_o,

  output mem_data_t      [NumBanks-1:0]  mem_wdata_o,

  output mem_strb_t      [NumBanks-1:0]  mem_strb_o,

  output axi_pkg::atop_t [NumBanks-1:0]  mem_atop_o,

  output logic           [NumBanks-1:0]  mem_we_o,

  input  logic           [NumBanks-1:0]  mem_rvalid_i,

  input  mem_data_t      [NumBanks-1:0]  mem_rdata_i
);

  axi_to_detailed_mem #(
    .axi_req_t    ( axi_req_t    ),
    .axi_resp_t   ( axi_resp_t   ),
    .AddrWidth    ( AddrWidth    ),
    .DataWidth    ( DataWidth    ),
    .IdWidth      ( IdWidth      ),
    .UserWidth    ( 1            ),
    .NumBanks     ( NumBanks     ),
    .BufDepth     ( BufDepth     ),
    .HideStrb     ( HideStrb     ),
    .OutFifoDepth ( OutFifoDepth )
  ) i_axi_to_detailed_mem (
    .clk_i,
    .rst_ni,
    .busy_o,
    .axi_req_i    ( axi_req_i     ),
    .axi_resp_o   ( axi_resp_o    ),
    .mem_req_o    ( mem_req_o     ),
    .mem_gnt_i    ( mem_gnt_i     ),
    .mem_addr_o   ( mem_addr_o    ),
    .mem_wdata_o  ( mem_wdata_o   ),
    .mem_strb_o   ( mem_strb_o    ),
    .mem_atop_o   ( mem_atop_o    ),
    .mem_lock_o   (),
    .mem_we_o     ( mem_we_o      ),
    .mem_id_o     (),
    .mem_user_o   (),
    .mem_cache_o  (),
    .mem_prot_o   (),
    .mem_qos_o    (),
    .mem_region_o (),
    .mem_rvalid_i ( mem_rvalid_i ),
    .mem_rdata_i  ( mem_rdata_i   ),
    .mem_err_i    ('0),
    .mem_exokay_i ('0)
  );

endmodule
