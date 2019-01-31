/**
 *  bp_be_dcache_lce.v
 *
 *  @author tommy
 */

`include "bp_be_dcache_lce_pkt.vh"
`include "bp_common_me_if.vh"

module bp_be_dcache_lce
  import bp_be_pkg::*;
  import bp_be_dcache_lce_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter lce_data_width_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    
    ,parameter timeout_max_limit_p=4
    
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
  
    ,parameter dcache_lce_data_mem_pkt_width_lp=`bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
    ,parameter dcache_lce_tag_mem_pkt_width_lp=`bp_be_dcache_lce_tag_mem_pkt_width(sets_p, ways_p, tag_width_p)
    ,parameter dcache_lce_stat_mem_pkt_width_lp=`bp_be_dcache_lce_stat_mem_pkt_width(sets_p, ways_p)
    
    ,parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_p, ways_p)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)
    ,parameter lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p)
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, ways_p, 4)
    ,parameter cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)
    ,parameter lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)

    ,localparam lce_id_width_lp=`bp_lce_id_width
  )
  (
    input clk_i
    ,input reset_i

    ,input logic [lce_id_width_lp-1:0] id_i

    ,output logic ready_o
    ,output logic cache_miss_o

    ,input load_miss_i
    ,input store_miss_i
    ,input [lce_addr_width_p-1:0] miss_addr_i

    // data_mem
    ,output logic data_mem_pkt_v_o
    ,output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    ,input [lce_data_width_p-1:0] data_mem_data_i
    ,input data_mem_pkt_yumi_i
  
    // tag_mem
    ,output logic tag_mem_pkt_v_o
    ,output logic [dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    ,input tag_mem_pkt_yumi_i
    
    // stat_mem
    ,output logic stat_mem_pkt_v_o
    ,output logic [dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    ,input [lg_ways_lp-1:0] lru_way_i
    ,input [ways_p-1:0] dirty_i
    ,input stat_mem_pkt_yumi_i

    // LCE-CCE interface
    ,output logic [lce_cce_req_width_lp-1:0] lce_cce_req_o
    ,output logic lce_cce_req_v_o
    ,input lce_cce_req_ready_i

    ,output logic [lce_cce_resp_width_lp-1:0] lce_cce_resp_o
    ,output logic lce_cce_resp_v_o
    ,input lce_cce_resp_ready_i

    ,output logic [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o
    ,output logic lce_cce_data_resp_v_o
    ,input lce_cce_data_resp_ready_i

    // CCE-LCE interface
    ,input [cce_lce_cmd_width_lp-1:0] cce_lce_cmd_i
    ,input cce_lce_cmd_v_i
    ,output logic cce_lce_cmd_ready_o

    ,input [cce_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_i
    ,input cce_lce_data_cmd_v_i
    ,output logic cce_lce_data_cmd_ready_o

    // LCE-LCE interface
    ,input [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_i
    ,input lce_lce_tr_resp_v_i
    ,output logic lce_lce_tr_resp_ready_o

    ,output logic [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_o
    ,output logic lce_lce_tr_resp_v_o
    ,input lce_lce_tr_resp_ready_i 
  );

  // casting structs
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p, 4);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_p);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(sets_p, ways_p);
 
  bp_lce_cce_req_s lce_cce_req;
  bp_lce_cce_resp_s lce_cce_resp;
  bp_lce_cce_data_resp_s lce_cce_data_resp;
  bp_cce_lce_cmd_s cce_lce_cmd;
  bp_cce_lce_data_cmd_s cce_lce_data_cmd;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_in;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_out;

  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;

  assign lce_cce_req_o = lce_cce_req;
  assign lce_cce_resp_o = lce_cce_resp;
  assign lce_cce_data_resp_o = lce_cce_data_resp;
  assign cce_lce_cmd = cce_lce_cmd_i;
  assign cce_lce_data_cmd = cce_lce_data_cmd_i;
  assign lce_lce_tr_resp_in = lce_lce_tr_resp_i;
  assign lce_lce_tr_resp_o = lce_lce_tr_resp_out;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;


  // LCE_CCE_req
  //
  logic tr_received_li;
  logic cce_data_received_li;
  logic tag_set_li;
  logic tag_set_wakeup_li;

  bp_lce_cce_resp_s lce_cce_req_lce_cce_resp_lo;
  logic lce_cce_req_lce_cce_resp_v_lo;
  logic lce_cce_req_lce_cce_resp_yumi_li;

  bp_be_dcache_lce_cce_req #(
    .data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.ways_p(ways_p)
  ) lce_cce_req_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.id_i(id_i)
  
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

    ,.lce_cce_req_o(lce_cce_req)
    ,.lce_cce_req_v_o(lce_cce_req_v_o)
    ,.lce_cce_req_ready_i(lce_cce_req_ready_i)

    ,.lce_cce_resp_o(lce_cce_req_lce_cce_resp_lo)
    ,.lce_cce_resp_v_o(lce_cce_req_lce_cce_resp_v_lo)
    ,.lce_cce_resp_yumi_i(lce_cce_req_lce_cce_resp_yumi_li)
  );

  // CCE_LCE_cmd
  //
  logic lce_sync_done_lo;

  bp_be_dcache_lce_data_mem_pkt_s cce_lce_cmd_data_mem_pkt_lo;
  logic cce_lce_cmd_data_mem_pkt_v_lo;
  logic cce_lce_cmd_data_mem_pkt_yumi_li;

  bp_lce_cce_resp_s cce_lce_cmd_lce_cce_resp_lo;
  logic cce_lce_cmd_lce_cce_resp_v_lo;
  logic cce_lce_cmd_lce_cce_resp_yumi_li;

  logic cce_lce_cmd_fifo_v_lo;
  logic cce_lce_cmd_fifo_yumi_li;
  bp_cce_lce_cmd_s cce_lce_cmd_fifo_data_lo;

  bsg_two_fifo #(
    .width_p(cce_lce_cmd_width_lp)
  ) cce_lce_cmd_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.ready_o(cce_lce_cmd_ready_o)
    ,.data_i(cce_lce_cmd)
    ,.v_i(cce_lce_cmd_v_i)
  
    ,.v_o(cce_lce_cmd_fifo_v_lo)
    ,.data_o(cce_lce_cmd_fifo_data_lo)
    ,.yumi_i(cce_lce_cmd_fifo_yumi_li)
  );

  bp_be_dcache_cce_lce_cmd #(
    .num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.ways_p(ways_p)
    ,.sets_p(sets_p)
    ,.tag_width_p(tag_width_p)
    ,.data_width_p(data_width_p)
  ) cce_lce_cmd_inst (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.id_i(id_i)

    ,.lce_sync_done_o(lce_sync_done_lo)
    ,.tag_set_o(tag_set_li)
    ,.tag_set_wakeup_o(tag_set_wakeup_li)

    ,.cce_lce_cmd_i(cce_lce_cmd_fifo_data_lo)
    ,.cce_lce_cmd_v_i(cce_lce_cmd_fifo_v_lo)
    ,.cce_lce_cmd_yumi_o(cce_lce_cmd_fifo_yumi_li)

    ,.lce_cce_resp_o(cce_lce_cmd_lce_cce_resp_lo)
    ,.lce_cce_resp_v_o(cce_lce_cmd_lce_cce_resp_v_lo)
    ,.lce_cce_resp_yumi_i(cce_lce_cmd_lce_cce_resp_yumi_li)

    ,.lce_cce_data_resp_o(lce_cce_data_resp)
    ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v_o)
    ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_ready_i)

    ,.lce_lce_tr_resp_o(lce_lce_tr_resp_out)
    ,.lce_lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
    ,.lce_lce_tr_resp_ready_i(lce_lce_tr_resp_ready_i)

    ,.data_mem_pkt_o(cce_lce_cmd_data_mem_pkt_lo)
    ,.data_mem_pkt_v_o(cce_lce_cmd_data_mem_pkt_v_lo)
    ,.data_mem_pkt_yumi_i(cce_lce_cmd_data_mem_pkt_yumi_li)
    ,.data_mem_data_i(data_mem_data_i)

    ,.tag_mem_pkt_o(tag_mem_pkt)
    ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
    ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)

    ,.stat_mem_pkt_o(stat_mem_pkt)
    ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
    ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_i)
    ,.dirty_i(dirty_i)
  );


  // CCE_LCE_DATA_CMD
  //
  logic cce_data_received_lo;
  bp_be_dcache_lce_data_mem_pkt_s cce_lce_data_cmd_data_mem_pkt_lo;
  logic cce_lce_data_cmd_data_mem_pkt_v_lo;
  logic cce_lce_data_cmd_data_mem_pkt_yumi_li;

  logic cce_lce_data_cmd_fifo_v_lo;
  bp_cce_lce_data_cmd_s cce_lce_data_cmd_fifo_data_lo;
  logic cce_lce_data_cmd_fifo_yumi_li;

  bsg_two_fifo #(
    .width_p(cce_lce_data_cmd_width_lp)
  ) cce_lce_data_cmd_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.ready_o(cce_lce_data_cmd_ready_o)
    ,.data_i(cce_lce_data_cmd)
    ,.v_i(cce_lce_data_cmd_v_i)
  
    ,.v_o(cce_lce_data_cmd_fifo_v_lo)
    ,.data_o(cce_lce_data_cmd_fifo_data_lo)
    ,.yumi_i(cce_lce_data_cmd_fifo_yumi_li)
  );

  bp_be_dcache_cce_lce_data_cmd #(
    .num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    ,.data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.ways_p(ways_p)
    ,.sets_p(sets_p)
  ) cce_lce_data_cmd_inst (
    .cce_data_received_o(cce_data_received_li)
     
    ,.cce_lce_data_cmd_i(cce_lce_data_cmd_fifo_data_lo)
    ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_fifo_v_lo)
    ,.cce_lce_data_cmd_yumi_o(cce_lce_data_cmd_fifo_yumi_li)
     
    ,.data_mem_pkt_o(cce_lce_data_cmd_data_mem_pkt_lo)
    ,.data_mem_pkt_v_o(cce_lce_data_cmd_data_mem_pkt_v_lo)
    ,.data_mem_pkt_yumi_i(cce_lce_data_cmd_data_mem_pkt_yumi_li)
  );

  // LCE_LCE_TR_RESP_IN
  //
  logic lce_lce_tr_resp_in_data_mem_pkt_v_lo;
  bp_be_dcache_lce_data_mem_pkt_s lce_lce_tr_resp_in_data_mem_pkt_lo;
  logic lce_lce_tr_resp_in_data_mem_pkt_yumi_li;
 
  logic lce_lce_tr_resp_in_fifo_v_lo;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_in_fifo_data_lo;
  logic lce_lce_tr_resp_in_fifo_yumi_li;

  bsg_two_fifo #(
    .width_p(lce_lce_tr_resp_width_lp)
  ) lce_lce_tr_resp_in_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.ready_o(lce_lce_tr_resp_ready_o)
    ,.data_i(lce_lce_tr_resp_in)
    ,.v_i(lce_lce_tr_resp_v_i)
  
    ,.v_o(lce_lce_tr_resp_in_fifo_v_lo)
    ,.data_o(lce_lce_tr_resp_in_fifo_data_lo)
    ,.yumi_i(lce_lce_tr_resp_in_fifo_yumi_li)
  );

  bp_be_dcache_lce_lce_tr_resp_in #(
    .num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.data_width_p(data_width_p)
    ,.lce_addr_width_p(lce_addr_width_p)
    ,.lce_data_width_p(lce_data_width_p)
    ,.ways_p(ways_p)
    ,.sets_p(sets_p)
  ) lce_lce_tr_resp_in_inst (
    .tr_received_o(tr_received_li)

    ,.lce_lce_tr_resp_i(lce_lce_tr_resp_in_fifo_data_lo)
    ,.lce_lce_tr_resp_v_i(lce_lce_tr_resp_in_fifo_v_lo)
    ,.lce_lce_tr_resp_yumi_o(lce_lce_tr_resp_in_fifo_yumi_li)

    ,.data_mem_pkt_v_o(lce_lce_tr_resp_in_data_mem_pkt_v_lo)
    ,.data_mem_pkt_o(lce_lce_tr_resp_in_data_mem_pkt_lo)
    ,.data_mem_pkt_yumi_i(lce_lce_tr_resp_in_data_mem_pkt_yumi_li)
  );

  // data_mem arbiter
  //
  always_comb begin
    lce_lce_tr_resp_in_data_mem_pkt_yumi_li = 1'b0;
    cce_lce_data_cmd_data_mem_pkt_yumi_li = 1'b0;
    cce_lce_cmd_data_mem_pkt_yumi_li = 1'b0;

    if (lce_lce_tr_resp_in_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o = 1'b1;
      data_mem_pkt = lce_lce_tr_resp_in_data_mem_pkt_lo;
      lce_lce_tr_resp_in_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
    else if (cce_lce_data_cmd_data_mem_pkt_v_lo) begin
      data_mem_pkt_v_o = 1'b1;
      data_mem_pkt = cce_lce_data_cmd_data_mem_pkt_lo;
      cce_lce_data_cmd_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
    else begin
      data_mem_pkt_v_o = cce_lce_cmd_data_mem_pkt_v_lo;
      data_mem_pkt = cce_lce_cmd_data_mem_pkt_lo;
      cce_lce_cmd_data_mem_pkt_yumi_li = data_mem_pkt_yumi_i;
    end
  end  

  // LCE_CCE_resp arbiter
  //

  always_comb begin
    lce_cce_req_lce_cce_resp_yumi_li = 1'b0;
    cce_lce_cmd_lce_cce_resp_yumi_li = 1'b0;

    if (lce_cce_req_lce_cce_resp_v_lo) begin
      lce_cce_resp_v_o = 1'b1;
      lce_cce_resp = lce_cce_req_lce_cce_resp_lo;
      lce_cce_req_lce_cce_resp_yumi_li = lce_cce_resp_ready_i;
    end
    else begin
      lce_cce_resp_v_o = cce_lce_cmd_lce_cce_resp_v_lo;
      lce_cce_resp = cce_lce_cmd_lce_cce_resp_lo;
      cce_lce_cmd_lce_cce_resp_yumi_li = cce_lce_cmd_lce_cce_resp_v_lo & lce_cce_resp_ready_i;
    end
  end

  // timeout logic
  //
  logic [`BSG_SAFE_CLOG2(timeout_max_limit_p+1)-1:0] timeout_count_r, timeout_count_n;
  logic timeout;

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
