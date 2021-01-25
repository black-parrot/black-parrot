`ifndef BP_FE_ICACHE_DEFINES_SVH
`define BP_FE_ICACHE_DEFINES_SVH

  `define declare_bp_fe_icache_pkt_s(vaddr_width_mp) \
    typedef struct packed                 \
    {                                     \
      logic [vaddr_width_mp-1:0] vaddr;   \
      bp_fe_icache_op_e          op;      \
    }  bp_fe_icache_pkt_s;

  `define bp_fe_icache_pkt_width(vaddr_width_mp) \
    (vaddr_width_mp+$bits(bp_fe_icache_op_e))

`endif

