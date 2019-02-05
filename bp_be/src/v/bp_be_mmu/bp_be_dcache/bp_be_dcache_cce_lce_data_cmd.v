/**
 *  bp_be_dcache_cce_lce_data_cmd.v
 */

module bp_be_dcache_cce_lce_data_cmd 
  #(parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter data_width_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter lce_data_width_p="inv"
    ,parameter ways_p="inv"
    ,parameter sets_p="inv"

    ,localparam data_mask_width_lp=(data_width_p>>3)
    ,localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)

    ,localparam cce_lce_data_cmd_width_lp=
      `bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)

    ,localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
  )
  (
    output logic cce_data_received_o
  
    ,input [cce_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_i
    ,input cce_lce_data_cmd_v_i
    ,output logic cce_lce_data_cmd_yumi_o

    ,output logic data_mem_pkt_v_o
    ,output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    ,input data_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  
  bp_cce_lce_data_cmd_s cce_lce_data_cmd;
  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;

  assign cce_lce_data_cmd = cce_lce_data_cmd_i;
  assign data_mem_pkt_o = data_mem_pkt;

  // channel connection
  //
  assign data_mem_pkt.index = cce_lce_data_cmd.addr[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp];
  assign data_mem_pkt.way = cce_lce_data_cmd.way_id;
  assign data_mem_pkt.data = cce_lce_data_cmd.data;
  assign data_mem_pkt.write_not_read = 1'b1; 
  
  assign data_mem_pkt_v_o = cce_lce_data_cmd_v_i;
  assign cce_lce_data_cmd_yumi_o = data_mem_pkt_yumi_i; 

  // wakeup logic
  //
  assign cce_data_received_o = data_mem_pkt_yumi_i;

endmodule
