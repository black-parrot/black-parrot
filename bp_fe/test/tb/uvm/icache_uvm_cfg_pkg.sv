// Devin Bidstrup 2022
// UVM Config Objects for BP L1 ICache Testbench

`ifndef ICACHE_CFG_PKG
`define ICACHE_CFG_PKG
package icache_uvm_cfg_pkg;

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  
  // Lists all of the interfaces
  typedef enum {INPUT, TLB, OUTPUT, CE} vif_type;
  
  //.......................................................
  // Agent
  //.......................................................
  class agt_config extends uvm_object;
    `uvm_object_utils(agt_config)

    //Config parameteres
    virtual icache_if icache_if_h;
    vif_type chosen_if;
    
    function new (string name = "");
      super.new(name);
    endfunction
  endclass : agt_config
  
  //.......................................................
  // Environment
  //.......................................................
  class env_config extends uvm_object;
    `uvm_object_utils(env_config)

    //Config parameteres
    virtual icache_if #(INPUT)  icache_input_if_h;
    virtual icache_if #(TLB)    icache_tlb_if_h;
    virtual icache_if #(OUTPUT) icache_output_if_h;
    virtual icache_if #(CE)     icache_ce_if_h;
    int              input_is_active;
    int              tlb_is_active;
    int              output_is_active;
    int              ce_is_active;
    
    function new (string name = "");
      super.new(name);
    endfunction

  endclass : env_config
  
endpackage : icache_uvm_cfg_pkg
`endif
