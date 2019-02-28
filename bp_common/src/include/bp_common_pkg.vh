/* 
 * bp_common_pkg.vh
 *
 * Contains the interface structures used for communicating between FE, BE, ME in BlackParrot.
 * Additionally contains global parameters used to configure the system. In the future, when 
 *   multiple configurations are supported, these global parameters will belong to groups 
 *   e.g. SV39, VM-disabled, ...
 *
 */

package bp_common_pkg;

  `include "bsg_defines.v"
  `include "bp_common_cfg_defines.vh"
  `include "bp_common_fe_be_if.vh"
  `include "bp_common_me_if.vh"

  /*
   * RV64 specifies a 64b effective address and 32b instruction.
   * BlackParrot supports SV39 virtual memory, which specifies 39b virtual / 56b physical address.
   * Effective addresses must have bits 39-63 match bit 38 
   *   or a page fault exception will occur during translation.
   * Currently, we only support a very limited number of parameter configurations.
   * Thought: We could have a `define surrounding core instantiations of each parameter and then
   * when they import this package, `declare the if structs. No more casting!
   */

  localparam bp_eaddr_width_gp = 64;
  localparam bp_vaddr_width_gp = 22;
  localparam bp_paddr_width_gp = 22;
  localparam bp_instr_width_gp = 32;

  parameter bp_sv39_vaddr_width_gp = 39;
  parameter bp_sv39_paddr_width_gp = 56;
  parameter bp_page_size_in_bytes_gp = 4096;
  parameter bp_page_offset_width_gp = `BSG_SAFE_CLOG2(bp_page_size_in_bytes_gp);


endpackage : bp_common_pkg
