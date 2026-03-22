/**
 * bp_be_pipe_int_if.sv
 * Simple flat interface for bp_be_pipe_int UVM testbench.
 * No packing logic inside — driver writes reservation_i directly.
 */
`ifndef BP_BE_PIPE_INT_IF_SV
`define BP_BE_PIPE_INT_IF_SV

interface bp_be_pipe_int_if
  #(parameter vaddr_width_p       = 39
  , parameter int_rec_width_p     = 65
  , parameter dpath_width_p       = 64
  , parameter reservation_width_p = 512
  )
  (input logic clk_i);

  // DUT primary ports
  logic                            reset_i;
  logic                            en_i;
  logic                            flush_i;
  logic [reservation_width_p-1:0] reservation_i;

  // DUT outputs
  logic [dpath_width_p-1:0]       data_o;
  logic                            v_o;
  logic                            branch_o;
  logic                            btaken_o;
  logic [vaddr_width_p-1:0]       npc_o;
  logic                            instr_misaligned_v_o;

  // Unpacked fields — driver sets these, then packs into reservation_i
  logic                            res_v;
  logic [vaddr_width_p-1:0]       res_pc;
  logic [int_rec_width_p-1:0]     res_rs1;
  logic [int_rec_width_p-1:0]     res_rs2;
  logic [int_rec_width_p-1:0]     res_imm;
  logic [3:0]                      res_fu_op;
  logic [2:0]                      res_src1_sel;
  logic [2:0]                      res_src2_sel;
  logic                            res_irs1_tag;
  logic                            res_irs2_r_v;
  logic                            res_ird_tag;
  logic                            res_pipe_int_v;
  logic                            res_br_v;
  logic                            res_j_v;
  logic                            res_jr_v;
  logic                            res_carryin;
  logic [1:0]                      res_size;

endinterface

`endif
