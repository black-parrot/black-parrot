
package bp_be_pkg;
  import bp_common_pkg::*;
  import bp_be_rv64_pkg::*;

  `include "bp_common_fe_be_if.vh"
  `include "bp_be_ctl_defines.vh"
  `include "bp_be_mem_defines.vh"
  `include "bp_be_internal_if_defines.vh"

  localparam bp_pc_entry_point_gp     = 39'h00_8000_0000;
  // TODO: Arbitrary addresses, should probably think about these
  //         2nd from top bit indicates MMIO
  localparam bp_mmio_mtime_addr_gp         = 39'h6f_ffff_0000;
  // mtimecmp base address, +8 for each hart
  localparam bp_mmio_mtimecmp_base_addr_gp = 39'h6f_ffff_0100;
  localparam bp_mmio_msoftint_base_addr_gp = 39'h6f_ffff_0200;
  localparam bp_be_itag_width_gp           = 8;
  localparam bp_be_pipe_stage_els_gp       = 5;

endpackage : bp_be_pkg

