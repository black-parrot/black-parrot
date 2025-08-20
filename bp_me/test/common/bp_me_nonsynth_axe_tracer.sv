ERROR_NOT_CURRENTLY_SUPPORTED

/**
 * Name:
 *   bp_me_nonsynth_axe_tracer.v
 *
 * Description:
 *   This module generates a single AXE trace for all caches
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_axe_tracer
  import bp_common_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_test_multicore_half_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter `BSG_INV_PARAM(block_width_p)
    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_width_p/8)
  )
  (
    input                                                   clk_i
    , input                                                 reset_i

    , input [lce_id_width_p-1:0]                            id_i

    , input                                                 load_commit_i
    , input                                                 store_commit_i
    , input [paddr_width_p-1:0]                             addr_i
    , input [dword_width_gp-1:0]                            load_data_i
    , input [dword_width_gp-1:0]                            store_data_i
  );

  // AXE / Memory Consistency Tracing
  localparam dword_byte_offset_lp=`BSG_SAFE_CLOG2(dword_width_gp/8);
  wire [paddr_width_p-1:0] axe_paddr = addr_i - dram_base_addr_gp;
  always_ff @(negedge clk_i) begin
    if (load_commit_i) begin
      $display("### AXE %0d: M[%0d] == %0d", id_i, (axe_paddr >> dword_byte_offset_lp), load_data_i);
    end
    if (store_commit_i) begin
      $display("### AXE %0d: M[%0d] := %0d", id_i, (axe_paddr >> dword_byte_offset_lp), store_data_i);
    end
  end

endmodule
