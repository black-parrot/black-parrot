/**
 * bp_be_pipe_int_env.sv
 * UVM environment for bp_be_pipe_int testbench.
 * Instantiates agent and scoreboard and wires them together.
 */
`ifndef BP_BE_PIPE_INT_ENV_SV
`define BP_BE_PIPE_INT_ENV_SV

class bp_be_pipe_int_env extends uvm_env;
  `uvm_component_utils(bp_be_pipe_int_env)

  bp_be_pipe_int_agent      agent;
  bp_be_pipe_int_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = bp_be_pipe_int_agent::type_id::create("agent", this);
    scoreboard = bp_be_pipe_int_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    // Monitor output -> scoreboard
    agent.ap.connect(scoreboard.analysis_export);
  endfunction

endclass
`endif
