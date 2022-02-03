/*
 * bp_common_test_pkg.sv
 *
 * This package contains extra testing configs which are not intended to be
 *   synthesized or used in production. However, they are useful for testing.
 *   This file can also be used as a template for 3rd parties wishing to
 *   synthesize extra configs without modifying the BP source directly.
 *
 */

  `include "bp_common_defines.svh"

package bp_common_pkg;

  `include "bp_common_accelerator_pkgdef.svh"
  `include "bp_common_addr_pkgdef.svh"
  //`include "bp_common_aviary_pkgdef.svh"
  `include "bp_common_aviary_cfg_pkgdef.svh"

  // Default configuration is unicore
  localparam bp_proc_param_s bp_unicore_cfg_p = bp_default_cfg_p;

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

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_cfg_p
                        ,bp_multicore_1_cce_ucode_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_test_unicore_half_override_p =
    '{num_lce  : 1
      ,dcache_fill_width    : 64
      ,icache_fill_width    : 64
      ,l2_data_width        : 64
      ,l2_fill_width        : 64
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_unicore_half_cfg_p
                        ,bp_test_unicore_half_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_half_override_p =
    '{num_lce : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_half_cfg_p
                        ,bp_test_multicore_half_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_2x1_override_p =
    '{num_lce  : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_2x1_cfg_p
                        ,bp_test_multicore_2x1_override_p
                        ,bp_test_multicore_half_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_4x1_override_p =
    '{num_lce  : 4
      ,cc_x_dim : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_4x1_cfg_p
                        ,bp_test_multicore_4x1_override_p
                        ,bp_test_multicore_half_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_8x1_override_p =
    '{num_lce  : 8
      ,cc_x_dim : 2
      ,cc_y_dim : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_8x1_cfg_p
                        ,bp_test_multicore_8x1_override_p
                        ,bp_test_multicore_half_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_half_cce_ucode_override_p =
    '{num_lce  : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_half_cce_ucode_cfg_p
                        ,bp_test_multicore_half_cce_ucode_override_p
                        ,bp_multicore_1_cce_ucode_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_2x1_cce_ucode_override_p =
    '{num_lce  : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_2x1_cce_ucode_cfg_p
                        ,bp_test_multicore_2x1_cce_ucode_override_p
                        ,bp_test_multicore_half_cce_ucode_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_4x1_cce_ucode_override_p =
    '{num_lce  : 4
      ,cc_x_dim : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_4x1_cce_ucode_cfg_p
                        ,bp_test_multicore_4x1_cce_ucode_override_p
                        ,bp_test_multicore_half_cce_ucode_cfg_p
                        );

  localparam bp_proc_param_s bp_test_multicore_8x1_cce_ucode_override_p =
    '{num_lce  : 8
      ,cc_x_dim : 2
      ,cc_y_dim : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_test_multicore_8x1_cce_ucode_cfg_p
                        ,bp_test_multicore_8x1_cce_ucode_override_p
                        ,bp_test_multicore_half_cce_ucode_cfg_p
                        );

  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    // Various testing configs
    bp_test_multicore_8x1_cce_ucode_cfg_p
    ,bp_test_multicore_8x1_cfg_p
    ,bp_test_multicore_4x1_cce_ucode_cfg_p
    ,bp_test_multicore_4x1_cfg_p
    ,bp_test_multicore_2x1_cce_ucode_cfg_p
    ,bp_test_multicore_2x1_cfg_p
    ,bp_test_multicore_half_cce_ucode_cfg_p
    ,bp_test_multicore_half_cfg_p
    ,bp_test_unicore_half_cfg_p

    // A custom BP configuration generated from Makefile
    ,bp_custom_cfg_p
    // The default BP
    ,bp_default_cfg_p
  };

  // This enum MUST be kept up to date with the parameter array above
  typedef enum bit [lg_max_cfgs-1:0]
  {
    e_bp_test_multicore_8x1_cce_ucode_cfg           = 10
    ,e_bp_test_multicore_8x1_cfg                    = 9
    ,e_bp_test_multicore_4x1_cce_ucode_cfg          = 8
    ,e_bp_test_multicore_4x1_cfg                    = 7
    ,e_bp_test_multicore_2x1_cce_ucode_cfg          = 6
    ,e_bp_test_multicore_2x1_cfg                    = 5
    ,e_bp_test_multicore_half_cce_ucode_cfg         = 4
    ,e_bp_test_multicore_half_cfg                   = 3
    ,e_bp_test_unicore_half_cfg                     = 2

    // A custom BP configuration generated from `defines
    ,e_bp_custom_cfg                                = 1
    // The default BP
    ,e_bp_default_cfg                               = 0
  } bp_params_e;

  `include "bp_common_bedrock_pkgdef.svh"
  `include "bp_common_cache_pkgdef.svh"
  `include "bp_common_cache_engine_pkgdef.svh"
  `include "bp_common_cfg_bus_pkgdef.svh"
  `include "bp_common_clint_pkgdef.svh"
  `include "bp_common_core_pkgdef.svh"
  `include "bp_common_host_pkgdef.svh"
  `include "bp_common_rv64_pkgdef.svh"

endpackage

