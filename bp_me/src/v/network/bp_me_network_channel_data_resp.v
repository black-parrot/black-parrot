/**
 *  Name:
 *    bp_me_network_channel_data_resp.v
 *
 *  Description:
 *    This channel uses bsg_wormhole_router.
 *
 *    LCE connects to N port (src).
 *    CCE connects to P port (dest). 
 *
 *      I$     D$     I$     D$
 *      |      |      |      |
 *      /\_____/\_____/\_____/\
 *      \/     \/     \/     \/
 *     /      / 
 *     CCE   CCE
 */

module bp_me_network_channel_data_resp 
  import bp_common_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
    , parameter paddr_width_p="inv"
    , parameter block_size_in_bits_p="inv"
    
    , parameter max_num_flit_p="inv"

    , localparam num_router_lp=`BSG_MAX(num_lce_p,num_cce_p)
    , localparam x_cord_width_lp=`BSG_SAFE_CLOG2(num_router_lp)
    , localparam y_cord_width_lp=1

    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p,num_lce_p,paddr_width_p,block_size_in_bits_p)

    , localparam len_width_lp=`BSG_SAFE_CLOG2(max_num_flit_p)
    , localparam max_payload_width_lp=lce_cce_data_resp_width_lp
    , localparam max_packet_width_lp=
      (x_cord_width_lp+y_cord_width_lp+len_width_lp+max_payload_width_lp)
    , localparam router_data_width_lp=
      (max_packet_width_lp/max_num_flit_p)+((max_packet_width_lp%max_num_flit_p) == 0 ? 0 : 1)
    , localparam payload_offset_lp=(x_cord_width_lp+y_cord_width_lp+len_width_lp)
  )
  (
    input clk_i
    , input reset_i

    // src
    , input  [num_lce_p-1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_i
    , input  [num_lce_p-1:0] lce_data_resp_v_i
    , output logic [num_lce_p-1:0] lce_data_resp_ready_o

    // dest
    , output logic [num_cce_p-1:0][lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
    , output logic [num_cce_p-1:0] lce_data_resp_v_o
    , input  [num_cce_p-1:0] lce_data_resp_ready_i
  );


  // router links
  //
  logic [num_router_lp-1:0][S:P] valid_li, ready_lo;
  logic [num_router_lp-1:0][S:P][router_data_width_lp-1:0] data_li;   

  logic [num_router_lp-1:0][S:P] valid_lo, ready_li;
  logic [num_router_lp-1:0][S:P][router_data_width_lp-1:0] data_lo;   

  logic [num_router_lp-1:0][x_cord_width_lp-1:0] local_x;
  logic [num_router_lp-1:0][y_cord_width_lp-1:0] local_y;
  logic [num_router_lp-1:0][S:P] stub_in;
  logic [num_router_lp-1:0][S:P] stub_out;

  for (genvar i = 0; i < num_router_lp; i++) begin: router

    assign local_x[i] = x_cord_width_lp'(i);
    assign local_y[i] = y_cord_width_lp'(0);
    
    assign stub_in[i][W] = (i == 0) ? 1'b1 : 1'b0;
    assign stub_out[i][W] = (i == 0) ? 1'b1 : 1'b0;
    assign stub_in[i][E] = (i == num_router_lp-1) ? 1'b1 : 1'b0;
    assign stub_out[i][E] = (i == num_router_lp-1) ? 1'b1 : 1'b0;
    assign stub_in[i][S] = 1'b1;
    assign stub_out[i][S] = 1'b1;
    assign stub_in[i][N] = (i < num_lce_p) ? 1'b0 : 1'b1;
    assign stub_out[i][N] = 1'b1;
    assign stub_in[i][P] = 1'b1;
    assign stub_out[i][P] = (i < num_cce_p) ? 1'b0 : 1'b1;

    bsg_wormhole_router #(
      .width_p(router_data_width_lp)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.len_width_p(len_width_lp)
      ,.enable_2d_routing_p(1)
      ,.enable_yx_routing_p(1)
      ,.header_on_lsb_p(1)
      ,.stub_in_p(stub_in[i])
      ,.stub_out_p(stub_out[i])
    ) router (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.local_x_cord_i(local_x[i])
      ,.local_y_cord_i(local_y[i])

      ,.valid_i(valid_li[i])
      ,.data_i(data_li[i])
      ,.ready_o(ready_lo[i])

      ,.valid_o(valid_lo[i])
      ,.data_o(data_lo[i])
      ,.ready_i(ready_li[i])
    );

  end

  // stitch router links
  //
  for (genvar i = 0; i < num_router_lp; i++) begin
    if (i != 0) begin
      assign valid_li[i][W] = valid_lo[i-1][E];
      assign ready_li[i][W] = ready_lo[i-1][E];
      assign data_li[i][W] = data_lo[i-1][E];
    end

    if (i != num_router_lp) begin
      assign valid_li[i][E] = valid_lo[i+1][W];
      assign ready_li[i][E] = ready_lo[i+1][W];
      assign data_li[i][E] = data_lo[i+1][W];
    end
  end

  // packet encode
  //
  logic [num_lce_p-1:0][max_packet_width_lp-1:0] lce_packet;

  for (genvar i = 0; i < num_lce_p; i++) begin
    bp_me_network_pkt_encode_data_resp #(
      .num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.block_size_in_bits_p(block_size_in_bits_p)
      ,.max_num_flits_p(max_num_flits_p)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) pkt_encode (
      .payload_i(lce_data_resp_i[i])
      ,.packet_o(lce_packet[i])
    );

  end

  // input adapter
  //
  for (genvar i = 0; i < num_lce_p; i++) begin
    bsg_wormhole_router_adapter_in #(
      .max_num_flit_p(max_num_flit_p)
      ,.max_payload_width_p(max_payload_width_lp)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) adapter_in (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i(lce_packet[i])
      ,.v_i(lce_data_resp_v_i[i])
      ,.ready_o(lce_data_resp_ready_o[i])

      ,.data_o(data_li[i][N])
      ,.v_o(valid_li[i][N])
      ,.ready_i(ready_lo[i][N])
    ); 
  end

  // output adapter
  //
  logic [num_lce_p-1:0][max_packet_width_lp-1:0] cce_packet;

  for (genvar i = 0; i < num_cce_p; i++) begin
    bsg_wormhole_router_adapter_out #(
      .max_num_flit_p(max_num_flit_p)
      ,.max_payload_width_p(max_payload_width_lp)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
    ) adapter_out (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_i(data_lo[i][P])
      ,.v_i(valid_lo[i][P])
      ,.ready_o(ready_li[i][P])

      ,.data_o(cce_packet[i])
      ,.v_o(lce_data_resp_v_o[i])
      ,.ready_i(lce_data_resp_ready_i[i])
    );

    assign lce_data_resp_o[i] = cce_packet[i][payload_offset_lp+:max_payload_width_lp];

  end

endmodule
