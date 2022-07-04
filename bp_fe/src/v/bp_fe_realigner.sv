/*
 * bp_fe_realigner.v
 *
 * 32-bit I$ output buffer which reconstructs 32-bit instructions fetched as two halves.
 * Passes through the input data unmodified when the fetch is aligned.
 */
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_realigner
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
 )
  (input   clk_i
   , input reset_i

   , input [vaddr_width_p-1:0]   fetch_pc_i
   , input                       fetch_linear_i // is this fetch address exactly 4 bytes greater than the previous one?
   , input [instr_width_gp-1:0]  fetch_data_i
   , input                       fetch_data_v_i

   , output [instr_width_gp-1:0] fetch_instr_o
   , output                      fetch_instr_v_o
   , output                      fetch_is_second_half_o
//    , output                      fetch_instr_progress_o // is the current input aiding resolution of a coherent instruction fetch?
   );

  wire [instr_half_width_gp-1:0] icache_data_lower_half_li = fetch_data_i[instr_half_width_gp-1:0];
  wire [instr_half_width_gp-1:0] icache_data_upper_half_li = fetch_data_i[instr_width_gp-1     :instr_half_width_gp];

  logic [instr_half_width_gp-1:0] upper_half_buffer_n, upper_half_buffer_r;
  logic upper_half_buffer_v_n, upper_half_buffer_v_r;
  // For ease in catching errors only, zero out register when input is invalid
  assign upper_half_buffer_n   = fetch_data_v_i ? icache_data_upper_half_li : '0;
  assign upper_half_buffer_v_n = fetch_data_v_i;
  bsg_dff_reset
   #(.width_p(instr_half_width_gp+1))
   upper_half_buffer_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({upper_half_buffer_n, upper_half_buffer_v_n})
     ,.data_o({upper_half_buffer_r, upper_half_buffer_v_r})
     );

  wire icache_fetch_is_aligned    = `bp_addr_is_aligned(fetch_pc_i, rv64_instr_width_bytes_gp);
  wire has_coherent_buffered_insn = !icache_fetch_is_aligned && fetch_data_v_i && fetch_linear_i && upper_half_buffer_v_r;

  assign fetch_is_second_half_o = !icache_fetch_is_aligned && fetch_linear_i && upper_half_buffer_v_r;

  assign fetch_instr_v_o = icache_fetch_is_aligned ? fetch_data_v_i : has_coherent_buffered_insn;
  assign fetch_instr_o   = icache_fetch_is_aligned ? fetch_data_i   : { icache_data_lower_half_li, upper_half_buffer_r };
endmodule