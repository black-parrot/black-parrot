
`ifndef BP_COMMON_HOST_PKGDEF_SVH
`define BP_COMMON_HOST_PKGDEF_SVH

  localparam bootrom_base_addr_gp      = 32'h0001_0000;
  localparam host_base_addr_gp         = 32'h0010_0000;
  localparam getchar_base_addr_gp      = 32'h0010_0000;
  localparam putchar_base_addr_gp      = 32'h0010_1000;
  localparam finish_base_addr_gp       = 32'h0010_2000;
  localparam putch_core_base_addr_gp   = 32'h0010_3000;

`endif

