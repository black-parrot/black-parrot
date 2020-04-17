/**
 *  Name: 
 *    bp_be_dcache_lce.v
 *
 *
 *  Description:
 *    Local coherence engine.
 *
 *      This module handles coherency protocols with CCE, acting as LCE.
 *    This involves reading or writing data_mem, tag_mem, and stat_mem,
 *    sending back responses to CCE or another LCE. These responses could
 *    include data or could simply be an ack. LCE also sends miss requests
 *    to CCE, when data cache has ran into store or load miss.
 *
 *      LCE receives commands from CCE through cce_lce_cmd. Some CCE
 *    commands could be arriving unsolicited. For example, LCE could be
 *    commanded to invalidate a tag for another LCE's store miss.
 *
 *      LCE sends miss request to CCE through lce_cce_req. load_miss_i and
 *    store_miss_i indicates that miss occured in the fast path of data
 *    cache. cache_miss_o is raised immediately once load_miss_i or
 *    store_miss_i is raised. cache_miss_o remains asserted until the miss
 *    is resolved.
 *     
 *      LCE sends responses back to CCE through lce_cce_resp. Both
 *    lce_cce_req or cce_lce_cmd could send response back, and when both
 *    modules want to send the response, lce_cce_req always get the higher
 *    priority in arbitration. We want to prioritize the types of acknowledge 
 *    that are sent later in the chain of coherence messages which resolves
 *    coherence transaction, otherwise it could create back-pressure in
 *    network and cause a deadlock.
 *
 *      LCE could be asked to writeback locally-cached data via lce_cce_data_resp.
 *    Only lce_cmd modules uses this channel.
 *
 *      LCE could be asked by CCE to write data to data_mem. When data_cmd
 *    is processed, it raises cce_data_received signal to lce_req module.
 *
 *      LCE could receive data transfer from another LCE or could be commanded
 *    to transfer data to another LCE. When transfer is received, tr module
 *    raises tr_data_received signal to lce_req module.
 */

module bp_be_dcache_lce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p) 
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)
    
    , localparam block_size_in_words_lp = dcache_assoc_p
    , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
    , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
    , localparam bypass_data_mask_width_lp = (dword_width_p >> 3)
    , localparam data_mem_mask_width_lp = (bank_width_lp >> 3)
    , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
    , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp = (word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp = `BSG_SAFE_CLOG2(dcache_sets_p)
    , localparam ptag_width_lp = (paddr_width_p-bp_page_offset_width_gp)
    , localparam way_id_width_lp = `BSG_SAFE_CLOG2(dcache_assoc_p)

    , localparam stat_info_width_lp=
      `bp_cache_stat_info_width(dcache_assoc_p)
  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_p-1:0] lce_id_i

    , input [dcache_req_width_lp-1:0] cache_req_i
    , input cache_req_v_i
    , output logic cache_req_ready_o
    , input [dcache_req_metadata_width_lp-1:0] cache_req_metadata_i
    , input cache_req_metadata_v_i
 
    , output logic cache_req_complete_o
    
    // data_mem
    , output logic data_mem_pkt_v_o
    , output logic [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input data_mem_pkt_ready_i
    , input [dcache_block_width_p-1:0] data_mem_i
  
    // tag_mem
    , output logic tag_mem_pkt_v_o
    , output logic [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    , input tag_mem_pkt_ready_i
    , input [ptag_width_lp-1:0] tag_mem_i
    
    // stat_mem
    , output logic stat_mem_pkt_v_o
    , output logic [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input stat_mem_pkt_ready_i
    , input [stat_info_width_lp-1:0] stat_mem_i

    // LCE-CCE interface
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_ready_i

    // CCE-LCE interface
    , input [lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_yumi_o

    // LCE-LCE interface
    , output logic [lce_cmd_width_lp-1:0] lce_cmd_o
    , output logic lce_cmd_v_o
    , input lce_cmd_ready_i

    , output logic credits_full_o
    , output logic credits_empty_o

  );

  // casting structs
  //
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);
 
  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd_in, lce_cmd_out;

  bp_dcache_data_mem_pkt_s data_mem_pkt;
  bp_dcache_tag_mem_pkt_s tag_mem_pkt;
  bp_dcache_stat_mem_pkt_s stat_mem_pkt;
  bp_dcache_req_s cache_req_cast_i;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;
  assign lce_cmd_in = lce_cmd_i;
  assign lce_cmd_o = lce_cmd_out;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;
  assign cache_req_cast_i = cache_req_i;

  // LCE_CCE_req
  //
  logic cce_data_received;
  logic uncached_data_received;
  logic set_tag_wakeup_received;
  logic uncached_store_done_received;

  bp_lce_cce_resp_s lce_req_to_lce_resp_lo;
  logic lce_req_to_lce_resp_v_lo;
  logic lce_req_to_lce_resp_yumi_li;

  logic [paddr_width_p-1:0] miss_addr_lo;

  // Outstanding Requests Counter - counts all requests, cached and uncached
  //
  logic [`BSG_WIDTH(coh_noc_max_credits_p)-1:0] credit_count_lo;
  wire credit_v_li = lce_req_v_o;
  wire credit_ready_li = lce_req_ready_i;
  // credit is returned when request completes
  // UC store done for UC Store, UC Data for UC Load, Set Tag Wakeup for
  // a miss that is actually an upgrade, and data and tag for normal requests.
  wire credit_returned_li = uncached_store_done_received | uncached_data_received
                            | set_tag_wakeup_received | cce_data_received;
  bsg_flow_counter
    #(.els_p(coh_noc_max_credits_p))
    uncached_store_counter
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // incremenent, when uncached store req is sent on LCE REQ
      ,.v_i(credit_v_li)
      ,.ready_i(credit_ready_li)
      // decrement, when LCE CMD processes UC_ST_DONE_CMD
      ,.yumi_i(credit_returned_li)
      ,.count_o(credit_count_lo)
      );
  assign credits_full_o = (credit_count_lo == coh_noc_max_credits_p);
  assign credits_empty_o = (credit_count_lo == 0);

  logic cmd_ready_lo;
  logic coherence_blocked_li;
  assign coherence_blocked_li = lce_cmd_v_i & ~lce_cmd_yumi_o;

  bp_be_dcache_lce_req
    #(.bp_params_p(bp_params_p))
    lce_req_inst
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)
  
      ,.cache_req_i(cache_req_i)
      ,.cache_req_v_i(cache_req_v_i)
      ,.cache_req_ready_o(cache_req_ready_o)
      ,.cache_req_metadata_i(cache_req_metadata_i)
      ,.cache_req_metadata_v_i(cache_req_metadata_v_i)

      ,.miss_addr_o(miss_addr_lo)

      ,.cce_data_received_i(cce_data_received)
      ,.uncached_data_received_i(uncached_data_received)
      ,.set_tag_wakeup_received_i(set_tag_wakeup_received)
      
      ,.coherence_blocked_i(coherence_blocked_li)
      ,.cmd_ready_i(cmd_ready_lo)
      ,.credits_ready_i(~credits_full_o)

      ,.lce_req_o(lce_req)
      ,.lce_req_v_o(lce_req_v_o)
      ,.lce_req_ready_i(lce_req_ready_i)

      ,.lce_resp_o(lce_req_to_lce_resp_lo)
      ,.lce_resp_v_o(lce_req_to_lce_resp_v_lo)
      ,.lce_resp_yumi_i(lce_req_to_lce_resp_yumi_li)
      );

  // LCE cmd

  bp_lce_cce_resp_s lce_cmd_to_lce_resp_lo;
  logic lce_cmd_to_lce_resp_v_lo;
  logic lce_cmd_to_lce_resp_yumi_li;

  bp_be_dcache_lce_cmd
    #(.bp_params_p(bp_params_p))
    lce_cmd_inst
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)

      ,.miss_addr_i(miss_addr_lo)

      ,.lce_ready_o(cmd_ready_lo)
      ,.set_tag_wakeup_received_o(set_tag_wakeup_received)
      ,.uncached_store_done_received_o(uncached_store_done_received)
      ,.cce_data_received_o(cce_data_received)
      ,.uncached_data_received_o(uncached_data_received)
      ,.cache_req_complete_o(cache_req_complete_o)

      ,.lce_cmd_i(lce_cmd_in)
      ,.lce_cmd_v_i(lce_cmd_v_i)
      ,.lce_cmd_yumi_o(lce_cmd_yumi_o)

      ,.lce_resp_o(lce_cmd_to_lce_resp_lo)
      ,.lce_resp_v_o(lce_cmd_to_lce_resp_v_lo)
      ,.lce_resp_yumi_i(lce_cmd_to_lce_resp_yumi_li)

      ,.lce_cmd_o(lce_cmd_out)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      ,.data_mem_pkt_o(data_mem_pkt)
      ,.data_mem_pkt_v_o(data_mem_pkt_v_o)
      ,.data_mem_pkt_ready_i(data_mem_pkt_ready_i)
      ,.data_mem_i(data_mem_i)

      ,.tag_mem_pkt_o(tag_mem_pkt)
      ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
      ,.tag_mem_pkt_ready_i(tag_mem_pkt_ready_i)
      ,.tag_mem_i(tag_mem_i)

      ,.stat_mem_pkt_o(stat_mem_pkt)
      ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
      ,.stat_mem_pkt_ready_i(stat_mem_pkt_ready_i)
      ,.stat_mem_i(stat_mem_i)
      );

  // LCE_CCE_resp arbiter
  // lce_cce_req has higher priority over cce_lce_cmd.
  always_comb begin
    lce_req_to_lce_resp_yumi_li = 1'b0;
    lce_cmd_to_lce_resp_yumi_li = 1'b0;

    if (lce_req_to_lce_resp_v_lo) begin
      lce_resp_v_o = 1'b1;
      lce_resp = lce_req_to_lce_resp_lo;
      lce_req_to_lce_resp_yumi_li = lce_resp_ready_i;
    end
    else begin
      lce_resp_v_o = lce_cmd_to_lce_resp_v_lo;
      lce_resp = lce_cmd_to_lce_resp_lo;
      lce_cmd_to_lce_resp_yumi_li = lce_cmd_to_lce_resp_v_lo & lce_resp_ready_i;
    end
  end

endmodule

