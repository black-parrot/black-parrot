
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

      ,boot_pc       : bootrom_base_addr_gp
      ,boot_in_debug : 1

      ,branch_metadata_fwd_width: 35
      ,btb_tag_width            : 10
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

  // Default configuration is unicore
  localparam bp_proc_param_s bp_unicore_cfg_p = bp_default_cfg_p;

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
      ,default: "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_no_l2_cfg_p
                        ,bp_unicore_no_l2_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_unicore_l1_medium_override_p =
    '{icache_sets         : 64
      ,icache_assoc       : 4
      ,icache_block_width : 256
      ,icache_fill_width  : 256
      ,dcache_sets        : 64
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
    '{icache_sets         : 64
      ,icache_assoc       : 2
      ,icache_block_width : 128
      ,icache_fill_width  : 128
      ,dcache_sets        : 64
      ,dcache_assoc       : 2
      ,dcache_block_width : 128
      ,dcache_fill_width  : 128
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_unicore_l1_small_cfg_p
                        ,bp_unicore_l1_small_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_override_p =
    '{multicore : 1
      ,num_cce  : 1
      ,num_lce  : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cfg_p
                        ,bp_multicore_1_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_no_l2_override_p =
    '{l2_en   : 0
      ,default: "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_no_l2_cfg_p
                        ,bp_multicore_1_no_l2_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_l1_medium_override_p =
    '{icache_sets         : 64
      ,icache_assoc       : 4
      ,icache_block_width : 256
      ,icache_fill_width  : 256
      ,dcache_sets        : 64
      ,dcache_assoc       : 4
      ,dcache_block_width : 256
      ,dcache_fill_width  : 256
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_l1_medium_cfg_p
                        ,bp_multicore_1_l1_medium_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_l1_small_override_p =
    '{icache_sets         : 64
      ,icache_assoc       : 2
      ,icache_block_width : 128
      ,icache_fill_width  : 128
      ,dcache_sets        : 64
      ,dcache_assoc       : 2
      ,dcache_block_width : 128
      ,dcache_fill_width  : 128
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
      ,sacc_type: e_sacc_vdp
      ,num_lce  : 4
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_accelerator_cfg_p
                        ,bp_multicore_1_accelerator_override_p
                        ,bp_multicore_1_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_4_accelerator_override_p =
    '{cac_x_dim : 2
      ,sac_x_dim: 2
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,num_lce  : 10
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_4_accelerator_cfg_p
                        ,bp_multicore_4_accelerator_override_p
                        ,bp_multicore_4_cfg_p
                        );

  localparam bp_proc_param_s bp_multicore_1_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_multicore_1_cce_ucode_cfg_p
                        ,bp_multicore_1_cce_ucode_override_p
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

  // Custom, tick define-based configuration
  localparam bp_proc_param_s bp_custom_cfg_p =
    '{`bp_aviary_define_override(multicore, BP_MULTICORE, bp_default_cfg_p)
      ,`bp_aviary_define_override(cc_x_dim, BP_CC_X_DIM, bp_default_cfg_p)
      ,`bp_aviary_define_override(cc_y_dim, BP_CC_Y_DIM, bp_default_cfg_p)
      ,`bp_aviary_define_override(ic_y_dim, BP_IC_Y_DIM, bp_default_cfg_p)
      ,`bp_aviary_define_override(mc_y_dim, BP_MC_Y_DIM, bp_default_cfg_p)
      ,`bp_aviary_define_override(cac_x_dim, BP_CAC_X_DIM, bp_default_cfg_p)
      ,`bp_aviary_define_override(sac_x_dim, BP_SAC_X_DIM, bp_default_cfg_p)
      ,`bp_aviary_define_override(cacc_type, BP_CACC_TYPE, bp_default_cfg_p)
      ,`bp_aviary_define_override(sacc_type, BP_SACC_TYPE, bp_default_cfg_p)

      ,`bp_aviary_define_override(num_cce, BP_NUM_CCE, bp_default_cfg_p)
      ,`bp_aviary_define_override(num_lce, BP_NUM_LCE, bp_default_cfg_p)

      ,`bp_aviary_define_override(vaddr_width, BP_VADDR_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(paddr_width, BP_PADDR_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(asid_width, BP_ASID_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(boot_pc, BP_BOOT_PC, bp_default_cfg_p)
      ,`bp_aviary_define_override(boot_in_debug, BP_BOOT_IN_DEBUG, bp_default_cfg_p)

      ,`bp_aviary_define_override(fe_queue_fifo_els, BP_FE_QUEUE_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(fe_cmd_fifo_els, BP_FE_CMD_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(branch_metadata_fwd_width, BRANCH_METADATA_FWD_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(btb_tag_width, BP_BTB_TAG_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(btb_idx_width, BP_BTB_IDX_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(bht_idx_width, BP_BHT_IDX_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(ghist_width, BP_GHIST_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(itlb_els, BP_ITLB_ELS, bp_default_cfg_p)
      ,`bp_aviary_define_override(dtlb_els, BP_DTLB_ELS, bp_default_cfg_p)

      ,`bp_aviary_define_override(lr_sc, BP_LR_SC, bp_default_cfg_p)
      ,`bp_aviary_define_override(amo_swap, BP_AMO_SWAP, bp_default_cfg_p)
      ,`bp_aviary_define_override(amo_fetch_logic, BP_AMO_FETCH_LOGIC, bp_default_cfg_p)
      ,`bp_aviary_define_override(amo_fetch_arithmetic, BP_AMO_FETCH_ARITHMETIC, bp_default_cfg_p)

      ,`bp_aviary_define_override(l1_writethrough, BP_L1_WRITETHROUGH, bp_default_cfg_p)
      ,`bp_aviary_define_override(l1_coherent, BP_L1_COHERENT, bp_default_cfg_p)

      ,`bp_aviary_define_override(icache_sets, BP_ICACHE_SETS, bp_default_cfg_p)
      ,`bp_aviary_define_override(icache_assoc, BP_ICACHE_ASSOC, bp_default_cfg_p)
      ,`bp_aviary_define_override(icache_block_width, BP_ICACHE_BLOCK_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(icache_fill_width, BP_ICACHE_FILL_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(dcache_sets, BP_DCACHE_SETS, bp_default_cfg_p)
      ,`bp_aviary_define_override(dcache_assoc, BP_DCACHE_ASSOC, bp_default_cfg_p)
      ,`bp_aviary_define_override(dcache_block_width, BP_DCACHE_BLOCK_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(dcache_fill_width, BP_DCACHE_FILL_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(acache_sets, BP_ACACHE_SETS, bp_default_cfg_p)
      ,`bp_aviary_define_override(acache_assoc, BP_ACACHE_ASSOC, bp_default_cfg_p)
      ,`bp_aviary_define_override(acache_block_width, BP_ACACHE_BLOCK_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(acache_fill_width, BP_ACACHE_FILL_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(cce_ucode, BP_CCE_UCODE, bp_default_cfg_p)
      ,`bp_aviary_define_override(cce_pc_width, BP_CCE_PC_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(l2_en, BP_L2_EN, bp_default_cfg_p)
      ,`bp_aviary_define_override(l2_sets, BP_L2_SETS, bp_default_cfg_p)
      ,`bp_aviary_define_override(l2_assoc, BP_L2_ASSOC, bp_default_cfg_p)
      ,`bp_aviary_define_override(l2_outstanding_reqs, BP_L2_OUTSTANDING_REQS, bp_default_cfg_p)

      ,`bp_aviary_define_override(async_coh_clk, BP_ASYNC_COH_CLK, bp_default_cfg_p)
      ,`bp_aviary_define_override(coh_noc_max_credits, BP_COH_NOC_MAX_CREDITS, bp_default_cfg_p)
      ,`bp_aviary_define_override(coh_noc_flit_width, BP_COH_NOC_FLIT_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(coh_noc_cid_width, BP_COH_NOC_CID_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(coh_noc_len_width, BP_COH_NOC_LEN_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(async_mem_clk, BP_ASYNC_MEM_CLK, bp_default_cfg_p)
      ,`bp_aviary_define_override(mem_noc_max_credits, BP_MEM_NOC_MAX_CREDITS, bp_default_cfg_p)
      ,`bp_aviary_define_override(mem_noc_flit_width, BP_MEM_NOC_FLIT_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(mem_noc_cid_width, BP_MEM_NOC_CID_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(mem_noc_len_width, BP_MEM_NOC_LEN_WIDTH, bp_default_cfg_p)

      ,`bp_aviary_define_override(async_io_clk, BP_ASYNC_IO_CLK, bp_default_cfg_p)
      ,`bp_aviary_define_override(io_noc_max_credits, BP_IO_NOC_MAX_CREDITS, bp_default_cfg_p)
      ,`bp_aviary_define_override(io_noc_flit_width, BP_IO_NOC_FLIT_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(io_noc_cid_width, BP_IO_NOC_CID_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(io_noc_did_width, BP_IO_NOC_DID_WIDTH, bp_default_cfg_p)
      ,`bp_aviary_define_override(io_noc_len_width, BP_IO_NOC_LEN_WIDTH, bp_default_cfg_p)
      };

  /* verilator lint_off WIDTH */
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    // Various testing configs
    bp_multicore_cce_ucode_half_cfg_p
    ,bp_multicore_half_cfg_p
    ,bp_unicore_half_cfg_p

    // Multicore configurations
    ,bp_multicore_16_cce_ucode_cfg_p
    ,bp_multicore_16_cfg_p
    ,bp_multicore_12_cce_ucode_cfg_p
    ,bp_multicore_12_cfg_p
    ,bp_multicore_8_cce_ucode_cfg_p
    ,bp_multicore_8_cfg_p
    ,bp_multicore_6_cce_ucode_cfg_p
    ,bp_multicore_6_cfg_p
    ,bp_multicore_4_accelerator_cfg_p
    ,bp_multicore_4_cce_ucode_cfg_p
    ,bp_multicore_4_cfg_p
    ,bp_multicore_3_cce_ucode_cfg_p
    ,bp_multicore_3_cfg_p
    ,bp_multicore_2_cce_ucode_cfg_p
    ,bp_multicore_2_cfg_p
    ,bp_multicore_1_accelerator_cfg_p
    ,bp_multicore_1_cce_ucode_cfg_p
    ,bp_multicore_1_l1_medium_cfg_p
    ,bp_multicore_1_l1_small_cfg_p
    ,bp_multicore_1_cfg_p

    // Unicore configurations
    ,bp_unicore_writethrough_cfg_p
    ,bp_unicore_l1_medium_cfg_p
    ,bp_unicore_l1_small_cfg_p
    ,bp_unicore_no_l2_cfg_p
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
    // Various testing configs
    e_bp_multicore_cce_ucode_half_cfg       = 29
    ,e_bp_multicore_half_cfg                = 28
    ,e_bp_unicore_half_cfg                  = 27

    // Multicore configurations
    ,e_bp_multicore_16_cce_ucode_cfg        = 26
    ,e_bp_multicore_16_cfg                  = 25
    ,e_bp_multicore_12_cce_ucode_cfg        = 24
    ,e_bp_multicore_12_cfg                  = 23
    ,e_bp_multicore_8_cce_ucode_cfg         = 22
    ,e_bp_multicore_8_cfg                   = 21
    ,e_bp_multicore_6_cce_ucode_cfg         = 20
    ,e_bp_multicore_6_cfg                   = 19
    ,e_bp_multicore_4_accelerator_cfg       = 18
    ,e_bp_multicore_4_cce_ucode_cfg         = 17
    ,e_bp_multicore_4_cfg                   = 16
    ,e_bp_multicore_3_cce_ucode_cfg         = 15
    ,e_bp_multicore_3_cfg                   = 14
    ,e_bp_multicore_2_cce_ucode_cfg         = 13
    ,e_bp_multicore_2_cfg                   = 12
    ,e_bp_multicore_1_accelerator_cfg       = 11
    ,e_bp_multicore_1_cce_ucode_cfg         = 10
    ,e_bp_multicore_1_l1_medium_cfg         = 9
    ,e_bp_multicore_1_l1_small_cfg          = 8
    ,e_bp_multicore_1_cfg                   = 7

    // Unicore configurations
    ,e_bp_unicore_writethrough_cfg          = 6
    ,e_bp_unicore_l1_medium_cfg             = 5
    ,e_bp_unicore_l1_small_cfg              = 4
    ,e_bp_unicore_no_l2_cfg                 = 3
    ,e_bp_unicore_cfg                       = 2

    // A custom BP configuration generated from Makefile
    ,e_bp_custom_cfg                        = 1
    // The default BP
    ,e_bp_default_cfg                       = 0
  } bp_params_e;

endpackage

