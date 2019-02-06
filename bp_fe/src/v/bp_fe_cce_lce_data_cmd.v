/**
y *
 * Name:
 *   bp_fe_lce_cce_data_cmd.v
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

`include "bp_common_me_if.vh"
`include "bsg_defines.v"

module bp_fe_cce_lce_data_cmd
  #(parameter data_width_p="inv"
    , parameter lce_addr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter lce_sets_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter block_size_in_bytes_p="inv"

    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)

    , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    , parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                        ,num_lce_p
                                                                        ,lce_addr_width_p
                                                                        ,lce_data_width_p
                                                                        ,lce_assoc_p
                                                                       )
    , parameter bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p
                                                                                            ,lce_assoc_p
                                                                                            ,lce_data_width_p
                                                                                           )
   )
   (output logic                                                 cce_data_received_o
              
    , input [bp_cce_lce_data_cmd_width_lp-1:0]                   cce_lce_data_cmd_i
    , input                                                      cce_lce_data_cmd_v_i
    , output logic                                               cce_lce_data_cmd_yumi_o
                 
    , output logic                                               data_mem_pkt_v_o
    , output logic [bp_fe_icache_lce_data_mem_pkt_width_lp-1:0]  data_mem_pkt_o
    , input                                                      data_mem_pkt_yumi_i
   );

  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p);
  bp_cce_lce_data_cmd_s cce_lce_data_cmd_li;
  assign cce_lce_data_cmd_li = cce_lce_data_cmd_i;
   
  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, lce_data_width_p);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;
  assign data_mem_pkt_o = data_mem_pkt_lo;

  assign data_mem_pkt_lo.index   = cce_lce_data_cmd_li.addr[lg_data_mask_width_lp
                                                            +lg_block_size_in_bytes_lp
                                                            +:lg_lce_sets_lp];
  assign data_mem_pkt_lo.assoc   = cce_lce_data_cmd_li.way_id;
  assign data_mem_pkt_lo.data    = cce_lce_data_cmd_li.data;
  assign data_mem_pkt_lo.we      = 1'b1;
  
  assign data_mem_pkt_v_o        = cce_lce_data_cmd_v_i;
  assign cce_lce_data_cmd_yumi_o = data_mem_pkt_yumi_i;
  assign cce_data_received_o     = cce_lce_data_cmd_v_i & data_mem_pkt_yumi_i;

endmodule
