import ariane_pkg::*;
import std_cache_pkg::*;module miss_handler #(
    parameter int unsigned NR_PORTS         = 3
)(
    input  logic                                        clk_i,
    input  logic                                        rst_ni,
    input  logic                                        flush_i,
    output logic                                        flush_ack_o,
    output logic                                        miss_o,
    input  logic                                        busy_i,

    input  logic [NR_PORTS-1:0][$bits(miss_req_t)-1:0]  miss_req_i,

    output logic [NR_PORTS-1:0]                         bypass_gnt_o,
    output logic [NR_PORTS-1:0]                         bypass_valid_o,
    output logic [NR_PORTS-1:0][63:0]                   bypass_data_o,

    output ariane_axi_pkg::m_req_t                            axi_bypass_o,
    input  ariane_axi_pkg::m_resp_t                           axi_bypass_i,

    output logic [NR_PORTS-1:0]                         miss_gnt_o,
    output logic [NR_PORTS-1:0]                         active_serving_o,

    output logic [63:0]                                 critical_word_o,
    output logic                                        critical_word_valid_o,
    output ariane_axi_pkg::m_req_t                            axi_data_o,
    input  ariane_axi_pkg::m_resp_t                           axi_data_i,

    input  logic [NR_PORTS-1:0][55:0]                   mshr_addr_i,
    output logic [NR_PORTS-1:0]                         mshr_addr_matches_o,
    output logic [NR_PORTS-1:0]                         mshr_index_matches_o,

    input  amo_req_t                                    amo_req_i,
    output amo_resp_t                                   amo_resp_o,

    output logic  [DCACHE_SET_ASSOC-1:0]                req_o,
    output logic  [DCACHE_INDEX_WIDTH-1:0]              addr_o,
    output cache_line_t                                 data_o,
    output cl_be_t                                      be_o,
    input  cache_line_t [DCACHE_SET_ASSOC-1:0]          data_i,
    output logic                                        we_o
);

    enum logic [3:0] {
        IDLE,
        FLUSHING,
        FLUSH,
        WB_CACHELINE_FLUSH,
        FLUSH_REQ_STATUS,
        WB_CACHELINE_MISS,
        WAIT_GNT_SRAM,
        MISS,
        REQ_CACHELINE,
        MISS_REPL,
        SAVE_CACHELINE,
        INIT,
        AMO_LOAD,
        AMO_SAVE_LOAD,
        AMO_STORE
    } state_d, state_q;

    mshr_t                                  mshr_d, mshr_q;
    logic [DCACHE_INDEX_WIDTH-1:0]          cnt_d, cnt_q;
    logic [DCACHE_SET_ASSOC-1:0]            evict_way_d, evict_way_q;

    cache_line_t                            evict_cl_d, evict_cl_q;

    logic serve_amo_d, serve_amo_q;

    logic [NR_PORTS-1:0]                    miss_req_valid;
    logic [NR_PORTS-1:0]                    miss_req_bypass;
    logic [NR_PORTS-1:0][63:0]              miss_req_addr;
    logic [NR_PORTS-1:0][63:0]              miss_req_wdata;
    logic [NR_PORTS-1:0]                    miss_req_we;
    logic [NR_PORTS-1:0][7:0]               miss_req_be;
    logic [NR_PORTS-1:0][1:0]               miss_req_size;

    logic                                    req_fsm_miss_valid;
    logic [63:0]                             req_fsm_miss_addr;
    logic [DCACHE_LINE_WIDTH-1:0]            req_fsm_miss_wdata;
    logic                                    req_fsm_miss_we;
    logic [(DCACHE_LINE_WIDTH/8)-1:0]        req_fsm_miss_be;
    ariane_axi_pkg::ad_req_t                 req_fsm_miss_req;
    logic [1:0]                              req_fsm_miss_size;

    logic                                    gnt_miss_fsm;
    logic                                    valid_miss_fsm;
    logic [(DCACHE_LINE_WIDTH/64)-1:0][63:0] data_miss_fsm;

    logic                                  lfsr_enable;
    logic [DCACHE_SET_ASSOC-1:0]           lfsr_oh;
    logic [$clog2(DCACHE_SET_ASSOC-1)-1:0] lfsr_bin;

    ariane_pkg::amo_t amo_op;
    logic [63:0] amo_operand_a, amo_operand_b, amo_result_o;

    struct packed {
        logic [63:3] address;
        logic        valid;
    } reservation_d, reservation_q;

    always_comb begin : cache_management
        automatic logic [DCACHE_SET_ASSOC-1:0] evict_way, valid_way;

        for (int unsigned i = 0; i < DCACHE_SET_ASSOC; i++) begin
            evict_way[i] = data_i[i].valid & data_i[i].dirty;
            valid_way[i] = data_i[i].valid;
        end

        req_o  = '0;
        addr_o = '0;
        data_o = '0;
        be_o   = '0;
        we_o   = '0;

        miss_gnt_o = '0;

        lfsr_enable = 1'b0;

        req_fsm_miss_valid  = 1'b0;
        req_fsm_miss_addr   = '0;
        req_fsm_miss_wdata  = '0;
        req_fsm_miss_we     = 1'b0;
        req_fsm_miss_be     = '0;
        req_fsm_miss_req    = ariane_axi_pkg::CACHE_LINE_REQ;
        req_fsm_miss_size   = 2'b11;

        flush_ack_o         = 1'b0;
        miss_o              = 1'b0;
        serve_amo_d         = serve_amo_q;

        state_d      = state_q;
        cnt_d        = cnt_q;
        evict_way_d  = evict_way_q;
        evict_cl_d   = evict_cl_q;
        mshr_d       = mshr_q;

        active_serving_o[mshr_q.id] = mshr_q.valid;

        amo_resp_o.ack = 1'b0;
        amo_resp_o.result = '0;

        amo_op = amo_req_i.amo_op;
        amo_operand_a = '0;
        amo_operand_b = '0;

        reservation_d = reservation_q;
        case (state_q)

            IDLE: begin

                if (amo_req_i.req && !busy_i) begin

                    if (!serve_amo_q) begin
                        state_d = FLUSH_REQ_STATUS;
                        serve_amo_d = 1'b1;

                    end else begin
                        state_d = AMO_LOAD;
                        serve_amo_d = 1'b0;
                    end
                end

                if (flush_i && !busy_i) begin
                    state_d = FLUSH_REQ_STATUS;
                    cnt_d = '0;
                end

                for (int unsigned i = 0; i < NR_PORTS; i++) begin

                    if (miss_req_valid[i] && !miss_req_bypass[i]) begin
                        state_d      = MISS;

                        serve_amo_d  = 1'b0;

                        mshr_d.valid = 1'b1;
                        mshr_d.we    = miss_req_we[i];
                        mshr_d.id    = i;
                        mshr_d.addr  = miss_req_addr[i][DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:0];
                        mshr_d.wdata = miss_req_wdata[i];
                        mshr_d.be    = miss_req_be[i];
                        break;
                    end
                end
            end

            MISS: begin

                req_o = '1;
                addr_o = mshr_q.addr[DCACHE_INDEX_WIDTH-1:0];
                state_d = MISS_REPL;
                miss_o = 1'b1;
            end

            MISS_REPL: begin

                if (&valid_way) begin
                    lfsr_enable = 1'b1;
                    evict_way_d = lfsr_oh;

                    if (data_i[lfsr_bin].dirty) begin
                        state_d = WB_CACHELINE_MISS;
                        evict_cl_d.tag = data_i[lfsr_bin].tag;
                        evict_cl_d.data = data_i[lfsr_bin].data;
                        cnt_d = mshr_q.addr[DCACHE_INDEX_WIDTH-1:0];

                    end else
                        state_d = REQ_CACHELINE;

                end else begin

                    evict_way_d = get_victim_cl(~valid_way);
                    state_d = REQ_CACHELINE;
                end
            end

            REQ_CACHELINE: begin
                req_fsm_miss_valid  = 1'b1;
                req_fsm_miss_addr   = mshr_q.addr;

                if (gnt_miss_fsm) begin
                    state_d = SAVE_CACHELINE;
                    miss_gnt_o[mshr_q.id] = 1'b1;
                end
            end

            SAVE_CACHELINE: begin

                automatic logic [$clog2(DCACHE_LINE_WIDTH)-1:0] cl_offset;
                cl_offset = mshr_q.addr[DCACHE_BYTE_OFFSET-1:3] << 6;

                if (valid_miss_fsm) begin

                    addr_o       = mshr_q.addr[DCACHE_INDEX_WIDTH-1:0];
                    req_o        = evict_way_q;
                    we_o         = 1'b1;
                    be_o         = '1;
                    be_o.vldrty  = evict_way_q;
                    data_o.tag   = mshr_q.addr[DCACHE_TAG_WIDTH+DCACHE_INDEX_WIDTH-1:DCACHE_INDEX_WIDTH];
                    data_o.data  = data_miss_fsm;
                    data_o.valid = 1'b1;
                    data_o.dirty = 1'b0;

                    if (mshr_q.we) begin

                        for (int i = 0; i < 8; i++) begin

                            if (mshr_q.be[i])
                                data_o.data[(cl_offset + i*8) +: 8] = mshr_q.wdata[i];
                        end

                        data_o.dirty = 1'b1;
                    end

                    mshr_d.valid = 1'b0;

                    state_d = IDLE;
                end
            end

            WB_CACHELINE_FLUSH, WB_CACHELINE_MISS: begin

                req_fsm_miss_valid  = 1'b1;
                req_fsm_miss_addr   = {evict_cl_q.tag, cnt_q[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET], {{DCACHE_BYTE_OFFSET}{1'b0}}};
                req_fsm_miss_be     = '1;
                req_fsm_miss_we     = 1'b1;
                req_fsm_miss_wdata  = evict_cl_q.data;

                if (gnt_miss_fsm) begin

                    addr_o     = cnt_q;
                    req_o      = 1'b1;
                    we_o       = 1'b1;
                    data_o.valid = INVALIDATE_ON_FLUSH ? 1'b0 : 1'b1;

                    be_o.vldrty = evict_way_q;

                    state_d = (state_q == WB_CACHELINE_MISS) ? MISS : FLUSH_REQ_STATUS;
                end
            end

            FLUSH_REQ_STATUS: begin
                req_o   = '1;
                addr_o  = cnt_q;
                state_d = FLUSHING;
            end

            FLUSHING: begin

                if (|evict_way) begin

                    evict_way_d = get_victim_cl(evict_way);
                    evict_cl_d  = data_i[one_hot_to_bin(evict_way)];
                    state_d     = WB_CACHELINE_FLUSH;

                end else begin

                    cnt_d       = cnt_q + (1'b1 << DCACHE_BYTE_OFFSET);
                    state_d     = FLUSH_REQ_STATUS;
                    addr_o      = cnt_q;
                    req_o       = 1'b1;
                    be_o.vldrty = INVALIDATE_ON_FLUSH ? '1 : '0;
                    we_o        = 1'b1;

                    if (cnt_q[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] == std_cache_pkg::DCACHE_NUM_WORDS-1) begin

                        flush_ack_o = ~serve_amo_q;
                        state_d     = IDLE;
                    end
                end
            end

            INIT: begin

                addr_o = cnt_q;
                req_o  = 1'b1;
                we_o   = 1'b1;

                be_o.vldrty = '1;
                cnt_d       = cnt_q + (1'b1 << DCACHE_BYTE_OFFSET);

                if (cnt_q[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] == std_cache_pkg::DCACHE_NUM_WORDS-1)
                    state_d = IDLE;
            end

            AMO_LOAD: begin
                req_fsm_miss_valid = 1'b1;

                req_fsm_miss_addr = amo_req_i.operand_a;
                req_fsm_miss_req = ariane_axi_pkg::SINGLE_REQ;
                req_fsm_miss_size = amo_req_i.size;

                if (gnt_miss_fsm) begin
                    state_d = AMO_SAVE_LOAD;
                end
            end

            AMO_SAVE_LOAD: begin
                if (valid_miss_fsm) begin

                    mshr_d.wdata = data_miss_fsm[0];
                    state_d = AMO_STORE;
                end
            end

            AMO_STORE: begin
                automatic logic [63:0] load_data;

                load_data = data_align(amo_req_i.operand_a[2:0], mshr_q.wdata);

                if (amo_req_i.size == 2'b10) begin
                    amo_operand_a = sext32(load_data[31:0]);
                    amo_operand_b = sext32(amo_req_i.operand_b[31:0]);
                end else begin
                    amo_operand_a = load_data;
                    amo_operand_b = amo_req_i.operand_b;
                end

                if (amo_req_i.amo_op == AMO_LR ||
                   (amo_req_i.amo_op == AMO_SC &&
                   ((reservation_q.valid && reservation_q.address != amo_req_i.operand_a[63:3]) || !reservation_q.valid))) begin
                    req_fsm_miss_valid = 1'b0;
                    state_d = IDLE;
                    amo_resp_o.ack = 1'b1;

                    amo_resp_o.result = amo_operand_a;

                    if (amo_req_i.amo_op == AMO_SC) begin
                        amo_resp_o.result = 1'b1;

                        reservation_d.valid = 1'b0;
                    end
                end else begin
                    req_fsm_miss_valid = 1'b1;
                end

                req_fsm_miss_we   = 1'b1;
                req_fsm_miss_req  = ariane_axi_pkg::SINGLE_REQ;
                req_fsm_miss_size = amo_req_i.size;
                req_fsm_miss_addr = amo_req_i.operand_a;

                req_fsm_miss_wdata = data_align(amo_req_i.operand_a[2:0], amo_result_o);
                req_fsm_miss_be = be_gen(amo_req_i.operand_a[2:0], amo_req_i.size);

                if (amo_req_i.amo_op == AMO_LR) begin
                    reservation_d.address = amo_req_i.operand_a[63:3];
                    reservation_d.valid = 1'b1;
                end

                if (valid_miss_fsm) begin
                    state_d = IDLE;
                    amo_resp_o.ack = 1'b1;

                    amo_resp_o.result = amo_operand_a;

                    if (amo_req_i.amo_op == AMO_SC) begin
                        amo_resp_o.result = 1'b0;

                        reservation_d.valid = 1'b0;
                    end
                end
            end
        endcase
    end

    always_comb begin

        mshr_addr_matches_o  = 'b0;
        mshr_index_matches_o = 'b0;

        for (int i = 0; i < NR_PORTS; i++) begin

            if (mshr_q.valid && mshr_addr_i[i][55:DCACHE_BYTE_OFFSET] == mshr_q.addr[55:DCACHE_BYTE_OFFSET]) begin
                mshr_addr_matches_o[i] = 1'b1;
            end

            if (mshr_q.valid && mshr_addr_i[i][DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET] == mshr_q.addr[DCACHE_INDEX_WIDTH-1:DCACHE_BYTE_OFFSET]) begin
                mshr_index_matches_o[i] = 1'b1;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mshr_q        <= '0;
            state_q       <= INIT;
            cnt_q         <= '0;
            evict_way_q   <= '0;
            evict_cl_q    <= '0;
            serve_amo_q   <= 1'b0;
            reservation_q <= '0;
        end else begin
            mshr_q        <= mshr_d;
            state_q       <= state_d;
            cnt_q         <= cnt_d;
            evict_way_q   <= evict_way_d;
            evict_cl_q    <= evict_cl_d;
            serve_amo_q   <= serve_amo_d;
            reservation_q <= reservation_d;
        end
    end

    logic                        req_fsm_bypass_valid;
    logic [63:0]                 req_fsm_bypass_addr;
    logic [63:0]                 req_fsm_bypass_wdata;
    logic                        req_fsm_bypass_we;
    logic [7:0]                  req_fsm_bypass_be;
    logic [1:0]                  req_fsm_bypass_size;
    logic                        gnt_bypass_fsm;
    logic                        valid_bypass_fsm;
    logic [63:0]                 data_bypass_fsm;
    logic [$clog2(NR_PORTS)-1:0] id_fsm_bypass;
    logic [3:0]                  id_bypass_fsm;
    logic [3:0]                  gnt_id_bypass_fsm;

    arbiter #(
        .NR_PORTS       ( NR_PORTS                                 ),
        .DATA_WIDTH     ( 64                                       )
    ) i_bypass_arbiter (

        .data_req_i     ( miss_req_valid & miss_req_bypass         ),
        .address_i      ( miss_req_addr                            ),
        .data_wdata_i   ( miss_req_wdata                           ),
        .data_we_i      ( miss_req_we                              ),
        .data_be_i      ( miss_req_be                              ),
        .data_size_i    ( miss_req_size                            ),
        .data_gnt_o     ( bypass_gnt_o                             ),
        .data_rvalid_o  ( bypass_valid_o                           ),
        .data_rdata_o   ( bypass_data_o                            ),

        .id_i           ( id_bypass_fsm[$clog2(NR_PORTS)-1:0]      ),
        .id_o           ( id_fsm_bypass                            ),
        .gnt_id_i       ( gnt_id_bypass_fsm[$clog2(NR_PORTS)-1:0]  ),
        .address_o      ( req_fsm_bypass_addr                      ),
        .data_wdata_o   ( req_fsm_bypass_wdata                     ),
        .data_req_o     ( req_fsm_bypass_valid                     ),
        .data_we_o      ( req_fsm_bypass_we                        ),
        .data_be_o      ( req_fsm_bypass_be                        ),
        .data_size_o    ( req_fsm_bypass_size                      ),
        .data_gnt_i     ( gnt_bypass_fsm                           ),
        .data_rvalid_i  ( valid_bypass_fsm                         ),
        .data_rdata_i   ( data_bypass_fsm                          ),
        .*
    );

    axi_adapter #(
        .DATA_WIDTH            ( 64                 ),
        .AXI_ID_WIDTH          ( 4                  ),
        .CACHELINE_BYTE_OFFSET ( DCACHE_BYTE_OFFSET )
    ) i_bypass_axi_adapter (
        .clk_i,
        .rst_ni,
        .req_i                 ( req_fsm_bypass_valid   ),
        .type_i                ( ariane_axi_pkg::SINGLE_REQ ),
        .gnt_o                 ( gnt_bypass_fsm         ),
        .addr_i                ( req_fsm_bypass_addr    ),
        .we_i                  ( req_fsm_bypass_we      ),
        .wdata_i               ( req_fsm_bypass_wdata   ),
        .be_i                  ( req_fsm_bypass_be      ),
        .size_i                ( req_fsm_bypass_size    ),
        .id_i                  ( {2'b10, id_fsm_bypass} ),
        .valid_o               ( valid_bypass_fsm       ),
        .rdata_o               ( data_bypass_fsm        ),
        .gnt_id_o              ( gnt_id_bypass_fsm      ),
        .id_o                  ( id_bypass_fsm          ),
        .critical_word_o       (                        ),
        .critical_word_valid_o (                        ),
        .axi_req_o             ( axi_bypass_o           ),
        .axi_resp_i            ( axi_bypass_i           )
    );

    axi_adapter  #(
        .DATA_WIDTH            ( DCACHE_LINE_WIDTH  ),
        .AXI_ID_WIDTH          ( 4                  ),
        .CACHELINE_BYTE_OFFSET ( DCACHE_BYTE_OFFSET )
    ) i_miss_axi_adapter (
        .clk_i,
        .rst_ni,
        .req_i               ( req_fsm_miss_valid ),
        .type_i              ( req_fsm_miss_req   ),
        .gnt_o               ( gnt_miss_fsm       ),
        .addr_i              ( req_fsm_miss_addr  ),
        .we_i                ( req_fsm_miss_we    ),
        .wdata_i             ( req_fsm_miss_wdata ),
        .be_i                ( req_fsm_miss_be    ),
        .size_i              ( req_fsm_miss_size  ),
        .id_i                ( 4'b1100            ),
        .gnt_id_o            (                    ),
        .valid_o             ( valid_miss_fsm     ),
        .rdata_o             ( data_miss_fsm      ),
        .id_o                (                    ),
        .critical_word_o,
        .critical_word_valid_o,
        .axi_req_o           ( axi_data_o         ),
        .axi_resp_i          ( axi_data_i         )
    );

    lfsr_8bit #(.WIDTH (DCACHE_SET_ASSOC)) i_lfsr (
        .en_i           ( lfsr_enable ),
        .refill_way_oh  ( lfsr_oh     ),
        .refill_way_bin ( lfsr_bin    ),
        .*
    );

    amo_alu i_amo_alu (
        .amo_op_i        ( amo_op        ),
        .amo_operand_a_i ( amo_operand_a ),
        .amo_operand_b_i ( amo_operand_b ),
        .amo_result_o    ( amo_result_o  )
    );

    always_comb begin
        automatic miss_req_t miss_req;

        for (int unsigned i = 0; i < NR_PORTS; i++) begin
            miss_req =  miss_req_t'(miss_req_i[i]);
            miss_req_valid  [i]  = miss_req.valid;
            miss_req_bypass [i]  = miss_req.bypass;
            miss_req_addr   [i]  = miss_req.addr;
            miss_req_wdata  [i]  = miss_req.wdata;
            miss_req_we     [i]  = miss_req.we;
            miss_req_be     [i]  = miss_req.be;
            miss_req_size   [i]  = miss_req.size;
        end
    end
endmodule

