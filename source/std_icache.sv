import ariane_pkg::*;
import std_cache_pkg::*;module std_icache (
    input logic             clk_i,
    input logic             rst_ni,
    input riscv_pkg::priv_lvl_t priv_lvl_i,

    input logic flush_i,  
    input logic en_i,  
    output logic miss_o,  

    input icache_areq_i_t areq_i,
    output icache_areq_o_t areq_o,

    input icache_dreq_i_t dreq_i,
    output icache_dreq_o_t dreq_o,

    output ariane_axi_pkg::m_req_t axi_req_o,
    input ariane_axi_pkg::m_resp_t axi_resp_i
);

  localparam int unsigned ICACHE_BYTE_OFFSET = $clog2(ICACHE_LINE_WIDTH / 8);  
  localparam int unsigned ICACHE_NUM_WORD = 2 ** (ICACHE_INDEX_WIDTH - ICACHE_BYTE_OFFSET);
  localparam int unsigned NR_AXI_REFILLS = ($clog2(
      ICACHE_LINE_WIDTH / 64
  ) == 0) ? 1 : $clog2(
      ICACHE_LINE_WIDTH / 64
  );

  enum logic [3:0] {
    FLUSH,
    IDLE,
    TAG_CMP,
    WAIT_AXI_R_RESP,
    WAIT_KILLED_REFILL,
    WAIT_KILLED_AXI_R_RESP,
    REDO_REQ,
    TAG_CMP_SAVED,
    REFILL,
    WAIT_ADDRESS_TRANSLATION,
    WAIT_ADDRESS_TRANSLATION_KILLED
  }
      state_d, state_q;
  logic [$clog2(ICACHE_NUM_WORD)-1:0] cnt_d, cnt_q;
  logic [NR_AXI_REFILLS-1:0] burst_cnt_d, burst_cnt_q;  
  logic [63:0] vaddr_d, vaddr_q;
  logic [ICACHE_TAG_WIDTH-1:0] tag_d, tag_q;
  logic [ICACHE_SET_ASSOC-1:0] evict_way_d, evict_way_q;
  logic flushing_d, flushing_q;

  logic [ICACHE_SET_ASSOC-1:0] req;  
  logic [ICACHE_SET_ASSOC-1:0] vld_req;  
  logic [(ICACHE_LINE_WIDTH+7)/8-1:0] data_be;  
  logic [(2**NR_AXI_REFILLS-1):0][7:0] be;  
  logic [$clog2(ICACHE_NUM_WORD)-1:0] addr;  
  logic we;  
  logic [ICACHE_SET_ASSOC-1:0] hit;  
  logic [$clog2(ICACHE_NUM_WORD)-1:0] idx;  
  logic update_lfsr;  
  logic [ICACHE_SET_ASSOC-1:0] random_way;  
  logic [ICACHE_SET_ASSOC-1:0] way_valid;  
  logic [$clog2(ICACHE_SET_ASSOC)-1:0] repl_invalid;  
  logic repl_w_random;  
  logic [ICACHE_TAG_WIDTH-1:0] tag;  

  struct packed {
    logic                        valid;
    logic [ICACHE_TAG_WIDTH-1:0] tag;
  }
      tag_rdata[ICACHE_SET_ASSOC-1:0], tag_wdata;

  logic [ICACHE_LINE_WIDTH-1:0] data_rdata[ICACHE_SET_ASSOC-1:0], data_wdata;
  logic [(2**NR_AXI_REFILLS-1):0][63:0] wdata;

  for (genvar i = 0; i < ICACHE_SET_ASSOC; i++) begin : sram_block

    sram #(

        .DATA_WIDTH(ICACHE_TAG_WIDTH + 1),
        .NUM_WORDS (ICACHE_NUM_WORD)
    ) tag_sram (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .req_i  (vld_req[i]),
        .we_i   (we),
        .addr_i (addr),
        .wdata_i(tag_wdata),
        .be_i   ('1),
        .rdata_o(tag_rdata[i])
    );

    sram #(
        .DATA_WIDTH(ICACHE_LINE_WIDTH),
        .NUM_WORDS (ICACHE_NUM_WORD)
    ) data_sram (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),
        .req_i  (req[i]),
        .we_i   (we),
        .addr_i (addr),
        .wdata_i(data_wdata),
        .be_i   (data_be),
        .rdata_o(data_rdata[i])
    );

  end

  logic [ICACHE_SET_ASSOC-1:0][FETCH_WIDTH-1:0] cl_sel;

  assign idx = vaddr_q[ICACHE_BYTE_OFFSET-1:2];

  generate
    for (genvar i = 0; i < ICACHE_SET_ASSOC; i++) begin : g_tag_cmpsel
      assign hit[i] = (tag_rdata[i].tag == tag) ? tag_rdata[i].valid : 1'b0;
      assign cl_sel[i] = (hit[i]) ? data_rdata[i][{idx, 5'b0}+:FETCH_WIDTH] : '0;
      assign way_valid[i] = tag_rdata[i].valid;
    end
  endgenerate

  always_comb begin : p_reduction
    dreq_o.data = cl_sel[0];
    for (int i = 1; i < ICACHE_SET_ASSOC; i++) dreq_o.data |= cl_sel[i];
  end

  assign axi_req_o.aw_valid = '0;
  assign axi_req_o.aw.addr = '0;
  assign axi_req_o.aw.prot = '0;
  assign axi_req_o.aw.region = '0;
  assign axi_req_o.aw.len = '0;
  assign axi_req_o.aw.size = 3'b000;
  assign axi_req_o.aw.burst = 2'b00;
  assign axi_req_o.aw.lock = '0;
  assign axi_req_o.aw.cache = '0;
  assign axi_req_o.aw.qos = '0;
  assign axi_req_o.aw.id = '0;
  assign axi_req_o.aw.atop = '0;
  assign axi_req_o.w_valid = '0;
  assign axi_req_o.w.data = '0;
  assign axi_req_o.w.strb = '0;
  assign axi_req_o.w.last = 1'b0;
  assign axi_req_o.b_ready = 1'b0;

  assign axi_req_o.ar.prot = {1'b1, 1'b0, (priv_lvl_i == riscv_pkg::PRIV_LVL_M)};
  assign axi_req_o.ar.region = '0;
  assign axi_req_o.ar.len = (2 ** NR_AXI_REFILLS) - 1;
  assign axi_req_o.ar.size = 3'b011;
  assign axi_req_o.ar.burst = 2'b01;
  assign axi_req_o.ar.lock = '0;
  assign axi_req_o.ar.cache = '0;
  assign axi_req_o.ar.qos = '0;
  assign axi_req_o.ar.id = '0;

  assign axi_req_o.r_ready = 1'b1;

  assign data_be = be;
  assign data_wdata = wdata;

  assign dreq_o.ex = areq_i.fetch_exception;

  assign addr = (state_q == FLUSH) ? cnt_q : vaddr_d[ICACHE_INDEX_WIDTH-1:ICACHE_BYTE_OFFSET];

  always_comb begin : cache_ctrl

    state_d = state_q;
    cnt_d = cnt_q;
    vaddr_d = vaddr_q;
    tag_d = tag_q;
    evict_way_d = evict_way_q;
    flushing_d = flushing_q;
    burst_cnt_d = burst_cnt_q;

    dreq_o.vaddr = vaddr_q;

    req = '0;
    vld_req = '0;
    we = 1'b0;
    be = '0;
    wdata = '0;
    tag_wdata = '0;
    dreq_o.ready = 1'b0;
    tag = areq_i.fetch_paddr[ICACHE_TAG_WIDTH+ICACHE_INDEX_WIDTH-1:ICACHE_INDEX_WIDTH];
    dreq_o.valid = 1'b0;
    update_lfsr = 1'b0;
    miss_o = 1'b0;

    axi_req_o.ar_valid = 1'b0;
    axi_req_o.ar.addr = '0;

    areq_o.fetch_req = 1'b0;
    areq_o.fetch_vaddr = vaddr_q;

    case (state_q)

      IDLE: begin
        dreq_o.ready = 1'b1;
        vaddr_d      = dreq_i.vaddr;

        if (dreq_i.req) begin

          req     = '1;
          vld_req = '1;

          state_d = TAG_CMP;
        end

        if (flush_i || flushing_q) state_d = FLUSH;

        if (dreq_i.kill_s1) state_d = IDLE;
      end

      TAG_CMP, TAG_CMP_SAVED: begin
        areq_o.fetch_req = 1'b1;  

        req              = '1;
        vld_req          = '1;

        if (state_q == TAG_CMP_SAVED) tag = tag_q;

        if (|hit && areq_i.fetch_valid && (en_i || (state_q != TAG_CMP))) begin
          dreq_o.ready = 1'b1;
          dreq_o.valid = 1'b1;
          vaddr_d      = dreq_i.vaddr;

          if (dreq_i.req) begin

            state_d = TAG_CMP;

          end else begin
            state_d = IDLE;
          end

          if (dreq_i.kill_s1) state_d = IDLE;

        end else begin
          state_d = REFILL;

          evict_way_d = hit;

          tag_d = areq_i.fetch_paddr[ICACHE_TAG_WIDTH+ICACHE_INDEX_WIDTH-1:ICACHE_INDEX_WIDTH];
          miss_o = en_i;

          if (!(|hit)) begin

            if (repl_w_random) begin
              evict_way_d = random_way;

              update_lfsr = 1'b1;

            end else begin
              evict_way_d[repl_invalid] = 1'b1;
            end
          end
        end

        if (!areq_i.fetch_valid) begin
          state_d = WAIT_ADDRESS_TRANSLATION;
        end
      end

      WAIT_ADDRESS_TRANSLATION, WAIT_ADDRESS_TRANSLATION_KILLED: begin
        areq_o.fetch_req = 1'b1;

        if (areq_i.fetch_valid && (state_q == WAIT_ADDRESS_TRANSLATION)) begin
          if (areq_i.fetch_exception.valid) begin
            dreq_o.valid = 1'b1;
            state_d = IDLE;
          end else begin
            state_d = REDO_REQ;
            tag_d   = areq_i.fetch_paddr[ICACHE_TAG_WIDTH+ICACHE_INDEX_WIDTH-1:ICACHE_INDEX_WIDTH];
          end
        end else if (areq_i.fetch_valid) begin
          state_d = IDLE;
        end

        if (dreq_i.kill_s2) state_d = WAIT_ADDRESS_TRANSLATION_KILLED;
      end

      REFILL, WAIT_KILLED_REFILL: begin
        axi_req_o.ar_valid = 1'b1;
        axi_req_o.ar.addr[ICACHE_INDEX_WIDTH+ICACHE_TAG_WIDTH-1:0] = {
          tag_q, vaddr_q[ICACHE_INDEX_WIDTH-1:ICACHE_BYTE_OFFSET], {ICACHE_BYTE_OFFSET{1'b0}}
        };
        burst_cnt_d = '0;

        if (dreq_i.kill_s2) state_d = WAIT_KILLED_REFILL;

        if (axi_resp_i.ar_ready)
          state_d = (dreq_i.kill_s2 || (state_q == WAIT_KILLED_REFILL)) ? WAIT_KILLED_AXI_R_RESP : WAIT_AXI_R_RESP;
      end

      WAIT_AXI_R_RESP, WAIT_KILLED_AXI_R_RESP: begin

        req     = evict_way_q;
        vld_req = evict_way_q;

        if (axi_resp_i.r_valid) begin
          we = 1'b1;
          tag_wdata.tag = tag_q;
          tag_wdata.valid = 1'b1;
          wdata[burst_cnt_q] = axi_resp_i.r.data;

          be[burst_cnt_q] = '1;

          burst_cnt_d = burst_cnt_q + 1;
        end

        if (dreq_i.kill_s2) state_d = WAIT_KILLED_AXI_R_RESP;

        if (axi_resp_i.r_valid && axi_resp_i.r.last) begin
          state_d = (dreq_i.kill_s2) ? IDLE : REDO_REQ;
        end

        if ((state_q == WAIT_KILLED_AXI_R_RESP) && axi_resp_i.r.last && axi_resp_i.r_valid)
          state_d = IDLE;
      end

      REDO_REQ: begin
        req     = '1;
        vld_req = '1;
        tag     = tag_q;
        state_d = TAG_CMP_SAVED;  
      end

      FLUSH: begin
        cnt_d   = cnt_q + 1;
        vld_req = '1;
        we      = 1;

        if (cnt_q == ICACHE_NUM_WORD - 1) begin
          state_d = IDLE;
          flushing_d = 1'b0;
        end
      end

      default: state_d = IDLE;
    endcase

    if (dreq_i.kill_s2 && !(state_q inside {
                                                    REFILL,
                                                    WAIT_AXI_R_RESP,
                                                    WAIT_KILLED_AXI_R_RESP,
                                                    WAIT_KILLED_REFILL,
                                                    WAIT_ADDRESS_TRANSLATION,
                                                    WAIT_ADDRESS_TRANSLATION_KILLED})
                           && !dreq_o.ready) begin
      state_d = IDLE;
    end

    if (dreq_i.kill_s2) dreq_o.valid = 1'b0;

    if (flush_i) begin
      flushing_d   = 1'b1;
      dreq_o.ready = 1'b0;  
    end

    if (flushing_q) dreq_o.ready = 1'b0;
  end

  lzc #(
      .WIDTH(ICACHE_SET_ASSOC)
  ) i_lzc (
      .in_i   (~way_valid),
      .cnt_o  (repl_invalid),
      .empty_o(repl_w_random)
  );

  lfsr_8bit #(
      .WIDTH(ICACHE_SET_ASSOC)
  ) i_lfsr (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .en_i          (update_lfsr),
      .refill_way_oh (random_way),
      .refill_way_bin()              
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q     <= FLUSH;
      cnt_q       <= '0;
      vaddr_q     <= '0;
      tag_q       <= '0;
      evict_way_q <= '0;
      flushing_q  <= 1'b0;
      burst_cnt_q <= '0;
      ;
    end else begin
      state_q     <= state_d;
      cnt_q       <= cnt_d;
      vaddr_q     <= vaddr_d;
      tag_q       <= tag_d;
      evict_way_q <= evict_way_d;
      flushing_q  <= flushing_d;
      burst_cnt_q <= burst_cnt_d;
    end
  end

endmodule
