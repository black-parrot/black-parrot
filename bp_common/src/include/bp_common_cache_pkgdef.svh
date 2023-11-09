
`ifndef BP_COMMON_CACHE_PKGDEF_SVH
`define BP_COMMON_CACHE_PKGDEF_SVH

  localparam cache_base_addr_gp          = (dev_id_width_gp+dev_addr_width_gp)'('h0400_0000);
  localparam cache_tagfl_addr_gp         = (dev_addr_width_gp)'('h0_0000);
  localparam cache_afl_addr_gp           = (dev_addr_width_gp)'('h0_1000);
  localparam cache_ainv_addr_gp          = (dev_addr_width_gp)'('h0_2000);
  localparam cache_aflinv_addr_gp        = (dev_addr_width_gp)'('h0_3000);
  localparam cache_tagfl_all_addr_gp     = (dev_addr_width_gp)'('h0_4000);
  localparam cache_taginv_all_addr_gp    = (dev_addr_width_gp)'('h0_5000);
  localparam cache_tagflinv_all_addr_gp  = (dev_addr_width_gp)'('h0_6000);

`endif

