import ariane_pkg::*;module lsu_bypass (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,

    input lsu_ctrl_t lsu_req_i,
    input logic      lus_req_valid_i,
    input logic      pop_ld_i,
    input logic      pop_st_i,

    output lsu_ctrl_t lsu_ctrl_o,
    output logic      ready_o
);

  lsu_ctrl_t [1:0] mem_n, mem_q;
  logic read_pointer_n, read_pointer_q;
  logic write_pointer_n, write_pointer_q;
  logic [1:0] status_cnt_n, status_cnt_q;

  logic empty;
  assign empty   = (status_cnt_q == 0);
  assign ready_o = empty;

  always_comb begin
    automatic logic [1:0] status_cnt;
    automatic logic write_pointer;
    automatic logic read_pointer;

    status_cnt = status_cnt_q;
    write_pointer = write_pointer_q;
    read_pointer = read_pointer_q;

    mem_n = mem_q;

    if (lus_req_valid_i) begin
      mem_n[write_pointer_q] = lsu_req_i;
      write_pointer++;
      status_cnt++;
    end

    if (pop_ld_i) begin

      mem_n[read_pointer_q].valid = 1'b0;
      read_pointer++;
      status_cnt--;
    end

    if (pop_st_i) begin

      mem_n[read_pointer_q].valid = 1'b0;
      read_pointer++;
      status_cnt--;
    end

    if (pop_st_i && pop_ld_i) foreach (mem_n[i]) mem_n[i] = lsu_ctrl_t'('0);

    if (flush_i) begin
      status_cnt = '0;
      write_pointer = '0;
      read_pointer = '0;
      foreach (mem_n[i]) mem_n[i] = lsu_ctrl_t'('0);
    end

    read_pointer_n  = read_pointer;
    write_pointer_n = write_pointer;
    status_cnt_n    = status_cnt;
  end

  always_comb begin : output_assignments
    if (empty) begin
      lsu_ctrl_o = lsu_req_i;
    end else begin
      lsu_ctrl_o = mem_q[read_pointer_q];
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      foreach (mem_q[i]) mem_q[i] <= lsu_ctrl_t'('0);
      status_cnt_q    <= '0;
      write_pointer_q <= '0;
      read_pointer_q  <= '0;
    end else begin
      mem_q           <= mem_n;
      status_cnt_q    <= status_cnt_n;
      write_pointer_q <= write_pointer_n;
      read_pointer_q  <= read_pointer_n;
    end
  end
endmodule

