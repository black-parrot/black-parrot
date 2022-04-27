// Devin Bidstrup 2022
// UVM Config Objects for BP L1 ICache Testbench

`ifndef ICACHE_CFG_PKG
`define ICACHE_CFG_PKG

`include "uvm_macros.svh"

package icache_uvm_cfg_pkg;

  import uvm_pkg::*;

  //.......................................................
  // Agent
  //.......................................................
  class input_agt_config extends uvm_object;
    `uvm_object_utils(input_agt_config)

    //Config parameteres
    virtual input_icache_if icache_if_h;

    function new (string name = "");
      super.new(name);
    endfunction
  endclass : input_agt_config

  class tlb_agt_config extends uvm_object;
    `uvm_object_utils(tlb_agt_config)

    //Config parameteres
    virtual tlb_icache_if icache_if_h;

    function new (string name = "");
      super.new(name);
    endfunction
  endclass : tlb_agt_config

  class output_agt_config extends uvm_object;
    `uvm_object_utils(output_agt_config)

    //Config parameteres
    virtual output_icache_if icache_if_h;

    function new (string name = "");
      super.new(name);
    endfunction
  endclass : output_agt_config

  class ce_agt_config extends uvm_object;
    `uvm_object_utils(ce_agt_config)

    //Config parameteres
    virtual ce_icache_if icache_if_h;

    function new (string name = "");
      super.new(name);
    endfunction
  endclass : ce_agt_config

  //.......................................................
  // Environment
  //.......................................................
  class env_config extends uvm_object;
    `uvm_object_utils(env_config)

    //Config parameteres
    virtual input_icache_if  #() icache_input_if_h;
    virtual tlb_icache_if    #() icache_tlb_if_h;
    virtual output_icache_if #() icache_output_if_h;
    virtual ce_icache_if     #() icache_ce_if_h;
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

