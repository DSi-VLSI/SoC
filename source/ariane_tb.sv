module ariane_tb;

  // Display messages at the start and end of the test
  initial $display("\033[7;38m---------------------- TEST STARTED ----------------------\033[0m");
  final $display("\033[7;38m----------------------- TEST ENDED -----------------------\033[0m");

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Signals
  //////////////////////////////////////////////////////////////////////////////////////////////////

  logic clk;
  logic rst_n;

  logic [63:0] boot_addr;
  logic [63:0] hart_id;

  logic [1:0] irq;
  logic ipi;

  logic time_irq;
  logic debug_req;

  ariane_axi_pkg::m_req_t axi_req;
  ariane_axi_pkg::m_resp_t axi_resp;

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Declare dictionary of symbols
  longint sym[string];

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // DUT Instantiation
  //////////////////////////////////////////////////////////////////////////////////////////////////

  ariane #(
      .DmBaseAddress(0),
      .CachedAddrBeg('h80000000)
  ) u_core (
      .clk_i(clk),
      .rst_ni(rst_n),
      .boot_addr_i(boot_addr),
      .hart_id_i(hart_id),
      .irq_i(irq),
      .ipi_i(ipi),
      .time_irq_i(time_irq),
      .debug_req_i(debug_req),
      .axi_req_o(axi_req),
      .axi_resp_i(axi_resp)
  );

  axi_ram #(
      .MEM_BASE(0),
      .MEM_SIZE(32),
      .req_t   (ariane_axi_pkg::m_req_t),
      .resp_t  (ariane_axi_pkg::m_resp_t)
  ) u_axi_ram (
      .clk_i  (clk),
      .arst_ni(rst_n),
      .req_i  (axi_req),
      .resp_o (axi_resp)
  );

  //////////////////////////////////////////////////////////////////////////////////////////////////
  // Methods
  //////////////////////////////////////////////////////////////////////////////////////////////////

  // Function to load memory contents from a file
  function automatic void load_memory(string filename);
    bit [7:0] mem[longint];
    $readmemh(filename, mem);
    foreach (mem[i]) u_axi_ram.write_mem_b(i, mem[i]);
    // foreach (mem[i]) $display("MEM[0x%0x]:0x%x", i, u_axi_ram.read_mem_b(i));
  endfunction

  // Function to load symbols from a file
  function automatic void load_symbols(string filename);
    int file, r;
    string line;
    string key;
    int value;
    file = $fopen(filename, "r");
    if (file == 0) begin
      $display("Error: Could not open file %s", filename);
      $finish;
    end
    while (!$feof(
        file
    )) begin
      r = $fgets(line, file);
      if (r != 0) begin
        r = $sscanf(line, "%h %*s %s", value, key);
        sym[key] = value;
      end
    end
    $fclose(file);
  endfunction

  // Task to apply reset to the DUT
  task static apply_reset();
    #100ns;
    clk       <= '0;
    rst_n     <= '0;
    hart_id   <= 10;
    irq       <= '0;
    ipi       <= '0;
    time_irq  <= '0;
    debug_req <= '0;
    #100ns;
    rst_n <= 1'b1;
    #100ns;
  endtask

  // Task to start the clock signal
  task static start_clock();
    fork
      forever begin
        clk <= 1'b1;
        #5ns;
        clk <= 1'b0;
        #5ns;
      end
    join_none
  endtask

  // Task to monitor and print characters written to the simulated STDOUT
  task static monitor_prints();
    string prints;
    prints = "";
    fork
      forever begin
        @(posedge clk);
        if (u_axi_ram.addr_out == sym["putchar_stdout"] && u_axi_ram.mem_strb[0] == '1 && u_axi_ram.mem_we == '1 && u_axi_ram.mem_req == '1) begin
          if (u_axi_ram.mem_wdata[0] == "\n") begin
            $display("\033[1;33mSTDOUT         : %s\033[0m [%0t]", prints, $realtime);
            prints = "";
          end else begin
            $sformat(prints, "%s%c", prints, u_axi_ram.mem_wdata[0]);
          end
        end
      end
    join_none
  endtask

  function automatic bit [63:0] get_gpr(input [4:0] index);
    return ariane_tb.u_core.issue_stage_i.i_issue_read_operands.i_ariane_regfile.mem[index];
  endfunction

  function automatic void set_gpr(input [4:0] index, input bit [63:0] data);
    if (index != 0)
      ariane_tb.u_core.issue_stage_i.i_issue_read_operands.i_ariane_regfile.mem[index] = data;
  endfunction

  // Task to wait for the test to exit and check the exit code
  task static wait_exit();
    longint exit_code;
    forever begin
      @(posedge clk);
      if (u_axi_ram.addr_out == sym["tohost"] && u_axi_ram.mem_strb == '1 && u_axi_ram.mem_we == '1 && u_axi_ram.mem_req == '1) begin
        exit_code = u_axi_ram.mem_wdata;
        break;
      end
    end
    $display("\033[0;35mEXIT CODE      : 0x%08x\033[0m", exit_code);

    for (int i = 0; i < 32; i++) begin
      string GPR_CHK;
      string GPR_VAL;
      $sformat(GPR_CHK, "GPR%02d_CHECK", i);
      $sformat(GPR_VAL, "GPR%02d_VALUE", i);
      if (u_axi_ram.read_mem_d(sym[GPR_CHK])) begin
        if (u_axi_ram.read_mem_d(sym[GPR_VAL]) != get_gpr(i)) begin
          exit_code = 1;
          $display("\033[1;31mGPR%02d EXP:0x%16h GOT:0x%16h\033[0m", i, u_axi_ram.read_mem_d(
                   sym[GPR_VAL]), get_gpr(i));
        end
      end
    end

    if (exit_code == 0) $display("\033[1;32m************** TEST PASSED **************\033[0m");
    else $display("\033[1;31m************** TEST FAILED **************\033[0m");
  endtask

  initial begin

    // Set time format to microseconds
    $timeformat(-6, 3, "us");

    if ($test$plusargs("DEBUG")) begin
      $display("\033[1;33m###### DEBUG ENABLED ######\033[0m");

      // Dump VCD file
      $dumpfile("prog.vcd");
      $dumpvars(0, ariane_tb);
    end

    // Load simulation memory and symbols
    load_memory("prog.hex");
    load_symbols("prog.sym");

    // Set boot address to the start of the program
    boot_addr <= sym["_start"];

    $display("\033[0;35mBOOTADDR       : 0x%08x\033[0m", sym["_start"]);
    $display("\033[0;35mTOHOSTADDR     : 0x%08x\033[0m", sym["tohost"]);
    $display("\033[0;35mPUTCHAR_STDOUT : 0x%08x\033[0m", sym["putchar_stdout"]);

    // Monitor STDOUT prints
    monitor_prints();

    // Apply reset and start clock
    apply_reset();
    start_clock();

    // Wait for the test to exit
    wait_exit();

    // Finish simulation after 100ns
    $finish;

  end

  initial begin
    #25ms;
    $fatal(1, "Simulation timeout after 1ms");
  end

endmodule
