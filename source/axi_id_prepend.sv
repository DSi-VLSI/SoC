module axi_id_prepend #(
  parameter int unsigned NoBus             = 1,     
  parameter int unsigned AxiIdWidthSlvPort = 4,     
  parameter int unsigned AxiIdWidthMstPort = 6,     
  parameter type         slv_aw_chan_t     = logic, 
  parameter type         slv_w_chan_t      = logic, 
  parameter type         slv_b_chan_t      = logic, 
  parameter type         slv_ar_chan_t     = logic, 
  parameter type         slv_r_chan_t      = logic, 
  parameter type         mst_aw_chan_t     = logic, 
  parameter type         mst_w_chan_t      = logic, 
  parameter type         mst_b_chan_t      = logic, 
  parameter type         mst_ar_chan_t     = logic, 
  parameter type         mst_r_chan_t      = logic, 

  parameter int unsigned PreIdWidth        = AxiIdWidthMstPort - AxiIdWidthSlvPort
) (
  input  logic [PreIdWidth-1:0] pre_id_i, 

  input  slv_aw_chan_t [NoBus-1:0] slv_aw_chans_i,
  input  logic         [NoBus-1:0] slv_aw_valids_i,
  output logic         [NoBus-1:0] slv_aw_readies_o,

  input  slv_w_chan_t  [NoBus-1:0] slv_w_chans_i,
  input  logic         [NoBus-1:0] slv_w_valids_i,
  output logic         [NoBus-1:0] slv_w_readies_o,

  output slv_b_chan_t  [NoBus-1:0] slv_b_chans_o,
  output logic         [NoBus-1:0] slv_b_valids_o,
  input  logic         [NoBus-1:0] slv_b_readies_i,

  input  slv_ar_chan_t [NoBus-1:0] slv_ar_chans_i,
  input  logic         [NoBus-1:0] slv_ar_valids_i,
  output logic         [NoBus-1:0] slv_ar_readies_o,

  output slv_r_chan_t  [NoBus-1:0] slv_r_chans_o,
  output logic         [NoBus-1:0] slv_r_valids_o,
  input  logic         [NoBus-1:0] slv_r_readies_i,

  output mst_aw_chan_t [NoBus-1:0] mst_aw_chans_o,
  output logic         [NoBus-1:0] mst_aw_valids_o,
  input  logic         [NoBus-1:0] mst_aw_readies_i,

  output mst_w_chan_t  [NoBus-1:0] mst_w_chans_o,
  output logic         [NoBus-1:0] mst_w_valids_o,
  input  logic         [NoBus-1:0] mst_w_readies_i,

  input  mst_b_chan_t  [NoBus-1:0] mst_b_chans_i,
  input  logic         [NoBus-1:0] mst_b_valids_i,
  output logic         [NoBus-1:0] mst_b_readies_o,

  output mst_ar_chan_t [NoBus-1:0] mst_ar_chans_o,
  output logic         [NoBus-1:0] mst_ar_valids_o,
  input  logic         [NoBus-1:0] mst_ar_readies_i,

  input  mst_r_chan_t  [NoBus-1:0] mst_r_chans_i,
  input  logic         [NoBus-1:0] mst_r_valids_i,
  output logic         [NoBus-1:0] mst_r_readies_o
);

  for (genvar i = 0; i < NoBus; i++) begin : gen_id_prepend
    if (PreIdWidth == 0) begin : gen_no_prepend
      assign mst_aw_chans_o[i] = slv_aw_chans_i[i];
      assign mst_ar_chans_o[i] = slv_ar_chans_i[i];
    end else begin : gen_prepend
      always_comb begin
        mst_aw_chans_o[i] = slv_aw_chans_i[i];
        mst_ar_chans_o[i] = slv_ar_chans_i[i];
        mst_aw_chans_o[i].id = {pre_id_i, slv_aw_chans_i[i].id[AxiIdWidthSlvPort-1:0]};
        mst_ar_chans_o[i].id = {pre_id_i, slv_ar_chans_i[i].id[AxiIdWidthSlvPort-1:0]};
      end
    end

    assign slv_b_chans_o[i] = mst_b_chans_i[i];
    assign slv_r_chans_o[i] = mst_r_chans_i[i];
  end

  assign mst_w_chans_o    = slv_w_chans_i;
  assign mst_aw_valids_o  = slv_aw_valids_i;
  assign slv_aw_readies_o = mst_aw_readies_i;
  assign mst_w_valids_o   = slv_w_valids_i;
  assign slv_w_readies_o  = mst_w_readies_i;
  assign slv_b_valids_o   = mst_b_valids_i;
  assign mst_b_readies_o  = slv_b_readies_i;
  assign mst_ar_valids_o  = slv_ar_valids_i;
  assign slv_ar_readies_o = mst_ar_readies_i;
  assign slv_r_valids_o   = mst_r_valids_i;
  assign mst_r_readies_o  = slv_r_readies_i;

endmodule
