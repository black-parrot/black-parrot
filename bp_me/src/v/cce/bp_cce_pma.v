/**
 *
 * Name:
 *   bp_cce_pma.v
 *
 * Description:
 *   This module defines the physical memory attributes (PMAs) obeyed by the CCE.
 *   The purpose is to define which regions of memory are coherent and which are incoherent.
 *
 *   Only cached, global memory is kept coherent (i.e., DRAM memory). All other memory
 *   is uncached and incoherent. See the BlackParrot Platform Guide (docs/platform_guide.md)
 *   and the bp_common_pkg files in bp_common/src/include/ for more details on BlackParrot's
 *   platform memory maps.
 *
 *   Uncacheable requests from an LCE are allowed to cacheable, global memory, and these requests
 *   will be kept coherent with all LCEs by invalidating (and writing back, if necessary) the block
 *   from all LCEs prior to performing the uncached operation.
 *
 */

module bp_cce_pma
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
  )
  (input [paddr_width_p-1:0]                           paddr_i
   , output logic                                      coherent_o
  );

  always_comb begin

    coherent_o = (paddr_i >= dram_base_addr_gp) && (paddr_i < (coproc_base_addr_gp));

  end

endmodule

