import ariane_pkg::*;module compressed_decoder
(
    input  logic [31:0] instr_i,
    output logic [31:0] instr_o,
    output logic        illegal_instr_o,
    output logic        is_compressed_o
);

    always_comb begin
        illegal_instr_o = 1'b0;
        instr_o         = '0;
        is_compressed_o = 1'b1;
        instr_o         = instr_i;

        unique case (instr_i[1:0])

            riscv_pkg::OpcodeC0: begin
                unique case (instr_i[15:13])
                    riscv_pkg::OpcodeC0Addi4spn: begin

                        instr_o = {2'b0, instr_i[10:7], instr_i[12:11], instr_i[5], instr_i[6], 2'b00, 5'h02, 3'b000, 2'b01, instr_i[4:2], riscv_pkg::OpcodeOpImm};
                        if (instr_i[12:5] == 8'b0)  illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC0Fld: begin

                        instr_o = {4'b0, instr_i[6:5], instr_i[12:10], 3'b000, 2'b01, instr_i[9:7], 3'b011, 2'b01, instr_i[4:2], riscv_pkg::OpcodeLoadFp};
                    end

                    riscv_pkg::OpcodeC0Lw: begin

                        instr_o = {5'b0, instr_i[5], instr_i[12:10], instr_i[6], 2'b00, 2'b01, instr_i[9:7], 3'b010, 2'b01, instr_i[4:2], riscv_pkg::OpcodeLoad};
                    end

                    riscv_pkg::OpcodeC0Ld: begin

                        instr_o = {4'b0, instr_i[6:5], instr_i[12:10], 3'b000, 2'b01, instr_i[9:7], 3'b011, 2'b01, instr_i[4:2], riscv_pkg::OpcodeLoad};
                    end

                    riscv_pkg::OpcodeC0Fsd: begin

                        instr_o = {4'b0, instr_i[6:5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b011, instr_i[11:10], 3'b000, riscv_pkg::OpcodeStoreFp};
                    end

                    riscv_pkg::OpcodeC0Sw: begin

                        instr_o = {5'b0, instr_i[5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b010, instr_i[11:10], instr_i[6], 2'b00, riscv_pkg::OpcodeStore};
                    end

                    riscv_pkg::OpcodeC0Sd: begin

                        instr_o = {4'b0, instr_i[6:5], instr_i[12], 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b011, instr_i[11:10], 3'b000, riscv_pkg::OpcodeStore};
                    end

                    default: begin
                        illegal_instr_o = 1'b1;
                    end
              endcase
            end

            riscv_pkg::OpcodeC1: begin
                unique case (instr_i[15:13])
                    riscv_pkg::OpcodeC1Addi: begin

                        instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b0, instr_i[11:7], riscv_pkg::OpcodeOpImm};
                    end

                    riscv_pkg::OpcodeC1Addiw: begin
                        if (instr_i[11:7] != 5'h0) 
                            instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b0, instr_i[11:7], riscv_pkg::OpcodeOpImm32};
                        else
                            illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC1Li: begin

                        instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 5'b0, 3'b0, instr_i[11:7], riscv_pkg::OpcodeOpImm};
                        if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC1LuiAddi16sp: begin

                        instr_o = {{15 {instr_i[12]}}, instr_i[6:2], instr_i[11:7], riscv_pkg::OpcodeLui};

                        if (instr_i[11:7] == 5'h02) begin

                            instr_o = {{3 {instr_i[12]}}, instr_i[4:3], instr_i[5], instr_i[2], instr_i[6], 4'b0, 5'h02, 3'b000, 5'h02, riscv_pkg::OpcodeOpImm};
                        end else if (instr_i[11:7] == 5'b0) begin
                            illegal_instr_o = 1'b1;
                        end

                        if ({instr_i[12], instr_i[6:2]} == 6'b0) illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC1MiscAlu: begin
                        unique case (instr_i[11:10])
                            2'b00,
                            2'b01: begin

                                instr_o = {1'b0, instr_i[10], 4'b0, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7], 3'b101, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOpImm};

                                if ({instr_i[12], instr_i[6:2]} == 6'b0) illegal_instr_o = 1'b1;
                            end

                            2'b10: begin

                                instr_o = {{6 {instr_i[12]}}, instr_i[12], instr_i[6:2], 2'b01, instr_i[9:7], 3'b111, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOpImm};
                            end

                            2'b11: begin
                                unique case ({instr_i[12], instr_i[6:5]})
                                    3'b000: begin

                                        instr_o = {2'b01, 5'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b000, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOp};
                                    end

                                    3'b001: begin

                                        instr_o = {7'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b100, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOp};
                                    end

                                    3'b010: begin

                                        instr_o = {7'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b110, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOp};
                                    end

                                    3'b011: begin

                                        instr_o = {7'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b111, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOp};
                                    end

                                    3'b100: begin

                                        instr_o = {2'b01, 5'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b000, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOp32};
                                    end
                                    3'b101: begin

                                        instr_o = {2'b00, 5'b0, 2'b01, instr_i[4:2], 2'b01, instr_i[9:7], 3'b000, 2'b01, instr_i[9:7], riscv_pkg::OpcodeOp32};
                                    end

                                    3'b110,
                                    3'b111: begin

                                        illegal_instr_o = 1'b1;
                                        instr_o = {16'b0, instr_i};
                                    end
                                endcase
                            end
                        endcase
                    end

                    riscv_pkg::OpcodeC1J: begin

                        instr_o = {instr_i[12], instr_i[8], instr_i[10:9], instr_i[6], instr_i[7], instr_i[2], instr_i[11], instr_i[5:3], {9 {instr_i[12]}}, 4'b0, ~instr_i[15], riscv_pkg::OpcodeJal};
                    end

                    riscv_pkg::OpcodeC1Beqz, riscv_pkg::OpcodeC1Bnez: begin

                        instr_o = {{4 {instr_i[12]}}, instr_i[6:5], instr_i[2], 5'b0, 2'b01, instr_i[9:7], 2'b00, instr_i[13], instr_i[11:10], instr_i[4:3], instr_i[12], riscv_pkg::OpcodeBranch};
                    end
                endcase
            end

            riscv_pkg::OpcodeC2: begin
                unique case (instr_i[15:13])
                    riscv_pkg::OpcodeC2Slli: begin

                        instr_o = {6'b0, instr_i[12], instr_i[6:2], instr_i[11:7], 3'b001, instr_i[11:7], riscv_pkg::OpcodeOpImm};
                        if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1; 
                        if ({instr_i[12], instr_i[6:2]}  == 6'b0)  illegal_instr_o = 1'b1; 
                    end

                    riscv_pkg::OpcodeC2Fldsp: begin

                        instr_o = {3'b0, instr_i[4:2], instr_i[12], instr_i[6:5], 3'b000, 5'h02, 3'b011, instr_i[11:7], riscv_pkg::OpcodeLoadFp};
                        if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC2Lwsp: begin

                        instr_o = {4'b0, instr_i[3:2], instr_i[12], instr_i[6:4], 2'b00, 5'h02, 3'b010, instr_i[11:7], riscv_pkg::OpcodeLoad};
                        if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC2Ldsp: begin

                        instr_o = {3'b0, instr_i[4:2], instr_i[12], instr_i[6:5], 3'b000, 5'h02, 3'b011, instr_i[11:7], riscv_pkg::OpcodeLoad};
                        if (instr_i[11:7] == 5'b0)  illegal_instr_o = 1'b1;
                    end

                    riscv_pkg::OpcodeC2JalrMvAdd: begin
                        if (instr_i[12] == 1'b0) begin

                            instr_o = {7'b0, instr_i[6:2], 5'b0, 3'b0, instr_i[11:7], riscv_pkg::OpcodeOp};

                            if (instr_i[6:2] == 5'b0) begin

                                instr_o = {12'b0, instr_i[11:7], 3'b0, 5'b0, riscv_pkg::OpcodeJalr};

                                illegal_instr_o = (instr_i[11:7] != '0) ? 1'b0 : 1'b1;
                            end
                        end else begin

                            instr_o = {7'b0, instr_i[6:2], instr_i[11:7], 3'b0, instr_i[11:7], riscv_pkg::OpcodeOp};

                            if (instr_i[11:7] == 5'b0) begin

                                instr_o = {32'h00_10_00_73};
                                if (instr_i[6:2] != 5'b0)
                                    illegal_instr_o = 1'b1;
                            end else if (instr_i[6:2] == 5'b0) begin

                                instr_o = {12'b0, instr_i[11:7], 3'b000, 5'b00001, riscv_pkg::OpcodeJalr};
                            end
                        end
                    end

                    riscv_pkg::OpcodeC2Fsdsp: begin

                        instr_o = {3'b0, instr_i[9:7], instr_i[12], instr_i[6:2], 5'h02, 3'b011, instr_i[11:10], 3'b000, riscv_pkg::OpcodeStoreFp};
                    end

                    riscv_pkg::OpcodeC2Swsp: begin

                        instr_o = {4'b0, instr_i[8:7], instr_i[12], instr_i[6:2], 5'h02, 3'b010, instr_i[11:9], 2'b00, riscv_pkg::OpcodeStore};
                    end

                    riscv_pkg::OpcodeC2Sdsp: begin

                        instr_o = {3'b0, instr_i[9:7], instr_i[12], instr_i[6:2], 5'h02, 3'b011, instr_i[11:10], 3'b000, riscv_pkg::OpcodeStore};
                    end

                    default: begin
                        illegal_instr_o = 1'b1;
                    end
                endcase
            end

            default: is_compressed_o = 1'b0;
        endcase

        if (illegal_instr_o && is_compressed_o) begin
            instr_o = instr_i;
        end
    end
endmodule
