////////////////////////////////////////////////////////////////////////////////
//
// bsg_chip_io_complex
//
// This is the chip's main IO logic. This IO complex has 2 routers for forward
// packets (where the chip is acting as a master node) and reverse packets
// (where the chip is responding to another master node). The packets from both
// routers get merged via channel tunnels that then go into the DDR links.
//

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// **OUT OF DATE**
// BSG CHIP IO COMPLEX DATAPATH                                                                                                  //
//                                    +-----+                                         +-----+                                    //
//        +-----------------+         |  C  |       +-----------+                     |  C  |         +-----------------+        //
//        |                 |         |  H  |       |           |                     |  H  |         |                 |        //
//  /---  |  PREV UPSTREAM  | <--+    |  A  | <===> W  FWD RTR  E <=================> |  A  |    +--> |  NEXT UPSTREAM  |  ---\  //
//  \---  |    DDR LINK     |    |    |  N  |       |           |                     |  N  |    |    |    DDR LINK     |  ---/  //
//        |                 |    |    |  N  |       +-----P-----+                     |  N  |    |    |                 |        //
//        +-----------------+    +--- |  E  |             ^                           |  E  | ---+    +-----------------+        //
//                                    |  L  |             |       +-----------+       |  L  |                                    //
//        +-----------------+    +--> |     |             |       |           |       |     | <--+    +-----------------+        //
//        |                 |    |    |  T  | <=================> W  REV RTR  E <===> |  T  |    |    |                 |        //
//  ---\  | PREV DOWNSTREAM |    |    |  U  |             |       |           |       |  U  |    |    | NEXT DOWNSTREAM |  /---  //
//  ---/  |    DDR LINK     | ---+    |  N  |             |       +-----P-----+       |  N  |    +--- |    DDR LINK     |  \---  //
//        |                 |         |  N  |             |             ^             |  N  |         |                 |        //
//        +-----------------+         |  E  |             |             |             |  E  |         +-----------------+        //
//                                    |  L  |             |             |             |  L  |                                    //
//                                    +-----+             V             V             +-----+                                    //
//                                                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//
// Tag Reset Sequence
//
// We have 5 tag clients all required to get the io out of reset properly. It
// is important to follow the seqence:
//
//  1. Assert reset for all synchronous reset (ie. not the async_token_reset)
//    1a. You should set the router x and y at the same
//    1b. You should make sure all async_token_reset are low
//  time as you assert reset.
//  2. Assert all async_token_reset
//  3. Deassert all async_token_reset
//  4. Deassert all io up_link_reset*
//  5. Deassert all io down_link_reset
//  6. Deassert all core up_link_reset**
//  7. Deassert all core down_link_reset**
//  8. Deassert all routers reset
//
// Note: "all" means prev and next, however if there is nothing attached to the
// prev or next links, you should keep that link in reset.
//
// * - After you take the up links out of reset, there are some number of
// cycles for the comm link clocks to start generating. These comm link clocks
// are what the io_down_link_reset get's synchronized to so it may be required
// to wait a few cycles to make sure the clock start up.
//
// ** - The order of these shouldn't matter
//

module bsg_chip_io_complex

import bsg_tag_pkg::*;
import bsg_noc_pkg::*;
import bsg_wormhole_router_pkg::StrictX;

#(parameter num_router_groups_p = -1

, parameter link_width_p = -1
, parameter link_channel_width_p = -1
, parameter link_num_channels_p = -1
, parameter link_lg_fifo_depth_p = -1
, parameter link_lg_credit_to_token_decimation_p = -1

, parameter ct_width_p = -1
, parameter ct_num_in_p = -1
, parameter ct_remote_credits_p = -1
, parameter ct_use_pseudo_large_fifo_p = -1
, parameter ct_lg_credit_decimation_p = -1

, parameter int wh_cord_markers_pos_p[1:0] = '{-1, -1}
, parameter wh_len_width_p = -1
, parameter wh_cord_width_lp = wh_cord_markers_pos_p[1] - wh_cord_markers_pos_p[0]

, parameter bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(ct_width_p)
)

( input  core_clk_i
, input  io_clk_i

, input bsg_tag_s  prev_link_io_tag_lines_i
, input bsg_tag_s  prev_link_core_tag_lines_i
, input bsg_tag_s  prev_ct_core_tag_lines_i

, input bsg_tag_s  next_link_io_tag_lines_i
, input bsg_tag_s  next_link_core_tag_lines_i
, input bsg_tag_s  next_ct_core_tag_lines_i

, input bsg_tag_s [num_router_groups_p-1:0] rtr_core_tag_lines_i

// comm link connection to next chip
, input  [link_num_channels_p-1:0]                           ci_clk_i
, input  [link_num_channels_p-1:0]                           ci_v_i
, input  [link_num_channels_p-1:0][link_channel_width_p-1:0] ci_data_i
, output [link_num_channels_p-1:0]                           ci_tkn_o

, output [link_num_channels_p-1:0]                           co_clk_o
, output [link_num_channels_p-1:0]                           co_v_o
, output [link_num_channels_p-1:0][link_channel_width_p-1:0] co_data_o
, input  [link_num_channels_p-1:0]                           co_tkn_i

// comm link connection to prev chip
, input  [link_num_channels_p-1:0]                           ci2_clk_i
, input  [link_num_channels_p-1:0]                           ci2_v_i
, input  [link_num_channels_p-1:0][link_channel_width_p-1:0] ci2_data_i
, output [link_num_channels_p-1:0]                           ci2_tkn_o

, output [link_num_channels_p-1:0]                           co2_clk_o
, output [link_num_channels_p-1:0]                           co2_v_o
, output [link_num_channels_p-1:0][link_channel_width_p-1:0] co2_data_o
, input  [link_num_channels_p-1:0]                           co2_tkn_i

, input   [num_router_groups_p-1:0][ct_num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] rtr_links_i
, output  [num_router_groups_p-1:0][ct_num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] rtr_links_o

, output logic [num_router_groups_p-1:0]                       rtr_reset_o
, output logic [num_router_groups_p-1:0][wh_cord_width_lp-1:0] rtr_cord_o
);

  genvar i,j;

  typedef struct packed { 
      logic reset;
      logic [wh_cord_width_lp-1:0] cord;
  } rtr_core_tag_payload_s;

  rtr_core_tag_payload_s [num_router_groups_p-1:0] rtr_core_tag_data_lo;

  // declare the bsg_ready_and_link_sif_s struct
  `declare_bsg_ready_and_link_sif_s(ct_width_p, bsg_ready_and_link_sif_s);

  // forward wormhole router links (P leaves this module)
  bsg_ready_and_link_sif_s [num_router_groups_p-1:0][ct_num_in_p-1:0][E:P] rtr_links_li;
  bsg_ready_and_link_sif_s [num_router_groups_p-1:0][ct_num_in_p-1:0][E:P] rtr_links_lo;

  bsg_chip_io_complex_links_ct_fifo #(.link_width_p( link_width_p )
                                     ,.link_channel_width_p( link_channel_width_p )
                                     ,.link_num_channels_p( link_num_channels_p )
                                     ,.link_lg_fifo_depth_p( link_lg_fifo_depth_p )
                                     ,.link_lg_credit_to_token_decimation_p( link_lg_credit_to_token_decimation_p )
                                     ,.ct_width_p( ct_width_p )
                                     ,.ct_num_in_p( ct_num_in_p )
                                     ,.ct_remote_credits_p( ct_remote_credits_p )
                                     ,.ct_use_pseudo_large_fifo_p( ct_use_pseudo_large_fifo_p )
                                     ,.ct_lg_credit_decimation_p( ct_lg_credit_decimation_p )
                                     )
    prev
      (.core_clk_i( core_clk_i )
      ,.io_clk_i( io_clk_i )

      ,.link_io_tag_lines_i( prev_link_io_tag_lines_i )
      ,.link_core_tag_lines_i( prev_link_core_tag_lines_i )
      ,.ct_core_tag_lines_i( prev_ct_core_tag_lines_i )

      ,.ci_clk_i( ci2_clk_i )
      ,.ci_v_i( ci2_v_i )
      ,.ci_data_i( ci2_data_i )
      ,.ci_tkn_o( ci2_tkn_o )

      ,.co_clk_o( co2_clk_o )
      ,.co_v_o( co2_v_o )
      ,.co_data_o( co2_data_o )
      ,.co_tkn_i( co2_tkn_i )

      ,.links_i({ rtr_links_lo[0][1][W], rtr_links_lo[0][0][W] })
      ,.links_o({ rtr_links_li[0][1][W], rtr_links_li[0][0][W] })
      );

  for (j = 0; j < num_router_groups_p; j++)
    begin: rtr

      bsg_tag_client #(.width_p( $bits(rtr_core_tag_data_lo[j]) ), .default_p( 0 ))
        btc
          (.bsg_tag_i     ( rtr_core_tag_lines_i[j] )
          ,.recv_clk_i    ( core_clk_i )
          ,.recv_reset_i  ( 1'b0 )
          ,.recv_new_r_o  ()
          ,.recv_data_r_o ( rtr_core_tag_data_lo[j] )
          );

      assign rtr_reset_o[j] = rtr_core_tag_data_lo[j].reset;
      assign rtr_cord_o[j] = rtr_core_tag_data_lo[j].cord;

      for (i = 0; i < ct_num_in_p; i++)
        begin: ct

          bsg_wormhole_router_generalized #(.flit_width_p( ct_width_p )
                                           ,.dims_p( 1 )
                                           ,.cord_markers_pos_p( wh_cord_markers_pos_p )
                                           ,.routing_matrix_p( StrictX )
                                           ,.len_width_p( wh_len_width_p )
                                           )   
            rtr
              (.clk_i    ( core_clk_i )
              ,.reset_i  ( rtr_core_tag_data_lo[j].reset )
              ,.my_cord_i( rtr_core_tag_data_lo[j].cord )
              ,.link_i   ( rtr_links_li[j][i] )
              ,.link_o   ( rtr_links_lo[j][i] )
              );

          assign rtr_links_li[j][i][P] = rtr_links_i[j][i];
          assign rtr_links_o[j][i] = rtr_links_lo[j][i][P];

        end:ct
    end: rtr

  // Stitcher
  for (j = 1; j < num_router_groups_p-1; j++)
    begin
      for (i = 0; i < ct_num_in_p; i++)
        begin
          assign rtr_links_li[j-1][i][E] = rtr_links_lo[j][i][W];
          assign rtr_links_li[j][i][E]   = rtr_links_lo[j+1][i][W];
        end
    end

  bsg_chip_io_complex_links_ct_fifo #(.link_width_p( link_width_p )
                                     ,.link_channel_width_p( link_channel_width_p )
                                     ,.link_num_channels_p( link_num_channels_p )
                                     ,.link_lg_fifo_depth_p( link_lg_fifo_depth_p )
                                     ,.link_lg_credit_to_token_decimation_p( link_lg_credit_to_token_decimation_p )
                                     ,.ct_width_p( ct_width_p )
                                     ,.ct_num_in_p( ct_num_in_p )
                                     ,.ct_remote_credits_p( ct_remote_credits_p )
                                     ,.ct_use_pseudo_large_fifo_p( ct_use_pseudo_large_fifo_p )
                                     ,.ct_lg_credit_decimation_p( ct_lg_credit_decimation_p )
                                     )
    next
      (.core_clk_i( core_clk_i )
      ,.io_clk_i( io_clk_i )

      ,.link_io_tag_lines_i( next_link_io_tag_lines_i )
      ,.link_core_tag_lines_i( next_link_core_tag_lines_i )
      ,.ct_core_tag_lines_i( next_ct_core_tag_lines_i )

      ,.ci_clk_i( ci_clk_i )
      ,.ci_v_i( ci_v_i )
      ,.ci_data_i( ci_data_i )
      ,.ci_tkn_o( ci_tkn_o )

      ,.co_clk_o( co_clk_o )
      ,.co_v_o( co_v_o )
      ,.co_data_o( co_data_o )
      ,.co_tkn_i( co_tkn_i )

      ,.links_i({ rtr_links_lo[num_router_groups_p-1][1][E], rtr_links_lo[num_router_groups_p-1][0][E] })
      ,.links_o({ rtr_links_li[num_router_groups_p-1][1][E], rtr_links_li[num_router_groups_p-1][0][E] })
      );

endmodule



module bsg_chip_io_complex_links_ct_fifo

import bsg_tag_pkg::*;

#(parameter link_width_p = -1
, parameter link_channel_width_p = -1
, parameter link_num_channels_p = -1
, parameter link_lg_fifo_depth_p = -1
, parameter link_lg_credit_to_token_decimation_p = -1

, parameter ct_width_p = -1
, parameter ct_num_in_p = -1
, parameter ct_remote_credits_p = -1
, parameter ct_use_pseudo_large_fifo_p = -1
, parameter ct_lg_credit_decimation_p = -1

, parameter bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(ct_width_p)
)

( input  core_clk_i
, input  io_clk_i

, input bsg_tag_s  link_io_tag_lines_i
, input bsg_tag_s  link_core_tag_lines_i
, input bsg_tag_s  ct_core_tag_lines_i

, input  [link_num_channels_p-1:0]                           ci_clk_i
, input  [link_num_channels_p-1:0]                           ci_v_i
, input  [link_num_channels_p-1:0][link_channel_width_p-1:0] ci_data_i
, output [link_num_channels_p-1:0]                           ci_tkn_o

, output [link_num_channels_p-1:0]                           co_clk_o
, output [link_num_channels_p-1:0]                           co_v_o
, output [link_num_channels_p-1:0][link_channel_width_p-1:0] co_data_o
, input  [link_num_channels_p-1:0]                           co_tkn_i

, input  [ct_num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] links_i
, output [ct_num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] links_o
);

  genvar i;

  typedef struct packed { 
      logic up_link_reset;
      logic down_link_reset;
      logic async_token_reset;
  } link_io_tag_payload_s;

  typedef struct packed { 
      logic up_link_reset;
      logic down_link_reset;
  } link_core_tag_payload_s;

  typedef struct packed { 
      logic reset;
      logic fifo_reset;
  } ct_core_tag_payload_s;

  link_io_tag_payload_s   link_io_tag_data_lo;
  link_core_tag_payload_s link_core_tag_data_lo;
  ct_core_tag_payload_s   ct_core_tag_data_lo;

  logic                    link_v_lo;
  logic [link_width_p-1:0] link_data_lo;
  logic                    link_ready_lo;

  logic                    ct_multi_v_lo;
  logic [link_width_p-1:0] ct_multi_data_lo;
  logic                    ct_multi_yumi_lo;

  logic [ct_num_in_p-1:0]                 ct_fifo_valid_lo;
  logic [ct_num_in_p-1:0][ct_width_p-1:0] ct_fifo_data_lo;
  logic [ct_num_in_p-1:0]                 ct_fifo_yumi_li;

  logic [ct_num_in_p-1:0]                 ct_valid_lo;
  logic [ct_num_in_p-1:0][ct_width_p-1:0] ct_data_lo;
  logic [ct_num_in_p-1:0]                 ct_yumi_li;

  // declare the bsg_ready_and_link_sif_s struct
  `declare_bsg_ready_and_link_sif_s(ct_width_p, bsg_ready_and_link_sif_s);

  bsg_ready_and_link_sif_s [ct_num_in_p-1:0] links_cast_li;
  assign links_cast_li = links_i;

  bsg_ready_and_link_sif_s [ct_num_in_p-1:0] links_cast_lo;
  assign links_o = links_cast_lo;;

  bsg_tag_client #(.width_p( $bits(link_io_tag_data_lo) ), .default_p( 0 ))
    btc_link_io
      (.bsg_tag_i     ( link_io_tag_lines_i )
      ,.recv_clk_i    ( io_clk_i )
      ,.recv_reset_i  ( 1'b0 )
      ,.recv_new_r_o  ()
      ,.recv_data_r_o ( link_io_tag_data_lo )
      );

  bsg_tag_client #(.width_p( $bits(link_core_tag_data_lo) ), .default_p( 0 ))
    btc_link_core
      (.bsg_tag_i     ( link_core_tag_lines_i )
      ,.recv_clk_i    ( core_clk_i )
      ,.recv_reset_i  ( 1'b0 )
      ,.recv_new_r_o  ()
      ,.recv_data_r_o ( link_core_tag_data_lo )
      );

  bsg_tag_client #(.width_p( $bits(ct_core_tag_data_lo) ), .default_p( 0 ))
    btc_ct_core
      (.bsg_tag_i     ( ct_core_tag_lines_i )
      ,.recv_clk_i    ( core_clk_i )
      ,.recv_reset_i  ( 1'b0 )
      ,.recv_new_r_o  ()
      ,.recv_data_r_o ( ct_core_tag_data_lo )
      );

  // UPSTREAM LINK
  bsg_link_ddr_upstream #(.width_p( link_width_p )
                         ,.channel_width_p( link_channel_width_p )
                         ,.num_channels_p( link_num_channels_p )
                         ,.lg_fifo_depth_p( link_lg_fifo_depth_p )
                         ,.lg_credit_to_token_decimation_p( link_lg_credit_to_token_decimation_p )
                         )
    uplink
      (.core_clk_i        ( core_clk_i )
      ,.core_link_reset_i ( link_core_tag_data_lo.up_link_reset )

      ,.core_data_i  ( ct_multi_data_lo )
      ,.core_valid_i ( ct_multi_v_lo )
      ,.core_ready_o ( link_ready_lo )

      ,.io_clk_i            ( io_clk_i )
      ,.io_link_reset_i     ( link_io_tag_data_lo.up_link_reset )
      ,.async_token_reset_i ( link_io_tag_data_lo.async_token_reset )

      ,.io_clk_r_o   ( co_clk_o )
      ,.io_data_r_o  ( co_data_o )
      ,.io_valid_r_o ( co_v_o )
      ,.token_clk_i  ( co_tkn_i )
      );

  // DOWNSTREAM
  logic ci_link_reset_lo;

  bsg_sync_sync #(.width_p( 1 ))
    downlink_io_reset_sync_sync
      (.oclk_i      ( ci_clk_i )
      ,.iclk_data_i ( link_io_tag_data_lo.down_link_reset )
      ,.oclk_data_o ( ci_link_reset_lo )
      );

  bsg_link_ddr_downstream #(.width_p( link_width_p )
                           ,.channel_width_p( link_channel_width_p )
                           ,.num_channels_p( link_num_channels_p )
                           ,.lg_fifo_depth_p( link_lg_fifo_depth_p )
                           ,.lg_credit_to_token_decimation_p( link_lg_credit_to_token_decimation_p )
                           )
    downlink
      (.core_clk_i        ( core_clk_i )
      ,.core_link_reset_i ( link_core_tag_data_lo.down_link_reset )

      ,.io_link_reset_i ( ci_link_reset_lo )

      ,.core_data_o  ( link_data_lo )
      ,.core_valid_o ( link_v_lo )
      ,.core_yumi_i  ( ct_multi_yumi_lo )

      ,.io_clk_i       ( ci_clk_i )
      ,.io_data_i      ( ci_data_i )
      ,.io_valid_i     ( ci_v_i )
      ,.core_token_r_o ( ci_tkn_o )
      );

  // CHANNEL TUNNEL
  bsg_channel_tunnel #(.width_p( ct_width_p )
                      ,.num_in_p( ct_num_in_p )
                      ,.remote_credits_p( ct_remote_credits_p )
                      ,.use_pseudo_large_fifo_p( ct_use_pseudo_large_fifo_p )
                      ,.lg_credit_decimation_p( ct_lg_credit_decimation_p )
                      )
    tunnel
      (.clk_i   ( core_clk_i )
      ,.reset_i ( ct_core_tag_data_lo.reset )

      ,.multi_v_i     ( link_v_lo )
      ,.multi_data_i  ( link_data_lo )
      ,.multi_yumi_o  ( ct_multi_yumi_lo )

      ,.multi_v_o    ( ct_multi_v_lo )
      ,.multi_data_o ( ct_multi_data_lo )
      ,.multi_yumi_i ( ct_multi_v_lo & link_ready_lo )

      ,.data_i ( ct_fifo_data_lo )
      ,.v_i    ( ct_fifo_valid_lo )
      ,.yumi_o ( ct_fifo_yumi_li )

      ,.data_o ( ct_data_lo )
      ,.v_o    ( ct_valid_lo )
      ,.yumi_i ( ct_yumi_li )
      );

  for (i = 0; i < ct_num_in_p; i++)
    begin: ct

      bsg_two_fifo #(.width_p( ct_width_p ))
        tunnel_fifo
          (.clk_i( core_clk_i )
          ,.reset_i ( ct_core_tag_data_lo.fifo_reset )

          ,.ready_o ( links_cast_lo[i].ready_and_rev )
          ,.data_i  ( links_cast_li[i].data )
          ,.v_i     ( links_cast_li[i].v )

          ,.v_o    ( ct_fifo_valid_lo[i] )
          ,.data_o ( ct_fifo_data_lo[i] )
          ,.yumi_i ( ct_fifo_yumi_li[i] )
          );

      assign links_cast_lo[i].v = ct_valid_lo[i];
      assign links_cast_lo[i].data = ct_data_lo[i];
      assign ct_yumi_li[i] = ct_valid_lo[i] & links_cast_li[i].ready_and_rev;

    end: ct

endmodule


