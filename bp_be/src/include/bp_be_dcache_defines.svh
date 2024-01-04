
`ifndef BP_BE_DCACHE_DEFINES_SVH
`define BP_BE_DCACHE_DEFINES_SVH

  `define declare_bp_be_dcache_wbuf_entry_s(caddr_width_mp, ways_mp) \
    typedef struct packed                            \
    {                                                \
      logic                                snoop;    \
      logic [ways_mp-1:0]                  bank_sel; \
      logic [(dword_width_gp>>3)-1:0]      mask;     \
      logic [dword_width_gp-1:0]           data;     \
      logic [caddr_width_mp-1:0]           caddr;    \
    } bp_be_dcache_wbuf_entry_s

  `define bp_be_dcache_wbuf_entry_width(caddr_width_mp, ways_mp) \
    (1+ways_mp+(dword_width_gp>>3)+dword_width_gp+caddr_width_mp)

  `define declare_bp_be_dcache_engine_if(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp) \
    `declare_bp_cache_engine_generic_if(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp, be_dcache)

  `define declare_bp_be_dcache_engine_if_widths(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp) \
    `declare_bp_cache_engine_generic_if_widths(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp, dcache)

`endif

