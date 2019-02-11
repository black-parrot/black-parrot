/**
 *
 * bp_common_cfg_defines.vh
 *
 */

`ifndef BP_COMMON_CFG_DEFINES_VH
`define BP_COMMON_CFG_DEFINES_VH

// Thoughts: 
// Hardcoding hartid and lceid width limits us to 8 cores for our standard configurations,
//   but would allow the hierachical flow to reuse a single BP core for both dual-core and
//   oct-core configurations.
// typedef logic[2:0] bp_mhartid_t;
// typedef logic[3:0] bp_lce_id_t;

// Passing in proc_cfg as a port rather than a parameter limits some optimizations (need to 
//   route the ids through the chip), but it allows us to stamp out cores in our flow
// mhartid   - the hartid for the core. Since BP does not support SMT, hartid == coreid
// icache_id - the lceid used for coherence operations
// dcache_id - the lceid used for coherence operations 
`define declare_bp_common_proc_cfg_s(num_core_mp, num_lce_mp)                                      \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic[`BSG_SAFE_CLOG2(num_core_mp)-1:0] mhartid;                                               \
    logic[`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  icache_id;                                             \
    logic[`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  dcache_id;                                             \
  }  bp_proc_cfg_s;

`define bp_proc_cfg_width(num_core_mp, num_lce_mp)                                                 \
  (`BSG_SAFE_CLOG2(num_core_mp) + 2 * `BSG_SAFE_CLOG2(num_lce_mp))

`endif
