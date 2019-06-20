/**
 *
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
  import bp_fe_pkg::*;
  import bp_common_aviary_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )
    // these will go away once the naming convention is decided on
    , localparam ways_p = lce_assoc_p
    , localparam sets_p = lce_sets_p
    , localparam data_width_p = dword_width_p

   `declare_bp_fe_tag_widths(ways_p, sets_p, num_lce_p, num_cce_p, data_width_p, paddr_width_p)
   `declare_bp_fe_lce_widths(ways_p, sets_p, tag_width_lp, lce_data_width_lp)
  )  
  ( input                                                        clk_i
    , input                                                      reset_i

    , output logic                                               cce_data_received_o
    , output logic                                               tr_data_received_o
    , output logic                                               uncached_data_received_o

    , input [paddr_width_p-1:0]                                  miss_addr_i
              
    , input [lce_data_cmd_width_lp-1:0]                          lce_data_cmd_i
    , input                                                      lce_data_cmd_v_i
    , output logic                                               lce_data_cmd_ready_o
                 
    , output logic                                               data_mem_pkt_v_o
    , output logic [data_mem_pkt_width_lp-1:0]  data_mem_pkt_o
    , input                                                      data_mem_pkt_yumi_i
   );

  `declare_bp_lce_data_cmd_s(num_lce_p, cce_block_width_p, ways_p);
  bp_lce_data_cmd_s lce_data_cmd_li;
  logic lce_data_cmd_v_li, lce_data_cmd_yumi_lo;
   
  `declare_bp_fe_icache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_lp);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;
  assign data_mem_pkt_o = data_mem_pkt_lo;

  assign data_mem_pkt_lo.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
  assign data_mem_pkt_lo.way_id  = lce_data_cmd_li.way_id;
  assign data_mem_pkt_lo.data    = lce_data_cmd_li.data;
  assign data_mem_pkt_lo.opcode  = (lce_data_cmd_li.msg_type == e_lce_data_cmd_non_cacheable)
    ? e_icache_lce_data_mem_uncached
    : e_icache_lce_data_mem_write;
  
  assign data_mem_pkt_v_o        = lce_data_cmd_v_li;
  assign lce_data_cmd_yumi_lo    = data_mem_pkt_yumi_i;
  assign cce_data_received_o = data_mem_pkt_yumi_i & (lce_data_cmd_li.msg_type == e_lce_data_cmd_cce);
  assign tr_data_received_o = data_mem_pkt_yumi_i & (lce_data_cmd_li.msg_type == e_lce_data_cmd_transfer);
  assign uncached_data_received_o = data_mem_pkt_yumi_i & (lce_data_cmd_li.msg_type == e_lce_data_cmd_non_cacheable);

  // We need this converter because the LCE expects this interface to be valid-yumi, while
  // the network links are ready-and-valid. It's possible that we could modify the LCE to 
  // be helpful and avoid this
  bsg_two_fifo 
   #(.width_p(lce_data_cmd_width_lp))
   rv_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(lce_data_cmd_i)
     ,.v_i(lce_data_cmd_v_i)
     ,.ready_o(lce_data_cmd_ready_o)

     ,.data_o(lce_data_cmd_li)
     ,.v_o(lce_data_cmd_v_li)
     ,.yumi_i(lce_data_cmd_yumi_lo)
     );

endmodule
