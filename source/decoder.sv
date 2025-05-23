import ariane_pkg::*;module decoder (
    input  logic [63:0]        pc_i,                    
    input  logic               is_compressed_i,         
    input  logic [15:0]        compressed_instr_i,      
    input  logic               is_illegal_i,            
    input  logic [31:0]        instruction_i,           
    input  branchpredict_sbe_t branch_predict_i,
    input  exception_t         ex_i,                    

    input  riscv_pkg::priv_lvl_t   priv_lvl_i,              
    input  logic               debug_mode_i,            
    input  riscv_pkg::xs_t         fs_i,                    
    input  logic [2:0]         frm_i,                   
    input  logic               tvm_i,                   
    input  logic               tw_i,                    
    input  logic               tsr_i,                   
    output scoreboard_entry_t  instruction_o,           
    output logic               is_control_flow_instr_o  
);
    logic illegal_instr;

    logic ecall;

    logic ebreak;

    logic check_fprm;
    riscv_pkg::instruction_t instr;
    assign instr = riscv_pkg::instruction_t'(instruction_i);

    enum logic[3:0] {
        NOIMM, IIMM, SIMM, SBIMM, UIMM, JIMM, RS3
    } imm_select;

    logic [63:0] imm_i_type;
    logic [63:0] imm_s_type;
    logic [63:0] imm_sb_type;
    logic [63:0] imm_u_type;
    logic [63:0] imm_uj_type;
    logic [63:0] imm_bi_type;

    always_comb begin : decoder

        imm_select                  = NOIMM;
        is_control_flow_instr_o     = 1'b0;
        illegal_instr               = 1'b0;
        instruction_o.pc            = pc_i;
        instruction_o.trans_id      = 5'b0;
        instruction_o.fu            = NONE;
        instruction_o.op            = ADD;
        instruction_o.rs1           = '0;
        instruction_o.rs2           = '0;
        instruction_o.rd            = '0;
        instruction_o.use_pc        = 1'b0;
        instruction_o.trans_id      = '0;
        instruction_o.is_compressed = is_compressed_i;
        instruction_o.use_zimm      = 1'b0;
        instruction_o.bp            = branch_predict_i;
        ecall                       = 1'b0;
        ebreak                      = 1'b0;
        check_fprm                  = 1'b0;

        if (~ex_i.valid) begin
            case (instr.rtype.opcode)
                riscv_pkg::OpcodeSystem: begin
                    instruction_o.fu       = CSR;
                    instruction_o.rs1[4:0] = instr.itype.rs1;
                    instruction_o.rd[4:0]  = instr.itype.rd;

                    unique case (instr.itype.funct3)
                        3'b000: begin

                            if (instr.itype.rs1 != '0 || instr.itype.rd != '0)
                                illegal_instr = 1'b1;

                            case (instr.itype.imm)

                                12'b0: ecall  = 1'b1;

                                12'b1: ebreak = 1'b1;

                                12'b1_0000_0010: begin
                                    instruction_o.op = SRET;

                                    if (priv_lvl_i == riscv_pkg::PRIV_LVL_U) begin
                                        illegal_instr = 1'b1;

                                        instruction_o.op = ADD;
                                    end

                                    if (priv_lvl_i == riscv_pkg::PRIV_LVL_S && tsr_i) begin
                                        illegal_instr = 1'b1;

                                        instruction_o.op = ADD;
                                    end
                                end

                                12'b11_0000_0010: begin
                                    instruction_o.op = MRET;

                                    if (priv_lvl_i inside {riscv_pkg::PRIV_LVL_U, riscv_pkg::PRIV_LVL_S})
                                        illegal_instr = 1'b1;
                                end

                                12'b111_1011_0010: begin
                                    instruction_o.op = DRET;

                                    illegal_instr = (!debug_mode_i) ? 1'b1 : 1'b0;
                                end

                                12'b1_0000_0101: begin
                                    if (ENABLE_WFI) instruction_o.op = WFI;

                                    if (priv_lvl_i == riscv_pkg::PRIV_LVL_S && tw_i) begin
                                        illegal_instr = 1'b1;
                                        instruction_o.op = ADD;
                                    end

                                    if (priv_lvl_i == riscv_pkg::PRIV_LVL_U) begin
                                        illegal_instr = 1'b1;
                                        instruction_o.op = ADD;
                                    end
                                end

                                default: begin
                                    if (instr.instr[31:25] == 7'b1001) begin

                                        illegal_instr    = (priv_lvl_i inside {riscv_pkg::PRIV_LVL_M, riscv_pkg::PRIV_LVL_S}) ? 1'b0 : 1'b1;
                                        instruction_o.op = SFENCE_VMA;

                                        if (priv_lvl_i == riscv_pkg::PRIV_LVL_S && tvm_i)
                                            illegal_instr = 1'b1;
                                    end
                                end
                            endcase
                        end

                        3'b001: begin
                            imm_select = IIMM;
                            instruction_o.op = CSR_WRITE;
                        end

                        3'b010: begin
                            imm_select = IIMM;

                            if (instr.itype.rs1 == 5'b0)
                                instruction_o.op = CSR_READ;
                            else
                                instruction_o.op = CSR_SET;
                        end

                        3'b011: begin
                            imm_select = IIMM;

                            if (instr.itype.rs1 == 5'b0)
                                instruction_o.op = CSR_READ;
                            else
                                instruction_o.op = CSR_CLEAR;
                        end

                        3'b101: begin
                            instruction_o.rs1[4:0] = instr.itype.rs1;
                            imm_select = IIMM;
                            instruction_o.use_zimm = 1'b1;
                            instruction_o.op = CSR_WRITE;
                        end
                        3'b110: begin
                            instruction_o.rs1[4:0] = instr.itype.rs1;
                            imm_select = IIMM;
                            instruction_o.use_zimm = 1'b1;

                            if (instr.itype.rs1 == 5'b0)
                                instruction_o.op = CSR_READ;
                            else
                                instruction_o.op = CSR_SET;
                        end
                        3'b111: begin
                            instruction_o.rs1[4:0] = instr.itype.rs1;
                            imm_select = IIMM;
                            instruction_o.use_zimm = 1'b1;

                            if (instr.itype.rs1 == 5'b0)
                                instruction_o.op = CSR_READ;
                            else
                                instruction_o.op = CSR_CLEAR;
                        end
                        default: illegal_instr = 1'b1;
                    endcase
                end

                riscv_pkg::OpcodeMiscMem: begin
                    instruction_o.fu  = CSR;
                    instruction_o.rs1 = '0;
                    instruction_o.rs2 = '0;
                    instruction_o.rd  = '0;

                    case (instr.stype.funct3)

                        3'b000: instruction_o.op  = FENCE;

                        3'b001: begin
                            if (instr.instr[31:20] != '0)
                                illegal_instr = 1'b1;
                            instruction_o.op  = FENCE_I;
                        end
                        default: illegal_instr = 1'b1;
                    endcase

                    if (instr.stype.rs1 != '0 || instr.stype.imm0 != '0 || instr.instr[31:28] != '0)
                        illegal_instr = 1'b1;
                end

                riscv_pkg::OpcodeOp: begin

                    if (instr.rvftype.funct2 == 2'b10) begin 

                        if (FP_PRESENT && XFVEC && fs_i != riscv_pkg::Off) begin
                            automatic logic allow_replication; 

                            instruction_o.fu       = FPU_VEC; 
                            instruction_o.rs1[4:0] = instr.rvftype.rs1;
                            instruction_o.rs2[4:0] = instr.rvftype.rs2;
                            instruction_o.rd[4:0]  = instr.rvftype.rd;
                            check_fprm             = 1'b1;
                            allow_replication      = 1'b1;

                            unique case (instr.rvftype.vecfltop)
                                5'b00001 : begin
                                    instruction_o.op  = FADD; 
                                    instruction_o.rs1 = '0;                
                                    instruction_o.rs2 = instr.rvftype.rs1; 
                                    imm_select        = IIMM;              
                                end
                                5'b00010 : begin
                                    instruction_o.op  = FSUB; 
                                    instruction_o.rs1 = '0;                
                                    instruction_o.rs2 = instr.rvftype.rs1; 
                                    imm_select        = IIMM;              
                                end
                                5'b00011 : instruction_o.op = FMUL; 
                                5'b00100 : instruction_o.op = FDIV; 
                                5'b00101 : begin
                                    instruction_o.op = VFMIN; 
                                    check_fprm       = 1'b0;  
                                end
                                5'b00110 : begin
                                    instruction_o.op = VFMAX; 
                                    check_fprm       = 1'b0;  
                                end
                                5'b00111 : begin
                                    instruction_o.op  = FSQRT; 
                                    allow_replication = 1'b0;  
                                    if (instr.rvftype.rs2 != 5'b00000) illegal_instr = 1'b1; 
                                end
                                5'b01000 : begin
                                    instruction_o.op = FMADD; 
                                    imm_select       = SIMM;  
                                end
                                5'b01001 : begin
                                    instruction_o.op = FMSUB; 
                                    imm_select       = SIMM;  
                                end
                                5'b01100 : begin
                                    unique case (instr.rvftype.rs2) inside 
                                        5'b00000 : begin
                                            instruction_o.rs2 = instr.rvftype.rs1; 
                                            if (instr.rvftype.repl)
                                                instruction_o.op = FMV_F2X; 
                                            else
                                                instruction_o.op = FMV_X2F; 
                                            check_fprm = 1'b0;              
                                        end
                                        5'b00001 : begin
                                            instruction_o.op  = FCLASS; 
                                            check_fprm        = 1'b0;   
                                            allow_replication = 1'b0;   
                                        end
                                        5'b00010 : instruction_o.op = FCVT_F2I; 
                                        5'b00011 : instruction_o.op = FCVT_I2F; 
                                        5'b001?? : begin
                                            instruction_o.op  = FCVT_F2F; 
                                            instruction_o.rs2 = instr.rvftype.rd; 
                                            imm_select        = IIMM;     

                                            unique case (instr.rvftype.rs2[21:20])

                                                2'b00: if (~RVFVEC)     illegal_instr = 1'b1;
                                                2'b01: if (~XF16ALTVEC) illegal_instr = 1'b1;
                                                2'b10: if (~XF16VEC)    illegal_instr = 1'b1;
                                                2'b11: if (~XF8VEC)     illegal_instr = 1'b1;
                                                default : illegal_instr = 1'b1;
                                            endcase
                                        end
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                5'b01101 : begin
                                    check_fprm = 1'b0;         
                                    instruction_o.op = VFSGNJ; 
                                end
                                5'b01110 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFSGNJN; 
                                end
                                5'b01111 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFSGNJX; 
                                end
                                5'b10000 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFEQ;    
                                end
                                5'b10001 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFNE;    
                                end
                                5'b10010 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFLT;    
                                end
                                5'b10011 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFGE;    
                                end
                                5'b10100 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFLE;    
                                end
                                5'b10101 : begin
                                    check_fprm = 1'b0;          
                                    instruction_o.op = VFGT;    
                                end
                                5'b11000 : begin
                                    instruction_o.op  = VFCPKAB_S; 
                                    imm_select        = SIMM;      
                                    if (~RVF) illegal_instr = 1'b1; 

                                    unique case (instr.rvftype.vfmt)

                                        2'b00: begin
                                            if (~RVFVEC)            illegal_instr = 1'b1; 
                                            if (instr.rvftype.repl) illegal_instr = 1'b1; 
                                        end
                                        2'b01: begin
                                            if (~XF16ALTVEC) illegal_instr = 1'b1; 
                                        end
                                        2'b10: begin
                                            if (~XF16VEC) illegal_instr = 1'b1; 
                                        end
                                        2'b11: begin
                                            if (~XF8VEC) illegal_instr = 1'b1; 
                                        end
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                5'b11001 : begin
                                    instruction_o.op  = VFCPKCD_S; 
                                    imm_select        = SIMM;      
                                    if (~RVF) illegal_instr = 1'b1; 

                                    unique case (instr.rvftype.vfmt)

                                        2'b00: illegal_instr = 1'b1; 
                                        2'b01: illegal_instr = 1'b1; 
                                        2'b10: illegal_instr = 1'b1; 
                                        2'b11: begin
                                            if (~XF8VEC) illegal_instr = 1'b1; 
                                        end
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                5'b11010 : begin
                                    instruction_o.op  = VFCPKAB_D; 
                                    imm_select        = SIMM;      
                                    if (~RVD) illegal_instr = 1'b1; 

                                    unique case (instr.rvftype.vfmt)

                                        2'b00: begin
                                            if (~RVFVEC)            illegal_instr = 1'b1; 
                                            if (instr.rvftype.repl) illegal_instr = 1'b1; 
                                        end
                                        2'b01: begin
                                            if (~XF16ALTVEC) illegal_instr = 1'b1; 
                                        end
                                        2'b10: begin
                                            if (~XF16VEC) illegal_instr = 1'b1; 
                                        end
                                        2'b11: begin
                                            if (~XF8VEC) illegal_instr = 1'b1; 
                                        end
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                5'b11011 : begin
                                    instruction_o.op  = VFCPKCD_D; 
                                    imm_select        = SIMM;      
                                    if (~RVD) illegal_instr = 1'b1; 

                                    unique case (instr.rvftype.vfmt)

                                        2'b00: illegal_instr = 1'b1; 
                                        2'b01: illegal_instr = 1'b1; 
                                        2'b10: illegal_instr = 1'b1; 
                                        2'b11: begin
                                            if (~XF8VEC) illegal_instr = 1'b1; 
                                        end
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                default : illegal_instr = 1'b1;
                            endcase

                            unique case (instr.rvftype.vfmt)

                                2'b00: if (~RVFVEC)     illegal_instr = 1'b1;
                                2'b01: if (~XF16ALTVEC) illegal_instr = 1'b1;
                                2'b10: if (~XF16VEC)    illegal_instr = 1'b1;
                                2'b11: if (~XF8VEC)     illegal_instr = 1'b1;
                                default: illegal_instr = 1'b1;
                            endcase

                            if (~allow_replication & instr.rvftype.repl) illegal_instr = 1'b1;

                            if (check_fprm) begin
                                unique case (frm_i) inside 
                                    [3'b000:3'b100]: ; 
                                    default : illegal_instr = 1'b1;
                                endcase
                            end

                        end else begin 
                            illegal_instr = 1'b1;
                        end

                    end else begin
                        instruction_o.fu  = (instr.rtype.funct7 == 7'b000_0001) ? MULT : ALU;
                        instruction_o.rs1 = instr.rtype.rs1;
                        instruction_o.rs2 = instr.rtype.rs2;
                        instruction_o.rd  = instr.rtype.rd;

                        unique case ({instr.rtype.funct7, instr.rtype.funct3})
                            {7'b000_0000, 3'b000}: instruction_o.op = ADD;   
                            {7'b010_0000, 3'b000}: instruction_o.op = SUB;   
                            {7'b000_0000, 3'b010}: instruction_o.op = SLTS;  
                            {7'b000_0000, 3'b011}: instruction_o.op = SLTU;  
                            {7'b000_0000, 3'b100}: instruction_o.op = XORL;  
                            {7'b000_0000, 3'b110}: instruction_o.op = ORL;   
                            {7'b000_0000, 3'b111}: instruction_o.op = ANDL;  
                            {7'b000_0000, 3'b001}: instruction_o.op = SLL;   
                            {7'b000_0000, 3'b101}: instruction_o.op = SRL;   
                            {7'b010_0000, 3'b101}: instruction_o.op = SRA;   

                            {7'b000_0001, 3'b000}: instruction_o.op = MUL;
                            {7'b000_0001, 3'b001}: instruction_o.op = MULH;
                            {7'b000_0001, 3'b010}: instruction_o.op = MULHSU;
                            {7'b000_0001, 3'b011}: instruction_o.op = MULHU;
                            {7'b000_0001, 3'b100}: instruction_o.op = DIV;
                            {7'b000_0001, 3'b101}: instruction_o.op = DIVU;
                            {7'b000_0001, 3'b110}: instruction_o.op = REM;
                            {7'b000_0001, 3'b111}: instruction_o.op = REMU;
                            default: begin
                                illegal_instr = 1'b1;
                            end
                        endcase
                    end
                end

                riscv_pkg::OpcodeOp32: begin
                    instruction_o.fu  = (instr.rtype.funct7 == 7'b000_0001) ? MULT : ALU;
                    instruction_o.rs1[4:0] = instr.rtype.rs1;
                    instruction_o.rs2[4:0] = instr.rtype.rs2;
                    instruction_o.rd[4:0]  = instr.rtype.rd;

                        unique case ({instr.rtype.funct7, instr.rtype.funct3})
                            {7'b000_0000, 3'b000}: instruction_o.op = ADDW; 
                            {7'b010_0000, 3'b000}: instruction_o.op = SUBW; 
                            {7'b000_0000, 3'b001}: instruction_o.op = SLLW; 
                            {7'b000_0000, 3'b101}: instruction_o.op = SRLW; 
                            {7'b010_0000, 3'b101}: instruction_o.op = SRAW; 

                            {7'b000_0001, 3'b000}: instruction_o.op = MULW;
                            {7'b000_0001, 3'b100}: instruction_o.op = DIVW;
                            {7'b000_0001, 3'b101}: instruction_o.op = DIVUW;
                            {7'b000_0001, 3'b110}: instruction_o.op = REMW;
                            {7'b000_0001, 3'b111}: instruction_o.op = REMUW;
                            default: illegal_instr = 1'b1;
                        endcase
                end

                riscv_pkg::OpcodeOpImm: begin
                    instruction_o.fu  = ALU;
                    imm_select = IIMM;
                    instruction_o.rs1[4:0] = instr.itype.rs1;
                    instruction_o.rd[4:0]  = instr.itype.rd;

                    unique case (instr.itype.funct3)
                        3'b000: instruction_o.op = ADD;   
                        3'b010: instruction_o.op = SLTS;  
                        3'b011: instruction_o.op = SLTU;  
                        3'b100: instruction_o.op = XORL;  
                        3'b110: instruction_o.op = ORL;   
                        3'b111: instruction_o.op = ANDL;  

                        3'b001: begin
                          instruction_o.op = SLL;  
                          if (instr.instr[31:26] != 6'b0)
                            illegal_instr = 1'b1;
                        end

                        3'b101: begin
                            if (instr.instr[31:26] == 6'b0)
                                instruction_o.op = SRL;  
                            else if (instr.instr[31:26] == 6'b010_000)
                                instruction_o.op = SRA;  
                            else
                                illegal_instr = 1'b1;
                        end
                    endcase
                end

                riscv_pkg::OpcodeOpImm32: begin
                    instruction_o.fu  = ALU;
                    imm_select = IIMM;
                    instruction_o.rs1[4:0] = instr.itype.rs1;
                    instruction_o.rd[4:0]  = instr.itype.rd;

                    unique case (instr.itype.funct3)
                        3'b000: instruction_o.op = ADDW;  

                        3'b001: begin
                          instruction_o.op = SLLW;  
                          if (instr.instr[31:25] != 7'b0)
                              illegal_instr = 1'b1;
                        end

                        3'b101: begin
                            if (instr.instr[31:25] == 7'b0)
                                instruction_o.op = SRLW;  
                            else if (instr.instr[31:25] == 7'b010_0000)
                                instruction_o.op = SRAW;  
                            else
                                illegal_instr = 1'b1;
                        end

                        default: illegal_instr = 1'b1;
                    endcase
                end

                riscv_pkg::OpcodeStore: begin
                    instruction_o.fu  = STORE;
                    imm_select = SIMM;
                    instruction_o.rs1[4:0]  = instr.stype.rs1;
                    instruction_o.rs2[4:0]  = instr.stype.rs2;

                    unique case (instr.stype.funct3)
                        3'b000: instruction_o.op  = SB;
                        3'b001: instruction_o.op  = SH;
                        3'b010: instruction_o.op  = SW;
                        3'b011: instruction_o.op  = SD;
                        default: illegal_instr = 1'b1;
                    endcase
                end

                riscv_pkg::OpcodeLoad: begin
                    instruction_o.fu  = LOAD;
                    imm_select = IIMM;
                    instruction_o.rs1[4:0] = instr.itype.rs1;
                    instruction_o.rd[4:0]  = instr.itype.rd;

                    unique case (instr.itype.funct3)
                        3'b000: instruction_o.op  = LB;
                        3'b001: instruction_o.op  = LH;
                        3'b010: instruction_o.op  = LW;
                        3'b100: instruction_o.op  = LBU;
                        3'b101: instruction_o.op  = LHU;
                        3'b110: instruction_o.op  = LWU;
                        3'b011: instruction_o.op  = LD;
                        default: illegal_instr = 1'b1;
                    endcase
                end

                riscv_pkg::OpcodeStoreFp: begin
                    if (FP_PRESENT && fs_i != riscv_pkg::Off) begin 
                        instruction_o.fu  = STORE;
                        imm_select = SIMM;
                        instruction_o.rs1        = instr.stype.rs1;
                        instruction_o.rs2        = instr.stype.rs2;

                        unique case (instr.stype.funct3)

                            3'b000: if (XF8) instruction_o.op = FSB;
                                    else illegal_instr = 1'b1;
                            3'b001: if (XF16 | XF16ALT) instruction_o.op = FSH;
                                    else illegal_instr = 1'b1;
                            3'b010: if (RVF) instruction_o.op = FSW;
                                    else illegal_instr = 1'b1;
                            3'b011: if (RVD) instruction_o.op = FSD;
                                    else illegal_instr = 1'b1;
                            default: illegal_instr = 1'b1;
                        endcase
                    end else
                        illegal_instr = 1'b1;
                end

                riscv_pkg::OpcodeLoadFp: begin
                    if (FP_PRESENT && fs_i != riscv_pkg::Off) begin 
                        instruction_o.fu  = LOAD;
                        imm_select = IIMM;
                        instruction_o.rs1       = instr.itype.rs1;
                        instruction_o.rd        = instr.itype.rd;

                        unique case (instr.itype.funct3)

                            3'b000: if (XF8) instruction_o.op = FLB;
                                    else illegal_instr = 1'b1;
                            3'b001: if (XF16 | XF16ALT) instruction_o.op = FLH;
                                    else illegal_instr = 1'b1;
                            3'b010: if (RVF) instruction_o.op  = FLW;
                                    else illegal_instr = 1'b1;
                            3'b011: if (RVD) instruction_o.op  = FLD;
                                    else illegal_instr = 1'b1;
                            default: illegal_instr = 1'b1;
                        endcase
                    end else
                        illegal_instr = 1'b1;
                end

                riscv_pkg::OpcodeMadd,
                riscv_pkg::OpcodeMsub,
                riscv_pkg::OpcodeNmsub,
                riscv_pkg::OpcodeNmadd: begin
                    if (FP_PRESENT && fs_i != riscv_pkg::Off) begin 
                        instruction_o.fu  = FPU;
                        instruction_o.rs1 = instr.r4type.rs1;
                        instruction_o.rs2 = instr.r4type.rs2;
                        instruction_o.rd  = instr.r4type.rd;
                        imm_select        = RS3; 
                        check_fprm        = 1'b1;

                        unique case (instr.r4type.opcode)
                            default:      instruction_o.op = FMADD;  
                            riscv_pkg::OpcodeMsub:  instruction_o.op = FMSUB;  
                            riscv_pkg::OpcodeNmsub: instruction_o.op = FNMSUB; 
                            riscv_pkg::OpcodeNmadd: instruction_o.op = FNMADD; 
                        endcase

                        unique case (instr.r4type.funct2)

                            2'b00: if (~RVF)             illegal_instr = 1'b1;
                            2'b01: if (~RVD)             illegal_instr = 1'b1;
                            2'b10: if (~XF16 & ~XF16ALT) illegal_instr = 1'b1;
                            2'b11: if (~XF8)             illegal_instr = 1'b1;
                            default: illegal_instr = 1'b1;
                        endcase

                        if (check_fprm) begin
                            unique case (instr.rftype.rm) inside
                                [3'b000:3'b100]: ; 
                                3'b101: begin      
                                    if (~XF16ALT || instr.rftype.fmt != 2'b10)
                                        illegal_instr = 1'b1;
                                    unique case (frm_i) inside 
                                        [3'b000:3'b100]: ; 
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                3'b111: begin

                                    unique case (frm_i) inside
                                        [3'b000:3'b100]: ; 
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                default : illegal_instr = 1'b1;
                            endcase
                        end
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                riscv_pkg::OpcodeOpFp: begin
                    if (FP_PRESENT && fs_i != riscv_pkg::Off) begin 
                        instruction_o.fu  = FPU;
                        instruction_o.rs1 = instr.rftype.rs1;
                        instruction_o.rs2 = instr.rftype.rs2;
                        instruction_o.rd  = instr.rftype.rd;
                        check_fprm        = 1'b1;

                        unique case (instr.rftype.funct5)
                            5'b00000: begin
                                instruction_o.op  = FADD;             
                                instruction_o.rs1 = '0;               
                                instruction_o.rs2 = instr.rftype.rs1; 
                                imm_select        = IIMM;             
                            end
                            5'b00001: begin
                                instruction_o.op  = FSUB;  
                                instruction_o.rs1 = '0;               
                                instruction_o.rs2 = instr.rftype.rs1; 
                                imm_select        = IIMM;             
                            end
                            5'b00010: instruction_o.op = FMUL;  
                            5'b00011: instruction_o.op = FDIV;  
                            5'b01011: begin
                                instruction_o.op = FSQRT; 

                                if (instr.rftype.rs2 != 5'b00000) illegal_instr = 1'b1;
                            end
                            5'b00100: begin
                                instruction_o.op = FSGNJ; 
                                check_fprm       = 1'b0;  
                                if (XF16ALT) begin        
                                    if (!(instr.rftype.rm inside {[3'b000:3'b010], [3'b100:3'b110]}))
                                        illegal_instr = 1'b1;
                                end else begin
                                    if (!(instr.rftype.rm inside {[3'b000:3'b010]}))
                                        illegal_instr = 1'b1;
                                end
                            end
                            5'b00101: begin
                                instruction_o.op = FMIN_MAX; 
                                check_fprm       = 1'b0;     
                                if (XF16ALT) begin           
                                    if (!(instr.rftype.rm inside {[3'b000:3'b001], [3'b100:3'b101]}))
                                        illegal_instr = 1'b1;
                                end else begin
                                    if (!(instr.rftype.rm inside {[3'b000:3'b001]}))
                                        illegal_instr = 1'b1;
                                end
                            end
                            5'b01000: begin
                                instruction_o.op  = FCVT_F2F; 
                                instruction_o.rs2 = instr.rvftype.rs1; 
                                imm_select        = IIMM;     
                                if (instr.rftype.rs2[24:23]) illegal_instr = 1'b1; 

                                unique case (instr.rftype.rs2[22:20])

                                    3'b000: if (~RVF)     illegal_instr = 1'b1;
                                    3'b001: if (~RVD)     illegal_instr = 1'b1;
                                    3'b010: if (~XF16)    illegal_instr = 1'b1;
                                    3'b110: if (~XF16ALT) illegal_instr = 1'b1;
                                    3'b011: if (~XF8)     illegal_instr = 1'b1;
                                    default: illegal_instr = 1'b1;
                                endcase
                            end
                            5'b10100: begin
                                instruction_o.op = FCMP; 
                                check_fprm       = 1'b0; 
                                if (XF16ALT) begin       
                                    if (!(instr.rftype.rm inside {[3'b000:3'b010], [3'b100:3'b110]}))
                                        illegal_instr = 1'b1;
                                end else begin
                                    if (!(instr.rftype.rm inside {[3'b000:3'b010]}))
                                        illegal_instr = 1'b1;
                                end
                            end
                            5'b11000: begin
                                instruction_o.op = FCVT_F2I; 
                                imm_select       = IIMM;     
                                if (instr.rftype.rs2[24:22]) illegal_instr = 1'b1; 
                            end
                            5'b11010: begin
                                instruction_o.op = FCVT_I2F;  
                                imm_select       = IIMM;     
                                if (instr.rftype.rs2[24:22]) illegal_instr = 1'b1; 
                            end
                            5'b11100: begin
                                instruction_o.rs2 = instr.rftype.rs1; 
                                check_fprm        = 1'b0; 
                                if (instr.rftype.rm == 3'b000 || (XF16ALT && instr.rftype.rm == 3'b100)) 
                                    instruction_o.op = FMV_F2X;       
                                else if (instr.rftype.rm == 3'b001 || (XF16ALT && instr.rftype.rm == 3'b101)) 
                                    instruction_o.op = FCLASS; 
                                else illegal_instr = 1'b1;

                                if (instr.rftype.rs2 != 5'b00000) illegal_instr = 1'b1;
                            end
                            5'b11110: begin
                                instruction_o.op = FMV_X2F;   
                                instruction_o.rs2 = instr.rftype.rs1; 
                                check_fprm       = 1'b0; 
                                if (!(instr.rftype.rm == 3'b000 || (XF16ALT && instr.rftype.rm == 3'b100)))
                                    illegal_instr = 1'b1;

                                if (instr.rftype.rs2 != 5'b00000) illegal_instr = 1'b1;
                            end
                            default : illegal_instr = 1'b1;
                        endcase

                        unique case (instr.rftype.fmt)

                            2'b00: if (~RVF)             illegal_instr = 1'b1;
                            2'b01: if (~RVD)             illegal_instr = 1'b1;
                            2'b10: if (~XF16 & ~XF16ALT) illegal_instr = 1'b1;
                            2'b11: if (~XF8)             illegal_instr = 1'b1;
                            default: illegal_instr = 1'b1;
                        endcase

                        if (check_fprm) begin
                            unique case (instr.rftype.rm) inside
                                [3'b000:3'b100]: ; 
                                3'b101: begin      
                                    if (~XF16ALT || instr.rftype.fmt != 2'b10)
                                        illegal_instr = 1'b1;
                                    unique case (frm_i) inside 
                                        [3'b000:3'b100]: ; 
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                3'b111: begin

                                    unique case (frm_i) inside
                                        [3'b000:3'b100]: ; 
                                        default : illegal_instr = 1'b1;
                                    endcase
                                end
                                default : illegal_instr = 1'b1;
                            endcase
                        end
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                riscv_pkg::OpcodeAmo: begin

                    instruction_o.fu  = STORE;
                    instruction_o.rs1[4:0] = instr.atype.rs1;
                    instruction_o.rs2[4:0] = instr.atype.rs2;
                    instruction_o.rd[4:0]  = instr.atype.rd;

                    if (RVA && instr.stype.funct3 == 3'h2) begin
                        unique case (instr.instr[31:27])
                            5'h0:  instruction_o.op = AMO_ADDW;
                            5'h1:  instruction_o.op = AMO_SWAPW;
                            5'h2: begin
                                instruction_o.op = AMO_LRW;
                                if (instr.atype.rs2 != 0) illegal_instr = 1'b1;
                            end
                            5'h3:  instruction_o.op = AMO_SCW;
                            5'h4:  instruction_o.op = AMO_XORW;
                            5'h8:  instruction_o.op = AMO_ORW;
                            5'hC:  instruction_o.op = AMO_ANDW;
                            5'h10: instruction_o.op = AMO_MINW;
                            5'h14: instruction_o.op = AMO_MAXW;
                            5'h18: instruction_o.op = AMO_MINWU;
                            5'h1C: instruction_o.op = AMO_MAXWU;
                            default: illegal_instr = 1'b1;
                        endcase

                    end else if (RVA && instr.stype.funct3 == 3'h3) begin
                        unique case (instr.instr[31:27])
                            5'h0:  instruction_o.op = AMO_ADDD;
                            5'h1:  instruction_o.op = AMO_SWAPD;
                            5'h2: begin
                                instruction_o.op = AMO_LRD;
                                if (instr.atype.rs2 != 0) illegal_instr = 1'b1;
                            end
                            5'h3:  instruction_o.op = AMO_SCD;
                            5'h4:  instruction_o.op = AMO_XORD;
                            5'h8:  instruction_o.op = AMO_ORD;
                            5'hC:  instruction_o.op = AMO_ANDD;
                            5'h10: instruction_o.op = AMO_MIND;
                            5'h14: instruction_o.op = AMO_MAXD;
                            5'h18: instruction_o.op = AMO_MINDU;
                            5'h1C: instruction_o.op = AMO_MAXDU;
                            default: illegal_instr = 1'b1;
                        endcase
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end

                riscv_pkg::OpcodeBranch: begin
                    imm_select              = SBIMM;
                    instruction_o.fu        = CTRL_FLOW;
                    instruction_o.rs1[4:0]  = instr.stype.rs1;
                    instruction_o.rs2[4:0]  = instr.stype.rs2;

                    is_control_flow_instr_o = 1'b1;

                    case (instr.stype.funct3)
                        3'b000: instruction_o.op = EQ;
                        3'b001: instruction_o.op = NE;
                        3'b100: instruction_o.op = LTS;
                        3'b101: instruction_o.op = GES;
                        3'b110: instruction_o.op = LTU;
                        3'b111: instruction_o.op = GEU;
                        default: begin
                            is_control_flow_instr_o = 1'b0;
                            illegal_instr           = 1'b1;
                        end
                    endcase
                end

                riscv_pkg::OpcodeJalr: begin
                    instruction_o.fu        = CTRL_FLOW;
                    instruction_o.op        = JALR;
                    instruction_o.rs1[4:0]  = instr.itype.rs1;
                    imm_select              = IIMM;
                    instruction_o.rd[4:0]   = instr.itype.rd;
                    is_control_flow_instr_o = 1'b1;

                    if (instr.itype.funct3 != 3'b0) illegal_instr = 1'b1;
                end

                riscv_pkg::OpcodeJal: begin
                    instruction_o.fu        = CTRL_FLOW;
                    imm_select              = JIMM;
                    instruction_o.rd[4:0]   = instr.utype.rd;
                    is_control_flow_instr_o = 1'b1;
                end

                riscv_pkg::OpcodeAuipc: begin
                    instruction_o.fu      = ALU;
                    imm_select            = UIMM;
                    instruction_o.use_pc  = 1'b1;
                    instruction_o.rd[4:0] = instr.utype.rd;
                end

                riscv_pkg::OpcodeLui: begin
                    imm_select            = UIMM;
                    instruction_o.fu      = ALU;
                    instruction_o.rd[4:0] = instr.utype.rd;
                end

                default: illegal_instr = 1'b1;
            endcase
        end
    end

    always_comb begin : sign_extend
        imm_i_type  = i_imm(instruction_i);
        imm_s_type  = { {52 {instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7] };
        imm_sb_type = sb_imm(instruction_i);
        imm_u_type  = { {32 {instruction_i[31]}}, instruction_i[31:12], 12'b0 }; 
        imm_uj_type = uj_imm(instruction_i);
        imm_bi_type = { {59{instruction_i[24]}}, instruction_i[24:20] };

        case (imm_select)
            IIMM: begin
                instruction_o.result = imm_i_type;
                instruction_o.use_imm = 1'b1;
            end
            SIMM: begin
                instruction_o.result = imm_s_type;
                instruction_o.use_imm = 1'b1;
            end
            SBIMM: begin
                instruction_o.result = imm_sb_type;
                instruction_o.use_imm = 1'b1;
            end
            UIMM: begin
                instruction_o.result = imm_u_type;
                instruction_o.use_imm = 1'b1;
            end
            JIMM: begin
                instruction_o.result = imm_uj_type;
                instruction_o.use_imm = 1'b1;
            end
            RS3: begin

                instruction_o.result = {59'b0, instr.r4type.rs3};
                instruction_o.use_imm = 1'b0;
            end
            default: begin
                instruction_o.result = 64'b0;
                instruction_o.use_imm = 1'b0;
            end
        endcase
    end

    always_comb begin : exception_handling
        instruction_o.ex      = ex_i;
        instruction_o.valid   = ex_i.valid;

        if (~ex_i.valid) begin

            instruction_o.ex.tval  = (is_compressed_i) ? {48'b0, compressed_instr_i} : {32'b0, instruction_i};

            if (illegal_instr || is_illegal_i) begin
                instruction_o.valid    = 1'b1;
                instruction_o.ex.valid = 1'b1;

                instruction_o.ex.cause = riscv_pkg::ILLEGAL_INSTR;

            end else if (ecall) begin

                instruction_o.valid    = 1'b1;

                instruction_o.ex.valid = 1'b1;

                case (priv_lvl_i)
                    riscv_pkg::PRIV_LVL_M: instruction_o.ex.cause = riscv_pkg::ENV_CALL_MMODE;
                    riscv_pkg::PRIV_LVL_S: instruction_o.ex.cause = riscv_pkg::ENV_CALL_SMODE;
                    riscv_pkg::PRIV_LVL_U: instruction_o.ex.cause = riscv_pkg::ENV_CALL_UMODE;
                    default:; 
                endcase
            end else if (ebreak) begin

                instruction_o.valid    = 1'b1;

                instruction_o.ex.valid = 1'b1;

                instruction_o.ex.cause = riscv_pkg::BREAKPOINT;
            end
        end
    end
endmodule
