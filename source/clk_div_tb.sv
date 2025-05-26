module clk_div_tb;

  initial $display("\033[7;38m************** TEST STARTED **************\033[0m");
  final $display("\033[7;38m************** TEST ENDED **************\033[0m");

  parameter int DIV_WIDTH = 4;

  parameter realtime TP = 10ns;

  logic                 arst_ni;
  logic [DIV_WIDTH-1:0] div_i;
  logic                 clk_i;
  logic                 clk_o;

  bit                   test_passed;

  clk_div #(
      .DIV_WIDTH(DIV_WIDTH)
  ) u_dut (
      .arst_ni,
      .div_i,
      .clk_i,
      .clk_o
  );

  task static start_clock(input realtime timeperiod = 10ns);
    fork
      forever begin
        clk_i <= '1;
        #(timeperiod / 2);
        clk_i <= '0;
        #(timeperiod / 2);
      end
    join_none
  endtask

  task static apply_reset(input realtime duration = 100ns);
    #(duration / 10);
    arst_ni <= '0;
    div_i   <= '0;
    clk_i   <= '0;
    #(duration);
    arst_ni <= '1;
    #(duration / 10);
  endtask

  wire ref_clk = clk_i;
  bit  ref_clk_error;

  specify
    $width(posedge ref_clk, (TP / 2), 0, ref_clk_error);
    $width(negedge ref_clk, (TP / 2), 0, ref_clk_error);
  endspecify
  always @(ref_clk_error) begin
    test_passed = 0;
  end

  initial begin
    // $dumpfile("clk_div_tb.vcd");
    // $dumpvars(0, clk_div_tb);

    test_passed = 1;

    apply_reset();
    start_clock(TP);

    @(posedge clk_o);

    repeat (50) begin
      div_i <= $urandom;
      repeat (50) @(clk_i);
    end

    if (test_passed) $display("\033[1;32m************** TEST PASSED **************\033[0m");
    else $display("\033[1;31m************** TEST FAILED **************\033[0m");

    #100ns;

    $finish;

  end

endmodule
