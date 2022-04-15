
`ifndef BP_COMMON_CLINT_PKGDEF_SVH
`define BP_COMMON_CLINT_PKGDEF_SVH


  localparam clint_base_addr_gp         = (dev_id_width_gp+dev_addr_width_gp)'('h30_0000);
  localparam clint_match_addr_gp        = (dev_id_width_gp+dev_addr_width_gp)'('h30_0???);

  localparam mipi_reg_base_addr_gp      = dev_addr_width_gp'('h0_0000);
  localparam mipi_reg_match_addr_gp     = dev_addr_width_gp'('h0_0???);

  localparam mtimecmp_reg_base_addr_gp  = dev_addr_width_gp'('h0_4000);
  localparam mtimecmp_reg_match_addr_gp = dev_addr_width_gp'('h0_4???);

  localparam mtimesel_reg_base_addr_gp  = dev_addr_width_gp'('h0_8000);
  localparam mtimesel_reg_match_addr_gp = dev_addr_width_gp'('h0_8???);

  localparam mtime_reg_addr_gp          = dev_addr_width_gp'('h0_bff8);
  localparam mtime_reg_match_addr_gp    = dev_addr_width_gp'('h0_bff?);

  localparam plic_reg_base_addr_gp      = dev_addr_width_gp'('h0_b000);
  localparam plic_reg_match_addr_gp     = dev_addr_width_gp'('h0_b00?);

  localparam debug_reg_base_addr_gp     = dev_addr_width_gp'('h0_c000);
  localparam debug_reg_match_addr_gp    = dev_addr_width_gp'('h0_c???);

`endif

