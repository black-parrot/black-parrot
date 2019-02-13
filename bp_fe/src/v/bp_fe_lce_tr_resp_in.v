/**
 *
 * Name:
 *   bp_fe_lce_tr_resp_in.v
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


module bp_fe_lce_tr_resp_in
  import bp_fe_icache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter lce_addr_width_p="inv"
    , parameter lce_sets_p="inv"
    , parameter ways_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter block_size_in_bytes_p="inv"
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , localparam lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    , localparam bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p
                                                                                            ,ways_p
                                                                                            ,lce_data_width_p
                                                                                           )
    , localparam bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                      ,lce_addr_width_p
                                                                      ,lce_data_width_p
                                                                      ,ways_p
                                                                     )
   )
   (
    output logic                                                tr_received_o
 
    , input [bp_lce_lce_tr_resp_width_lp-1:0]                    lce_tr_resp_i
    , input                                                      lce_tr_resp_v_i
    , output logic                                               lce_tr_resp_yumi_o

    , output logic                                               data_mem_pkt_v_o
    , output logic [bp_fe_icache_lce_data_mem_pkt_width_lp-1:0]  data_mem_pkt_o
    , input                                                      data_mem_pkt_yumi_i
   );

  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  bp_lce_lce_tr_resp_s lce_tr_resp_li;
  assign lce_tr_resp_li = lce_tr_resp_i;

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, ways_p, lce_data_width_p);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;
  assign data_mem_pkt_o = data_mem_pkt_lo;

  assign data_mem_pkt_lo.index  = lce_tr_resp_li.addr[lg_data_mask_width_lp
                                                          +lg_block_size_in_bytes_lp
                                                          +:lg_lce_sets_lp];
  assign data_mem_pkt_lo.way_id = lce_tr_resp_li.way_id;
  assign data_mem_pkt_lo.data   = lce_tr_resp_li.data;
  assign data_mem_pkt_lo.we     = 1'b1;
  
  assign data_mem_pkt_v_o       = lce_tr_resp_v_i;
  assign lce_tr_resp_yumi_o = data_mem_pkt_yumi_i & lce_tr_resp_v_i;
  assign tr_received_o          = data_mem_pkt_yumi_i & lce_tr_resp_v_i;

endmodule   
  
