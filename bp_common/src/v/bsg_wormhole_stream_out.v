
`include "bsg_defines.v"

//
// Converts a wormhole router stream into a higher level protocol without
//   deserializing the data. This module can be used for converting various 
//   DMA formats to wormhole flits efficently and with minimal buffering. 
//   It can also be used to forward data between wormholes on different 
//   networks, or to convert between multiple protocol formats.
//
// Example use cases:
//   - bsg_cache {dma_pkt, data/v/yumi} format <-> wormhole
//   - SRAM read/write <-> bsg_wormhole_stream_in/out <-> Wormhole Network
//   - Wide Network <-> bsg_wormhole_stream_in/out <-> Narrow Network
//
// Assumptions:
//  Usage of this module requires correctly formed wormhole headers. The length
//    field of the wormhole message determines how many protocol data beats are
//    expected (some multiple or divisor of the flit_width). We expect most
//    link and protocol data widths to be powers of 2 (32, 64, 512), so this
//    length restriction is lenient.
//
//   - data width is a multiple of flit width (would be easy to add support)
//   - header width is a multiple of flit width  (would be more challenging)
//     - header width == wormhole header width + protocol header width
//   - wormhole packets are laid out like the following:
//   ---------------------------------------------------------------
//   | data   | data  | data  | data  | protocol info | len   cord |
//   ---------------------------------------------------------------
//   - header flits do not contain any data
//
//  Header will arrive at or before data and either can be acked at any time.
//    Typical users of this module will simply ack the header to learn the 
//    protocol information of the impending transaction, begin the transaction,
//    and then forward or accept all of the data serially.
//
module bsg_wormhole_stream_out
 #(// The wormhole router protocol information
   // flit_width_p: number of physical data wires between links
   // cord_width_p: the width of the {y,x} coordinate of the destination
   // len_width_p : the width of the length field, denoting #flits+1
   // cid_width   : the width of the concentrator id of the destination
   // Default to 0 for cord and cid, so that this module can be used either
   //   for concentrator or router
   parameter flit_width_p      = "inv"
   , parameter cord_width_p    = 0
   , parameter len_width_p     = "inv"
   , parameter cid_width_p     = 0

   // Higher level protocol information
   , parameter pr_hdr_width_p  = "inv"
   , parameter pr_data_width_p = "inv"
   , parameter pr_len_width_p  = "inv"

   // Size of the wormhole header + the protocol header. The data starts afterwards.
   // Users may set this directly rather than relying on the protocol header derived default
   , parameter hdr_width_p = cord_width_p + len_width_p + cid_width_p + pr_hdr_width_p
   )
  (input                          clk_i
   , input                        reset_i

   // The output of a wormhole network
   , input [flit_width_p-1:0]     link_data_i
   , input                        link_v_i
   , output                       link_ready_and_o

   // The wormhole and protocol header information
   , output [hdr_width_p-1:0]     hdr_o
   , output                       hdr_v_o
   , input                        hdr_ready_and_i
   // number of protocol message data in arriving wormhole message
   // arrives late when hdr_v_o & hdr_ready_and_i
   // value is len-1 (i.e., zero based)
   , input [pr_len_width_p-1:0]   pr_data_beats_i

   // The protocol data information
   , output [pr_data_width_p-1:0] data_o
   , output                       data_v_o
   , input                        data_ready_and_i
   );

  wire is_hdr, is_data;
  
  localparam [len_width_p-1:0] hdr_len_lp = `BSG_CDIV(hdr_width_p, flit_width_p);

  logic hdr_v_li, hdr_ready_lo;

  // Aggregate flits until we have a full header-worth of data, then let the
  //   client process it
  assign hdr_v_li = is_hdr & link_v_i;
  bsg_serial_in_parallel_out_passthrough
   #(.width_p(flit_width_p)
     ,.els_p(hdr_len_lp)
     )
   hdr_sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(link_data_i)
     ,.v_i(hdr_v_li)
     ,.ready_and_o(hdr_ready_lo)

     ,.data_o(hdr_o)
     ,.v_o(hdr_v_o)
     ,.ready_and_i(hdr_ready_and_i)
     );

  logic data_v_li, data_ready_lo;
  assign data_v_li = is_data & link_v_i;
  // Protocol data is less than a single flit-sized. We accept a large
  //   wormhole flit, then let the client process it piecemeal
  if (flit_width_p > pr_data_width_p)
    begin : narrow
      // flit_width_p > pr_data_width_p -> multiple protocol data per link flit
      // and it is possible that last link flit is not completely filled with valid
      // protocol data.

      // number of protocol data per full link flit
      localparam [len_width_p-1:0] max_els_lp = `BSG_CDIV(flit_width_p, pr_data_width_p);
      localparam lg_max_els_lp = `BSG_SAFE_CLOG2(max_els_lp);
      // PISO len_i is zero-based, i.e., input is len-1
      localparam [lg_max_els_lp-1:0] piso_full_len_lp = max_els_lp - 1;

      // PISO inputs
      logic piso_first_lo;
      logic [lg_max_els_lp-1:0] piso_len_li;

      // count of protocol data packets to consume after current
      // set late when hdr_v_o & hdr_ready_i
      // set value is provided by consumer, derived from output header
      logic [pr_len_width_p-1:0] pr_data_cnt;
      wire pr_data_consumed = (pr_data_cnt == '0);
      bsg_counter_set_down
       #(.width_p(pr_len_width_p)
         ,.init_val_p('0)
         ,.set_and_down_exclusive_p(0)
         )
       pr_data_counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.set_i(hdr_v_o & hdr_ready_and_i)
         ,.val_i(pr_data_beats_i)
         ,.down_i(data_v_o & data_ready_and_i & ~pr_data_consumed)
         ,.count_r_o(pr_data_cnt)
         );

      // for each PISO transaction, provide number of protocol data to expect
      assign piso_len_li = (pr_data_cnt >= piso_full_len_lp)
                           ? piso_full_len_lp
                           : lg_max_els_lp'(pr_data_cnt);

      bsg_parallel_in_serial_out_passthrough_dynamic
       #(.width_p(pr_data_width_p)
         ,.max_els_p(max_els_lp)
         )
       data_piso
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(link_data_i)
         ,.v_i(data_v_li)
         ,.ready_and_o(data_ready_lo)

         ,.data_o(data_o)
         ,.v_o(data_v_o)
         ,.ready_and_i(data_ready_and_i)

         ,.first_o(piso_first_lo)
         // must be presented when ready_and_i & first_o
         ,.len_i(piso_len_li)
         );
    end
  else
    // Protocol data is 1 or multiple flit-sized. We aggregate wormhole data 
    //   until we have a full protocol data and then let the client process it
    begin : wide
      localparam [len_width_p-1:0] data_len_lp = `BSG_CDIV(pr_data_width_p, flit_width_p);
      bsg_serial_in_parallel_out_passthrough
       #(.width_p(flit_width_p)
         ,.els_p(data_len_lp)
         )
       data_sipo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(link_data_i)
         ,.v_i(data_v_li)
         ,.ready_and_o(data_ready_lo)

         ,.data_o(data_o)
         ,.v_o(data_v_o)
         ,.ready_and_i(data_ready_and_i)
         );
    end

  // Identifies which flits are header vs data flits
  bsg_wormhole_stream_control
   #(.len_width_p(len_width_p)
     ,.hdr_len_p(hdr_len_lp)
     )
   stream_control
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.len_i(link_data_i[cord_width_p+:len_width_p])
     ,.link_accept_i(link_ready_and_o & link_v_i)

     ,.is_hdr_o(is_hdr)
     ,.is_data_o(is_data)
     );

  assign link_ready_and_o = is_hdr ? hdr_ready_lo : data_ready_lo;

  //synopsys translate_off
  if (hdr_width_p % flit_width_p != 0)
    $fatal("Header width: %d must be multiple of flit width: %d", hdr_width_p, flit_width_p);

  if ((pr_data_width_p % flit_width_p != 0) && (flit_width_p % pr_data_width_p != 0))
    $fatal("Protocol data width: %d must be multiple of flit width: %d", pr_data_width_p, flit_width_p);
  //synopsys translate_on

endmodule

