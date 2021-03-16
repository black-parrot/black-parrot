
`ifndef BP_ME_CACHE_DEFINES_SVH
`define BP_ME_CACHE_DEFINES_SVH

  // TODO: Replace with basejump definition once merged
  `define declare_bsg_cache_wh_header_flit_s(wh_flit_width_mp,wh_cord_width_mp,wh_len_width_mp,wh_cid_width_mp) \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [wh_flit_width_mp-(wh_cord_width_mp*2)-1-wh_len_width_mp-(wh_cid_width_mp*2)-1:0]      \
            unused;                                                                                \
      logic write_not_read;                                                                        \
      logic [wh_cid_width_mp-1:0] src_cid;                                                         \
      logic [wh_cord_width_mp-1:0] src_cord;                                                       \
      logic [wh_cid_width_mp-1:0] cid;                                                             \
      logic [wh_len_width_mp-1:0] len;                                                             \
      logic [wh_cord_width_mp-1:0] cord;                                                           \
    }  bsg_cache_wh_header_flit_s

`endif

