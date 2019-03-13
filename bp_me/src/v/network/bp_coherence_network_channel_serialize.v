module bp_coherence_network_channel_serialize
  #(parameter packet_width_p      = "inv"
  , parameter num_src_p           = "inv"
  , parameter num_dst_p           = "inv"
  , parameter chunk_size_p        = "inv"
  , parameter debug_p             = "inv"
  , parameter repeater_output_p   = "inv"
  , localparam  dest_id_width_p       = `BSG_SAFE_CLOG2(num_dst_p)
  , localparam  src_id_width_p        = `BSG_SAFE_CLOG2(num_src_p)
  , localparam  num_packets_p         = (packet_width_p + chunk_size_p - 1) / packet_width_p
//  , localparam  total_data_width      = packet_data_width_p*num_packets_p
  , localparam  total_o_data_width    = chunk_size_p + dest_id_width_p + src_id_width_p
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

  logic [num_src_p-1:0][total_o_data_width-1:0] src_data_serial;
  logic [num_src_p-1:0]                   src_v_serial;
  logic [num_src_p-1:0]                   src_ready_serial;

  logic [num_dst_p-1:0][total_o_data_width-1:0] dst_data_serial;
  logic [num_dst_p-1:0]                   dst_v_serial;
  logic [num_dst_p-1:0]                   dst_ready_serial;

  genvar i;
  for(i = 0; i < num_src_p; i = i + 1) begin : serializers
    bp_network_serializer #(.num_dest(num_dst_p)
                          , .num_src(num_src_p)
                          , .source_data_width_p(packet_width_p)
                          , .packet_data_width_p(chunk_size_p)
                          )
    serialize
    ( .clk_i(clk_i)
    , .reset_i(reset_i)
    // Data Input Channel
    , .valid_i(src_v_i[i])
    , .data_i(src_data_i[i])
    , .ready_o(src_ready_o[i])
    // Data Output Channel
    , .valid_o(src_v_serial[i])
    , .data_o(src_data_serial[i])
    , .yumi_i(src_ready_serial[i])
    );
  end // serializers

  bp_coherence_network_channel #(.packet_width_p(total_o_data_width)
                               , .num_src_p(num_src_p)
                               , .num_dst_p(num_dst_p)
                               , .debug_p(debug_p)//
                               , .repeater_output_p(repeater_output_p)//
                               )
    network_channel
    ( .clk_i(clk_i)
    , .reset_i(reset_i)
    // South Port (src)
    , .src_data_i(src_data_serial)
    , .src_v_i(src_v_serial)
    , .src_ready_o(src_ready_serial)
    // Proc Port (dst)
    , .dst_data_o(dst_data_serial)
    , .dst_v_o(dst_v_serial)
    , .dst_ready_i(dst_ready_serial)
    );


  genvar j;
  for(j = 0; j < num_dst_p; j = j + 1) begin : deserializers
    bp_network_deserializer #(.num_dest(num_dst_p)            
                            , .num_src(num_src_p)
                            , .source_data_width_p(packet_width_p) 
                            , .packet_data_width_p(chunk_size_p) 
                            )
    to_parallel
    ( .clk_i(clk_i)
    , .reset_i(reset_i)
    
    , .v_i(dst_v_serial[j])
    , .ready_o(dst_ready_serial[j])
    , .data_i(dst_data_serial[j])

    , .data_o(dst_data_o[j])
    , .v_o(dst_v_o[j])
    , .yumi_i(dst_ready_i[j])
    );
  end // deserializers

endmodule // bp_coherence_network_channel_serialize