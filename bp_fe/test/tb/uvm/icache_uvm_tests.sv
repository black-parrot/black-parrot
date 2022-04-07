// Devin Bidstrup 2022
// UVM Tests for BP L1 ICache Testbench

`ifndef ICACHE_TESTS_PKG
`define ICACHE_TESTS_PKG

`include "icache_uvm_cfg_pkg.sv"
`include "icache_uvm_comp.sv"
`include "icache_uvm_seq.sv"
//import icache_uvm_cfg_pkg::*;

`include "uvm_macros.svh"
//import uvm_pkg::*;

//.......................................................
// Base Test
//.......................................................
class base_test extends uvm_test;

  `uvm_component_utils(base_test)
  
  virtual input_icache_if icache_input_if_h;
  virtual tlb_icache_if icache_tlb_if_h;
  virtual output_icache_if icache_output_if_h;
  virtual ce_icache_if icache_ce_if_h;
  
  base_env   base_env_h;
  env_config env_cfg;
 
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction: new
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    base_env_h = base_env::type_id::create("base_env_h", this);
    
    // Get interface virtual handles from top
    env_cfg = env_config::type_id::create("env_cfg");
    if(!(uvm_config_db#(virtual input_icache_if)::get(this, "", "dut_input_vi", env_cfg.icache_input_if_h) &&
         uvm_config_db#(virtual tlb_icache_if)::get(this, "", "dut_tlb_vi", env_cfg.icache_tlb_if_h) &&
         uvm_config_db#(virtual output_icache_if)::get(this, "", "dut_output_vi", env_cfg.icache_output_if_h) &&
         uvm_config_db#(virtual ce_icache_if)::get(this, "", "dut_ce_vi", env_cfg.icache_ce_if_h)))
     `uvm_fatal("NO_CFG", "No virtual interface set")

    //Define agent activity for each interface
    env_cfg.input_is_active  = 1'b1;
    env_cfg.tlb_is_active    = 1'b0;
    env_cfg.output_is_active = 1'b0;
    env_cfg.ce_is_active     = 1'b0;
    
    // Pass configuration information to the enviornment
    uvm_config_db#(env_config)::set(this, "*", "env_config", env_cfg);
  endfunction: build_phase
  
  task run_phase(uvm_phase phase);
    seq_of_commands seq1;
    phase.raise_objection(this, "Starting Sequences");
    `uvm_info("test", "Starting seq of commands", UVM_HIGH);
    seq1 = seq_of_commands::type_id::create("seq1");
    assert( seq1.randomize() );
    seq1.start( base_env_h.input_agent_h.my_sequencer_h);
    phase.drop_objection(this, "Finished sequences");
  endtask: run_phase
  
endclass: base_test
`endif
