module wrapper
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   , parameter uce_p = 1
   `declare_bp_proc_params(bp_params_p)
   // These alternate parameters are untested
   , parameter sets_p = icache_sets_p
   , parameter assoc_p = icache_assoc_p
   , parameter block_width_p = icache_block_width_p
   , parameter fill_width_p = icache_fill_width_p
   , parameter id_width_p = icache_req_id_width_p
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   `declare_bp_cache_engine_generic_if_widths(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p, icache)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                         clk_i
   , input                                       reset_i

   , input [cfg_bus_width_lp-1:0]                cfg_bus_i

   , input [vaddr_width_p-1:0]                   vaddr_i
   , input [ptag_width_p-1:0]                    ptag_i
   , input                                       ptag_uncached_i
   , input                                       ptag_nonidem_i
   , input                                       ptag_dram_i
   , input                                       v_i
   , output                                      yumi_o

   , output [instr_width_gp-1:0]                 data_o
   , output                                      data_v_o
   , input                                       ready_i

   , output logic [mem_fwd_header_width_lp-1:0]  mem_fwd_header_o
   , output logic [l2_data_width_p-1:0]          mem_fwd_data_o
   , output logic                                mem_fwd_v_o
   , input                                       mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]         mem_rev_header_i
   , input [l2_data_width_p-1:0]                 mem_rev_data_i
   , input                                       mem_rev_v_i
   , output logic                                mem_rev_ready_and_o
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // I$-LCE Interface signals
  // Miss, Management Interfaces
  logic cache_req_yumi_li, cache_req_lock_li;
  logic [icache_req_width_lp-1:0] cache_req_lo;
  logic cache_req_v_lo;
  logic [icache_req_metadata_width_lp-1:0] cache_req_metadata_lo;
  logic cache_req_metadata_v_lo;
  logic [icache_req_id_width_p-1:0] cache_req_id_li;
  logic cache_req_critical_li, cache_req_last_li;
  logic cache_req_credits_full_li, cache_req_credits_empty_li;

  // Fill Interfaces
  logic data_mem_pkt_v_li, tag_mem_pkt_v_li, stat_mem_pkt_v_li;
  logic data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
  logic [icache_data_mem_pkt_width_lp-1:0] data_mem_pkt_li;
  logic [icache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_li;
  logic [icache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_li;
  logic [icache_block_width_p-1:0] data_mem_lo;
  logic [icache_tag_info_width_lp-1:0] tag_mem_lo;
  logic [icache_stat_info_width_lp-1:0] stat_mem_lo;

  logic ptag_dram_r, ptag_nonidem_r, ptag_uncached_r;
  logic [vaddr_width_p-1:0] vaddr_r;
  logic [ptag_width_p-1:0] ptag_r;
  bsg_dff_reset_en
   #(.width_p(3+vaddr_width_p+ptag_width_p))
   ptag_dff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(yumi_o)

     ,.data_i({ptag_dram_i, ptag_nonidem_i, ptag_uncached_i, vaddr_i, ptag_i})
     ,.data_o({ptag_dram_r, ptag_nonidem_r, ptag_uncached_r, vaddr_r, ptag_r})
     );


  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt;
  assign icache_pkt = '{vaddr: vaddr_i, op: e_icache_fetch, spec: 1'b0};

  // I-Cache
  bp_fe_icache
   #(.bp_params_p(bp_params_p)
     ,.sets_p(icache_sets_p)
     ,.assoc_p(icache_assoc_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     )
   icache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.icache_pkt_i(icache_pkt)
     ,.v_i(v_i)
     ,.yumi_o(yumi_o)
     ,.force_i(1'b0)
     ,.poison_tl_i(1'b0)

     ,.ptag_i(ptag_r)
     ,.ptag_v_i(1'b1)
     ,.ptag_uncached_i(ptag_uncached_r)
     ,.ptag_nonidem_i(ptag_nonidem_r)
     ,.ptag_dram_i(ptag_dram_r)
     ,.poison_tv_i(1'b0)
     ,.tv_we_o()

     ,.data_o(data_o)
     ,.data_v_o(data_v_o)
     ,.spec_v_o()
     ,.yumi_i(ready_i & data_v_o)

     ,.cache_req_o(cache_req_lo)
     ,.cache_req_v_o(cache_req_v_lo)
     ,.cache_req_yumi_i(cache_req_yumi_li)
     ,.cache_req_lock_i(cache_req_lock_li)
     ,.cache_req_metadata_o(cache_req_metadata_lo)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_lo)
     ,.cache_req_id_i(cache_req_id_li)
     ,.cache_req_critical_i(cache_req_critical_li)
     ,.cache_req_last_i(cache_req_last_li)
     ,.cache_req_credits_full_i(cache_req_credits_full_li)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_li)

     ,.data_mem_pkt_v_i(data_mem_pkt_v_li)
     ,.data_mem_pkt_i(data_mem_pkt_li)
     ,.data_mem_o(data_mem_lo)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo)

     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_li)
     ,.tag_mem_pkt_i(tag_mem_pkt_li)
     ,.tag_mem_o(tag_mem_lo)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo)

     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_li)
     ,.stat_mem_pkt_i(stat_mem_pkt_li)
     ,.stat_mem_o(stat_mem_lo)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo)
     );

  if (uce_p == 0) begin : CCE
    // LCE-CCE connections
    bp_bedrock_lce_req_header_s lce_req_header_lo;
    logic [icache_fill_width_p-1:0] lce_req_data_lo;
    logic lce_req_v_lo, lce_req_ready_and_li;

    bp_bedrock_lce_resp_header_s lce_resp_header_lo;
    logic [icache_fill_width_p-1:0] lce_resp_data_lo;
    logic lce_resp_v_lo, lce_resp_ready_and_li;

    bp_bedrock_lce_cmd_header_s lce_cmd_header_li;
    logic [icache_fill_width_p-1:0] lce_cmd_data_li;
    logic lce_cmd_v_li, lce_cmd_ready_and_lo;

    bp_bedrock_lce_fill_header_s lce_fill_header_li;
    logic [icache_fill_width_p-1:0] lce_fill_data_li;
    logic lce_fill_v_li, lce_fill_ready_and_lo;
    assign lce_fill_header_li = '0;
    assign lce_fill_data_li = '0;
    assign lce_fill_v_li = 1'b0;

    // I-Cache LCE
    bp_lce
     #(.bp_params_p(bp_params_p)
       ,.assoc_p(icache_assoc_p)
       ,.sets_p(icache_sets_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       ,.id_width_p(icache_req_id_width_p)
       ,.timeout_max_limit_p(4)
       ,.credits_p(coh_noc_max_credits_p)
       ,.non_excl_reads_p(1)
       ,.tag_width_p(icache_tag_width_p)
       )
     icache_lce
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.did_i('0)
       ,.lce_id_i(cfg_bus_cast_i.icache_id)
       ,.lce_mode_i(cfg_bus_cast_i.icache_mode)

       ,.cache_req_v_i(cache_req_v_lo)
       ,.cache_req_i(cache_req_lo)
       ,.cache_req_yumi_o(cache_req_yumi_li)
       ,.cache_req_lock_o(cache_req_lock_li)
       ,.cache_req_metadata_i(cache_req_metadata_lo)
       ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
       ,.cache_req_id_o(cache_req_id_li)
       ,.cache_req_critical_o(cache_req_critical_li)
       ,.cache_req_last_o(cache_req_last_li)
       ,.cache_req_credits_full_o(cache_req_credits_full_li)
       ,.cache_req_credits_empty_o(cache_req_credits_empty_li)

       ,.data_mem_i(data_mem_lo)
       ,.data_mem_pkt_o(data_mem_pkt_li)
       ,.data_mem_pkt_v_o(data_mem_pkt_v_li)
       ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)

       ,.tag_mem_i(tag_mem_lo)
       ,.tag_mem_pkt_o(tag_mem_pkt_li)
       ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li)
       ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)

       ,.stat_mem_i(stat_mem_lo)
       ,.stat_mem_pkt_o(stat_mem_pkt_li)
       ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li)
       ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)

       ,.lce_req_header_o(lce_req_header_lo)
       ,.lce_req_data_o(lce_req_data_lo)
       ,.lce_req_v_o(lce_req_v_lo)
       ,.lce_req_ready_and_i(lce_req_ready_and_li)

       ,.lce_cmd_header_i(lce_cmd_header_li)
       ,.lce_cmd_data_i(lce_cmd_data_li)
       ,.lce_cmd_v_i(lce_cmd_v_li)
       ,.lce_cmd_ready_and_o(lce_cmd_ready_and_lo)

       ,.lce_fill_header_i(lce_fill_header_li)
       ,.lce_fill_data_i(lce_fill_data_li)
       ,.lce_fill_v_i(lce_fill_v_li)
       ,.lce_fill_ready_and_o(lce_fill_ready_and_lo)

       ,.lce_fill_header_o()
       ,.lce_fill_data_o()
       ,.lce_fill_v_o()
       ,.lce_fill_ready_and_i(1'b0)

       ,.lce_resp_header_o(lce_resp_header_lo)
       ,.lce_resp_data_o(lce_resp_data_lo)
       ,.lce_resp_v_o(lce_resp_v_lo)
       ,.lce_resp_ready_and_i(lce_resp_ready_and_li)
       );

    // FSM CCE
    bp_cce_fsm
     #(.bp_params_p(bp_params_p))
     cce_fsm
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.cfg_bus_i(cfg_bus_i)

       // LCE-CCE Interface
       // BedRock Burst protocol: ready&valid
       ,.lce_req_header_i(lce_req_header_lo)
       ,.lce_req_data_i(lce_req_data_lo)
       ,.lce_req_v_i(lce_req_v_lo)
       ,.lce_req_ready_and_o(lce_req_ready_and_li)

       ,.lce_resp_header_i(lce_resp_header_lo)
       ,.lce_resp_data_i(lce_resp_data_lo)
       ,.lce_resp_v_i(lce_resp_v_lo)
       ,.lce_resp_ready_and_o(lce_resp_ready_and_li)

       ,.lce_cmd_header_o(lce_cmd_header_li)
       ,.lce_cmd_data_o(lce_cmd_data_li)
       ,.lce_cmd_v_o(lce_cmd_v_li)
       ,.lce_cmd_ready_and_i(lce_cmd_ready_and_lo)

       // CCE-MEM Interface
       // BedRock Stream protocol: ready&valid
       ,.mem_rev_header_i(mem_rev_header_i)
       ,.mem_rev_data_i(mem_rev_data_i)
       ,.mem_rev_v_i(mem_rev_v_i)
       ,.mem_rev_ready_and_o(mem_rev_ready_and_o)

       ,.mem_fwd_header_o(mem_fwd_header_o)
       ,.mem_fwd_data_o(mem_fwd_data_o)
       ,.mem_fwd_v_o(mem_fwd_v_o)
       ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)
       );

  end
  else begin: UCE
    bp_uce
     #(.bp_params_p(bp_params_p)
       ,.assoc_p(icache_assoc_p)
       ,.sets_p(icache_sets_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       ,.tag_width_p(icache_tag_width_p)
       ,.id_width_p(icache_req_id_width_p)
       ,.writeback_p(icache_features_p[e_cfg_writeback])
       )
     icache_uce
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.lce_id_i('0)

       ,.cache_req_i(cache_req_lo)
       ,.cache_req_v_i(cache_req_v_lo)
       ,.cache_req_yumi_o(cache_req_yumi_li)
       ,.cache_req_lock_o(cache_req_lock_li)
       ,.cache_req_metadata_i(cache_req_metadata_lo)
       ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
       ,.cache_req_id_o(cache_req_id_li)
       ,.cache_req_critical_o(cache_req_critical_li)
       ,.cache_req_last_o(cache_req_last_li)
       ,.cache_req_credits_full_o(cache_req_credits_full_li)
       ,.cache_req_credits_empty_o(cache_req_credits_empty_li)

       ,.tag_mem_pkt_o(tag_mem_pkt_li)
       ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li)
       ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)
       ,.tag_mem_i(tag_mem_lo)

       ,.data_mem_pkt_o(data_mem_pkt_li)
       ,.data_mem_pkt_v_o(data_mem_pkt_v_li)
       ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)
       ,.data_mem_i(data_mem_lo)

       ,.stat_mem_pkt_o(stat_mem_pkt_li)
       ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li)
       ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)
       ,.stat_mem_i(stat_mem_lo)

       ,.mem_fwd_header_o(mem_fwd_header_o)
       ,.mem_fwd_data_o(mem_fwd_data_o)
       ,.mem_fwd_v_o(mem_fwd_v_o)
       ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)

       ,.mem_rev_header_i(mem_rev_header_i)
       ,.mem_rev_data_i(mem_rev_data_i)
       ,.mem_rev_v_i(mem_rev_v_i)
       ,.mem_rev_ready_and_o(mem_rev_ready_and_o)
       );

  end
endmodule

