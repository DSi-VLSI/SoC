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
      .DmBaseAddress(soc_pkg::DM_BASE_ADDR),
      .CachedAddrBeg(soc_pkg::CACHEABLE_ADDR_START)
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
      .MEM_BASE(soc_pkg::RAM_BASE),
      .MEM_SIZE(soc_pkg::RAM_SIZE),
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
    $readmemh(filename, u_axi_ram.u_mem.g_vip.mem);
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

  initial begin

    // Set time format to microseconds
    $timeformat(-6, 3, "us");
    $dumpfile("prog.vcd");
    $dumpvars(0, ariane_tb);

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

    // Apply reset and start clock
    apply_reset();
    start_clock();

    // Wait for the test to exit
    // wait_exit();

    // Finish simulation after 100ns
    #1000ns $finish;

  end

endmodule
