import ariane_pkg::*;module csr_buffer (
    input  logic                     clk_i,          
    input  logic                     rst_ni,         
    input  logic                     flush_i,

    input  fu_data_t                 fu_data_i,

    output logic                     csr_ready_o,    
    input  logic                     csr_valid_i,    
    output logic [63:0]              csr_result_o,
    input  logic                     csr_commit_i,   

    output logic  [11:0]             csr_addr_o      
);

    struct packed {
        logic [11:0] csr_address;
        logic        valid;
    } csr_reg_n, csr_reg_q;

    assign csr_result_o   = fu_data_i.operand_a;
    assign csr_addr_o     = csr_reg_q.csr_address;

    always_comb begin : write
        csr_reg_n  = csr_reg_q;

        csr_ready_o = 1'b1;

        if ((csr_reg_q.valid || csr_valid_i) && ~csr_commit_i)
            csr_ready_o = 1'b0;

        if (csr_valid_i) begin
            csr_reg_n.csr_address = fu_data_i.operand_b[11:0];
            csr_reg_n.valid       = 1'b1;
        end

        if (csr_commit_i && ~csr_valid_i) begin
            csr_reg_n.valid       = 1'b0;
        end

        if (flush_i)
            csr_reg_n.valid       = 1'b0;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            csr_reg_q <= '{default: 0};
        end else begin
            csr_reg_q <= csr_reg_n;
        end
    end

endmodule
