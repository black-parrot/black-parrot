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
typedef enum logic
{
  e_cce_mode_uncached
  ,e_cce_mode_normal
} bp_cce_mode_e;


typedef enum logic [15:0]{
  e_sacc_vdp
} bp_sacc_type_e;

typedef enum logic [15:0]{
  e_cacc_vdp
} bp_cacc_type_e;


`define declare_bp_cfg_bus_s(vaddr_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, cce_pc_width_mp, cce_instr_width_mp) \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                                    freeze;                                               \
    logic [core_id_width_mp-1:0]             core_id;                                              \
    logic [lce_id_width_mp-1:0]              icache_id;                                            \
    bp_lce_mode_e                            icache_mode;                                          \
    logic                                    npc_w_v;                                              \
    logic                                    npc_r_v;                                              \
    logic [vaddr_width_mp-1:0]               npc;                                                  \
    logic [lce_id_width_mp-1:0]              dcache_id;                                            \
    bp_lce_mode_e                            dcache_mode;                                          \
    logic [cce_id_width_mp-1:0]              cce_id;                                               \
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

`define bp_cfg_bus_width(vaddr_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, cce_pc_width_mp, cce_instr_width_mp) \
  (1                                \
   + core_id_width_mp               \
   + lce_id_width_mp                \
   + $bits(bp_lce_mode_e)           \
   + 1                              \
   + 1                              \
   + vaddr_width_mp                 \
   + lce_id_width_mp                \
   + $bits(bp_lce_mode_e)           \
   + cce_id_width_mp                \
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
  integer cc_x_dim;
  integer cc_y_dim;

  integer ic_y_dim;
  integer mc_y_dim;
  integer cac_x_dim;
  integer sac_x_dim;
  integer cacc_type;
  integer sacc_type;

  integer vaddr_width;
  integer paddr_width;
  integer asid_width;

  integer branch_metadata_fwd_width;
  integer btb_tag_width;
  integer btb_idx_width;
  integer bht_idx_width;
  integer ghist_width;

  integer itlb_els;
  integer dtlb_els;

  integer l1_writethrough;
  integer l1_coherent;
  integer dcache_sets;
  integer dcache_assoc;
  integer dcache_block_width;
  integer dcache_fill_width;
  integer icache_sets;
  integer icache_assoc;
  integer icache_block_width;
  integer icache_fill_width;
  integer acache_sets;
  integer acache_assoc;
  integer acache_block_width;
  integer acache_fill_width;
  integer cce_pc_width;
  integer ucode_cce;

  integer l2_en;
  integer l2_sets;
  integer l2_assoc;
  integer l2_outstanding_reqs;

  integer fe_queue_fifo_els;
  integer fe_cmd_fifo_els;

  integer async_coh_clk;
  integer coh_noc_max_credits;
  integer coh_noc_flit_width;
  integer coh_noc_cid_width;
  integer coh_noc_len_width;

  integer async_mem_clk;
  integer mem_noc_max_credits;
  integer mem_noc_flit_width;
  integer mem_noc_cid_width;
  integer mem_noc_len_width;

  integer async_io_clk;
  integer io_noc_max_credits;
  integer io_noc_flit_width;
  integer io_noc_did_width;
  integer io_noc_cid_width;
  integer io_noc_len_width;

}  bp_proc_param_s;

// For now, we have a fixed address map
typedef struct packed
{
  logic [2:0]  did;
  logic [36:0] addr;
}  bp_global_addr_s;

localparam cfg_cce_width_p  = 7;
localparam cfg_dev_width_p  = 4;
localparam cfg_addr_width_p = 20;
localparam cfg_data_width_p = 64;
typedef struct packed
{
  logic [8:0]  nonlocal;
  logic [6:0]  cce;
  logic [3:0]  dev;
  logic [19:0] addr;
}  bp_local_addr_s;

`define declare_bp_proc_params(bp_params_e_mp) \
  , localparam bp_proc_param_s proc_param_lp = all_cfgs_gp[bp_params_e_mp]                         \
                                                                                                   \
  , localparam cc_x_dim_p  = proc_param_lp.cc_x_dim                                                \
  , localparam cc_y_dim_p  = proc_param_lp.cc_y_dim                                                \
                                                                                                   \
  , localparam ic_x_dim_p = cc_x_dim_p                                                             \
  , localparam ic_y_dim_p = proc_param_lp.ic_y_dim                                                 \
  , localparam mc_x_dim_p = cc_x_dim_p                                                             \
  , localparam mc_y_dim_p = proc_param_lp.mc_y_dim                                                 \
  , localparam cac_x_dim_p = proc_param_lp.cac_x_dim                                               \
  , localparam cac_y_dim_p = cc_y_dim_p                                                            \
  , localparam sac_x_dim_p = proc_param_lp.sac_x_dim                                               \
  , localparam sac_y_dim_p = cc_y_dim_p                                                            \
  , localparam cacc_type_p = proc_param_lp.cacc_type                                               \
  , localparam sacc_type_p = proc_param_lp.sacc_type                                               \
                                                                                                   \
  , localparam num_core_p  = cc_x_dim_p * cc_y_dim_p                                               \
  , localparam num_io_p    = ic_x_dim_p * ic_y_dim_p                                               \
  , localparam num_l2e_p   = mc_x_dim_p * mc_y_dim_p                                               \
  , localparam num_cacc_p  = cac_x_dim_p * cac_y_dim_p                                             \
  , localparam num_sacc_p  = sac_x_dim_p * sac_y_dim_p                                             \
                                                                                                   \
  , localparam num_cce_p  = ((bp_params_e_mp == e_bp_half_core_cfg) | (bp_params_e_mp == e_bp_half_core_ucode_cce_cfg)) ? 1 : num_core_p + num_l2e_p    \
  , localparam num_lce_p  = ((bp_params_e_mp == e_bp_half_core_cfg) | (bp_params_e_mp == e_bp_half_core_ucode_cce_cfg)) ? 1 : 2*num_core_p + num_cacc_p \
                                                                                                   \
  , localparam core_id_width_p = `BSG_SAFE_CLOG2(cc_x_dim_p*cc_y_dim_p)                            \
  , localparam cce_id_width_p  = `BSG_SAFE_CLOG2((cc_x_dim_p*1+2)*(cc_y_dim_p*1+2))                \
  , localparam lce_id_width_p  = `BSG_SAFE_CLOG2((cc_x_dim_p*2+2)*(cc_y_dim_p*2+2))                \
                                                                                                   \
  , localparam vaddr_width_p = proc_param_lp.vaddr_width                                           \
  , localparam paddr_width_p = proc_param_lp.paddr_width                                           \
  , localparam asid_width_p  = proc_param_lp.asid_width                                            \
                                                                                                   \
  , localparam branch_metadata_fwd_width_p = proc_param_lp.branch_metadata_fwd_width               \
  , localparam btb_tag_width_p             = proc_param_lp.btb_tag_width                           \
  , localparam btb_idx_width_p             = proc_param_lp.btb_idx_width                           \
  , localparam bht_idx_width_p             = proc_param_lp.bht_idx_width                           \
  , localparam ghist_width_p               = proc_param_lp.ghist_width                             \
                                                                                                   \
  , localparam itlb_els_p              = proc_param_lp.itlb_els                                    \
  , localparam dtlb_els_p              = proc_param_lp.dtlb_els                                    \
                                                                                                   \
  , localparam l1_coherent_p              = proc_param_lp.l1_coherent                              \
  , localparam l1_writethrough_p          = proc_param_lp.l1_writethrough                          \
  , localparam dcache_sets_p              = proc_param_lp.dcache_sets                              \
  , localparam dcache_assoc_p             = proc_param_lp.dcache_assoc                             \
  , localparam dcache_block_width_p       = proc_param_lp.dcache_block_width                       \
  , localparam dcache_fill_width_p        = proc_param_lp.dcache_fill_width                        \
  , localparam icache_sets_p              = proc_param_lp.icache_sets                              \
  , localparam icache_assoc_p             = proc_param_lp.icache_assoc                             \
  , localparam icache_block_width_p       = proc_param_lp.icache_block_width                       \
  , localparam icache_fill_width_p        = proc_param_lp.icache_fill_width                        \
  , localparam acache_sets_p              = proc_param_lp.acache_sets                              \
  , localparam acache_assoc_p             = proc_param_lp.acache_assoc                             \
  , localparam acache_block_width_p       = proc_param_lp.acache_block_width                       \
  , localparam acache_fill_width_p        = proc_param_lp.acache_fill_width                        \
  , localparam lce_assoc_p                = `BSG_MAX(dcache_assoc_p,                               \
                                                     `BSG_MAX(icache_assoc_p, acache_assoc_p))     \
  , localparam lce_assoc_width_p          = `BSG_SAFE_CLOG2(lce_assoc_p)                           \
  , localparam lce_sets_p                 = `BSG_MAX(dcache_sets_p,                                \
                                                     `BSG_MAX(icache_sets_p, acache_sets_p))       \
  , localparam lce_sets_width_p           = `BSG_SAFE_CLOG2(lce_sets_p)                            \
                                                                                                   \
  , localparam cce_block_width_p          =  `BSG_MAX(dcache_block_width_p,                        \
                                                     `BSG_MAX(icache_block_width_p,                \
                                                       acache_block_width_p))                      \
                                                                                                   \
                                                                                                   \
  , localparam cce_pc_width_p             = proc_param_lp.cce_pc_width                             \
  , localparam num_cce_instr_ram_els_p    = 2**cce_pc_width_p                                      \
  , localparam cce_way_groups_p           = `BSG_MAX(dcache_sets_p, icache_sets_p)                 \
  , localparam cce_instr_width_p          = 34                                                     \
  , localparam ucode_cce_p                = proc_param_lp.ucode_cce                                \
                                                                                                   \
  , localparam l2_en_p    = proc_param_lp.l2_en                                                    \
  , localparam l2_sets_p  = proc_param_lp.l2_sets                                                  \
  , localparam l2_assoc_p = proc_param_lp.l2_assoc                                                 \
  , localparam l2_outstanding_reqs_p = proc_param_lp.l2_outstanding_reqs                           \
                                                                                                   \
  , localparam fe_queue_fifo_els_p = proc_param_lp.fe_queue_fifo_els                               \
  , localparam fe_cmd_fifo_els_p   = proc_param_lp.fe_cmd_fifo_els                                 \
                                                                                                   \
  , localparam async_coh_clk_p        = proc_param_lp.async_coh_clk                                \
  , localparam coh_noc_max_credits_p  = proc_param_lp.coh_noc_max_credits                          \
  , localparam coh_noc_flit_width_p   = proc_param_lp.coh_noc_flit_width                           \
  , localparam coh_noc_cid_width_p    = proc_param_lp.coh_noc_cid_width                            \
  , localparam coh_noc_len_width_p    = proc_param_lp.coh_noc_len_width                            \
  , localparam coh_noc_y_cord_width_p = `BSG_SAFE_CLOG2(ic_y_dim_p+cc_y_dim_p+mc_y_dim_p+1)        \
  , localparam coh_noc_x_cord_width_p = `BSG_SAFE_CLOG2(sac_x_dim_p+cc_x_dim_p+cac_x_dim_p+1)      \
  , localparam coh_noc_dims_p         = 2                                                          \
  , localparam coh_noc_dirs_p         = coh_noc_dims_p*2 + 1                                       \
  , localparam coh_noc_trans_p        = 0                                                          \
  , localparam int coh_noc_cord_markers_pos_p[coh_noc_dims_p:0] = coh_noc_trans_p                  \
      ? '{coh_noc_x_cord_width_p+coh_noc_y_cord_width_p, coh_noc_y_cord_width_p, 0}                \
      : '{coh_noc_y_cord_width_p+coh_noc_x_cord_width_p, coh_noc_x_cord_width_p, 0}                \
  , localparam coh_noc_cord_width_p   = coh_noc_cord_markers_pos_p[coh_noc_dims_p]                 \
                                                                                                   \
  , localparam async_mem_clk_p           = proc_param_lp.async_mem_clk                             \
  , localparam mem_noc_max_credits_p     = proc_param_lp.mem_noc_max_credits                       \
  , localparam mem_noc_flit_width_p      = proc_param_lp.mem_noc_flit_width                        \
  , localparam mem_noc_cid_width_p       = proc_param_lp.mem_noc_cid_width                         \
  , localparam mem_noc_len_width_p       = proc_param_lp.mem_noc_len_width                         \
  , localparam mem_noc_y_cord_width_p    = `BSG_SAFE_CLOG2(ic_y_dim_p+cc_y_dim_p+mc_y_dim_p+1)     \
  , localparam mem_noc_x_cord_width_p    = `BSG_SAFE_CLOG2(sac_x_dim_p+cc_x_dim_p+cac_x_dim_p+1)   \
  , localparam mem_noc_dims_p            = 1                                                       \
  , localparam mem_noc_cord_dims_p       = 2                                                       \
  , localparam mem_noc_dirs_p            = mem_noc_dims_p*2 + 1                                    \
  , localparam mem_noc_trans_p           = 1                                                       \
  , localparam int mem_noc_cord_markers_pos_p[mem_noc_cord_dims_p:0] = mem_noc_trans_p             \
      ? '{mem_noc_x_cord_width_p+mem_noc_y_cord_width_p, mem_noc_y_cord_width_p, 0}                \
      : '{mem_noc_y_cord_width_p+mem_noc_x_cord_width_p, mem_noc_x_cord_width_p, 0}                \
  , localparam mem_noc_cord_width_p      = mem_noc_cord_markers_pos_p[mem_noc_dims_p]              \
                                                                                                   \
  , localparam async_io_clk_p           = proc_param_lp.async_io_clk                               \
  , localparam io_noc_max_credits_p     = proc_param_lp.io_noc_max_credits                         \
  , localparam io_noc_did_width_p       = proc_param_lp.io_noc_did_width                           \
  , localparam io_noc_flit_width_p      = proc_param_lp.io_noc_flit_width                          \
  , localparam io_noc_cid_width_p       = proc_param_lp.io_noc_cid_width                           \
  , localparam io_noc_len_width_p       = proc_param_lp.io_noc_len_width                           \
  , localparam io_noc_y_cord_width_p    = `BSG_SAFE_CLOG2(ic_y_dim_p+1)                            \
  , localparam io_noc_x_cord_width_p    = io_noc_did_width_p                                       \
  , localparam io_noc_dims_p            = 1                                                        \
  , localparam io_noc_cord_dims_p       = 2                                                        \
  , localparam io_noc_dirs_p            = io_noc_cord_dims_p*2 + 1                                 \
  , localparam io_noc_trans_p           = 0                                                        \
  , localparam int io_noc_cord_markers_pos_p[io_noc_cord_dims_p:0] = io_noc_trans_p                \
      ? '{io_noc_x_cord_width_p+io_noc_y_cord_width_p, io_noc_y_cord_width_p, 0}                   \
      : '{io_noc_y_cord_width_p+io_noc_x_cord_width_p, io_noc_x_cord_width_p, 0}                   \
  , localparam io_noc_cord_width_p      = io_noc_cord_markers_pos_p[io_noc_dims_p]                 \
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
