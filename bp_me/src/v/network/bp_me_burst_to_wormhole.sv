/**
 *
 * Name:
 *   bp_me_burst_to_wormhole.sv
 *
 * Description:
 *   Converts BedRock Burst protocol to wormhole router stream.
 *   The data width of the BedRock Burst protocol is first gearboxed to match the
 *   wormhole network flit width.
 *
 * Assumptions:
 *  Usage of this module requires correctly formed wormhole headers. The length
 *    field of the wormhole message determines how many protocol data beats are
 *    expected (some multiple or divisor of the flit_width). We expect most
 *    link and protocol data widths to be powers of 2 (32, 64, 512), so this
 *    length restriction is lenient.
 *
 *   - data width is a multiple of flit width (would be easy to add support)
 *   - header width is a multiple of flit width  (would be more challenging)
 *     - header width == wormhole header width + protocol header width
 *   - wormhole packets are laid out like the following:
 *   ----------------------------------------------------------------
 *   | data   | data  | data  | data  | pad  pr_hdr  cid  len  cord |
 *   ----------------------------------------------------------------
 *   - header flits do not contain any data
 *   - the example above shows the entire header in a single flit, but it
 *     may require more than one wormhole link flits if pr_hdr length
 *     is greater than flit_width - cord_width - len_width - cid_width
 *
 * Input Burst message has a single header beat and zero or more data beats.
 * This module does not accept data until the header sends.
 * Header must be formatted for wormhole network as shown above.
 *
 */

`include "bsg_defines.v"
`include "bp_common_defines.svh"

module bp_me_burst_to_wormhole
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   // The wormhole router protocol information
   // flit_width_p: number of physical data wires between links
   // cord_width_p: the width of the {y,x} coordinate of the destination
   // len_width_p : the width of the length field, denoting #flits+1
   // cid_width   : the width of the concentrator id of the destination
   // Default to 0 for cord and cid, so that this module can be used either
   //   for concentrator or router
   , parameter `BSG_INV_PARAM(flit_width_p)
   , parameter `BSG_INV_PARAM(cord_width_p)
   , parameter `BSG_INV_PARAM(len_width_p)
   , parameter cid_width_p     = 0

   // Higher level protocol information
   , parameter `BSG_INV_PARAM(pr_hdr_width_p)
   , parameter `BSG_INV_PARAM(pr_payload_width_p)
   , parameter `BSG_INV_PARAM(pr_payload_mask_p)
   , parameter `BSG_INV_PARAM(pr_data_width_p)

   // Computed wormhole header parameters. These can be overridden directly if desired.
   // Size of the wormhole header + the protocol header
   , parameter wh_hdr_width_p = cord_width_p + len_width_p + cid_width_p + pr_hdr_width_p
   // offset of protocol header in deserialized wormhole header
   , parameter wh_pr_hdr_offset_p = (cord_width_p + len_width_p + cid_width_p)
   // offset of length field in wormhole header
   , parameter wh_len_offset_p = cord_width_p

   // Number of wormhole link flits per wormhole header
   , localparam [len_width_p-1:0] hdr_len_lp = `BSG_CDIV(wh_hdr_width_p, flit_width_p)

   // padding in wormhole header
   , localparam wh_hdr_pad_lp = (flit_width_p*hdr_len_lp) - wh_hdr_width_p
   )
  (input                             clk_i
   , input                           reset_i

   // BedRock Burst input channel
   // ready&valid
   , input [pr_hdr_width_p-1:0]      pr_hdr_i
   , input                           pr_hdr_v_i
   , output logic                    pr_hdr_ready_and_o
   , input                           pr_has_data_i
   , input [cord_width_p-1:0]        dst_cord_i
   , input [cid_width_p-1:0]         dst_cid_i

   , input [pr_data_width_p-1:0]     pr_data_i
   , input                           pr_data_v_i
   , output logic                    pr_data_ready_and_o
   , input                           pr_last_i

   // Wormhole output
   // ready&valid
   , output logic [flit_width_p-1:0] link_data_o
   , output logic                    link_v_o
   , input                           link_ready_and_i
   );

  // parameter checks
  if (!(`BSG_IS_POW2(pr_data_width_p)) || !(`BSG_IS_POW2(flit_width_p)))
    $error("Protocol and Network data widths must be powers of 2");

  `declare_bp_bedrock_if(paddr_width_p, pr_payload_width_p, lce_id_width_p, lce_assoc_p, msg);
  `bp_cast_i(bp_bedrock_msg_header_s, pr_hdr);

  `declare_bp_bedrock_wormhole_header_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, bp_bedrock_msg_header_s, bedrock);
  bp_bedrock_wormhole_header_s wh_hdr_lo;
  bp_me_wormhole_header_encode
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     ,.payload_width_p(pr_payload_width_p)
     ,.payload_mask_p(pr_payload_mask_p)
     )
   encode
    (.header_i(pr_hdr_cast_i)
     ,.dst_cord_i(dst_cord_i)
     ,.dst_cid_i(dst_cid_i)
     ,.wh_header_o(wh_hdr_lo)
     );

  // BedRock Burst Gearbox
  // header is only used to determine number of output data beats, and is otherwise passed
  // through the gearbox without modification
  logic pr_hdr_v_li, pr_hdr_ready_and_lo;
  logic [flit_width_p-1:0] pr_data_li;
  logic pr_data_v_li, pr_data_ready_and_lo;

  bp_me_burst_gearbox
    #(.bp_params_p(bp_params_p)
      ,.in_data_width_p(pr_data_width_p)
      ,.out_data_width_p(flit_width_p)
      ,.payload_width_p(pr_payload_width_p)
      )
    gearbox
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.msg_header_i(pr_hdr_i)
      ,.msg_header_v_i(pr_hdr_v_i)
      ,.msg_header_ready_and_o(pr_hdr_ready_and_o)
      ,.msg_has_data_i(pr_has_data_i)
      ,.msg_data_i(pr_data_i)
      ,.msg_data_v_i(pr_data_v_i)
      ,.msg_data_ready_and_o(pr_data_ready_and_o)
      ,.msg_last_i(pr_last_i)

      ,.msg_header_o(/* unused */)
      ,.msg_header_v_o(pr_hdr_v_li)
      ,.msg_header_ready_and_i(pr_hdr_ready_and_lo)
      ,.msg_has_data_o(/* unused */)
      ,.msg_data_o(pr_data_li)
      ,.msg_data_v_o(pr_data_v_li)
      ,.msg_data_ready_and_i(pr_data_ready_and_lo)
      ,.msg_last_o(/* unused */)
      );

  // WH control signals
  logic is_hdr, is_data;

  // Header PISO
  // Header is input all at once and streamed out 1 flit at a time
  logic hdr_v_li, hdr_ready_and_lo;
  assign hdr_v_li = is_hdr & pr_hdr_v_li;
  logic [flit_width_p-1:0] hdr_lo;
  logic hdr_v_lo, hdr_ready_and_li;
  assign hdr_ready_and_li = is_hdr & link_ready_and_i;
  assign pr_hdr_ready_and_lo = is_hdr & hdr_ready_and_lo;

  wire [(flit_width_p*hdr_len_lp)-1:0] wh_hdr_padded_li = wh_hdr_lo;
  bsg_parallel_in_serial_out_passthrough
   #(.width_p(flit_width_p)
     ,.els_p(hdr_len_lp)
     )
   hdr_piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(wh_hdr_padded_li)
     ,.v_i(hdr_v_li)
     ,.ready_and_o(hdr_ready_and_lo)

     ,.data_o(hdr_lo)
     ,.v_o(hdr_v_lo)
     ,.ready_and_i(hdr_ready_and_li)
     );

  // Data is streamed 1:1 from output of gearbox directly to link
  assign pr_data_ready_and_lo = is_data & link_ready_and_i;

  // Identifies which flits are header vs data flits
  bsg_wormhole_stream_control
   #(.len_width_p(len_width_p)
     ,.hdr_len_p(hdr_len_lp)
     )
   stream_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.len_i(hdr_lo[wh_len_offset_p+:len_width_p])
     ,.link_accept_i(link_ready_and_i & link_v_o)

     ,.is_hdr_o(is_hdr)
     ,.has_data_o(/* unused */)
     ,.is_data_o(is_data)
     ,.last_data_o(/* unused */)
     );

  // patch header or data flits to link
  assign link_data_o = is_hdr ? hdr_lo   : pr_data_li;
  assign link_v_o    = is_hdr ? hdr_v_lo : pr_data_v_li;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_burst_to_wormhole)

