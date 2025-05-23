module axi_adapter #(
    parameter int unsigned DATA_WIDTH            = 256,
    parameter logic        CRITICAL_WORD_FIRST   = 0, 
    parameter int unsigned AXI_ID_WIDTH          = 10,
    parameter int unsigned CACHELINE_BYTE_OFFSET = 8
)(
    input  logic                                        clk_i,  
    input  logic                                        rst_ni, 

    input  logic                                        req_i,
    input  ariane_axi_pkg::ad_req_t                     type_i,
    output logic                                        gnt_o,
    output logic [AXI_ID_WIDTH-1:0]                     gnt_id_o,
    input  logic [63:0]                                 addr_i,
    input  logic                                        we_i,
    input  logic [(DATA_WIDTH/64)-1:0][63:0]            wdata_i,
    input  logic [(DATA_WIDTH/64)-1:0][7:0]             be_i,
    input  logic [1:0]                                  size_i,
    input  logic [AXI_ID_WIDTH-1:0]                     id_i,

    output logic                                        valid_o,
    output logic [(DATA_WIDTH/64)-1:0][63:0]            rdata_o,
    output logic [AXI_ID_WIDTH-1:0]                     id_o,

    output logic [63:0]                                 critical_word_o,
    output logic                                        critical_word_valid_o,

    output ariane_axi_pkg::m_req_t                        axi_req_o,
    input  ariane_axi_pkg::m_resp_t                       axi_resp_i
);
    localparam BURST_SIZE = DATA_WIDTH/64-1;
    localparam ADDR_INDEX = ($clog2(DATA_WIDTH/64) > 0) ? $clog2(DATA_WIDTH/64) : 1;

    enum logic [3:0] {
        IDLE, WAIT_B_VALID, WAIT_AW_READY, WAIT_LAST_W_READY, WAIT_LAST_W_READY_AW_READY, WAIT_AW_READY_BURST,
        WAIT_R_VALID, WAIT_R_VALID_MULTIPLE, COMPLETE_READ
    } state_q, state_d;

    logic [ADDR_INDEX-1:0] cnt_d, cnt_q;
    logic [(DATA_WIDTH/64)-1:0][63:0] cache_line_d, cache_line_q;

    logic [(DATA_WIDTH/64)-1:0] addr_offset_d, addr_offset_q;
    logic [AXI_ID_WIDTH-1:0]    id_d, id_q;
    logic [ADDR_INDEX-1:0]      index;

    always_comb begin : axi_fsm

        axi_req_o.aw_valid  = 1'b0;
        axi_req_o.aw.addr   = addr_i;
        axi_req_o.aw.prot   = 3'b0;
        axi_req_o.aw.region = 4'b0;
        axi_req_o.aw.len    = 8'b0;
        axi_req_o.aw.size   = {1'b0, size_i};
        axi_req_o.aw.burst  = (type_i == ariane_axi_pkg::SINGLE_REQ) ? 2'b00 :  2'b01;  
        axi_req_o.aw.lock   = 1'b0;
        axi_req_o.aw.cache  = 4'b0;
        axi_req_o.aw.qos    = 4'b0;
        axi_req_o.aw.id     = id_i;
        axi_req_o.aw.atop   = '0; 

        axi_req_o.ar_valid  = 1'b0;

        axi_req_o.ar.addr   = (CRITICAL_WORD_FIRST || type_i == ariane_axi_pkg::SINGLE_REQ) ? addr_i : { addr_i[63:CACHELINE_BYTE_OFFSET], {{CACHELINE_BYTE_OFFSET}{1'b0}}};
        axi_req_o.ar.prot   = 3'b0;
        axi_req_o.ar.region = 4'b0;
        axi_req_o.ar.len    = 8'b0;
        axi_req_o.ar.size   = {1'b0, size_i}; 
        axi_req_o.ar.burst  = (type_i == ariane_axi_pkg::SINGLE_REQ) ? 2'b00 : (CRITICAL_WORD_FIRST ? 2'b10 : 2'b01);  
        axi_req_o.ar.lock   = 1'b0;
        axi_req_o.ar.cache  = 4'b0;
        axi_req_o.ar.qos    = 4'b0;
        axi_req_o.ar.id     = id_i;

        axi_req_o.w_valid   = 1'b0;
        axi_req_o.w.data    = wdata_i[0];
        axi_req_o.w.strb    = be_i[0];
        axi_req_o.w.last    = 1'b0;

        axi_req_o.b_ready   = 1'b0;
        axi_req_o.r_ready   = 1'b0;

        gnt_o         = 1'b0;
        gnt_id_o      = id_i;
        valid_o       = 1'b0;
        id_o          = axi_resp_i.r.id;

        critical_word_o         = axi_resp_i.r.data;
        critical_word_valid_o   = 1'b0;
        rdata_o                 = cache_line_q;

        state_d                 = state_q;
        cnt_d                   = cnt_q;
        cache_line_d            = cache_line_q;
        addr_offset_d           = addr_offset_q;
        id_d                    = id_q;
        index                   = '0;

        case (state_q)

            IDLE: begin
                cnt_d = '0;

                if (req_i) begin

                    if (we_i) begin

                        axi_req_o.aw_valid = 1'b1;
                        axi_req_o.w_valid  = 1'b1;

                        if (type_i == ariane_axi_pkg::SINGLE_REQ) begin

                            axi_req_o.w.last   = 1'b1;

                            gnt_o = axi_resp_i.aw_ready & axi_resp_i.w_ready;
                            case ({axi_resp_i.aw_ready, axi_resp_i.w_ready})
                                2'b11: state_d = WAIT_B_VALID;
                                2'b01: state_d = WAIT_AW_READY;
                                2'b10: state_d = WAIT_LAST_W_READY;
                                default: state_d = IDLE;
                            endcase

                        end else begin
                            axi_req_o.aw.len = BURST_SIZE; 
                            axi_req_o.w.data = wdata_i[0];
                            axi_req_o.w.strb = be_i[0];

                            if (axi_resp_i.w_ready)
                                cnt_d = BURST_SIZE - 1;
                            else
                                cnt_d = BURST_SIZE;

                            case ({axi_resp_i.aw_ready, axi_resp_i.w_ready})
                                2'b11: state_d = WAIT_LAST_W_READY;
                                2'b01: state_d = WAIT_LAST_W_READY_AW_READY;
                                2'b10: state_d = WAIT_LAST_W_READY;
                                default:;
                            endcase
                        end

                    end else begin

                        axi_req_o.ar_valid = 1'b1;
                        gnt_o = axi_resp_i.ar_ready;
                        if (type_i != ariane_axi_pkg::SINGLE_REQ) begin
                            axi_req_o.ar.len = BURST_SIZE;
                            cnt_d = BURST_SIZE;
                        end

                        if (axi_resp_i.ar_ready) begin
                            state_d = (type_i == ariane_axi_pkg::SINGLE_REQ) ? WAIT_R_VALID : WAIT_R_VALID_MULTIPLE;
                            addr_offset_d = addr_i[ADDR_INDEX-1+3:3];
                        end
                    end
                end
            end

            WAIT_AW_READY: begin
                axi_req_o.aw_valid = 1'b1;

                if (axi_resp_i.aw_ready) begin
                    gnt_o   = 1'b1;
                    state_d = WAIT_B_VALID;
                end
            end

            WAIT_LAST_W_READY_AW_READY: begin
                axi_req_o.w_valid  = 1'b1;
                axi_req_o.w.last   = (cnt_q == '0);
                if (type_i == ariane_axi_pkg::SINGLE_REQ) begin
                    axi_req_o.w.data   = wdata_i[0];
                    axi_req_o.w.strb   = be_i[0];
                end else begin
                    axi_req_o.w.data   = wdata_i[BURST_SIZE-cnt_q];
                    axi_req_o.w.strb   = be_i[BURST_SIZE-cnt_q];
                end
                axi_req_o.aw_valid = 1'b1;

                axi_req_o.aw.len   = BURST_SIZE;

                case ({axi_resp_i.aw_ready, axi_resp_i.w_ready})

                    2'b01: begin

                        if (cnt_q == 0)
                            state_d = WAIT_AW_READY_BURST;
                        else 
                            cnt_d = cnt_q - 1;
                    end
                    2'b10: state_d = WAIT_LAST_W_READY;
                    2'b11: begin

                        if (cnt_q == 0) begin
                            state_d  = WAIT_B_VALID;
                            gnt_o    = 1'b1;

                        end else begin
                            state_d = WAIT_LAST_W_READY;
                            cnt_d = cnt_q - 1;
                        end
                    end
                    default:;
               endcase

            end

            WAIT_AW_READY_BURST: begin
                axi_req_o.aw_valid = 1'b1;
                axi_req_o.aw.len   = BURST_SIZE;

                if (axi_resp_i.aw_ready) begin
                    state_d  = WAIT_B_VALID;
                    gnt_o    = 1'b1;
                end
            end

            WAIT_LAST_W_READY: begin
                axi_req_o.w_valid = 1'b1;

                if (type_i != ariane_axi_pkg::SINGLE_REQ) begin
                    axi_req_o.w.data   = wdata_i[BURST_SIZE-cnt_q];
                    axi_req_o.w.strb   = be_i[BURST_SIZE-cnt_q];
                end

                if (cnt_q == '0) begin
                    axi_req_o.w.last = 1'b1;
                    if (axi_resp_i.w_ready) begin
                        state_d  = WAIT_B_VALID;
                        gnt_o    = 1'b1;
                    end
                end else if (axi_resp_i.w_ready) begin
                    cnt_d = cnt_q - 1;
                end
            end

            WAIT_B_VALID: begin
                axi_req_o.b_ready = 1'b1;
                id_o = axi_resp_i.b.id;

                if (axi_resp_i.b_valid) begin
                    state_d = IDLE;
                    valid_o = 1'b1;
                end
            end

            WAIT_R_VALID_MULTIPLE, WAIT_R_VALID: begin
                if (CRITICAL_WORD_FIRST)
                    index = addr_offset_q + (BURST_SIZE-cnt_q);
                else
                    index = BURST_SIZE-cnt_q;

                axi_req_o.r_ready = 1'b1;

                if (axi_resp_i.r_valid) begin
                    if (CRITICAL_WORD_FIRST) begin

                        if (state_q == WAIT_R_VALID_MULTIPLE && cnt_q == BURST_SIZE) begin
                            critical_word_valid_o = 1'b1;
                            critical_word_o       = axi_resp_i.r.data;
                        end
                    end else begin

                        if (index == addr_offset_q) begin
                            critical_word_valid_o = 1'b1;
                            critical_word_o       = axi_resp_i.r.data;
                        end
                    end

                    if (axi_resp_i.r.last) begin
                        id_d    = axi_resp_i.r.id;
                        state_d = COMPLETE_READ;
                    end

                    if (state_q == WAIT_R_VALID_MULTIPLE) begin
                        cache_line_d[index] = axi_resp_i.r.data;

                    end else
                        cache_line_d[0] = axi_resp_i.r.data;

                    cnt_d = cnt_q - 1;
                end
            end

            COMPLETE_READ: begin
                valid_o = 1'b1;
                state_d = IDLE;
                id_o    = id_q;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin

            state_q       <= IDLE;
            cnt_q         <= '0;
            cache_line_q  <= '0;
            addr_offset_q <= '0;
            id_q          <= '0;
        end else begin
            state_q       <= state_d;
            cnt_q         <= cnt_d;
            cache_line_q  <= cache_line_d;
            addr_offset_q <= addr_offset_d;
            id_q          <= id_d;
        end
    end

endmodule
