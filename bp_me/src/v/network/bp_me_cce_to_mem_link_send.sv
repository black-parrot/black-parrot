/**
 *
 * Name:
 *   bp_me_cce_to_mem_link_send.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_cce_to_mem_link_send
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter `BSG_INV_PARAM(flit_width_p)
   , parameter `BSG_INV_PARAM(cord_width_p)
   , parameter `BSG_INV_PARAM(cid_width_p)
   , parameter `BSG_INV_PARAM(len_width_p)

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
   )
  (input                                                clk_i
   , input                                              reset_i

   // Configuration
   , input [cord_width_p-1:0]                           dst_cord_i
   , input [cid_width_p-1:0]                            dst_cid_i

   // CCE-MEM Interface
   , input [mem_header_width_lp-1:0]                    mem_cmd_header_i
   , input [cce_block_width_p-1:0]                      mem_cmd_data_i
   , input                                              mem_cmd_v_i
   , output logic                                       mem_cmd_ready_and_o
   , input                                              mem_cmd_last_i

   , output logic [mem_header_width_lp-1:0]             mem_resp_header_o
   , output logic [cce_block_width_p-1:0]               mem_resp_data_o
   , output                                             mem_resp_v_o
   , input                                              mem_resp_yumi_i
   , output logic                                       mem_resp_last_o

   // bsg_noc_wormhole interface
   , output logic [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o
   , input [bsg_ready_and_link_sif_width_lp-1:0]        resp_link_i
   );

  wire unused = &{mem_cmd_last_i};
  assign mem_resp_last_o = mem_resp_v_o;

  // CCE-MEM interface packets
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  // CCE-MEM IF to Wormhole routed interface
  `declare_bp_bedrock_wormhole_packet_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, bp_bedrock_mem_header_s, mem, cce_block_width_p);
  localparam payload_width_lp = `bp_bedrock_wormhole_payload_width(flit_width_p, cord_width_p, len_width_p, cid_width_p, $bits(bp_bedrock_mem_header_s), cce_block_width_p);

  bp_mem_wormhole_packet_s mem_cmd_packet_li;
  bp_mem_wormhole_header_s mem_cmd_header_li;
  bp_me_wormhole_packet_encode_mem
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     ,.payload_mask_p(mem_cmd_payload_mask_gp)
     )
   mem_cmd_encode
    (.mem_header_i(mem_cmd_header_i)
     ,.dst_cord_i(dst_cord_i)
     ,.dst_cid_i(dst_cid_i)
     ,.wh_header_o(mem_cmd_header_li)
     );
  assign mem_cmd_packet_li = '{header: mem_cmd_header_li, data: mem_cmd_data_i};

  bp_mem_wormhole_packet_s mem_resp_packet_lo;
  bsg_wormhole_router_adapter
   #(.max_payload_width_p(payload_width_lp)
     ,.len_width_p(len_width_p)
     ,.cord_width_p(cord_width_p)
     ,.flit_width_p(flit_width_p)
     )
   mem_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(mem_cmd_packet_li)
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_and_o)

     ,.link_o(cmd_link_o)
     ,.link_i(resp_link_i)

     ,.packet_o(mem_resp_packet_lo)
     ,.v_o(mem_resp_v_o)
     ,.yumi_i(mem_resp_yumi_i)
     );
  assign mem_resp_header_o = mem_resp_packet_lo.header.msg_hdr;
  assign mem_resp_data_o = mem_resp_packet_lo.data;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_cce_to_mem_link_send)

