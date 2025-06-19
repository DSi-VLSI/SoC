import ariane_pkg::*;
module ariane #(
    parameter logic [63:0] DmBaseAddress = 64'h0,
    parameter logic [63:0] CachedAddrBeg = 64'h00_8000_0000
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [63:0] boot_addr_i,
    input logic [63:0] hart_id_i,

    input logic [1:0] irq_i,
    input logic       ipi_i,

    input logic time_irq_i,
    input logic debug_req_i,

    output ariane_axi_pkg::m_req_t  axi_req_o,
    input  ariane_axi_pkg::m_resp_t axi_resp_i
);

  riscv_pkg::priv_lvl_t                             priv_lvl;
  exception_t                                       ex_commit;
  branchpredict_t                                   resolved_branch;
  logic                 [               63:0]       pc_commit;
  logic                                             eret;
  logic                 [NR_COMMIT_PORTS-1:0]       commit_ack;

  logic                 [               63:0]       trap_vector_base_commit_pcgen;
  logic                 [               63:0]       epc_commit_pcgen;

  frontend_fetch_t                                  fetch_entry_if_id;
  logic                                             fetch_valid_if_id;
  logic                                             decode_ack_id_if;

  scoreboard_entry_t                                issue_entry_id_issue;
  logic                                             issue_entry_valid_id_issue;
  logic                                             is_ctrl_fow_id_issue;
  logic                                             issue_instr_issue_id;

  fu_data_t                                         fu_data_id_ex;
  logic                 [               63:0]       pc_id_ex;
  logic                                             is_compressed_instr_id_ex;

  logic                                             flu_ready_ex_id;
  logic                 [  TRANS_ID_BITS-1:0]       flu_trans_id_ex_id;
  logic                                             flu_valid_ex_id;
  logic                 [               63:0]       flu_result_ex_id;
  exception_t                                       flu_exception_ex_id;

  logic                                             alu_valid_id_ex;

  logic                                             branch_valid_id_ex;

  branchpredict_sbe_t                               branch_predict_id_ex;
  logic                                             resolve_branch_ex_id;

  logic                                             lsu_valid_id_ex;
  logic                                             lsu_ready_ex_id;

  logic                 [  TRANS_ID_BITS-1:0]       load_trans_id_ex_id;
  logic                 [               63:0]       load_result_ex_id;
  logic                                             load_valid_ex_id;
  exception_t                                       load_exception_ex_id;

  logic                 [               63:0]       store_result_ex_id;
  logic                 [  TRANS_ID_BITS-1:0]       store_trans_id_ex_id;
  logic                                             store_valid_ex_id;
  exception_t                                       store_exception_ex_id;

  logic                                             mult_valid_id_ex;

  logic                                             fpu_ready_ex_id;
  logic                                             fpu_valid_id_ex;
  logic                 [                1:0]       fpu_fmt_id_ex;
  logic                 [                2:0]       fpu_rm_id_ex;
  logic                 [  TRANS_ID_BITS-1:0]       fpu_trans_id_ex_id;
  logic                 [               63:0]       fpu_result_ex_id;
  logic                                             fpu_valid_ex_id;
  exception_t                                       fpu_exception_ex_id;

  logic                                             csr_valid_id_ex;

  logic                                             csr_commit_commit_ex;
  logic                                             dirty_fp_state;

  logic                                             lsu_commit_commit_ex;
  logic                                             lsu_commit_ready_ex_commit;
  logic                                             no_st_pending_ex;
  logic                                             no_st_pending_commit;
  logic                                             amo_valid_commit;

  scoreboard_entry_t    [NR_COMMIT_PORTS-1:0]       commit_instr_id_commit;

  logic                 [NR_COMMIT_PORTS-1:0][ 4:0] waddr_commit_id;
  logic                 [NR_COMMIT_PORTS-1:0][63:0] wdata_commit_id;
  logic                 [NR_COMMIT_PORTS-1:0]       we_gpr_commit_id;
  logic                 [NR_COMMIT_PORTS-1:0]       we_fpr_commit_id;

  logic                 [                4:0]       fflags_csr_commit;
  riscv_pkg::xs_t                                   fs;
  logic                 [                2:0]       frm_csr_id_issue_ex;
  logic                 [                6:0]       fprec_csr_ex;
  logic                                             enable_translation_csr_ex;
  logic                                             en_ld_st_translation_csr_ex;
  riscv_pkg::priv_lvl_t                             ld_st_priv_lvl_csr_ex;
  logic                                             sum_csr_ex;
  logic                                             mxr_csr_ex;
  logic                 [               43:0]       satp_ppn_csr_ex;
  logic                 [                0:0]       asid_csr_ex;
  logic                 [               11:0]       csr_addr_ex_csr;
  fu_op                                             csr_op_commit_csr;
  logic                 [               63:0]       csr_wdata_commit_csr;
  logic                 [               63:0]       csr_rdata_csr_commit;
  exception_t                                       csr_exception_csr_commit;
  logic                                             tvm_csr_id;
  logic                                             tw_csr_id;
  logic                                             tsr_csr_id;
  logic                                             dcache_en_csr_nbdcache;
  logic                                             csr_write_fflags_commit_cs;
  logic                                             icache_en_csr;
  logic                                             debug_mode;
  logic                                             single_step_csr_commit;

  logic                 [                4:0]       addr_csr_perf;
  logic [63:0] data_csr_perf, data_perf_csr;
  logic           we_csr_perf;

  logic           icache_flush_ctrl_cache;
  logic           itlb_miss_ex_perf;
  logic           dtlb_miss_ex_perf;
  logic           dcache_miss_cache_perf;
  logic           icache_miss_cache_perf;

  logic           set_pc_ctrl_pcgen;
  logic           flush_csr_ctrl;
  logic           flush_unissued_instr_ctrl_id;
  logic           flush_ctrl_if;
  logic           flush_ctrl_id;
  logic           flush_ctrl_ex;
  logic           flush_tlb_ctrl_ex;
  logic           fence_i_commit_controller;
  logic           fence_commit_controller;
  logic           sfence_vma_commit_controller;
  logic           halt_ctrl;
  logic           halt_csr_ctrl;
  logic           dcache_flush_ctrl_cache;
  logic           dcache_flush_ack_cache_ctrl;
  logic           set_debug_pc;
  logic           flush_commit;

  icache_areq_i_t icache_areq_ex_cache;
  icache_areq_o_t icache_areq_cache_ex;
  icache_dreq_i_t icache_dreq_if_cache;
  icache_dreq_o_t icache_dreq_cache_if;

  amo_req_t       amo_req;
  amo_resp_t      amo_resp;
  logic           sb_full;

  logic           debug_req;

  assign debug_req = debug_req_i & ~amo_valid_commit;

  dcache_req_i_t [2:0] dcache_req_ports_ex_cache;
  dcache_req_o_t [2:0] dcache_req_ports_cache_ex;
  logic                dcache_commit_wbuffer_empty;

  frontend #(
      .DmBaseAddress(DmBaseAddress)
  ) i_frontend (
      .flush_i            (flush_ctrl_if),
      .flush_bp_i         (1'b0),
      .debug_mode_i       (debug_mode),
      .boot_addr_i        (boot_addr_i),
      .icache_dreq_i      (icache_dreq_cache_if),
      .icache_dreq_o      (icache_dreq_if_cache),
      .resolved_branch_i  (resolved_branch),
      .pc_commit_i        (pc_commit),
      .set_pc_commit_i    (set_pc_ctrl_pcgen),
      .set_debug_pc_i     (set_debug_pc),
      .epc_i              (epc_commit_pcgen),
      .eret_i             (eret),
      .trap_vector_base_i (trap_vector_base_commit_pcgen),
      .ex_valid_i         (ex_commit.valid),
      .fetch_entry_o      (fetch_entry_if_id),
      .fetch_entry_valid_o(fetch_valid_if_id),
      .fetch_ack_i        (decode_ack_id_if),
      .*
  );

  id_stage id_stage_i (
      .flush_i(flush_ctrl_if),

      .fetch_entry_i      (fetch_entry_if_id),
      .fetch_entry_valid_i(fetch_valid_if_id),
      .decoded_instr_ack_o(decode_ack_id_if),

      .issue_entry_o      (issue_entry_id_issue),
      .issue_entry_valid_o(issue_entry_valid_id_issue),
      .is_ctrl_flow_o     (is_ctrl_fow_id_issue),
      .issue_instr_ack_i  (issue_instr_issue_id),

      .priv_lvl_i  (priv_lvl),
      .fs_i        (fs),
      .frm_i       (frm_csr_id_issue_ex),
      .debug_mode_i(debug_mode),
      .tvm_i       (tvm_csr_id),
      .tw_i        (tw_csr_id),
      .tsr_i       (tsr_csr_id),
      .*
  );

  issue_stage #(
      .NR_ENTRIES (NR_SB_ENTRIES),
      .NR_WB_PORTS(NR_WB_PORTS)
  ) issue_stage_i (
      .clk_i,
      .rst_ni,
      .sb_full_o(sb_full),
      .flush_unissued_instr_i(flush_unissued_instr_ctrl_id),
      .flush_i(flush_ctrl_id),

      .decoded_instr_i(issue_entry_id_issue),
      .decoded_instr_valid_i(issue_entry_valid_id_issue),
      .is_ctrl_flow_i(is_ctrl_fow_id_issue),
      .decoded_instr_ack_o(issue_instr_issue_id),

      .fu_data_o(fu_data_id_ex),
      .pc_o(pc_id_ex),
      .is_compressed_instr_o(is_compressed_instr_id_ex),

      .flu_ready_i(flu_ready_ex_id),

      .alu_valid_o(alu_valid_id_ex),

      .branch_valid_o  (branch_valid_id_ex),
      .branch_predict_o(branch_predict_id_ex),
      .resolve_branch_i(resolve_branch_ex_id),

      .lsu_ready_i(lsu_ready_ex_id),
      .lsu_valid_o(lsu_valid_id_ex),

      .mult_valid_o(mult_valid_id_ex),

      .fpu_ready_i(fpu_ready_ex_id),
      .fpu_valid_o(fpu_valid_id_ex),
      .fpu_fmt_o(fpu_fmt_id_ex),
      .fpu_rm_o(fpu_rm_id_ex),

      .csr_valid_o(csr_valid_id_ex),

      .resolved_branch_i(resolved_branch),
      .trans_id_i({
        flu_trans_id_ex_id, load_trans_id_ex_id, store_trans_id_ex_id, fpu_trans_id_ex_id
      }),
      .wbdata_i({flu_result_ex_id, load_result_ex_id, store_result_ex_id, fpu_result_ex_id}),
      .ex_ex_i({
        flu_exception_ex_id, load_exception_ex_id, store_exception_ex_id, fpu_exception_ex_id
      }),
      .wb_valid_i({flu_valid_ex_id, load_valid_ex_id, store_valid_ex_id, fpu_valid_ex_id}),

      .waddr_i       (waddr_commit_id),
      .wdata_i       (wdata_commit_id),
      .we_gpr_i      (we_gpr_commit_id),
      .we_fpr_i      (we_fpr_commit_id),
      .commit_instr_o(commit_instr_id_commit),
      .commit_ack_i  (commit_ack),
      .*
  );

  ex_stage ex_stage_i (
      .clk_i                (clk_i),
      .rst_ni               (rst_ni),
      .flush_i              (flush_ctrl_ex),
      .fu_data_i            (fu_data_id_ex),
      .pc_i                 (pc_id_ex),
      .is_compressed_instr_i(is_compressed_instr_id_ex),

      .flu_result_o   (flu_result_ex_id),
      .flu_trans_id_o (flu_trans_id_ex_id),
      .flu_valid_o    (flu_valid_ex_id),
      .flu_exception_o(flu_exception_ex_id),
      .flu_ready_o    (flu_ready_ex_id),

      .alu_valid_i(alu_valid_id_ex),

      .branch_valid_i   (branch_valid_id_ex),
      .branch_predict_i (branch_predict_id_ex),
      .resolved_branch_o(resolved_branch),
      .resolve_branch_o (resolve_branch_ex_id),

      .csr_valid_i (csr_valid_id_ex),
      .csr_addr_o  (csr_addr_ex_csr),
      .csr_commit_i(csr_commit_commit_ex),

      .mult_valid_i(mult_valid_id_ex),

      .lsu_ready_o(lsu_ready_ex_id),
      .lsu_valid_i(lsu_valid_id_ex),

      .load_result_o   (load_result_ex_id),
      .load_trans_id_o (load_trans_id_ex_id),
      .load_valid_o    (load_valid_ex_id),
      .load_exception_o(load_exception_ex_id),

      .store_result_o   (store_result_ex_id),
      .store_trans_id_o (store_trans_id_ex_id),
      .store_valid_o    (store_valid_ex_id),
      .store_exception_o(store_exception_ex_id),

      .lsu_commit_i      (lsu_commit_commit_ex),
      .lsu_commit_ready_o(lsu_commit_ready_ex_commit),
      .no_st_pending_o   (no_st_pending_ex),

      .fpu_ready_o       (fpu_ready_ex_id),
      .fpu_valid_i       (fpu_valid_id_ex),
      .fpu_fmt_i         (fpu_fmt_id_ex),
      .fpu_rm_i          (fpu_rm_id_ex),
      .fpu_frm_i         (frm_csr_id_issue_ex),
      .fpu_prec_i        (fprec_csr_ex),
      .fpu_trans_id_o    (fpu_trans_id_ex_id),
      .fpu_result_o      (fpu_result_ex_id),
      .fpu_valid_o       (fpu_valid_ex_id),
      .fpu_exception_o   (fpu_exception_ex_id),
      .amo_valid_commit_i(amo_valid_commit),
      .amo_req_o         (amo_req),
      .amo_resp_i        (amo_resp),

      .itlb_miss_o(itlb_miss_ex_perf),
      .dtlb_miss_o(dtlb_miss_ex_perf),

      .enable_translation_i  (enable_translation_csr_ex),
      .en_ld_st_translation_i(en_ld_st_translation_csr_ex),
      .flush_tlb_i           (flush_tlb_ctrl_ex),
      .priv_lvl_i            (priv_lvl),
      .ld_st_priv_lvl_i      (ld_st_priv_lvl_csr_ex),
      .sum_i                 (sum_csr_ex),
      .mxr_i                 (mxr_csr_ex),
      .satp_ppn_i            (satp_ppn_csr_ex),
      .asid_i                (asid_csr_ex),
      .icache_areq_i         (icache_areq_cache_ex),
      .icache_areq_o         (icache_areq_ex_cache),

      .dcache_req_ports_i(dcache_req_ports_cache_ex),
      .dcache_req_ports_o(dcache_req_ports_ex_cache)
  );

  assign no_st_pending_commit = no_st_pending_ex & dcache_commit_wbuffer_empty;

  commit_stage commit_stage_i (
      .clk_i,
      .rst_ni,
      .halt_i            (halt_ctrl),
      .flush_dcache_i    (dcache_flush_ctrl_cache),
      .exception_o       (ex_commit),
      .dirty_fp_state_o  (dirty_fp_state),
      .debug_mode_i      (debug_mode),
      .debug_req_i       (debug_req),
      .single_step_i     (single_step_csr_commit),
      .commit_instr_i    (commit_instr_id_commit),
      .commit_ack_o      (commit_ack),
      .no_st_pending_i   (no_st_pending_commit),
      .waddr_o           (waddr_commit_id),
      .wdata_o           (wdata_commit_id),
      .we_gpr_o          (we_gpr_commit_id),
      .we_fpr_o          (we_fpr_commit_id),
      .commit_lsu_o      (lsu_commit_commit_ex),
      .commit_lsu_ready_i(lsu_commit_ready_ex_commit),
      .amo_valid_commit_o(amo_valid_commit),
      .amo_resp_i        (amo_resp),
      .commit_csr_o      (csr_commit_commit_ex),
      .pc_o              (pc_commit),
      .csr_op_o          (csr_op_commit_csr),
      .csr_wdata_o       (csr_wdata_commit_csr),
      .csr_rdata_i       (csr_rdata_csr_commit),
      .csr_write_fflags_o(csr_write_fflags_commit_cs),
      .csr_exception_i   (csr_exception_csr_commit),
      .fence_i_o         (fence_i_commit_controller),
      .fence_o           (fence_commit_controller),
      .sfence_vma_o      (sfence_vma_commit_controller),
      .flush_commit_o    (flush_commit),
      .*
  );

  csr_regfile #(
      .AsidWidth    (ASID_WIDTH),
      .DmBaseAddress(DmBaseAddress)
  ) csr_regfile_i (
      .flush_o               (flush_csr_ctrl),
      .halt_csr_o            (halt_csr_ctrl),
      .commit_instr_i        (commit_instr_id_commit),
      .commit_ack_i          (commit_ack),
      .ex_i                  (ex_commit),
      .csr_op_i              (csr_op_commit_csr),
      .csr_write_fflags_i    (csr_write_fflags_commit_cs),
      .dirty_fp_state_i      (dirty_fp_state),
      .csr_addr_i            (csr_addr_ex_csr),
      .csr_wdata_i           (csr_wdata_commit_csr),
      .csr_rdata_o           (csr_rdata_csr_commit),
      .pc_i                  (pc_commit),
      .csr_exception_o       (csr_exception_csr_commit),
      .epc_o                 (epc_commit_pcgen),
      .eret_o                (eret),
      .set_debug_pc_o        (set_debug_pc),
      .trap_vector_base_o    (trap_vector_base_commit_pcgen),
      .priv_lvl_o            (priv_lvl),
      .fs_o                  (fs),
      .fflags_o              (fflags_csr_commit),
      .frm_o                 (frm_csr_id_issue_ex),
      .fprec_o               (fprec_csr_ex),
      .ld_st_priv_lvl_o      (ld_st_priv_lvl_csr_ex),
      .en_translation_o      (enable_translation_csr_ex),
      .en_ld_st_translation_o(en_ld_st_translation_csr_ex),
      .sum_o                 (sum_csr_ex),
      .mxr_o                 (mxr_csr_ex),
      .satp_ppn_o            (satp_ppn_csr_ex),
      .asid_o                (asid_csr_ex),
      .tvm_o                 (tvm_csr_id),
      .tw_o                  (tw_csr_id),
      .tsr_o                 (tsr_csr_id),
      .debug_mode_o          (debug_mode),
      .single_step_o         (single_step_csr_commit),
      .dcache_en_o           (dcache_en_csr_nbdcache),
      .icache_en_o           (icache_en_csr),
      .perf_addr_o           (addr_csr_perf),
      .perf_data_o           (data_csr_perf),
      .perf_data_i           (data_perf_csr),
      .perf_we_o             (we_csr_perf),
      .debug_req_i           (debug_req),
      .ipi_i,
      .irq_i,
      .time_irq_i,
      .*
  );

  perf_counters i_perf_counters (
      .clk_i         (clk_i),
      .rst_ni        (rst_ni),
      .debug_mode_i  (debug_mode),
      .addr_i        (addr_csr_perf),
      .we_i          (we_csr_perf),
      .data_i        (data_csr_perf),
      .data_o        (data_perf_csr),
      .commit_instr_i(commit_instr_id_commit),
      .commit_ack_i  (commit_ack),

      .l1_icache_miss_i (icache_miss_cache_perf),
      .l1_dcache_miss_i (dcache_miss_cache_perf),
      .itlb_miss_i      (itlb_miss_ex_perf),
      .dtlb_miss_i      (dtlb_miss_ex_perf),
      .sb_full_i        (sb_full),
      .if_empty_i       (~fetch_valid_if_id),
      .ex_i             (ex_commit),
      .eret_i           (eret),
      .resolved_branch_i(resolved_branch)
  );

  controller controller_i (

      .set_pc_commit_o       (set_pc_ctrl_pcgen),
      .flush_unissued_instr_o(flush_unissued_instr_ctrl_id),
      .flush_if_o            (flush_ctrl_if),
      .flush_id_o            (flush_ctrl_id),
      .flush_ex_o            (flush_ctrl_ex),
      .flush_tlb_o           (flush_tlb_ctrl_ex),
      .flush_dcache_o        (dcache_flush_ctrl_cache),
      .flush_dcache_ack_i    (dcache_flush_ack_cache_ctrl),

      .halt_csr_i(halt_csr_ctrl),
      .halt_o    (halt_ctrl),

      .eret_i           (eret),
      .ex_valid_i       (ex_commit.valid),
      .set_debug_pc_i   (set_debug_pc),
      .flush_csr_i      (flush_csr_ctrl),
      .resolved_branch_i(resolved_branch),
      .fence_i_i        (fence_i_commit_controller),
      .fence_i          (fence_commit_controller),
      .sfence_vma_i     (sfence_vma_commit_controller),
      .flush_commit_i   (flush_commit),

      .flush_icache_o(icache_flush_ctrl_cache),
      .*
  );

  std_cache_subsystem #(
      .CACHE_START_ADDR(CachedAddrBeg)
  ) i_cache_subsystem (

      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .priv_lvl_i(priv_lvl),

      .icache_en_i   (icache_en_csr),
      .icache_flush_i(icache_flush_ctrl_cache),
      .icache_miss_o (icache_miss_cache_perf),
      .icache_areq_i (icache_areq_ex_cache),
      .icache_areq_o (icache_areq_cache_ex),
      .icache_dreq_i (icache_dreq_if_cache),
      .icache_dreq_o (icache_dreq_cache_if),

      .dcache_enable_i   (dcache_en_csr_nbdcache),
      .dcache_flush_i    (dcache_flush_ctrl_cache),
      .dcache_flush_ack_o(dcache_flush_ack_cache_ctrl),

      .amo_req_i    (amo_req),
      .amo_resp_o   (amo_resp),
      .dcache_miss_o(dcache_miss_cache_perf),

      .wbuffer_empty_o(dcache_commit_wbuffer_empty),

      .dcache_req_ports_i(dcache_req_ports_ex_cache),
      .dcache_req_ports_o(dcache_req_ports_cache_ex),

      .axi_req_o (axi_req_o),
      .axi_resp_i(axi_resp_i)
  );

  int f;
  logic [63:0] cycles;

  initial begin
    f = $fopen("trace_hart_00.dasm", "w");
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cycles <= 0;
    end else begin
      automatic string mode = "";
      if (debug_mode) mode = "D";
      else begin
        case (priv_lvl)
          riscv_pkg::PRIV_LVL_M: mode = "M";
          riscv_pkg::PRIV_LVL_S: mode = "S";
          riscv_pkg::PRIV_LVL_U: mode = "U";
        endcase
      end
      for (int i = 0; i < NR_COMMIT_PORTS; i++) begin
        if (commit_ack[i] && !commit_instr_id_commit[i].ex.valid) begin
          $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_id_commit[i].pc, mode,
                  commit_instr_id_commit[i].ex.tval[31:0], commit_instr_id_commit[i].ex.tval[31:0]);
        end else if (commit_ack[i] && commit_instr_id_commit[i].ex.valid) begin
          if (commit_instr_id_commit[i].ex.cause == 2) begin
            $fwrite(f, "Exception Cause: Illegal Instructions, DASM(%h) PC=%h\n",
                    commit_instr_id_commit[i].ex.tval[31:0], commit_instr_id_commit[i].pc);
          end else begin
            if (debug_mode) begin
              $fwrite(f, "%d 0x%0h %s (0x%h) DASM(%h)\n", cycles, commit_instr_id_commit[i].pc,
                      mode, commit_instr_id_commit[i].ex.tval[31:0],
                      commit_instr_id_commit[i].ex.tval[31:0]);
            end else begin
              $fwrite(f, "Exception Cause: %5d, DASM(%h) PC=%h\n",
                      commit_instr_id_commit[i].ex.cause, commit_instr_id_commit[i].ex.tval[31:0],
                      commit_instr_id_commit[i].pc);
            end
          end
        end
      end
      cycles <= cycles + 1;
    end
  end

  final begin
    $fclose(f);
  end

endmodule

