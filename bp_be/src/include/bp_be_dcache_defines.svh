
`ifndef BP_BE_DCACHE_DEFINES_SVH
`define BP_BE_DCACHE_DEFINES_SVH

  `define declare_bp_be_dcache_wbuf_entry_s(paddr_width_mp, ways_mp) \
    typedef struct packed                                        \
    {                                                            \
      logic [paddr_width_mp-1:0]           paddr;                \
      logic [dword_width_gp-1:0]           data;                 \
      logic [(dword_width_gp>>3)-1:0]      mask;                 \
      logic [`BSG_SAFE_CLOG2(ways_mp)-1:0] way_id;               \
    } bp_be_dcache_wbuf_entry_s

  `define bp_be_dcache_wbuf_entry_width(paddr_width_mp, ways_mp) \
    (paddr_width_mp+dword_width_gp+(dword_width_gp>>3)+`BSG_SAFE_CLOG2(ways_mp))

`endif

