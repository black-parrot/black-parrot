/**
 * bp_fe_lce.vh
 *
 */

`ifndef BP_FE_LCE_VH
`define BP_FE_LCE_VH

`include "bsg_defines.v"

`include "bp_common_me_if.vh"








/*
 * Declare all icache-lce-cce width calculations at once as localparams
 */
`define declare_bp_fe_tag_widths(ways_mp, sets_mp, lce_id_width_mp, cce_id_width_mp, data_width_mp, paddr_width_mp)   \
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_mp)                                                   \
    , localparam block_size_in_words_lp=ways_mp                                                             \
    , localparam data_mask_width_lp=(data_width_mp>>3)                                                      \
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)                                   \
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)                               \
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_mp)                                                    \
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)                          \
    , localparam tag_width_lp=(paddr_width_mp-block_offset_width_lp-index_width_lp                          \
)       

`endif
