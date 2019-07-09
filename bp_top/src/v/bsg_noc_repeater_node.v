//
// This module instantiates num_nodes_p two-element-fifos in chains
// It supports multiple bsg_noc_links in parallel
//
// Insert this module into long routings on chip, which can become critical path
//
// Node that side_A_reset_i signal shoule be close to side A
// If reset happens to be close to side B, please swap side A and side B connection, 
// since side A and side B are symmetric, functionality will not be affected.
//

module bsg_noc_repeater_node

#(parameter width_p = -1
, parameter num_in_p = 1
, parameter num_nodes_p = 0
, parameter bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)
)

( input  clk_i
, input  side_A_reset_i

, input  [num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] side_A_links_i
, output [num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] side_A_links_o

, input  [num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] side_B_links_i
, output [num_in_p-1:0][bsg_ready_and_link_sif_width_lp-1:0] side_B_links_o
);

  genvar i, n;

  // declare the bsg_ready_and_link_sif_s struct
  `declare_bsg_ready_and_link_sif_s(width_p, bsg_ready_and_link_sif_s);
  
  // noc links
  bsg_ready_and_link_sif_s [num_nodes_p:0][num_in_p-1:0] links_cast_A2B, links_cast_B2A;
  
  // Attach to input and output ports
  assign links_cast_A2B[0]           = side_A_links_i;
  assign side_B_links_o              = links_cast_A2B[num_nodes_p];
  assign links_cast_B2A[num_nodes_p] = side_B_links_i;
  assign side_A_links_o              = links_cast_B2A[0];
  
  // pipelines reset
  logic [num_nodes_p:0] reset_r;
  assign reset_r[0] = side_A_reset_i;
  
  for (i = 0; i < num_in_p; i++)
    begin: ch
      
      for (n = 0; n < num_nodes_p; n++)
        begin: node
        
          always_ff @(posedge clk_i)
            reset_r[n+1] <= reset_r[n];

          bsg_two_fifo #(.width_p( width_p ))
            A_to_B
              (.clk_i   ( clk_i )
              ,.reset_i ( reset_r[n] )

              ,.v_o     ( links_cast_A2B[n+1][i].v )
              ,.data_o  ( links_cast_A2B[n+1][i].data )
              ,.yumi_i  ( links_cast_A2B[n+1][i].v & links_cast_B2A[n+1][i].ready_and_rev)

              ,.v_i     ( links_cast_A2B[n][i].v )
              ,.data_i  ( links_cast_A2B[n][i].data )
              ,.ready_o ( links_cast_B2A[n][i].ready_and_rev )
              );

          bsg_two_fifo #(.width_p( width_p ))
            B_to_A
              (.clk_i   ( clk_i )
              ,.reset_i ( reset_r[n] )

              ,.ready_o ( links_cast_A2B[n+1][i].ready_and_rev )
              ,.data_i  ( links_cast_B2A[n+1][i].data )
              ,.v_i     ( links_cast_B2A[n+1][i].v )

              ,.v_o     ( links_cast_B2A[n][i].v )
              ,.data_o  ( links_cast_B2A[n][i].data )
              ,.yumi_i  ( links_cast_B2A[n][i].v & links_cast_A2B[n][i].ready_and_rev )
              );
          
        end: node
    end: ch

endmodule