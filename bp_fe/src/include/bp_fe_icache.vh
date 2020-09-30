`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH


  typedef enum
  {
    e_icache_fetch
    ,e_icache_fencei
    ,e_icache_fill
  } bp_fe_icache_op_e;

`define declare_bp_fe_icache_pkt_s(vaddr_width_mp, icache_assoc_p) \
  typedef struct packed                 \
  {                                     \
    logic [vaddr_width_mp-1:0] vaddr;   \
    bp_fe_icache_op_e op;               \
    logic [icache_assoc_p-2:0] miss_lru;\
  }  bp_fe_icache_pkt_s;

`define bp_fe_icache_pkt_width(vaddr_width_mp, icache_assoc_mp) \
  (vaddr_width_mp+$bits(bp_fe_icache_op_e)+icache_assoc_mp-1)

`endif

