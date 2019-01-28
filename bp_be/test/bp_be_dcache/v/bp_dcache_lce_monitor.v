/**
 *  bp_dcache_lce_monitor.v
 *
 *  @author tommy
 */

`include "bp_common_me_if.vh"

module bp_dcache_lce_monitor
  #(parameter id_p="inv"
    ,parameter data_width_p="inv"
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
  
    ,parameter dcache_lce_data_mem_pkt_width_lp=`bp_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
    ,parameter dcache_lce_tag_mem_pkt_width_lp=`bp_dcache_lce_tag_mem_pkt_width(sets_p, ways_p, tag_width_p)
    ,parameter dcache_lce_stat_mem_pkt_width_lp=`bp_dcache_lce_stat_mem_pkt_width(sets_p, ways_p)
    
    ,parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_p, ways_p)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)
    ,parameter lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p)
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, ways_p, 4)
    ,parameter cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)
    ,parameter lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)
  )
  (
    input clk_i
    ,input reset_i
    
    // LCE-CCE interface
    ,input [lce_cce_req_width_lp-1:0] lce_cce_req_i
    ,input lce_cce_req_v_i
    ,input lce_cce_req_ready_i

    ,input [lce_cce_resp_width_lp-1:0] lce_cce_resp_i
    ,input lce_cce_resp_v_i
    ,input lce_cce_resp_ready_i

    ,input [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_i
    ,input lce_cce_data_resp_v_i
    ,input lce_cce_data_resp_ready_i

    // CCE-LCE interface
    ,input [cce_lce_cmd_width_lp-1:0] cce_lce_cmd_i
    ,input cce_lce_cmd_v_i
    ,input cce_lce_cmd_yumi_i

    ,input [cce_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_i
    ,input cce_lce_data_cmd_v_i
    ,input cce_lce_data_cmd_yumi_i

    // LCE-LCE interface
    ,input [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_in_i
    ,input lce_lce_tr_resp_in_v_i
    ,input lce_lce_tr_resp_in_yumi_i

    ,input [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_out_i
    ,input lce_lce_tr_resp_out_v_i
    ,input lce_lce_tr_resp_out_ready_i 
  );

  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p, 4);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  bp_lce_cce_req_s lce_cce_req;
  bp_lce_cce_resp_s lce_cce_resp;
  bp_lce_cce_data_resp_s lce_cce_data_resp;
  bp_cce_lce_cmd_s cce_lce_cmd;
  bp_cce_lce_data_cmd_s cce_lce_data_cmd;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_in;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_out;

  assign lce_cce_req = lce_cce_req_i;
  assign lce_cce_resp = lce_cce_resp_i;
  assign lce_cce_data_resp = lce_cce_data_resp_i;
  assign cce_lce_cmd = cce_lce_cmd_i;
  assign cce_lce_data_cmd = cce_lce_data_cmd_i;
  assign lce_lce_tr_resp_in = lce_lce_tr_resp_in_i;
  assign lce_lce_tr_resp_out = lce_lce_tr_resp_out_i;

  `ifndef verilator
  // synopsys translate_off

  // properties
  //
  property prop_lce_cce_req_src_id_valid;
    disable iff (reset_i)
    @(posedge clk_i) not (lce_cce_req_v_i & lce_cce_req.src_id != id_p);
  endproperty
 
  property prop_lce_cce_req_miss_dirty;
    disable iff (reset_i)
    @(posedge clk_i) (lce_cce_req_v_i & lce_cce_req_ready_i & lce_cce_req.lru_dirty)
      |=> ##[1:$] (cce_lce_cmd_v_i & cce_lce_cmd_yumi_i& (cce_lce_cmd.msg_type == e_lce_cmd_writeback))
          ##[1:$] (lce_cce_data_resp_v_i & lce_cce_data_resp_ready_i);
  endproperty


  // assertion directives.
  //
  assert property(prop_lce_cce_req_src_id_valid) else $error("error");
  assert property(prop_lce_cce_req_miss_dirty);

  // synopsys translate_on
  `endif


endmodule
