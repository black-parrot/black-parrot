/**
 *
 *  Name:
 *    bp_be_dcache_lce_tr.v
 *
 *  Description:
 *    LCE transfer handler.
 *
 *    It receives transfer from another LCE and write it on data_mem.
 *    It signals lce_req module, when transfer is received.
 */

module bp_be_dcache_lce_tr
  #(parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
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

    , localparam lce_lce_tr_resp_width_lp=
      `bp_lce_lce_tr_resp_width(num_lce_p, paddr_width_p, lce_data_width_p, ways_p)

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
  )
  (
    output logic tr_received_o

    , input [lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_i
    , input lce_tr_resp_v_i
    , output logic lce_tr_resp_yumi_o

    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input data_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, lce_data_width_p, ways_p);
  bp_lce_lce_tr_resp_s lce_tr_resp_in;

  assign lce_tr_resp_in = lce_tr_resp_i;

  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  
  assign data_mem_pkt_o = data_mem_pkt;

  // connecting channels
  //
  assign data_mem_pkt.index = lce_tr_resp_in.addr[block_offset_width_lp+:index_width_lp];
  assign data_mem_pkt.way_id = lce_tr_resp_in.way_id;
  assign data_mem_pkt.data = lce_tr_resp_in.data;
  assign data_mem_pkt.write_not_read = 1'b1;

  assign data_mem_pkt_v_o = lce_tr_resp_v_i;
  assign lce_tr_resp_yumi_o = data_mem_pkt_yumi_i;

  // wakeup logic
  //
  assign tr_received_o = data_mem_pkt_yumi_i;

endmodule
