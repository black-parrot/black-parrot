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
    
    , parameter timeout_max_limit_p=4
   
    , localparam block_size_in_words_lp=lce_assoc_p
    , localparam data_mask_width_lp=(dword_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp=(paddr_width_p-index_width_lp-block_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
  
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p) 

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(lce_sets_p, lce_assoc_p, cce_block_width_p)
    , localparam dcache_lce_tag_mem_pkt_width_lp=
      `bp_be_dcache_lce_tag_mem_pkt_width(lce_sets_p, lce_assoc_p, tag_width_lp)
    , localparam dcache_lce_stat_mem_pkt_width_lp=
      `bp_be_dcache_lce_stat_mem_pkt_width(lce_sets_p, lce_assoc_p)
    
  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_lp-1:0] lce_id_i
    , input bp_lce_mode_e lce_mode_i

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
    , output logic lce_cmd_ready_o

    // LCE-LCE interface
    , output logic [lce_cmd_width_lp-1:0] lce_cmd_o
    , output logic lce_cmd_v_o
    , input lce_cmd_ready_i

    , output credits_full_o
    , output credits_empty_o
  );

  // casting structs
  //
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

  `declare_bp_be_dcache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, cce_block_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, tag_width_lp);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);
 
  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd_in, lce_cmd_out;

  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;
  assign lce_cmd_in = lce_cmd_i;
  assign lce_cmd_o = lce_cmd_out;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;

  // Outstanding Uncached Store Counter
  //
  logic uncached_store_done_received;
  logic lce_req_uncached_store_lo;
  logic [`BSG_WIDTH(mem_noc_max_credits_p)-1:0] credit_count_lo;
  logic credit_v_li, credit_ready_li;
  assign credit_v_li = lce_req_uncached_store_lo & lce_req_v_o & lce_req_ready_i;
  assign credit_ready_li = lce_req_ready_i;
  bsg_flow_counter
    #(.els_p(mem_noc_max_credits_p))
    uncached_store_counter
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // incremenent, when uncached store req is sent on LCE REQ
      ,.v_i(credit_v_li)
      ,.ready_i(credit_ready_li)
      // decrement, when LCE CMD processes UC_ST_DONE_CMD
      ,.yumi_i(uncached_store_done_received)
      ,.count_o(credit_count_lo)
      );
  assign credits_full_o = (credit_count_lo == mem_noc_max_credits_p);
  assign credits_empty_o = (credit_count_lo == 0);


  // LCE_CCE_req
  //
  logic cce_data_received;
  logic uncached_data_received;
  logic set_tag_received;
  logic set_tag_wakeup_received;

  bp_lce_cce_resp_s lce_req_to_lce_resp_lo;
  logic lce_req_to_lce_resp_v_lo;
  logic lce_req_to_lce_resp_yumi_li;

  logic [paddr_width_p-1:0] miss_addr_lo;

  bp_be_dcache_lce_req
    #(.dword_width_p(dword_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.ways_p(lce_assoc_p)
      ,.cce_block_width_p(cce_block_width_p)
      )
    lce_req_inst
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)
  
      ,.load_miss_i(load_miss_i)
      ,.store_miss_i(store_miss_i)
      ,.lr_miss_i(lr_miss_i)
      ,.uncached_load_req_i(uncached_load_req_i)
      ,.uncached_store_req_i(uncached_store_req_i)

      ,.miss_addr_i(miss_addr_i)
      ,.lru_way_i(lru_way_i)
      ,.dirty_i(dirty_i)
      ,.store_data_i(store_data_i)
      ,.size_op_i(size_op_i)

      ,.cache_miss_o(cache_miss_o)
      ,.miss_addr_o(miss_addr_lo)

      ,.cce_data_received_i(cce_data_received)
      ,.uncached_data_received_i(uncached_data_received)
      ,.set_tag_received_i(set_tag_received)
      ,.set_tag_wakeup_received_i(set_tag_wakeup_received)

      ,.lce_req_uncached_store_o(lce_req_uncached_store_lo)
      ,.lce_req_o(lce_req)
      ,.lce_req_v_o(lce_req_v_o)
      ,.lce_req_ready_i(lce_req_ready_i)

      ,.lce_resp_o(lce_req_to_lce_resp_lo)
      ,.lce_resp_v_o(lce_req_to_lce_resp_v_lo)
      ,.lce_resp_yumi_i(lce_req_to_lce_resp_yumi_li)

      ,.credits_full_i(credits_full_o)
      );

  // LCE cmd
  //
  logic lce_sync_done_lo;

  bp_lce_cce_resp_s lce_cmd_to_lce_resp_lo;
  logic lce_cmd_to_lce_resp_v_lo;
  logic lce_cmd_to_lce_resp_yumi_li;

  bp_be_dcache_lce_cmd
    #(.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_data_width_p(cce_block_width_p)
      ,.ways_p(lce_assoc_p)
      ,.sets_p(lce_sets_p)
      ,.data_width_p(dword_width_p)
      )
    lce_cmd_inst
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)
      ,.lce_mode_i(lce_mode_i)

      ,.miss_addr_i(miss_addr_lo)

      ,.lce_sync_done_o(lce_sync_done_lo)
      ,.set_tag_received_o(set_tag_received)
      ,.set_tag_wakeup_received_o(set_tag_wakeup_received)
      ,.uncached_store_done_received_o(uncached_store_done_received)
      ,.cce_data_received_o(cce_data_received)
      ,.uncached_data_received_o(uncached_data_received)

      ,.lce_cmd_i(lce_cmd_in)
      ,.lce_cmd_v_i(lce_cmd_v_i)
      ,.lce_cmd_ready_o(lce_cmd_ready_o)

      ,.lce_resp_o(lce_cmd_to_lce_resp_lo)
      ,.lce_resp_v_o(lce_cmd_to_lce_resp_v_lo)
      ,.lce_resp_yumi_i(lce_cmd_to_lce_resp_yumi_li)

      ,.lce_cmd_o(lce_cmd_out)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      ,.data_mem_pkt_o(data_mem_pkt)
      ,.data_mem_pkt_v_o(data_mem_pkt_v_o)
      ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_i)
      ,.data_mem_data_i(data_mem_data_i)

      ,.tag_mem_pkt_o(tag_mem_pkt)
      ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
      ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)

      ,.stat_mem_pkt_o(stat_mem_pkt)
      ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
      ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_i)
      ,.dirty_i(dirty_i)
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

  //  timeout logic
  //  LCE can read/write to data_mem, tag_mem, and stat_mem, when they are free (e.g. tl stage in dcache is not accessing them).
  //  In order to prevent LCE taking too much time to process incoming coherency requests,
  //  there is a timer, which counts up whenever LCE needs to access mem, but have not been able to.
  //  when the timer reaches max, it deasserts ready_o of dcache for one cycle, allowing it to access mem
  //  by creating a free slot.
  logic [`BSG_SAFE_CLOG2(timeout_max_limit_p+1)-1:0] timeout_count_r, timeout_count_n;
  logic timeout;

  // synopsys sync_set_reset "reset_i"
  always_comb begin
    if (timeout_count_r == timeout_max_limit_p) begin
      timeout = 1'b1;
      timeout_count_n = '0;
    end
    else begin
      timeout = 1'b0;
      if (data_mem_pkt_v_o | tag_mem_pkt_v_o | stat_mem_pkt_v_o) begin
        timeout_count_n = (~data_mem_pkt_yumi_i & ~tag_mem_pkt_yumi_i & ~stat_mem_pkt_yumi_i)
          ? timeout_count_r + 1
          : '0;
      end
      else begin
        timeout_count_n = '0;
      end 
    end
  end

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      timeout_count_r <= '0;
    end
    else begin
      timeout_count_r <= timeout_count_n;
    end
  end

  // LCE Ready Signal
  // The LCE ready signal depends on the mode of operation.
  // In uncached only mode, the LCE is always ready
  // In normal mode, the signal goes high after the LCE CMD unit signals that the CCE has
  // completed the initialization sequence.
  logic lce_ready;
  assign lce_ready = (lce_mode_i == e_lce_mode_uncached) ? 1'b1 : lce_sync_done_lo;
  assign ready_o = lce_ready & ~timeout & ~cache_miss_o; 

endmodule
