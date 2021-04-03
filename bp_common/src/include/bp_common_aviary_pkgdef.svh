`ifndef BP_COMMON_AVIARY_PKGDEF_SVH
`define BP_COMMON_AVIARY_PKGDEF_SVH

  `include "bp_common_aviary_defines.svh"

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs);

  // Configuration enums
  typedef enum logic [1:0]
  {
    e_none = 0
    , e_l1 = 1
    , e_l2 = 2
  } bp_atomic_op_e;

  typedef enum logic [15:0]
  {
    e_sacc_vdp = 0
  } bp_sacc_type_e;

  typedef enum logic [15:0]
  {
    e_cacc_vdp = 0
  } bp_cacc_type_e;

  typedef struct packed
  {
    // 0: BP unicore (minimal, single-core configuration)
    // 1: BP multicore (coherent, multi-core configuration)
    integer unsigned multicore;

    // Dimensions of the different complexes
    // Core Complex may be any integer unsigned (though has only been validated up to 4x4)
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
    integer unsigned cc_x_dim;
    integer unsigned cc_y_dim;
    integer unsigned ic_y_dim;
    integer unsigned mc_y_dim;
    integer unsigned cac_x_dim;
    integer unsigned sac_x_dim;

    // The type of accelerator in the accelerator complexes, selected out of bp_cacc_type_e/bp_sacc_type_e
    // Only supports homogeneous configurations
    integer unsigned cacc_type;
    integer unsigned sacc_type;

    // Number of CCEs/LCEs in the system. Must be consistent within complex dimensions
    integer unsigned num_cce;
    integer unsigned num_lce;

    // Virtual address width
    //   Only tested for SV39 (39-bit virtual address)
    integer unsigned vaddr_width;
    // Physical address width
    //   Only tested for 40-bit physical address
    integer unsigned paddr_width;
    // The max size of the connected DRAM i.e. cached address space
    integer unsigned dram_max_size;
    // Address space ID width
    //   Currently unused, so set to 1 bit
    integer unsigned asid_width;

    // The virtual address of the PC coming out of reset
    integer unsigned boot_pc;
    // 0: boots in M-mode, not debug-mode
    // 1: boots in M-mode, debug-mode
    integer unsigned boot_in_debug;

    // Branch metadata information for the Front End
    // Must be kept consistent with FE
    integer unsigned branch_metadata_fwd_width;
    integer unsigned btb_tag_width;
    integer unsigned btb_idx_width;
    integer unsigned bht_idx_width;
    integer unsigned ghist_width;

    // Capacity of the Instruction/Data TLBs
    integer unsigned itlb_els_4k;
    integer unsigned itlb_els_1g;
    integer unsigned dtlb_els_4k;
    integer unsigned dtlb_els_1g;

    // Atomic support in the system. There are 3 levels of support
    //   None: Will cause illegal instruction trap
    //   L1  : Handled by L1
    //   L2  : Handled by L2 via uncached access in L1
    integer unsigned lr_sc;
    integer unsigned amo_swap;
    integer unsigned amo_fetch_logic;
    integer unsigned amo_fetch_arithmetic;

    // Whether the D$ is writethrough or writeback
    integer unsigned l1_writethrough;
    // Whether the I$ and D$ are kept coherent
    integer unsigned l1_coherent;

    // I$ parameterizations
    integer unsigned icache_sets;
    integer unsigned icache_assoc;
    integer unsigned icache_block_width;
    integer unsigned icache_fill_width;

    // D$ parameterizations
    integer unsigned dcache_sets;
    integer unsigned dcache_assoc;
    integer unsigned dcache_block_width;
    integer unsigned dcache_fill_width;

    // A$ parameterizations
    integer unsigned acache_sets;
    integer unsigned acache_assoc;
    integer unsigned acache_block_width;
    integer unsigned acache_fill_width;

    // Microcoded CCE parameters
    // 0: CCE is FSM-based
    // 1: CCE is ucode
    integer unsigned cce_ucode;
    // Determines the size of the CCE instruction RAM
    integer unsigned cce_pc_width;

    // L2 slice parameters (per core)
    integer unsigned l2_en;
    integer unsigned l2_data_width;
    integer unsigned l2_sets;
    integer unsigned l2_assoc;
    integer unsigned l2_block_width;
    integer unsigned l2_fill_width;
    integer unsigned l2_outstanding_reqs;

    // Size of the issue queue
    integer unsigned fe_queue_fifo_els;
    // Size of the cmd queue
    integer unsigned fe_cmd_fifo_els;

    // Whether the coherence network is on the core clock or on its own clock
    integer unsigned async_coh_clk;
    // Flit width of the coherence network. Has major impact on latency / area of the network
    integer unsigned coh_noc_flit_width;
    // Concentrator ID width of the coherence network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned coh_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned coh_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned coh_noc_max_credits;

    // Whether the memory network is on the core clock or on its own clock
    integer unsigned async_mem_clk;
    // Flit width of the memory network. Has major impact on latency / area of the network
    integer unsigned mem_noc_flit_width;
    // Concentrator ID width of the memory network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned mem_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned mem_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned mem_noc_max_credits;

    // Whether the I/O network is on the core clock or on its own clock
    integer unsigned async_io_clk;
    // Flit width of the I/O network. Has major impact on latency / area of the network
    integer unsigned io_noc_flit_width;
    // Concentrator ID width of the I/O network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned io_noc_cid_width;
    // Domain ID width of the I/O network. Corresponds to how many chips compose a multichip chain
    integer unsigned io_noc_did_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned io_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned io_noc_max_credits;

  }  bp_proc_param_s;

  localparam bp_proc_param_s bp_default_cfg_p =
    '{multicore : 0
      ,cc_x_dim : 1
      ,cc_y_dim : 1
      ,ic_y_dim : 1
      ,mc_y_dim : 0
      ,cac_x_dim: 0
      ,sac_x_dim: 0
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp

      ,num_cce: 1
      ,num_lce: 2

      ,vaddr_width: 39
      ,paddr_width: 40
      // 4 GB
      ,dram_max_size : (1 << 31)
      ,asid_width : 1

      ,boot_pc       : dram_base_addr_gp
      ,boot_in_debug : 0

      ,branch_metadata_fwd_width: 35
      ,btb_tag_width            : 9
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ghist_width              : 2

      ,itlb_els_4k : 8
      ,dtlb_els_4k : 8
      ,itlb_els_1g : 2
      ,dtlb_els_1g : 2

      ,lr_sc                : e_l1
      ,amo_swap             : e_none
      ,amo_fetch_logic      : e_none
      ,amo_fetch_arithmetic : e_none

      ,l1_writethrough      : 0
      ,l1_coherent          : 0
      ,dcache_sets          : 64
      ,dcache_assoc         : 8
      ,dcache_block_width   : 512
      ,dcache_fill_width    : 512
      ,icache_sets          : 64
      ,icache_assoc         : 8
      ,icache_block_width   : 512
      ,icache_fill_width    : 512
      ,acache_sets          : 64
      ,acache_assoc         : 8
      ,acache_block_width   : 512
      ,acache_fill_width    : 512

      ,cce_ucode            : 0
      ,cce_pc_width         : 8

      ,l2_en               : 1
      ,l2_data_width       : 64
      ,l2_sets             : 128
      ,l2_assoc            : 8
      ,l2_block_width      : 512
      ,l2_fill_width       : 64
      ,l2_outstanding_reqs : 8

      ,fe_queue_fifo_els : 8
      ,fe_cmd_fifo_els   : 4

      ,async_coh_clk       : 0
      ,coh_noc_max_credits : 8
      ,coh_noc_flit_width  : 128
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 3

      ,async_mem_clk         : 0
      ,mem_noc_max_credits   : 8
      ,mem_noc_flit_width    : 64
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 4

      ,async_io_clk         : 0
      ,io_noc_did_width     : 3
      ,io_noc_max_credits   : 16
      ,io_noc_flit_width    : 64
      ,io_noc_cid_width     : 2
      ,io_noc_len_width     : 4
      };

  // Default configuration is unicore
  localparam bp_proc_param_s bp_unicore_override_p =
    '{dcache_fill_width     : 512
      ,icache_fill_width    : 512
      ,l2_data_width        : 512
      ,l2_fill_width        : 512
      ,mem_noc_flit_width   : 512
      ,default       : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_cfg_p
                        ,bp_unicore_override_p
                        ,bp_default_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_bootrom_override_p =
    '{boot_pc        : bootrom_base_addr_gp
      ,boot_in_debug : 1
      ,default       : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_bootrom_cfg_p
                        ,bp_unicore_bootrom_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_no_l2_override_p =
    '{l2_en   : 0
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_no_l2_cfg_p
                        ,bp_unicore_no_l2_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_paddr_large_override_p =
    '{paddr_width   : 44
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_paddr_large_cfg_p
                        ,bp_unicore_paddr_large_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_medium_override_p =
    '{icache_sets         : 128
      ,icache_assoc       : 4
      ,icache_block_width : 256
      ,icache_fill_width  : 256
      ,dcache_sets        : 128
      ,dcache_assoc       : 4
      ,dcache_block_width : 256
      ,dcache_fill_width  : 256
      ,l2_data_width      : 256
      ,l2_fill_width      : 256
      ,mem_noc_flit_width : 256
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_medium_cfg_p
                        ,bp_unicore_l1_medium_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_small_override_p =
    '{icache_sets         : 256
      ,icache_assoc       : 2
      ,icache_block_width : 128
      ,icache_fill_width  : 128
      ,dcache_sets        : 256
      ,dcache_assoc       : 2
      ,dcache_block_width : 128
      ,dcache_fill_width  : 128
      ,l2_data_width      : 128
      ,l2_fill_width      : 128
      ,mem_noc_flit_width : 128
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_small_cfg_p
                        ,bp_unicore_l1_small_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_tiny_override_p =
    '{icache_sets         : 64
      ,icache_assoc       : 1
      ,icache_block_width : 512
      ,icache_fill_width  : 512
      ,dcache_sets        : 64
      ,dcache_assoc       : 1
      ,dcache_block_width : 512
      ,dcache_fill_width  : 512
      ,l2_data_width      : 512
      ,l2_fill_width      : 512
      ,mem_noc_flit_width : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_tiny_cfg_p
                        ,bp_unicore_l1_tiny_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_hetero_override_p =
    '{icache_sets         : 256
      ,icache_assoc       : 2
      ,icache_block_width : 128
      ,icache_fill_width  : 128
      ,dcache_sets        : 128
      ,dcache_assoc       : 4
      ,dcache_block_width : 256
      ,dcache_fill_width  : 256
      ,l2_data_width      : 256
      ,l2_fill_width      : 256
      ,mem_noc_flit_width : 256
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_hetero_cfg_p
                        ,bp_unicore_l1_hetero_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_wide_override_p =
    '{icache_sets         : 64
      ,icache_assoc       : 4
      ,icache_block_width : 512
      ,icache_fill_width  : 512
      ,dcache_sets        : 64
      ,dcache_assoc       : 4
      ,dcache_block_width : 512
      ,dcache_fill_width  : 512
      ,l2_data_width      : 512
      ,l2_fill_width      : 512
      ,mem_noc_flit_width : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_wide_cfg_p
                        ,bp_unicore_l1_wide_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_atomic_override_p =
    '{lr_sc                 : e_l1
      ,amo_swap             : e_l1
      ,amo_fetch_logic      : e_l1
      ,amo_fetch_arithmetic : e_l1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_atomic_cfg_p
                        ,bp_unicore_l1_atomic_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l2_atomic_override_p =
    '{lr_sc                 : e_l1
      ,amo_swap             : e_l2
      ,amo_fetch_logic      : e_l2
      ,amo_fetch_arithmetic : e_l2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l2_atomic_cfg_p
                        ,bp_unicore_l2_atomic_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_writethrough_override_p =
    '{l1_writethrough: 1
      ,default       : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_writethrough_cfg_p
                        ,bp_unicore_writethrough_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_override_p =
    '{multicore      : 1
      ,num_cce       : 1
      ,num_lce       : 2
      ,l1_coherent   : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cfg_p
                        ,bp_multicore_1_override_p
                        ,bp_default_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_paddr_large_override_p =
    '{paddr_width : 44
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_paddr_large_cfg_p
                        ,bp_multicore_1_paddr_large_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_l2e_override_p =
    '{mc_y_dim   : 1
      ,num_cce   : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_l2e_cfg_p
                        ,bp_multicore_1_l2e_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_bootrom_override_p =
    '{boot_pc        : bootrom_base_addr_gp
      ,boot_in_debug : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_bootrom_cfg_p
                        ,bp_multicore_1_bootrom_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_no_l2_override_p =
    '{l2_en   : 0
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_no_l2_cfg_p
                        ,bp_multicore_1_no_l2_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_l1_medium_override_p =
    '{icache_sets         : 128
      ,icache_assoc       : 4
      ,icache_block_width : 256
      ,icache_fill_width  : 256
      ,dcache_sets        : 128
      ,dcache_assoc       : 4
      ,dcache_block_width : 256
      ,dcache_fill_width  : 256
      ,acache_sets        : 128
      ,acache_assoc       : 4
      ,acache_block_width : 256
      ,acache_fill_width  : 256
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_l1_medium_cfg_p
                        ,bp_multicore_1_l1_medium_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_l1_small_override_p =
    '{icache_sets         : 256
      ,icache_assoc       : 2
      ,icache_block_width : 128
      ,icache_fill_width  : 128
      ,dcache_sets        : 256
      ,dcache_assoc       : 2
      ,dcache_block_width : 128
      ,dcache_fill_width  : 128
      ,acache_sets        : 256
      ,acache_assoc       : 2
      ,acache_block_width : 128
      ,acache_fill_width  : 128
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_l1_small_cfg_p
                        ,bp_multicore_1_l1_small_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_2_override_p =
    '{cc_x_dim : 2
      ,num_cce : 2
      ,num_lce : 4
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_2_cfg_p
                        ,bp_multicore_2_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_2_l2e_override_p =
    '{mc_y_dim   : 1
      ,num_cce   : 4
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_2_l2e_cfg_p
                        ,bp_multicore_2_l2e_override_p
                        ,bp_multicore_2_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_3_override_p =
    '{cc_x_dim : 3
      ,num_cce : 3
      ,num_lce : 6
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_3_cfg_p
                        ,bp_multicore_3_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_override_p =
    '{cc_x_dim : 2
      ,cc_y_dim: 2
      ,num_cce : 4
      ,num_lce : 8
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_cfg_p
                        ,bp_multicore_4_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_l2e_override_p =
    '{mc_y_dim   : 1
      ,num_cce   : 6
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_l2e_cfg_p
                        ,bp_multicore_4_l2e_override_p
                        ,bp_multicore_4_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_6_override_p =
    '{cc_x_dim : 3
      ,cc_y_dim: 2
      ,num_cce : 6
      ,num_lce : 12
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_6_cfg_p
                        ,bp_multicore_6_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_8_override_p =
    '{cc_x_dim : 4
      ,cc_y_dim: 2
      ,num_cce : 8
      ,num_lce : 16
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_8_cfg_p
                        ,bp_multicore_8_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_12_override_p =
    '{cc_x_dim : 4
      ,cc_y_dim: 3
      ,num_cce : 12
      ,num_lce : 24
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_12_cfg_p
                        ,bp_multicore_12_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_16_override_p =
    '{cc_x_dim : 4
      ,cc_y_dim: 4
      ,num_cce : 16
      ,num_lce : 32
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_16_cfg_p
                        ,bp_multicore_16_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_accelerator_override_p =
    '{cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,num_lce  : 4
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_accelerator_cfg_p
                        ,bp_multicore_1_accelerator_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_cfg_p
                        ,bp_multicore_1_cce_ucode_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_bootrom_override_p =
    '{boot_pc        : bootrom_base_addr_gp
      ,boot_in_debug : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_bootrom_cfg_p
                        ,bp_multicore_1_cce_ucode_bootrom_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_paddr_large_override_p =
    '{paddr_width : 44
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_paddr_large_cfg_p
                        ,bp_multicore_1_cce_ucode_paddr_large_override_p
                        ,bp_multicore_1_cce_ucode_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_2_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_2_cce_ucode_cfg_p
                        ,bp_multicore_2_cce_ucode_override_p
                        ,bp_multicore_2_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_3_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_3_cce_ucode_cfg_p
                        ,bp_multicore_3_cce_ucode_override_p
                        ,bp_multicore_3_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_cce_ucode_cfg_p
                        ,bp_multicore_4_cce_ucode_override_p
                        ,bp_multicore_4_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_6_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_6_cce_ucode_cfg_p
                        ,bp_multicore_6_cce_ucode_override_p
                        ,bp_multicore_6_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_8_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_8_cce_ucode_cfg_p
                        ,bp_multicore_8_cce_ucode_override_p
                        ,bp_multicore_8_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_12_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_12_cce_ucode_cfg_p
                        ,bp_multicore_12_cce_ucode_override_p
                        ,bp_multicore_12_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_16_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_16_cce_ucode_cfg_p
                        ,bp_multicore_16_cce_ucode_override_p
                        ,bp_multicore_16_cfg_p
                        );

  // Half core configs
  localparam bp_proc_param_s bp_unicore_half_override_p =
    '{num_lce  : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_half_cfg_p
                        ,bp_unicore_half_override_p
                        ,bp_default_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_half_override_p =
    '{num_lce  : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_half_cfg_p
                        ,bp_multicore_half_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_cce_ucode_half_override_p =
    '{num_lce  : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_cce_ucode_half_cfg_p
                        ,bp_multicore_cce_ucode_half_override_p
                        ,bp_multicore_1_cce_ucode_cfg_p
                        );

  `ifndef BP_CUSTOM_BASE_CFG
  `define BP_CUSTOM_BASE_CFG bp_default_cfg_p
  `endif
  // Custom, tick define-based configuration
  localparam bp_proc_param_s bp_custom_cfg_p =
    '{`bp_aviary_define_override(multicore, BP_MULTICORE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cc_x_dim, BP_CC_X_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cc_y_dim, BP_CC_Y_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ic_y_dim, BP_IC_Y_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mc_y_dim, BP_MC_Y_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cac_x_dim, BP_CAC_X_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(sac_x_dim, BP_SAC_X_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cacc_type, BP_CACC_TYPE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(sacc_type, BP_SACC_TYPE, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(num_cce, BP_NUM_CCE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(num_lce, BP_NUM_LCE, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(vaddr_width, BP_VADDR_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(paddr_width, BP_PADDR_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dram_max_size, BP_DRAM_MAX_SIZE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(asid_width, BP_ASID_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(boot_pc, BP_BOOT_PC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(boot_in_debug, BP_BOOT_IN_DEBUG, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(fe_queue_fifo_els, BP_FE_QUEUE_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(fe_cmd_fifo_els, BP_FE_CMD_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(branch_metadata_fwd_width, BRANCH_METADATA_FWD_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_tag_width, BP_BTB_TAG_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_idx_width, BP_BTB_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_idx_width, BP_BHT_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ghist_width, BP_GHIST_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(itlb_els_4k, BP_ITLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(itlb_els_1g, BP_ITLB_ELS_1G, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_4k, BP_DTLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_1g, BP_DTLB_ELS_1G, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(lr_sc, BP_LR_SC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(amo_swap, BP_AMO_SWAP, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(amo_fetch_logic, BP_AMO_FETCH_LOGIC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(amo_fetch_arithmetic, BP_AMO_FETCH_ARITHMETIC, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(l1_writethrough, BP_L1_WRITETHROUGH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l1_coherent, BP_L1_COHERENT, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(icache_sets, BP_ICACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_assoc, BP_ICACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_block_width, BP_ICACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_fill_width, BP_ICACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(dcache_sets, BP_DCACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_assoc, BP_DCACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_block_width, BP_DCACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_fill_width, BP_DCACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(acache_sets, BP_ACACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_assoc, BP_ACACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_block_width, BP_ACACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_fill_width, BP_ACACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(cce_ucode, BP_CCE_UCODE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cce_pc_width, BP_CCE_PC_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(l2_en, BP_L2_EN, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_data_width, BP_L2_DATA_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_sets, BP_L2_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_assoc, BP_L2_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_block_width, BP_L2_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_fill_width, BP_L2_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_outstanding_reqs, BP_L2_OUTSTANDING_REQS, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_coh_clk, BP_ASYNC_COH_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_max_credits, BP_COH_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_flit_width, BP_COH_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_cid_width, BP_COH_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_len_width, BP_COH_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_mem_clk, BP_ASYNC_MEM_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_max_credits, BP_MEM_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_flit_width, BP_MEM_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_cid_width, BP_MEM_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_len_width, BP_MEM_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_io_clk, BP_ASYNC_IO_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_max_credits, BP_IO_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_flit_width, BP_IO_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_cid_width, BP_IO_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_did_width, BP_IO_NOC_DID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_len_width, BP_IO_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)
      };

  /* verilator lint_off WIDTH */
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    // Various testing configs
    bp_multicore_cce_ucode_half_cfg_p
    ,bp_multicore_half_cfg_p
    ,bp_unicore_half_cfg_p

    // L2 extension configurations
    ,bp_multicore_4_l2e_cfg_p
    ,bp_multicore_2_l2e_cfg_p
    ,bp_multicore_1_l2e_cfg_p

    // Accelerator configurations
    ,bp_multicore_1_accelerator_cfg_p

    // Ucode configurations
    ,bp_multicore_16_cce_ucode_cfg_p
    ,bp_multicore_12_cce_ucode_cfg_p
    ,bp_multicore_8_cce_ucode_cfg_p
    ,bp_multicore_6_cce_ucode_cfg_p
    ,bp_multicore_4_cce_ucode_cfg_p
    ,bp_multicore_3_cce_ucode_cfg_p
    ,bp_multicore_2_cce_ucode_cfg_p
    ,bp_multicore_1_cce_ucode_paddr_large_cfg_p
    ,bp_multicore_1_cce_ucode_bootrom_cfg_p
    ,bp_multicore_1_cce_ucode_cfg_p

    // Multicore configurations
    ,bp_multicore_16_cfg_p
    ,bp_multicore_12_cfg_p
    ,bp_multicore_8_cfg_p
    ,bp_multicore_6_cfg_p
    ,bp_multicore_4_cfg_p
    ,bp_multicore_3_cfg_p
    ,bp_multicore_2_cfg_p
    ,bp_multicore_1_paddr_large_cfg_p
    ,bp_multicore_1_l1_small_cfg_p
    ,bp_multicore_1_l1_medium_cfg_p
    ,bp_multicore_1_no_l2_cfg_p
    ,bp_multicore_1_bootrom_cfg_p
    ,bp_multicore_1_cfg_p

    // Unicore configurations
    ,bp_unicore_paddr_large_cfg_p
    ,bp_unicore_writethrough_cfg_p
    ,bp_unicore_l2_atomic_cfg_p
    ,bp_unicore_l1_atomic_cfg_p
    ,bp_unicore_l1_wide_cfg_p
    ,bp_unicore_l1_hetero_cfg_p
    ,bp_unicore_l1_tiny_cfg_p
    ,bp_unicore_l1_small_cfg_p
    ,bp_unicore_l1_medium_cfg_p
    ,bp_unicore_no_l2_cfg_p
    ,bp_unicore_bootrom_cfg_p
    ,bp_unicore_cfg_p

    // A custom BP configuration generated from Makefile
    ,bp_custom_cfg_p
    // The default BP
    ,bp_default_cfg_p
  };
  /* verilator lint_on WIDTH */

  // This enum MUST be kept up to date with the parameter array above
  typedef enum bit [lg_max_cfgs-1:0]
  {
    // Various testing config
    e_bp_multicore_cce_ucode_half_cfg               = 43
    ,e_bp_multicore_half_cfg                        = 42
    ,e_bp_unicore_half_cfg                          = 41

    // L2 extension configurations
    ,e_bp_multicore_4_l2e_cfg                       = 40
    ,e_bp_multicore_2_l2e_cfg                       = 39
    ,e_bp_multicore_1_l2e_cfg                       = 38

    // Accelerator configurations
    ,e_bp_multicore_1_accelerator_cfg               = 37

    // Ucode configurations
    ,e_bp_multicore_16_cce_ucode_cfg                = 36
    ,e_bp_multicore_12_cce_ucode_cfg                = 35
    ,e_bp_multicore_8_cce_ucode_cfg                 = 34
    ,e_bp_multicore_6_cce_ucode_cfg                 = 33
    ,e_bp_multicore_4_cce_ucode_cfg                 = 32
    ,e_bp_multicore_3_cce_ucode_cfg                 = 31
    ,e_bp_multicore_2_cce_ucode_cfg                 = 30
    ,e_bp_multicore_1_cce_ucode_paddr_large_cfg     = 29
    ,e_bp_multicore_1_cce_ucode_bootrom_cfg         = 28
    ,e_bp_multicore_1_cce_ucode_cfg                 = 27

    // Multicore configurations
    ,e_bp_multicore_16_cfg                          = 26
    ,e_bp_multicore_12_cfg                          = 25
    ,e_bp_multicore_8_cfg                           = 24
    ,e_bp_multicore_6_cfg                           = 23
    ,e_bp_multicore_4_cfg                           = 22
    ,e_bp_multicore_3_cfg                           = 21
    ,e_bp_multicore_2_cfg                           = 20
    ,e_bp_multicore_1_paddr_large_cfg               = 19
    ,e_bp_multicore_1_l1_small_cfg                  = 18
    ,e_bp_multicore_1_l1_medium_cfg                 = 17
    ,e_bp_multicore_1_no_l2_cfg                     = 16
    ,e_bp_multicore_1_bootrom_cfg                   = 15
    ,e_bp_multicore_1_cfg                           = 14

    // Unicore configurations
    ,e_bp_unicore_paddr_large_cfg                   = 13
    ,e_bp_unicore_writethrough_cfg                  = 12
    ,e_bp_unicore_l2_atomic_cfg                     = 11
    ,e_bp_unicore_l1_atomic_cfg                     = 10
    ,e_bp_unicore_l1_wide_cfg                       = 9
    ,e_bp_unicore_l1_hetero_cfg                     = 8
    ,e_bp_unicore_l1_tiny_cfg                       = 7
    ,e_bp_unicore_l1_small_cfg                      = 6
    ,e_bp_unicore_l1_medium_cfg                     = 5
    ,e_bp_unicore_no_l2_cfg                         = 4
    ,e_bp_unicore_bootrom_cfg                       = 3
    ,e_bp_unicore_cfg                               = 2

    // A custom BP configuration generated from Makefile
    ,e_bp_custom_cfg                                = 1
    // The default BP
    ,e_bp_default_cfg                               = 0
  } bp_params_e;

`endif

