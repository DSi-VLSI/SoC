import ariane_pkg::*;module instr_realigner (
    input  logic                   clk_i,               
    input  logic                   rst_ni,              

    input  logic                   flush_i,

    input  frontend_fetch_t        fetch_entry_i,
    input  logic                   fetch_entry_valid_i,
    output logic                   fetch_ack_o,

    output fetch_entry_t           fetch_entry_o,
    output logic                   fetch_entry_valid_o,
    input  logic                   fetch_ack_i
);

    logic        unaligned_n,         unaligned_q;

    logic [15:0] unaligned_instr_n,   unaligned_instr_q;

    logic        compressed_n,        compressed_q;

    logic [63:0] unaligned_address_n, unaligned_address_q;

    logic jump_unaligned_half_word;

    logic kill_upper_16_bit;
    assign kill_upper_16_bit = fetch_entry_i.branch_predict.valid &
                               fetch_entry_i.branch_predict.predict_taken &
                               fetch_entry_i.bp_taken[0];

    always_comb begin : realign_instr

        unaligned_n          = unaligned_q;
        unaligned_instr_n    = unaligned_instr_q;
        compressed_n         = compressed_q;
        unaligned_address_n  = unaligned_address_q;

        fetch_entry_o.address        = fetch_entry_i.address;
        fetch_entry_o.instruction    = fetch_entry_i.instruction;
        fetch_entry_o.branch_predict = fetch_entry_i.branch_predict;
        fetch_entry_o.ex.valid       = fetch_entry_i.page_fault;
        fetch_entry_o.ex.tval        = (fetch_entry_i.page_fault) ? fetch_entry_i.address : '0;
        fetch_entry_o.ex.cause       = (fetch_entry_i.page_fault) ? riscv_pkg::INSTR_PAGE_FAULT : '0;

        fetch_entry_valid_o  = fetch_entry_valid_i;
        fetch_ack_o        = fetch_ack_i;

        jump_unaligned_half_word = 1'b0;

        if (fetch_entry_valid_i && !compressed_q) begin

            if (fetch_entry_i.address[1] == 1'b0) begin

                if (!unaligned_q) begin

                    unaligned_n = 1'b0;

                    if (fetch_entry_i.instruction[1:0] != 2'b11) begin

                        fetch_entry_o.instruction = {15'b0, fetch_entry_i.instruction[15:0]};

                        if (fetch_entry_i.branch_predict.valid && !fetch_entry_i.bp_taken[0])
                            fetch_entry_o.branch_predict.valid = 1'b0;

                        if (!kill_upper_16_bit) begin

                            if (fetch_entry_i.instruction[17:16] != 2'b11) begin

                                compressed_n = 1'b1;

                                fetch_ack_o = 1'b0;

                            end else begin

                                unaligned_instr_n = fetch_entry_i.instruction[31:16];

                                unaligned_address_n = {fetch_entry_i.address[63:2], 2'b10};

                                unaligned_n = 1'b1;

                            end
                        end
                    end
                end

                else if (unaligned_q) begin

                    fetch_entry_o.address = unaligned_address_q;
                    fetch_entry_o.instruction = {fetch_entry_i.instruction[15:0], unaligned_instr_q};

                    if (!kill_upper_16_bit) begin

                        if (fetch_entry_i.instruction[17:16] != 2'b11) begin

                            compressed_n  = 1'b1;

                            fetch_ack_o = 1'b0;

                            unaligned_n = 1'b0;

                            if (fetch_entry_i.branch_predict.valid && !fetch_entry_i.bp_taken[0])
                                fetch_entry_o.branch_predict.valid = 1'b0;

                        end else if (!kill_upper_16_bit) begin

                            unaligned_instr_n = fetch_entry_i.instruction[31:16];

                            unaligned_address_n = {fetch_entry_i.address[63:2], 2'b10};

                            unaligned_n = 1'b1;
                        end
                    end

                    else if (fetch_entry_i.branch_predict.valid) begin

                        unaligned_n = 1'b0;
                    end
                end
            end

            else if (fetch_entry_i.address[1] == 1'b1) begin 

                unaligned_n = 1'b0;

                if (fetch_entry_i.instruction[17:16] != 2'b11) begin

                    fetch_entry_o.instruction = {15'b0, fetch_entry_i.instruction[31:16]};

                end else begin

                    unaligned_instr_n = fetch_entry_i.instruction[31:16];

                    unaligned_n = 1'b1;

                    unaligned_address_n = {fetch_entry_i.address[63:2], 2'b10};

                    fetch_entry_valid_o = 1'b0;

                    fetch_ack_o = 1'b1;

                    jump_unaligned_half_word = 1'b1;
                end

            end
        end

        if (compressed_q) begin
            fetch_ack_o = fetch_ack_i;
            compressed_n  = 1'b0;
            fetch_entry_o.instruction = {16'b0, fetch_entry_i.instruction[31:16]};
            fetch_entry_o.address = {fetch_entry_i.address[63:2], 2'b10};
            fetch_entry_valid_o = 1'b1;
        end

        if (!fetch_ack_i && !jump_unaligned_half_word) begin
            unaligned_n         = unaligned_q;
            unaligned_instr_n   = unaligned_instr_q;
            compressed_n        = compressed_q;
            unaligned_address_n = unaligned_address_q;
        end

        if (flush_i) begin

            unaligned_n  = 1'b0;
            compressed_n = 1'b0;
        end

        fetch_entry_o.ex.tval = fetch_entry_o.address;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            unaligned_q         <= 1'b0;
            unaligned_instr_q   <= 16'b0;
            unaligned_address_q <= 64'b0;
            compressed_q        <= 1'b0;
        end else begin
            unaligned_q         <= unaligned_n;
            unaligned_instr_q   <= unaligned_instr_n;
            unaligned_address_q <= unaligned_address_n;
            compressed_q        <= compressed_n;
        end
    end

endmodule
