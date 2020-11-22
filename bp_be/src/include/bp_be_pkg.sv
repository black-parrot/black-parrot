
package bp_be_pkg;
  import bp_common_pkg::*;
  import bp_common_rv64_pkg::*;

  localparam dpath_width_p = 66;

  `include "bp_common_core_if.svh"
  `include "bp_be_ctl_defines.svh"
  `include "bp_be_mem_defines.svh"
  `include "bp_be_internal_if_defines.svh"

  typedef struct packed
  {
    logic        sp_not_dp;
    logic [64:0] rec;
  } bp_be_fp_reg_s;

endpackage

