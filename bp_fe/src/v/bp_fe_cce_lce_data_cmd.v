/**
y *
 * Name:
 *   bp_fe_lce_data_cmd.v
 *
 * Description:
 *   To	be updated
 *
 * Parameters:
 *
 * Inputs:
 *
 * Outputs:
 *
 * Keywords:
 *
 * Notes:
 *
 */


module bp_fe_lce_data_cmd
  import bp_common_pkg::*;
  import bp_fe_icache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter lce_addr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter lce_sets_p="inv"
    , parameter ways_p="inv"
    , parameter block_size_in_bytes_p="inv"

    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)

    , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    , parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                        ,num_lce_p
                                                                        ,lce_addr_width_p
                                                                        ,lce_data_width_p
                                                                        ,ways_p
                                                                       )
    , parameter bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p
                                                                                            ,ways_p
                                                                                            ,lce_data_width_p
                                                                                           )
   )
   (output logic                                                 cce_data_received_o
              
    , input [bp_cce_lce_data_cmd_width_lp-1:0]                   lce_data_cmd_i
    , input                                                      lce_data_cmd_v_i
    , output logic                                               lce_data_cmd_yumi_o
                 
    , output logic                                               data_mem_pkt_v_o
    , output logic [bp_fe_icache_lce_data_mem_pkt_width_lp-1:0]  data_mem_pkt_o
    , input                                                      data_mem_pkt_yumi_i
   );

  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  bp_cce_lce_data_cmd_s lce_data_cmd_li;
  assign lce_data_cmd_li = lce_data_cmd_i;
   
  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, ways_p, lce_data_width_p);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;
  assign data_mem_pkt_o = data_mem_pkt_lo;

  assign data_mem_pkt_lo.index   = lce_data_cmd_li.addr[lg_data_mask_width_lp
                                                            +lg_block_size_in_bytes_lp
                                                            +:lg_lce_sets_lp];
  assign data_mem_pkt_lo.way_id  = lce_data_cmd_li.way_id;
  assign data_mem_pkt_lo.data    = lce_data_cmd_li.data;
  assign data_mem_pkt_lo.we      = 1'b1;
  
  assign data_mem_pkt_v_o        = lce_data_cmd_v_i;
  assign lce_data_cmd_yumi_o = data_mem_pkt_yumi_i;
  assign cce_data_received_o     = lce_data_cmd_v_i & data_mem_pkt_yumi_i;

endmodule
