/**
 *
 * Name:
 *   bp_me_stream_to_wormhole.sv
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
 *    link and protocol data width to be powers of 2 (32, 64, 512), so this
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

`include "bsg_defines.sv"
`include "bp_common_defines.svh"

module bp_me_stream_to_wormhole
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
   , parameter `BSG_INV_PARAM(pr_stream_mask_p)
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
   , input [pr_data_width_p-1:0]     pr_data_i
   , input                           pr_v_i
   , output logic                    pr_ready_and_o
   , input [cord_width_p-1:0]        dst_cord_i
   , input [cid_width_p-1:0]         dst_cid_i

   // Wormhole output
   // ready&valid
   , output logic [flit_width_p-1:0] link_data_o
   , output logic                    link_v_o
   , input                           link_ready_and_i
   );

  // parameter checks
  if (!(`BSG_IS_POW2(pr_data_width_p)) || !(`BSG_IS_POW2(flit_width_p)))
    $error("Protocol and Network data width must be powers of 2");

  `declare_bp_bedrock_generic_if(paddr_width_p, pr_payload_width_p, msg);
  `bp_cast_i(bp_bedrock_msg_header_s, pr_hdr);

  // WH control signals
  logic is_hdr, is_data, wh_has_data, wh_last_data;

  `declare_bp_bedrock_wormhole_header_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, bp_bedrock_msg_header_s, bedrock);
  bp_bedrock_wormhole_header_s pr_wh_hdr_lo;

  bp_me_wormhole_header_encode
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     ,.payload_width_p(pr_payload_width_p)
     ,.stream_mask_p(pr_stream_mask_p)
     )
   encode
    (.header_i(pr_hdr_cast_i)
     ,.dst_cord_i(dst_cord_i)
     ,.dst_cid_i(dst_cid_i)
     ,.wh_header_o(pr_wh_hdr_lo)
     );
  wire [(flit_width_p*hdr_len_lp)-1:0] pr_wh_hdr_padded_li = pr_wh_hdr_lo;

  // Header is input all at once and streamed out 1 flit at a time
  logic piso_ready_and_lo, piso_v_li;
  logic [flit_width_p-1:0] wh_hdr_lo;
  logic wh_hdr_ready_and_li, wh_hdr_v_lo;
  assign piso_v_li = is_hdr & pr_v_i;
  bsg_parallel_in_serial_out_passthrough
   #(.width_p(flit_width_p), .els_p(hdr_len_lp))
   hdr_piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(pr_wh_hdr_padded_li)
     ,.v_i(piso_v_li)
     ,.ready_and_o(piso_ready_and_lo)

     ,.data_o(wh_hdr_lo)
     ,.v_o(wh_hdr_v_lo)
     ,.ready_and_i(wh_hdr_ready_and_li)
     );
  assign wh_hdr_ready_and_li = is_hdr & link_ready_and_i;

  logic [pr_data_width_p-1:0] wh_data_r;
  bsg_dff_en
   #(.width_p(pr_data_width_p))
   wh_data_reg
    (.clk_i(clk_i)
     ,.en_i(pr_ready_and_o & pr_v_i)
     ,.data_i(pr_data_i)
     ,.data_o(wh_data_r)
     );

  logic wh_data_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   wh_data_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(pr_ready_and_o & pr_v_i & wh_has_data)
     ,.clear_i(link_ready_and_i & link_v_o & is_data)
     ,.data_o(wh_data_v_r)
     );

  assign pr_ready_and_o = is_hdr ? piso_ready_and_lo : (~wh_last_data & link_ready_and_i);

  // Identifies which flits are header vs data flits
  bp_me_wormhole_stream_control
   #(.len_width_p(len_width_p), .hdr_len_p(hdr_len_lp))
   stream_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.len_i(pr_wh_hdr_lo[wh_len_offset_p+:len_width_p])
     ,.link_accept_i(link_ready_and_i & link_v_o)

     ,.is_hdr_o(is_hdr)
     ,.has_data_o(wh_has_data)
     ,.is_data_o(is_data)
     ,.last_data_o(wh_last_data)
     );

  // patch header or data flits to link
  assign link_data_o = is_hdr ? wh_hdr_lo   : wh_data_r;
  assign link_v_o    = is_hdr ? wh_hdr_v_lo : wh_data_v_r;

  if (flit_width_p != pr_data_width_p)
    $error("flit_width_p %d != pr_data_width_p %d", flit_width_p, pr_data_width_p);

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_to_wormhole)

