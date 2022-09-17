/*
 * bp_fe_realigner.sv
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
   , input [instr_width_gp-1:0]  fetch_data_i
   , input                       fetch_data_v_i

    // poison_i takes precedence over fetch_data_v_i
    // restore_lower_half_v_i takes precedence over poison_i
   , input                           poison_i
   , input                           restore_lower_half_v_i
   , input [instr_half_width_gp-1:0] restore_lower_half_i
   , input [vaddr_width_p-1:0]       restore_lower_half_pc_i

   , output [vaddr_width_p-1:0]  fetch_instr_pc_o
   , output [instr_width_gp-1:0] fetch_instr_o
   , output                      fetch_instr_v_o
   , output                      fetch_is_second_half_o
   );

  wire [instr_half_width_gp-1:0] icache_data_lower_half_li = fetch_data_i[0                  +:instr_half_width_gp];
  wire [instr_half_width_gp-1:0] icache_data_upper_half_li = fetch_data_i[instr_half_width_gp+:instr_half_width_gp];

  logic [vaddr_width_p-1:0] fetch_instr_pc_n, fetch_instr_pc_r;
  logic [instr_half_width_gp-1:0] half_buffer_n, half_buffer_r;
  logic half_buffer_v_r;

  wire icache_fetch_is_aligned  = `bp_addr_is_aligned(fetch_pc_i, rv64_instr_width_bytes_gp);
  wire buffered_pc_is_aligned   = `bp_addr_is_aligned(fetch_instr_pc_r, rv64_instr_width_bytes_gp);

  assign fetch_instr_pc_n = restore_lower_half_v_i ? restore_lower_half_pc_i : half_buffer_v_r ? fetch_pc_i + vaddr_width_p'(2) : fetch_pc_i;
  assign half_buffer_n    = restore_lower_half_v_i ? restore_lower_half_i    : icache_data_upper_half_li;

  bsg_dff_reset_en
   #(.width_p(vaddr_width_p+instr_half_width_gp))
   half_buffer_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i  (fetch_data_v_i | restore_lower_half_v_i)
     ,.data_i({fetch_instr_pc_n, half_buffer_n})
     ,.data_o({fetch_instr_pc_r, half_buffer_r})
     );

  bsg_dff_reset_set_clear
   #(.width_p(1))
   half_buffer_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i  ((fetch_data_v_i & ~poison_i & (half_buffer_v_r | !icache_fetch_is_aligned)) | restore_lower_half_v_i)
     // TODO: invalidate when PC is aligned? (outside the realigner)
     ,.clear_i(fetch_instr_v_o | poison_i) // set overrides clear
     ,.data_o (half_buffer_v_r)
     );

  // wire buffered_insn_v          = fetch_data_v_i && half_buffer_v_r;

  assign fetch_is_second_half_o = half_buffer_v_r;

  assign fetch_instr_v_o  = (half_buffer_v_r | icache_fetch_is_aligned) & fetch_data_v_i;
  assign fetch_instr_pc_o = half_buffer_v_r ? fetch_instr_pc_r                             : fetch_pc_i;
  assign fetch_instr_o    = half_buffer_v_r ? { icache_data_lower_half_li, half_buffer_r } : fetch_data_i;

  always @(negedge clk_i)
    if(buffered_pc_is_aligned && half_buffer_v_r)
      $error("bad");
endmodule
