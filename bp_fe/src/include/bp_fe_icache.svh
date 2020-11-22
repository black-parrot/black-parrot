`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH

  typedef enum
  {
    e_icache_fetch
    ,e_icache_fencei
  } bp_fe_icache_op_e;

`define declare_bp_fe_icache_pkt_s(vaddr_width_mp) \
  typedef struct packed                 \
  {                                     \
    logic [vaddr_width_mp-1:0] vaddr;   \
    bp_fe_icache_op_e op;               \
  }  bp_fe_icache_pkt_s;

`define bp_fe_icache_pkt_width(vaddr_width_mp) \
  (vaddr_width_mp+$bits(bp_fe_icache_op_e))

`endif

