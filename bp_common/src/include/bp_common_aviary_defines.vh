/**
 *
 * bp_common_aviary_defines.vh
 *
 */

`ifndef BP_COMMON_AVIARY_DEFINES_VH
`define BP_COMMON_AVIARY_DEFINES_VH

// Thoughts: 
// Hardcoding hartid and lceid width limits us to 8 cores for our standard configurations,
//   but would allow the hierachical flow to reuse a single BP core for both dual-core and
//   oct-core configurations.
// typedef logic[2:0] bp_mhartid_t;
// typedef logic[3:0] bp_lce_id_t;
//
// We could pass pc_entry_point here as logic.  We could also pass it as a bsg_tag message

// Passing in proc_cfg as a port rather than a parameter limits some optimizations (need to 
//   route the ids through the chip), but it allows us to stamp out cores in our flow
// mhartid   - the hartid for the core. Since BP does not support SMT, hartid == coreid
// icache_id - the lceid used for coherence operations
// dcache_id - the lceid used for coherence operations 
`define declare_bp_common_proc_cfg_s(num_core_mp, num_cce_mp, num_lce_mp)                          \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [`BSG_SAFE_CLOG2(num_core_mp)-1:0] core_id;                                              \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]  cce_id;                                               \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  icache_id;                                            \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  dcache_id;                                            \
  }  bp_proc_cfg_s;

`define bp_proc_cfg_width(num_core_mp, num_cce_mp, num_lce_mp)                                     \
  (`BSG_SAFE_CLOG2(num_core_mp) + `BSG_SAFE_CLOG2(num_cce_mp) + 2 * `BSG_SAFE_CLOG2(num_lce_mp))

typedef struct packed
{
  integer num_core;
  integer num_cce;
  integer num_lce;

  integer vaddr_width;
  integer paddr_width;
  integer asid_width;

  integer branch_metadata_fwd_width;
  integer btb_tag_width;
  integer btb_idx_width;
  integer bht_idx_width;
  integer ras_idx_width;

  integer itlb_els;
  integer dtlb_els;

  integer lce_sets;
  integer lce_assoc;
  integer cce_block_width;
  integer num_cce_instr_ram_els;

  integer fe_queue_fifo_els;
  integer fe_cmd_fifo_els;

  integer noc_width;
  integer max_credits;

  integer dword_width;
  integer instr_width;
  integer reg_addr_width;
  integer page_offset_width;
}  bp_proc_param_s;

`define declare_bp_proc_params(bp_cfg_e_mp) \
  , localparam bp_proc_param_s proc_param_lp = all_cfgs_gp[bp_cfg_e_mp]                            \
                                                                                                   \
  , localparam num_core_p = proc_param_lp.num_core                                                 \
  , localparam num_cce_p  = proc_param_lp.num_cce                                                  \
  , localparam num_lce_p  = proc_param_lp.num_lce                                                  \
                                                                                                   \
  , localparam vaddr_width_p = proc_param_lp.vaddr_width                                           \
  , localparam paddr_width_p = proc_param_lp.paddr_width                                           \
  , localparam asid_width_p  = proc_param_lp.asid_width                                            \
                                                                                                   \
  , localparam branch_metadata_fwd_width_p = proc_param_lp.branch_metadata_fwd_width               \
  , localparam btb_tag_width_p             = proc_param_lp.btb_tag_width                           \
  , localparam btb_idx_width_p             = proc_param_lp.btb_idx_width                           \
  , localparam bht_idx_width_p             = proc_param_lp.bht_idx_width                           \
  , localparam ras_idx_width_p             = proc_param_lp.ras_idx_width                           \
                                                                                                   \
  , localparam itlb_els_p              = proc_param_lp.itlb_els                                    \
  , localparam dtlb_els_p              = proc_param_lp.dtlb_els                                    \
                                                                                                   \
  , localparam lce_sets_p              = proc_param_lp.lce_sets                                    \
  , localparam lce_assoc_p             = proc_param_lp.lce_assoc                                   \
  , localparam cce_block_width_p       = proc_param_lp.cce_block_width                             \
  , localparam num_cce_instr_ram_els_p = proc_param_lp.num_cce_instr_ram_els                       \
                                                                                                   \
  , localparam fe_queue_fifo_els_p = proc_param_lp.fe_queue_fifo_els                               \
  , localparam fe_cmd_fifo_els_p   = proc_param_lp.fe_cmd_fifo_els                                 \
                                                                                                   \
  , localparam noc_width_p   = proc_param_lp.noc_width                                             \
  , localparam max_credits_p = proc_param_lp.max_credits                                           \
                                                                                                   \
  , localparam dword_width_p       = proc_param_lp.dword_width                                     \
  , localparam instr_width_p       = proc_param_lp.instr_width                                     \
  , localparam reg_addr_width_p    = proc_param_lp.reg_addr_width                                  \
  , localparam page_offset_width_p = proc_param_lp.page_offset_width                               \
                                                                                                   \
  , localparam vtag_width_p        = proc_param_lp.vaddr_width - proc_param_lp.page_offset_width   \
  , localparam ptag_width_p        = proc_param_lp.paddr_width - proc_param_lp.page_offset_width

`endif

