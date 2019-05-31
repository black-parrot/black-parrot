
`ifndef BP_CFG_LINK_VH
`define BP_CFG_LINK_VH

  `define declare_bp_cfg_link_payload_s(cfg_addr_width_mp, cfg_data_width_mp) \
    typedef struct packed                 \
    {                                     \
      logic [cfg_addr_width_mp-1:0] addr; \
      logic [cfg_data_width_mp-1:0] data; \
    }  bp_cfg_link_payload_s

  `define bp_cfg_link_payload_width(cfg_addr_width_mp, cfg_data_width_mp) \
    (cfg_addr_width_mp+cfg_data_width_mp)

`endif

