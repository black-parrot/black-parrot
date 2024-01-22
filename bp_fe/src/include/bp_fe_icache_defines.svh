`ifndef BP_FE_ICACHE_DEFINES_SVH
`define BP_FE_ICACHE_DEFINES_SVH

  `define declare_bp_fe_icache_pkt_s(vaddr_width_mp) \
    typedef struct packed                 \
    {                                     \
      logic [vaddr_width_mp-1:0] vaddr;   \
      bp_fe_icache_op_e          op;      \
      logic                      spec;    \
    }  bp_fe_icache_pkt_s

  `define bp_fe_icache_pkt_width(vaddr_width_mp) \
    (1+vaddr_width_mp+$bits(bp_fe_icache_op_e))

  `define declare_bp_fe_icache_engine_if(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp) \
    `declare_bp_cache_engine_generic_if(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp, fe_icache)

  `define declare_bp_fe_icache_engine_if_widths(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp) \
    `declare_bp_cache_engine_generic_if_widths(addr_width_mp, tag_width_mp, sets_mp, ways_mp, data_width_mp, block_width_mp, fill_width_mp, id_width_mp, icache)

`endif

