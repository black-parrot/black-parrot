/**
 *
 * Name:
 *   bp_me_bedrock_mem_to_link.sv
 *
 * Description:
 *   Converts BedRock Burst Memory Interface to Wormhole Link interface.
 *   The payload_mask_p parameter indicates which BedRock input messages carry data.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_bedrock_mem_to_link
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(flit_width_p)
   , parameter `BSG_INV_PARAM(cord_width_p)
   , parameter `BSG_INV_PARAM(cid_width_p)
   , parameter `BSG_INV_PARAM(len_width_p)

   , parameter payload_mask_p = 0

  // wormhole parameters
  , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
  )

  (input                                                clk_i
   , input                                              reset_i

   , input [cord_width_p-1:0]                           dst_cord_i
   , input [cid_width_p-1:0]                            dst_cid_i

   // CCE-MEM Interface
   , input [mem_header_width_lp-1:0]                    mem_header_i
   , input                                              mem_header_v_i
   , output logic                                       mem_header_ready_and_o
   , input                                              mem_has_data_i
   , input [bedrock_data_width_p-1:0]                   mem_data_i
   , input                                              mem_data_v_i
   , output logic                                       mem_data_ready_and_o
   , input                                              mem_last_i

   , output logic [mem_header_width_lp-1:0]             mem_header_o
   , output                                             mem_header_v_o
   , input                                              mem_header_ready_and_i
   , output logic                                       mem_has_data_o
   , output logic [bedrock_data_width_p-1:0]            mem_data_o
   , output                                             mem_data_v_o
   , input                                              mem_data_ready_and_i
   , output logic                                       mem_last_o

   // bsg_noc_wormhole interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]        link_i
   , output logic [bsg_ready_and_link_sif_width_lp-1:0] link_o
   );

  // CCE-MEM interface packets
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bsg_ready_and_link_sif_s(flit_width_p, bp_mem_ready_and_link_s);
  `bp_cast_i(bp_mem_ready_and_link_s, link);
  `bp_cast_o(bp_mem_ready_and_link_s, link);
  `bp_cast_o(bp_bedrock_mem_header_s, mem_header);

  // CCE-MEM IF to Wormhole routed interface
  `declare_bp_bedrock_wormhole_header_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, bp_bedrock_mem_header_s, mem);
  localparam wh_pad_width_lp = `bp_bedrock_wormhole_packet_pad_width(flit_width_p, cord_width_p, len_width_p, cid_width_p, $bits(bp_bedrock_mem_header_s));

  // mem resp burst to wh
  bp_mem_wormhole_header_s mem_header_li;
  bp_me_wormhole_packet_encode_mem
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     ,.payload_mask_p(payload_mask_p)
     )
   mem_encode
    (.mem_header_i(mem_header_i)
     ,.dst_cord_i(dst_cord_i)
     ,.dst_cid_i(dst_cid_i)
     ,.wh_header_o(mem_header_li)
     );

  bp_me_burst_to_wormhole
   #(.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.len_width_p(len_width_p)
     ,.cid_width_p(cid_width_p)
     ,.pr_hdr_width_p(mem_header_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     )
   mem_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.pr_hdr_i(mem_header_li[0+:($bits(bp_mem_wormhole_header_s)-wh_pad_width_lp)])
    ,.pr_hdr_v_i(mem_header_v_i)
    ,.pr_hdr_ready_and_o(mem_header_ready_and_o)
    ,.pr_has_data_i(mem_has_data_i)

    ,.pr_data_i(mem_data_i)
    ,.pr_data_v_i(mem_data_v_i)
    ,.pr_data_ready_and_o(mem_data_ready_and_o)
    ,.pr_last_i(mem_last_i)

    ,.link_data_o(link_cast_o.data)
    ,.link_v_o(link_cast_o.v)
    ,.link_ready_and_i(link_cast_i.ready_and_rev)
    );

  // mem cmd wh to burst
  localparam bedrock_len_width_lp = `BSG_SAFE_CLOG2(`BSG_CDIV((1<<e_bedrock_msg_size_128)*8,bedrock_data_width_p));
  logic [bedrock_len_width_lp-1:0] mem_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(bedrock_len_width_lp)
     ,.beat_width_p(bedrock_data_width_p)
     )
   mem_size_to_len
   (.size_i(mem_header_cast_o.size)
    ,.len_o(mem_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.len_width_p(len_width_p)
     ,.cid_width_p(cid_width_p)
     ,.pr_hdr_width_p(mem_header_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     ,.pr_len_width_p(bedrock_len_width_lp)
     )
   mem_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_data_i(link_cast_i.data)
    ,.link_v_i(link_cast_i.v)
    ,.link_ready_and_o(link_cast_o.ready_and_rev)

    ,.pr_hdr_o(mem_header_cast_o)
    ,.pr_hdr_v_o(mem_header_v_o)
    ,.pr_hdr_ready_and_i(mem_header_ready_and_i)
    ,.pr_has_data_o(mem_has_data_o)
    ,.pr_data_beats_i(mem_pr_len)

    ,.pr_data_o(mem_data_o)
    ,.pr_data_v_o(mem_data_v_o)
    ,.pr_data_ready_and_i(mem_data_ready_and_i)
    ,.pr_last_o(mem_last_o)
    );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_bedrock_mem_to_link)

