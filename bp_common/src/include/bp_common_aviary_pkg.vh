
package bp_common_aviary_pkg;
  `include "bp_common_aviary_defines.vh"

  import bp_common_pkg::*;
    // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs);

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
      ,asid_width : 1

      ,boot_pc       : dram_base_addr_gp
      ,boot_in_debug : 0

      ,branch_metadata_fwd_width: 37
      ,btb_tag_width            : 9
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ghist_width              : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

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

      ,l2_en   : 1
      ,l2_sets : 128
      ,l2_assoc: 8
      ,l2_outstanding_reqs: 8

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 4

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
  localparam bp_proc_param_s bp_unicore_cfg_p = bp_default_cfg_p;

  localparam bp_proc_param_s bp_unicore_bootrom_override_p =
    '{boot_pc        : bootrom_base_addr_gp
      ,boot_in_debug : 1
      ,default       : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_bootrom_cfg_p
                        ,bp_unicore_bootrom_override_p
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

  localparam bp_proc_param_s bp_unicore_no_l2_override_p =
    '{l2_en   : 0
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_no_l2_cfg_p
                        ,bp_unicore_no_l2_override_p
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
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_small_cfg_p
                        ,bp_unicore_l1_small_override_p
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
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_wide_cfg_p
                        ,bp_unicore_l1_wide_override_p
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
                        ,bp_unicore_cfg_p
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
      ,sacc_type: e_sacc_zipline//e_sacc_vdp
      ,num_lce  : 3//4?
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
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_half_override_p =
    '{num_lce  : 1
      ,default : "inv"
>>>>>>> add zipline files-tests
      };

  localparam bp_proc_param_s bp_twelve_core_ucode_cce_cfg_p =
    '{cc_x_dim   : 4
      ,cc_y_dim  : 3
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,cac_x_dim : 0
      ,sac_x_dim : 0
      ,cacc_type : e_cacc_vdp
      ,sacc_type : e_sacc_vdp

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 35
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ghist_width              : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,l1_writethrough      : 0
      ,l1_coherent          : 1
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

      ,cce_pc_width         : 8
      ,ucode_cce            : 1

      ,l2_en   : 1
      ,l2_sets : 128
      ,l2_assoc: 8
      ,l2_outstanding_reqs: 8

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 4

      ,async_coh_clk       : 0
      ,coh_noc_max_credits : 8
      ,coh_noc_flit_width  : 128
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 3

      ,async_mem_clk         : 1
      ,mem_noc_max_credits   : 8
      ,mem_noc_flit_width    : 64
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 4

      ,async_io_clk         : 1
      ,io_noc_did_width     : 3
      ,io_noc_max_credits   : 16
      ,io_noc_flit_width    : 64
      ,io_noc_cid_width     : 2
      ,io_noc_len_width     : 4
      };

  localparam bp_proc_param_s bp_sexta_core_ucode_cce_cfg_p =
    '{cc_x_dim   : 4
      ,cc_y_dim  : 4
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,cac_x_dim : 0
      ,sac_x_dim : 0
      ,cacc_type : e_cacc_vdp
      ,sacc_type : e_sacc_vdp

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 35
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ghist_width              : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,l1_writethrough      : 0
      ,l1_coherent          : 1
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

      ,cce_pc_width         : 8
      ,ucode_cce            : 1

      ,l2_en   : 1
      ,l2_sets : 128
      ,l2_assoc: 8
      ,l2_outstanding_reqs: 8

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 4

      ,async_coh_clk       : 0
      ,coh_noc_max_credits : 8
      ,coh_noc_flit_width  : 128
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 3

      ,async_mem_clk         : 1
      ,mem_noc_max_credits   : 8
      ,mem_noc_flit_width    : 64
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 4

      ,async_io_clk         : 1
      ,io_noc_did_width     : 3
      ,io_noc_max_credits   : 16
      ,io_noc_flit_width    : 64
      ,io_noc_cid_width     : 1
      ,io_noc_len_width     : 4
      };


  typedef enum bit [lg_max_cfgs-1:0]
  {
    e_bp_unicore_writethrough_cfg    = 28
    ,e_bp_single_core_l1_medium_cfg   = 27
    ,e_bp_single_core_l1_small_cfg    = 26
    ,e_bp_unicore_l1_medium_cfg      = 25
    ,e_bp_unicore_l1_small_cfg       = 24
    ,e_bp_sexta_core_ucode_cce_cfg    = 23
    ,e_bp_twelve_core_ucode_cce_cfg   = 22
    ,e_bp_oct_core_ucode_cce_cfg      = 21
    ,e_bp_hexa_core_ucode_cce_cfg     = 20
    ,e_bp_quad_core_ucode_cce_cfg     = 19
    ,e_bp_tri_core_ucode_cce_cfg      = 18
    ,e_bp_dual_core_ucode_cce_cfg     = 17
    ,e_bp_single_core_ucode_cce_cfg   = 16
    ,e_bp_half_core_ucode_cce_cfg     = 15
    ,e_bp_accelerator_quad_core_cfg   = 14
    ,e_bp_accelerator_single_core_cfg = 13
    ,e_bp_sexta_core_cfg              = 12
    ,e_bp_twelve_core_cfg             = 11
    ,e_bp_oct_core_cfg                = 10
    ,e_bp_hexa_core_cfg               = 9
    ,e_bp_quad_core_cfg               = 8
    ,e_bp_tri_core_cfg                = 7
    ,e_bp_dual_core_cfg               = 6
    ,e_bp_single_core_cfg             = 5
    ,e_bp_single_core_no_l2_cfg       = 4
    ,e_bp_half_core_cfg               = 3
    ,e_bp_unicore_cfg                = 2
    ,e_bp_unicore_no_l2_cfg          = 1
    ,e_bp_inv_cfg                     = 0
  } bp_params_e;

  /* verilator lint_off WIDTH */
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    bp_unicore_writethrough_cfg_p
    ,bp_single_core_l1_medium_cfg_p
    ,bp_single_core_l1_small_cfg_p
    ,bp_unicore_l1_medium_cfg_p
    ,bp_unicore_l1_small_cfg_p
    ,bp_sexta_core_ucode_cce_cfg_p
    ,bp_twelve_core_ucode_cce_cfg_p
    ,bp_oct_core_ucode_cce_cfg_p
    ,bp_hexa_core_ucode_cce_cfg_p
    ,bp_quad_core_ucode_cce_cfg_p
    ,bp_tri_core_ucode_cce_cfg_p
    ,bp_dual_core_ucode_cce_cfg_p
    ,bp_single_core_ucode_cce_cfg_p
    ,bp_half_core_ucode_cce_cfg_p
    ,bp_accelerator_quad_core_cfg_p
    ,bp_accelerator_single_core_cfg_p
    ,bp_sexta_core_cfg_p
    ,bp_twelve_core_cfg_p
    ,bp_oct_core_cfg_p
    ,bp_hexa_core_cfg_p
    ,bp_quad_core_cfg_p
    ,bp_tri_core_cfg_p
    ,bp_dual_core_cfg_p
    ,bp_single_core_cfg_p
    ,bp_single_core_no_l2_cfg_p
    ,bp_half_core_cfg_p
    ,bp_unicore_cfg_p
    ,bp_unicore_no_l2_cfg_p
    ,bp_inv_cfg_p
  };
  /* verilator lint_on WIDTH */

endpackage
