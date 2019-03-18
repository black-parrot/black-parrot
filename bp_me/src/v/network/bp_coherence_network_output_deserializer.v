/**
 *
 * Name: bp_coherence_network_output_deserializer.v
 *
 * Description:
 *    --
*/

module bp_coherence_network_output_deserializer
  #(parameter packet_width_p                     = "inv"
    , parameter num_src_p                        = "inv"
    , parameter num_dst_p                        = "inv"
    , parameter reduced_payload_width_p          = "inv"

    // Derived parameters
    , localparam mesh_width_lp              = `BSG_MAX(num_src_p,num_dst_p)
    , localparam lg_mesh_width_lp           = `BSG_SAFE_CLOG2(mesh_width_lp)
    , localparam num_serialized_blocks_lp   = (packet_width_p+reduced_payload_width_p-1)/reduced_payload_width_p
    , localparam lg_num_dst_lp              = `BSG_SAFE_CLOG2(num_dst_p)
    , localparam reduced_packet_width_lp    = (num_serialized_blocks_lp == 1) ? packet_width_p + lg_mesh_width_lp -lg_num_dst_lp : reduced_payload_width_p + lg_mesh_width_lp
    )
  (input                                                      clk_i
   , input                                                    reset_i

   // Output interface
   , output [num_dst_p-1:0][packet_width_p-1:0]               dst_data_o
   , output [num_dst_p-1:0]                                   dst_v_o
   , input  [num_dst_p-1:0]                                   dst_ready_i

   // Input interface
   , input  [num_dst_p-1:0][reduced_packet_width_lp-1:0]      dst_serialized_data_i
   , input  [num_dst_p-1:0]                                   dst_serialized_v_i
   , output [num_dst_p-1:0]                                   dst_serialized_ready_o
);

  // Instantiate one serializer for each input port of the network
  genvar i;
  for (i = 0; i < num_dst_p; i=i+1) begin: rof
    // Instantiations
    
    bp_coherence_network_individual_output_deserializer
      #(.packet_width_p(packet_width_p)
        ,.num_src_p(num_src_p)
        ,.num_dst_p(num_dst_p)
        ,.reduced_payload_width_p(reduced_payload_width_p)
        )
      bp_coherence_network_individual_output_deserializer
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.dst_data_o(dst_data_o[i])
        ,.dst_v_o(dst_v_o[i])
        ,.dst_ready_i(dst_ready_i[i])
        ,.dst_serialized_data_i(dst_serialized_data_i[i])
        ,.dst_serialized_v_i(dst_serialized_v_i[i])
        ,.dst_serialized_ready_o(dst_serialized_ready_o[i])
      );
  end //rof

endmodule
