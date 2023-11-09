/**
 *
 * Name:
 *   bp_me_wormhole_stream_control.sv
 *
 * Description:
 *   Handles flow control for a bsg_wormhole packet. Given a length of
 *   wormhole packet and a begin transaction signal, this module tracks which
 *   flits are header flits and which are data flits.
 *
 *   A bsg_wormhole packet is assumed to be laid out as:
 *   ----------------------------------------------------------------
 *   | data   | data  | data  | data  |  pad   pr_hdr    len  cord  |
 *   ----------------------------------------------------------------
 *   - header flits do not contain any data
 *   - the example above shows the entire header in a single flit, but it
 *     may require more than one wormhole link flits if pr_hdr width is
 *     greater than flit_width - cord_width - len_width.
 *     In general, a wormhole packet has one or more header flits and zero or
 *     more data flits.
 *
 *   For this module, all that is required is that the first header flit
 *   contains the wormhole message length, passed in as len_i.
 *
 */

`include "bsg_defines.sv"

module bp_me_wormhole_stream_control
 #(parameter `BSG_INV_PARAM(len_width_p)
   , parameter [len_width_p-1:0] `BSG_INV_PARAM(hdr_len_p)
   )
  (input                     clk_i
   , input                   reset_i

   , input [len_width_p-1:0] len_i
   , input                   link_accept_i

   , output logic            is_hdr_o
   , output logic            has_data_o
   , output logic            is_data_o
   , output logic            last_data_o
   );

  enum logic {e_hdr, e_data} state_n, state_r;
  wire is_hdr  = (state_r == e_hdr);
  wire is_data = (state_r == e_data);

  assign is_hdr_o  = is_hdr;
  assign is_data_o = is_data;

  // Wormhole len is defined to be (num_flits-1), add it back here
  wire [len_width_p-1:0] data_len_li = len_i - hdr_len_p + (len_width_p)'(1);

  // count from num_flits to zero, count_r_o==1 means last flit
  logic [len_width_p-1:0] hdr_flit_cnt, data_flit_cnt;

  // Sending last hdr flit (single header packets are always good to go)
  wire hdr_flit_last  = (hdr_flit_cnt  == (len_width_p)'(1)) || (hdr_len_p == 1);
  // Sending last data flit
  wire data_flit_last = (data_flit_cnt == (len_width_p)'(1));
  // All hdr flits are sent
  wire hdr_flit_done  = (hdr_flit_cnt  == '0);
  // All data flits are sent
  wire data_flit_done = (data_flit_cnt == '0);

  assign last_data_o = is_data & data_flit_last;

  // Set counter value when new packet hdr arrives
  // and all hdr flits are sent
  // (set data_flit_counter in same cycle)
  wire set_counter    = is_hdr & hdr_flit_done & link_accept_i;

  bsg_counter_set_down
   #(.width_p(len_width_p)
     ,.init_val_p(0)
     // allow set down same cycle to avoid bubble
     ,.set_and_down_exclusive_p(0)
     )
   hdr_flit_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(set_counter)
     ,.val_i(hdr_len_p)
     ,.down_i(is_hdr & link_accept_i)
     ,.count_r_o(hdr_flit_cnt)
     );

  bsg_counter_set_down
   #(.width_p(len_width_p)
     ,.init_val_p(0)
     // allow set down same cycle to avoid bubble
     ,.set_and_down_exclusive_p(0)
     )
   data_flit_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(set_counter)
     ,.val_i(data_len_li)
     ,.down_i(is_data & link_accept_i)
     ,.count_r_o(data_flit_cnt)
     );

  wire e_hdr_to_e_data;

  // Single hdr flit
  if (hdr_len_p == 1) begin
    // When wormhole link accept flit
    // and data flit non-zero
    // and is_hdr (avoid possible X-pessimism in simulation)
    //
    // (data_flit_done signal takes one cycle to be registered, not useful
    // in this case, extract data_len_li signal directly from hdr)
    assign e_hdr_to_e_data = (link_accept_i & is_hdr & data_len_li != '0);
    assign has_data_o = (data_len_li != '0);
  // Multiple hdr flits
  end else begin
    // When wormhole link accept flit
    // and sending last hdr flit
    // and data flit non-zero
    //
    // (data_len_li signal only meaningful in first hdr flit, not useful
    // in this case, use registered data_flit_done signal from data_flit_counter)
    assign e_hdr_to_e_data = (link_accept_i & hdr_flit_last & ~data_flit_done);
    assign has_data_o = ~data_flit_done;
  end

  // When wormhole link accept flit and sending last data flit
  wire e_data_to_e_hdr = link_accept_i & data_flit_last;

  always_comb begin
    case (state_r)
      e_hdr  : state_n = (e_hdr_to_e_data) ? e_data : e_hdr;
      e_data : state_n = (e_data_to_e_hdr) ? e_hdr : e_data;
      default: state_n = e_hdr;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (reset_i)
      state_r <= e_hdr;
    else
      state_r <= state_n;
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_wormhole_stream_control)

