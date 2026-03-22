`ifndef BP_BE_PIPE_INT_DRIVER_SV
`define BP_BE_PIPE_INT_DRIVER_SV

class bp_be_pipe_int_driver extends uvm_driver #(bp_be_pipe_int_transaction);
  `uvm_component_utils(bp_be_pipe_int_driver)

  virtual bp_be_pipe_int_if vif;

  // Bit offsets into reservation_i flat bus
  localparam V_BIT       = 0;
  localparam PC_LSB      = 1;
  localparam PC_MSB      = 39;
  localparam RS1_LSB     = 40;
  localparam RS1_MSB     = 104;
  localparam RS2_LSB     = 105;
  localparam RS2_MSB     = 169;
  localparam IMM_LSB     = 170;
  localparam IMM_MSB     = 234;
  localparam PIPE_INT_B  = 235;
  localparam BR_B        = 236;
  localparam J_B         = 237;
  localparam JR_B        = 238;
  localparam CARRY_B     = 239;
  localparam IRS1TAG_B   = 240;
  localparam IRS2RV_B    = 241;
  localparam IRDTAG_B    = 242;
  localparam FUOP_LSB    = 243;
  localparam FUOP_MSB    = 246;
  localparam SRC1_LSB    = 247;
  localparam SRC1_MSB    = 249;
  localparam SRC2_LSB    = 250;
  localparam SRC2_MSB    = 252;
  localparam SIZE_LSB    = 253;
  localparam SIZE_MSB    = 254;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual bp_be_pipe_int_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Driver could not get virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    bp_be_pipe_int_transaction tr;
    vif.reset_i       = 1'b1;
    vif.en_i          = 1'b0;
    vif.flush_i       = 1'b0;
    vif.reservation_i = '0;
    repeat(5) @(posedge vif.clk_i);
    vif.reset_i = 1'b0;
    @(posedge vif.clk_i);
    forever begin
      seq_item_port.get_next_item(tr);
      drive_transaction(tr);
      seq_item_port.item_done();
    end
  endtask

  task drive_transaction(bp_be_pipe_int_transaction tr);
    logic [511:0] res;
    @(posedge vif.clk_i);
    // Pack reservation fields into flat bus
    res = '0;
    res[V_BIT]              = tr.v;
    res[PC_MSB:PC_LSB]      = tr.pc;
    res[RS1_MSB:RS1_LSB]    = tr.rs1;
    res[RS2_MSB:RS2_LSB]    = tr.rs2;
    res[IMM_MSB:IMM_LSB]    = tr.imm;
    res[PIPE_INT_B]         = tr.pipe_int_v;
    res[BR_B]               = tr.br_v;
    res[J_B]                = tr.j_v;
    res[JR_B]               = tr.jr_v;
    res[CARRY_B]            = tr.carryin;
    res[IRS1TAG_B]          = tr.irs1_tag;
    res[IRS2RV_B]           = tr.irs2_r_v;
    res[IRDTAG_B]           = tr.ird_tag;
    res[FUOP_MSB:FUOP_LSB]  = tr.fu_op;
    res[SRC1_MSB:SRC1_LSB]  = tr.src1_sel;
    res[SRC2_MSB:SRC2_LSB]  = tr.src2_sel;
    res[SIZE_MSB:SIZE_LSB]  = tr.size;
    vif.en_i          = tr.en_i;
    vif.flush_i       = tr.flush_i;
    vif.reservation_i = res;
    `uvm_info("DRV", tr.convert2string(), UVM_HIGH)
  endtask

endclass
`endif
