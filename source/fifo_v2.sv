module fifo_v2 #(
    parameter bit          FALL_THROUGH = 1'b0, 
    parameter int unsigned DATA_WIDTH   = 32,   
    parameter int unsigned DEPTH        = 8,    
    parameter int unsigned ALM_EMPTY_TH = 1,    
    parameter int unsigned ALM_FULL_TH  = 1,    
    parameter type dtype                = logic [DATA_WIDTH-1:0],

    parameter int unsigned ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
)(
    input  logic  clk_i,            
    input  logic  rst_ni,           
    input  logic  flush_i,          
    input  logic  testmode_i,       

    output logic  full_o,           
    output logic  empty_o,          
    output logic  alm_full_o,       
    output logic  alm_empty_o,      

    input  dtype  data_i,           
    input  logic  push_i,           

    output dtype  data_o,           
    input  logic  pop_i             
);

    logic [ADDR_DEPTH-1:0] usage;

    if (DEPTH == 0) begin
        assign alm_full_o  = 1'b0; 
        assign alm_empty_o = 1'b0; 
    end else begin
        assign alm_full_o   = (usage >= ALM_FULL_TH[ADDR_DEPTH-1:0]);
        assign alm_empty_o  = (usage <= ALM_EMPTY_TH[ADDR_DEPTH-1:0]);
    end

    fifo_v3 #(
        .FALL_THROUGH ( FALL_THROUGH ),
        .DATA_WIDTH   ( DATA_WIDTH   ),
        .DEPTH        ( DEPTH        ),
        .dtype        ( dtype        )
    ) i_fifo_v3 (
        .clk_i,
        .rst_ni,
        .flush_i,
        .testmode_i,
        .full_o,
        .empty_o,
        .usage_o (usage),
        .data_i,
        .push_i,
        .data_o,
        .pop_i
    );

endmodule 
