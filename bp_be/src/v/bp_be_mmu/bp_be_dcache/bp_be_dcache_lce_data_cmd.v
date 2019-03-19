/**
 *  Name:
 *    bp_be_dcache_lce_data_cmd.v
 *
 *  Description:
 *    LCE data command handler.
 */

module bp_be_dcache_lce_data_cmd 
  import bp_common_pkg::*;
  #(parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter ways_p="inv"
    , parameter sets_p="inv"

    , localparam block_size_in_words_lp=ways_p
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam page_offset_width_lp=(block_offset_width_lp+index_width_lp)
    , localparam ptag_width_lp=(paddr_width_p-page_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)

    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, lce_data_width_p, ways_p)

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
  )
  (
    output logic cce_data_received_o
    , output logic tr_data_received_o

    , input [paddr_width_p-1:0] miss_addr_i
  
    , input [lce_data_cmd_width_lp-1:0] lce_data_cmd_i
    , input lce_data_cmd_v_i
    , output logic lce_data_cmd_yumi_o

    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input data_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_lce_data_cmd_s(num_lce_p, lce_data_width_p, ways_p);
  bp_lce_data_cmd_s lce_data_cmd;

  assign lce_data_cmd = lce_data_cmd_i;

  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;

  assign data_mem_pkt_o = data_mem_pkt;

  // channel connection
  //
  assign data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
  assign data_mem_pkt.way_id = lce_data_cmd.way_id;
  assign data_mem_pkt.data = lce_data_cmd.data;
  assign data_mem_pkt.write_not_read = 1'b1; 
  
  assign data_mem_pkt_v_o = lce_data_cmd_v_i;
  assign lce_data_cmd_yumi_o = data_mem_pkt_yumi_i; 

  // wakeup logic
  //
  assign cce_data_received_o = data_mem_pkt_yumi_i & (lce_data_cmd.msg_type == e_lce_data_cmd_cce);
  assign tr_data_received_o = data_mem_pkt_yumi_i & (lce_data_cmd.msg_type == e_lce_data_cmd_transfer);

endmodule
