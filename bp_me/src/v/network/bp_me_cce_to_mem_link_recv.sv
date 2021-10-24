/**
 *
 * Name:
 *   bp_me_cce_to_mem_link_recv.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_cce_to_mem_link_recv
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)

   , parameter `BSG_INV_PARAM(num_outstanding_req_p)
   , parameter `BSG_INV_PARAM(flit_width_p)
   , parameter `BSG_INV_PARAM(cord_width_p)
   , parameter `BSG_INV_PARAM(cid_width_p)
   , parameter `BSG_INV_PARAM(len_width_p)

  // wormhole parameters
  , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
  )

  (input                                                clk_i
   , input                                              reset_i

   , input [cord_width_p-1:0]                           dst_cord_i
   , input [cid_width_p-1:0]                            dst_cid_i

   , output logic [cce_mem_msg_header_width_lp-1:0]     mem_cmd_header_o
   , output logic [cce_block_width_p-1:0]               mem_cmd_data_o
   , output logic                                       mem_cmd_v_o
   , input                                              mem_cmd_yumi_i
   , output logic                                       mem_cmd_last_o

   , input [cce_mem_msg_header_width_lp-1:0]            mem_resp_header_i
   , input [cce_block_width_p-1:0]                      mem_resp_data_i
   , input                                              mem_resp_v_i
   , output logic                                       mem_resp_ready_and_o
   , input                                              mem_resp_last_i

   // bsg_noc_wormhole interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]        cmd_link_i
   , output logic [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );

  wire unused = &{mem_resp_last_i};
  assign mem_cmd_last_o = mem_cmd_v_o;

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);
  `declare_bp_wormhole_packet_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, bp_bedrock_cce_mem_msg_header_s, mem, cce_block_width_p);
  localparam payload_width_lp = `bp_wormhole_payload_width(flit_width_p, cord_width_p, len_width_p, cid_width_p, $bits(bp_bedrock_cce_mem_msg_header_s), cce_block_width_p);

  bp_mem_wormhole_packet_s mem_cmd_packet_lo;
  bp_mem_wormhole_packet_s mem_resp_packet_lo;
  bp_mem_wormhole_header_s mem_resp_header_lo;
  bsg_wormhole_router_adapter
   #(.max_payload_width_p(payload_width_lp)
     ,.len_width_p(len_width_p)
     ,.cord_width_p(cord_width_p)
     ,.flit_width_p(flit_width_p)
     )
   mem_cmd_adapter
    (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.packet_o(mem_cmd_packet_lo)
      ,.v_o(mem_cmd_v_o)
      ,.yumi_i(mem_cmd_yumi_i)

      ,.link_i(cmd_link_i)
      ,.link_o(resp_link_o)

      ,.packet_i(mem_resp_packet_lo)
      ,.v_i(mem_resp_v_i)
      ,.ready_o(mem_resp_ready_and_o)
      );
  assign mem_cmd_header_o = mem_cmd_packet_lo.header.msg_hdr;
  assign mem_cmd_data_o = mem_cmd_packet_lo.data;

  bp_me_wormhole_packet_encode_mem_resp
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     )
   mem_resp_encode
    (.mem_resp_header_i(mem_resp_header_i)
     ,.dst_cord_i(dst_cord_i)
     ,.dst_cid_i(dst_cid_i)
     ,.wh_header_o(mem_resp_header_lo)
     );
  assign mem_resp_packet_lo = '{header: mem_resp_header_lo, data: mem_resp_data_i};

endmodule

`BSG_ABSTRACT_MODULE(bp_me_cce_to_mem_link_recv)

