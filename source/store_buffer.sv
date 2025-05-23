import ariane_pkg::*;module store_buffer (
    input logic          clk_i,           
    input logic          rst_ni,          
    input logic          flush_i,         

    output logic         no_st_pending_o, 

    input  logic [11:0]  page_offset_i,         
    output logic         page_offset_matches_o, 

    input  logic         commit_i,        
    output logic         commit_ready_o,  
    output logic         ready_o,         

    input  logic         valid_i,         
    input  logic         valid_without_flush_i, 

    input  logic [63:0]  paddr_i,         
    input  logic [63:0]  data_i,          
    input  logic [7:0]   be_i,            
    input  logic [1:0]   data_size_i,     

    input  dcache_req_o_t req_port_i,
    output dcache_req_i_t req_port_o
);

    struct packed {
        logic [63:0] address;
        logic [63:0] data;
        logic [7:0]  be;
        logic [1:0]  data_size;
        logic        valid;     
    } speculative_queue_n [DEPTH_SPEC-1:0], speculative_queue_q [DEPTH_SPEC-1:0],
      commit_queue_n [DEPTH_COMMIT-1:0],    commit_queue_q [DEPTH_COMMIT-1:0];

    logic [$clog2(DEPTH_SPEC):0] speculative_status_cnt_n, speculative_status_cnt_q;
    logic [$clog2(DEPTH_COMMIT):0] commit_status_cnt_n, commit_status_cnt_q;

    logic [$clog2(DEPTH_SPEC)-1:0] speculative_read_pointer_n,  speculative_read_pointer_q;
    logic [$clog2(DEPTH_SPEC)-1:0] speculative_write_pointer_n, speculative_write_pointer_q;

    logic [$clog2(DEPTH_COMMIT)-1:0] commit_read_pointer_n,  commit_read_pointer_q;
    logic [$clog2(DEPTH_COMMIT)-1:0] commit_write_pointer_n, commit_write_pointer_q;

    always_comb begin : core_if
        automatic logic [DEPTH_SPEC:0] speculative_status_cnt;
        speculative_status_cnt = speculative_status_cnt_q;

        ready_o = (speculative_status_cnt_q < (DEPTH_SPEC - 1)) || commit_i;

        speculative_status_cnt_n    = speculative_status_cnt_q;
        speculative_read_pointer_n  = speculative_read_pointer_q;
        speculative_write_pointer_n = speculative_write_pointer_q;
        speculative_queue_n         = speculative_queue_q;

        if (valid_i) begin
            speculative_queue_n[speculative_write_pointer_q].address   = paddr_i;
            speculative_queue_n[speculative_write_pointer_q].data      = data_i;
            speculative_queue_n[speculative_write_pointer_q].be        = be_i;
            speculative_queue_n[speculative_write_pointer_q].data_size = data_size_i;
            speculative_queue_n[speculative_write_pointer_q].valid   = 1'b1;

            speculative_write_pointer_n = speculative_write_pointer_q + 1'b1;
            speculative_status_cnt++;
        end

        if (commit_i) begin

            speculative_queue_n[speculative_read_pointer_q].valid = 1'b0;

            speculative_read_pointer_n = speculative_read_pointer_q + 1'b1;
            speculative_status_cnt--;
        end

        speculative_status_cnt_n = speculative_status_cnt;

        if (flush_i) begin

            for (int unsigned i = 0; i < DEPTH_SPEC; i++)
                speculative_queue_n[i].valid = 1'b0;

            speculative_write_pointer_n = speculative_read_pointer_q;

            speculative_status_cnt_n = 'b0;
        end
    end

    assign req_port_o.kill_req  = 1'b0;
    assign req_port_o.data_we   = 1'b1; 
    assign req_port_o.tag_valid = 1'b0;

    assign req_port_o.address_index = commit_queue_q[commit_read_pointer_q].address[ariane_pkg::DCACHE_INDEX_WIDTH-1:0];

    assign req_port_o.address_tag   = commit_queue_q[commit_read_pointer_q].address[ariane_pkg::DCACHE_TAG_WIDTH     +
                                                                                    ariane_pkg::DCACHE_INDEX_WIDTH-1 :
                                                                                    ariane_pkg::DCACHE_INDEX_WIDTH];
    assign req_port_o.data_wdata    = commit_queue_q[commit_read_pointer_q].data;
    assign req_port_o.data_be       = commit_queue_q[commit_read_pointer_q].be;
    assign req_port_o.data_size     = commit_queue_q[commit_read_pointer_q].data_size;

    always_comb begin : store_if
        automatic logic [DEPTH_COMMIT:0] commit_status_cnt;
        commit_status_cnt = commit_status_cnt_q;

        commit_ready_o = (commit_status_cnt_q < DEPTH_COMMIT);

        no_st_pending_o         = (commit_status_cnt_q == 0);

        commit_read_pointer_n   = commit_read_pointer_q;
        commit_write_pointer_n  = commit_write_pointer_q;

        commit_queue_n = commit_queue_q;

        req_port_o.data_req     = 1'b0;

        if (commit_queue_q[commit_read_pointer_q].valid) begin
            req_port_o.data_req = 1'b1;
            if (req_port_i.data_gnt) begin

                commit_queue_n[commit_read_pointer_q].valid = 1'b0;

                commit_read_pointer_n = commit_read_pointer_q + 1'b1;
                commit_status_cnt--;
            end
        end

        if (commit_i) begin
            commit_queue_n[commit_write_pointer_q] = speculative_queue_q[speculative_read_pointer_q];
            commit_write_pointer_n = commit_write_pointer_n + 1'b1;
            commit_status_cnt++;
        end

        commit_status_cnt_n     = commit_status_cnt;
    end

    always_comb begin : address_checker
        page_offset_matches_o = 1'b0;

        for (int unsigned i = 0; i < DEPTH_COMMIT; i++) begin

            if ((page_offset_i[11:3] == commit_queue_q[i].address[11:3]) && commit_queue_q[i].valid) begin
                page_offset_matches_o = 1'b1;
                break;
            end
        end

        for (int unsigned i = 0; i < DEPTH_SPEC; i++) begin

            if ((page_offset_i[11:3] == speculative_queue_q[i].address[11:3]) && speculative_queue_q[i].valid) begin
                page_offset_matches_o = 1'b1;
                break;
            end
        end

        if ((page_offset_i[11:3] == paddr_i[11:3]) && valid_without_flush_i) begin
            page_offset_matches_o = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_spec
        if (~rst_ni) begin
            speculative_queue_q         <= '{default: 0};
            speculative_read_pointer_q  <= '0;
            speculative_write_pointer_q <= '0;
            speculative_status_cnt_q    <= '0;
        end else begin
            speculative_queue_q         <= speculative_queue_n;
            speculative_read_pointer_q  <= speculative_read_pointer_n;
            speculative_write_pointer_q <= speculative_write_pointer_n;
            speculative_status_cnt_q    <= speculative_status_cnt_n;
        end
     end

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_commit
        if (~rst_ni) begin
            commit_queue_q              <= '{default: 0};
            commit_read_pointer_q       <= '0;
            commit_write_pointer_q      <= '0;
            commit_status_cnt_q         <= '0;
        end else begin
            commit_queue_q              <= commit_queue_n;
            commit_read_pointer_q       <= commit_read_pointer_n;
            commit_write_pointer_q      <= commit_write_pointer_n;
            commit_status_cnt_q         <= commit_status_cnt_n;
        end
     end

endmodule

