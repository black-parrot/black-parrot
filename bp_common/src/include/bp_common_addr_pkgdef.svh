`ifndef BP_COMMON_ADDR_PKGDEF
`define BP_COMMON_ADDR_PKGDEF

  // TODO: These could be parameterizable, but there are some constraints of
  //   of bit placement within the local uncached space.
  // TL;DR 16MB ought to be enough for anyone
  localparam tile_id_width_gp  = 7;
  localparam dev_id_width_gp   = 4;
  localparam dev_addr_width_gp = 20;

  localparam boot_dev_gp  = 0;
  localparam host_dev_gp  = 1;
  localparam cfg_dev_gp   = 2;
  localparam clint_dev_gp = 3;
  localparam cache_dev_gp = 4;

                             // 0x00_0(nnnN)(D)(A_AAAA)
  localparam boot_dev_base_addr_gp     = 32'h0000_0000;
  localparam host_dev_base_addr_gp     = 32'h0010_0000;
  localparam cfg_dev_base_addr_gp      = 32'h0020_0000;
  localparam clint_dev_base_addr_gp    = 32'h0030_0000;
  localparam cache_dev_base_addr_gp    = 32'h0040_0000;

  localparam mipi_reg_base_addr_gp     = 32'h0030_0000;
  localparam mtimecmp_reg_base_addr_gp = 32'h0030_4000;
  localparam mtime_reg_addr_gp         = 32'h0030_bff8;
  localparam plic_reg_base_addr_gp     = 32'h0030_b000;

  localparam cache_tagfl_base_addr_gp  = 20'h0_0000;

  localparam bootrom_base_addr_gp      = 40'h00_0001_0000;
  localparam dram_base_addr_gp         = 40'h00_8000_0000;
  localparam coproc_base_addr_gp       = 40'h10_0000_0000;
  localparam global_base_addr_gp       = 40'h20_0000_0000;

`endif

