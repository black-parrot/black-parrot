/**
 * bp_be_pipe_int_monitor.sv
 * UVM monitor for bp_be_pipe_int testbench.
 * Observes DUT outputs and broadcasts them to the scoreboard.
 */
`ifndef BP_BE_PIPE_INT_MONITOR_SV
`define BP_BE_PIPE_INT_MONITOR_SV

class bp_be_pipe_int_output_transaction extends uvm_sequence_item;
  `uvm_object_utils_begin(bp_be_pipe_int_output_transaction)
    `uvm_field_int(data_o,               UVM_ALL_ON)
    `uvm_field_int(v_o,                  UVM_ALL_ON)
    `uvm_field_int(branch_o,             UVM_ALL_ON)
    `uvm_field_int(btaken_o,             UVM_ALL_ON)
    `uvm_field_int(npc_o,                UVM_ALL_ON)
    `uvm_field_int(instr_misaligned_v_o, UVM_ALL_ON)
  `uvm_object_utils_end

  logic [63:0] data_o;
  logic        v_o;
  logic        branch_o;
  logic        btaken_o;
  logic [38:0] npc_o;
  logic        instr_misaligned_v_o;

  function new(string name = "bp_be_pipe_int_output_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
      "data=0x%0h v=%0b branch=%0b btaken=%0b npc=0x%0h misaligned=%0b",
      data_o, v_o, branch_o, btaken_o, npc_o, instr_misaligned_v_o
    );
  endfunction
endclass

class bp_be_pipe_int_monitor extends uvm_monitor;
  `uvm_component_utils(bp_be_pipe_int_monitor)

  virtual bp_be_pipe_int_if vif;

  // Analysis port — connects to scoreboard
  uvm_analysis_port #(bp_be_pipe_int_output_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual bp_be_pipe_int_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Monitor could not get virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    bp_be_pipe_int_output_transaction tr;
    // Wait until reset deasserts
    @(negedge vif.reset_i);
    forever begin
      @(posedge vif.clk_i);
      #1; // sample after clock edge
      // Only capture when output is valid
      if (vif.v_o) begin
        tr = bp_be_pipe_int_output_transaction::type_id::create("tr");
        tr.data_o               = vif.data_o;
        tr.v_o                  = vif.v_o;
        tr.branch_o             = vif.branch_o;
        tr.btaken_o             = vif.btaken_o;
        tr.npc_o                = vif.npc_o;
        tr.instr_misaligned_v_o = vif.instr_misaligned_v_o;
        `uvm_info("MON", tr.convert2string(), UVM_HIGH)
        ap.write(tr);
      end
    end
  endtask

endclass
`endif
