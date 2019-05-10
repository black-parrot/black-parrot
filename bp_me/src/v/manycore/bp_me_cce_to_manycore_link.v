/**
 *  Name:
 *    bp_me_cce_to_manycore_link.v
 *
 *  Description:
 *    This is a bridge module between CCE and manycore network.
 *    It connects to mem interface of CCE. It handles cached and uncached
 *    memory requests. Manycore and CCE are in different clock domain.
 *
 */

`include "bsg_manycore_packet.vh"

module bp_me_cce_to_manycore_link
  import bp_common_pkg::*;
  #(parameter link_data_width_p="inv"
    , parameter link_addr_width_p="inv" // in words
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter paddr_width_p="inv" // risc-v physical address 56-bit.
    , parameter num_lce_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter block_size_in_bits_p="inv"

    , parameter fifo_els_p=16
    , parameter max_out_credits_p=16
    , parameter freeze_init_p=1
 
    , localparam link_mask_width_lp=(link_data_width_p>>3)

    , localparam link_sif_width_lp=
      `bsg_manycore_link_sif_width(link_addr_width_p,link_data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)

    , localparam mem_resp_width_lp=
      `bp_mem_cce_resp_width(paddr_width_p,num_lce_p,lce_assoc_p)
    , localparam mem_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
    , localparam mem_cmd_width_lp=
      `bp_cce_mem_cmd_width(paddr_width_p,num_lce_p,lce_assoc_p)
    , localparam mem_data_cmd_width_lp=
      `bp_cce_mem_data_cmd_width(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
  )
  (
    input link_clk_i
    , input bp_clk_i
    , input async_reset_i

    // manycore side
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
    
    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o
   
    // bp side
    , input [mem_cmd_width_lp-1:0] mem_cmd_i
    , input mem_cmd_v_i
    , output logic mem_cmd_yumi_o

    , input [mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    , input mem_data_cmd_v_i
    , output logic mem_data_cmd_yumi_o

    , output logic [mem_resp_width_lp-1:0] mem_resp_o
    , output logic mem_resp_v_o
    , input mem_resp_ready_i

    , output logic [mem_data_resp_width_lp-1:0] mem_data_resp_o
    , output logic mem_data_resp_v_o
    , input  mem_data_resp_ready_i

    , output logic [link_addr_width_p-2:0] config_addr_o
    , output logic [link_data_width_p-1:0] config_data_o
    , output logic config_v_o
    , output logic config_w_o
    , input config_ready_i

    , input [link_data_width_p-1:0] config_data_i
    , input config_v_i
    , output logic config_ready_o

    , output logic reset_o
    , output logic freeze_o
  );

  // synchronize reset signal
  //
  logic link_reset_r;
  logic bp_reset_r;

  bsg_sync_sync #(
    .width_p(1)
  ) link_reset_sync (
    .oclk_i(link_clk_i)
    ,.iclk_data_i(async_reset_i)
    ,.oclk_data_o(link_reset_r)
  );

  bsg_sync_sync #(
    .width_p(1)
  ) bp_reset_sync (
    .oclk_i(bp_clk_i)
    ,.iclk_data_i(async_reset_i)
    ,.oclk_data_o(bp_reset_r)
  );

  // declare some structs
  //
  `declare_bsg_manycore_link_sif_s(link_addr_width_p,link_data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);
  `declare_bsg_manycore_packet_s(link_addr_width_p,link_data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);

  // link_async_buffer
  // we are crossing clock domain from manycore to black-parrot.
  //
  bsg_manycore_link_sif_s cce_link_sif_li;
  bsg_manycore_link_sif_s cce_link_sif_lo;
  
  bsg_manycore_link_sif_async_buffer #(
    .addr_width_p(link_addr_width_p)
    ,.data_width_p(link_data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.fifo_els_p(4)
  ) link_sif_async_buf (
    .L_clk_i(link_clk_i)
    ,.L_reset_i(link_reset_r)
    ,.L_link_sif_i(link_sif_i)
    ,.L_link_sif_o(link_sif_o)

    ,.R_clk_i(bp_clk_i)
    ,.R_reset_i(bp_reset_r)
    ,.R_link_sif_i(cce_link_sif_li)
    ,.R_link_sif_o(cce_link_sif_lo)
  );  

  // endpoint_standard
  //

  logic ep_in_v_lo;
  logic ep_in_yumi_li;
  logic [link_data_width_p-1:0] ep_in_data_lo;
  logic [link_mask_width_lp-1:0] ep_in_mask_lo;
  logic [link_addr_width_p-1:0] ep_in_addr_lo;
  logic ep_in_we_lo;

  logic ep_out_v_li;
  bsg_manycore_packet_s ep_out_packet_li;
  logic ep_out_ready_lo;
    
  logic [link_data_width_p-1:0] ep_returned_data_lo;
  logic ep_returned_v_lo;
  logic ep_returned_yumi_li;

  logic ep_returning_v_li;
  logic [link_data_width_p-1:0] ep_returning_data_li;
  
  logic [$clog2(max_out_credits_p+1)-1:0] ep_out_credits;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(link_data_width_p)
    ,.addr_width_p(link_addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.fifo_els_p(fifo_els_p)
    ,.max_out_credits_p(max_out_credits_p)
  ) endpoint_standard (
    .clk_i(bp_clk_i)
    ,.reset_i(bp_reset_r)

    ,.link_sif_i(cce_link_sif_lo)
    ,.link_sif_o(cce_link_sif_li)
   
    // outbound request 
    ,.out_v_i(ep_out_v_li)
    ,.out_packet_i(ep_out_packet_li)
    ,.out_ready_o(ep_out_ready_lo)
  
    // inbound response
    ,.returned_data_r_o(ep_returned_data_lo)
    ,.returned_load_id_r_o()
    ,.returned_v_r_o(ep_returned_v_lo)
    ,.returned_yumi_i(ep_returned_yumi_li)
    ,.returned_fifo_full_o()

    // inbound request
    ,.in_v_o(ep_in_v_lo)
    ,.in_yumi_i(ep_in_yumi_li)
    ,.in_data_o(ep_in_data_lo)
    ,.in_mask_o(ep_in_mask_lo)
    ,.in_addr_o(ep_in_addr_lo)
    ,.in_we_o(ep_in_we_lo)
    ,.in_src_x_cord_o()
    ,.in_src_y_cord_o()

    // outbound response
    ,.returning_data_i(ep_returning_data_li)
    ,.returning_v_i(ep_returning_v_li)

    ,.out_credits_o(ep_out_credits)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );

  logic credit_left;
  assign credit_left = (|ep_out_credits); // make sure that credit counter does not underflow!

  // rx module
  //
  bsg_manycore_packet_s rx_pkt;
  logic rx_pkt_v;
  logic rx_pkt_yumi;

  bp_me_cce_to_manycore_link_rx #(
    .link_addr_width_p(link_addr_width_p)
    ,.link_data_width_p(link_data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
  
    ,.paddr_width_p(paddr_width_p)
    ,.num_lce_p(num_lce_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.block_size_in_bits_p(block_size_in_bits_p)
  ) rx (
    .clk_i(bp_clk_i)
    ,.reset_i(bp_reset_r)

    ,.mem_cmd_i(mem_cmd_i)
    ,.mem_cmd_v_i(mem_cmd_v_i)
    ,.mem_cmd_yumi_o(mem_cmd_yumi_o)

    ,.mem_data_resp_o(mem_data_resp_o)
    ,.mem_data_resp_v_o(mem_data_resp_v_o)
    ,.mem_data_resp_ready_i(mem_data_resp_ready_i)

    ,.rx_pkt_o(rx_pkt)
    ,.rx_pkt_v_o(rx_pkt_v)
    ,.rx_pkt_yumi_i(rx_pkt_yumi)

    ,.returned_data_i(ep_returned_data_lo)
    ,.returned_yumi_o(ep_returned_yumi_li)
    ,.returned_v_i(ep_returned_v_lo)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  ); 

  // tx module
  //
  bsg_manycore_packet_s tx_pkt;
  logic tx_pkt_v;
  logic tx_pkt_yumi;

  bp_me_cce_to_manycore_link_tx #(
    .link_addr_width_p(link_addr_width_p)
    ,.link_data_width_p(link_data_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.load_id_width_p(load_id_width_p)
  
    ,.paddr_width_p(paddr_width_p)
    ,.num_lce_p(num_lce_p)
    ,.lce_assoc_p(lce_assoc_p)
    ,.block_size_in_bits_p(block_size_in_bits_p)
  ) tx (
    .clk_i(bp_clk_i)
    ,.reset_i(bp_reset_r)

    ,.mem_data_cmd_i(mem_data_cmd_i)
    ,.mem_data_cmd_v_i(mem_data_cmd_v_i)
    ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_o)

    ,.mem_resp_o(mem_resp_o)
    ,.mem_resp_v_o(mem_resp_v_o)
    ,.mem_resp_ready_i(mem_resp_ready_i)
    
    ,.tx_pkt_o(tx_pkt)
    ,.tx_pkt_v_o(tx_pkt_v)
    ,.tx_pkt_yumi_i(tx_pkt_yumi)

    ,.my_x_i(my_x_i)
    ,.my_y_i(my_y_i)
  );

  // manycore pkt arbiter
  //
  always_comb begin
    rx_pkt_yumi = 1'b0;
    tx_pkt_yumi = 1'b0;

    if (rx_pkt_v) begin
      ep_out_v_li = credit_left;
      ep_out_packet_li = rx_pkt;
      rx_pkt_yumi = credit_left & ep_out_ready_lo;
    end
    else begin
      ep_out_v_li = tx_pkt_v & credit_left;
      ep_out_packet_li = tx_pkt;
      tx_pkt_yumi = tx_pkt_v & credit_left & ep_out_ready_lo;
    end
  end


  // black-parrot config interface
  //
  bp_me_cce_to_manycore_link_config #(
    .link_data_width_p(link_data_width_p)
    ,.link_addr_width_p(link_addr_width_p)
    ,.freeze_init_p(freeze_init_p)
  ) config_inst (
    .clk_i(bp_clk_i)
    ,.reset_i(bp_reset_r)
  
    // black-parrot side
    ,.reset_o(reset_o)
    ,.freeze_o(freeze_o)

    ,.config_addr_o(config_addr_o)
    ,.config_data_o(config_data_o)
    ,.config_v_o(config_v_o)
    ,.config_w_o(config_w_o)
    ,.config_ready_i(config_ready_i)

    ,.config_data_i(config_data_i)
    ,.config_v_i(config_v_i)
    ,.config_ready_o(config_ready_o)    

    // manycore side
    ,.v_i(ep_in_v_lo)
    ,.data_i(ep_in_data_lo)
    ,.mask_i(ep_in_mask_lo)
    ,.addr_i(ep_in_addr_lo)
    ,.we_i(ep_in_we_lo)
    ,.yumi_o(ep_in_yumi_li)

    ,.data_o(ep_returning_data_li)
    ,.v_o(ep_returning_v_li)
  );

endmodule
