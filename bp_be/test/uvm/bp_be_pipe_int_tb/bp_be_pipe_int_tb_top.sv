`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "uvm_macros.svh"

import uvm_pkg::*;
import bp_common_pkg::*;
import bp_be_pkg::*;

`include "bp_be_pipe_int_if.sv"
`include "bp_be_pipe_int_transaction.sv"
`include "bp_be_pipe_int_driver.sv"
`include "bp_be_pipe_int_monitor.sv"
`include "bp_be_pipe_int_scoreboard.sv"
`include "bp_be_pipe_int_sequence.sv"
`include "bp_be_pipe_int_agent.sv"
`include "bp_be_pipe_int_env.sv"
`include "bp_be_pipe_int_test.sv"

module bp_be_pipe_int_tb_top;

  localparam vaddr_width_p        = 39;
  localparam int_rec_width_p      = 65;
  localparam dpath_width_p        = 64;
  localparam reservation_width_p  = 512;

  // Clock
  logic clk;
  initial clk = 0;
  always #5 clk = ~clk;

  // Interface
  bp_be_pipe_int_if
   #(.vaddr_width_p       (vaddr_width_p)
    ,.int_rec_width_p     (int_rec_width_p)
    ,.dpath_width_p       (dpath_width_p)
    ,.reservation_width_p (reservation_width_p)
    )
   pipe_int_if(.clk_i(clk));

  // DUT
  bp_be_pipe_int
   #(.bp_params_p(e_bp_default_cfg))
   dut
    (.clk_i               (clk)
    ,.reset_i             (pipe_int_if.reset_i)
    ,.en_i                (pipe_int_if.en_i)
    ,.reservation_i       (pipe_int_if.reservation_i)
    ,.flush_i             (pipe_int_if.flush_i)
    ,.data_o              (pipe_int_if.data_o)
    ,.v_o                 (pipe_int_if.v_o)
    ,.branch_o            (pipe_int_if.branch_o)
    ,.btaken_o            (pipe_int_if.btaken_o)
    ,.npc_o               (pipe_int_if.npc_o)
    ,.instr_misaligned_v_o(pipe_int_if.instr_misaligned_v_o)
    );

  initial begin
    // Wait for clock to stabilize before starting UVM
    @(posedge clk);
    @(posedge clk);
    uvm_config_db #(virtual bp_be_pipe_int_if)::set(
      null, "uvm_test_top.*", "vif", pipe_int_if);
    run_test();
  end

  initial begin
    #1_000_000;
    `uvm_fatal("TIMEOUT", "Simulation exceeded 1ms")
  end

endmodule
