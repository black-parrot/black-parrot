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

  ///////////////////////
  // Initialization state machine
  enum logic [1:0] {e_reset, e_clear, e_run} state_n, state_r;
  wire is_reset = (state_r == e_reset);
  wire is_clear = (state_r == e_clear);
  wire is_run   = (state_r == e_run);

  assign init_done_o = is_run;

  localparam ras_els_lp = 2**ras_idx_width_p;
  logic [`BSG_WIDTH(ras_els_lp)-1:0] init_cnt;
  bsg_counter_clear_up
   #(.max_val_p(ras_els_lp), .init_val_p(0))
   init_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(is_clear)
     ,.count_o(init_cnt)
     );
  wire finished_init = (init_cnt == ras_els_lp-1'b1);

  always_comb
    case (state_r)
      e_clear: state_n = finished_init ? e_run : e_clear;
      e_run  : state_n = e_run;
      // e_reset
      default: state_n = e_clear;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

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

  wire w_v_li = is_run ? call_i : 1'b1;
  wire [ras_idx_width_p-1:0] w_addr_li = is_run ? next_r : init_cnt;
  wire [ras_idx_width_p+vaddr_width_p-1:0] w_data_li = is_run ? {tos_r, addr_i} : '0;

  // Needs to push/pop at the same time to comply with RISC-V hints, preventing
  //   hardening. But, we expect this to be a fairly small structure
  bsg_mem_1r1w
   #(.width_p(ras_idx_width_p+vaddr_width_p), .els_p(ras_els_lp), .read_write_same_addr_p(1))
   mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(w_v_li)
     ,.w_addr_i(w_addr_li)
     ,.w_data_i(w_data_li)
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

endmodule

