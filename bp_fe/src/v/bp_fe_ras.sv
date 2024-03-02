/*
 * bp_fe_ras.sv
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_ras
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                                clk_i
   , input                              reset_i

   , output logic                       init_done_o

   , input                              restore_i
   , input [ras_idx_width_p-1:0]        w_next_i
   , input [ras_idx_width_p-1:0]        w_tos_i

   , input                              call_i
   , input [vaddr_width_p-1:0]          addr_i

   , output logic                       v_o
   , output logic [vaddr_width_p-1:0]   tgt_o
   , output logic [ras_idx_width_p-1:0] next_o
   , output logic [ras_idx_width_p-1:0] tos_o
   , input                              return_i
   );

  localparam ras_els_lp = 2**ras_idx_width_p;
  logic [ras_idx_width_p-1:0] next_n, next_r;
  logic [ras_idx_width_p-1:0] tos_n, tos_r;
  logic [ras_idx_width_p-1:0] nos_lo;
  logic [vaddr_width_p-1:0] tgt_lo;

  // Algorithm taken from "Recovery Requirements of Branch Prediction Storage
  //   Structures in the Presence of Mispredicted-Path Execution"
  assign next_n = restore_i ? w_next_i : call_i ? (next_r+1'b1) :                     next_r;
  assign tos_n  = restore_i ? w_tos_i  : call_i ? (next_r+1'b0) : return_i ? nos_lo : tos_r;
  bsg_dff_reset
   #(.width_p(2*ras_idx_width_p))
   ptr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({next_n, tos_n})
     ,.data_o({next_r, tos_r})
     );

  // Needs to push/pop at the same time to comply with RISC-V hints, preventing
  //   hardening. But, we expect this to be a fairly small structure
  bsg_mem_1r1w
   #(.width_p(ras_idx_width_p+vaddr_width_p), .els_p(ras_els_lp), .read_write_same_addr_p(1))
   mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(call_i)
     ,.w_addr_i(next_r)
     ,.w_data_i({tos_r, addr_i})
     ,.r_v_i(return_i)
     ,.r_addr_i(tos_r)
     ,.r_data_o({nos_lo, tgt_lo})
     );
  assign tgt_o = tgt_lo;
  assign next_o = next_r;
  assign tos_o = tos_r;

  // Keeping track is more overhead than correcting misaligned stacks. See:
  // "Improving Prediction for Procedure Returns with Return-Address-Stack Repair Mechanisms"
  assign v_o = 1'b1;

  // We use count for valid, so we're immediately ready to go
  assign init_done_o = 1'b1;

endmodule

