import ariane_pkg::*;
import std_cache_pkg::*;module cache_ctrl #(
    parameter logic [63:0] CACHE_START_ADDR  = 64'h4000_0000
) (
    input  logic                                 clk_i,     
    input  logic                                 rst_ni,    
    input  logic                                 flush_i,
    input  logic                                 bypass_i,  
    output logic                                 busy_o,

    input  dcache_req_i_t                        req_port_i,
    output dcache_req_o_t                        req_port_o,

    output logic [DCACHE_SET_ASSOC-1:0]          req_o,  
    output logic [DCACHE_INDEX_WIDTH-1:0]        addr_o, 
    input  logic                                 gnt_i,
    output cache_line_t                          data_o,
    output cl_be_t                               be_o,
    output logic [DCACHE_TAG_WIDTH-1:0]          tag_o, 
    input  cache_line_t [DCACHE_SET_ASSOC-1:0]   data_i,
    output logic                                 we_o,
    input  logic [DCACHE_SET_ASSOC-1:0]          hit_way_i,

    output miss_req_t                            miss_req_o,

    input  logic                                 miss_gnt_i,
    input  logic                                 active_serving_i, 
    input  logic [63:0]                          critical_word_i,
    input  logic                                 critical_word_valid_i,

    input  logic                                 bypass_gnt_i,
    input  logic                                 bypass_valid_i,
    input  logic [63:0]                          bypass_data_i,

    output logic [55:0]                          mshr_addr_o,
    input  logic                                 mshr_addr_matches_i,
    input  logic                                 mshr_index_matches_i
);

    enum logic [3:0] {
        IDLE,               
        WAIT_TAG,           
        WAIT_TAG_BYPASSED,  
        STORE_REQ,          
        WAIT_REFILL_VALID,  
        WAIT_REFILL_GNT,    
        WAIT_TAG_SAVED,     
        WAIT_MSHR,          
        WAIT_CRITICAL_WORD  
    } state_d, state_q;

    typedef struct packed {
        logic [DCACHE_INDEX_WIDTH-1:0] index;
        logic [DCACHE_TAG_WIDTH-1:0]   tag;
        logic [7:0]             be;
        logic [1:0]             size;
        logic                   we;
        logic [63:0]            wdata;
        logic                   bypass;
    } mem_req_t;

    logic [DCACHE_SET_ASSOC-1:0] hit_way_d, hit_way_q;

    assign busy_o = (state_q != IDLE);

    mem_req_t mem_req_d, mem_req_q;

    logic [DCACHE_LINE_WIDTH-1:0] cl_i;

    always_comb begin : way_select
        cl_i = '0;
        for (int unsigned i = 0; i < DCACHE_SET_ASSOC; i++)
            if (hit_way_i[i])
                cl_i = data_i[i].data;

    end

    always_comb begin : cache_ctrl_fsm
        automatic logic [$clog2(DCACHE_LINE_WIDTH)-1:0] cl_offset;

        cl_offset = mem_req_q.index[DCACHE_BYTE_OFFSET-1:3] << 6; 

        state_d   = state_q;
        mem_req_d = mem_req_q;
        hit_way_d = hit_way_q;

        req_port_o.data_gnt    = 1'b0;
        req_port_o.data_rvalid = 1'b0;
        req_port_o.data_rdata  = '0;
        miss_req_o    = '0;
        mshr_addr_o   = '0;

        req_o  = '0;
        addr_o = req_port_i.address_index;
        data_o = '0;
        be_o   = '0;
        tag_o  = '0;
        we_o   = '0;
        tag_o  = 'b0;

        case (state_q)

            IDLE: begin

                if (req_port_i.data_req && !flush_i) begin

                    req_o = '1;

                    mem_req_d.index = req_port_i.address_index;
                    mem_req_d.tag   = req_port_i.address_tag;
                    mem_req_d.be    = req_port_i.data_be;
                    mem_req_d.size  = req_port_i.data_size;
                    mem_req_d.we    = req_port_i.data_we;
                    mem_req_d.wdata = req_port_i.data_wdata;

                    if (bypass_i) begin
                        state_d = (req_port_i.data_we) ? WAIT_REFILL_GNT : WAIT_TAG_BYPASSED;

                        req_port_o.data_gnt = (req_port_i.data_we) ? 1'b0 : 1'b1;
                        mem_req_d.bypass = 1'b1;

                    end else begin

                        if (gnt_i) begin
                            state_d = WAIT_TAG;
                            mem_req_d.bypass = 1'b0;

                            if (!req_port_i.data_we)
                                req_port_o.data_gnt = 1'b1;
                        end
                    end
                end
            end

            WAIT_TAG, WAIT_TAG_SAVED: begin

                tag_o = (state_q == WAIT_TAG_SAVED || mem_req_q.we) ? mem_req_q.tag
                                                                    : req_port_i.address_tag;

                if (req_port_i.data_req && !flush_i) begin
                    req_o = '1;
                end

                if (!req_port_i.kill_req) begin

                    if (|hit_way_i) begin

                        if (req_port_i.data_req && !mem_req_q.we && !flush_i) begin
                            state_d          = WAIT_TAG; 
                            mem_req_d.index  = req_port_i.address_index;
                            mem_req_d.be     = req_port_i.data_be;
                            mem_req_d.size   = req_port_i.data_size;
                            mem_req_d.we     = req_port_i.data_we;
                            mem_req_d.wdata  = req_port_i.data_wdata;
                            mem_req_d.tag    = req_port_i.address_tag;
                            mem_req_d.bypass = 1'b0;

                            req_port_o.data_gnt = gnt_i;

                            if (!gnt_i) begin
                                state_d = IDLE;
                            end
                        end else begin
                            state_d = IDLE;
                        end

                        case (mem_req_q.index[3])
                            1'b0: req_port_o.data_rdata = cl_i[63:0];
                            1'b1: req_port_o.data_rdata = cl_i[127:64];
                        endcase

                        if (!mem_req_q.we) begin
                            req_port_o.data_rvalid = 1'b1;

                        end else begin
                            state_d = STORE_REQ;
                            hit_way_d = hit_way_i;
                        end

                    end else begin

                        mem_req_d.tag = req_port_i.address_tag;

                        state_d = WAIT_REFILL_GNT;
                    end

                    mshr_addr_o = {tag_o, mem_req_q.index};

                    if ((mshr_index_matches_i && mem_req_q.we) || mshr_addr_matches_i) begin
                        state_d = WAIT_MSHR;

                        if (state_q != WAIT_TAG_SAVED) begin
                            mem_req_d.tag = req_port_i.address_tag;
                        end
                    end

                    if (tag_o < CACHE_START_ADDR[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH]) begin
                        mem_req_d.tag = req_port_i.address_tag;
                        mem_req_d.bypass = 1'b1;
                        state_d = WAIT_REFILL_GNT;
                    end
                end
            end

            STORE_REQ: begin

                mshr_addr_o = {mem_req_q.tag, mem_req_q.index};

                if (!mshr_index_matches_i) begin

                    req_o      = hit_way_q;
                    addr_o     = mem_req_q.index;
                    we_o       = 1'b1;

                    be_o.vldrty = hit_way_q;

                    be_o.data[cl_offset>>3 +: 8]  = mem_req_q.be;
                    data_o.data[cl_offset  +: 64] = mem_req_q.wdata;

                    data_o.dirty = 1'b1;
                    data_o.valid = 1'b1;

                    if (gnt_i) begin
                        req_port_o.data_gnt = 1'b1;
                        state_d = IDLE;
                    end
                end else begin
                    state_d = WAIT_MSHR;
                end
            end 

            WAIT_MSHR: begin
                mshr_addr_o = {mem_req_q.tag, mem_req_q.index};

                if (!mshr_index_matches_i) begin
                    req_o = '1;

                    addr_o = mem_req_q.index;

                    if (gnt_i) state_d = WAIT_TAG_SAVED;
                end
            end

            WAIT_TAG_BYPASSED: begin

                if (!req_port_i.kill_req) begin

                    mem_req_d.tag = req_port_i.address_tag;
                    state_d = WAIT_REFILL_GNT;
                end
            end

            WAIT_REFILL_GNT: begin

                mshr_addr_o = {mem_req_q.tag, mem_req_q.index};

                miss_req_o.valid = 1'b1;
                miss_req_o.bypass = mem_req_q.bypass;
                miss_req_o.addr = {mem_req_q.tag, mem_req_q.index};
                miss_req_o.be = mem_req_q.be;
                miss_req_o.size = mem_req_q.size;
                miss_req_o.we = mem_req_q.we;
                miss_req_o.wdata = mem_req_q.wdata;

                if (bypass_gnt_i) begin
                    state_d = WAIT_REFILL_VALID;

                    if (mem_req_q.we)
                        req_port_o.data_gnt = 1'b1;
                end

                if (miss_gnt_i && !mem_req_q.we)
                    state_d = WAIT_CRITICAL_WORD;
                else if (miss_gnt_i) begin
                    state_d = IDLE;
                    req_port_o.data_gnt = 1'b1;
                end

                if (mshr_addr_matches_i && !active_serving_i) begin
                    state_d = WAIT_MSHR;
                end
            end

            WAIT_CRITICAL_WORD: begin

                if (req_port_i.data_req) begin

                    req_o = '1;
                end

                if (critical_word_valid_i) begin
                    req_port_o.data_rvalid = 1'b1;
                    req_port_o.data_rdata = critical_word_i;

                    if (req_port_i.data_req) begin

                        mem_req_d.index = req_port_i.address_index;
                        mem_req_d.be    = req_port_i.data_be;
                        mem_req_d.size  = req_port_i.data_size;
                        mem_req_d.we    = req_port_i.data_we;
                        mem_req_d.wdata = req_port_i.data_wdata;
                        mem_req_d.tag   = req_port_i.address_tag;

                        state_d = IDLE;

                        if (gnt_i) begin
                            state_d = WAIT_TAG;
                            mem_req_d.bypass = 1'b0;
                            req_port_o.data_gnt = 1'b1;
                        end
                    end else begin
                        state_d = IDLE;
                    end
                end
            end

            WAIT_REFILL_VALID: begin

                if (bypass_valid_i) begin
                    req_port_o.data_rdata = bypass_data_i;
                    req_port_o.data_rvalid = 1'b1;
                    state_d = IDLE;
                end
            end
        endcase

        if (req_port_i.kill_req) begin
            state_d = IDLE;
            req_port_o.data_rvalid = 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q       <= IDLE;
            mem_req_q     <= '0;
            hit_way_q     <= '0;
        end else begin
            state_q   <= state_d;
            mem_req_q <= mem_req_d;
            hit_way_q <= hit_way_d;
        end
    end

endmodule
