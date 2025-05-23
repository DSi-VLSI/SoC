import ariane_pkg::*;module load_unit (
    input  logic                     clk_i,    
    input  logic                     rst_ni,   
    input  logic                     flush_i,

    input  logic                     valid_i,
    input  lsu_ctrl_t                lsu_ctrl_i,
    output logic                     pop_ld_o,

    output logic                     valid_o,
    output logic [TRANS_ID_BITS-1:0] trans_id_o,
    output logic [63:0]              result_o,
    output exception_t               ex_o,

    output logic                     translation_req_o,   
    output logic [63:0]              vaddr_o,             
    input  logic [63:0]              paddr_i,             
    input  exception_t               ex_i,                
    input  logic                     dtlb_hit_i,          

    output logic [11:0]              page_offset_o,
    input  logic                     page_offset_matches_i,

    input dcache_req_o_t             req_port_i,
    output dcache_req_i_t            req_port_o
);
    enum logic [2:0] { IDLE, WAIT_GNT, SEND_TAG, WAIT_PAGE_OFFSET,
                       ABORT_TRANSACTION, WAIT_TRANSLATION, WAIT_FLUSH
                     } state_d, state_q;

    struct packed {
        logic [TRANS_ID_BITS-1:0] trans_id;
        logic [2:0]               address_offset;
        fu_op                     operator;
    } load_data_d, load_data_q, in_data;

    assign page_offset_o = lsu_ctrl_i.vaddr[11:0];

    assign vaddr_o = lsu_ctrl_i.vaddr;

    assign req_port_o.data_we = 1'b0;
    assign req_port_o.data_wdata = '0;

    assign in_data = {lsu_ctrl_i.trans_id, lsu_ctrl_i.vaddr[2:0], lsu_ctrl_i.operator};

    assign req_port_o.address_index = lsu_ctrl_i.vaddr[ariane_pkg::DCACHE_INDEX_WIDTH-1:0];

    assign req_port_o.address_tag   = paddr_i[ariane_pkg::DCACHE_TAG_WIDTH     +
                                              ariane_pkg::DCACHE_INDEX_WIDTH-1 :
                                              ariane_pkg::DCACHE_INDEX_WIDTH];

    assign ex_o = ex_i;

    always_comb begin : load_control

        state_d              = state_q;
        load_data_d          = load_data_q;
        translation_req_o    = 1'b0;
        req_port_o.data_req  = 1'b0;

        req_port_o.kill_req  = 1'b0;
        req_port_o.tag_valid = 1'b0;
        req_port_o.data_be   = lsu_ctrl_i.be;
        req_port_o.data_size = extract_transfer_size(lsu_ctrl_i.operator);
        pop_ld_o             = 1'b0;

        case (state_q)
            IDLE: begin

                if (valid_i) begin

                    translation_req_o = 1'b1;

                    if (!page_offset_matches_i) begin

                        req_port_o.data_req = 1'b1;

                        if (!req_port_i.data_gnt) begin
                            state_d = WAIT_GNT;
                        end else begin
                            if (dtlb_hit_i) begin

                                state_d = SEND_TAG;
                                pop_ld_o = 1'b1;
                            end else
                                state_d = ABORT_TRANSACTION;
                        end
                    end else begin

                        state_d = WAIT_PAGE_OFFSET;
                    end
                end
            end

            WAIT_PAGE_OFFSET: begin

                if (!page_offset_matches_i) begin
                    state_d = WAIT_GNT;
                end
            end

            ABORT_TRANSACTION: begin
                req_port_o.kill_req  = 1'b1;
                req_port_o.tag_valid = 1'b1;

                state_d = WAIT_TRANSLATION;
            end

            WAIT_TRANSLATION: begin
                translation_req_o = 1'b1;

                if (dtlb_hit_i)
                    state_d = WAIT_GNT;
            end

            WAIT_GNT: begin

                translation_req_o = 1'b1;

                req_port_o.data_req = 1'b1;

                if (req_port_i.data_gnt) begin

                    if (dtlb_hit_i) begin
                        state_d = SEND_TAG;
                        pop_ld_o = 1'b1;
                    end else 
                        state_d = ABORT_TRANSACTION;
                end

            end

            SEND_TAG: begin
                req_port_o.tag_valid = 1'b1;
                state_d = IDLE;

                if (valid_i) begin

                    translation_req_o = 1'b1;

                    if (!page_offset_matches_i) begin

                        req_port_o.data_req = 1'b1;

                        if (!req_port_i.data_gnt) begin
                            state_d = WAIT_GNT;
                        end else begin

                            if (dtlb_hit_i) begin

                                state_d = SEND_TAG;
                                pop_ld_o = 1'b1;
                            end else 
                                state_d = ABORT_TRANSACTION;
                        end
                    end else begin

                        state_d = WAIT_PAGE_OFFSET;
                    end
                end

                if (ex_i.valid) begin
                    req_port_o.kill_req = 1'b1;
                end
            end

            WAIT_FLUSH: begin

                req_port_o.kill_req  = 1'b1;
                req_port_o.tag_valid = 1'b1;

                state_d = IDLE;
            end

        endcase

        if (ex_i.valid && valid_i) begin

            state_d = IDLE;

            if (!req_port_i.data_rvalid)
                pop_ld_o = 1'b1;
        end

        if (pop_ld_o && !ex_i.valid) begin
            load_data_d = in_data;
        end

        if (flush_i) begin
            state_d = WAIT_FLUSH;
        end
    end

    always_comb begin : rvalid_output
        valid_o = 1'b0;

        trans_id_o = load_data_q.trans_id;

        if (req_port_i.data_rvalid && state_q != WAIT_FLUSH) begin

            if(!req_port_o.kill_req)
                valid_o = 1'b1;

            if (ex_i.valid)
                valid_o = 1'b1;
        end

        if (valid_i && ex_i.valid && !req_port_i.data_rvalid) begin
            valid_o    = 1'b1;
            trans_id_o = lsu_ctrl_i.trans_id;

        end else if (state_q == WAIT_TRANSLATION) begin
            valid_o = 1'b0;
        end

    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q     <= IDLE;
            load_data_q <= '0;
        end else begin
            state_q     <= state_d;
            load_data_q <= load_data_d;
        end
    end

    logic [63:0] shifted_data;

    assign shifted_data   = req_port_i.data_rdata >> {load_data_q.address_offset, 3'b000};

    logic [7:0]  sign_bits;
    logic [2:0]  idx_d, idx_q;
    logic        sign_bit, signed_d, signed_q, fp_sign_d, fp_sign_q;

    assign signed_d  = load_data_d.operator inside {LW, LH, LB};
    assign fp_sign_d = load_data_d.operator inside {FLW, FLH, FLB};
    assign idx_d     = (load_data_d.operator inside {LW, FLW}) ? load_data_d.address_offset + 3 :
                       (load_data_d.operator inside {LH, FLH}) ? load_data_d.address_offset + 1 :
                                                                 load_data_d.address_offset;

    assign sign_bits = { req_port_i.data_rdata[63],
                         req_port_i.data_rdata[55],
                         req_port_i.data_rdata[47],
                         req_port_i.data_rdata[39],
                         req_port_i.data_rdata[31],
                         req_port_i.data_rdata[23],
                         req_port_i.data_rdata[15],
                         req_port_i.data_rdata[7]  };

    assign sign_bit       = signed_q & sign_bits[idx_q] | fp_sign_q;

    always_comb begin
        unique case (load_data_q.operator)
            LW, LWU, FLW:    result_o = {{32{sign_bit}}, shifted_data[31:0]};
            LH, LHU, FLH:    result_o = {{48{sign_bit}}, shifted_data[15:0]};
            LB, LBU, FLB:    result_o = {{56{sign_bit}}, shifted_data[7:0]};
            default:    result_o = shifted_data;
        endcase
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : p_regs
        if (~rst_ni) begin
            idx_q     <= 0;
            signed_q  <= 0;
            fp_sign_q <= 0;
        end else begin
            idx_q     <= idx_d;
            signed_q  <= signed_d;
            fp_sign_q <= fp_sign_d;
        end
    end

endmodule
