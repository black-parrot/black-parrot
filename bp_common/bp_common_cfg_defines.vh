/**
 *
 * bp_common_cfg_defines.vh
 *
 */

`ifndef BP_COMMON_CFG_DEFINES_VH
`define BP_COMMON_CFG_DEFINES_VH

// Hardcoding hartid and lceid width limits us to 8 cores for our standard configurations,
//   but would allow the hierachical flow to reuse a single BP core for both dual-core and
//   oct-core configurations.
typedef logic[2:0] bp_mhartid_t;
typedef logic[3:0] bp_lce_id_t;

// Passing in proc_cfg as a port rather than a parameter limits some optimizations (need to 
//   route the ids through the chip), but it allows us to stamp out cores in our flow
// mhartid   - the hartid for the core. Since BP does not support SMT, hartid == coreid
// icache_id - the lceid used for coherence operations
// dcache_id - the lceid used for coherence operations 
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
