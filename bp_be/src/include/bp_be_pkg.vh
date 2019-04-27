
package bp_be_pkg;
  import bp_common_pkg::*;
  import bp_be_rv64_pkg::*;

  `include "bp_common_fe_be_if.vh"
  `include "bp_be_ctl_defines.vh"
  `include "bp_be_mem_defines.vh"
  `include "bp_be_internal_if_defines.vh"
  `include "bp_be_vm_defines.vh"

  localparam bp_pc_entry_point_gp     = 39'h00_8000_0000;
  // TODO: Arbitrary addresses, should probably think about these
  //         2nd from top bit indicates MMIO
  localparam bp_mmio_mtime_addr_gp         = 39'h6f_ffff_0000;
  // mtimecmp base address, +8 for each hart
  localparam bp_mmio_mtimecmp_base_addr_gp = 39'h6f_ffff_0100;
  localparam bp_mmio_msoftint_base_addr_gp = 39'h6f_ffff_0200;
  localparam bp_be_itag_width_gp           = 8;
  localparam bp_be_pipe_stage_els_gp       = 5;

  // Right now, we support up to 8 cores. Therefore, 8 mtimecmps...
  localparam bp_mmio_mtimecmp_addr_gp = {39'h6f_ffff_0138
                                         ,39'h6f_ffff_0130
                                         ,39'h6f_ffff_0128
                                         ,39'h6f_ffff_0120
                                         ,39'h6f_ffff_0118
                                         ,39'h6f_ffff_0110
                                         ,39'h6f_ffff_0108
                                         ,39'h6f_ffff_0100
                                         };

  localparam bp_mmio_msoftint_addr_gp = {39'h6f_ffff_0238
                                         ,39'h6f_ffff_0230
                                         ,39'h6f_ffff_0228
                                         ,39'h6f_ffff_0220
                                         ,39'h6f_ffff_0218
                                         ,39'h6f_ffff_0210
                                         ,39'h6f_ffff_0208
                                         ,39'h6f_ffff_0200
                                         };

endpackage : bp_be_pkg

