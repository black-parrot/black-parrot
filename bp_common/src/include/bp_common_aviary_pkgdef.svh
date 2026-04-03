`ifndef BP_COMMON_AVIARY_PKGDEF_SVH
`define BP_COMMON_AVIARY_PKGDEF_SVH

  `include "bp_common_aviary_cfg_pkgdef.svh"
  `include "bp_common_host_pkgdef.svh"

  // Default configuration is unicore
  localparam bp_proc_param_s bp_unicore_cfg_p = bp_default_cfg_p;

  localparam bp_proc_param_s bp_unicore_megaparrot_override_p =
    '{paddr_width : 56
      ,daddr_width: 55
      ,caddr_width: 54

      ,branch_metadata_fwd_width: 50
      ,ras_idx_width            : 3
      ,btb_tag_width            : 9
      ,btb_idx_width            : 8
      ,bht_idx_width            : 8
      ,bht_row_els              : 4
      ,ghist_width              : 2

      ,icache_sets        : 64
      ,icache_assoc       : 8
      ,icache_block_width : 512
      ,icache_fill_width  : 512

      ,dcache_sets        : 64
      ,dcache_assoc       : 8
      ,dcache_block_width : 512
      ,dcache_fill_width  : 512

      ,bedrock_block_width : 512
      ,bedrock_fill_width  : 512

      ,l2_banks            : 8
      ,l2_data_width       : 512
      ,l2_sets             : 128
      ,l2_assoc            : 8
      ,l2_block_width      : 512
      ,l2_fill_width       : 512

      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_megaparrot_cfg_p
                        ,bp_unicore_megaparrot_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_tinyparrot_override_p =
    '{paddr_width         : 34

      ,branch_metadata_fwd_width: 31
      ,ras_idx_width            : 1
      ,btb_tag_width            : 6
      ,btb_idx_width            : 4
      ,bht_idx_width            : 5
      ,bht_row_els              : 2
      ,ghist_width              : 2

      ,icache_sets        : 128
      ,icache_assoc       : 1
      ,icache_block_width : 64
      ,icache_fill_width  : 64

      ,dcache_features    : (1 << e_cfg_enabled) | (1 << e_cfg_lr_sc)
      ,dcache_sets        : 128
      ,dcache_assoc       : 1
      ,dcache_block_width : 64
      ,dcache_fill_width  : 64

      ,bedrock_block_width: 64
      ,bedrock_fill_width : 64

      ,l2_features   : (1 << e_cfg_writeback)
                       | (1 << e_cfg_amo_swap)
                       | (1 << e_cfg_amo_fetch_logic)
                       | (1 << e_cfg_amo_fetch_arithmetic)
      ,l2_data_width : 64
      ,l2_fill_width : 64

      ,integer_support: (1 << e_basic)
      ,muldiv_support : (1 << e_idiv) | (1 << e_imul)
      ,fpu_support    : (1 << e_fma) | (1 << e_fdivsqrt)

      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_tinyparrot_cfg_p
                        ,bp_unicore_tinyparrot_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_miniparrot_override_p =
    '{paddr_width         : 34

      ,branch_metadata_fwd_width: 31
      ,ras_idx_width            : 1
      ,btb_tag_width            : 6
      ,btb_idx_width            : 4
      ,bht_idx_width            : 5
      ,bht_row_els              : 2
      ,ghist_width              : 2

      ,icache_sets        : 256
      ,icache_assoc       : 2
      ,icache_block_width : 128
      ,icache_fill_width  : 128

      ,dcache_features    : (1 << e_cfg_enabled) | (1 << e_cfg_lr_sc)
      ,dcache_sets        : 256
      ,dcache_assoc       : 2
      ,dcache_block_width : 128
      ,dcache_fill_width  : 128

      ,bedrock_block_width: 128
      ,bedrock_fill_width : 128

      // We use L2 for the write buffer support
      ,l2_features   : (1 << e_cfg_enabled)
                       | (1 << e_cfg_writeback)
                       | (1 << e_cfg_amo_swap)
                       | (1 << e_cfg_amo_fetch_logic)
                       | (1 << e_cfg_amo_fetch_arithmetic)
      ,l2_data_width : 128
      ,l2_fill_width : 128

      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_miniparrot_cfg_p
                        ,bp_unicore_miniparrot_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_override_p =
    '{cce_type              : e_cce_fsm
      ,ic_y_dim             : 1
      ,icache_features      : (1 << e_cfg_enabled) | (1 << e_cfg_coherent)
      ,dcache_features      : (1 << e_cfg_enabled)
                              | (1 << e_cfg_coherent)
                              | (1 << e_cfg_writeback)
                              | (1 << e_cfg_lr_sc)
                              | (1 << e_cfg_amo_swap)
                              | (1 << e_cfg_amo_fetch_logic)
                              | (1 << e_cfg_amo_fetch_arithmetic)
      ,l2_features          : (1 << e_cfg_enabled) | (1 << e_cfg_writeback)
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cfg_p
                        ,bp_multicore_1_override_p
                        ,bp_default_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_megaparrot_override_p =
    '{paddr_width : 56
      ,daddr_width: 55
      ,caddr_width: 54

      ,branch_metadata_fwd_width: 46
      ,ras_idx_width            : 1
      ,btb_tag_width            : 9
      ,btb_idx_width            : 8
      ,bht_idx_width            : 8
      ,bht_row_els              : 4
      ,ghist_width              : 2

      ,icache_sets        : 64
      ,icache_assoc       : 8
      ,icache_block_width : 512
      ,icache_fill_width  : 512

      ,dcache_sets        : 64
      ,dcache_assoc       : 8
      ,dcache_block_width : 512
      ,dcache_fill_width  : 512

      ,bedrock_block_width : 512
      ,bedrock_fill_width  : 512

      ,l2_banks            : 8
      ,l2_data_width       : 512
      ,l2_sets             : 128
      ,l2_assoc            : 8
      ,l2_block_width      : 512
      ,l2_fill_width       : 512

      ,dma_noc_flit_width  : 512
      ,coh_noc_flit_width  : 512
      ,mem_noc_flit_width  : 512
      ,dma_noc_cid_width   : 4

      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_megaparrot_cfg_p
                        ,bp_multicore_1_megaparrot_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_miniparrot_override_p =
    '{paddr_width : 34
      ,daddr_width: 33
      ,caddr_width: 32

      ,branch_metadata_fwd_width: 31
      ,ras_idx_width            : 1
      ,btb_tag_width            : 6
      ,btb_idx_width            : 4
      ,bht_idx_width            : 5
      ,bht_row_els              : 2
      ,ghist_width              : 2

      ,icache_sets        : 256
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

      ,bedrock_block_width : 128
      ,bedrock_fill_width  : 128

      ,l2_data_width : 128
      ,l2_fill_width : 128

      ,coh_noc_flit_width : 128
      ,dma_noc_flit_width : 128
      ,mem_noc_flit_width : 128

      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_miniparrot_cfg_p
                        ,bp_multicore_1_miniparrot_override_p
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
      ,l2_banks  : 1
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
      ,l2_slices: 1
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
      ,l2_slices: 1
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
      ,l2_banks: 1
      ,l2_slices: 1
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
      ,l2_banks: 1
      ,l2_slices: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_16_cfg_p
                        ,bp_multicore_16_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_acc_scratchpad_override_p =
    '{sac_x_dim: 1
      ,sacc_type: e_sacc_scratchpad
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_acc_scratchpad_cfg_p
                        ,bp_multicore_1_acc_scratchpad_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_acc_vdp_override_p =
    '{cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,num_lce  : 3
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_acc_vdp_cfg_p
                        ,bp_multicore_1_acc_vdp_override_p
                        ,bp_multicore_1_cfg_p
                        );


 localparam bp_proc_param_s bp_multicore_4_acc_scratchpad_override_p =
    '{sac_x_dim : 1
      ,sacc_type: e_sacc_scratchpad
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_acc_scratchpad_cfg_p
                        ,bp_multicore_4_acc_scratchpad_override_p
                        ,bp_multicore_4_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_acc_vdp_override_p =
    '{cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,num_lce  : 10
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_acc_vdp_cfg_p
                        ,bp_multicore_4_acc_vdp_override_p
                        ,bp_multicore_4_cfg_p
                        );


  localparam bp_proc_param_s bp_multicore_1_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_cfg_p
                        ,bp_multicore_1_cce_ucode_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_megaparrot_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_megaparrot_cfg_p
                        ,bp_multicore_1_cce_ucode_megaparrot_override_p
                        ,bp_multicore_1_megaparrot_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_miniparrot_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_miniparrot_cfg_p
                        ,bp_multicore_1_cce_ucode_miniparrot_override_p
                        ,bp_multicore_1_miniparrot_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_2_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_2_cce_ucode_cfg_p
                        ,bp_multicore_2_cce_ucode_override_p
                        ,bp_multicore_2_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_3_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_3_cce_ucode_cfg_p
                        ,bp_multicore_3_cce_ucode_override_p
                        ,bp_multicore_3_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_cce_ucode_cfg_p
                        ,bp_multicore_4_cce_ucode_override_p
                        ,bp_multicore_4_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_6_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_6_cce_ucode_cfg_p
                        ,bp_multicore_6_cce_ucode_override_p
                        ,bp_multicore_6_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_8_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_8_cce_ucode_cfg_p
                        ,bp_multicore_8_cce_ucode_override_p
                        ,bp_multicore_8_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_12_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_12_cce_ucode_cfg_p
                        ,bp_multicore_12_cce_ucode_override_p
                        ,bp_multicore_12_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_16_cce_ucode_override_p =
    '{cce_type : e_cce_ucode
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_16_cce_ucode_cfg_p
                        ,bp_multicore_16_cce_ucode_override_p
                        ,bp_multicore_16_cfg_p
                        );

  /* verilator lint_off WIDTH */
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    // L2 extension configurations
    bp_multicore_4_l2e_cfg_p
    ,bp_multicore_2_l2e_cfg_p
    ,bp_multicore_1_l2e_cfg_p

    // Accelerator configurations
    ,bp_multicore_4_acc_vdp_cfg_p
    ,bp_multicore_4_acc_scratchpad_cfg_p
    ,bp_multicore_1_acc_vdp_cfg_p
    ,bp_multicore_1_acc_scratchpad_cfg_p

    // Ucode configurations
    ,bp_multicore_16_cce_ucode_cfg_p
    ,bp_multicore_12_cce_ucode_cfg_p
    ,bp_multicore_8_cce_ucode_cfg_p
    ,bp_multicore_6_cce_ucode_cfg_p
    ,bp_multicore_4_cce_ucode_cfg_p
    ,bp_multicore_3_cce_ucode_cfg_p
    ,bp_multicore_2_cce_ucode_cfg_p
    ,bp_multicore_1_cce_ucode_megaparrot_cfg_p
    ,bp_multicore_1_cce_ucode_miniparrot_cfg_p
    ,bp_multicore_1_cce_ucode_cfg_p

    // Multicore configurations
    ,bp_multicore_16_cfg_p
    ,bp_multicore_12_cfg_p
    ,bp_multicore_8_cfg_p
    ,bp_multicore_6_cfg_p
    ,bp_multicore_4_cfg_p
    ,bp_multicore_3_cfg_p
    ,bp_multicore_2_cfg_p
    ,bp_multicore_1_megaparrot_cfg_p
    ,bp_multicore_1_miniparrot_cfg_p
    ,bp_multicore_1_cfg_p

    // Unicore configurations
    ,bp_unicore_megaparrot_cfg_p
    ,bp_unicore_miniparrot_cfg_p
    ,bp_unicore_tinyparrot_cfg_p
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
    // L2 extension configurations
    e_bp_multicore_4_l2e_cfg                        = 32
    ,e_bp_multicore_2_l2e_cfg                       = 31
    ,e_bp_multicore_1_l2e_cfg                       = 30

    // Accelerator configurations
    ,e_bp_multicore_4_acc_vdp_cfg                   = 29
    ,e_bp_multicore_4_acc_scratchpad_cfg            = 28
    ,e_bp_multicore_1_acc_vdp_cfg                   = 27
    ,e_bp_multicore_1_acc_scratchpad_cfg            = 26

    // Ucode configurations
    ,e_bp_multicore_16_cce_ucode_cfg                = 25
    ,e_bp_multicore_12_cce_ucode_cfg                = 24
    ,e_bp_multicore_8_cce_ucode_cfg                 = 23
    ,e_bp_multicore_6_cce_ucode_cfg                 = 22
    ,e_bp_multicore_4_cce_ucode_cfg                 = 21
    ,e_bp_multicore_3_cce_ucode_cfg                 = 20
    ,e_bp_multicore_2_cce_ucode_cfg                 = 19
    ,e_bp_multicore_1_cce_ucode_megaparrot_cfg      = 18
    ,e_bp_multicore_1_cce_ucode_miniparrot_cfg      = 17
    ,e_bp_multicore_1_cce_ucode_cfg                 = 16

    // Multicore configurations
    ,e_bp_multicore_16_cfg                          = 15
    ,e_bp_multicore_12_cfg                          = 14
    ,e_bp_multicore_8_cfg                           = 13
    ,e_bp_multicore_6_cfg                           = 12
    ,e_bp_multicore_4_cfg                           = 11
    ,e_bp_multicore_3_cfg                           = 10
    ,e_bp_multicore_2_cfg                           = 9
    ,e_bp_multicore_1_megaparrot_cfg                = 8
    ,e_bp_multicore_1_miniparrot_cfg                = 7
    ,e_bp_multicore_1_cfg                           = 6

    // Unicore configurations
    ,e_bp_unicore_megaparrot_cfg                    = 5
    ,e_bp_unicore_miniparrot_cfg                    = 4
    ,e_bp_unicore_tinyparrot_cfg                    = 3
    ,e_bp_unicore_cfg                               = 2

    // A custom BP configuration generated from `defines
    ,e_bp_custom_cfg                                = 1
    // The default BP
    ,e_bp_default_cfg                               = 0
  } bp_params_e;

`endif

