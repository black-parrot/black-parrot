/**
 *  bp_core.v
 *
 *  icache is connected to 0.
 *  dcache is connected to 1.
 */

module bp_core_minimal
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam way_id_width_lp = `BSG_SAFE_CLOG2(lce_assoc_p)

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(lce_sets_p, lce_assoc_p, cce_block_width_p)
    , localparam dcache_lce_tag_mem_pkt_width_lp=
      `bp_be_dcache_lce_tag_mem_pkt_width(lce_sets_p, lce_assoc_p, ptag_width_p)
    , localparam dcache_lce_stat_mem_pkt_width_lp=
      `bp_be_dcache_lce_stat_mem_pkt_width(lce_sets_p, lce_assoc_p)
    )
   (
    input          clk_i
    , input        reset_i

    // BlackParrot side
    , output logic ready_o
    , output logic cache_miss_o

    , input load_miss_i
    , input store_miss_i
    , input lr_miss_i
    , input uncached_load_req_i
    , input uncached_store_req_i

    , input [paddr_width_p-1:0] miss_addr_i
    , input [dword_width_p-1:0] store_data_i
    , input [1:0] size_op_i

    // data_mem
    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input [cce_block_width_p-1:0] data_mem_data_i
    , input data_mem_pkt_yumi_i

    // tag_mem
    , output logic tag_mem_pkt_v_o
    , output logic [dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    , input tag_mem_pkt_yumi_i

    // stat_mem
    , output logic stat_mem_pkt_v_o
    , output logic [dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input [way_id_width_lp-1:0] lru_way_i
    , input [lce_assoc_p-1:0] dirty_i
    , input stat_mem_pkt_yumi_i
    );

  logic load_miss, store_miss;
  logic [paddr_width_p-1:0] miss_addr;
  logic [dword_width_p-1:0] miss_data;

  `declare_bp_be_dcache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, cce_block_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, tag_width_lp);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);

  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  logic data_mem_pkt_v, data_mem_pkt_yumi;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  logic tag_mem_pkt_v, tag_mem_pkt_yumi;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;
  logic stat_mem_pkt_v, stat_mem_pkt_yumi;


endmodule

