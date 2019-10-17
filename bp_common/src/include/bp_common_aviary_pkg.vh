
package bp_common_aviary_pkg;
  `include "bp_common_aviary_defines.vh"

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs);

  localparam bp_proc_param_s bp_inv_cfg_p = 
    '{default: "inv"};

  localparam bp_proc_param_s bp_half_core_cfg_p = 
    '{num_core: 1
      ,num_cce: 1
      ,num_lce: 1

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
      ,cce_instr_width      : 48

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 62
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 5
      ,coh_noc_y_cord_width: 0
      ,coh_noc_x_cord_width: 1
      ,coh_noc_y_dim       : 1
      ,coh_noc_x_dim       : 1

      ,cfg_core_width: 8
      ,cfg_addr_width: 16
      ,cfg_data_width: 64

      ,async_mem_clk         : 0
      ,mem_noc_max_credits   : 32
      ,mem_noc_flit_width    : 30
      ,mem_noc_reserved_width: 2
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 5
      ,mem_noc_y_cord_width  : 0
      ,mem_noc_x_cord_width  : 8
      ,mem_noc_y_dim         : 1
      ,mem_noc_x_dim         : 1
      };

  localparam bp_proc_param_s bp_single_core_cfg_p = 
    '{num_core: 1
      ,num_cce: 1
      ,num_lce: 2

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
      ,cce_instr_width      : 48

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 62
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 5
      ,coh_noc_y_cord_width: 1
      ,coh_noc_x_cord_width: 1
      ,coh_noc_y_dim       : 1
      ,coh_noc_x_dim       : 1

      ,cfg_core_width: 8
      ,cfg_addr_width: 16
      ,cfg_data_width: 64

      ,async_mem_clk         : 0
      ,mem_noc_max_credits   : 32
      ,mem_noc_flit_width    : 30
      ,mem_noc_reserved_width: 2
      ,mem_noc_cid_width     : 5
      ,mem_noc_len_width     : 5
      ,mem_noc_y_cord_width  : 1
      ,mem_noc_x_cord_width  : 8
      ,mem_noc_y_dim         : 1
      ,mem_noc_x_dim         : 1
      };

  localparam bp_proc_param_s bp_dual_core_cfg_p = 
    '{num_core: 2
      ,num_cce: 2
      ,num_lce: 4
      
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
      ,cce_instr_width      : 48

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 62
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 5
      ,coh_noc_y_cord_width: 1
      ,coh_noc_x_cord_width: 2
      ,coh_noc_y_dim       : 1
      ,coh_noc_x_dim       : 2

      ,cfg_core_width: 8
      ,cfg_addr_width: 16
      ,cfg_data_width: 64

      ,async_mem_clk         : 0
      ,mem_noc_max_credits   : 32
      ,mem_noc_flit_width    : 30
      ,mem_noc_reserved_width: 2
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 5
      ,mem_noc_y_cord_width  : 1
      ,mem_noc_x_cord_width  : 7
      ,mem_noc_y_dim         : 1
      ,mem_noc_x_dim         : 2
      };

  localparam bp_proc_param_s bp_quad_core_cfg_p = 
    '{num_core: 4
      ,num_cce: 4
      ,num_lce: 8
      
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
      ,cce_instr_width      : 48

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 62
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 5
      ,coh_noc_y_cord_width: 1
      ,coh_noc_x_cord_width: 1
      ,coh_noc_y_dim       : 2
      ,coh_noc_x_dim       : 2

      ,cfg_core_width: 8
      ,cfg_addr_width: 16
      ,cfg_data_width: 64

      ,async_mem_clk         : 1
      ,mem_noc_max_credits   : 32
      ,mem_noc_flit_width    : 30
      ,mem_noc_reserved_width: 2
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 5
      ,mem_noc_y_cord_width  : 2
      ,mem_noc_x_cord_width  : 6
      ,mem_noc_y_dim         : 2
      ,mem_noc_x_dim         : 2
      };

  localparam bp_proc_param_s bp_oct_core_cfg_p = 
    '{num_core: 8
      ,num_cce: 8
      ,num_lce: 16
      
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
      ,cce_instr_width      : 48

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 62
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 5
      ,coh_noc_y_cord_width: 4
      ,coh_noc_x_cord_width: 4
      ,coh_noc_y_dim       : 2
      ,coh_noc_x_dim       : 4

      ,cfg_core_width: 8
      ,cfg_addr_width: 16
      ,cfg_data_width: 64

      ,async_mem_clk         : 0
      ,mem_noc_max_credits   : 32
      ,mem_noc_flit_width    : 30
      ,mem_noc_reserved_width: 2
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 5
      ,mem_noc_y_cord_width  : 4
      ,mem_noc_x_cord_width  : 4
      ,mem_noc_y_dim         : 2
      ,mem_noc_x_dim         : 4
      };

  localparam bp_proc_param_s bp_sexta_core_cfg_p =
    '{num_core: 16
      ,num_cce: 16
      ,num_lce: 32

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
      ,cce_instr_width      : 48

      ,fe_queue_fifo_els: 8
      ,fe_cmd_fifo_els  : 2

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 62
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 5
      ,coh_noc_y_cord_width: 4
      ,coh_noc_x_cord_width: 4
      ,coh_noc_y_dim       : 4
      ,coh_noc_x_dim       : 4

      ,cfg_core_width: 8
      ,cfg_addr_width: 16
      ,cfg_data_width: 64

      ,async_mem_clk         : 0
      ,mem_noc_max_credits   : 32
      ,mem_noc_flit_width    : 30
      ,mem_noc_reserved_width: 2
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 5
      ,mem_noc_y_cord_width  : 4
      ,mem_noc_x_cord_width  : 4
      ,mem_noc_y_dim         : 4
      ,mem_noc_x_dim         : 4
      };

  typedef enum bit [lg_max_cfgs-1:0] 
  {
    e_bp_sexta_core_cfg     = 6
    ,e_bp_oct_core_cfg      = 5
    ,e_bp_quad_core_cfg     = 4
    ,e_bp_dual_core_cfg     = 3
    ,e_bp_single_core_cfg   = 2
    ,e_bp_half_core_cfg     = 1
    ,e_bp_inv_cfg           = 0
  } bp_params_e;

  /* verilator lint_off WIDTH */     
  parameter bp_proc_param_s [max_cfgs-1:0] all_cfgs_gp =
  {
    bp_sexta_core_cfg_p
    ,bp_oct_core_cfg_p
    ,bp_quad_core_cfg_p
    ,bp_dual_core_cfg_p
    ,bp_single_core_cfg_p
    ,bp_half_core_cfg_p
    ,bp_inv_cfg_p
  };
  /* verilator lint_on WIDTH */

endpackage

