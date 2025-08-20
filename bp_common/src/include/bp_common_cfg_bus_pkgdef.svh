
`ifndef BP_COMMON_CFG_BUS_PKGDEF_SVH
`define BP_COMMON_CFG_BUS_PKGDEF_SVH

  // LCE Operating Mode
  // e_lce_mode_uncached: Cache treats all requests as uncached
  // e_lce_mode_normal: Cache acts normally
  // e_lce_mode_nonspec: Cache acts mostly normally, but will not send a speculative miss
  typedef enum logic [1:0]
  {
    e_lce_mode_uncached = 0
    ,e_lce_mode_normal  = 1
    ,e_lce_mode_nonspec = 2
  } bp_lce_mode_e;

  // CCE Operating Mode
  // e_cce_mode_uncached: CCE supports uncached requests only
  // e_cce_mode_normal: CCE supports cacheable requests
  typedef enum logic
  {
    e_cce_mode_uncached = 0
    ,e_cce_mode_normal  = 1
  } bp_cce_mode_e;

  // Core Operating Mode
  // e_core_status_run: execute normally
  // e_core_status_freeze: do not issue further instructions
  typedef enum logic
  {
    e_core_status_run     = 0
    ,e_core_status_freeze = 1
  } bp_core_status_e;

  // The overall memory map of the config link is:
  //   16'h0000 - 16'h01ff: chip level config
  //   16'h0200 - 16'h03ff: fe config
  //   16'h0400 - 16'h05ff: be config
  //   16'h0600 - 16'h07ff: me config
  //   16'h0800 - 16'h7fff: reserved
  //   16'h8000 - 16'h8fff: cce ucode

  localparam cfg_base_addr_gp           = (dev_id_width_gp+dev_addr_width_gp)'('h0020_0000);
  localparam cfg_match_addr_gp          = (dev_id_width_gp+dev_addr_width_gp)'('h002?_????);

  localparam cfg_unused_00_gp           = (dev_addr_width_gp)'('h0_0000);
  localparam cfg_reg_freeze_gp          = (dev_addr_width_gp)'('h0_0008);
  localparam cfg_reg_npc_gp             = (dev_addr_width_gp)'('h0_0010);
  localparam cfg_reg_core_id_gp         = (dev_addr_width_gp)'('h0_0018);
  localparam cfg_reg_did_gp             = (dev_addr_width_gp)'('h0_0020);
  localparam cfg_reg_cord_gp            = (dev_addr_width_gp)'('h0_0028);
  localparam cfg_reg_host_did_gp        = (dev_addr_width_gp)'('h0_0030);
  // Used until PMP are setup properly
  localparam cfg_reg_hio_mask_gp        = (dev_addr_width_gp)'('h0_0038);
  localparam cfg_reg_icache_id_gp       = (dev_addr_width_gp)'('h0_0200);
  localparam cfg_reg_icache_mode_gp     = (dev_addr_width_gp)'('h0_0208);
  localparam cfg_reg_dcache_id_gp       = (dev_addr_width_gp)'('h0_0400);
  localparam cfg_reg_dcache_mode_gp     = (dev_addr_width_gp)'('h0_0408);
  localparam cfg_reg_cce_id_gp          = (dev_addr_width_gp)'('h0_0600);
  localparam cfg_reg_cce_mode_gp        = (dev_addr_width_gp)'('h0_0608);
  localparam cfg_mem_cce_ucode_base_gp  = (dev_addr_width_gp)'('h0_8000);
  localparam cfg_mem_cce_ucode_match_gp = (dev_addr_width_gp)'('h0_8???);

`endif

