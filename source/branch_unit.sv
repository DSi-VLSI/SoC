import ariane_pkg::*;module branch_unit (
    input  fu_data_t                  fu_data_i,
    input  logic [63:0]               pc_i,                   
    input  logic                      is_compressed_instr_i,
    input  logic                      fu_valid_i,             
    input  logic                      branch_valid_i,
    input  logic                      branch_comp_res_i,      
    output logic [63:0]               branch_result_o,

    input  branchpredict_sbe_t        branch_predict_i,       
    output branchpredict_t            resolved_branch_o,      
    output logic                      resolve_branch_o,       

    output exception_t                branch_exception_o      
);
    logic [63:0] target_address;
    logic [63:0] next_pc;

    always_comb begin : mispredict_handler

        automatic logic [63:0] jump_base;
        jump_base = (fu_data_i.operator == JALR) ? fu_data_i.operand_a : pc_i;

        resolve_branch_o                 = 1'b0;
        resolved_branch_o.target_address = 64'b0;
        resolved_branch_o.is_taken       = 1'b0;
        resolved_branch_o.valid          = branch_valid_i;
        resolved_branch_o.is_mispredict  = 1'b0;
        resolved_branch_o.clear          = 1'b0;
        resolved_branch_o.cf_type        = branch_predict_i.cf_type;

        next_pc                          = pc_i + ((is_compressed_instr_i) ? 64'h2 : 64'h4);

        target_address                   = $unsigned($signed(jump_base) + $signed(fu_data_i.imm));

        if (fu_data_i.operator == JALR)
            target_address[0] = 1'b0;

        branch_result_o = next_pc;

        resolved_branch_o.pc = (is_compressed_instr_i || pc_i[1] == 1'b0) ? pc_i : ({pc_i[63:2], 2'b0} + 64'h4);

        if (branch_valid_i) begin

            resolved_branch_o.target_address = (branch_comp_res_i) ? target_address : next_pc;
            resolved_branch_o.is_taken       = branch_comp_res_i;

            if (target_address[0] == 1'b0) begin

                if (branch_predict_i.valid) begin

                    if (branch_predict_i.predict_taken != branch_comp_res_i) begin
                        resolved_branch_o.is_mispredict  = 1'b1;
                    end

                    if (branch_predict_i.predict_taken && target_address != branch_predict_i.predict_address) begin
                        resolved_branch_o.is_mispredict  = 1'b1;
                    end

                end else begin
                    if (branch_comp_res_i) begin
                        resolved_branch_o.is_mispredict = 1'b1;
                    end
                end
            end

            resolve_branch_o = 1'b1;

        end else if (fu_valid_i && branch_predict_i.valid && branch_predict_i.predict_taken) begin

            resolved_branch_o.is_mispredict  = 1'b1;
            resolved_branch_o.target_address = next_pc;

            resolved_branch_o.clear          = 1'b1;
            resolved_branch_o.valid          = 1'b1;
            resolve_branch_o                 = 1'b1;
        end
    end

    always_comb begin : exception_handling
        branch_exception_o.cause = riscv_pkg::INSTR_ADDR_MISALIGNED;
        branch_exception_o.valid = 1'b0;
        branch_exception_o.tval  = pc_i;

        if (branch_valid_i && target_address[0] != 1'b0)
            branch_exception_o.valid = 1'b1;
    end
endmodule
