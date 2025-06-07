

module fpu_wrap
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = '{
  
  XLEN                  : 64,
  VLEN                  : 0, 
  PLEN                  : 64, 
  GPLEN                 : 64,
  IS_XLEN32             : 1'b0,
  IS_XLEN64             : 1'b1,
  XLEN_ALIGN_BYTES      : 8, 
  ASID_WIDTH            : 9, 
  VMID_WIDTH            : 7, 

  
  FpgaEn                : 1'b0,
  FpgaAlteraEn          : 1'b0,
  TechnoCut             : 1'b0,

  
  SuperscalarEn         : 1'b0,
  NrCommitPorts         : 1,
  NrIssuePorts          : 1,
  SpeculativeSb         : 1'b0,

  
  NrLoadPipeRegs        : 2,
  NrStorePipeRegs       : 2,

  
  AxiAddrWidth          : 64,
  AxiDataWidth          : 64,
  AxiIdWidth            : 4,
  AxiUserWidth          : 1,
  MEM_TID_WIDTH         : 4,
  NrLoadBufEntries      : 8,

  
  RVF                   : 1'b1, 
  RVD                   : 1'b1, 
  XF16                  : 1'b0, 
  XF16ALT               : 1'b0, 
  XF8                   : 1'b0, 
  RVA                   : 1'b1, 
  RVB                   : 1'b0, 
  ZKN                   : 1'b0, 
  RVV                   : 1'b0, 
  RVC                   : 1'b1, 
  RVH                   : 1'b0, 
  RVZCB                 : 1'b0, 
  RVZCMP                : 1'b0, 
  RVZCMT                : 1'b0, 
  XFVec                 : 1'b0, 
  CvxifEn               : 1'b0, 
  CoproType             : config_pkg::COPRO_NONE, 
  RVZiCond              : 1'b0, 
  RVZicntr              : 1'b0, 
  RVZihpm               : 1'b0, 

  
  NR_SB_ENTRIES         : 8,
  TRANS_ID_BITS         : 4,

  
  FpPresent             : 1'b1, 
  NSX                   : 1'b0, 
  FLen                  : 64, 
  RVFVec                : 1'b0, 
  XF16Vec               : 1'b0,
  XF16ALTVec            : 1'b0,
  XF8Vec                : 1'b0,

  
  NrRgprPorts           : 2, 
  NrWbPorts             : 1, 

  
  EnableAccelerator     : 1'b0,
  PerfCounterEn         : 1'b1, 
  MmuPresent            : 1'b1, 
  RVS                   : 1'b1, 
  RVU                   : 1'b1, 
  SoftwareInterruptEn   : 1'b1,

  
  HaltAddress           : 64'h80000000, 
  ExceptionAddress      : 64'h80000000, 

  
  RASDepth              : 8,
  BTBEntries            : 32,
  BPType                : config_pkg::BHT, 
  BHTEntries            : 256,
  BHTHist               : 8,

  
  InstrTlbEntries       : 16,
  DataTlbEntries        : 16,
  UseSharedTlb          : 1'b0, 
  SharedTlbDepth        : 0,
  VpnLen                : 39, 
  PtLevels              : 3, 

  
  DmBaseAddress         : 64'h0, 
  TvalEn                : 1'b1, 
  DirectVecOnly         : 1'b0, 

  
  NrPMPEntries          : 8, 
  
  PMPCfgRstVal          : '0,
  PMPAddrRstVal         : '0,
  PMPEntryReadOnly      : '0,
  PMPNapotEn            : 1'b1, 

  
  NOCType               : config_pkg::NOC_TYPE_AXI4_ATOP, 
  NrNonIdempotentRules  : 0,
  NonIdempotentAddrBase : '0,
  NonIdempotentLength   : '0,
  NrExecuteRegionRules  : 0,
  ExecuteRegionAddrBase : '0,
  ExecuteRegionLength   : '0,
  NrCachedRegionRules   : 0,
  CachedRegionAddrBase  : '0,
  CachedRegionLength    : '0,
  MaxOutstandingStores  : 8,
  DebugEn               : 1'b1,
  NonIdemPotenceEn      : 1'b0,
  AxiBurstWriteEn       : 1'b1,

  
  ICACHE_SET_ASSOC          : 4,
  ICACHE_SET_ASSOC_WIDTH    : 2, 
  ICACHE_INDEX_WIDTH        : 8, 
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
  ICACHE_TAG_WIDTH          : 64 - 6 - 6, 
  ICACHE_LINE_WIDTH         : 64, 
  ICACHE_USER_LINE_WIDTH    : 0, 

  
  DCacheType                : config_pkg::WT, 
  DcacheIdWidth             : 4,
  DCACHE_SET_ASSOC          : 4,
  DCACHE_SET_ASSOC_WIDTH    : 2, 
  DCACHE_INDEX_WIDTH        : 6, 
  DCACHE_TAG_WIDTH          : 64 - 6 - 6, 
  DCACHE_LINE_WIDTH         : 64, 
  DCACHE_USER_LINE_WIDTH    : 0,
  DCACHE_USER_WIDTH         : 0,
  DCACHE_OFFSET_WIDTH       : 6, 
  DCACHE_NUM_WORDS          : 8, 

  DCACHE_MAX_TX             : 2, 

  DcacheFlushOnFence        : 1'b1,
  DcacheInvalidateOnFlush   : 1'b1,

  
  DATA_USER_EN          : 1'b0,
  WtDcacheWbufDepth     : 4,
  FETCH_USER_WIDTH      : 0,
  FETCH_USER_EN         : 1'b0,
  AXI_USER_EN           : 1'b0,

  
  FETCH_WIDTH           : 64, 
  FETCH_ALIGN_BITS      : 3, 
  INSTR_PER_FETCH       : 2, 
  LOG2_INSTR_PER_FETCH  : 1, 

  
  ModeW                 : 2, 
  ASIDW                 : 9,
  VMIDW                 : 7,
  PPNW                  : 44, 
  GPPNW                 : 44, 
  MODE_SV               : config_pkg::ModeOff, 
  SV                    : 1, 
  SVX                   : 0, 

  
  X_NUM_RS              : 16, 
  X_ID_WIDTH            : 4,
  X_RFR_WIDTH           : 5, 
  X_RFW_WIDTH           : 5, 
  X_NUM_HARTS           : 1,
  X_HARTID_WIDTH        : 0,
  X_DUALREAD            : 1, 
  X_DUALWRITE           : 0, 
  X_ISSUE_REGISTER_SPLIT : 0 
},
    parameter type exception_t = struct packed {
      logic [CVA6Cfg.XLEN-1:0] cause;  
      logic [CVA6Cfg.XLEN-1:0] tval;  
      
      logic [CVA6Cfg.GPLEN-1:0] tval2;  
      logic [31:0] tinst;  
      logic gva;  
      logic valid;
    },
    parameter type fu_data_t = struct packed {
      fu_t                              fu;
      fu_op                             operation;
      logic [CVA6Cfg.XLEN-1:0]          operand_a;
      logic [CVA6Cfg.XLEN-1:0]          operand_b;
      logic [CVA6Cfg.XLEN-1:0]          imm;
      logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id;
    }
) (
    input  logic     clk_i,
    input  logic     rst_ni,
    input  logic     flush_i,
    input  logic     fpu_valid_i,
    output logic     fpu_ready_o,
    input  fu_data_t fu_data_i,

    input  logic       [                      1:0] fpu_fmt_i,
    input  logic       [                      2:0] fpu_rm_i,
    input  logic       [                      2:0] fpu_frm_i,
    input  logic       [                      6:0] fpu_prec_i,
    output logic       [CVA6Cfg.TRANS_ID_BITS-1:0] fpu_trans_id_o,
    output logic       [         CVA6Cfg.FLen-1:0] result_o,
    output logic                                   fpu_valid_o,
    output exception_t                             fpu_exception_o
);

  
  
  enum logic {
    READY,
    STALL
  }
      state_q, state_d;
  if (CVA6Cfg.FpPresent) begin : fpu_gen
    logic [CVA6Cfg.FLen-1:0] operand_a_i;
    logic [CVA6Cfg.FLen-1:0] operand_b_i;
    logic [CVA6Cfg.FLen-1:0] operand_c_i;
    assign operand_a_i = fu_data_i.operand_a[CVA6Cfg.FLen-1:0];
    assign operand_b_i = fu_data_i.operand_b[CVA6Cfg.FLen-1:0];
    assign operand_c_i = fu_data_i.imm[CVA6Cfg.FLen-1:0];

    
    
    
    localparam OPBITS = fpnew_pkg::OP_BITS;
    localparam FMTBITS = $clog2(fpnew_pkg::NUM_FP_FORMATS);
    localparam IFMTBITS = $clog2(fpnew_pkg::NUM_INT_FORMATS);

    
    localparam fpnew_pkg::fpu_features_t FPU_FEATURES = '{
        Width: unsigned'(CVA6Cfg.FLen),  
        EnableVectors: CVA6Cfg.XFVec,
        EnableNanBox: 1'b1,
        FpFmtMask: {CVA6Cfg.RVF, CVA6Cfg.RVD, CVA6Cfg.XF16, CVA6Cfg.XF8, CVA6Cfg.XF16ALT},
        IntFmtMask: {
          CVA6Cfg.XFVec && CVA6Cfg.XF8,
          CVA6Cfg.XFVec && (CVA6Cfg.XF16 || CVA6Cfg.XF16ALT),
          1'b1,
          1'b1
        }
    };

    
    localparam fpnew_pkg::fpu_implementation_t FPU_IMPLEMENTATION = '{
        PipeRegs: '{  
            '{
                unsigned'(LAT_COMP_FP32),
                unsigned'(LAT_COMP_FP64),
                unsigned'(LAT_COMP_FP16),
                unsigned'(LAT_COMP_FP8),
                unsigned'(LAT_COMP_FP16ALT)
            },  
            '{default: unsigned'(LAT_DIVSQRT)},  
            '{default: unsigned'(LAT_NONCOMP)},  
            '{default: unsigned'(LAT_CONV)}
        },  
        UnitTypes: '{
            '{default: fpnew_pkg::PARALLEL},  
            '{default: fpnew_pkg::MERGED},  
            '{default: fpnew_pkg::PARALLEL},  
            '{default: fpnew_pkg::MERGED}
        },  
        PipeConfig: fpnew_pkg::DISTRIBUTED
    };

    
    
    
    logic [CVA6Cfg.FLen-1:0] operand_a_d, operand_a_q, operand_a;
    logic [CVA6Cfg.FLen-1:0] operand_b_d, operand_b_q, operand_b;
    logic [CVA6Cfg.FLen-1:0] operand_c_d, operand_c_q, operand_c;
    logic [OPBITS-1:0] fpu_op_d, fpu_op_q, fpu_op;
    logic fpu_op_mod_d, fpu_op_mod_q, fpu_op_mod;
    logic [FMTBITS-1:0] fpu_srcfmt_d, fpu_srcfmt_q, fpu_srcfmt;
    logic [FMTBITS-1:0] fpu_dstfmt_d, fpu_dstfmt_q, fpu_dstfmt;
    logic [IFMTBITS-1:0] fpu_ifmt_d, fpu_ifmt_q, fpu_ifmt;
    logic [2:0] fpu_rm_d, fpu_rm_q, fpu_rm;
    logic fpu_vec_op_d, fpu_vec_op_q, fpu_vec_op;

    logic [CVA6Cfg.TRANS_ID_BITS-1:0] fpu_tag_d, fpu_tag_q, fpu_tag;

    logic fpu_in_ready, fpu_in_valid;
    logic fpu_out_ready, fpu_out_valid;

    logic [4:0] fpu_status;

    
    logic hold_inputs;
    logic use_hold;

    
    
    

    always_comb begin : input_translation

      automatic logic vec_replication;  
      automatic logic replicate_c;  
      automatic logic check_ah;  

      
      operand_a_d     = operand_a_i;
      operand_b_d     = operand_b_i;  
      operand_c_d     = operand_c_i;  
      fpu_op_d        = fpnew_pkg::SGNJ;  
      fpu_op_mod_d    = 1'b0;
      fpu_dstfmt_d    = fpnew_pkg::FP32;
      fpu_ifmt_d      = fpnew_pkg::INT32;
      fpu_rm_d        = fpu_rm_i;
      fpu_vec_op_d    = fu_data_i.fu == FPU_VEC;
      fpu_tag_d       = fu_data_i.trans_id;
      vec_replication = fpu_rm_i[0];  
      replicate_c     = 1'b0;
      check_ah        = 1'b0;  

      
      if (!(fpu_rm_i inside {[3'b000 : 3'b100]})) fpu_rm_d = fpu_frm_i;

      
      if (fpu_vec_op_d) fpu_rm_d = fpu_frm_i;

      
      unique case (fpu_fmt_i)
        
        2'b00:   fpu_dstfmt_d = fpnew_pkg::FP32;
        
        2'b01:   fpu_dstfmt_d = fpu_vec_op_d ? fpnew_pkg::FP16ALT : fpnew_pkg::FP64;
        
        2'b10: begin
          if (!fpu_vec_op_d && fpu_rm_i == 3'b101) fpu_dstfmt_d = fpnew_pkg::FP16ALT;
          else fpu_dstfmt_d = fpnew_pkg::FP16;
        end
        
        default: fpu_dstfmt_d = fpnew_pkg::FP8;
      endcase

      
      fpu_srcfmt_d = fpu_dstfmt_d;

      
      unique case (fu_data_i.operation)
        
        FADD: begin
          fpu_op_d    = fpnew_pkg::ADD;
          replicate_c = 1'b1; 
        end
        
        FSUB: begin
          fpu_op_d     = fpnew_pkg::ADD;
          fpu_op_mod_d = 1'b1;
          replicate_c  = 1'b1;  
        end
        
        FMUL:    fpu_op_d = fpnew_pkg::MUL;
        
        FDIV:    fpu_op_d = fpnew_pkg::DIV;
        
        FMIN_MAX: begin
          fpu_op_d = fpnew_pkg::MINMAX;
          fpu_rm_d = {1'b0, fpu_rm_i[1:0]};  
          check_ah = 1'b1;  
        end
        
        FSQRT:   fpu_op_d = fpnew_pkg::SQRT;
        
        FMADD:   fpu_op_d = fpnew_pkg::FMADD;
        
        FMSUB: begin
          fpu_op_d     = fpnew_pkg::FMADD;
          fpu_op_mod_d = 1'b1;
        end
        
        FNMSUB:  fpu_op_d = fpnew_pkg::FNMSUB;
        
        FNMADD: begin
          fpu_op_d     = fpnew_pkg::FNMSUB;
          fpu_op_mod_d = 1'b1;
        end
        
        FCVT_F2I: begin
          fpu_op_d = fpnew_pkg::F2I;
          
          if (fpu_vec_op_d) begin
            fpu_op_mod_d    = fpu_rm_i[0];
            vec_replication = 1'b0;  
            unique case (fpu_fmt_i)
              2'b00: fpu_ifmt_d = fpnew_pkg::INT32;
              2'b01, 2'b10: fpu_ifmt_d = fpnew_pkg::INT16;
              2'b11: fpu_ifmt_d = fpnew_pkg::INT8;
            endcase
            
          end else begin
            fpu_op_mod_d = operand_c_i[0];
            if (operand_c_i[1]) fpu_ifmt_d = fpnew_pkg::INT64;
            else fpu_ifmt_d = fpnew_pkg::INT32;
          end
        end
        
        FCVT_I2F: begin
          fpu_op_d = fpnew_pkg::I2F;
          
          if (fpu_vec_op_d) begin
            fpu_op_mod_d    = fpu_rm_i[0];
            vec_replication = 1'b0;  
            unique case (fpu_fmt_i)
              2'b00: fpu_ifmt_d = fpnew_pkg::INT32;
              2'b01, 2'b10: fpu_ifmt_d = fpnew_pkg::INT16;
              2'b11: fpu_ifmt_d = fpnew_pkg::INT8;
            endcase
            
          end else begin
            fpu_op_mod_d = operand_c_i[0];
            if (operand_c_i[1]) fpu_ifmt_d = fpnew_pkg::INT64;
            else fpu_ifmt_d = fpnew_pkg::INT32;
          end
        end
        
        FCVT_F2F: begin
          fpu_op_d = fpnew_pkg::F2F;
          
          if (fpu_vec_op_d) begin
            vec_replication = 1'b0;  
            unique case (operand_c_i[1:0])
              2'b00: fpu_srcfmt_d = fpnew_pkg::FP32;
              2'b01: fpu_srcfmt_d = fpnew_pkg::FP16ALT;
              2'b10: fpu_srcfmt_d = fpnew_pkg::FP16;
              2'b11: fpu_srcfmt_d = fpnew_pkg::FP8;
            endcase
            
          end else begin
            unique case (operand_c_i[2:0])
              3'b000:  fpu_srcfmt_d = fpnew_pkg::FP32;
              3'b001:  fpu_srcfmt_d = fpnew_pkg::FP64;
              3'b010:  fpu_srcfmt_d = fpnew_pkg::FP16;
              3'b110:  fpu_srcfmt_d = fpnew_pkg::FP16ALT;
              3'b011:  fpu_srcfmt_d = fpnew_pkg::FP8;
              default: ;  
            endcase
          end
        end
        
        FSGNJ: begin
          fpu_op_d = fpnew_pkg::SGNJ;
          fpu_rm_d = {1'b0, fpu_rm_i[1:0]};  
          check_ah = 1'b1;  
        end
        
        FMV_F2X: begin
          fpu_op_d        = fpnew_pkg::SGNJ;
          fpu_rm_d        = 3'b011;  
          fpu_op_mod_d    = 1'b1;  
          check_ah        = 1'b1;  
          vec_replication = 1'b0;  
        end
        
        FMV_X2F: begin
          fpu_op_d        = fpnew_pkg::SGNJ;
          fpu_rm_d        = 3'b011;  
          check_ah        = 1'b1;  
          vec_replication = 1'b0;  
        end
        
        FCMP: begin
          fpu_op_d = fpnew_pkg::CMP;
          fpu_rm_d = {1'b0, fpu_rm_i[1:0]};  
          check_ah = 1'b1;  
        end
        
        FCLASS: begin
          fpu_op_d = fpnew_pkg::CLASSIFY;
          fpu_rm_d = {
            1'b0, fpu_rm_i[1:0]
          };  
          check_ah = 1'b1;  
        end
        
        VFMIN: begin
          fpu_op_d = fpnew_pkg::MINMAX;
          fpu_rm_d = 3'b000;  
        end
        
        VFMAX: begin
          fpu_op_d = fpnew_pkg::MINMAX;
          fpu_rm_d = 3'b001;  
        end
        
        VFSGNJ: begin
          fpu_op_d = fpnew_pkg::SGNJ;
          fpu_rm_d = 3'b000;  
        end
        
        VFSGNJN: begin
          fpu_op_d = fpnew_pkg::SGNJ;
          fpu_rm_d = 3'b001;  
        end
        
        VFSGNJX: begin
          fpu_op_d = fpnew_pkg::SGNJ;
          fpu_rm_d = 3'b010;  
        end
        
        VFEQ: begin
          fpu_op_d = fpnew_pkg::CMP;
          fpu_rm_d = 3'b010;  
        end
        
        VFNE: begin
          fpu_op_d     = fpnew_pkg::CMP;
          fpu_op_mod_d = 1'b1;  
          fpu_rm_d     = 3'b010;  
        end
        
        VFLT: begin
          fpu_op_d = fpnew_pkg::CMP;
          fpu_rm_d = 3'b001;  
        end
        
        VFGE: begin
          fpu_op_d     = fpnew_pkg::CMP;
          fpu_op_mod_d = 1'b1;  
          fpu_rm_d     = 3'b001;  
        end
        
        VFLE: begin
          fpu_op_d = fpnew_pkg::CMP;
          fpu_rm_d = 3'b000;  
        end
        
        VFGT: begin
          fpu_op_d     = fpnew_pkg::CMP;
          fpu_op_mod_d = 1'b1;  
          fpu_rm_d     = 3'b000;  
        end
        
        VFCPKAB_S: begin
          fpu_op_d        = fpnew_pkg::CPKAB;
          fpu_op_mod_d    = fpu_rm_i[0];  
          vec_replication = 1'b0;  
          fpu_srcfmt_d    = fpnew_pkg::FP32;  
        end
        
        VFCPKCD_S: begin
          fpu_op_d        = fpnew_pkg::CPKCD;
          fpu_op_mod_d    = fpu_rm_i[0];  
          vec_replication = 1'b0;  
          fpu_srcfmt_d    = fpnew_pkg::FP32;  
        end
        
        VFCPKAB_D: begin
          fpu_op_d        = fpnew_pkg::CPKAB;
          fpu_op_mod_d    = fpu_rm_i[0];  
          vec_replication = 1'b0;  
          fpu_srcfmt_d    = fpnew_pkg::FP64;  
        end
        
        VFCPKCD_D: begin
          fpu_op_d        = fpnew_pkg::CPKCD;
          fpu_op_mod_d    = fpu_rm_i[0];  
          vec_replication = 1'b0;  
          fpu_srcfmt_d    = fpnew_pkg::FP64;  
        end
        
        default: ;  
      endcase

      
      if (!fpu_vec_op_d && check_ah) if (fpu_rm_i[2]) fpu_dstfmt_d = fpnew_pkg::FP16ALT;

      
      if (fpu_vec_op_d && vec_replication) begin
        if (replicate_c) begin
          unique case (fpu_dstfmt_d)
            fpnew_pkg::FP32: operand_c_d = CVA6Cfg.RVD ? {2{operand_c_i[31:0]}} : operand_c_i;
            fpnew_pkg::FP16, fpnew_pkg::FP16ALT:
            operand_c_d = CVA6Cfg.RVD ? {4{operand_c_i[15:0]}} : {2{operand_c_i[15:0]}};
            fpnew_pkg::FP8:
            operand_c_d = CVA6Cfg.RVD ? {8{operand_c_i[7:0]}} : {4{operand_c_i[7:0]}};
            default: ;  
          endcase  
        end else begin
          unique case (fpu_dstfmt_d)
            fpnew_pkg::FP32: operand_b_d = CVA6Cfg.RVD ? {2{operand_b_i[31:0]}} : operand_b_i;
            fpnew_pkg::FP16, fpnew_pkg::FP16ALT:
            operand_b_d = CVA6Cfg.RVD ? {4{operand_b_i[15:0]}} : {2{operand_b_i[15:0]}};
            fpnew_pkg::FP8:
            operand_b_d = CVA6Cfg.RVD ? {8{operand_b_i[7:0]}} : {4{operand_b_i[7:0]}};
            default: ;  
          endcase  
        end
      end
    end
    
    
    

    always_comb begin : p_inputFSM
      
      fpu_ready_o  = 1'b0;
      fpu_in_valid = 1'b0;
      hold_inputs  = 1'b0;  
      use_hold     = 1'b0;  
      state_d      = state_q;  

      
      unique case (state_q)
        
        READY: begin
          fpu_ready_o  = 1'b1;  
          fpu_in_valid = fpu_valid_i;  
          
          if (fpu_valid_i & ~fpu_in_ready) begin
            fpu_ready_o = 1'b0;  
            hold_inputs = 1'b1;  
            state_d     = STALL;  
          end
        end
        
        STALL: begin
          fpu_in_valid = 1'b1;  
          use_hold     = 1'b1;  
          
          if (fpu_in_ready) begin
            fpu_ready_o = 1'b1;  
            state_d     = READY;  
          end
        end
        
        default: ;
      endcase

      
      if (flush_i) begin
        state_d = READY;
      end

    end

    
    always_ff @(posedge clk_i or negedge rst_ni) begin : fp_hold_reg
      if (~rst_ni) begin
        state_q      <= READY;
        operand_a_q  <= '0;
        operand_b_q  <= '0;
        operand_c_q  <= '0;
        fpu_op_q     <= '0;
        fpu_op_mod_q <= '0;
        fpu_srcfmt_q <= '0;
        fpu_dstfmt_q <= '0;
        fpu_ifmt_q   <= '0;
        fpu_rm_q     <= '0;
        fpu_vec_op_q <= '0;
        fpu_tag_q    <= '0;
      end else begin
        state_q <= state_d;
        
        if (hold_inputs) begin
          operand_a_q  <= operand_a_d;
          operand_b_q  <= operand_b_d;
          operand_c_q  <= operand_c_d;
          fpu_op_q     <= fpu_op_d;
          fpu_op_mod_q <= fpu_op_mod_d;
          fpu_srcfmt_q <= fpu_srcfmt_d;
          fpu_dstfmt_q <= fpu_dstfmt_d;
          fpu_ifmt_q   <= fpu_ifmt_d;
          fpu_rm_q     <= fpu_rm_d;
          fpu_vec_op_q <= fpu_vec_op_d;
          fpu_tag_q    <= fpu_tag_d;
        end
      end
    end

    
    assign operand_a  = use_hold ? operand_a_q : operand_a_d;
    assign operand_b  = use_hold ? operand_b_q : operand_b_d;
    assign operand_c  = use_hold ? operand_c_q : operand_c_d;
    assign fpu_op     = use_hold ? fpu_op_q : fpu_op_d;
    assign fpu_op_mod = use_hold ? fpu_op_mod_q : fpu_op_mod_d;
    assign fpu_srcfmt = use_hold ? fpu_srcfmt_q : fpu_srcfmt_d;
    assign fpu_dstfmt = use_hold ? fpu_dstfmt_q : fpu_dstfmt_d;
    assign fpu_ifmt   = use_hold ? fpu_ifmt_q : fpu_ifmt_d;
    assign fpu_rm     = use_hold ? fpu_rm_q : fpu_rm_d;
    assign fpu_vec_op = use_hold ? fpu_vec_op_q : fpu_vec_op_d;
    assign fpu_tag    = use_hold ? fpu_tag_q : fpu_tag_d;

    
    logic [2:0][CVA6Cfg.FLen-1:0] fpu_operands;

    assign fpu_operands[0] = operand_a;
    assign fpu_operands[1] = operand_b;
    assign fpu_operands[2] = operand_c;

    
    
    

    fpnew_top #(
        .Features      (FPU_FEATURES),
        .Implementation(FPU_IMPLEMENTATION),
        .TagType       (logic [CVA6Cfg.TRANS_ID_BITS-1:0])
    ) i_fpnew_bulk (
        .clk_i,
        .rst_ni,
        .operands_i    (fpu_operands),
        .rnd_mode_i    (fpnew_pkg::roundmode_e'(fpu_rm)),
        .op_i          (fpnew_pkg::operation_e'(fpu_op)),
        .op_mod_i      (fpu_op_mod),
        .src_fmt_i     (fpnew_pkg::fp_format_e'(fpu_srcfmt)),
        .dst_fmt_i     (fpnew_pkg::fp_format_e'(fpu_dstfmt)),
        .int_fmt_i     (fpnew_pkg::int_format_e'(fpu_ifmt)),
        .vectorial_op_i(fpu_vec_op),
        .tag_i         (fpu_tag),
        .simd_mask_i   (1'b1),
        .in_valid_i    (fpu_in_valid),
        .in_ready_o    (fpu_in_ready),
        .flush_i,
        .result_o,
        .status_o      (fpu_status),
        .tag_o         (fpu_trans_id_o),
        .out_valid_o   (fpu_out_valid),
        .out_ready_i   (fpu_out_ready),
        .busy_o        (             )
    );

    
    assign fpu_exception_o.cause = {59'h0, fpu_status};
    assign fpu_exception_o.valid = 1'b0;
    assign fpu_exception_o.tval = '0;

    
    assign fpu_out_ready = 1'b1;

    
    assign fpu_valid_o = fpu_out_valid;

  end
endmodule
