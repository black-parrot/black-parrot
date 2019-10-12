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

typedef enum logic {
  e_lce_mode_uncached
  ,e_lce_mode_normal
} bp_lce_mode_e;

// CCE Operating Mode
// e_cce_mode_uncached: CCE supports uncached requests only
// e_cce_mode_normal: CCE operates as a microcoded engine, features depend on microcode provided
typedef enum bit
{
  e_cce_mode_uncached = 1'b0
  ,e_cce_mode_normal  = 1'b1
} bp_cce_mode_e;

`define declare_bp_cfg_bus_s(vaddr_width_mp, num_core_mp, num_cce_mp, num_lce_mp, cce_pc_width_mp, cce_instr_width_mp) \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                                    freeze;                                               \
    logic [`BSG_SAFE_CLOG2(num_core_mp)-1:0] core_id;                                              \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  icache_id;                                            \
    bp_lce_mode_e                            icache_mode;                                          \
    logic                                    npc_w_v;                                              \
    logic                                    npc_r_v;                                              \
    logic [vaddr_width_mp-1:0]               npc;                                                  \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  dcache_id;                                            \
    bp_lce_mode_e                            dcache_mode;                                          \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]  cce_id;                                               \
    bp_cce_mode_e                            cce_mode;                                             \
    logic                                    cce_ucode_w_v;                                        \
    logic                                    cce_ucode_r_v;                                        \
    logic [cce_pc_width_mp-1:0]              cce_ucode_addr;                                       \
    logic [cce_instr_width_mp-1:0]           cce_ucode_data;                                       \
    logic                                    irf_w_v;                                              \
    logic                                    irf_r_v;                                              \
    logic [reg_addr_width_p-1:0]             irf_addr;                                             \
    logic [dword_width_p-1:0]                irf_data;                                             \
    logic                                    csr_w_v;                                              \
    logic                                    csr_r_v;                                              \
    logic [csr_addr_width_p-1:0]             csr_addr;                                             \
    logic [dword_width_p-1:0]                csr_data;                                             \
    logic                                    priv_w_v;                                             \
    logic                                    priv_r_v;                                             \
    logic [1:0]                              priv_data;                                            \
  }  bp_cfg_bus_s

`define bp_cfg_bus_width(vaddr_width_mp, num_core_mp, num_cce_mp, num_lce_mp, cce_pc_width_mp, cce_instr_width_mp) \
  (1                                \
   + `BSG_SAFE_CLOG2(num_core_mp)   \
   + `BSG_SAFE_CLOG2(num_lce_mp)    \
   + $bits(bp_lce_mode_e)           \
   + 2                              \
   + vaddr_width_mp                 \
   + `BSG_SAFE_CLOG2(num_lce_mp)    \
   + $bits(bp_lce_mode_e)           \
   + `BSG_SAFE_CLOG2(num_cce_mp)    \
   + $bits(bp_cce_mode_e)           \
   + 2                              \
   + cce_pc_width_mp                \
   + cce_instr_width_mp             \
   + 2                              \
   + reg_addr_width_p               \
   + dword_width_p                  \
   + 2                              \
   + csr_addr_width_p               \
   + dword_width_p                  \
   + 2                              \
   + 2                              \
   )


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
  integer cce_pc_width;
  integer cce_instr_width;

  integer fe_queue_fifo_els;
  integer fe_cmd_fifo_els;

  integer async_coh_clk;
  integer coh_noc_flit_width;
  integer coh_noc_cid_width;
  integer coh_noc_len_width;
  integer coh_noc_y_cord_width;
  integer coh_noc_x_cord_width;
  integer coh_noc_y_dim;
  integer coh_noc_x_dim;

  integer cfg_core_width;
  integer cfg_addr_width;
  integer cfg_data_width;

  integer async_mem_clk;
  integer mem_noc_max_credits;
  integer mem_noc_flit_width;
  integer mem_noc_reserved_width;
  integer mem_noc_cid_width;
  integer mem_noc_len_width;
  integer mem_noc_y_cord_width;
  integer mem_noc_x_cord_width;
  integer mem_noc_y_dim;
  integer mem_noc_x_dim;
}  bp_proc_param_s;

`define declare_bp_proc_params(bp_params_e_mp) \
  , localparam bp_proc_param_s proc_param_lp = all_cfgs_gp[bp_params_e_mp]                            \
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
  , localparam lce_sets_p                 = proc_param_lp.lce_sets                                 \
  , localparam lce_assoc_p                = proc_param_lp.lce_assoc                                \
  , localparam cce_block_width_p          = proc_param_lp.cce_block_width                          \
  , localparam cce_pc_width_p             = proc_param_lp.cce_pc_width                             \
  , localparam cce_instr_width_p          = proc_param_lp.cce_instr_width                          \
  , localparam num_cce_instr_ram_els_p    = 2**cce_pc_width_p                                      \
                                                                                                   \
  , localparam fe_queue_fifo_els_p = proc_param_lp.fe_queue_fifo_els                               \
  , localparam fe_cmd_fifo_els_p   = proc_param_lp.fe_cmd_fifo_els                                 \
                                                                                                   \
  , localparam async_coh_clk_p        = proc_param_lp.async_coh_clk                                \
  , localparam coh_noc_flit_width_p   = proc_param_lp.coh_noc_flit_width                           \
  , localparam coh_noc_cid_width_p    = proc_param_lp.coh_noc_cid_width                            \
  , localparam coh_noc_len_width_p    = proc_param_lp.coh_noc_len_width                            \
  , localparam coh_noc_y_cord_width_p = proc_param_lp.coh_noc_y_cord_width                         \
  , localparam coh_noc_x_cord_width_p = proc_param_lp.coh_noc_x_cord_width                         \
  , localparam coh_noc_y_dim_p        = proc_param_lp.coh_noc_y_dim                                \
  , localparam coh_noc_x_dim_p        = proc_param_lp.coh_noc_x_dim                                \
  , localparam coh_noc_cord_width_p   = coh_noc_x_cord_width_p + coh_noc_y_cord_width_p            \
  , localparam coh_noc_dims_p         = 2                                                          \
  , localparam coh_noc_dirs_p         = coh_noc_dims_p*2 + 1                                       \
  , localparam int coh_noc_cord_markers_pos_p[coh_noc_dims_p:0] =                                  \
      '{coh_noc_cord_width_p, coh_noc_x_cord_width_p, 0}                                           \
                                                                                                   \
  , localparam cfg_core_width_p = proc_param_lp.cfg_core_width                                     \
  , localparam cfg_addr_width_p = proc_param_lp.cfg_addr_width                                     \
  , localparam cfg_data_width_p = proc_param_lp.cfg_data_width                                     \
                                                                                                   \
  , localparam async_mem_clk_p           = proc_param_lp.async_mem_clk                             \
  , localparam mem_noc_max_credits_p     = proc_param_lp.mem_noc_max_credits                       \
  , localparam mem_noc_flit_width_p      = proc_param_lp.mem_noc_flit_width                        \
  , localparam mem_noc_reserved_width_p  = proc_param_lp.mem_noc_reserved_width                    \
  , localparam mem_noc_cid_width_p       = proc_param_lp.mem_noc_cid_width                         \
  , localparam mem_noc_len_width_p       = proc_param_lp.mem_noc_len_width                         \
  , localparam mem_noc_y_cord_width_p    = proc_param_lp.mem_noc_y_cord_width                      \
  , localparam mem_noc_x_cord_width_p    = proc_param_lp.mem_noc_x_cord_width                      \
  , localparam mem_noc_y_dim_p           = proc_param_lp.mem_noc_y_dim                             \
  , localparam mem_noc_x_dim_p           = proc_param_lp.mem_noc_x_dim                             \
  , localparam mem_noc_cord_width_p      = mem_noc_x_cord_width_p + mem_noc_y_cord_width_p         \
  , localparam mem_noc_dims_p            = 2                                                       \
  , localparam mem_noc_dirs_p            = mem_noc_dims_p*2 + 1                                    \
  , localparam int mem_noc_cord_markers_pos_p[mem_noc_dims_p:0] =                                  \
      '{mem_noc_cord_width_p, mem_noc_x_cord_width_p, 0}                                           \
                                                                                                   \
  , localparam num_mem_p     = mem_noc_x_dim_p + 2                                                 \
  , localparam clint_x_pos_p = (mem_noc_x_dim_p+1)/2                                               \
                                                                                                   \
  , localparam dword_width_p       = 64                                                            \
  , localparam instr_width_p       = 32                                                            \
  , localparam csr_addr_width_p    = 12                                                            \
  , localparam reg_addr_width_p    = 5                                                             \
  , localparam page_offset_width_p = 12                                                            \
                                                                                                   \
  , localparam vtag_width_p  = proc_param_lp.vaddr_width - page_offset_width_p                     \
  , localparam ptag_width_p  = proc_param_lp.paddr_width - page_offset_width_p                     \

`endif

