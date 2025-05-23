import ariane_pkg::*;module csr_regfile #(
    parameter logic [63:0] DmBaseAddress   = 64'h0, 
    parameter int          AsidWidth       = 1,
    parameter int unsigned NrCommitPorts   = 2
) (
    input  logic                  clk_i,                      
    input  logic                  rst_ni,                     
    input  logic                  time_irq_i,                 

    output logic                  flush_o,
    output logic                  halt_csr_o,                 

    input  scoreboard_entry_t [NrCommitPorts-1:0] commit_instr_i, 
    input  logic [NrCommitPorts-1:0]              commit_ack_i,   

    input  logic  [63:0]          boot_addr_i,                
    input  logic  [63:0]          hart_id_i,                  

    input exception_t             ex_i,                       

    input  fu_op                  csr_op_i,                   
    input  logic  [11:0]          csr_addr_i,                 
    input  logic  [63:0]          csr_wdata_i,                
    output logic  [63:0]          csr_rdata_o,                
    input  logic                  dirty_fp_state_i,           
    input  logic                  csr_write_fflags_i,         
    input  logic  [63:0]          pc_i,                       
    output exception_t            csr_exception_o,            

    output logic  [63:0]          epc_o,                      
    output logic                  eret_o,                     
    output logic  [63:0]          trap_vector_base_o,         
    output riscv_pkg::priv_lvl_t      priv_lvl_o,                 

    output riscv_pkg::xs_t            fs_o,                       
    output logic [4:0]            fflags_o,                   
    output logic [2:0]            frm_o,                      
    output logic [6:0]            fprec_o,                    

    output logic                  en_translation_o,           
    output logic                  en_ld_st_translation_o,     
    output riscv_pkg::priv_lvl_t      ld_st_priv_lvl_o,           
    output logic                  sum_o,
    output logic                  mxr_o,
    output logic [43:0]           satp_ppn_o,
    output logic [AsidWidth-1:0] asid_o,

    input  logic [1:0]            irq_i,                      
    input  logic                  ipi_i,                      
    input  logic                  debug_req_i,                
    output logic                  set_debug_pc_o,

    output logic                  tvm_o,                      
    output logic                  tw_o,                       
    output logic                  tsr_o,                      
    output logic                  debug_mode_o,               
    output logic                  single_step_o,              

    output logic                  icache_en_o,                
    output logic                  dcache_en_o,                

    output logic  [4:0]           perf_addr_o,                
    output logic  [63:0]          perf_data_o,                
    input  logic  [63:0]          perf_data_i,                
    output logic                  perf_we_o
);

    logic        read_access_exception, update_access_exception;
    logic        csr_we, csr_read;
    logic [63:0] csr_wdata, csr_rdata;
    riscv_pkg::priv_lvl_t   trap_to_priv_lvl;

    logic        en_ld_st_translation_d, en_ld_st_translation_q;
    logic  mprv;
    logic  mret;  
    logic  sret;  
    logic  dret;  

    logic  dirty_fp_state_csr;
    riscv_pkg::csr_t  csr_addr;

    assign csr_addr = riscv_pkg::csr_t'(csr_addr_i);
    assign fs_o = mstatus_q.fs;

    riscv_pkg::priv_lvl_t   priv_lvl_d, priv_lvl_q;

    logic        debug_mode_q, debug_mode_d;

    riscv_pkg::status_rv64_t  mstatus_q,  mstatus_d;
    riscv_pkg::satp_t         satp_q, satp_d;
    riscv_pkg::dcsr_t         dcsr_q,     dcsr_d;

    logic        mtvec_rst_load_q;

    logic [63:0] dpc_q,       dpc_d;
    logic [63:0] dscratch0_q, dscratch0_d;
    logic [63:0] dscratch1_q, dscratch1_d;
    logic [63:0] mtvec_q,     mtvec_d;
    logic [63:0] medeleg_q,   medeleg_d;
    logic [63:0] mideleg_q,   mideleg_d;
    logic [63:0] mip_q,       mip_d;
    logic [63:0] mie_q,       mie_d;
    logic [63:0] mscratch_q,  mscratch_d;
    logic [63:0] mepc_q,      mepc_d;
    logic [63:0] mcause_q,    mcause_d;
    logic [63:0] mtval_q,     mtval_d;

    logic [63:0] stvec_q,     stvec_d;
    logic [63:0] sscratch_q,  sscratch_d;
    logic [63:0] sepc_q,      sepc_d;
    logic [63:0] scause_q,    scause_d;
    logic [63:0] stval_q,     stval_d;
    logic [63:0] dcache_q,    dcache_d;
    logic [63:0] icache_q,    icache_d;

    logic        wfi_d,       wfi_q;

    logic [63:0] cycle_q,     cycle_d;
    logic [63:0] instret_q,   instret_d;

    riscv_pkg::fcsr_t fcsr_q, fcsr_d;

    always_comb begin : csr_read_process

        read_access_exception = 1'b0;
        csr_rdata = 64'b0;
        perf_addr_o = csr_addr.address[4:0];;

        if (csr_read) begin
            unique case (csr_addr.address)
                riscv_pkg::CSR_FFLAGS: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {59'b0, fcsr_q.fflags};
                    end
                end
                riscv_pkg::CSR_FRM: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {61'b0, fcsr_q.frm};
                    end
                end
                riscv_pkg::CSR_FCSR: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {56'b0, fcsr_q.frm, fcsr_q.fflags};
                    end
                end

                riscv_pkg::CSR_FTRAN: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = {57'b0, fcsr_q.fprec};
                    end
                end

                riscv_pkg::CSR_DCSR:               csr_rdata = {32'b0, dcsr_q};
                riscv_pkg::CSR_DPC:                csr_rdata = dpc_q;
                riscv_pkg::CSR_DSCRATCH0:          csr_rdata = dscratch0_q;
                riscv_pkg::CSR_DSCRATCH1:          csr_rdata = dscratch1_q;

                riscv_pkg::CSR_TSELECT:; 
                riscv_pkg::CSR_TDATA1:;  
                riscv_pkg::CSR_TDATA2:;  
                riscv_pkg::CSR_TDATA3:;  

                riscv_pkg::CSR_SSTATUS: begin
                    csr_rdata = mstatus_q & ariane_pkg::SMODE_STATUS_READ_MASK;
                end
                riscv_pkg::CSR_SIE:                csr_rdata = mie_q & mideleg_q;
                riscv_pkg::CSR_SIP:                csr_rdata = mip_q & mideleg_q;
                riscv_pkg::CSR_STVEC:              csr_rdata = stvec_q;
                riscv_pkg::CSR_SCOUNTEREN:         csr_rdata = 64'b0; 
                riscv_pkg::CSR_SSCRATCH:           csr_rdata = sscratch_q;
                riscv_pkg::CSR_SEPC:               csr_rdata = sepc_q;
                riscv_pkg::CSR_SCAUSE:             csr_rdata = scause_q;
                riscv_pkg::CSR_STVAL:              csr_rdata = stval_q;
                riscv_pkg::CSR_SATP: begin

                    if (priv_lvl_o == riscv_pkg::PRIV_LVL_S && mstatus_q.tvm) begin
                        read_access_exception = 1'b1;
                    end else begin
                        csr_rdata = satp_q;
                    end
                end

                riscv_pkg::CSR_MSTATUS:            csr_rdata = mstatus_q;
                riscv_pkg::CSR_MISA:               csr_rdata = ISA_CODE;
                riscv_pkg::CSR_MEDELEG:            csr_rdata = medeleg_q;
                riscv_pkg::CSR_MIDELEG:            csr_rdata = mideleg_q;
                riscv_pkg::CSR_MIE:                csr_rdata = mie_q;
                riscv_pkg::CSR_MTVEC:              csr_rdata = mtvec_q;
                riscv_pkg::CSR_MCOUNTEREN:         csr_rdata = 64'b0; 
                riscv_pkg::CSR_MSCRATCH:           csr_rdata = mscratch_q;
                riscv_pkg::CSR_MEPC:               csr_rdata = mepc_q;
                riscv_pkg::CSR_MCAUSE:             csr_rdata = mcause_q;
                riscv_pkg::CSR_MTVAL:              csr_rdata = mtval_q;
                riscv_pkg::CSR_MIP:                csr_rdata = mip_q;
                riscv_pkg::CSR_MVENDORID:          csr_rdata = 64'b0; 
                riscv_pkg::CSR_MARCHID:            csr_rdata = ARIANE_MARCHID;
                riscv_pkg::CSR_MIMPID:             csr_rdata = 64'b0; 
                riscv_pkg::CSR_MHARTID:            csr_rdata = hart_id_i;
                riscv_pkg::CSR_MCYCLE:             csr_rdata = cycle_q;
                riscv_pkg::CSR_MINSTRET:           csr_rdata = instret_q;

                riscv_pkg::CSR_DCACHE:             csr_rdata = dcache_q;
                riscv_pkg::CSR_ICACHE:             csr_rdata = icache_q;

                riscv_pkg::CSR_CYCLE:              csr_rdata = cycle_q;
                riscv_pkg::CSR_INSTRET:            csr_rdata = instret_q;
                riscv_pkg::CSR_L1_ICACHE_MISS,
                riscv_pkg::CSR_L1_DCACHE_MISS,
                riscv_pkg::CSR_ITLB_MISS,
                riscv_pkg::CSR_DTLB_MISS,
                riscv_pkg::CSR_LOAD,
                riscv_pkg::CSR_STORE,
                riscv_pkg::CSR_EXCEPTION,
                riscv_pkg::CSR_EXCEPTION_RET,
                riscv_pkg::CSR_BRANCH_JUMP,
                riscv_pkg::CSR_CALL,
                riscv_pkg::CSR_RET,
                riscv_pkg::CSR_MIS_PREDICT,
                riscv_pkg::CSR_SB_FULL,
                riscv_pkg::CSR_IF_EMPTY:           csr_rdata   = perf_data_i;
                default: read_access_exception = 1'b1;
            endcase
        end
    end

    logic [63:0] mask;
    always_comb begin : csr_update
        automatic riscv_pkg::satp_t sapt;
        automatic logic [63:0] instret;

        sapt = satp_q;
        instret = instret_q;

        cycle_d = cycle_q;
        instret_d = instret_q;
        if (!debug_mode_q) begin

            for (int i = 0; i < NrCommitPorts; i++) begin
                if (commit_ack_i[i] && !ex_i.valid) instret++;
            end
            instret_d = instret;

            if (ENABLE_CYCLE_COUNT) cycle_d = cycle_q + 1'b1;
            else cycle_d = instret;
        end

        eret_o                  = 1'b0;
        flush_o                 = 1'b0;
        update_access_exception = 1'b0;

        set_debug_pc_o          = 1'b0;

        perf_we_o               = 1'b0;
        perf_data_o             = 'b0;

        fcsr_d                  = fcsr_q;

        priv_lvl_d              = priv_lvl_q;
        debug_mode_d            = debug_mode_q;
        dcsr_d                  = dcsr_q;
        dpc_d                   = dpc_q;
        dscratch0_d             = dscratch0_q;
        dscratch1_d             = dscratch1_q;
        mstatus_d               = mstatus_q;

        if (mtvec_rst_load_q) begin
            mtvec_d             = boot_addr_i + 'h40;
        end else begin
            mtvec_d             = mtvec_q;
        end

        medeleg_d               = medeleg_q;
        mideleg_d               = mideleg_q;
        mip_d                   = mip_q;
        mie_d                   = mie_q;
        mepc_d                  = mepc_q;
        mcause_d                = mcause_q;
        mscratch_d              = mscratch_q;
        mtval_d                 = mtval_q;
        dcache_d                = dcache_q;
        icache_d                = icache_q;

        sepc_d                  = sepc_q;
        scause_d                = scause_q;
        stvec_d                 = stvec_q;
        sscratch_d              = sscratch_q;
        stval_d                 = stval_q;
        satp_d                  = satp_q;

        en_ld_st_translation_d  = en_ld_st_translation_q;
        dirty_fp_state_csr      = 1'b0;

        if (csr_we) begin
            unique case (csr_addr.address)

                riscv_pkg::CSR_FFLAGS: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.fflags = csr_wdata[4:0];

                        flush_o = 1'b1;
                    end
                end
                riscv_pkg::CSR_FRM: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.frm    = csr_wdata[2:0];

                        flush_o = 1'b1;
                    end
                end
                riscv_pkg::CSR_FCSR: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d[7:0] = csr_wdata[7:0]; 

                        flush_o = 1'b1;
                    end
                end
                riscv_pkg::CSR_FTRAN: begin
                    if (mstatus_q.fs == riscv_pkg::Off) begin
                        update_access_exception = 1'b1;
                    end else begin
                        dirty_fp_state_csr = 1'b1;
                        fcsr_d.fprec = csr_wdata[6:0]; 

                        flush_o = 1'b1;
                    end
                end

                riscv_pkg::CSR_DCSR: begin
                    dcsr_d = csr_wdata[31:0];

                    dcsr_d.xdebugver = 4'h4;

                    dcsr_d.prv = priv_lvl_q;

                    dcsr_d.nmip      = 1'b0;
                    dcsr_d.stopcount = 1'b0;
                    dcsr_d.stoptime  = 1'b0;
                end
                riscv_pkg::CSR_DPC:                dpc_d = csr_wdata;
                riscv_pkg::CSR_DSCRATCH0:          dscratch0_d = csr_wdata;
                riscv_pkg::CSR_DSCRATCH1:          dscratch1_d = csr_wdata;

                riscv_pkg::CSR_TSELECT:; 
                riscv_pkg::CSR_TDATA1:;  
                riscv_pkg::CSR_TDATA2:;  
                riscv_pkg::CSR_TDATA3:;  

                riscv_pkg::CSR_SSTATUS: begin
                    mask = ariane_pkg::SMODE_STATUS_WRITE_MASK;
                    mstatus_d = (mstatus_q & ~mask) | (csr_wdata & mask);

                    if (!FP_PRESENT) begin
                        mstatus_d.fs = riscv_pkg::Off;
                    end

                    mstatus_d.sd   = (&mstatus_q.xs) | (&mstatus_q.fs);

                    flush_o = 1'b1;
                end

                riscv_pkg::CSR_SIE: begin

                    mie_d = (mie_q & ~mideleg_q) | (csr_wdata & mideleg_q);
                end

                riscv_pkg::CSR_SIP: begin

                    mask = riscv_pkg::MIP_SSIP & mideleg_q;
                    mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                end

                riscv_pkg::CSR_SCOUNTEREN:;
                riscv_pkg::CSR_STVEC:              stvec_d     = {csr_wdata[63:2], 1'b0, csr_wdata[0]};
                riscv_pkg::CSR_SSCRATCH:           sscratch_d  = csr_wdata;
                riscv_pkg::CSR_SEPC:               sepc_d      = {csr_wdata[63:1], 1'b0};
                riscv_pkg::CSR_SCAUSE:             scause_d    = csr_wdata;
                riscv_pkg::CSR_STVAL:              stval_d     = csr_wdata;

                riscv_pkg::CSR_SATP: begin

                    if (priv_lvl_o == riscv_pkg::PRIV_LVL_S && mstatus_q.tvm)
                        update_access_exception = 1'b1;
                    else begin
                        sapt      = riscv_pkg::satp_t'(csr_wdata);

                        sapt.asid = sapt.asid & {{(16-AsidWidth){1'b0}}, {AsidWidth{1'b1}}};

                        if (sapt.mode == MODE_OFF || sapt.mode == MODE_SV39) satp_d = sapt;
                    end

                    flush_o = 1'b1;
                end

                riscv_pkg::CSR_MSTATUS: begin
                    mstatus_d      = csr_wdata;

                    mstatus_d.sd   = (&mstatus_q.xs) | (&mstatus_q.fs);
                    mstatus_d.xs   = riscv_pkg::Off;
                    if (!FP_PRESENT) begin
                        mstatus_d.fs = riscv_pkg::Off;
                    end
                    mstatus_d.upie = 1'b0;
                    mstatus_d.uie  = 1'b0;

                    flush_o        = 1'b1;
                end

                riscv_pkg::CSR_MISA:;

                riscv_pkg::CSR_MEDELEG: begin
                    mask = (1 << riscv_pkg::INSTR_ADDR_MISALIGNED) |
                           (1 << riscv_pkg::BREAKPOINT) |
                           (1 << riscv_pkg::ENV_CALL_UMODE) |
                           (1 << riscv_pkg::INSTR_PAGE_FAULT) |
                           (1 << riscv_pkg::LOAD_PAGE_FAULT) |
                           (1 << riscv_pkg::STORE_PAGE_FAULT);
                    medeleg_d = (medeleg_q & ~mask) | (csr_wdata & mask);
                end

                riscv_pkg::CSR_MIDELEG: begin
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP;
                    mideleg_d = (mideleg_q & ~mask) | (csr_wdata & mask);
                end

                riscv_pkg::CSR_MIE: begin
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP | riscv_pkg::MIP_MSIP | riscv_pkg::MIP_MTIP;
                    mie_d = (mie_q & ~mask) | (csr_wdata & mask); 
                end

                riscv_pkg::CSR_MTVEC: begin
                    mtvec_d = {csr_wdata[63:2], 1'b0, csr_wdata[0]};

                    if (csr_wdata[0]) mtvec_d = {csr_wdata[63:8], 7'b0, csr_wdata[0]};
                end
                riscv_pkg::CSR_MCOUNTEREN:;

                riscv_pkg::CSR_MSCRATCH:           mscratch_d  = csr_wdata;
                riscv_pkg::CSR_MEPC:               mepc_d      = {csr_wdata[63:1], 1'b0};
                riscv_pkg::CSR_MCAUSE:             mcause_d    = csr_wdata;
                riscv_pkg::CSR_MTVAL:              mtval_d     = csr_wdata;
                riscv_pkg::CSR_MIP: begin
                    mask = riscv_pkg::MIP_SSIP | riscv_pkg::MIP_STIP | riscv_pkg::MIP_SEIP;
                    mip_d = (mip_q & ~mask) | (csr_wdata & mask);
                end

                riscv_pkg::CSR_MCYCLE:             cycle_d     = csr_wdata;
                riscv_pkg::CSR_MINSTRET:           instret     = csr_wdata;
                riscv_pkg::CSR_DCACHE:             dcache_d    = csr_wdata[0]; 
                riscv_pkg::CSR_ICACHE:             icache_d    = csr_wdata[0]; 
                riscv_pkg::CSR_L1_ICACHE_MISS,
                riscv_pkg::CSR_L1_DCACHE_MISS,
                riscv_pkg::CSR_ITLB_MISS,
                riscv_pkg::CSR_DTLB_MISS,
                riscv_pkg::CSR_LOAD,
                riscv_pkg::CSR_STORE,
                riscv_pkg::CSR_EXCEPTION,
                riscv_pkg::CSR_EXCEPTION_RET,
                riscv_pkg::CSR_BRANCH_JUMP,
                riscv_pkg::CSR_CALL,
                riscv_pkg::CSR_RET,
                riscv_pkg::CSR_MIS_PREDICT: begin
                                        perf_data_o = csr_wdata;
                                        perf_we_o   = 1'b1;
                end
                default: update_access_exception = 1'b1;
            endcase
        end

        mstatus_d.sxl  = riscv_pkg::XLEN_64;
        mstatus_d.uxl  = riscv_pkg::XLEN_64;

        if (FP_PRESENT && (dirty_fp_state_csr || dirty_fp_state_i)) begin
            mstatus_d.fs = riscv_pkg::Dirty;
        end

        if (csr_write_fflags_i) begin
            fcsr_d.fflags = csr_wdata_i[4:0] | fcsr_q.fflags;
        end

        mip_d[riscv_pkg::IRQ_M_EXT] = irq_i[0];

        mip_d[riscv_pkg::IRQ_M_SOFT] = ipi_i;

        mip_d[riscv_pkg::IRQ_M_TIMER] = time_irq_i;

        trap_to_priv_lvl = riscv_pkg::PRIV_LVL_M;

        if (!debug_mode_q && ex_i.valid) begin

            flush_o   = 1'b0;

            if ((ex_i.cause[63] && mideleg_q[ex_i.cause[5:0]]) ||
                (~ex_i.cause[63] && medeleg_q[ex_i.cause[5:0]])) begin

                trap_to_priv_lvl = (priv_lvl_o == riscv_pkg::PRIV_LVL_M) ? riscv_pkg::PRIV_LVL_M : riscv_pkg::PRIV_LVL_S;
            end

            if (trap_to_priv_lvl == riscv_pkg::PRIV_LVL_S) begin

                mstatus_d.sie  = 1'b0;
                mstatus_d.spie = mstatus_q.sie;

                mstatus_d.spp  = priv_lvl_q[0];

                scause_d       = ex_i.cause;

                sepc_d         = pc_i;

                stval_d        = (ariane_pkg::ZERO_TVAL
                                  && (ex_i.cause inside {
                                    riscv_pkg::ILLEGAL_INSTR,
                                    riscv_pkg::BREAKPOINT,
                                    riscv_pkg::ENV_CALL_UMODE,
                                    riscv_pkg::ENV_CALL_SMODE,
                                    riscv_pkg::ENV_CALL_MMODE
                                  } || ex_i.cause[63])) ? '0 : ex_i.tval;

            end else begin

                mstatus_d.mie  = 1'b0;
                mstatus_d.mpie = mstatus_q.mie;

                mstatus_d.mpp  = priv_lvl_q;
                mcause_d       = ex_i.cause;

                mepc_d         = pc_i;

                mtval_d        = (ariane_pkg::ZERO_TVAL
                                  && (ex_i.cause inside {
                                    riscv_pkg::ILLEGAL_INSTR,
                                    riscv_pkg::BREAKPOINT,
                                    riscv_pkg::ENV_CALL_UMODE,
                                    riscv_pkg::ENV_CALL_SMODE,
                                    riscv_pkg::ENV_CALL_MMODE
                                  } || ex_i.cause[63])) ? '0 : ex_i.tval;
            end

            priv_lvl_d = trap_to_priv_lvl;
        end

        if (!debug_mode_q) begin
            dcsr_d.prv = priv_lvl_o;

            if (ex_i.valid && ex_i.cause == riscv_pkg::BREAKPOINT) begin

                unique case (priv_lvl_o)
                    riscv_pkg::PRIV_LVL_M: begin
                        debug_mode_d = dcsr_q.ebreakm;
                        set_debug_pc_o = dcsr_q.ebreakm;
                    end
                    riscv_pkg::PRIV_LVL_S: begin
                        debug_mode_d = dcsr_q.ebreaks;
                        set_debug_pc_o = dcsr_q.ebreaks;
                    end
                    riscv_pkg::PRIV_LVL_U: begin
                        debug_mode_d = dcsr_q.ebreaku;
                        set_debug_pc_o = dcsr_q.ebreaku;
                    end
                    default:;
                endcase

                dpc_d = pc_i;
                dcsr_d.cause = dm::CauseBreakpoint;
            end

            if (debug_req_i && commit_instr_i[0].valid) begin

                dpc_d = pc_i;

                debug_mode_d = 1'b1;

                set_debug_pc_o = 1'b1;

                dcsr_d.cause = dm::CauseRequest;
            end

            if (dcsr_q.step && commit_ack_i[0]) begin

                if (commit_instr_i[0].fu == CTRL_FLOW) begin

                    dpc_d = commit_instr_i[0].bp.predict_address;

                end else if (ex_i.valid) begin
                    dpc_d = trap_vector_base_o;

                end else if (eret_o) begin
                    dpc_d = epc_o;

                end else begin
                    dpc_d = commit_instr_i[0].pc + (commit_instr_i[0].is_compressed ? 'h2 : 'h4);
                end
                debug_mode_d = 1'b1;
                set_debug_pc_o = 1'b1;
                dcsr_d.cause = dm::CauseSingleStep;
            end
        end

        if (debug_mode_q && ex_i.valid && ex_i.cause == riscv_pkg::BREAKPOINT) begin
            set_debug_pc_o = 1'b1;
        end

        if (mprv && satp_q.mode == MODE_SV39 && (mstatus_q.mpp != riscv_pkg::PRIV_LVL_M))
            en_ld_st_translation_d = 1'b1;
        else 
            en_ld_st_translation_d = en_translation_o;

        ld_st_priv_lvl_o = (mprv) ? mstatus_q.mpp : priv_lvl_o;
        en_ld_st_translation_o = en_ld_st_translation_q;

        if (mret) begin

            eret_o = 1'b1;

            mstatus_d.mie  = mstatus_q.mpie;

            priv_lvl_d     = mstatus_q.mpp;

            mstatus_d.mpp  = riscv_pkg::PRIV_LVL_U;

            mstatus_d.mpie = 1'b1;
        end

        if (sret) begin

            eret_o = 1'b1;

            mstatus_d.sie  = mstatus_q.spie;

            priv_lvl_d     = riscv_pkg::priv_lvl_t'({1'b0, mstatus_q.spp});

            mstatus_d.spp  = 1'b0;

            mstatus_d.spie = 1'b1;
        end

        if (dret) begin

            eret_o = 1'b1;

            priv_lvl_d     = riscv_pkg::priv_lvl_t'(dcsr_q.prv);

            debug_mode_d = 1'b0;
        end
    end

    always_comb begin : csr_op_logic
        csr_wdata = csr_wdata_i;
        csr_we    = 1'b1;
        csr_read  = 1'b1;
        mret      = 1'b0;
        sret      = 1'b0;
        dret      = 1'b0;

        unique case (csr_op_i)
            CSR_WRITE: csr_wdata = csr_wdata_i;
            CSR_SET:   csr_wdata = csr_wdata_i | csr_rdata;
            CSR_CLEAR: csr_wdata = (~csr_wdata_i) & csr_rdata;
            CSR_READ:  csr_we    = 1'b0;
            SRET: begin

                csr_we   = 1'b0;
                csr_read = 1'b0;
                sret     = 1'b1; 
            end
            MRET: begin

                csr_we   = 1'b0;
                csr_read = 1'b0;
                mret     = 1'b1; 
            end
            DRET: begin

                csr_we   = 1'b0;
                csr_read = 1'b0;
                dret     = 1'b1; 
            end
            default: begin
                csr_we   = 1'b0;
                csr_read = 1'b0;
            end
        endcase

        if (ex_i.valid) begin
            mret = 1'b0;
            sret = 1'b0;
            dret = 1'b0;
        end
    end

    logic interrupt_global_enable;

    always_comb begin : exception_ctrl
        automatic logic [63:0] interrupt_cause;
        interrupt_cause = '0;

        wfi_d = wfi_q;

        csr_exception_o = {
            64'b0, 64'b0, 1'b0
        };

        if (mie_q[riscv_pkg::S_TIMER_INTERRUPT[5:0]] && mip_q[riscv_pkg::S_TIMER_INTERRUPT[5:0]])
            interrupt_cause = riscv_pkg::S_TIMER_INTERRUPT;

        if (mie_q[riscv_pkg::S_SW_INTERRUPT[5:0]] && mip_q[riscv_pkg::S_SW_INTERRUPT[5:0]])
            interrupt_cause = riscv_pkg::S_SW_INTERRUPT;

        if (mie_q[riscv_pkg::S_EXT_INTERRUPT[5:0]] && (mip_q[riscv_pkg::S_EXT_INTERRUPT[5:0]] | irq_i[1]))
            interrupt_cause = riscv_pkg::S_EXT_INTERRUPT;

        if (mip_q[riscv_pkg::M_TIMER_INTERRUPT[5:0]] && mie_q[riscv_pkg::M_TIMER_INTERRUPT[5:0]])
            interrupt_cause = riscv_pkg::M_TIMER_INTERRUPT;

        if (mip_q[riscv_pkg::M_SW_INTERRUPT[5:0]] && mie_q[riscv_pkg::M_SW_INTERRUPT[5:0]])
            interrupt_cause = riscv_pkg::M_SW_INTERRUPT;

        if (mip_q[riscv_pkg::M_EXT_INTERRUPT[5:0]] && mie_q[riscv_pkg::M_EXT_INTERRUPT[5:0]])
            interrupt_cause = riscv_pkg::M_EXT_INTERRUPT;

        interrupt_global_enable = (~debug_mode_q)

                                & (~dcsr_q.step | dcsr_q.stepie)
                                & ((mstatus_q.mie & (priv_lvl_o == riscv_pkg::PRIV_LVL_M))
                                | (priv_lvl_o != riscv_pkg::PRIV_LVL_M));

        if (interrupt_cause[63] && interrupt_global_enable) begin

            csr_exception_o.cause = interrupt_cause;

            if (mideleg_q[interrupt_cause[5:0]]) begin
                if ((mstatus_q.sie && priv_lvl_o == riscv_pkg::PRIV_LVL_S) || priv_lvl_o == riscv_pkg::PRIV_LVL_U)
                    csr_exception_o.valid = 1'b1;
            end else begin
                csr_exception_o.valid = 1'b1;
            end
        end

        if (csr_we || csr_read) begin
            if ((riscv_pkg::priv_lvl_t'(priv_lvl_o & csr_addr.csr_decode.priv_lvl) != csr_addr.csr_decode.priv_lvl)) begin
                csr_exception_o.cause = riscv_pkg::ILLEGAL_INSTR;
                csr_exception_o.valid = 1'b1;
            end

            if (csr_addr_i[11:4] == 8'h7b && !debug_mode_q) begin
                csr_exception_o.cause = riscv_pkg::ILLEGAL_INSTR;
                csr_exception_o.valid = 1'b1;
            end
        end

        if (update_access_exception || read_access_exception) begin
            csr_exception_o.cause = riscv_pkg::ILLEGAL_INSTR;

            csr_exception_o.valid = 1'b1;
        end

        if (|mip_q || debug_req_i || irq_i[1]) begin
            wfi_d = 1'b0;

        end else if (!debug_mode_q && csr_op_i == WFI && !ex_i.valid) begin
            wfi_d = 1'b1;
        end
    end

    always_comb begin : priv_output
        trap_vector_base_o = {mtvec_q[63:2], 2'b0};

        if (trap_to_priv_lvl == riscv_pkg::PRIV_LVL_S) begin
            trap_vector_base_o = {stvec_q[63:2], 2'b0};
        end

        if (debug_mode_q) begin
            trap_vector_base_o = DmBaseAddress + dm::ExceptionAddress;
        end

        if ((mtvec_q[0] || stvec_q[0]) && csr_exception_o.cause[63]) begin
            trap_vector_base_o[7:2] = csr_exception_o.cause[5:0];
        end

        epc_o = mepc_q;

        if (sret) begin
            epc_o = sepc_q;
        end

        if (dret) begin
            epc_o = dpc_q;
        end
    end

    always_comb begin

        csr_rdata_o = csr_rdata;

        unique case (csr_addr.address)
            riscv_pkg::CSR_MIP: csr_rdata_o = csr_rdata | (irq_i[1] << riscv_pkg::IRQ_S_EXT);

            riscv_pkg::CSR_SIP: begin
                csr_rdata_o = csr_rdata
                            | ((irq_i[1] & mideleg_q[riscv_pkg::IRQ_S_EXT]) << riscv_pkg::IRQ_S_EXT);
            end
            default:;
        endcase
    end

    assign priv_lvl_o       = (debug_mode_q) ? riscv_pkg::PRIV_LVL_M : priv_lvl_q;

    assign fflags_o         = fcsr_q.fflags;
    assign frm_o            = fcsr_q.frm;
    assign fprec_o          = fcsr_q.fprec;

    assign satp_ppn_o       = satp_q.ppn;
    assign asid_o           = satp_q.asid[AsidWidth-1:0];
    assign sum_o            = mstatus_q.sum;

    assign en_translation_o = (satp_q.mode == 4'h8 && priv_lvl_o != riscv_pkg::PRIV_LVL_M)
                              ? 1'b1
                              : 1'b0;
    assign mxr_o            = mstatus_q.mxr;
    assign tvm_o            = mstatus_q.tvm;
    assign tw_o             = mstatus_q.tw;
    assign tsr_o            = mstatus_q.tsr;
    assign halt_csr_o       = wfi_q;
    assign icache_en_o      = icache_q[0] & (~debug_mode_q);
    assign dcache_en_o      = dcache_q[0];

    assign mprv             = (debug_mode_q && !dcsr_q.mprven) ? 1'b0 : mstatus_q.mprv;
    assign debug_mode_o     = debug_mode_q;
    assign single_step_o    = dcsr_q.step;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            priv_lvl_q             <= riscv_pkg::PRIV_LVL_M;

            fcsr_q                 <= 64'b0;

            debug_mode_q           <= 1'b0;
            dcsr_q                 <= '0;
            dcsr_q.prv             <= riscv_pkg::PRIV_LVL_M;
            dpc_q                  <= 64'b0;
            dscratch0_q            <= 64'b0;
            dscratch1_q            <= 64'b0;

            mstatus_q              <= 64'b0;

            mtvec_rst_load_q       <= 1'b1;
            mtvec_q                <= '0;
            medeleg_q              <= 64'b0;
            mideleg_q              <= 64'b0;
            mip_q                  <= 64'b0;
            mie_q                  <= 64'b0;
            mepc_q                 <= 64'b0;
            mcause_q               <= 64'b0;
            mscratch_q             <= 64'b0;
            mtval_q                <= 64'b0;
            dcache_q               <= 64'b1;
            icache_q               <= 64'b1;

            sepc_q                 <= 64'b0;
            scause_q               <= 64'b0;
            stvec_q                <= 64'b0;
            sscratch_q             <= 64'b0;
            stval_q                <= 64'b0;
            satp_q                 <= 64'b0;

            cycle_q                <= 64'b0;
            instret_q              <= 64'b0;

            en_ld_st_translation_q <= 1'b0;

            wfi_q                  <= 1'b0;
        end else begin
            priv_lvl_q             <= priv_lvl_d;

            fcsr_q                 <= fcsr_d;

            debug_mode_q           <= debug_mode_d;
            dcsr_q                 <= dcsr_d;
            dpc_q                  <= dpc_d;
            dscratch0_q            <= dscratch0_d;
            dscratch1_q            <= dscratch1_d;

            mstatus_q              <= mstatus_d;
            mtvec_rst_load_q       <= 1'b0;
            mtvec_q                <= mtvec_d;
            medeleg_q              <= medeleg_d;
            mideleg_q              <= mideleg_d;
            mip_q                  <= mip_d;
            mie_q                  <= mie_d;
            mepc_q                 <= mepc_d;
            mcause_q               <= mcause_d;
            mscratch_q             <= mscratch_d;
            mtval_q                <= mtval_d;
            dcache_q               <= dcache_d;
            icache_q               <= icache_d;

            sepc_q                 <= sepc_d;
            scause_q               <= scause_d;
            stvec_q                <= stvec_d;
            sscratch_q             <= sscratch_d;
            stval_q                <= stval_d;
            satp_q                 <= satp_d;

            cycle_q                <= cycle_d;
            instret_q              <= instret_d;

            en_ld_st_translation_q <= en_ld_st_translation_d;

            wfi_q                  <= wfi_d;
        end
    end

endmodule
