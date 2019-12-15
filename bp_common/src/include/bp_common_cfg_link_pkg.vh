
package bp_common_cfg_link_pkg;

  // TODO: This is out of date.  The actual map shouldn't matter much, but we should decide...
  // The overall memory map of the config link is:
  //   16'h0000 - 16'h001f: chip level config
  //   16'h0020 - 16'h003f: fe config
  //   16'h0040 - 16'h005f: be config
  //   16'h0060 - 16'h007f: me config
  //   16'h0080 - 16'h00ff: reserved
  //   16'h8000 - 16'h8fff: cce ucode
  // Specific cfg registers
  //   16'h0000      = clk_osc
  //   16'h0001      = reset
  //   16'h0002      = freeze
  //   16'h0040      = npc low  32 bits
  //   16'h0041      = npc high 32 bits
  //   16'h0060      = cce_mode
  //   16'h8000-8fff = cce ucode

  localparam bp_cfg_base_addr_gp          = 'h0100_0000;
  localparam bp_cfg_reg_reset_gp          = 'h0001;
  localparam bp_cfg_reg_freeze_gp         = 'h0002;
  localparam bp_cfg_reg_core_id_gp        = 'h0005;
  localparam bp_cfg_reg_did_gp            = 'h0006;
  localparam bp_cfg_reg_cord_gp           = 'h0007;
  localparam bp_cfg_reg_host_did_gp       = 'h0008;
  localparam bp_cfg_reg_icache_id_gp      = 'h0021;
  localparam bp_cfg_reg_icache_mode_gp    = 'h0022;
  localparam bp_cfg_reg_npc_gp            = 'h0040;
  localparam bp_cfg_reg_dcache_id_gp      = 'h0042;
  localparam bp_cfg_reg_dcache_mode_gp    = 'h0043;
  localparam bp_cfg_reg_priv_gp           = 'h0044;
  localparam bp_cfg_reg_irf_x0_gp         = 'h0050;
  /* ... */
  localparam bp_cfg_reg_irf_x31_gp        = 'h006f;
  localparam bp_cfg_reg_cce_id_gp         = 'h0080;
  localparam bp_cfg_reg_cce_mode_gp       = 'h0081;
  localparam bp_cfg_reg_num_lce_gp        = 'h0082;
  localparam bp_cfg_reg_frf_x0_gp         = 'h00a0;
  /* ... */
  localparam bp_cfg_reg_frf_x31_gp        = 'h00bf;
  localparam bp_cfg_reg_csr_begin_gp      = 'h6000;
  localparam bp_cfg_reg_csr_end_gp        = 'h6fff;
  localparam bp_cfg_mem_base_cce_ucode_gp = 'h8000;

endpackage

