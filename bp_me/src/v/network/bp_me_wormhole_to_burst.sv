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
   // Comes from external interpretation of pr_hdr_o, late
   , input bp_bedrock_msg_size_e        pr_hdr_size_i

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
  logic hdr_ready_and_lo;
  logic [(flit_width_p*hdr_len_lp)-1:0] pr_hdr_lo;
  logic [hdr_len_lp-1:0] sipo_v_lo;
  bsg_serial_in_parallel_out_passthrough
   #(.width_p(flit_width_p), .els_p(hdr_len_lp))
   hdr_sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(link_data_i)
     ,.v_i(is_hdr & link_v_i)
     ,.ready_and_o(hdr_ready_and_lo)

     ,.data_o(pr_hdr_lo)
     ,.v_o(sipo_v_lo)
     ,.ready_and_i(is_hdr & pr_hdr_ready_and_i)
     );
  assign pr_hdr_o = pr_hdr_lo[wh_pr_hdr_offset_p+:pr_hdr_width_p];
  assign pr_hdr_v_o = sipo_v_lo[hdr_len_lp-1];
  assign pr_has_data_o = wh_has_data;

  logic data_ready_and_lo;
  if (flit_width_p > pr_data_width_p)
    begin : narrow
      logic [flit_width_p/pr_data_width_p-1:0] piso_v_lo;
      logic piso_ready_and_lo;
      wire early_ack = pr_data_ready_and_i & pr_data_v_o & pr_last_o;
      bsg_parallel_in_serial_out_passthrough
       #(.width_p(pr_data_width_p), .els_p(flit_width_p/pr_data_width_p))
       pisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i | early_ack)
         ,.data_i(link_data_i)
         ,.v_i(is_data & link_v_i)
         ,.ready_and_o(piso_ready_and_lo)

         ,.data_o(pr_data_o)
         ,.v_o(piso_v_lo)
         ,.ready_and_i(pr_data_ready_and_i)
         );
      assign data_ready_and_lo = piso_ready_and_lo | early_ack;

      localparam max_len_lp = flit_width_p/pr_data_width_p;
      localparam flit_data_size_lp = `BSG_SAFE_CLOG2(flit_width_p>>3);
      localparam pr_data_size_lp = `BSG_SAFE_CLOG2(pr_data_width_p>>3);
      logic [max_len_lp-1:0] count_n, count_r;
      logic [10:0] test0, test1, test2, test3;
      assign test0 = (1'b1 << pr_hdr_size_i) << 3;
      assign test1 = (((1'b1 << pr_hdr_size_i) << 3) / pr_data_width_p);
      assign test2 = (1'b1 << max_len_lp-1);
      assign test3 =
        (pr_hdr_size_i >= flit_data_size_lp)
        ? (1'b1 << max_len_lp-1)
        : (pr_hdr_size_i <= pr_data_size_lp)
          ? (1'b1 << 1'b0)
          : (1'b1 << ((((1'b1 << pr_hdr_size_i) << 3) / pr_data_width_p) - 1'b1));
      //assign count_n = (1'b1 << ((((1'b1 << pr_hdr_size_i) << 3) / pr_data_width_p) - 1'b1));
      assign count_n = test3;
      //assign count_n = (pr_hdr_size_i < flit_data_size_lp) ? (1'b1 << (((1'b1 << pr_hdr_size_i) << 3) / pr_data_width_p) - 1'b1) : (1'b1 << max_len_lp-1);
      bsg_dff_en
       #(.width_p(max_len_lp))
       drain_match
        (.clk_i(clk_i)
         ,.en_i(pr_hdr_v_o)
         ,.data_i(count_n)
         ,.data_o(count_r)
         );
      //wire test_last = is_data & wh_last_data & (piso_ready_and_lo || |{count_r & piso_v_lo});
      //assign pr_last_o = is_data & wh_last_data & (piso_ready_and_lo || |{count_r & piso_v_lo});
      //assign pr_last_o = is_data & wh_last_data & (~|count_r || |{count_r & piso_v_lo});
      assign pr_last_o = is_data & wh_last_data & |{count_r & piso_v_lo};
      assign pr_data_v_o = |piso_v_lo;
      $error("flit_width_p > pr_data_width_p");
    end
  else if (flit_width_p < pr_data_width_p)
    begin : wide
      localparam flit_beats_lp = flit_width_p/pr_data_width_p;
      logic [(flit_width_p/pr_data_width_p)-1:0] sipo_v_lo;
      wire early_ack = pr_data_ready_and_i & pr_data_v_o & pr_last_o;
      bsg_serial_in_parallel_out_passthrough
       #(.width_p(flit_width_p), .els_p(pr_data_width_p/flit_width_p))
       sipop
        (.clk_i(clk_i)
         // Reset for less than flit size packets
         ,.reset_i(reset_i | early_ack)
         ,.data_i(link_data_i)
         ,.v_i(is_data & link_v_i)
         ,.ready_and_o(data_ready_and_lo)

         ,.data_o(pr_data_o)
         ,.v_o(sipo_v_lo)
         ,.ready_and_i(pr_data_ready_and_i)
         );
      // WH data is valid if we've filled the SIPO or if it's the last beat
      assign pr_data_v_o = (|sipo_v_lo & wh_last_data) || sipo_v_lo[flit_beats_lp-1];
      assign pr_last_o = is_data & wh_last_data;
      $error("flit_width_p < pr_data_width_p");
    end
  else
    begin
      assign pr_data_o = link_data_i;
      assign pr_data_v_o = link_v_i;
      assign link_ready_and_o = pr_data_ready_and_i;
    end

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

  assign link_ready_and_o = is_hdr ? hdr_ready_and_lo : data_ready_and_lo;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wormhole_to_burst)

