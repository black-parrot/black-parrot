
package bp_common_aviary_pkg;
  `include "bp_common_aviary_defines.vh"

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs);

  localparam bp_proc_param_s bp_inv_cfg_p =
    '{default: 1};

  localparam bp_proc_param_s bp_unicore_cfg_p =
    '{multicore  : 0
      ,cc_x_dim  : 1
      ,cc_y_dim  : 1
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,cac_x_dim : 0
      ,sac_x_dim : 0
      ,cacc_type : e_cacc_vdp
      ,sacc_type : e_sacc_vdp

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 36
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

      ,cce_pc_width         : 8
      ,cce_ucode            : 0

      ,l2_en   : 1
      ,l2_sets : 128
      ,l2_assoc: 8
      ,l2_outstanding_reqs: 2

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
  // We differentiate some defines based on the name, rather than the config parameters themselves
  localparam bp_proc_param_s bp_half_core_cfg_p = bp_unicore_cfg_p;

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

  localparam bp_proc_param_s bp_single_core_override_p =
    '{multicore : 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_single_core_cfg_p
                        ,bp_single_core_override_p
                        ,bp_unicore_cfg_p
                        );

  localparam bp_proc_param_s bp_single_core_no_l2_override_p =
    '{l2_en   : 0
      ,default: "inv"
      };
  `bp_aviary_derive_cfg(bp_single_core_no_l2_cfg_p
                        ,bp_single_core_no_l2_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_single_core_l1_medium_override_p =
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
  `bp_aviary_derive_cfg(bp_single_core_l1_medium_cfg_p
                        ,bp_single_core_l1_medium_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_single_core_l1_small_override_p =
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
  `bp_aviary_derive_cfg(bp_single_core_l1_small_cfg_p
                        ,bp_single_core_l1_small_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_dual_core_override_p =
    '{cc_x_dim : 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_dual_core_cfg_p
                        ,bp_dual_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_tri_core_override_p =
    '{cc_x_dim : 3
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_tri_core_cfg_p
                        ,bp_tri_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_quad_core_override_p =
    '{cc_x_dim : 2
      ,cc_y_dim: 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_quad_core_cfg_p
                        ,bp_quad_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_hexa_core_override_p =
    '{cc_x_dim : 3
      ,cc_y_dim: 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_hexa_core_cfg_p
                        ,bp_hexa_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_oct_core_override_p =
    '{cc_x_dim : 4
      ,cc_y_dim: 2
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_oct_core_cfg_p
                        ,bp_oct_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_twelve_core_override_p =
    '{cc_x_dim : 4
      ,cc_y_dim: 3
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_twelve_core_cfg_p
                        ,bp_twelve_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_sexta_core_override_p =
    '{cc_x_dim : 4
      ,cc_y_dim: 4
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_sexta_core_cfg_p
                        ,bp_sexta_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_accelerator_single_core_override_p =
    '{cac_x_dim : 1
      ,sac_x_dim: 1
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_accelerator_single_core_cfg_p
                        ,bp_accelerator_single_core_override_p
                        ,bp_single_core_cfg_p
                        );

  localparam bp_proc_param_s bp_accelerator_quad_core_override_p =
    '{cac_x_dim : 2
      ,sac_x_dim: 2
      ,cacc_type: e_cacc_vdp
      ,sacc_type: e_sacc_vdp
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_accelerator_quad_core_cfg_p
                        ,bp_accelerator_quad_core_override_p
                        ,bp_quad_core_cfg_p
                        );

  localparam bp_proc_param_s bp_single_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_single_core_cce_ucode_cfg_p
                        ,bp_single_core_cce_ucode_override_p
                        ,bp_single_core_cfg_p
                        );
  // We differentiate some defines based on the name, rather than the config parameters themselves
  localparam bp_proc_param_s bp_half_core_cce_ucode_cfg_p = bp_single_core_cce_ucode_cfg_p;

  localparam bp_proc_param_s bp_dual_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_dual_core_cce_ucode_cfg_p
                        ,bp_dual_core_cce_ucode_override_p
                        ,bp_dual_core_cfg_p
                        );

  localparam bp_proc_param_s bp_tri_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_tri_core_cce_ucode_cfg_p
                        ,bp_tri_core_cce_ucode_override_p
                        ,bp_tri_core_cfg_p
                        );

  localparam bp_proc_param_s bp_quad_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_quad_core_cce_ucode_cfg_p
                        ,bp_quad_core_cce_ucode_override_p
                        ,bp_quad_core_cfg_p
                        );

  localparam bp_proc_param_s bp_hexa_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_hexa_core_cce_ucode_cfg_p
                        ,bp_hexa_core_cce_ucode_override_p
                        ,bp_hexa_core_cfg_p
                        );

  localparam bp_proc_param_s bp_oct_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_oct_core_cce_ucode_cfg_p
                        ,bp_oct_core_cce_ucode_override_p
                        ,bp_oct_core_cfg_p
                        );

  localparam bp_proc_param_s bp_twelve_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_twelve_core_cce_ucode_cfg_p
                        ,bp_twelve_core_cce_ucode_override_p
                        ,bp_twelve_core_cfg_p
                        );

  localparam bp_proc_param_s bp_sexta_core_cce_ucode_override_p =
    '{cce_ucode: 1
      ,default : "inv"
      };
  `bp_aviary_derive_cfg(bp_sexta_core_cce_ucode_cfg_p
                        ,bp_sexta_core_cce_ucode_override_p
                        ,bp_sexta_core_cfg_p
                        );

  //localparam bp_proc_param_s bp_custom_cfg_p =
  //  '{multicore  : `BP_MULTICORE
  //    ,cc_x_dim  : `BP_CC_X_DIM
  //    ,cc_y_dim  : `BP_CC_Y_DIM
  //    ,ic_y_dim  : `BP_IC_Y_DIM
  //    ,mc_y_dim  : `BP_MC_Y_DIM
  //    ,cac_x_dim : `BP_CAC_X_DIM
  //    ,sac_x_dim : `BP_SAC_X_DIM
  //    ,cacc_type : `BP_CACC_TYPE
  //    ,sacc_type : `BP_SACC_TYPE

  //    ,vaddr_width: `BP_VADDR_WIDTH
  //    ,paddr_width: `BP_PADDR_WIDTH
  //    ,asid_width : `BP_ASID_WIDTH

  //    ,branch_metadata_fwd_width: `BP_BRANCH_METADATA_FWD_WIDTH
  //    ,btb_tag_width            : `BP_BTB_TAG_WIDTH
  //    ,btb_idx_width            : `BP_BTB_IDX_WIDTH
  //    ,bht_idx_width            : `BP_BHT_IDX_WIDTH
  //    ,ghist_width              : `BP_GHIST_WIDTH

  //    ,itlb_els             : `BP_ITLB_ELS
  //    ,dtlb_els             : `BP_DTLB_ELS

  //    ,lr_sc                : `BP_LR_SC
  //    ,amo_swap             : `BP_AMO_SWAP
  //    ,amo_fetch_logic      : `BP_AMO_FETCH_LOGIC
  //    ,amo_fetch_arithmetic : `BP_AMO_FETCH_ARTITHMETIC
  //    
  //    ,l1_writethrough      : `BP_L1_WRITETHROUGH
  //    ,l1_coherent          : `BP_L1_COHERENT
  //    ,dcache_sets          : `BP_DCACHE_SETS
  //    ,dcache_assoc         : `BP_DCACHE_ASSOC
  //    ,dcache_block_width   : `BP_DCACHE_BLOCK_WIDTH
  //    ,dcache_fill_width    : `BP_DCACHE_FILL_WIDTH
  //    ,icache_sets          : `BP_ICACHE_SETS
  //    ,icache_assoc         : `BP_ICACHE_ASSOC
  //    ,icache_block_width   : `BP_ICACHE_BLOCK_WIDTH
  //    ,icache_fill_width    : `BP_ICACHE_FILL_WIDTH
  //    ,acache_sets          : `BP_ACACHE_SETS
  //    ,acache_assoc         : `BP_ACACHE_ASSOC
  //    ,acache_block_width   : `BP_ACACHE_BLOCK_WIDTH
  //    ,acache_fill_width    : `BP_ACACHE_FILL_WIDTH

  //    ,cce_pc_width         : `BP_CCE_PC_WIDTH
  //    ,cce_ucode            : `BP_CCE_UCODE

  //    ,l2_en   : `BP_L2_EN
  //    ,l2_sets : `BP_L2_SETS
  //    ,l2_assoc: `BP_L2_ASSOC
  //    ,l2_outstanding_reqs: `BP_L2_OUTSTANDING_REQS

  //    ,fe_queue_fifo_els: `BP_FE_QUEUE_FIFO_ELS
  //    ,fe_cmd_fifo_els  : `BP_FE_CMD_FIFO_ELS

  //    ,async_coh_clk       : `BP_ASYNC_COH_CLK
  //    ,coh_noc_max_credits : `BP_COH_NOC_MAX_CREDITS
  //    ,coh_noc_flit_width  : `BP_COH_NOC_FLIT_WIDTH
  //    ,coh_noc_cid_width   : `BP_COH_NOC_CID_WIDTH
  //    ,coh_noc_len_width   : `BP_COH_NOC_LEN_WIDTH

  //    ,async_mem_clk         : `BP_ASYNC_MEM_CLK
  //    ,mem_noc_max_credits   : `BP_MEM_NOC_MAX_CREDITS
  //    ,mem_noc_flit_width    : `BP_MEM_NOC_FLIT_WIDTH
  //    ,mem_noc_cid_width     : `BP_MEM_NOC_CID_WIDTH
  //    ,mem_noc_len_width     : `BP_MEM_NOC_LEN_WIDTH

  //    ,async_io_clk         : `BP_ASYNC_IO_CLK
  //    ,io_noc_did_width     : `BP_IO_NOC_DID_WIDTH
  //    ,io_noc_max_credits   : `BP_IO_NOC_MAX_CREDITS
  //    ,io_noc_flit_width    : `BP_IO_NOC_FLIT_WIDTH
  //    ,io_noc_cid_width     : `BP_IO_NOC_CID_WIDTH
  //    ,io_noc_len_width     : `BP_IO_NOC_LEN_WIDTH
  //    };

  typedef enum bit [lg_max_cfgs-1:0]
  {
    e_bp_unicore_writethrough_cfg    = 28
    ,e_bp_single_core_l1_medium_cfg   = 27
    ,e_bp_single_core_l1_small_cfg    = 26
    ,e_bp_unicore_l1_medium_cfg      = 25
    ,e_bp_unicore_l1_small_cfg       = 24
    ,e_bp_sexta_core_cce_ucode_cfg    = 23
    ,e_bp_twelve_core_cce_ucode_cfg   = 22
    ,e_bp_oct_core_cce_ucode_cfg      = 21
    ,e_bp_hexa_core_cce_ucode_cfg     = 20
    ,e_bp_quad_core_cce_ucode_cfg     = 19
    ,e_bp_tri_core_cce_ucode_cfg      = 18
    ,e_bp_dual_core_cce_ucode_cfg     = 17
    ,e_bp_single_core_cce_ucode_cfg   = 16
    ,e_bp_half_core_cce_ucode_cfg     = 15
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
    ,bp_sexta_core_cce_ucode_cfg_p
    ,bp_twelve_core_cce_ucode_cfg_p
    ,bp_oct_core_cce_ucode_cfg_p
    ,bp_hexa_core_cce_ucode_cfg_p
    ,bp_quad_core_cce_ucode_cfg_p
    ,bp_tri_core_cce_ucode_cfg_p
    ,bp_dual_core_cce_ucode_cfg_p
    ,bp_single_core_cce_ucode_cfg_p
    ,bp_half_core_cce_ucode_cfg_p
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
