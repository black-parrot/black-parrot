/**
 *
 * bp_fe_lce_lce_tr_resp_in.v
*/

`ifndef BP_CCE_MSG_VH
`define BP_CCE_MSG_VH
`include "bp_common_me_if.vh"
`endif

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

module bp_fe_lce_lce_tr_resp_in
  #(parameter lce_id_p="inv"
    , parameter data_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter lce_addr_width_p="inv"
    , parameter lce_sets_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter block_size_in_bytes_p="inv"
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    , parameter bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p
                                                                                            ,lce_assoc_p
                                                                                            ,lce_data_width_p
                                                                                           )
    , parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                      ,lce_addr_width_p
                                                                      ,lce_data_width_p
                                                                      ,lce_assoc_p
                                                                     )
   )
   (
    output logic                                                tr_received_o
 
    , input logic[bp_lce_lce_tr_resp_width_lp-1:0]              lce_lce_tr_resp_i
    , input logic                                               lce_lce_tr_resp_v_i
    , output logic                                              lce_lce_tr_resp_yumi_o

    , output logic                                              data_mem_pkt_v_o
    , output logic[bp_fe_icache_lce_data_mem_pkt_width_lp-1:0]  data_mem_pkt_o
    , input logic                                               data_mem_pkt_yumi_i
   );

  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p);
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_li;
  assign lce_lce_tr_resp_li = lce_lce_tr_resp_i;

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, lce_data_width_p);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;
  assign data_mem_pkt_o = data_mem_pkt_lo;

  assign data_mem_pkt_lo.index  = lce_lce_tr_resp_li.addr[lg_data_mask_width_lp
                                                          +lg_block_size_in_bytes_lp
                                                          +:lg_lce_sets_lp];
  assign data_mem_pkt_lo.assoc  = lce_lce_tr_resp_li.way_id;
  assign data_mem_pkt_lo.data   = lce_lce_tr_resp_li.data;
  assign data_mem_pkt_lo.we     = 1'b1;
  
  assign data_mem_pkt_v_o       = lce_lce_tr_resp_v_i;
  assign lce_lce_tr_resp_yumi_o = data_mem_pkt_yumi_i & lce_lce_tr_resp_v_i;
  assign tr_received_o          = data_mem_pkt_yumi_i & lce_lce_tr_resp_v_i;

endmodule   
  
