`ifndef BP_ME_CCE_DEFINES_SVH
`define BP_ME_CCE_DEFINES_SVH

  // Miss Status Handling Register Struct
  // This struct tracks the information required to process an LCE request
  `define declare_bp_cce_mshr_s(paddr_width_mp, lce_id_width_mp, cce_id_width_mp, did_width_mp, lce_assoc_mp) \
    typedef struct packed                                                   \
    {                                                                       \
      logic [lce_id_width_mp-1:0]                   owner_lce_id;           \
      logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]     owner_way_id;           \
      bp_coh_states_e                               owner_coh_state;        \
      bp_cce_flags_s                                flags;                  \
      bp_coh_states_e                               lru_coh_state;          \
      logic [paddr_width_mp-1:0]                    lru_paddr;              \
      logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]     lru_way_id;             \
      logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]     way_id;                 \
      logic [paddr_width_mp-1:0]                    paddr;                  \
      bp_coh_states_e                               next_coh_state;         \
      logic [lce_id_width_mp-1:0]                   lce_id;                 \
      logic [did_width_mp-1:0]                      src_did;                \
      bp_bedrock_msg_size_e                         msg_size;               \
      bp_bedrock_wr_subop_e                         msg_subop;              \
      bp_bedrock_msg_u                              msg_type;               \
    } bp_cce_mshr_s

  `define declare_bp_cce_dir_entry_s(tag_width_mp) \
    typedef struct packed                            \
    {                                                \
      logic [tag_width_mp-1:0] tag;                  \
      bp_coh_states_e          state;                \
    } dir_entry_s

  `define bp_cce_mshr_width(paddr_width_mp, lce_id_width_mp, cce_id_width_mp, did_width_mp, lce_assoc_mp) \
    ((2*lce_id_width_mp)+(3*`BSG_SAFE_CLOG2(lce_assoc_mp))+(2*paddr_width_mp)       \
     +(3*$bits(bp_coh_states_e))+$bits(bp_cce_flags_s)+$bits(bp_bedrock_msg_size_e) \
     +$bits(bp_bedrock_msg_u)+$bits(bp_bedrock_wr_subop_e)+did_width_mp)

  `define bp_cce_dir_entry_width(tag_width_mp) \
    ($bits(bp_coh_states_e)+tag_width_mp)

`endif

