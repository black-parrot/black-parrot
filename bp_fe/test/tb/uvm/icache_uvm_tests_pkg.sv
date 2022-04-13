// Devin Bidstrup 2022
// UVM Tests for BP L1 ICache Testbench

`ifndef ICACHE_TESTS_PKG
`define ICACHE_TESTS_PKG

`include "icache_uvm_cfg_pkg.sv"
`include "icache_uvm_comp_pkg.sv"
`include "icache_uvm_seq_pkg.sv"
`include "uvm_macros.svh"

package icache_uvm_tests_pkg;

  import uvm_pkg::*;
  import icache_uvm_cfg_pkg::*;
  import icache_uvm_comp_pkg::*;
  import icache_uvm_seq_pkg::*;

  //.......................................................
  // Base Test
  //.......................................................
  class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    
    virtual input_icache_if icache_input_if_h;
    virtual tlb_icache_if icache_tlb_if_h;
    virtual output_icache_if icache_output_if_h;
    virtual ce_icache_if icache_ce_if_h;

    bit input_is_active = 1'b1;
    bit tlb_is_active = 1'b0;
    bit output_is_active = 1'b0;
    bit ce_is_active = 1'b0;
    
    base_env   base_env_h;
    env_config env_cfg;

    myvseq_base myvseq_h;
  
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
      env_cfg.input_is_active  = input_is_active;
      env_cfg.tlb_is_active    = tlb_is_active;
      env_cfg.output_is_active = output_is_active;
      env_cfg.ce_is_active     = ce_is_active;
      
      // Pass configuration information to the enviornment
      uvm_config_db#(env_config)::set(this, "*", "env_config", env_cfg);
    endfunction: build_phase
    
    function void init_vseq(myvseq_base vseq);
      `uvm_info("init_vseq", "Initializing", UVM_NONE);
      myvseq_h.input_sequencer_h = base_env_h.input_agent_h.input_sequencer_h;
      myvseq_h.tlb_sequencer_h = base_env_h.tlb_agent_h.tlb_sequencer_h;
      myvseq_h.output_sequencer_h = base_env_h.output_agent_h.output_sequencer_h;
      myvseq_h.ce_sequencer_h = base_env_h.ce_agent_h.ce_sequencer_h;
    endfunction: init_vseq

    virtual function void end_of_elaboration_phase (uvm_phase phase);
      myvseq_h = myvseq_base::type_id::create("myvseq_h");
      init_vseq(myvseq_h);
    endfunction

    virtual function void start_of_simulation_phase (uvm_phase phase);
      uvm_top.print_topology();
    endfunction: start_of_simulation_phase

    virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this, "Starting Sequences");

      phase.get_objection().display_objections(null, 1);

      `uvm_info("base_test", "Starting virtual test sequence", UVM_HIGH);
      myvseq_h.start(null);
      `uvm_info("base_test", "Stopping test sequence", UVM_HIGH);
      
      phase.phase_done.set_drain_time(this, 20ns);
      phase.drop_objection(this, "Finished sequences");
    endtask: run_phase
  endclass: base_test

  class test_load extends base_test;
    `uvm_component_utils(test_load)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new
    
    function void build_phase(uvm_phase phase);
      tlb_is_active = 1'b1;
      super.build_phase(phase);
      myvseq_base::type_id::set_type_override(test_load_vseq::get_type());
    endfunction: build_phase
  endclass: test_load

  class test_uncached_load extends base_test;
    `uvm_component_utils(test_uncached_load)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      tlb_is_active = 1'b1;
      super.build_phase(phase);
      myvseq_base::type_id::set_type_override(test_uncached_load_vseq::get_type());
    endfunction: build_phase
  endclass: test_uncached_load
endpackage: icache_uvm_tests_pkg
`endif
