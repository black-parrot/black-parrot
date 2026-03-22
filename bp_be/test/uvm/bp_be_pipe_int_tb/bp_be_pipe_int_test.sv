/**
 * bp_be_pipe_int_test.sv
 * UVM test classes for bp_be_pipe_int testbench.
 * Four tests:
 *   1. bp_be_pipe_int_rand_test   - fully random
 *   2. bp_be_pipe_int_alu_test    - walks all ALU ops
 *   3. bp_be_pipe_int_branch_test - branch/jump coverage
 *   4. bp_be_pipe_int_flush_test  - flush behaviour
 */
`ifndef BP_BE_PIPE_INT_TEST_SV
`define BP_BE_PIPE_INT_TEST_SV

//--------------------------------------------------------------------
// Base test
//--------------------------------------------------------------------
class bp_be_pipe_int_base_test extends uvm_test;
  `uvm_component_utils(bp_be_pipe_int_base_test)

  bp_be_pipe_int_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = bp_be_pipe_int_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_test_body(phase);
    #100; // drain time
    phase.drop_objection(this);
  endtask

  // Override in child tests
  virtual task run_test_body(uvm_phase phase);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server srv = uvm_report_server::get_server();
    if (srv.get_severity_count(UVM_ERROR) > 0) begin
      `uvm_info("TEST", "** TEST FAILED **", UVM_NONE)
    end else begin
      `uvm_info("TEST", "** TEST PASSED **", UVM_NONE)
    end
  endfunction

endclass

//--------------------------------------------------------------------
// 1. Random test
//--------------------------------------------------------------------
class bp_be_pipe_int_rand_test extends bp_be_pipe_int_base_test;
  `uvm_component_utils(bp_be_pipe_int_rand_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body(uvm_phase phase);
    bp_be_pipe_int_rand_seq seq;
    seq = bp_be_pipe_int_rand_seq::type_id::create("seq");
    seq.num_transactions = 500;
    seq.start(env.agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------
// 2. ALU op coverage test
//--------------------------------------------------------------------
class bp_be_pipe_int_alu_test extends bp_be_pipe_int_base_test;
  `uvm_component_utils(bp_be_pipe_int_alu_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body(uvm_phase phase);
    bp_be_pipe_int_alu_seq seq;
    seq = bp_be_pipe_int_alu_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------
// 3. Branch/jump test
//--------------------------------------------------------------------
class bp_be_pipe_int_branch_test extends bp_be_pipe_int_base_test;
  `uvm_component_utils(bp_be_pipe_int_branch_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body(uvm_phase phase);
    bp_be_pipe_int_branch_seq seq;
    seq = bp_be_pipe_int_branch_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
  endtask
endclass

//--------------------------------------------------------------------
// 4. Flush test
//--------------------------------------------------------------------
class bp_be_pipe_int_flush_test extends bp_be_pipe_int_base_test;
  `uvm_component_utils(bp_be_pipe_int_flush_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body(uvm_phase phase);
    bp_be_pipe_int_flush_seq seq;
    seq = bp_be_pipe_int_flush_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);
  endtask
endclass

`endif
