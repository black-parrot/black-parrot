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
 import bp_be_dcache_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam way_id_width_lp = `BSG_SAFE_CLOG2(lce_assoc_p)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
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

    // Config info
    , input [cfg_bus_width_lp-1:0] cfg_bus_i
    , output [vaddr_width_p-1:0] cfg_npc_data_o
    , output [dword_width_p-1:0] cfg_irf_data_o
    , output [dword_width_p-1:0] cfg_csr_data_o
    , output [1:0] cfg_priv_data_o

    // request side
    , output [1:0] ready_o
    , output [1:0] cache_miss_o

    , input [1:0] load_miss_i
    , input [1:0] store_miss_i
    , input [1:0] lr_miss_i
    , input [1:0] uncached_load_req_i
    , input [1:0] uncached_store_req_i

    , input [1:0][cce_block_width_p-1:0] data_mem_data_i
    , input [1:0][paddr_width_p-1:0] miss_addr_i
    , input [1:0][way_id_width_lp-1:0] lru_way_i
    , input [1:0][lce_assoc_p-1:0] dirty_i
    , input [1:0][dword_width_p-1:0] store_data_i
    , input [1:0] size_op_i

    // response side
    , output [1:0][dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , output [1:0] data_mem_pkt_v_o
    , input [1:0] data_mem_pkt_yumi_i

    , output [1:0][dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    , output [1:0] tag_mem_pkt_v_o
    , input [1:0] tag_mem_pkt_yumi_i

    , output [1:0][dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , output [1:0] stat_mem_pkt_v_o
    , input [1:0] stat_mem_pkt_yumi_i
    );

  logic load_miss, store_miss;
  logic [paddr_width_p-1:0] miss_addr;
  logic [dword_width_p-1:0] miss_data;

  `declare_bp_be_dcache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, cce_block_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, ptag_width_p);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);

  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  logic data_mem_pkt_v, data_mem_pkt_yumi;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  logic tag_mem_pkt_v, tag_mem_pkt_yumi;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;
  logic stat_mem_pkt_v, stat_mem_pkt_yumi;


endmodule

