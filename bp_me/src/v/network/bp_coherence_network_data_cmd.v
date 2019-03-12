/**
 *  Name:
 *    bp_coherence_network_data_cmd.v
 *
 *  Description:
 *    LCE data_cmd in connects to P-port.
 *    LCE data_cmd out connects to N-port.
 *    CCE data_cmd out connects to S-port.
 */

module bp_coherence_network_data_cmd
  import bp_common_pkg::*;
  import bsg_noc_pkg::*;
  #(parameter num_lce_p="inv"
    , parameter num_cce_p="inv"
    , parameter block_size_in_bits_p="inv"
    , parameter lce_assoc_p="inv"
    
    , localparam mesh_width_lp=`BSG_MAX(num_lce_p,num_cce_p)
    , localparam lg_mesh_width_lp=`BSG_SAFE_CLOG2(mesh_width_lp)

    , localparam x_cord_width_lp=`BSG_SAFE_CLOG2(mesh_width_lp)
    , localparam y_cord_width_lp=2
  
    , localparam lce_x_start_idx_lp=0
    , localparam cce_x_start_idx_lp=0

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

  `declare_bsg_ready_and_link_sif_s(link_sif_width_lp,bp_lce_data_cmd_link_sif_s);
  
  bp_lce_data_cmd_link_sif_s [mesh_width_lp-1:0][S:W] link_in;
  bp_lce_data_cmd_link_sif_s [mesh_width_lp-1:0][S:W] link_out;
  bp_lce_data_cmd_link_sif_s [S:N][mesh_width_lp-1:0] ver_link_in;
  bp_lce_data_cmd_link_sif_s [S:N][mesh_width_lp-1:0] ver_link_out;

  // mesh_router
  //
  for (genvar i = 0; i < mesh_width_lp; i++) begin
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
  
      ,.my_x_i(x_cord_width_lp'(i))
      ,.my_y_i(y_cord_width_lp'(1))
    );

    assign link_in[i][P] = '0;
    assign link_in[i]
  end

  // mesh_stitch
  //
  bsg_mesh_stitch #(
    .width_p(link_sif_width_lp)
    ,.x_max_p(mesh_width_lp)
    ,.y_max_p(1)
  ) stitch (
    .outs_i(link_out)
    ,.ins_o(link_in)
    ,.hor_i('0)
    ,.hor_o()
    ,.ver_i(ver_link_in)
    ,.ver_o(ver_link_out)
  );



  // synopsys translate_off
  initial begin
    assert( < mesh_width_lp) else $error("LCE x cord out of range.");
  end
  // synopsys translate_on



endmodule
