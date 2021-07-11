
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
  // e_cce_mode_normal: CCE operates as a microcoded engine, features depend on microcode provided
  typedef enum logic
  {
    e_cce_mode_uncached = 0
    ,e_cce_mode_normal  = 1
  } bp_cce_mode_e;

  // The overall memory map of the config link is:
  //   16'h0000 - 16'h01ff: chip level config
  //   16'h0200 - 16'h03ff: fe config
  //   16'h0400 - 16'h05ff: be config
  //   16'h0600 - 16'h07ff: me config
  //   16'h0800 - 16'h7fff: reserved
  //   16'h8000 - 16'h8fff: cce ucode

  localparam cfg_addr_width_gp = 20;
  localparam cfg_data_width_gp = 64;

  localparam cfg_base_addr_gp          = 'h0200_0000;
  localparam cfg_reg_unused_gp         = 'h0004;
  localparam cfg_reg_freeze_gp         = 'h0008;
  localparam cfg_reg_core_id_gp        = 'h000c;
  localparam cfg_reg_did_gp            = 'h0010;
  localparam cfg_reg_cord_gp           = 'h0014;
  localparam cfg_reg_host_did_gp       = 'h0018;
  localparam cfg_reg_hio_mask_gp       = 'h001c;
  localparam cfg_reg_icache_id_gp      = 'h0200;
  localparam cfg_reg_icache_mode_gp    = 'h0204;
  localparam cfg_reg_dcache_id_gp      = 'h0400;
  localparam cfg_reg_dcache_mode_gp    = 'h0404;
  localparam cfg_reg_cce_id_gp         = 'h0600;
  localparam cfg_reg_cce_mode_gp       = 'h0604;
  localparam cfg_mem_base_cce_ucode_gp = 'h8000;

`endif

