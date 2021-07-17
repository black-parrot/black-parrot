
`ifndef BP_COMMON_HOST_PKGDEF_SVH
`define BP_COMMON_HOST_PKGDEF_SVH


  localparam host_base_addr_gp         = (dev_id_width_gp+dev_addr_width_gp)'('h0010_0000);
  localparam host_match_addr_gp        = (dev_id_width_gp+dev_addr_width_gp)'('h001?_????);

  localparam getchar_base_addr_gp      = (dev_addr_width_gp)'('h0_0000);
  localparam getchar_match_addr_gp     = (dev_addr_width_gp)'('h0_0???);

  localparam putchar_base_addr_gp      = (dev_addr_width_gp)'('h0_1000);
  localparam putchar_match_addr_gp     = (dev_addr_width_gp)'('h0_1???);

  localparam finish_base_addr_gp       = (dev_addr_width_gp)'('h0_2000);
  localparam finish_match_addr_gp      = (dev_addr_width_gp)'('h0_2???);

  localparam putch_core_base_addr_gp   = (dev_addr_width_gp)'('h0_3000);
  localparam putch_core_match_addr_gp  = (dev_addr_width_gp)'('h0_3???);

  localparam bootrom_base_addr_gp      = (dev_addr_width_gp)'('h1_0000);
  localparam bootrom_match_addr_gp     = (dev_addr_width_gp)'('h1_????);


`endif

