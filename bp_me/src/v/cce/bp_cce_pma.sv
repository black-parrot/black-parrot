/**
 *
 * Name:
 *   bp_cce_pma.sv
 *
 * Description:
 *   This module defines the physical memory attributes (PMAs) obeyed by the CCE.
 *   The purpose is to define the coherence and cacheability properties of memory.
 *
 *   Only L1 cached memory is kept explicitly coherent (i.e., coherent DRAM memory).
 *   All other memory is uncached in the L1, but may be cached in the L2.
 *
 *   Uncacheable requests from an LCE are allowed to cacheable/coherent global memory.
 *   Coherence is maintained by the CCE for all accesses to L1 cached/coherent memory.
 *
 */

`include "bp_common_defines.svh"

module bp_cce_pma
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [paddr_width_p-1:0] paddr_i
   , input                   paddr_v_i
   , output logic            l1_cacheable_o
   , output logic            l2_cacheable_o
   );

  assign l1_cacheable_o = paddr_v_i & (paddr_i >= dram_base_addr_gp) & (paddr_i < dram_l1uc_base_addr_gp);
  assign l2_cacheable_o = paddr_v_i & (paddr_i >= dram_base_addr_gp) & (paddr_i < dram_l2uc_base_addr_gp);

endmodule

