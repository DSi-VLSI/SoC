import ariane_pkg::*;module perf_counters #(
    int unsigned NR_EXTERNAL_COUNTERS = 1
)(
    input  logic                                    clk_i,
    input  logic                                    rst_ni,
    input  logic                                    debug_mode_i, 

    input  logic [4:0]                              addr_i,   
    input  logic                                    we_i,     
    input  logic [63:0]                             data_i,   
    output logic [63:0]                             data_o,   

    input  scoreboard_entry_t [NR_COMMIT_PORTS-1:0] commit_instr_i,     
    input  logic [NR_COMMIT_PORTS-1:0]              commit_ack_i,       

    input  logic                                    l1_icache_miss_i,
    input  logic                                    l1_dcache_miss_i,

    input  logic                                    itlb_miss_i,
    input  logic                                    dtlb_miss_i,

    input  logic                                    sb_full_i,

    input  logic                                    if_empty_i,

    input  exception_t                              ex_i,
    input  logic                                    eret_i,
    input  branchpredict_t                          resolved_branch_i
);

    logic [riscv_pkg::CSR_IF_EMPTY[4:0] : riscv_pkg::CSR_L1_ICACHE_MISS[4:0]][63:0] perf_counter_d, perf_counter_q;

    always_comb begin : perf_counters
        perf_counter_d = perf_counter_q;
        data_o = 'b0;

        if (!debug_mode_i) begin

            if (l1_icache_miss_i)
                perf_counter_d[riscv_pkg::CSR_L1_ICACHE_MISS[4:0]] = perf_counter_q[riscv_pkg::CSR_L1_ICACHE_MISS[4:0]] + 1'b1;

            if (l1_dcache_miss_i)
                perf_counter_d[riscv_pkg::CSR_L1_DCACHE_MISS[4:0]] = perf_counter_q[riscv_pkg::CSR_L1_DCACHE_MISS[4:0]] + 1'b1;

            if (itlb_miss_i)
                perf_counter_d[riscv_pkg::CSR_ITLB_MISS[4:0]] = perf_counter_q[riscv_pkg::CSR_ITLB_MISS[4:0]] + 1'b1;

            if (dtlb_miss_i)
                perf_counter_d[riscv_pkg::CSR_DTLB_MISS[4:0]] = perf_counter_q[riscv_pkg::CSR_DTLB_MISS[4:0]] + 1'b1;

            for (int unsigned i = 0; i < NR_COMMIT_PORTS-1; i++) begin
                if (commit_ack_i[i]) begin
                    if (commit_instr_i[i].fu == LOAD)
                        perf_counter_d[riscv_pkg::CSR_LOAD[4:0]] = perf_counter_q[riscv_pkg::CSR_LOAD[4:0]] + 1'b1;

                    if (commit_instr_i[i].fu == STORE)
                        perf_counter_d[riscv_pkg::CSR_STORE[4:0]] = perf_counter_q[riscv_pkg::CSR_STORE[4:0]] + 1'b1;

                    if (commit_instr_i[i].fu == CTRL_FLOW)
                        perf_counter_d[riscv_pkg::CSR_BRANCH_JUMP[4:0]] = perf_counter_q[riscv_pkg::CSR_BRANCH_JUMP[4:0]] + 1'b1;

                    if (commit_instr_i[i].fu == CTRL_FLOW && commit_instr_i[i].op == '0 && commit_instr_i[i].rd == 'b1)
                        perf_counter_d[riscv_pkg::CSR_CALL[4:0]] = perf_counter_q[riscv_pkg::CSR_CALL[4:0]] + 1'b1;

                    if (commit_instr_i[i].op == JALR && commit_instr_i[i].rs1 == 'b1)
                        perf_counter_d[riscv_pkg::CSR_RET[4:0]] = perf_counter_q[riscv_pkg::CSR_RET[4:0]] + 1'b1;
                end
            end

            if (ex_i.valid)
                perf_counter_d[riscv_pkg::CSR_EXCEPTION[4:0]] = perf_counter_q[riscv_pkg::CSR_EXCEPTION[4:0]] + 1'b1;

            if (eret_i)
                perf_counter_d[riscv_pkg::CSR_EXCEPTION_RET[4:0]] = perf_counter_q[riscv_pkg::CSR_EXCEPTION_RET[4:0]] + 1'b1;

            if (resolved_branch_i.valid && resolved_branch_i.is_mispredict)
                perf_counter_d[riscv_pkg::CSR_MIS_PREDICT[4:0]] = perf_counter_q[riscv_pkg::CSR_MIS_PREDICT[4:0]] + 1'b1;

            if (sb_full_i) begin
                perf_counter_d[riscv_pkg::CSR_SB_FULL[4:0]] = perf_counter_q[riscv_pkg::CSR_SB_FULL[4:0]] + 1'b1;
            end

            if (if_empty_i) begin
                perf_counter_d[riscv_pkg::CSR_IF_EMPTY[4:0]] = perf_counter_q[riscv_pkg::CSR_IF_EMPTY[4:0]] + 1'b1;
            end
        end

        data_o = perf_counter_q[addr_i];
        if (we_i) begin
            perf_counter_d[addr_i] = data_i;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
           perf_counter_q <= '0;
        end else begin
           perf_counter_q <= perf_counter_d;
        end
    end

endmodule
