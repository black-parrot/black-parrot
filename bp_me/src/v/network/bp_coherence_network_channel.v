/**
 * bp_coherence_network_channel
 *
 * This coherence network channel is a series of buffered mesh routers and
 * fifos used to relay messages between the LCE and CCE or LCE and LCE
 *
 * All y's defaulted to 1 since channel is 1 dim
 *
 * Assumes first node will always have a source and destination
 *
 * Since the stub_p plays a major role in node functionality but is a parameter value
 * and parameter values have to be constant at instantiation we explicitly lay
 * out each instantiation situation which is verbose but adds no extra logic
 * and shouldn't make it too much harder to follow
*/

`include "bsg_noc_links.vh"
`include "bsg_defines.v"


module bp_coherence_network_channel
  import bsg_noc_pkg::*;
  #(parameter packet_width_p=-1
    ,parameter num_src_p="inv"
    ,parameter num_dst_p="inv"
    ,parameter mesh_width_lp=`BSG_MAX(num_src_p,num_dst_p)
    ,parameter lg_mesh_width_lp=`BSG_SAFE_CLOG2(mesh_width_lp)
    ,parameter network_width_lp=(packet_width_p+lg_mesh_width_lp+1)
    ,parameter debug_p=0
    ,parameter dirs_lp=5
    ,parameter repeater_output_p={dirs_lp {1'b0}}
    ,parameter bsg_ready_then_link_sif_width_lp=`bsg_ready_then_link_sif_width(network_width_lp)
  )
  (
    input clk_i
    ,input reset_i

    //South port (src), helpful consumer (buffered inputs), ready->valid
    ,input [num_src_p-1:0][packet_width_p-1:0] src_data_i
    ,input [num_src_p-1:0] src_v_i
    ,output[num_src_p-1:0] src_ready_o

    //Proc port (dest), demanding producer, ready->valid
    ,output [num_dst_p-1:0][packet_width_p-1:0] dst_data_o
    ,output [num_dst_p-1:0] dst_v_o
    ,input  [num_dst_p-1:0] dst_ready_i
  );
  //Each message type has its own packet structure, and the router has its own format so we refactor
  //dst_id_i based around lg_mesh_width_lp instead of some lg_num_dst_p since bsg_mesh_router determines
  //x_dirs[i] = data_i[i][0+:x_cord_width_p]; and x_cord_width has to be centered around
  //the mesh width. Slightly inefficent but conforms with preexisting/proven ip
  logic [num_src_p-1:0][lg_mesh_width_lp-1:0] dst_id_i;

  always_comb begin
    int i;
    for (i = 0; i < num_src_p; i=i+1) begin
      dst_id_i[i] = src_data_i[i][packet_width_p-1 -: `BSG_SAFE_CLOG2(num_dst_p)];
    end
  end

  `declare_bsg_ready_then_link_sif_s(network_width_lp,bsg_ready_then_link_sif_s);
  //Similar to dst_id_i, even though Dirs is logic[2:0], the router links follow this [dirs_lp-1:0] format
  bsg_ready_then_link_sif_s [mesh_width_lp-1:0][dirs_lp-1:0] link_i_stitch;
  bsg_ready_then_link_sif_s [mesh_width_lp-1:0][dirs_lp-1:0] link_o_stitch;

  //South port
  logic [num_src_p-1:0][packet_width_p-1:0] src_data_i_stitch;
  logic [num_src_p-1:0] src_v_i_stitch, src_ready_o_stitch;
  logic [num_src_p-1:0][lg_mesh_width_lp-1:0] dst_id_i_stitch;
  //Proc port
  logic [num_dst_p-1:0][packet_width_p-1:0] dst_data_o_stitch;
  logic [num_dst_p-1:0] dst_v_o_stitch;//, dst_ready_i_stitch;

  //Intermediate stitching signals
  assign src_data_i_stitch = src_data_i;
  assign src_v_i_stitch  = src_v_i;
  assign src_ready_o     = src_ready_o_stitch;
  assign dst_id_i_stitch   = dst_id_i;

  assign dst_data_o    = dst_data_o_stitch;
  assign dst_v_o       = dst_v_o_stitch;

  //Create the mesh network
  genvar i;

  for (i = 0; i < mesh_width_lp; i=i+1) begin: rof

    //Initialize no valid input data for stubbed North port
    assign link_i_stitch[i][N].data = {network_width_lp {1'b0}} ;
    assign link_i_stitch[i][N].v  =  1'b0;
    assign link_i_stitch[i][N].ready_then_rev = 1'b0;

    //Initialize no valid input data for Proc port
    assign link_i_stitch[i][P].data = {network_width_lp {1'b0}} ;
    assign link_i_stitch[i][P].v  = 1'b0;

    //Stitching input data to the mesh
    if(i < num_src_p) begin: fi0
      //Format data on router to {packet, y, x}
      assign link_i_stitch[i][S].data = {src_data_i_stitch[i], 1'b1, dst_id_i_stitch[i]};
      assign link_i_stitch[i][S].v  = src_v_i_stitch[i];
      assign link_i_stitch[i][S].ready_then_rev = 1'b0;

      //Routing ready signal for input source
      assign src_ready_o_stitch[i] = link_o_stitch[i][S].ready_then_rev;
    end

    //First node instantiation scenarios
    if(i == 0) begin: fi2

      //Initialize no valid input data for stubbed West port
      assign link_i_stitch[i][W].data = {network_width_lp {1'b0}};
      assign link_i_stitch[i][W].v  = 1'b0;
      assign link_i_stitch[i][W].ready_then_rev = 1'b0;

      //If first node is also the last node, Stub north east and west
      if( i == mesh_width_lp -1) begin: fi3

        //Initialize no valid input data for stubbed East port
        assign link_i_stitch[i][E].data = {network_width_lp {1'b0}};
        assign link_i_stitch[i][E].v  = 1'b0;
        assign link_i_stitch[i][E].ready_then_rev = 1'b0;

        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b01110) //SNEWP -> _NEW_
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi3

      //If first node but not last node
      else begin: efi3

        //Inst and stitch a mesh router unit stub north and west
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b01010) //SNEWP -> _N_W_
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //efi3
    end //fi2

    //Remaining node instantiation scenarios
    else begin: efi2

      //Stitching the previous node's east port to this nodes west port
      assign link_i_stitch[i][W] = link_o_stitch[i-1][E];
      assign link_i_stitch[i-1][E] = link_o_stitch[i][W];

      //South, Proc, and East port used
      if((i < num_src_p) & (i < num_dst_p) & (i != (mesh_width_lp-1))) begin: fi4
        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b01000)  //SNEWP -> _N___
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi4

      //South, and Proc port used, stub East port
      else if((i < num_src_p) & (i < num_dst_p) & (i == (mesh_width_lp-1))) begin: fi5

        //Initialize no valid input data for stubbed East port
        assign link_i_stitch[i][E].data = {network_width_lp {1'b0}};
        assign link_i_stitch[i][E].v  = 1'b0;
        assign link_i_stitch[i][E].ready_then_rev = 1'b0;

        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b01100)  //SNEWP -> _NE__
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi5

      //South, and East port used, stub Proc port
      else if((i < num_src_p) & (i >= num_dst_p) & (i != (mesh_width_lp-1))) begin: fi6

        //Proc input already initialized to no valid input data by default

        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b01001) //SNEWP -> _N__P
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi6

      //South port used, stub East and Proc port
      else if((i < num_src_p) & (i >= num_dst_p) & (i == (mesh_width_lp-1))) begin: fi7

        //Proc input already initialized to no valid input data by default

        //Initialize no valid input data for stubbed East port
        assign link_i_stitch[i][E].data = {network_width_lp {1'b0}};
        assign link_i_stitch[i][E].v  = 1'b0;
        assign link_i_stitch[i][E].ready_then_rev = 1'b0;

        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b01101) //SNEWP -> _NE_P
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi7

      //Proc and East port used, stub South port
      else if((i >= num_src_p) & (i < num_dst_p) & (i != (mesh_width_lp-1))) begin: fi8

        //Initialize no valid input data for stubbed South port
        assign link_i_stitch[i][S].data = {network_width_lp {1'b0}};
        assign link_i_stitch[i][S].v  = 1'b0;
        assign link_i_stitch[i][S].ready_then_rev = 1'b0;

        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b11000)  //SNEWP -> SN___
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi8

      //Proc port used, stub South and East port
      else if((i >= num_src_p) & (i < num_dst_p) & (i == (mesh_width_lp-1))) begin: fi9

        //Initialize no valid input data for stubbed South port
        assign link_i_stitch[i][S].data = {network_width_lp {1'b0}};
        assign link_i_stitch[i][S].v  = 1'b0;
        assign link_i_stitch[i][S].ready_then_rev = 1'b0;

        //Initialize no valid input data for stubbed East port
        assign link_i_stitch[i][E].data = {network_width_lp {1'b0}};
        assign link_i_stitch[i][E].v  = 1'b0;
        assign link_i_stitch[i][E].ready_then_rev = 1'b0;

        //Inst and stitch a mesh router unit
        bsg_mesh_router_buffered  #(.width_p(network_width_lp)
                      ,.x_cord_width_p(lg_mesh_width_lp)
                      ,.y_cord_width_p(1)
                      ,.debug_p(debug_p)
                      ,.dirs_lp(5)
                      ,.stub_p(5'b11100) //SNEWP -> SNE__
                      ,.allow_S_to_EW_p(1)
                      ,.bsg_ready_and_link_sif_width_lp(bsg_ready_then_link_sif_width_lp)
                      ,.repeater_output_p(repeater_output_p)
                      )
          coherence_network_channel_node
          (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.link_i(link_i_stitch[i])
          ,.link_o(link_o_stitch[i])
          ,.my_x_i(i[lg_mesh_width_lp-1:0]) //Indexed to remove truncation warning
          ,.my_y_i(1'b1)
          );
      end //fi9
    end //efi2

    if (i < num_dst_p) begin
      assign dst_data_o_stitch[i] = link_o_stitch[i][P].data[(network_width_lp-1):(lg_mesh_width_lp+1)];
      assign dst_v_o_stitch[i] = link_o_stitch[i][P].v;
      assign link_i_stitch[i][P].ready_then_rev = dst_ready_i[i];
    end else begin
      assign link_i_stitch[i][P].ready_then_rev  = 1'b0;
    end

  end //rof
endmodule
