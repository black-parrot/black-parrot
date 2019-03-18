/**
 *
 * Name: bp_coherence_network_input_serializer.v
 *
 * Description:
 *    This block "divides" the input packet in N smaller packets and sends
 *    them sequentially through the network. This allows us to use a smaller
 *    network (less area) but imposes a higher latency (less performance)
*/

module bp_coherence_network_input_serializer
  #(parameter packet_width_p                     = "inv"
    , parameter num_src_p                        = "inv"
    , parameter num_dst_p                        = "inv"
    , parameter reduced_payload_width_p          = "inv"
    , parameter fifo_els_p                       = "inv"

    // Derived parameters
    , localparam mesh_width_lp              = `BSG_MAX(num_src_p,num_dst_p)
    , localparam lg_mesh_width_lp           = `BSG_SAFE_CLOG2(mesh_width_lp)
    , localparam lg_num_dst_lp              = `BSG_SAFE_CLOG2(num_dst_p)
    , localparam num_serialized_blocks_lp       = (packet_width_p+reduced_payload_width_p-1)/reduced_payload_width_p
    , localparam reduced_packet_width_lp    = (num_serialized_blocks_lp == 1) ? packet_width_p + lg_mesh_width_lp -lg_num_dst_lp : reduced_payload_width_p + lg_mesh_width_lp
    )
  (input                                              clk_i
   , input                                            reset_i

   // Input interface
   , input [num_src_p-1:0][packet_width_p-1:0]        src_data_i
   , input [num_src_p-1:0]                            src_v_i
   , output[num_src_p-1:0]                            src_ready_o

   // Output Interface
   , output [num_src_p-1:0][reduced_packet_width_lp-1:0]       src_serialized_data_o
   , output [num_src_p-1:0]                                    src_serialized_v_o
   , input  [num_src_p-1:0]                                    src_serialized_ready_i
);

  logic [num_src_p-1:0][packet_width_p-1:0] src_data_i_int;
  logic [num_src_p-1:0] yumi_fifo, valid_fifo;
  // Instantiate one serializer for each input port of the network
  genvar i;
  for (i = 0; i < num_src_p; i=i+1) begin: rof
    if(fifo_els_p == 0) begin
      assign src_data_i_int[i] = src_data_i[i];
      assign valid_fifo[i] = src_v_i[i];
      assign src_ready_o[i] = yumi_fifo[i];
    end
    else begin
      bsg_fifo_1r1w_large 
         #(  .width_p(packet_width_p)
           , .els_p(fifo_els_p)
          )
      ser_fifo
       ( .clk_i(clk_i)
       , .reset_i(reset_i)
 
       , .data_i(src_data_i[i])
       , .v_i(src_v_i[i] & src_ready_o[i])
       , .ready_o(src_ready_o[i])

       , .v_o(valid_fifo[i])
       , .data_o(src_data_i_int[i])
       , .yumi_i(yumi_fifo[i] & valid_fifo[i])
       ); 
    end

    bp_coherence_network_individual_input_serializer
      #(.packet_width_p(packet_width_p)
        ,.num_src_p(num_src_p)
        ,.num_dst_p(num_dst_p)
        ,.reduced_payload_width_p(reduced_payload_width_p)
        )
      bp_coherence_network_individual_input_serializer
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.src_data_i(src_data_i_int[i])
        ,.src_v_i(valid_fifo[i])
        ,.src_ready_o(yumi_fifo[i])
        ,.src_serialized_data_o(src_serialized_data_o[i])
        ,.src_serialized_v_o(src_serialized_v_o[i])
        ,.src_serialized_ready_i(src_serialized_ready_i[i])
      );
  end //rof

endmodule
