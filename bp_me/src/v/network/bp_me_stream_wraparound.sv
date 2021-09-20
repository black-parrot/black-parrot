
`include "bsg_defines.v"

module bp_me_stream_wraparound
 #(parameter `BSG_INV_PARAM(max_val_p)
   , localparam width_lp = `BSG_WIDTH(max_val_p)
   , localparam size_lp = `BSG_SAFE_CLOG2(width_lp)
   )
  (input                                          clk_i
   , input                                        reset_i

   // A new wraparound sequence has started, this is a transparent write
   , input                                        set_i
   // Increment counter
   , input                                        en_i
   , input [`BSG_SAFE_MINUS(width_lp,1):0]        max_i
   , input [`BSG_SAFE_MINUS(width_lp,1):0]        val_i

   , output logic [`BSG_SAFE_MINUS(width_lp,1):0] full_o
   , output logic [`BSG_SAFE_MINUS(width_lp,1):0] wrap_o
   );

  if (max_val_p == 0)
    begin : z
      assign full_o = '0;
      assign wrap_o = '0;
    end
  else
    begin : nz
      logic [width_lp-1:0] cnt_r;
      wire [width_lp-1:0] cnt_val_li = val_i + en_i;
      bsg_counter_set_en
       #(.max_val_p(max_val_p), .reset_val_p('0))
       counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(set_i)
         ,.en_i(en_i)
         ,.val_i(cnt_val_li)
         ,.count_o(cnt_r)
         );

      // Generate proper wrap-around address for different incoming msg size dynamically.
      // __________________________________________________________
      // |                |          block offset                  |  input address
      // |  upper address |________________________________________|
      // |                |     stream count   |  stream offset    |  output address
      // |________________|____________________|___________________|
      // Block size = stream count * stream size, with a request smaller than block_width_p,
      // a narrower stream_cnt is required to generate address for each sub-stream pkt.
      // Eg. block_width_p = 512, stream_data_witdh_p = 64, then counter width = log2(512/64) = 3
      // size = 512: a wrapped around seq: 2, 3, 4, 5, 6, 7, 0, 1  all 3-bit of cnt is used
      // size = 256: a wrapped around seq: 2, 3, 0, 1              only lower 2-bit of cnt is used

      assign full_o = cnt_r;

      logic [width_lp-1:0] cnt_sel_li;
      for (genvar i = 0; i < width_lp; i++)
        begin : cnt_sel
          assign cnt_sel_li[i] = max_i >= 2**i;
        end

      bsg_mux_bitwise
       #(.width_p(width_lp))
       wrap_mux
        (.data0_i(val_i)
         ,.data1_i(cnt_r)
         ,.sel_i(cnt_sel_li)
         ,.data_o(wrap_o)
         );
    end

endmodule

