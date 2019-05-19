/**
 *  Name:
 *    bp_be_dcache_lce_data_cmd.v
 *
 *  Description:
 *    LCE data command handler.
 */

module bp_be_dcache_lce_data_cmd 
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter ways_p="inv"
    , parameter sets_p="inv"

    , localparam block_size_in_words_lp=ways_p
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)

    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, lce_data_width_p, ways_p)

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
  )
  (input clk_i
   , input reset_i

    , output logic cce_data_received_o
    , output logic tr_data_received_o
    , output logic uncached_data_received_o

    , input [paddr_width_p-1:0] miss_addr_i
  
    , input [lce_data_cmd_width_lp-1:0] lce_data_cmd_i
    , input lce_data_cmd_v_i
    , output logic lce_data_cmd_ready_o

    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input data_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_lce_data_cmd_s(num_lce_p, lce_data_width_p, ways_p);

  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;

  assign data_mem_pkt_o = data_mem_pkt;

  // Output of ready-and-valid to ready-then-valid conversion
  //
  bp_lce_data_cmd_s lce_data_cmd_li;
  logic lce_data_cmd_v_li, lce_data_cmd_yumi_lo;

  // channel connection
  //
  assign data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
  assign data_mem_pkt.way_id = lce_data_cmd_li.way_id;
  assign data_mem_pkt.data = lce_data_cmd_li.data;
  assign data_mem_pkt.opcode = (lce_data_cmd_li.msg_type == e_lce_data_cmd_non_cacheable)
    ? e_dcache_lce_data_mem_uncached 
    : e_dcache_lce_data_mem_write;
    
  
  assign data_mem_pkt_v_o = lce_data_cmd_v_li;
  assign lce_data_cmd_yumi_lo = data_mem_pkt_yumi_i; 

  // wakeup logic
  //
  assign cce_data_received_o =
    data_mem_pkt_yumi_i & (lce_data_cmd_li.msg_type == e_lce_data_cmd_cce);

  assign tr_data_received_o =
    data_mem_pkt_yumi_i & (lce_data_cmd_li.msg_type == e_lce_data_cmd_transfer);

  assign uncached_data_received_o =
    data_mem_pkt_yumi_i & (lce_data_cmd_li.msg_type == e_lce_data_cmd_non_cacheable);

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
