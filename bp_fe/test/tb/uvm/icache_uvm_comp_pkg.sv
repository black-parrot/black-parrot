// Devin Bidstrup 2022
// UVM Environment Components for BP L1 ICache Testbench

`ifndef ICACHE_COMP_PKG
`define ICACHE_COMP_PKG

`include "icache_uvm_seq_pkg.sv"
`include "icache_uvm_cfg_pkg.sv"
`include "icache_uvm_subs_pkg.sv"
`include "uvm_macros.svh"

package icache_uvm_comp_pkg;

  import uvm_pkg::*;
  import icache_uvm_cfg_pkg::*;
  import icache_uvm_seq_pkg::*;
  import icache_uvm_subs_pkg::*;

  //.......................................................
  // Driver
  //.......................................................
  class input_driver extends uvm_driver #(input_transaction);

    `uvm_component_utils(input_driver)

    virtual input_icache_if dut_vi;
    input_agt_config input_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      input_agt_cfg = input_agt_config::type_id::create("input_agt_cfg");
      if(!uvm_config_db#(input_agt_config)::get(this, "", "input_agt_config", input_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in input_driver")
      dut_vi = input_agt_cfg.icache_if_h;
    endfunction : build_phase

    // Main Phase, takes sequences and drives them
    task run_phase(uvm_phase phase);
      input_transaction tx;
      
      #10
      wait(dut_vi.reset_i == 1'b0);

      forever begin
        seq_item_port.get_next_item(tx);

         @(posedge dut_vi.clk_i);

        // Wait for consumer(cache) to be ready
        // wait(dut_vi.ready_o == 1'b1);

        // Send packet
        dut_vi.icache_pkt_i = tx.icache_pkt_i;
        dut_vi.v_i          = tx.v_i;

        // Copy for printing and print
        tx.clk_i = dut_vi.clk_i;
        tx.reset_i = dut_vi.reset_i;
        tx.ready_o = dut_vi.ready_o;
        `uvm_info(get_type_name(), $psprintf("input driver sending tx %s", tx.convert2string()), UVM_HIGH);

        // Indicate we have finished packet to sequencer
        seq_item_port.item_done();
      end
    endtask: run_phase

  endclass: input_driver

  class tlb_driver extends uvm_driver #(tlb_transaction);

    `uvm_component_utils(tlb_driver)

    virtual tlb_icache_if dut_vi;
    tlb_agt_config tlb_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      tlb_agt_cfg = tlb_agt_config::type_id::create("tlb_agt_cfg");
      if(!uvm_config_db#(tlb_agt_config)::get(this, "", "tlb_agt_config", tlb_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in tlb_driver")
      dut_vi = tlb_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      tlb_transaction tx;
      tlb_transaction tx_prev[$];

      //Init empty queue item
      tx = tlb_transaction::type_id::create("tx");
      tx.ptag_i = '0;
      tx.ptag_v_i = 1'b0;
      tx.ptag_uncached_i = 1'b0;
      tx.ptag_dram_i = 1'b0;
      tx.ptag_nonidem_i = 1'b0;
      tx_prev.push_back(tx);
      
      //Wait for reset signal to go low
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      //Drive
      forever
      begin
        seq_item_port.get_next_item(tx);
        tx_prev.push_back(tx);
        tx = tx_prev.pop_front();

        @(posedge dut_vi.clk_i);

        dut_vi.ptag_i           = tx.ptag_i;
        dut_vi.ptag_v_i 	      = tx.ptag_v_i;
        dut_vi.ptag_uncached_i  = tx.ptag_uncached_i;
        dut_vi.ptag_dram_i      = tx.ptag_dram_i;
        dut_vi.ptag_nonidem_i   = tx.ptag_nonidem_i;

        `uvm_info("driver", $psprintf("tlb driver sending tx %s", tx.convert2string()), UVM_HIGH);
        seq_item_port.item_done();
      end
    endtask: run_phase

  endclass: tlb_driver

  class output_driver extends uvm_driver #(output_transaction);

    `uvm_component_utils(output_driver)

    virtual output_icache_if dut_vi;
    output_agt_config output_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      output_agt_cfg = output_agt_config::type_id::create("output_agt_cfg");
      if(!uvm_config_db#(output_agt_config)::get(this, "", "output_agt_config", output_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in output_driver")
      dut_vi = output_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      forever
      begin
        output_transaction tx;

        @(posedge dut_vi.clk_i);
        seq_item_port.get(tx);

        dut_vi.data_o   = tx.data_o;
        dut_vi.data_v_o = tx.data_v_o;
        dut_vi.miss_v_o  = tx.miss_v_o;

        `uvm_info(get_type_name(), $psprintf("output driver sending tx %s", tx.convert2string()), UVM_HIGH);
        seq_item_port.item_done();
      end
    endtask: run_phase

  endclass: output_driver

  class ce_driver extends uvm_driver #(ce_transaction);

    `uvm_component_utils(ce_driver)
    
    virtual ce_icache_if dut_vi;
    ce_agt_config ce_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      ce_agt_cfg = ce_agt_config::type_id::create("ce_agt_cfg");
      if(!uvm_config_db#(ce_agt_config)::get(this, "", "ce_agt_config", ce_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in ce_driver")
      dut_vi = ce_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      forever
      begin
        ce_transaction tx;

        @(posedge dut_vi.clk_i);
        seq_item_port.get(tx);

        dut_vi.cache_req_o              = tx.cache_req_o;
        dut_vi.cache_req_v_o            = tx.cache_req_v_o;
        dut_vi.cache_req_yumi_i         = tx.cache_req_yumi_i;
        dut_vi.cache_req_busy_i         = tx.cache_req_busy_i;
        dut_vi.cache_req_metadata_o     = tx.cache_req_metadata_o;
        dut_vi.cache_req_metadata_v_o   = tx.cache_req_metadata_v_o;
        dut_vi.cache_req_critical_tag_i = tx.cache_req_critical_tag_i;
        dut_vi.cache_req_complete_i     = tx.cache_req_complete_i;
        dut_vi.cache_req_credits_full_i = tx.cache_req_credits_full_i;
        dut_vi.cache_req_credits_empty_i= tx.cache_req_credits_empty_i;

        `uvm_info(get_type_name(), $psprintf("ce driver sending tx %s", tx.convert2string()), UVM_HIGH);
        seq_item_port.item_done();
      end
    endtask: run_phase

  endclass: ce_driver

  //.......................................................
  // Monitor
  //.......................................................
  class input_monitor extends uvm_monitor;

    `uvm_component_utils(input_monitor)

    uvm_analysis_port #(input_transaction) aport;

    virtual input_icache_if dut_vi;
    input_agt_config input_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      aport = new("aport", this);

      input_agt_cfg = input_agt_config::type_id::create("input_agt_cfg");
      if(!uvm_config_db#(input_agt_config)::get(this, "", "input_agt_config", input_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in input_monitor")
      dut_vi = input_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      forever begin
        input_transaction tx;

        @(posedge dut_vi.clk_i);
        if (dut_vi.v_i === 1'b1) begin
          tx = input_transaction::type_id::create("tx");

          tx.icache_pkt_i     = dut_vi.icache_pkt_i;
          tx.v_i              = dut_vi.v_i;
          tx.ready_o          = dut_vi.ready_o;
          tx.reset_i          = dut_vi.reset_i;
          tx.clk_i            = dut_vi.clk_i;

          `uvm_info(get_type_name(), $psprintf("monitor sending tx %s", tx.convert2string()), UVM_HIGH);

          aport.write(tx);
        end
      end
    endtask: run_phase
  endclass: input_monitor

  class tlb_monitor extends uvm_monitor;

    `uvm_component_utils(tlb_monitor)

    uvm_analysis_port #(tlb_transaction) aport;

    virtual tlb_icache_if dut_vi;
    tlb_agt_config tlb_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      aport = new("aport", this);

      tlb_agt_cfg = tlb_agt_config::type_id::create("tlb_agt_cfg");
      if(!uvm_config_db#(tlb_agt_config)::get(this, "", "tlb_agt_config", tlb_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in tlb_monitor")
      dut_vi = tlb_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      forever
      begin
        tlb_transaction tx;

        @(posedge dut_vi.clk_i);
        if (dut_vi.ptag_v_i === 1'b1) begin
          tx = tlb_transaction::type_id::create("tx");

          tx.ptag_i           = dut_vi.ptag_i;
          tx.ptag_v_i 	      = dut_vi.ptag_v_i;
          tx.ptag_uncached_i  = dut_vi.ptag_uncached_i;
          tx.ptag_dram_i      = dut_vi.ptag_dram_i;
          tx.ptag_nonidem_i   = dut_vi.ptag_nonidem_i;

          `uvm_info(get_type_name(), $psprintf("monitor sending tx %s", tx.convert2string()), UVM_HIGH);

          aport.write(tx);
        end
      end
    endtask: run_phase

  endclass: tlb_monitor

  class output_monitor extends uvm_monitor;

    `uvm_component_utils(output_monitor)

    uvm_analysis_port #(output_transaction) aport;

    virtual output_icache_if dut_vi;
    output_agt_config output_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      aport = new("aport", this);

      output_agt_cfg = output_agt_config::type_id::create("output_agt_cfg");
      if(!uvm_config_db#(output_agt_config)::get(this, "", "output_agt_config", output_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in output_monitor")
      dut_vi = output_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      forever
      begin
        output_transaction tx;

        @(posedge dut_vi.clk_i);
        tx = output_transaction::type_id::create("tx");

        tx.data_o   = dut_vi.data_o;
        tx.data_v_o = dut_vi.data_v_o;
        tx.miss_v_o  = dut_vi.miss_v_o;

        `uvm_info(get_type_name(), $psprintf("monitor sending tx %s", tx.convert2string()), (dut_vi.data_v_o) ? UVM_LOW : UVM_MEDIUM);

        aport.write(tx);
      end
    endtask: run_phase

  endclass: output_monitor

  class ce_monitor extends uvm_monitor;

    `uvm_component_utils(ce_monitor)

    uvm_analysis_port #(ce_transaction) aport;

    virtual ce_icache_if dut_vi;
    ce_agt_config ce_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      aport = new("aport", this);

      ce_agt_cfg = ce_agt_config::type_id::create("ce_agt_cfg");
      if(!uvm_config_db#(ce_agt_config)::get(this, "", "ce_agt_config", ce_agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set in ce_monitor")
      dut_vi = ce_agt_cfg.icache_if_h;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
      
      #10
      wait(dut_vi.reset_i == 1'b0);
      
      forever
      begin
        ce_transaction tx;

        @(posedge dut_vi.clk_i);
        if (dut_vi.cache_req_v_o === 1'b1) begin
          tx = ce_transaction::type_id::create("tx");

          tx.cache_req_o              = dut_vi.cache_req_o;
          tx.cache_req_v_o            = dut_vi.cache_req_v_o;
          tx.cache_req_yumi_i         = dut_vi.cache_req_yumi_i;
          tx.cache_req_busy_i         = dut_vi.cache_req_busy_i;
          tx.cache_req_metadata_o     = dut_vi.cache_req_metadata_o;
          tx.cache_req_metadata_v_o   = dut_vi.cache_req_metadata_v_o;
          tx.cache_req_critical_tag_i = dut_vi.cache_req_critical_tag_i;
          tx.cache_req_complete_i     = dut_vi.cache_req_complete_i;
          tx.cache_req_credits_full_i = dut_vi.cache_req_credits_full_i;
          tx.cache_req_credits_empty_i= dut_vi.cache_req_credits_empty_i;

          `uvm_info(get_type_name(), $psprintf("monitor sending tx %s", tx.convert2string()), UVM_HIGH);

          aport.write(tx);
        end
      end
    endtask: run_phase

  endclass: ce_monitor

  //.......................................................
  // Agent
  //.......................................................
  class input_agent extends uvm_agent;

    `uvm_component_utils(input_agent)

    uvm_analysis_port #(input_transaction) aport;

    input_sequencer input_sequencer_h;
    input_driver    input_driver_h;
    input_monitor   input_monitor_h;
    
    input_agt_config   agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // Get and pass configuration information from test to the agent
      agt_cfg = input_agt_config::type_id::create("agt_cfg");
      if(!uvm_config_db#(input_agt_config)::get(this, "", "input_agt_config", agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set")

      // If Agent is Active, create Driver and Sequencer, else skip
      `uvm_info("agent", (get_is_active()) ? "input agent is active" : "input agent is not active", UVM_HIGH);
      if (get_is_active()) begin
        input_sequencer_h  = input_sequencer::type_id::create("input_sequencer_h", this);
        input_driver_h     = input_driver::type_id::create("input_driver_h", this);
      end

      aport = new("aport", this);
      input_monitor_h = input_monitor::type_id::create("input_monitor_h", this); 
      uvm_config_db#(input_agt_config)::set(this, "*", "input_agt_config", agt_cfg);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
      if (get_is_active()) begin
        input_driver_h.seq_item_port.connect( input_sequencer_h.seq_item_export );
      end
      input_monitor_h.aport.connect( this.aport );
    endfunction: connect_phase
  endclass: input_agent

  class tlb_agent extends uvm_agent;

    `uvm_component_utils(tlb_agent)

    uvm_analysis_port #(tlb_transaction) aport;

    tlb_sequencer tlb_sequencer_h;
    tlb_driver    tlb_driver_h;
    tlb_monitor   tlb_monitor_h;
    
    tlb_agt_config   agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // Get and pass configuration information from test to the agent
      agt_cfg = tlb_agt_config::type_id::create("agt_cfg");
      if(!uvm_config_db#(tlb_agt_config)::get(this, "", "tlb_agt_config", agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set")

      // If Agent is Active, create Driver and Sequencer, else skip
      `uvm_info("agent", (get_is_active()) ? "tlb agent is active" : "tlb agent is not active", UVM_HIGH);
      if (get_is_active()) begin
        tlb_sequencer_h  = tlb_sequencer::type_id::create("tlb_sequencer_h", this);
        tlb_driver_h     = tlb_driver::type_id::create("tlb_driver_h", this);
      end

      aport = new("aport", this);
      tlb_monitor_h = tlb_monitor::type_id::create("tlb_monitor_h", this); 
      uvm_config_db#(tlb_agt_config)::set(this, "*", "tlb_agt_config", agt_cfg);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
      if (get_is_active()) begin
        tlb_driver_h.seq_item_port.connect( tlb_sequencer_h.seq_item_export );
      end
      tlb_monitor_h.aport.connect( this.aport );
    endfunction: connect_phase
  endclass: tlb_agent

  class output_agent extends uvm_agent;

    `uvm_component_utils(output_agent)

    uvm_analysis_port #(output_transaction) aport;

    output_sequencer output_sequencer_h;
    output_driver    output_driver_h;
    output_monitor   output_monitor_h;
    
    output_agt_config   agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // Get and pass configuration information from test to the agent
      agt_cfg = output_agt_config::type_id::create("agt_cfg");
      if(!uvm_config_db#(output_agt_config)::get(this, "", "output_agt_config", agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set")

      // If Agent is Active, create Driver and Sequencer, else skip
      `uvm_info("agent", (get_is_active()) ? "output agent is active" : "output agent is not active", UVM_HIGH);
      if (get_is_active()) begin
        output_sequencer_h  = output_sequencer::type_id::create("output_sequencer_h", this);
        output_driver_h     = output_driver::type_id::create("output_driver_h", this);
      end

      aport = new("aport", this);
      output_monitor_h = output_monitor::type_id::create("output_monitor_h", this); 
      uvm_config_db#(output_agt_config)::set(this, "*", "output_agt_config", agt_cfg);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
      if (get_is_active()) begin
        output_driver_h.seq_item_port.connect( output_sequencer_h.seq_item_export );
      end
      output_monitor_h.aport.connect( this.aport );
    endfunction: connect_phase
  endclass: output_agent

  class ce_agent extends uvm_agent;

    `uvm_component_utils(ce_agent)

    uvm_analysis_port #(ce_transaction) aport;

    ce_sequencer ce_sequencer_h;
    ce_driver    ce_driver_h;
    ce_monitor   ce_monitor_h;
    
    ce_agt_config   agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // Get and pass configuration information from test to the agent
      agt_cfg = ce_agt_config::type_id::create("agt_cfg");
      if(!uvm_config_db#(ce_agt_config)::get(this, "", "ce_agt_config", agt_cfg))
        `uvm_fatal("NO_CFG", "No agent config set")

      // If Agent is Active, create Driver and Sequencer, else skip
      `uvm_info("agent", (get_is_active()) ? "ce agent is active" : "ce agent is not active", UVM_HIGH);
      if (get_is_active()) begin
        ce_sequencer_h  = ce_sequencer::type_id::create("ce_sequencer_h", this);
        ce_driver_h     = ce_driver::type_id::create("ce_driver_h", this);
      end

      aport = new("aport", this);
      ce_monitor_h = ce_monitor::type_id::create("ce_monitor_h", this); 
      uvm_config_db#(ce_agt_config)::set(this, "*", "ce_agt_config", agt_cfg);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
      if (get_is_active()) begin
        ce_driver_h.seq_item_port.connect( ce_sequencer_h.seq_item_export );
      end
      ce_monitor_h.aport.connect( this.aport );
    endfunction: connect_phase
  endclass: ce_agent

  //.......................................................
  // Environment
  //.......................................................
  class base_env extends uvm_env;

    `uvm_component_utils(base_env)

    input_agent     input_agent_h;
    tlb_agent       tlb_agent_h;
    output_agent    output_agent_h;
    ce_agent        ce_agent_h;
    icache_cov_col  icache_cov_col_h;
    //my_scoreboard my_scoreboard_h;
    //my_predictor  my_predictor_h;
    //my_comparator my_comparator_h;

    env_config    env_cfg;
    input_agt_config  input_agt_cfg;
    tlb_agt_config    tlb_agt_cfg;
    output_agt_config output_agt_cfg;
    ce_agt_config     ce_agt_cfg;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      input_agent_h   = input_agent::type_id::create("input_agent_h",   this);
      tlb_agent_h     = tlb_agent::type_id::create("tlb_agent_h",   this);
      output_agent_h  = output_agent::type_id::create("output_agent_h",   this);
      ce_agent_h      = ce_agent::type_id::create("ce_agent_h",   this);
      icache_cov_col_h    = icache_cov_col#()::type_id::create("icache_cov_col_h", this);
      //my_scoreboard_h = my_scoreboard::type_id::create("my_scoreboard_h", this);
      //my_predictor_h  = my_predictor::type_id::create("my_predictor_h", this);
      //my_comparator_h = my_comparator::type_id::create("my_comparator_h", this);

      // Get configuration information for environment
      env_cfg = env_config::type_id::create("env_cfg");
      if(!uvm_config_db#(env_config)::get(this, "", "env_config", env_cfg))
        `uvm_fatal("NO_CFG", "No environment config set")

      // Set Agent Config Information depending on environment configuration
      input_agt_cfg   = input_agt_config::type_id::create("input_agt_cfg");
      tlb_agt_cfg     = tlb_agt_config::type_id::create("tlb_agt_cfg");
      output_agt_cfg  = output_agt_config::type_id::create("output_agt_cfg");
      ce_agt_cfg      = ce_agt_config::type_id::create("ce_agt_cfg");

      input_agt_cfg.icache_if_h  = env_cfg.icache_input_if_h;
      tlb_agt_cfg.icache_if_h    = env_cfg.icache_tlb_if_h;
      output_agt_cfg.icache_if_h = env_cfg.icache_output_if_h;
      ce_agt_cfg.icache_if_h     = env_cfg.icache_ce_if_h;

      uvm_config_db #(int) :: set (this, "input_agent_h", "is_active", (env_cfg.input_is_active == 1'b1) ? UVM_ACTIVE : UVM_PASSIVE);
      uvm_config_db #(int) :: set (this, "tlb_agent_h", "is_active", (env_cfg.tlb_is_active == 1'b1) ? UVM_ACTIVE : UVM_PASSIVE);
      uvm_config_db #(int) :: set (this, "output_agent_h", "is_active", (env_cfg.output_is_active == 1'b1) ? UVM_ACTIVE : UVM_PASSIVE);
      uvm_config_db #(int) :: set (this, "ce_agent_h", "is_active", (env_cfg.ce_is_active == 1'b1) ? UVM_ACTIVE : UVM_PASSIVE);

      uvm_config_db#(input_agt_config)::set(this, "input_agent_h", "input_agt_config", input_agt_cfg);
      uvm_config_db#(tlb_agt_config)::set(this, "tlb_agent_h", "tlb_agt_config", tlb_agt_cfg);
      uvm_config_db#(output_agt_config)::set(this, "output_agent_h", "output_agt_config", output_agt_cfg);
      uvm_config_db#(ce_agt_config)::set(this, "ce_agent_h", "ce_agt_config", ce_agt_cfg);
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
      input_agent_h.aport.connect(icache_cov_col_h.input_export);
      // input_agent_h.aport.connect(my_scoreboard_h.analysis_export);
      tlb_agent_h.aport.connect(icache_cov_col_h.tlb_export);
      // tlb_agent_h.aport.connect(my_scoreboard_h.analysis_export);
      output_agent_h.aport.connect(icache_cov_col_h.output_export);
      // output_agent_h.aport.connect(my_scoreboard_h.analysis_export);
      ce_agent_h.aport.connect(icache_cov_col_h.ce_export);
      // ce_agent_h.aport.connect(my_scoreboard_h.analysis_export);

      //my_scoreboard_h.pred_in_ap.connect(my_predictor_h.analysis_export);
      //my_scoreboard_h.comp_in_ap.connect(my_comparator_h.dut_export);
      //my_predictor_h.results_ap.connect(my_comparator_h.pred_export);
    endfunction: connect_phase

  endclass: base_env
endpackage: icache_uvm_comp_pkg
`endif
