
`ifndef BP_COMMON_CFG_LINK_VH
`define BP_COMMON_CFG_LINK_VH

  `define declare_bp_cfg_link_cmd_s(cfg_addr_width_mp, cfg_data_width_mp) \
    typedef struct packed                 \
    {                                     \
      logic               write_not_read; \
      logic [cfg_addr_width_mp-1:0] addr; \
      logic [cfg_data_width_mp-1:0] data; \
    }  bp_cfg_link_cmd_s

  `define bp_cfg_link_cmd_width(cfg_addr_width_mp, cfg_data_width_mp) \
    (1+cfg_addr_width_mp+cfg_data_width_mp)

`endif

