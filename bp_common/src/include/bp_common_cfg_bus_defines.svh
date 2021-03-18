`ifndef BP_COMMON_CFG_BUS_DEFINES_SVH
`define BP_COMMON_CFG_BUS_DEFINES_SVH

  `define declare_bp_cfg_bus_s(domain_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp) \
    typedef struct packed                             \
    {                                                 \
      logic                        freeze;            \
      logic [core_id_width_mp-1:0] core_id;           \
      logic [lce_id_width_mp-1:0]  icache_id;         \
      bp_lce_mode_e                icache_mode;       \
      logic [lce_id_width_mp-1:0]  dcache_id;         \
      bp_lce_mode_e                dcache_mode;       \
      logic [cce_id_width_mp-1:0]  cce_id;            \
      bp_cce_mode_e                cce_mode;          \
      logic [domain_width_mp-1:0]  domain_mask;       \
    }  bp_cfg_bus_s

  `define bp_cfg_bus_width(domain_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp) \
    (1                                \
     + core_id_width_mp               \
     + lce_id_width_mp                \
     + $bits(bp_lce_mode_e)           \
     + lce_id_width_mp                \
     + $bits(bp_lce_mode_e)           \
     + cce_id_width_mp                \
     + $bits(bp_cce_mode_e)           \
     + domain_width_mp                \
     )

`endif

