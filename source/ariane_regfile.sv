module ariane_regfile #(
  parameter int unsigned DATA_WIDTH     = 32,
  parameter int unsigned NR_READ_PORTS  = 2,
  parameter int unsigned NR_WRITE_PORTS = 2,
  parameter bit          ZERO_REG_ZERO  = 0
)(

  input  logic                                      clk_i,
  input  logic                                      rst_ni,

  input  logic                                      test_en_i,

  input  logic [NR_READ_PORTS-1:0][4:0]             raddr_i,
  output logic [NR_READ_PORTS-1:0][DATA_WIDTH-1:0]  rdata_o,

  input  logic [NR_WRITE_PORTS-1:0][4:0]            waddr_i,
  input  logic [NR_WRITE_PORTS-1:0][DATA_WIDTH-1:0] wdata_i,
  input  logic [NR_WRITE_PORTS-1:0]                 we_i
);

  localparam    ADDR_WIDTH = 5;
  localparam    NUM_WORDS  = 2**ADDR_WIDTH;

  logic [NUM_WORDS-1:0][DATA_WIDTH-1:0]     mem;
  logic [NR_WRITE_PORTS-1:0][NUM_WORDS-1:0] we_dec;

    always_comb begin : we_decoder
        for (int unsigned j = 0; j < NR_WRITE_PORTS; j++) begin
            for (int unsigned i = 0; i < NUM_WORDS; i++) begin
                if (waddr_i[j] == i)
                    we_dec[j][i] = we_i[j];
                else
                    we_dec[j][i] = 1'b0;
            end
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin : register_write_behavioral
        if (~rst_ni) begin
            mem <= '{default: '0};
        end else begin
            for (int unsigned j = 0; j < NR_WRITE_PORTS; j++) begin
                for (int unsigned i = 0; i < NUM_WORDS; i++) begin
                    if (we_dec[j][i]) begin
                        mem[i] <= wdata_i[j];
                    end
                end
                if (ZERO_REG_ZERO) begin
                  mem[0] <= '0;
                end
            end
        end
    end

  for (genvar i = 0; i < NR_READ_PORTS; i++) begin
    assign rdata_o[i] = mem[raddr_i[i]];
  end

endmodule
