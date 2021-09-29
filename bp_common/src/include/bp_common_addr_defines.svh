`ifndef BP_COMMON_ADDR_DEFINES_SVH
`define BP_COMMON_ADDR_DEFINES_SVH

  `define declare_bp_memory_map(paddr_width_mp, daddr_width_mp) \
    typedef struct packed                                           \
    {                                                               \
      logic [paddr_width_mp-daddr_width_mp-1:0] hio;                \
      logic [daddr_width_mp-1:0]                daddr;              \
    }  bp_global_addr_s;                                            \
                                                                    \
    typedef struct packed                                           \
    {                                                               \
      logic [paddr_width_mp-tile_id_width_gp-dev_id_width_gp-dev_addr_width_gp-1:0] \
                                     nonlocal;         \
      logic [tile_id_width_gp-1:0]   tile;             \
      logic [dev_id_width_gp-1:0]    dev;              \
      logic [dev_addr_width_gp-1:0]  addr;             \
    }  bp_local_addr_s

`endif

