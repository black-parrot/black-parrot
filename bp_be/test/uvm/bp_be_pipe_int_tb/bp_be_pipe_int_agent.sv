/**
 * bp_be_pipe_int_agent.sv
 * UVM agent for bp_be_pipe_int testbench.
 * Bundles the sequencer, driver, and monitor into one reusable unit.
 */
`ifndef BP_BE_PIPE_INT_AGENT_SV
`define BP_BE_PIPE_INT_AGENT_SV

class bp_be_pipe_int_agent extends uvm_agent;
  `uvm_component_utils(bp_be_pipe_int_agent)

  // Sub-components
  uvm_sequencer #(bp_be_pipe_int_transaction) sequencer;
  bp_be_pipe_int_driver                       driver;
  bp_be_pipe_int_monitor                      monitor;

  // Analysis port forwarded from monitor (scoreboard connects here)
  uvm_analysis_port #(bp_be_pipe_int_output_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap        = new("ap", this);
    sequencer = uvm_sequencer #(bp_be_pipe_int_transaction)::type_id
                  ::create("sequencer", this);
    driver    = bp_be_pipe_int_driver::type_id::create("driver",  this);
    monitor   = bp_be_pipe_int_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    // Driver gets items from sequencer
    driver.seq_item_port.connect(sequencer.seq_item_export);
    // Forward monitor analysis port upward
    monitor.ap.connect(ap);
  endfunction

endclass
`endif
