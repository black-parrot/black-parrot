
`include "bsg_defines.v"

module bp_me_stream_wraparound
 #(parameter `BSG_INV_PARAM(max_val_p)
   , parameter awt_p = 0
   , localparam width_lp = `BSG_WIDTH(max_val_p)
   , localparam size_lp = `BSG_SAFE_CLOG2(width_lp)
   )
  (input                            clk_i
   , input                          reset_i

   // A new wraparound sequence has started, this is a transparent write
   , input                          set_i
   , input [width_lp-1:0]           max_i
   // Increment counter
   , input                          en_i
   , input [width_lp-1:0]           base_cnt_i
   , input [width_lp-1:0]           num_stream_i

   , output logic [width_lp-1:0]    cnt_o
   );

  logic [width_lp-1:0] max_r, cnt_r;

  always_ff @(posedge clk_i)
    if (reset_i)
      max_r <= '0;
    else
      max_r <= max_i;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      cnt_r <= '0;
    else if (set_i)
      cnt_r <= base_cnt_i + en_i;
    else if (cnt_r < max_r)
      cnt_r <= cnt_r + en_i;
    else if (en_i)
      cnt_r <= '0;

  if (awt_p == 1)
    begin : awt
      assign cnt_o = set_i ? base_cnt_i : cnt_r;
    end
  else
    begin : no_awt
      assign cnt_o = cnt_r;
    end

endmodule

