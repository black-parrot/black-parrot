
package bp_common_aviary_pkg;
  `include "bp_common_aviary_defines.vh"

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs);

  localparam bp_proc_param_s bp_inv_cfg_p = 
    '{default: 1};

  // NOTE: To use this config, need to manually override CCE=1 and LCE=1 at instantiation
  localparam bp_proc_param_s bp_half_core_cfg_p =
    '{cc_x_dim   : 1
      ,cc_y_dim  : 1
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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

  localparam bp_proc_param_s bp_single_core_cfg_p = 
    '{cc_x_dim   : 1
      ,cc_y_dim  : 1
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,itlb_els             : 8
      ,dtlb_els             : 8
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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


  localparam bp_proc_param_s bp_dual_core_cfg_p = 
    '{cc_x_dim   : 2
      ,cc_y_dim  : 1
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,itlb_els             : 8
      ,dtlb_els             : 8
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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

  localparam bp_proc_param_s bp_tri_core_cfg_p = 
    '{cc_x_dim   : 3
      ,cc_y_dim  : 1
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1
      
      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2
      
      ,itlb_els             : 8
      ,dtlb_els             : 8
      
      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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

  localparam bp_proc_param_s bp_quad_core_cfg_p =
    '{cc_x_dim   : 2
      ,cc_y_dim  : 2
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 4

      ,async_coh_clk       : 1
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

  localparam bp_proc_param_s bp_hexa_core_cfg_p =
    '{cc_x_dim   : 3
      ,cc_y_dim  : 2
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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

  localparam bp_proc_param_s bp_oct_core_cfg_p =
    '{cc_x_dim   : 4
      ,cc_y_dim  : 2
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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

  localparam bp_proc_param_s bp_twelve_core_cfg_p =
    '{cc_x_dim   : 4
      ,cc_y_dim  : 3
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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

  localparam bp_proc_param_s bp_sexta_core_cfg_p =
    '{cc_x_dim   : 4
      ,cc_y_dim  : 4
      ,ic_y_dim  : 1
      ,mc_y_dim  : 0
      ,ac_x_dim  : 0

      ,vaddr_width: 39
      ,paddr_width: 40
      ,asid_width : 1

      ,branch_metadata_fwd_width: 28
      ,btb_tag_width            : 10
      ,btb_idx_width            : 6
      ,bht_idx_width            : 9
      ,ras_idx_width            : 2

      ,itlb_els             : 8
      ,dtlb_els             : 8

      ,lce_sets             : 64
      ,lce_assoc            : 8
      ,cce_block_width      : 512
      ,cce_pc_width         : 8

      ,l2_sets : 128
      ,l2_assoc: 8

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
    e_bp_sexta_core_cfg     = 9
    ,e_bp_twelve_core_cfg   = 8
    ,e_bp_oct_core_cfg      = 7
    ,e_bp_hexa_core_cfg     = 6
    ,e_bp_quad_core_cfg     = 5
    ,e_bp_tri_core_cfg      = 4
    ,e_bp_dual_core_cfg     = 3
    ,e_bp_single_core_cfg   = 2
    ,e_bp_half_core_cfg     = 1
    ,e_bp_inv_cfg           = 0
  } bp_params_e;

  /* verilator lint_off WIDTH */     
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    bp_sexta_core_cfg_p
    ,bp_twelve_core_cfg_p
    ,bp_oct_core_cfg_p
    ,bp_hexa_core_cfg_p
    ,bp_quad_core_cfg_p
    ,bp_tri_core_cfg_p
    ,bp_dual_core_cfg_p
    ,bp_single_core_cfg_p
    ,bp_half_core_cfg_p
    ,bp_inv_cfg_p
  };
  /* verilator lint_on WIDTH */

endpackage

