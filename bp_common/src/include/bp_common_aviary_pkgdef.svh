`ifndef BP_COMMON_AVIARY_PKGDEF_SVH
`define BP_COMMON_AVIARY_PKGDEF_SVH

  `include "bp_common_aviary_cfg_pkgdef.svh"
  `include "bp_common_host_pkgdef.svh"

  // Default configuration is unicore
  localparam bp_proc_param_s bp_unicore_cfg_p = bp_default_cfg_p;

  localparam bp_proc_param_s bp_unicore_bootrom_override_p =
    '{boot_pc        : bootrom_base_addr_gp
      ,boot_in_debug : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_bootrom_cfg_p
                        ,bp_unicore_bootrom_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_no_l2_override_p =
    '{l2_en : 0
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_no_l2_cfg_p
                        ,bp_unicore_no_l2_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_paddr_large_override_p =
    '{paddr_width : 44
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_paddr_large_cfg_p
                        ,bp_unicore_paddr_large_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_paddr_small_override_p =
    '{paddr_width : 33
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_paddr_small_cfg_p
                        ,bp_unicore_paddr_small_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_tinyparrot_override_p =
    '{paddr_width         : 34

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 6
      ,btb_idx_width            : 4
      ,bht_idx_width            : 5
      ,bht_row_els              : 2
      ,ghist_width              : 2

      ,icache_sets        : 512
      ,icache_assoc       : 1
      ,icache_block_width : 64
      ,icache_fill_width  : 64

      ,dcache_amo_support : (1 << e_lr_sc)
      ,dcache_sets        : 512
      ,dcache_assoc       : 1
      ,dcache_block_width : 64
      ,dcache_fill_width  : 64

      ,l2_en          : 0
      ,l2_amo_support : '0

      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_tinyparrot_cfg_p
                        ,bp_unicore_tinyparrot_override_p
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
    '{icache_sets         : 512
      ,icache_assoc       : 1
      ,icache_block_width : 64
      ,icache_fill_width  : 64
      ,dcache_sets        : 512
      ,dcache_assoc       : 1
      ,dcache_block_width : 64
      ,dcache_fill_width  : 64
      ,l2_data_width      : 64
      ,l2_fill_width      : 64
      ,mem_noc_flit_width : 64
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
      ,dcache_fill_width  : 128
      ,l2_data_width      : 128
      ,l2_fill_width      : 128
      ,mem_noc_flit_width : 128
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

  localparam bp_proc_param_s bp_unicore_l2_atomic_override_p =
    '{dcache_amo_support : (1 << e_lr_sc)
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l2_atomic_cfg_p
                        ,bp_unicore_l2_atomic_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_writethrough_override_p =
    '{dcache_writethrough: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_writethrough_cfg_p
                        ,bp_unicore_writethrough_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_override_p =
    '{multicore             : 1
      ,ic_y_dim             : 1
      ,num_cce              : 1
      ,num_lce              : 2
      ,icache_coherent      : 1
      ,l2_amo_support       : '0
      ,l2_banks             : 1
      ,dcache_fill_width    : 512
      ,icache_fill_width    : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cfg_p
                        ,bp_multicore_1_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_paddr_large_override_p =
    '{paddr_width : 44
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_paddr_large_cfg_p
                        ,bp_multicore_1_paddr_large_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_paddr_small_override_p =
    '{paddr_width : 33
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_paddr_small_cfg_p
                        ,bp_multicore_1_paddr_small_override_p
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
    '{l2_en : 0
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
      ,l2_banks: 1
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
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_16_cfg_p
                        ,bp_multicore_16_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_acc_loopback_override_p =
    '{cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_loopback
      ,num_lce  : 3
      ,dcache_fill_width : 512
      ,icache_fill_width : 512
      ,acache_fill_width : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_acc_loopback_cfg_p
                        ,bp_multicore_1_acc_loopback_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_acc_vdp_override_p =
    '{cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,num_lce  : 3
      ,dcache_fill_width : 512
      ,icache_fill_width : 512
      ,acache_fill_width : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_acc_vdp_cfg_p
                        ,bp_multicore_1_acc_vdp_override_p
                        ,bp_multicore_1_cfg_p
                        );


 localparam bp_proc_param_s bp_multicore_4_acc_loopback_override_p =
    '{cc_x_dim : 2
      ,cc_y_dim: 2
      ,cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_loopback
      ,num_cce : 4
      ,num_lce  : 10
      ,dcache_fill_width : 512
      ,icache_fill_width : 512
      ,acache_fill_width : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_acc_loopback_cfg_p
                        ,bp_multicore_4_acc_loopback_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_acc_vdp_override_p =
    '{cc_x_dim : 2
      ,cc_y_dim: 2
      ,cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,num_cce : 4
      ,num_lce  : 10
      ,dcache_fill_width : 512
      ,icache_fill_width : 512
      ,acache_fill_width : 512
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_acc_vdp_cfg_p
                        ,bp_multicore_4_acc_vdp_override_p
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

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_paddr_small_override_p =
    '{paddr_width : 33
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_paddr_small_cfg_p
                        ,bp_multicore_1_cce_ucode_paddr_small_override_p
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

  /* verilator lint_off WIDTH */
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    // L2 extension configurations
    bp_multicore_4_l2e_cfg_p
    ,bp_multicore_2_l2e_cfg_p
    ,bp_multicore_1_l2e_cfg_p

    // Accelerator configurations
    ,bp_multicore_4_acc_vdp_cfg_p
    ,bp_multicore_4_acc_loopback_cfg_p
    ,bp_multicore_1_acc_vdp_cfg_p
    ,bp_multicore_1_acc_loopback_cfg_p

    // Ucode configurations
    ,bp_multicore_16_cce_ucode_cfg_p
    ,bp_multicore_12_cce_ucode_cfg_p
    ,bp_multicore_8_cce_ucode_cfg_p
    ,bp_multicore_6_cce_ucode_cfg_p
    ,bp_multicore_4_cce_ucode_cfg_p
    ,bp_multicore_3_cce_ucode_cfg_p
    ,bp_multicore_2_cce_ucode_cfg_p
    ,bp_multicore_1_cce_ucode_paddr_small_cfg_p
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
    ,bp_multicore_1_paddr_small_cfg_p
    ,bp_multicore_1_paddr_large_cfg_p
    ,bp_multicore_1_l1_small_cfg_p
    ,bp_multicore_1_l1_medium_cfg_p
    ,bp_multicore_1_no_l2_cfg_p
    ,bp_multicore_1_bootrom_cfg_p
    ,bp_multicore_1_cfg_p

    // Unicore configurations
    ,bp_unicore_tinyparrot_cfg_p
    ,bp_unicore_paddr_small_cfg_p
    ,bp_unicore_paddr_large_cfg_p
    ,bp_unicore_writethrough_cfg_p
    ,bp_unicore_l2_atomic_cfg_p
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
    // L2 extension configurations
    e_bp_multicore_4_l2e_cfg                        = 46
    ,e_bp_multicore_2_l2e_cfg                       = 45
    ,e_bp_multicore_1_l2e_cfg                       = 44

    // Accelerator configurations
    ,e_bp_multicore_4_acc_vdp_cfg                   = 43
    ,e_bp_multicore_4_acc_loopback_cfg              = 42
    ,e_bp_multicore_1_acc_vdp_cfg                   = 41
    ,e_bp_multicore_1_acc_loopback_cfg              = 40

    // Ucode configurations
    ,e_bp_multicore_16_cce_ucode_cfg                = 39
    ,e_bp_multicore_12_cce_ucode_cfg                = 38
    ,e_bp_multicore_8_cce_ucode_cfg                 = 37
    ,e_bp_multicore_6_cce_ucode_cfg                 = 36
    ,e_bp_multicore_4_cce_ucode_cfg                 = 35
    ,e_bp_multicore_3_cce_ucode_cfg                 = 34
    ,e_bp_multicore_2_cce_ucode_cfg                 = 33
    ,e_bp_multicore_1_cce_ucode_paddr_small_cfg     = 32
    ,e_bp_multicore_1_cce_ucode_paddr_large_cfg     = 31
    ,e_bp_multicore_1_cce_ucode_bootrom_cfg         = 30
    ,e_bp_multicore_1_cce_ucode_cfg                 = 29

    // Multicore configurations
    ,e_bp_multicore_16_cfg                          = 28
    ,e_bp_multicore_12_cfg                          = 27
    ,e_bp_multicore_8_cfg                           = 26
    ,e_bp_multicore_6_cfg                           = 25
    ,e_bp_multicore_4_cfg                           = 24
    ,e_bp_multicore_3_cfg                           = 23
    ,e_bp_multicore_2_cfg                           = 22
    ,e_bp_multicore_1_paddr_small_cfg               = 21
    ,e_bp_multicore_1_paddr_large_cfg               = 20
    ,e_bp_multicore_1_l1_small_cfg                  = 19
    ,e_bp_multicore_1_l1_medium_cfg                 = 18
    ,e_bp_multicore_1_no_l2_cfg                     = 17
    ,e_bp_multicore_1_bootrom_cfg                   = 16
    ,e_bp_multicore_1_cfg                           = 15

    // Unicore configurations
    ,e_bp_unicore_tinyparrot_cfg                    = 14
    ,e_bp_unicore_paddr_small_cfg                   = 13
    ,e_bp_unicore_paddr_large_cfg                   = 12
    ,e_bp_unicore_writethrough_cfg                  = 11
    ,e_bp_unicore_l2_atomic_cfg                     = 10
    ,e_bp_unicore_l1_wide_cfg                       = 9
    ,e_bp_unicore_l1_hetero_cfg                     = 8
    ,e_bp_unicore_l1_tiny_cfg                       = 7
    ,e_bp_unicore_l1_small_cfg                      = 6
    ,e_bp_unicore_l1_medium_cfg                     = 5
    ,e_bp_unicore_no_l2_cfg                         = 4
    ,e_bp_unicore_bootrom_cfg                       = 3
    ,e_bp_unicore_cfg                               = 2

    // A custom BP configuration generated from `defines
    ,e_bp_custom_cfg                                = 1
    // The default BP
    ,e_bp_default_cfg                               = 0
  } bp_params_e;

`endif

