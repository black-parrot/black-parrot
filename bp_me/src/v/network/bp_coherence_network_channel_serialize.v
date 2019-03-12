module bp_coherence_network_channel_serialize
  #(parameter packet_width_p        = "inv"
    , parameter num_src_p           = "inv"
    , parameter num_dst_p           = "inv"
    , parameter chunk_size_p        = "inv"
    )

   ( input                                              clk_i
   , input                                            reset_i

   // South port (src), helpful consumer (buffered inputs), ready->valid
   , input [num_src_p-1:0][packet_width_p-1:0]        src_data_i
   , input [num_src_p-1:0]                            src_v_i
   , output[num_src_p-1:0]                            src_ready_o

   // Proc port (dest), demanding producer, ready->valid
   , output [num_dst_p-1:0][packet_width_p-1:0]       dst_data_o
   , output [num_dst_p-1:0]                           dst_v_o
   , input  [num_dst_p-1:0]                           dst_ready_i
  );

  bp_network_serializer 
  //import bp_common_pkg::*;
  #(.num_dest(num_dst_p)
  , .num_src(num_src_p)
  , .source_data_width_p(packet_width_p)
  , .packet_data_width_p(chunk_size_p)
  )
  serialize
  ( .clk_i(clk_i)
  , .reset_i(reset_i)
  // Data Input Channel
  , .valid_i(src_v_i)
  , .data_i(src_data_i)
  , .ready_o(src_ready_o)
  // Data Output Channel
  , .valid_o()
  , .data_o()
  , .yumi_i()
  );


  bp_coherence_network_channel
    #(.packet_width_p(packet_width_p)
      ,.num_src_p(num_src)
      ,.num_dst_p(num_dst)
      ,.debug_p(debug_p)//
      ,.repeater_output_p(repeater_output_lp)//
      )
    cce_lce_cmd_network
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // South Port (src)
      ,.src_data_i(lce_cmd_i)
      ,.src_v_i(lce_cmd_v_i)
      ,.src_ready_o(lce_cmd_ready_o)
      // Proc Port (dst)
      ,.dst_data_o(lce_cmd_o)
      ,.dst_v_o(lce_cmd_v_o)
      ,.dst_ready_i(lce_cmd_ready_i)
);

  bp_network_deserializer 
  //import bp_common_pkg::*;
  #( .num_dest(num_dest_p)            
   , .num_src(num_src_p)
   , .source_data_width_p(packet_width_p) 
   , .packet_data_width_p(chunk_width_p) 

  )
  to_parallel
  ( .clk_i(clk_i)
  , .reset_i(reset_i)
  
  , .v_i()
  , .ready_o()
  , .data_i()

  , .data_o(dst_data_o)
  , .v_o(dst_valid_o)
  , .yumi_i(dst_ready_i)
);