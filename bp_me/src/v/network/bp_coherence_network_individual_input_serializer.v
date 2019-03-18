/**
 *
 * Name: bp_coherence_network_individual_input_serializer.v
 *
 * Description:
 *    This block "divides" the input packet in N smaller packets and sends
 *    them sequentially through the network. This allows us to use a smaller
 *    network (less area) but imposes a higher latency (less performance)
*/

module bp_coherence_network_individual_input_serializer
  #(parameter packet_width_p                     = "inv"
    , parameter num_src_p                        = "inv"
    , parameter num_dst_p                        = "inv"
    , parameter reduced_payload_width_p          = "inv" // Each "divided" package will need to be attached to dst_id

    // Derived parameters
    , localparam mesh_width_lp                  = `BSG_MAX(num_src_p,num_dst_p)
    , localparam lg_mesh_width_lp               = `BSG_SAFE_CLOG2(mesh_width_lp)
    , localparam dst_id_width_lp                = `BSG_SAFE_CLOG2(num_dst_p)
    , localparam num_serialized_blocks_lp       = (packet_width_p+reduced_payload_width_p-1)/reduced_payload_width_p
    , localparam lg_num_dst_lp              = `BSG_SAFE_CLOG2(num_dst_p)
    , localparam reduced_packet_width_lp    = (num_serialized_blocks_lp == 1) ? packet_width_p + lg_mesh_width_lp -lg_num_dst_lp : reduced_payload_width_p + lg_mesh_width_lp
    , localparam log_num_serialized_blocks_lp   = `BSG_SAFE_CLOG2(num_serialized_blocks_lp)
    )
  (input                                        clk_i
   , input                                      reset_i

   // Input interface
   , input [packet_width_p-1:0]                 src_data_i
   , input                                      src_v_i
   , output                                     src_ready_o

   // Output interface
   , output [reduced_packet_width_lp-1:0]       src_serialized_data_o 
   , output                                     src_serialized_v_o
   , input                                      src_serialized_ready_i
);

  // If there is no serialization, don't do anything
  if(num_serialized_blocks_lp == 1) begin
    assign src_serialized_data_o = (reduced_packet_width_lp)'(src_data_i);
    assign src_serialized_v_o = src_v_i;
    assign src_ready_o = src_serialized_ready_i;
  end

  // If there is serialization:
  else begin
    logic [packet_width_p-1:0]                    src_data_i_mux, src_data_i_mux_r;
    logic [log_num_serialized_blocks_lp-1:0]      counter, counter_n, counter_n_aux;
    logic [reduced_payload_width_p-1:0]           src_serialized_payload_data;
    logic [lg_mesh_width_lp-1:0]                  dst_id;

    // Getting the destination from the original packet
    assign dst_id = (lg_mesh_width_lp)'(src_data_i_mux[packet_width_p-1 -: dst_id_width_lp]);
    // assign dst_id = src_data_i_mux[packet_width_p-1 -: dst_id_width_lp];

    always_comb begin
      // MUX that choses the appropiate section of src_data_i_mux as the output,
      // depending on the value of counter.
      int i;
      for (i=0; i<num_serialized_blocks_lp-1; i=i+1) begin: rof
        if( counter == log_num_serialized_blocks_lp'(i))  src_serialized_payload_data = src_data_i_mux[i*reduced_payload_width_p +: reduced_payload_width_p];
      end //rof
      // The following default includes the next (commented) case
      // log_num_serialized_blocks_lp'(num_serialized_blocks_lp-1)  :   \
      // CHECK FOR BUG
      if( counter >= log_num_serialized_blocks_lp'(num_serialized_blocks_lp-1) ) src_serialized_payload_data = (reduced_payload_width_p)'(src_data_i_mux[packet_width_p-1 -: packet_width_p - ( (num_serialized_blocks_lp - 1) * reduced_payload_width_p)]);
    end

    // Next value for the two registers:
    assign counter_n_aux = ( ( counter == (log_num_serialized_blocks_lp)'(0) ) & ( !src_v_i ) ) ? (log_num_serialized_blocks_lp)'(0) : ( counter == (log_num_serialized_blocks_lp)'(num_serialized_blocks_lp-1) ) ? (log_num_serialized_blocks_lp)'(0) :  counter + (log_num_serialized_blocks_lp)'(1);
    assign counter_n = (src_serialized_ready_i) ? counter_n_aux : counter;
    assign src_data_i_mux = ( counter == (log_num_serialized_blocks_lp)'(0) ) ? src_data_i : src_data_i_mux_r;

    // Logic for the ready_o signal in the input interface
    assign src_ready_o = ( counter == (log_num_serialized_blocks_lp)'(0) ) & src_serialized_ready_i;

    // Logic for the v_o signal in the output interface, and the actual output
    assign src_serialized_v_o = src_v_i | ( counter != (log_num_serialized_blocks_lp)'(0) );
    assign src_serialized_data_o = { dst_id, src_serialized_payload_data };

    // Registers
    always_ff @ (posedge clk_i) begin
      if (reset_i) begin
        counter <= '0;
        src_data_i_mux_r <= '0;
      end
      else begin
        counter <= counter_n;
        src_data_i_mux_r <= src_data_i_mux;
      end
    end
  end
endmodule
