module btb #(
    parameter int NR_ENTRIES = 8
)(
    input  logic                        clk_i,           
    input  logic                        rst_ni,          
    input  logic                        flush_i,         
    input  logic                        debug_mode_i,

    input  logic [63:0]                 vpc_i,           
    input  ariane_pkg::btb_update_t     btb_update_i,    
    output ariane_pkg::btb_prediction_t btb_prediction_o 
);

    localparam OFFSET = 1; 
    localparam ANTIALIAS_BITS = 8;

    localparam PREDICTION_BITS = $clog2(NR_ENTRIES) + OFFSET;

    ariane_pkg::btb_prediction_t btb_d [NR_ENTRIES-1:0], btb_q [NR_ENTRIES-1:0];
    logic [$clog2(NR_ENTRIES)-1:0]          index, update_pc;

    assign index     = vpc_i[PREDICTION_BITS - 1:OFFSET];
    assign update_pc = btb_update_i.pc[PREDICTION_BITS - 1:OFFSET];

    assign btb_prediction_o = btb_q[index];

    always_comb begin : update_branch_predict
        btb_d = btb_q;

        if (btb_update_i.valid && !debug_mode_i) begin
            btb_d[update_pc].valid = 1'b1;

            btb_d[update_pc].target_address = btb_update_i.target_address;

            if (btb_update_i.clear) begin
                btb_d[update_pc].valid = 1'b0;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin

            for (int i = 0; i < NR_ENTRIES; i++)
                btb_q[i] <= '{default: 0};
        end else begin

            if (flush_i) begin
                for (int i = 0; i < NR_ENTRIES; i++) begin
                    btb_q[i].valid <=  1'b0;
                end
            end else begin
                btb_q <=  btb_d;
            end
        end
    end
endmodule
