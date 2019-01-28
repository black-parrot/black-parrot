/**
 *
 * bp_common_cfg_defines.vh
 *
 */

`ifndef BP_COMMON_CFG_DEFINES_VH
`define BP_COMMON_CFG_DEFINES_VH

typedef logic[2:0] bp_mhartid_t;
typedef logic[3:0] bp_lce_id_t;

typedef struct packed
{
  bp_mhartid_t mhartid;
  bp_lce_id_t  icache_id;
  bp_lce_id_t  dcache_id;
}  bp_proc_cfg_s;

`define bp_mhartid_width \
  ($bits(bp_mhartid_t))

`define bp_lce_id_width \
  ($bits(bp_lce_id_t))

`define bp_proc_cfg_width \
  ($bits(bp_proc_cfg_s))

`endif
