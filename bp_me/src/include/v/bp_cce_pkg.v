/**
 *
 * Name:
 *   bp_cce_pkg.v
 *
 * Description:
 *
 */

package bp_cce_pkg;

  import bp_common_pkg::*;

  `include "bp_cce_inst.vh"

  typedef enum bit
  {
    e_cce_mode_uncached = 1'b0
    ,e_cce_mode_normal  = 1'b1
  } bp_cce_mode_e;

  `define bp_cce_mode_bits $bits(bp_cce_mode_e)

endpackage : bp_cce_pkg
