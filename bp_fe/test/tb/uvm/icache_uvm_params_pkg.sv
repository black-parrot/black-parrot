// Devin Bidstrup 2022
// BP Parameters as a package for BP L1 ICache Testbench

// This is needed as the UVM sequencer cannot handle parameterized transactions,
// so the parameters need to be imported as a package

`ifndef ICACHE_PARAMS_PKG
`define ICACHE_PARAMS_PKG

package icache_uvm_params_pkg;

  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;

  // Manual typedefs to resolve dependencies (not best solution)
  typedef enum logic [1:0]
  {// write cache block
    e_cache_data_mem_write
    // read cache block
    ,e_cache_data_mem_read
    // write uncached load data
    ,e_cache_data_mem_uncached
  } bp_cache_data_mem_opcode_e;

  // Tag mem pkt opcodes
  typedef enum logic [2:0]
  {// clear all blocks in a set for a given index
    e_cache_tag_mem_set_clear
    // set tag and coherence state for given index and way_id
    ,e_cache_tag_mem_set_tag
    // set coherence state for given index and way_id
    ,e_cache_tag_mem_set_state
    // read tag mem packets for writeback and transfer (Used for UCE)
    ,e_cache_tag_mem_read
  } bp_cache_tag_mem_opcode_e;

  // Stat mem pkt opcodes
  typedef enum logic [1:0]
  {// clear all dirty bits and LRU bits to zero for given index.
    e_cache_stat_mem_set_clear
    // read stat_info for given index.
    ,e_cache_stat_mem_read
    // clear dirty bit for given index and way_id.
    ,e_cache_stat_mem_clear_dirty
  } bp_cache_stat_mem_opcode_e;

  typedef enum
  {
      e_icache_fetch
      ,e_icache_fencei
      ,e_icache_fill
  } bp_fe_icache_op_e;

  parameter bp_params_e bp_params_p = e_bp_default_cfg;//BP_CFG_FLOWVAR

  //`declare_bp_proc_params(bp_params_p)
  parameter bp_proc_param_s proc_param_lp = all_cfgs_gp[bp_params_p];
  parameter multicore_p                    = proc_param_lp.multicore;
  parameter cc_x_dim_p                     = proc_param_lp.cc_x_dim;
  parameter cc_y_dim_p                     = proc_param_lp.cc_y_dim;
  parameter ic_x_dim_p                     = cc_x_dim_p;
  parameter ic_y_dim_p                     = proc_param_lp.ic_y_dim;
  parameter mc_x_dim_p                     = cc_x_dim_p;
  parameter mc_y_dim_p                     = proc_param_lp.mc_y_dim;
  parameter cac_x_dim_p                    = proc_param_lp.cac_x_dim;
  parameter cac_y_dim_p                    = cc_y_dim_p;
  parameter sac_x_dim_p                    = proc_param_lp.sac_x_dim;
  parameter sac_y_dim_p                    = cc_y_dim_p;
  parameter cacc_type_p                    = proc_param_lp.cacc_type;
  parameter sacc_type_p                    = proc_param_lp.sacc_type;
  parameter num_core_p                     = cc_x_dim_p * cc_y_dim_p;
  parameter num_io_p                       = ic_x_dim_p * ic_y_dim_p;
  parameter num_l2e_p                      = mc_x_dim_p * mc_y_dim_p;
  parameter num_cacc_p                     = cac_x_dim_p * cac_y_dim_p;
  parameter num_sacc_p                     = sac_x_dim_p * sac_y_dim_p;
  parameter num_cce_p                      = proc_param_lp.num_cce;
  parameter num_lce_p                      = proc_param_lp.num_lce;
  parameter core_id_width_p                = `BSG_SAFE_CLOG2(cc_x_dim_p*cc_y_dim_p);
  parameter cce_id_width_p                 = `BSG_SAFE_CLOG2(((cc_x_dim_p*1)+2)*((cc_y_dim_p*1)+2));
  parameter lce_id_width_p                 = `BSG_SAFE_CLOG2(((cc_x_dim_p*2)+2)*((cc_y_dim_p*2)+2));
  parameter vaddr_width_p                  = proc_param_lp.vaddr_width;
  parameter paddr_width_p                  = proc_param_lp.paddr_width;
  parameter daddr_width_p                  = proc_param_lp.daddr_width;
  parameter caddr_width_p                  = proc_param_lp.caddr_width;
  parameter asid_width_p                   = proc_param_lp.asid_width;
  parameter hio_width_p                    = paddr_width_p - daddr_width_p;
  parameter boot_pc_p                      = proc_param_lp.boot_pc;
  parameter boot_in_debug_p                = proc_param_lp.boot_in_debug;
  parameter branch_metadata_fwd_width_p    = proc_param_lp.branch_metadata_fwd_width;
  parameter btb_tag_width_p                = proc_param_lp.btb_tag_width;
  parameter btb_idx_width_p                = proc_param_lp.btb_idx_width;
  parameter bht_idx_width_p                = proc_param_lp.bht_idx_width;
  parameter bht_row_els_p                  = proc_param_lp.bht_row_els;
  parameter ghist_width_p                  = proc_param_lp.ghist_width;
  parameter bht_row_width_p                = 2*bht_row_els_p;
  parameter itlb_els_4k_p                  = proc_param_lp.itlb_els_4k;
  parameter itlb_els_1g_p                  = proc_param_lp.itlb_els_1g;
  parameter dtlb_els_4k_p                  = proc_param_lp.dtlb_els_4k;
  parameter dtlb_els_1g_p                  = proc_param_lp.dtlb_els_1g;
  parameter lr_sc_p                        = proc_param_lp.lr_sc;
  parameter amo_swap_p                     = proc_param_lp.amo_swap;
  parameter amo_fetch_logic_p              = proc_param_lp.amo_fetch_logic;
  parameter amo_fetch_arithmetic_p         = proc_param_lp.amo_fetch_arithmetic;
  parameter l1_coherent_p                  = proc_param_lp.l1_coherent;
  parameter l1_writethrough_p              = proc_param_lp.l1_writethrough;
  parameter dcache_sets_p                  = proc_param_lp.dcache_sets;
  parameter dcache_assoc_p                 = proc_param_lp.dcache_assoc;
  parameter dcache_block_width_p           = proc_param_lp.dcache_block_width;
  parameter dcache_fill_width_p            = proc_param_lp.dcache_fill_width;
  parameter icache_sets_p                  = proc_param_lp.icache_sets;
  parameter icache_assoc_p                 = proc_param_lp.icache_assoc;
  parameter icache_block_width_p           = proc_param_lp.icache_block_width;
  parameter icache_fill_width_p            = proc_param_lp.icache_fill_width;
  parameter acache_sets_p                  = proc_param_lp.acache_sets;
  parameter acache_assoc_p                 = proc_param_lp.acache_assoc;
  parameter acache_block_width_p           = proc_param_lp.acache_block_width;
  parameter acache_fill_width_p            = proc_param_lp.acache_fill_width;
  parameter lce_assoc_p                    = `BSG_MAX(dcache_assoc_p, `BSG_MAX(icache_assoc_p, num_cacc_p ? acache_assoc_p : '0));
  parameter lce_assoc_width_p              = `BSG_SAFE_CLOG2(lce_assoc_p);
  parameter lce_sets_p                     = `BSG_MAX(dcache_sets_p, `BSG_MAX(icache_sets_p, num_cacc_p ? acache_sets_p : '0));
  parameter lce_sets_width_p               = `BSG_SAFE_CLOG2(lce_sets_p);
  parameter cce_block_width_p              = `BSG_MAX(dcache_block_width_p, `BSG_MAX(icache_block_width_p, num_cacc_p ? acache_block_width_p : '0));
  parameter uce_fill_width_p               = `BSG_MAX(dcache_fill_width_p, `BSG_MAX(icache_fill_width_p, num_cacc_p ? acache_fill_width_p : '0));
  parameter cce_pc_width_p                 = proc_param_lp.cce_pc_width;
  parameter num_cce_instr_ram_els_p        = 2**cce_pc_width_p;
  parameter cce_way_groups_p               = `BSG_MAX(dcache_sets_p, `BSG_MAX(icache_sets_p, num_cacc_p ? acache_sets_p : '0));
  parameter cce_ucode_p                    = proc_param_lp.cce_ucode;
  parameter l2_en_p                        = proc_param_lp.l2_en;
  parameter l2_data_width_p                = proc_param_lp.l2_data_width;
  parameter l2_sets_p                      = proc_param_lp.l2_sets;
  parameter l2_assoc_p                     = proc_param_lp.l2_assoc;
  parameter l2_block_width_p               = proc_param_lp.l2_block_width;
  parameter l2_fill_width_p                = proc_param_lp.l2_fill_width;
  parameter l2_outstanding_reqs_p          = proc_param_lp.l2_outstanding_reqs;
  parameter l2_block_size_in_words_p       = l2_block_width_p / l2_data_width_p;
  parameter l2_block_size_in_fill_p        = l2_block_width_p / l2_fill_width_p;
  parameter fe_queue_fifo_els_p            = proc_param_lp.fe_queue_fifo_els;
  parameter fe_cmd_fifo_els_p              = proc_param_lp.fe_cmd_fifo_els;
  parameter async_coh_clk_p                = proc_param_lp.async_coh_clk;
  parameter coh_noc_max_credits_p          = proc_param_lp.coh_noc_max_credits;
  parameter coh_noc_flit_width_p           = proc_param_lp.coh_noc_flit_width;
  parameter coh_noc_cid_width_p            = proc_param_lp.coh_noc_cid_width;
  parameter coh_noc_len_width_p            = proc_param_lp.coh_noc_len_width;
  parameter coh_noc_y_cord_width_p         = `BSG_SAFE_CLOG2(ic_y_dim_p+cc_y_dim_p+mc_y_dim_p+1);
  parameter coh_noc_x_cord_width_p         = `BSG_SAFE_CLOG2(sac_x_dim_p+cc_x_dim_p+cac_x_dim_p+1);
  parameter coh_noc_dims_p                 = 2;
  parameter coh_noc_dirs_p                 = coh_noc_dims_p*2 + 1;
  parameter coh_noc_trans_p                = 0;
  parameter int coh_noc_cord_markers_pos_p[coh_noc_dims_p:0] = coh_noc_trans_p
      ? '{coh_noc_x_cord_width_p+coh_noc_y_cord_width_p, coh_noc_y_cord_width_p, 0}
      : '{coh_noc_y_cord_width_p+coh_noc_x_cord_width_p, coh_noc_x_cord_width_p, 0};
  parameter coh_noc_cord_width_p           = coh_noc_cord_markers_pos_p[coh_noc_dims_p];
  parameter async_mem_clk_p                = proc_param_lp.async_mem_clk;
  parameter mem_noc_max_credits_p          = proc_param_lp.mem_noc_max_credits;
  parameter mem_noc_flit_width_p           = proc_param_lp.mem_noc_flit_width;
  parameter mem_noc_cid_width_p            = proc_param_lp.mem_noc_cid_width;
  parameter mem_noc_len_width_p            = proc_param_lp.mem_noc_len_width;
  parameter mem_noc_y_cord_width_p         = `BSG_SAFE_CLOG2(ic_y_dim_p+cc_y_dim_p+mc_y_dim_p+1);
  parameter mem_noc_x_cord_width_p         = 0;
  parameter mem_noc_dims_p                 = 1;
  parameter mem_noc_cord_dims_p            = 2;
  parameter mem_noc_dirs_p                 = mem_noc_dims_p*2 + 1;
  parameter mem_noc_trans_p                = 1;
  parameter int mem_noc_cord_markers_pos_p[mem_noc_cord_dims_p:0] = mem_noc_trans_p
      ? '{mem_noc_x_cord_width_p+mem_noc_y_cord_width_p, mem_noc_y_cord_width_p, 0}
      : '{mem_noc_y_cord_width_p+mem_noc_x_cord_width_p, mem_noc_x_cord_width_p, 0};
  parameter mem_noc_cord_width_p           = mem_noc_cord_markers_pos_p[mem_noc_dims_p];
  parameter async_io_clk_p                 = proc_param_lp.async_io_clk;
  parameter io_noc_max_credits_p           = proc_param_lp.io_noc_max_credits;
  parameter io_noc_did_width_p             = proc_param_lp.io_noc_did_width;
  parameter io_noc_flit_width_p            = proc_param_lp.io_noc_flit_width;
  parameter io_noc_cid_width_p             = proc_param_lp.io_noc_cid_width;
  parameter io_noc_len_width_p             = proc_param_lp.io_noc_len_width;
  parameter io_noc_y_cord_width_p          = 0;
  parameter io_noc_x_cord_width_p          = io_noc_did_width_p;
  parameter io_noc_dims_p                  = 1;
  parameter io_noc_cord_dims_p             = 2;
  parameter io_noc_dirs_p                  = io_noc_cord_dims_p*2 + 1;
  parameter io_noc_trans_p                 = 0;
  parameter int io_noc_cord_markers_pos_p[io_noc_cord_dims_p:0] = io_noc_trans_p
      ? '{io_noc_x_cord_width_p+io_noc_y_cord_width_p, io_noc_y_cord_width_p, 0}
      : '{io_noc_y_cord_width_p+io_noc_x_cord_width_p, io_noc_x_cord_width_p, 0};
  parameter io_noc_cord_width_p            = io_noc_cord_markers_pos_p[io_noc_dims_p];
  parameter did_width_p                    = io_noc_did_width_p;
  parameter etag_width_p                   = dword_width_gp - page_offset_width_gp;
  parameter vtag_width_p                   = vaddr_width_p - page_offset_width_gp;
  parameter ptag_width_p                   = paddr_width_p - page_offset_width_gp;
  parameter dtag_width_p                   = daddr_width_p - page_offset_width_gp;
  parameter ctag_width_p                   = caddr_width_p - page_offset_width_gp;



  //`declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
  parameter fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p);
  parameter fe_cmd_width_lp   = `bp_fe_cmd_width(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);



  //`declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache
  parameter icache_req_width_lp          = `bp_cache_req_width(dword_width_gp, paddr_width_p);
  parameter icache_req_metadata_width_lp = `bp_cache_req_metadata_width(icache_assoc_p);
  parameter icache_data_mem_pkt_width_lp = `bp_cache_data_mem_pkt_width(icache_sets_p,icache_assoc_p,icache_block_width_p,icache_fill_width_p);
  parameter icache_tag_mem_pkt_width_lp  = `bp_cache_tag_mem_pkt_width(icache_sets_p,icache_assoc_p,ctag_width_p);
  parameter icache_tag_info_width_lp     = `bp_cache_tag_info_width(ctag_width_p);
  parameter icache_stat_mem_pkt_width_lp = `bp_cache_stat_mem_pkt_width(icache_sets_p,icache_assoc_p);
  parameter icache_stat_info_width_lp    = `bp_cache_stat_info_width(icache_assoc_p);



  //`declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce));
  parameter cce_mem_payload_width_lp = `bp_bedrock_mem_payload_width(did_width_p, lce_id_width_p, lce_assoc_p);
  parameter cce_mem_header_width_lp  = `bp_bedrock_header_width(paddr_width_p, cce_mem_payload_width_lp);



  // Calculated parameters
  parameter dram_type_p         = "dramsim3"; //BP_DRAM_FLOWVAR;
  parameter bank_width_lp       = icache_block_width_p / icache_assoc_p;
  parameter icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p);
  parameter cfg_bus_width_lp    = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);



  //typedef macros
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, cache);
  `declare_bp_cfg_bus_s      (hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  `declare_bp_bedrock_mem_if (paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

endpackage : icache_uvm_params_pkg
`endif

