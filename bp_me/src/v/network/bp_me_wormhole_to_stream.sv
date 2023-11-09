/**
 *
 * Name:
 *   bp_me_wormhole_to_stream.sv
 *
 * Description:
 *   Converts a wormhole router stream to BedRock Burst protocol without
 *   deserializing the data.
 *
 *   The data arriving on from the wormhole network is gearboxed to match the
 *   BedRock protocol data width.
 *
 * Assumptions:
 *  Usage of this module requires correctly formed wormhole headers. The length
 *    field of the wormhole message determines how many protocol data beats are
 *    expected (some multiple or divisor of the flit_width). We expect most
 *    link and protocol data width to be powers of 2 (32, 64, 512), so this
 *    length restriction is lenient.
 *
 *   - data width is a multiple of flit width
 *   - header width is a multiple of flit width
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
 *  Burst header is output before data.
 *
 */

`include "bsg_defines.sv"
`include "bp_common_defines.svh"

module bp_me_wormhole_to_stream
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   // The wormhole router protocol information
   // flit_width_p: number of physical data wires between links
   // cord_width_p: the width of the {y,x} coordinate of the destination
   // len_width_p : the width of the length field, denoting #flits+1
   // cid_width   : the width of the concentrator id of the destination
   // Default to 0 for cid so that this module can be used either
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
   )
  (input                                clk_i
   , input                              reset_i

   // The output of a wormhole network
   , input [flit_width_p-1:0]           link_data_i
   , input                              link_v_i
   , output logic                       link_ready_and_o

   // BedRock Burst output
   , output logic [pr_hdr_width_p-1:0]  pr_hdr_o
   , output logic [pr_data_width_p-1:0] pr_data_o
   , output logic                       pr_v_o
   , input                              pr_ready_and_i
   );

  `declare_bp_bedrock_generic_if(paddr_width_p, pr_payload_width_p, msg);
  `bp_cast_o(bp_bedrock_msg_header_s, pr_hdr);

  // parameter checks
  if (!(`BSG_IS_POW2(pr_data_width_p)) || !(`BSG_IS_POW2(flit_width_p)))
    $error("Protocol and Network data width must be powers of 2");

  // WH control signals
  logic is_hdr, is_data, wh_has_data, wh_last_data;

  // Header SIPO
  // Aggregate flits until we have a full header-worth of data
  logic sipo_ready_and_lo, sipo_v_li;
  logic [(flit_width_p*hdr_len_lp)-1:0] wh_hdr_lo;
  logic pr_hdr_v_lo, pr_hdr_yumi_li;
  bsg_serial_in_parallel_out_full
   #(.width_p(flit_width_p), .els_p(hdr_len_lp))
   hdr_sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(link_data_i)
     ,.v_i(sipo_v_li)
     ,.ready_and_o(sipo_ready_and_lo)

     ,.data_o(wh_hdr_lo)
     ,.v_o(pr_hdr_v_lo)
     ,.yumi_i(pr_hdr_yumi_li)
     );
  wire pr_has_data_lo = pr_stream_mask_p[pr_hdr_cast_o.msg_type];
  wire pr_last_data_lo = wh_last_data;
  assign sipo_v_li = is_hdr & link_v_i;

  assign pr_hdr_cast_o = wh_hdr_lo[wh_pr_hdr_offset_p+:pr_hdr_width_p];
  assign pr_data_o = link_data_i;
  assign pr_v_o = is_hdr ? (pr_hdr_v_lo & ~pr_has_data_lo) : link_v_i;
  assign pr_hdr_yumi_li = pr_ready_and_i & pr_v_o & (~pr_has_data_lo | pr_last_data_lo);

  assign link_ready_and_o = is_hdr ? sipo_ready_and_lo : pr_ready_and_i;

  // Identifies which flits are header vs data flits
  bp_me_wormhole_stream_control
   #(.len_width_p(len_width_p)
     ,.hdr_len_p(hdr_len_lp)
     )
   stream_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.len_i(link_data_i[wh_len_offset_p+:len_width_p])
     ,.link_accept_i(link_ready_and_o & link_v_i)

     ,.is_hdr_o(is_hdr)
     ,.has_data_o(wh_has_data)
     ,.is_data_o(is_data)
     ,.last_data_o(wh_last_data)
     );

  if (flit_width_p != pr_data_width_p)
    $error("flit_width_p %d != pr_data_width_p %d", flit_width_p, pr_data_width_p);

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wormhole_to_stream)

