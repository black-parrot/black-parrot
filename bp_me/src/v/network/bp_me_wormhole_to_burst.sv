/**
 *
 * Name:
 *   bp_me_wormhole_to_burst.sv
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
 *    link and protocol data widths to be powers of 2 (32, 64, 512), so this
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

`include "bsg_defines.v"
`include "bp_common_defines.svh"

module bp_me_wormhole_to_burst
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
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
   , output logic                       pr_hdr_v_o
   , input                              pr_hdr_ready_and_i
   , output logic                       pr_has_data_o

   // The protocol data information
   , output logic [pr_data_width_p-1:0] pr_data_o
   , output logic                       pr_data_v_o
   , input                              pr_data_ready_and_i
   , output logic                       pr_last_o
   );

  // parameter checks
  if (!(`BSG_IS_POW2(pr_data_width_p)) || !(`BSG_IS_POW2(flit_width_p)))
    $error("Protocol and Network data widths must be powers of 2");

  // WH control signals
  logic is_hdr, is_data, wh_has_data, wh_last_data;

  // Header SIPO
  // Aggregate flits until we have a full header-worth of data
  logic hdr_v_li, hdr_ready_and_lo;
  assign hdr_v_li = is_hdr & link_v_i;
  logic [(flit_width_p*hdr_len_lp)-1:0] pr_hdr_lo;
  logic pr_hdr_v_lo, pr_hdr_ready_and_li;

  bsg_serial_in_parallel_out_passthrough
   #(.width_p(flit_width_p)
     ,.els_p(hdr_len_lp)
     )
   hdr_sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(link_data_i)
     ,.v_i(hdr_v_li)
     ,.ready_and_o(hdr_ready_and_lo)

     ,.data_o(pr_hdr_lo)
     ,.v_o(pr_hdr_v_lo)
     ,.ready_and_i(pr_hdr_ready_and_li)
     );

  // BedRock Burst Gearbox
  logic pr_data_ready_and_li;
  wire pr_data_v_lo = is_data & link_v_i;
  bp_me_burst_gearbox
    #(.bp_params_p(bp_params_p)
      ,.in_data_width_p(flit_width_p)
      ,.out_data_width_p(pr_data_width_p)
      ,.payload_width_p(pr_payload_width_p)
      )
    gearbox
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.msg_header_i(pr_hdr_lo[wh_pr_hdr_offset_p+:pr_hdr_width_p])
      ,.msg_header_v_i(pr_hdr_v_lo)
      ,.msg_header_ready_and_o(pr_hdr_ready_and_li)
      ,.msg_has_data_i(wh_has_data)
      ,.msg_data_i(link_data_i)
      ,.msg_data_v_i(pr_data_v_lo)
      ,.msg_data_ready_and_o(pr_data_ready_and_li)
      ,.msg_last_i(wh_last_data)

      ,.msg_header_o(pr_hdr_o)
      ,.msg_header_v_o(pr_hdr_v_o)
      ,.msg_header_ready_and_i(pr_hdr_ready_and_i)
      ,.msg_has_data_o(pr_has_data_o)
      ,.msg_data_o(pr_data_o)
      ,.msg_data_v_o(pr_data_v_o)
      ,.msg_data_ready_and_i(pr_data_ready_and_i)
      ,.msg_last_o(pr_last_o)
      );

  // Identifies which flits are header vs data flits
  bsg_wormhole_stream_control
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

  assign link_ready_and_o = is_hdr ? hdr_ready_and_lo : pr_data_ready_and_li;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wormhole_to_burst)

