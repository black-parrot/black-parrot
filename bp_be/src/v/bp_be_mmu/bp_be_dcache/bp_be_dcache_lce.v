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
 *    is processed, it raises cce_data_received_li signal to lce_req module.
 *
 *      LCE could receive data transfer from another LCE or could be commanded
 *    to transfer data to another LCE. When transfer is received, tr module
 *    raises tr_received_li signal to lce_req module.
 */

module bp_be_dcache_lce
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    
    , parameter timeout_max_limit_p=4
   
    , localparam block_size_in_words_lp=ways_p
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam tag_width_lp=(paddr_width_p-index_width_lp-block_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
  
    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
    , localparam dcache_lce_tag_mem_pkt_width_lp=
      `bp_be_dcache_lce_tag_mem_pkt_width(sets_p, ways_p, tag_width_lp)
    , localparam dcache_lce_stat_mem_pkt_width_lp=
      `bp_be_dcache_lce_stat_mem_pkt_width(sets_p, ways_p)
    
    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p)
    , localparam cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam cce_lce_data_cmd_width_lp=
      `bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p, ways_p)
    , localparam lce_lce_tr_resp_width_lp=
      `bp_lce_lce_tr_resp_width(num_lce_p, paddr_width_p, lce_data_width_p, ways_p)
  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_lp-1:0] lce_id_i

    , output logic ready_o
    , output logic cache_miss_o

    , input load_miss_i
    , input store_miss_i
    , input [paddr_width_p-1:0] miss_addr_i

    // data_mem
    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input [lce_data_width_p-1:0] data_mem_data_i
    , input data_mem_pkt_yumi_i
  
    // tag_mem
    , output logic tag_mem_pkt_v_o
    , output logic [dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    , input tag_mem_pkt_yumi_i
    
    // stat_mem
    , output logic stat_mem_pkt_v_o
    , output logic [dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input [way_id_width_lp-1:0] lru_way_i
    , input [ways_p-1:0] dirty_i
    , input stat_mem_pkt_yumi_i

    // LCE-CCE interface
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_ready_i

    , output logic [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
    , output logic lce_data_resp_v_o
    , input lce_data_resp_ready_i

    // CCE-LCE interface
    , input [cce_lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_ready_o

    , input [cce_lce_data_cmd_width_lp-1:0] lce_data_cmd_i
    , input lce_data_cmd_v_i
    , output logic lce_data_cmd_ready_o

    // LCE-LCE interface
    , input [lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_i
    , input lce_tr_resp_v_i
    , output logic lce_tr_resp_ready_o

    , output logic [lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_o
    , output logic lce_tr_resp_v_o
    , input lce_tr_resp_ready_i 
  );

  // casting structs
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p, ways_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, lce_data_width_p, ways_p);

  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_lp);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(sets_p, ways_p);
 
  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_data_resp_s lce_data_resp;
  bp_cce_lce_cmd_s lce_cmd;
  bp_cce_lce_data_cmd_s lce_data_cmd;
  bp_lce_lce_tr_resp_s lce_tr_resp_in;
  bp_lce_lce_tr_resp_s lce_tr_resp_out;

  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;
  assign lce_data_resp_o = lce_data_resp;
  assign lce_cmd = lce_cmd_i;
  assign lce_data_cmd = lce_data_cmd_i;
  assign lce_tr_resp_in = lce_tr_resp_i;
  assign lce_tr_resp_o = lce_tr_resp_out;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;


  // LCE_CCE_req
  //
  logic tr_received_li;
  logic cce_data_received_li;
  logic tag_set_li;
  logic tag_set_wakeup_li;

  bp_lce_cce_resp_s lce_req_to_lce_resp_lo;
  logic lce_req_to_lce_resp_v_lo;
  logic lce_req_to_lce_resp_yumi_li;

  bp_be_dcache_lce_req
    #(.data_width_p(data_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.ways_p(ways_p)
      ,.sets_p(sets_p)
      )
    lce_cce_req_inst
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)
  
      ,.load_miss_i(load_miss_i)
      ,.store_miss_i(store_miss_i)
      ,.miss_addr_i(miss_addr_i)
      ,.lru_way_i(lru_way_i)
      ,.dirty_i(dirty_i)
      ,.cache_miss_o(cache_miss_o)

      ,.tr_received_i(tr_received_li)
      ,.cce_data_received_i(cce_data_received_li)
      ,.tag_set_i(tag_set_li)
      ,.tag_set_wakeup_i(tag_set_wakeup_li)

      ,.lce_req_o(lce_req)
      ,.lce_req_v_o(lce_req_v_o)
      ,.lce_req_ready_i(lce_req_ready_i)

      ,.lce_resp_o(lce_req_to_lce_resp_lo)
      ,.lce_resp_v_o(lce_req_to_lce_resp_v_lo)
      ,.lce_resp_yumi_i(lce_req_to_lce_resp_yumi_li)
      );

  // LCE cmd
  //
  logic lce_sync_done_lo;

  bp_be_dcache_lce_data_mem_pkt_s lce_cmd_data_mem_pkt_lo;
  logic lce_cmd_data_mem_pkt_v_lo;
  logic lce_cmd_data_mem_pkt_yumi_li;

  bp_lce_cce_resp_s lce_cmd_to_lce_resp_lo;
  logic lce_cmd_to_lce_resp_v_lo;
  logic lce_cmd_to_lce_resp_yumi_li;

  logic lce_cmd_fifo_v_lo;
  logic lce_cmd_fifo_yumi_li;
  bp_cce_lce_cmd_s lce_cmd_fifo_data_lo;

  // this two_fifo is needed to convert from valid-yumi to valid-ready interface.
  bsg_two_fifo
    #(.width_p(cce_lce_cmd_width_lp)
      )
    lce_cmd_fifo 
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.ready_o(lce_cmd_ready_o)
      ,.data_i(lce_cmd)
      ,.v_i(lce_cmd_v_i)
  
      ,.v_o(lce_cmd_fifo_v_lo)
      ,.data_o(lce_cmd_fifo_data_lo)
      ,.yumi_i(lce_cmd_fifo_yumi_li)
      );

  bp_be_dcache_lce_cmd
    #(.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.ways_p(ways_p)
      ,.sets_p(sets_p)
      ,.data_width_p(data_width_p)
      )
    lce_cmd_inst
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)

      ,.lce_sync_done_o(lce_sync_done_lo)
      ,.tag_set_o(tag_set_li)
      ,.tag_set_wakeup_o(tag_set_wakeup_li)

      ,.lce_cmd_i(lce_cmd_fifo_data_lo)
      ,.lce_cmd_v_i(lce_cmd_fifo_v_lo)
      ,.lce_cmd_yumi_o(lce_cmd_fifo_yumi_li)

      ,.lce_resp_o(lce_cmd_to_lce_resp_lo)
      ,.lce_resp_v_o(lce_cmd_to_lce_resp_v_lo)
      ,.lce_resp_yumi_i(lce_cmd_to_lce_resp_yumi_li)

      ,.lce_data_resp_o(lce_data_resp)
      ,.lce_data_resp_v_o(lce_data_resp_v_o)
      ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

      ,.lce_tr_resp_o(lce_tr_resp_out)
      ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
      ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)

      ,.data_mem_pkt_o(lce_cmd_data_mem_pkt_lo)
      ,.data_mem_pkt_v_o(lce_cmd_data_mem_pkt_v_lo)
      ,.data_mem_pkt_yumi_i(lce_cmd_data_mem_pkt_yumi_li)
      ,.data_mem_data_i(data_mem_data_i)

      ,.tag_mem_pkt_o(tag_mem_pkt)
      ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
      ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)

      ,.stat_mem_pkt_o(stat_mem_pkt)
      ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
      ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_i)
      ,.dirty_i(dirty_i)
      );


  // LCE_DATA_CMD
  //
  logic cce_data_received_lo;

  bp_be_dcache_lce_data_mem_pkt_s lce_data_cmd_data_mem_pkt_lo;
  logic lce_data_cmd_data_mem_pkt_v_lo;
  logic lce_data_cmd_data_mem_pkt_yumi_li;

  bp_cce_lce_data_cmd_s lce_data_cmd_fifo_data_lo;
  logic lce_data_cmd_fifo_v_lo;
  logic lce_data_cmd_fifo_yumi_li;

  // this two_fifo is needed to convert from valid-yumi to valid-ready interface.
  bsg_two_fifo
    #(.width_p(cce_lce_data_cmd_width_lp))
    lce_data_cmd_fifo
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.ready_o(lce_data_cmd_ready_o)
      ,.data_i(lce_data_cmd)
      ,.v_i(lce_data_cmd_v_i)
  
      ,.v_o(lce_data_cmd_fifo_v_lo)
      ,.data_o(lce_data_cmd_fifo_data_lo)
      ,.yumi_i(lce_data_cmd_fifo_yumi_li)
      );

  bp_be_dcache_lce_data_cmd
    #(.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.data_width_p(data_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.ways_p(ways_p)
      ,.sets_p(sets_p)
      )
    lce_data_cmd_inst
      (.cce_data_received_o(cce_data_received_li)
     
      ,.lce_data_cmd_i(lce_data_cmd_fifo_data_lo)
      ,.lce_data_cmd_v_i(lce_data_cmd_fifo_v_lo)
      ,.lce_data_cmd_yumi_o(lce_data_cmd_fifo_yumi_li)
     
      ,.data_mem_pkt_o(lce_data_cmd_data_mem_pkt_lo)
      ,.data_mem_pkt_v_o(lce_data_cmd_data_mem_pkt_v_lo)
      ,.data_mem_pkt_yumi_i(lce_data_cmd_data_mem_pkt_yumi_li)
      );

  // LCE_TR_RESP_IN
  //
  logic lce_tr_resp_in_fifo_v_lo;
  logic lce_tr_resp_in_fifo_yumi_li;
  bp_lce_lce_tr_resp_s lce_tr_resp_in_fifo_data_lo;

  logic lce_tr_resp_in_data_mem_pkt_v_lo;
  logic lce_tr_resp_in_data_mem_pkt_yumi_li;
  bp_be_dcache_lce_data_mem_pkt_s lce_tr_resp_in_data_mem_pkt_lo;
 

  // this two_fifo is needed to convert from valid-yumi to valid-ready interface.
  bsg_two_fifo
    #(.width_p(lce_lce_tr_resp_width_lp))
    lce_tr_resp_in_fifo
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.ready_o(lce_tr_resp_ready_o)
      ,.data_i(lce_tr_resp_in)
      ,.v_i(lce_tr_resp_v_i)
  
      ,.v_o(lce_tr_resp_in_fifo_v_lo)
      ,.data_o(lce_tr_resp_in_fifo_data_lo)
      ,.yumi_i(lce_tr_resp_in_fifo_yumi_li)
      );

  bp_be_dcache_lce_tr
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.data_width_p(data_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_data_width_p(lce_data_width_p)
      ,.ways_p(ways_p)
      ,.sets_p(sets_p)
      )
    lce_tr_inst
      (.tr_received_o(tr_received_li)

      ,.lce_tr_resp_i(lce_tr_resp_in_fifo_data_lo)
      ,.lce_tr_resp_v_i(lce_tr_resp_in_fifo_v_lo)
      ,.lce_tr_resp_yumi_o(lce_tr_resp_in_fifo_yumi_li)

      ,.data_mem_pkt_v_o(lce_tr_resp_in_data_mem_pkt_v_lo)
      ,.data_mem_pkt_o(lce_tr_resp_in_data_mem_pkt_lo)
      ,.data_mem_pkt_yumi_i(lce_tr_resp_in_data_mem_pkt_yumi_li)
      );

  // data_mem arbiter
  // lce_lce_tr_resp_in and cce_lce_data_cmd (which are mutually exclusive events) have
  // higher priority over cce_lce_cmd.
  always_comb begin
    lce_tr_resp_in_data_mem_pkt_yumi_li = 1'b0;
    lce_data_cmd_data_mem_pkt_yumi_li = 1'b0;
    lce_cmd_data_mem_pkt_yumi_li = 1'b0;

    if (lce_tr_resp_in_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o = 1'b1;
      data_mem_pkt = lce_tr_resp_in_data_mem_pkt_lo;
      lce_tr_resp_in_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
    else if (lce_data_cmd_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o = 1'b1;
      data_mem_pkt = lce_data_cmd_data_mem_pkt_lo;
      lce_data_cmd_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
    else begin
      data_mem_pkt_v_o = lce_cmd_data_mem_pkt_v_lo;
      data_mem_pkt = lce_cmd_data_mem_pkt_lo;
      lce_cmd_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
  end  

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

  assign ready_o = lce_sync_done_lo & ~timeout & ~cache_miss_o; 

endmodule
