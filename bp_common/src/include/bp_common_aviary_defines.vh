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
  
  // Place of atomic operation
  typedef enum logic [1:0] {
    e_none
    , e_l1
    , e_l2
  } bp_atomic_op_e;
  
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
      logic [lce_id_width_mp-1:0]              dcache_id;                                            \
      bp_lce_mode_e                            dcache_mode;                                          \
      logic [cce_id_width_mp-1:0]              cce_id;                                               \
      bp_cce_mode_e                            cce_mode;                                             \
      logic [7:0]                              domain;                                               \
      logic                                    sac;                                                  \
    }  bp_cfg_bus_s
  
  `define bp_cfg_bus_width(vaddr_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, cce_pc_width_mp, cce_instr_width_mp) \
    (1                                \
     + core_id_width_mp               \
     + lce_id_width_mp                \
     + $bits(bp_lce_mode_e)           \
     + lce_id_width_mp                \
     + $bits(bp_lce_mode_e)           \
     + cce_id_width_mp                \
     + $bits(bp_cce_mode_e)           \
     + 8                              \
     + 1                              \
     )
  
  
  typedef struct packed
  {
    // 0: BP unicore (minimal, single-core configuration)
    // 1: BP multicore (coherent, multi-core configuration)
    integer multicore;

    // Dimensions of the different complexes
    // Core Complex may be any integer (though has only been validated up to 4x4)
    // All other Complexes are 1-dimensional
    //                                    [                           ]
    //                                    [        I/O Complex        ]
    //                                    [                           ]
    //
    //  [                               ] [                           ] [                               ]
    //  [ Streaming Accelerator Complex ] [        Core Complex       ] [ Coherent Accelerator Complex  ]
    //  [                               ] [                           ] [                               ]
    //
    //                                    [                           ]
    //                                    [       Memory Complex      ]
    //                                    [                           ]
    //
    integer cc_x_dim;
    integer cc_y_dim;
    integer ic_y_dim;
    integer mc_y_dim;
    integer cac_x_dim;
    integer sac_x_dim;

    // The type of accelerator in the accelerator complexes, selected out of bp_cacc_type_e/bp_sacc_type_e
    // Only supports homogeneous configurations
    integer cacc_type;
    integer sacc_type;
 
    // Number of CCEs/LCEs in the system. Must be consistent within complex dimensions
    integer num_cce;
    integer num_lce;
 
    // Virtual address width
    //   Only tested for SV39 (39-bit virtual address)
    integer vaddr_width;
    // Physical address width
    //   Only tested for 40-bit physical address
    integer paddr_width;
    // Address space ID width
    //   Currently unused, so set to 1 bit
    integer asid_width;

    // The virtual address of the PC coming out of reset
    integer boot_pc;
    // 0: boots in M-mode, not debug-mode
    // 1: boots in M-mode, debug-mode
    integer boot_in_debug;

    // Branch metadata information for the Front End
    // Must be kept consistent with FE
    integer branch_metadata_fwd_width;
    integer btb_tag_width;
    integer btb_idx_width;
    integer bht_idx_width;
    integer ghist_width;
 
    // Capacity of the Instruction/Data TLBs 
    integer itlb_els;
    integer dtlb_els;

    // Atomic support in the system. There are 3 levels of support
    //   None: Will cause illegal instruction trap
    //   L1  : Handled by L1
    //   L2  : Handled by L2 via uncached access in L1
    integer lr_sc;
    integer amo_swap;
    integer amo_fetch_logic;
    integer amo_fetch_arithmetic;

    // Whether the D$ is writethrough or writeback
    integer l1_writethrough;
    // Whether the I$ and D$ are kept coherent
    integer l1_coherent;

    // I$ parameterizations
    integer icache_sets;
    integer icache_assoc;
    integer icache_block_width;
    integer icache_fill_width;

    // D$ parameterizations
    integer dcache_sets;
    integer dcache_assoc;
    integer dcache_block_width;
    integer dcache_fill_width;

    // A$ parameterizations
    integer acache_sets;
    integer acache_assoc;
    integer acache_block_width;
    integer acache_fill_width;

    // Microcoded CCE parameters
    // 0: CCE is FSM-based
    // 1: CCE is ucode
    integer cce_ucode;
    // Determines the size of the CCE instruction RAM
    integer cce_pc_width;
  
    // L2 slice parameters (per core)
    integer l2_en;
    integer l2_sets;
    integer l2_assoc;
    integer l2_outstanding_reqs;
  
    // Size of the issue queue
    integer fe_queue_fifo_els;
    // Size of the cmd queue
    integer fe_cmd_fifo_els;
  
    // Whether the coherence network is on the core clock or on its own clock
    integer async_coh_clk;
    // Flit width of the coherence network. Has major impact on latency / area of the network
    integer coh_noc_flit_width;
    // Concentrator ID width of the coherence network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer coh_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer coh_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer coh_noc_max_credits;
  
    // Whether the memory network is on the core clock or on its own clock
    integer async_mem_clk;
    // Flit width of the memory network. Has major impact on latency / area of the network
    integer mem_noc_flit_width;
    // Concentrator ID width of the memory network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer mem_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer mem_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer mem_noc_max_credits;
  
    // Whether the I/O network is on the core clock or on its own clock
    integer async_io_clk;
    // Flit width of the I/O network. Has major impact on latency / area of the network
    integer io_noc_flit_width;
    // Concentrator ID width of the I/O network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer io_noc_cid_width;
    // Domain ID width of the I/O network. Corresponds to how many chips compose a multichip chain
    integer io_noc_did_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer io_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer io_noc_max_credits;
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
  , localparam multicore_p = proc_param_lp.multicore                                               \
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
  , localparam num_cce_p = proc_param_lp.num_cce                                                   \
  , localparam num_lce_p = proc_param_lp.num_lce                                                   \
                                                                                                   \
  , localparam core_id_width_p = `BSG_SAFE_CLOG2(cc_x_dim_p*cc_y_dim_p)                            \
  , localparam cce_id_width_p  = `BSG_SAFE_CLOG2((cc_x_dim_p*1+2)*(cc_y_dim_p*1+2))                \
  , localparam lce_id_width_p  = `BSG_SAFE_CLOG2((cc_x_dim_p*2+2)*(cc_y_dim_p*2+2))                \
                                                                                                   \
  , localparam vaddr_width_p = proc_param_lp.vaddr_width                                           \
  , localparam paddr_width_p = proc_param_lp.paddr_width                                           \
  , localparam asid_width_p  = proc_param_lp.asid_width                                            \
                                                                                                   \
  , localparam boot_pc_p       = proc_param_lp.boot_pc                                             \
  , localparam boot_in_debug_p = proc_param_lp.boot_in_debug                                       \
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
  , localparam lr_sc_p                    = proc_param_lp.lr_sc                                    \
  , localparam amo_swap_p                 = proc_param_lp.amo_swap                                 \
  , localparam amo_fetch_logic_p          = proc_param_lp.amo_fetch_logic                          \
  , localparam amo_fetch_arithmetic_p     = proc_param_lp.amo_fetch_arithmetic                     \
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
  , localparam cce_ucode_p                = proc_param_lp.cce_ucode                                \
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
  , localparam word_width_p        = 32                                                            \
  , localparam instr_width_p       = 32                                                            \
  , localparam csr_addr_width_p    = 12                                                            \
  , localparam reg_addr_width_p    = 5                                                             \
  , localparam page_offset_width_p = 12                                                            \
                                                                                                   \
  , localparam vtag_width_p  = proc_param_lp.vaddr_width - page_offset_width_p                     \
  , localparam ptag_width_p  = proc_param_lp.paddr_width - page_offset_width_p                     \

  `define bp_aviary_parameter_override(parameter_mp, override_cfg_mp, default_cfg_mp) \
    parameter_mp: (override_cfg_mp.``parameter_mp`` == "inv") \
                  ? default_cfg_mp.``parameter_mp``           \
                  : override_cfg_mp.``parameter_mp``          \

  `define bp_aviary_define_override(parameter_mp, define_mp, default_cfg_mp) \
    `ifdef define_mp                                          \
    parameter_mp: `define_mp                                  \
    `else                                                     \
    parameter_mp: default_cfg_mp.``parameter_mp``             \
    `endif

  `define bp_aviary_derive_cfg(cfg_name_mp, override_cfg_mp, default_cfg_mp) \
    localparam bp_proc_param_s cfg_name_mp =                                                       \
      '{`bp_aviary_parameter_override(multicore, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(cc_x_dim, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(cc_y_dim, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(ic_y_dim, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(mc_y_dim, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(cac_x_dim, override_cfg_mp, default_cfg_mp)                 \
        ,`bp_aviary_parameter_override(sac_x_dim, override_cfg_mp, default_cfg_mp)                 \
        ,`bp_aviary_parameter_override(cacc_type, override_cfg_mp, default_cfg_mp)                 \
        ,`bp_aviary_parameter_override(sacc_type, override_cfg_mp, default_cfg_mp)                 \
                                                                                                   \
        ,`bp_aviary_parameter_override(num_cce, override_cfg_mp, default_cfg_mp)                   \
        ,`bp_aviary_parameter_override(num_lce, override_cfg_mp, default_cfg_mp)                   \
                                                                                                   \
        ,`bp_aviary_parameter_override(vaddr_width, override_cfg_mp, default_cfg_mp)               \
        ,`bp_aviary_parameter_override(paddr_width, override_cfg_mp, default_cfg_mp)               \
        ,`bp_aviary_parameter_override(asid_width, override_cfg_mp, default_cfg_mp)                \
                                                                                                   \
        ,`bp_aviary_parameter_override(boot_pc, override_cfg_mp, default_cfg_mp)                   \
        ,`bp_aviary_parameter_override(boot_in_debug, override_cfg_mp, default_cfg_mp)             \
                                                                                                   \
        ,`bp_aviary_parameter_override(fe_queue_fifo_els, override_cfg_mp, default_cfg_mp)         \
        ,`bp_aviary_parameter_override(fe_cmd_fifo_els, override_cfg_mp, default_cfg_mp)           \
                                                                                                   \
        ,`bp_aviary_parameter_override(branch_metadata_fwd_width, override_cfg_mp, default_cfg_mp) \
        ,`bp_aviary_parameter_override(btb_tag_width, override_cfg_mp, default_cfg_mp)             \
        ,`bp_aviary_parameter_override(btb_idx_width, override_cfg_mp, default_cfg_mp)             \
        ,`bp_aviary_parameter_override(bht_idx_width, override_cfg_mp, default_cfg_mp)             \
        ,`bp_aviary_parameter_override(ghist_width, override_cfg_mp, default_cfg_mp)               \
                                                                                                   \
        ,`bp_aviary_parameter_override(itlb_els, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(dtlb_els, override_cfg_mp, default_cfg_mp)                  \
                                                                                                   \
        ,`bp_aviary_parameter_override(lr_sc, override_cfg_mp, default_cfg_mp)                     \
        ,`bp_aviary_parameter_override(amo_swap, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(amo_fetch_logic, override_cfg_mp, default_cfg_mp)           \
        ,`bp_aviary_parameter_override(amo_fetch_arithmetic, override_cfg_mp, default_cfg_mp)      \
                                                                                                   \
        ,`bp_aviary_parameter_override(l1_writethrough, override_cfg_mp, default_cfg_mp)           \
        ,`bp_aviary_parameter_override(l1_coherent, override_cfg_mp, default_cfg_mp)               \
                                                                                                   \
        ,`bp_aviary_parameter_override(icache_sets, override_cfg_mp, default_cfg_mp)               \
        ,`bp_aviary_parameter_override(icache_assoc, override_cfg_mp, default_cfg_mp)              \
        ,`bp_aviary_parameter_override(icache_block_width, override_cfg_mp, default_cfg_mp)        \
        ,`bp_aviary_parameter_override(icache_fill_width, override_cfg_mp, default_cfg_mp)         \
                                                                                                   \
        ,`bp_aviary_parameter_override(dcache_sets, override_cfg_mp, default_cfg_mp)               \
        ,`bp_aviary_parameter_override(dcache_assoc, override_cfg_mp, default_cfg_mp)              \
        ,`bp_aviary_parameter_override(dcache_block_width, override_cfg_mp, default_cfg_mp)        \
        ,`bp_aviary_parameter_override(dcache_fill_width, override_cfg_mp, default_cfg_mp)         \
        ,`bp_aviary_parameter_override(acache_sets, override_cfg_mp, default_cfg_mp)               \
        ,`bp_aviary_parameter_override(acache_assoc, override_cfg_mp, default_cfg_mp)              \
        ,`bp_aviary_parameter_override(acache_block_width, override_cfg_mp, default_cfg_mp)        \
        ,`bp_aviary_parameter_override(acache_fill_width, override_cfg_mp, default_cfg_mp)         \
                                                                                                   \
        ,`bp_aviary_parameter_override(cce_ucode, override_cfg_mp, default_cfg_mp)                 \
        ,`bp_aviary_parameter_override(cce_pc_width, override_cfg_mp, default_cfg_mp)              \
                                                                                                   \
        ,`bp_aviary_parameter_override(l2_en, override_cfg_mp, default_cfg_mp)                     \
        ,`bp_aviary_parameter_override(l2_sets, override_cfg_mp, default_cfg_mp)                   \
        ,`bp_aviary_parameter_override(l2_assoc, override_cfg_mp, default_cfg_mp)                  \
        ,`bp_aviary_parameter_override(l2_outstanding_reqs, override_cfg_mp, default_cfg_mp)       \
                                                                                                   \
        ,`bp_aviary_parameter_override(async_coh_clk, override_cfg_mp, default_cfg_mp)             \
        ,`bp_aviary_parameter_override(coh_noc_max_credits, override_cfg_mp, default_cfg_mp)       \
        ,`bp_aviary_parameter_override(coh_noc_flit_width, override_cfg_mp, default_cfg_mp)        \
        ,`bp_aviary_parameter_override(coh_noc_cid_width, override_cfg_mp, default_cfg_mp)         \
        ,`bp_aviary_parameter_override(coh_noc_len_width, override_cfg_mp, default_cfg_mp)         \
                                                                                                   \
        ,`bp_aviary_parameter_override(async_mem_clk, override_cfg_mp, default_cfg_mp)             \
        ,`bp_aviary_parameter_override(mem_noc_max_credits, override_cfg_mp, default_cfg_mp)       \
        ,`bp_aviary_parameter_override(mem_noc_flit_width, override_cfg_mp, default_cfg_mp)        \
        ,`bp_aviary_parameter_override(mem_noc_cid_width, override_cfg_mp, default_cfg_mp)         \
        ,`bp_aviary_parameter_override(mem_noc_len_width, override_cfg_mp, default_cfg_mp)         \
                                                                                                   \
        ,`bp_aviary_parameter_override(async_io_clk, override_cfg_mp, default_cfg_mp)              \
        ,`bp_aviary_parameter_override(io_noc_max_credits, override_cfg_mp, default_cfg_mp)        \
        ,`bp_aviary_parameter_override(io_noc_flit_width, override_cfg_mp, default_cfg_mp)         \
        ,`bp_aviary_parameter_override(io_noc_cid_width, override_cfg_mp, default_cfg_mp)          \
        ,`bp_aviary_parameter_override(io_noc_did_width, override_cfg_mp, default_cfg_mp)          \
        ,`bp_aviary_parameter_override(io_noc_len_width, override_cfg_mp, default_cfg_mp)          \
        }

`endif

