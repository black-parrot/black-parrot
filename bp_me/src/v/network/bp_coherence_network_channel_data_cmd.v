/**
 *  Name:
 *    bp_coherence_network_channel_data_cmd.v
 *
 *  Description:
 *    LCE data_cmd in connects to P-port.
 *    LCE data_cmd out connects to N-port.
 *    CCE data_cmd out connects to S-port.
 */

module bp_coherence_network_channel_data_cmd
  import bp_common_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
    , parameter block_size_in_bits_p="inv"
    , parameter lce_assoc_p="inv"

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam cce_id_width_lp=`BSG_SAFE_CLOG2(num_cce_p)
    
    , localparam mesh_width_lp=`BSG_MAX(num_lce_p,num_cce_p)
    , localparam lg_mesh_width_lp=`BSG_SAFE_CLOG2(mesh_width_lp)

    , localparam x_cord_width_lp=`BSG_SAFE_CLOG2(mesh_width_lp)
    , localparam y_cord_width_lp=2

    , localparam bp_lce_data_cmd_width_lp =
      `bp_lce_data_cmd_width(num_lce_p,block_size_in_bits_p,lce_assoc_p)
    , localparam link_sif_width_lp =
      (bp_lce_data_cmd_width_lp+x_cord_width_lp+y_cord_width_lp)
  )
  (
    input clk_i
    , input reset_i

    // dest
    , output [num_lce_p-1:0][bp_lce_data_cmd_width_lp-1:0] lce_data_cmd_o
    , output [num_lce_p-1:0] lce_data_cmd_v_o
    , input  [num_lce_p-1:0] lce_data_cmd_ready_i

    // src
    , input  [num_cce_p-1:0][bp_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_i
    , input  [num_cce_p-1:0] cce_lce_data_cmd_v_i
    , output [num_cce_p-1:0] cce_lce_data_cmd_ready_o

    , input  [num_lce_p-1:0][bp_lce_data_cmd_width_lp-1:0] lce_lce_data_cmd_i
    , input  [num_lce_p-1:0] lce_lce_data_cmd_v_i
    , output [num_lce_p-1:0] lce_lce_data_cmd_ready_o
  );
  

  // bp_lce_data_cmd_s
  //
  `declare_bp_lce_data_cmd_s(num_lce_p,block_size_in_bits_p,lce_assoc_p);

  bp_lce_data_cmd_s [num_cce_p-1:0] cce_lce_data_cmd_in;
  bp_lce_data_cmd_s [num_lce_p-1:0] lce_lce_data_cmd_in;
  assign cce_lce_data_cmd_in = cce_lce_data_cmd_i;
  assign lce_lce_data_cmd_in = lce_lce_data_cmd_i;

  // link_sif
  //
  `declare_bsg_ready_and_link_sif_s(link_sif_width_lp,bp_lce_data_cmd_link_sif_s);

  bp_lce_data_cmd_link_sif_s [mesh_width_lp-1:0][S:P] link_in;
  bp_lce_data_cmd_link_sif_s [mesh_width_lp-1:0][S:P] link_out;

  // mesh_router
  //
  logic [mesh_width_lp-1:0][x_cord_width_lp-1:0] my_x;
  logic [mesh_width_lp-1:0][y_cord_width_lp-1:0] my_y;

  for (genvar i = 0; i < mesh_width_lp; i++) begin

    assign my_x[i] = x_cord_width_lp'(i);
    assign my_y[i] = y_cord_width_lp'(1);

    bsg_mesh_router_buffered #(
      .width_p(link_sif_width_lp)
      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.XY_order_p(0)
    ) router (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.link_i(link_in[i])
      ,.link_o(link_out[i])
  
      ,.my_x_i(my_x[i])
      ,.my_y_i(my_y[i])
    );

  end

  // stitch mesh together
  //
  for (genvar i = 0; i < mesh_width_lp; i++) begin
    if (i == 0) begin
      assign link_in[i][W] = '0;
      assign link_in[i][E] = link_out[i+1][W];
    end
    else if (i == mesh_width_lp-1) begin
      assign link_in[i][E] = '0;
      assign link_in[i][W] = link_out[i-1][E];
    end
    else begin
      assign link_in[i][W] = link_out[i-1][E];
      assign link_in[i][E] = link_out[i+1][W];
    end
  end

  // connect LCE
  //
  for (genvar i = 0; i < mesh_width_lp; i++) begin

    if (i < num_lce_p) begin

      assign link_in[i][P].ready_and_rev = lce_data_cmd_ready_i[i];
      assign link_in[i][P].data = '0;
      assign link_in[i][P].v = 1'b0;

      assign lce_data_cmd_v_o[i] = link_out[i][P].v;
      assign lce_data_cmd_o[i] =
        link_out[i][P].data[x_cord_width_lp+y_cord_width_lp+:bp_lce_data_cmd_width_lp];

      assign link_in[i][N].v = lce_lce_data_cmd_v_i[i];
      assign link_in[i][N].ready_and_rev = 1'b0;
      assign link_in[i][N].data = {lce_lce_data_cmd_in[i], my_y[i], lce_lce_data_cmd_in[i].dst_id};

      assign lce_lce_data_cmd_ready_o[i] = link_out[i][N].ready_and_rev;      
      
    end
    else begin
      assign link_in[i][P] = '0;
      assign link_in[i][N] = '0;
    end

  end

  // connect CCE 
  //
  for (genvar i = 0; i < mesh_width_lp; i++) begin
    if (i < num_cce_p) begin
      assign link_in[i][S].v = cce_lce_data_cmd_v_i[i];
      assign link_in[i][S].ready_and_rev = 1'b0;
      assign link_in[i][S].data = {cce_lce_data_cmd_in[i], my_y[i], cce_lce_data_cmd_in[i].dst_id};

      assign cce_lce_data_cmd_ready_o[i] = link_out[i][S].ready_and_rev;
    end
    else begin
      assign link_in[i][S] = '0;
    end
  end

endmodule
