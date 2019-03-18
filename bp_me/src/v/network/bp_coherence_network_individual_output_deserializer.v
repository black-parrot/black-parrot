/**
 *
 * Name: bp_coherence_network_individual_output_deserializer.v
 *
 * Description:
 *    --
*/

module bp_coherence_network_individual_output_deserializer
  #(parameter packet_width_p                     = "inv"
    , parameter num_src_p                        = "inv"
    , parameter num_dst_p                        = "inv"
    , parameter reduced_payload_width_p          = "inv" // Each "divided" package will need to be attached to dst_id

    // Derived parameters
    , localparam mesh_width_lp                  = `BSG_MAX(num_src_p,num_dst_p)
    , localparam lg_mesh_width_lp               = `BSG_SAFE_CLOG2(mesh_width_lp)
    , localparam dst_id_width_lp                = `BSG_SAFE_CLOG2(num_dst_p)
    , localparam num_serialized_blocks_lp       = (packet_width_p+reduced_payload_width_p-1)/reduced_payload_width_p
    , localparam reduced_packet_width_lp        = (num_serialized_blocks_lp == 1) ? packet_width_p : reduced_payload_width_p + lg_mesh_width_lp
    , localparam log_num_serialized_blocks_lp   = `BSG_SAFE_CLOG2(num_serialized_blocks_lp)
    )
  (input                                        clk_i
   , input                                      reset_i

   // Output interface
   , output [packet_width_p-1:0]                dst_data_o
   , output                                     dst_v_o
   , input                                      dst_ready_i

   // Input interface
   , input [reduced_packet_width_lp-1:0]        dst_serialized_data_i
   , input                                      dst_serialized_v_i
   , output                                     dst_serialized_ready_o
);

  // If there is no serialization, don't do anything
  if(num_serialized_blocks_lp == 1) begin
    assign dst_data_o = dst_serialized_data_i;
    assign dst_v_o = dst_serialized_v_i;
    assign dst_serialized_ready_o = dst_ready_i;
  end

  // If there is serialization:
  else begin
    logic [num_serialized_blocks_lp-2:0][reduced_payload_width_p-1:0]       dst_serialized_payload_data_r, dst_serialized_payload_data_r_n;
  logic [log_num_serialized_blocks_lp-1:0]      counter, counter_n;

    // Next value for the first register
    assign dst_serialized_payload_data_r_n[0] = (dst_serialized_v_i & dst_serialized_ready_o ) ? dst_serialized_data_i[reduced_payload_width_p-1:0] : dst_serialized_payload_data_r[0];
    // Next value for the other registers and the first parts of dst_data_o
    genvar i;
    for (i=0; i<num_serialized_blocks_lp-2; i=i+1) begin: rof
      assign dst_serialized_payload_data_r_n[i+1] = ( dst_serialized_v_i & dst_serialized_ready_o ) ? dst_serialized_payload_data_r[i] : dst_serialized_payload_data_r[i+1];
      assign dst_data_o[i*reduced_payload_width_p +: reduced_payload_width_p] = dst_serialized_payload_data_r[num_serialized_blocks_lp-2-i];
    end //rof
    if(num_serialized_blocks_lp >= 2) assign dst_data_o[(num_serialized_blocks_lp-2)*reduced_payload_width_p +: reduced_payload_width_p] = dst_serialized_payload_data_r[0];
    assign dst_data_o[packet_width_p-1 : (num_serialized_blocks_lp-1)*reduced_payload_width_p] = dst_serialized_data_i[packet_width_p - ( (num_serialized_blocks_lp - 1) * reduced_payload_width_p )-1:0];
  
    // Next value for the counter
    assign counter_n = ( !(dst_serialized_v_i & dst_serialized_ready_o) ) ? counter : ( counter == (log_num_serialized_blocks_lp)'(num_serialized_blocks_lp-1) ) ? (log_num_serialized_blocks_lp)'(0) :  counter + (log_num_serialized_blocks_lp)'(1);

    // This module is always ready to receive data, unless the output is ready
    // and cannot be received (which shouldn't happen in our system)
    assign dst_serialized_ready_o = (!dst_v_o) | (dst_ready_i);

    // Logic for the v_o in the output
    assign dst_v_o = ( counter == (log_num_serialized_blocks_lp)'(num_serialized_blocks_lp-1) );

    // Registers
    always_ff @ (posedge clk_i) begin
      if (reset_i) begin
        dst_serialized_payload_data_r <= '0;
        counter <= '0;
      end
      else begin
        dst_serialized_payload_data_r <= dst_serialized_payload_data_r_n;
        counter <= counter_n;
      end
    end
  end
endmodule
