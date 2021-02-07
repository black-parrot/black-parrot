`ifndef BP_COMMON_ADDR_PKGDEF
`define BP_COMMON_ADDR_PKGDEF

  // For now, we have a fixed address map
  typedef struct packed
  {
    logic [2:0]  did;
    logic [36:0] addr;
  }  bp_global_addr_s;

  typedef struct packed
  {
    logic [8:0]  nonlocal;
    logic [6:0]  cce;
    logic [3:0]  dev;
    logic [19:0] addr;
  }  bp_local_addr_s;

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

  // 4 GB
  localparam dram_max_size_gp          = 1 << 31;

`endif

