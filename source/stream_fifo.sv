module stream_fifo #(

    parameter bit          FALL_THROUGH = 1'b0,

    parameter int unsigned DATA_WIDTH   = 32,

    parameter int unsigned DEPTH        = 8,
    parameter type         T            = logic [DATA_WIDTH-1:0],

    parameter int unsigned ADDR_DEPTH  = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input  logic                  clk_i,      
    input  logic                  rst_ni,     
    input  logic                  flush_i,    
    input  logic                  testmode_i, 
    output logic [ADDR_DEPTH-1:0] usage_o,    

    input  T                      data_i,     
    input  logic                  valid_i,    
    output logic                  ready_o,    

    output T                      data_o,     
    output logic                  valid_o,    
    input  logic                  ready_i     
);

    logic push, pop;
    logic empty, full;

    assign push    = valid_i & ~full;
    assign pop     = ready_i & ~empty;
    assign ready_o = ~full;
    assign valid_o = ~empty;

    fifo_v3 #(
        .FALL_THROUGH   (FALL_THROUGH),
        .DATA_WIDTH     (DATA_WIDTH),
        .DEPTH          (DEPTH),
        .dtype(T)
    ) fifo_i (
        .clk_i,
        .rst_ni,
        .flush_i,
        .testmode_i,
        .full_o     (full),
        .empty_o    (empty),
        .usage_o,
        .data_i,
        .push_i     (push),
        .data_o,
        .pop_i      (pop)
    );

endmodule
