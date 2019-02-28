
package bp_be_pkg;

  //import bp_common_pkg::*;
  import bp_be_rv64_pkg::*;

  `include "bp_common_fe_be_if.vh"
  `include "bp_be_ucode_defines.vh"
  `include "bp_be_mmu_defines.vh"
  `include "bp_be_internal_if_defines.vh"

  localparam bp_pc_entry_point_gp    = 32'h80000124;
  localparam bp_be_itag_width_gp     = 8;
  localparam bp_be_pipe_stage_els_gp = 5;

endpackage : bp_be_pkg

