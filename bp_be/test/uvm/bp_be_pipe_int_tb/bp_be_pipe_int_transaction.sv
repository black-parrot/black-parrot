/**
 * bp_be_pipe_int_transaction.sv
 * UVM transaction for bp_be_pipe_int testbench.
 */
`ifndef BP_BE_PIPE_INT_TRANSACTION_SV
`define BP_BE_PIPE_INT_TRANSACTION_SV

class bp_be_pipe_int_transaction extends uvm_sequence_item;

  `uvm_object_utils_begin(bp_be_pipe_int_transaction)
    `uvm_field_int(v,          UVM_ALL_ON)
    `uvm_field_int(en_i,       UVM_ALL_ON)
    `uvm_field_int(flush_i,    UVM_ALL_ON)
    `uvm_field_int(pc,         UVM_ALL_ON)
    `uvm_field_int(rs1,        UVM_ALL_ON)
    `uvm_field_int(rs2,        UVM_ALL_ON)
    `uvm_field_int(imm,        UVM_ALL_ON)
    `uvm_field_int(fu_op,      UVM_ALL_ON)
    `uvm_field_int(src1_sel,   UVM_ALL_ON)
    `uvm_field_int(src2_sel,   UVM_ALL_ON)
    `uvm_field_int(irs1_tag,   UVM_ALL_ON)
    `uvm_field_int(irs2_r_v,   UVM_ALL_ON)
    `uvm_field_int(ird_tag,    UVM_ALL_ON)
    `uvm_field_int(pipe_int_v, UVM_ALL_ON)
    `uvm_field_int(br_v,       UVM_ALL_ON)
    `uvm_field_int(j_v,        UVM_ALL_ON)
    `uvm_field_int(jr_v,       UVM_ALL_ON)
    `uvm_field_int(carryin,    UVM_ALL_ON)
    `uvm_field_int(size,       UVM_ALL_ON)
  `uvm_object_utils_end

  rand logic        v;
  rand logic        en_i;
  rand logic        flush_i;
  rand logic [38:0] pc;
  rand logic [64:0] rs1;
  rand logic [64:0] rs2;
  rand logic [64:0] imm;
  rand logic [3:0]  fu_op;
  rand logic [2:0]  src1_sel;
  rand logic [2:0]  src2_sel;
  rand logic        irs1_tag;
  rand logic        irs2_r_v;
  rand logic        ird_tag;
  rand logic        pipe_int_v;
  rand logic        br_v;
  rand logic        j_v;
  rand logic        jr_v;
  rand logic        carryin;
  rand logic [1:0]  size;

  constraint c_flush_rare  { flush_i dist {0 := 95, 1 := 5}; }
  constraint c_en_usually  { en_i dist {1 := 90, 0 := 10}; }
  constraint c_v_mostly    { v dist {1 := 85, 0 := 15}; }
  constraint c_pipe_int_v  { pipe_int_v == 1'b1; }
  constraint c_branch_jump {
    (br_v + j_v + jr_v) <= 1;
    br_v  dist {0 := 80, 1 := 20};
    j_v   dist {0 := 90, 1 := 10};
    jr_v  dist {0 := 90, 1 := 10};
  }
  constraint c_no_j_and_br { !(j_v && br_v); }
  constraint c_pc_align    { pc[0] == 1'b0; }
  constraint c_rs1_rec     { rs1[64] == 1'b0; }
  constraint c_rs2_rec     { rs2[64] == 1'b0; }
  constraint c_imm_rec     { imm[64] == 1'b0; }
  constraint c_src1_sel    { src1_sel inside {3'd0, 3'd1, 3'd2, 3'd3, 3'd4}; }
  constraint c_src2_sel    { src2_sel inside {3'd0, 3'd1, 3'd2, 3'd3}; }
  constraint c_fu_op_range { fu_op inside {[4'd0 : 4'd15]}; }
  constraint c_size        { size inside {2'd0, 2'd1}; }

  function new(string name = "bp_be_pipe_int_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
      "v=%0b en=%0b flush=%0b pc=0x%0h rs1=0x%0h rs2=0x%0h imm=0x%0h fu_op=%0d src1=%0d src2=%0d br=%0b j=%0b jr=%0b carry=%0b",
      v, en_i, flush_i, pc, rs1, rs2, imm, fu_op, src1_sel, src2_sel, br_v, j_v, jr_v, carryin
    );
  endfunction

endclass
`endif
