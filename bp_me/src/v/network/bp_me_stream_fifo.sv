
`include "bsg_defines.v"

// This module efficiently buffers a bedrock stream, by storing one header
//   per stream. The data elements can be configured as >= header els.
// Two common configurations would be 2&2, which provides timing isolation
//   without impacting throughput, and 2&16 which provides two full messages
//   worth of buffering (for a 512-bit block system).

module bp_me_stream_fifo
 #(// Size of fifos
   parameter `BSG_INV_PARAM(header_els_p)
   , parameter `BSG_INV_PARAM(header_width_p)
   , parameter `BSG_INV_PARAM(data_els_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   // Input BedRock Stream
   , input [header_width_p-1:0]              msg_header_i
   , input [data_width_p-1:0]                msg_data_i
   , input                                   msg_v_i
   , input                                   msg_last_i
   , output logic                            msg_ready_and_o


   , output logic [header_width_p-1:0]       msg_header_o
   , output logic [data_width_p-1:0]         msg_data_o
   , output logic                            msg_v_o
   , output logic                            msg_last_o
   , input                                   msg_yumi_i
   );

  enum logic {e_ready, e_stream} state_n, state_r;
  wire is_ready  = (state_r == e_ready);
  wire is_stream = (state_r == e_stream);

  logic msg_header_ready_and_lo, msg_header_v_li;
  logic msg_data_ready_and_lo, msg_data_v_li;
  if (header_els_p == 0 && data_els_p == 0)
    begin : passthrough
      // This could just be the address, but should synthesize the same
      logic [header_width_p-1:0] msg_header_r;
      bsg_dff_reset_en_bypass
       #(.width_p(header_width_p))
       header_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.en_i(is_ready & msg_v_i)
         ,.data_i(msg_header_i)
         ,.data_o(msg_header_r)
         );

      assign msg_header_o       = msg_header_r;
      assign msg_data_o              = msg_data_i;
      assign msg_v_o                 = msg_v_i;
      assign msg_last_o              = msg_last_i;
      assign msg_header_ready_and_lo = msg_yumi_i;
      assign msg_data_ready_and_lo   = msg_yumi_i;
    end
  else if (header_els_p != 0 && data_els_p != 0 && header_els_p <= data_els_p)
    begin : buffered
      // Only save headers after last signals
      bsg_fifo_1r1w_small
       #(.width_p(header_width_p), .els_p(header_els_p), .ready_THEN_valid_p(1))
       header_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_header_i)
         ,.v_i(msg_header_v_li)
         ,.ready_o(msg_header_ready_and_lo)

         ,.data_o(msg_header_o)
         ,.v_o()
         ,.yumi_i(msg_yumi_i & msg_last_o)
         );

      // Every arriving beat's data is buffered (regardless of whether data is valid)
      bsg_fifo_1r1w_small
       #(.width_p(1+data_width_p), .els_p(data_els_p), .ready_THEN_valid_p(1))
       data_fifo
        (.clk_i(clk_i)
          ,.reset_i(reset_i)

          ,.data_i({msg_last_i, msg_data_i})
          ,.v_i(msg_data_v_li)
          ,.ready_o(msg_data_ready_and_lo)

          ,.data_o({msg_last_o, msg_data_o})
          ,.v_o(msg_v_o)
          ,.yumi_i(msg_yumi_i)
          );
    end
  else
    begin : partial
      $error("Partial buffering unsupported %d %d", header_els_p, data_els_p);
    end

  always_comb
    case (state_r)
      e_stream:
        begin
          msg_ready_and_o = msg_data_ready_and_lo;
          msg_header_v_li = 1'b0;
          msg_data_v_li   = msg_ready_and_o & msg_v_i;

          state_n = (msg_ready_and_o & msg_v_i & msg_last_i) ? e_ready : e_stream;
        end

      default:
        begin
          msg_ready_and_o = msg_header_ready_and_lo & msg_data_ready_and_lo;
          msg_header_v_li = msg_ready_and_o & msg_v_i;
          msg_data_v_li   = msg_ready_and_o & msg_v_i;

          state_n = (msg_ready_and_o & msg_v_i & ~msg_last_i) ? e_stream : e_ready;
        end
    endcase

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_fifo)

