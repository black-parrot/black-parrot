/**
 *  bp_dcache_lce_lce_tr_resp_in.v
 *
 *  @author tommy
 */

module bp_dcache_lce_lce_tr_resp_in
  #(parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter data_width_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter lce_data_width_p="inv"
    ,parameter ways_p="inv"
    ,parameter sets_p="inv"

    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)

    ,parameter lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)

    ,parameter dcache_lce_data_mem_pkt_width_lp=`bp_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
  )
  (
    output logic tr_received_o

    ,input [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_i
    ,input lce_lce_tr_resp_v_i
    ,output logic lce_lce_tr_resp_yumi_o

    ,output logic data_mem_pkt_v_o
    ,output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    ,input data_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  `declare_bp_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_in;
  bp_dcache_lce_data_mem_pkt_s data_mem_pkt;

  assign lce_lce_tr_resp_in = lce_lce_tr_resp_i;
  assign data_mem_pkt_o = data_mem_pkt;

  // connecting channels
  //
  assign data_mem_pkt.index = lce_lce_tr_resp_in.addr[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp];
  assign data_mem_pkt.way = lce_lce_tr_resp_in.way_id;
  assign data_mem_pkt.data = lce_lce_tr_resp_in.data;
  assign data_mem_pkt.write_not_read = 1'b1;

  assign data_mem_pkt_v_o = lce_lce_tr_resp_v_i;
  assign lce_lce_tr_resp_yumi_o = data_mem_pkt_yumi_i;

  // wakeup logic
  //
  assign tr_received_o = data_mem_pkt_yumi_i;

endmodule
