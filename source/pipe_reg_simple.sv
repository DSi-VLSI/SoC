module pipe_reg_simple #(
    parameter type dtype         = logic,
    parameter int unsigned Depth = 1
)(
    input  logic clk_i,    
    input  logic rst_ni,   
    input  dtype d_i,
    output dtype d_o
);

    if (Depth == 0) begin
        assign d_o = d_i;

    end else if (Depth == 1) begin
        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                d_o <= '0;
            end else begin
                d_o <= d_i;
            end
        end

    end else if (Depth > 1) begin
        dtype [Depth-1:0] reg_d, reg_q;
        assign d_o = reg_q[Depth-1];
        assign reg_d = {reg_q[Depth-2:0], d_i};

        always_ff @(posedge clk_i or negedge rst_ni) begin
            if (~rst_ni) begin
                reg_q <= '0;
            end else begin
                reg_q <= reg_d;
            end
        end
    end

endmodule
