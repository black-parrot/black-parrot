
module bsg_fifo_1r1w_periodic
 #(parameter `BSG_INV_PARAM(a_period_p)
   , parameter `BSG_INV_PARAM(b_period_p)
   , parameter num_hs_p = 1
   )
  (input                         a_clk_i
   , input                       a_reset_i
   , input [num_hs_p-1:0]        a_v_i
   , output logic [num_hs_p-1:0] a_ready_and_o

   , input                       b_clk_i
   , input                       b_reset_i
   , output logic [num_hs_p-1:0] b_v_o
   , input [num_hs_p-1:0]        b_ready_and_i
   );

  localparam fast2slow_lp  = (a_period_p < b_period_p);
  localparam ratio_lp      = fast2slow_lp ? b_period_p : a_period_p;

  logic [ratio_lp-1:0] cnt_r;
  if (a_period_p == b_period_p)
    begin : fi
      assign cnt_r = 1'b1;
    end
  else
    begin : fi
      wire fast_clk   = fast2slow_lp ? a_clk_i   : b_clk_i;
      bsg_counter_clear_up_one_hot
       #(.max_val_p(ratio_lp-1))
       counter
        (.clk_i(fast_clk)
         ,.reset_i(a_reset_i | b_reset_i)

         ,.clear_i(1'b0)
         ,.up_i(1'b1)
         ,.count_r_o(cnt_r)
         );
    end
  wire [num_hs_p-1:0] accept_input = {num_hs_p{cnt_r[ratio_lp-1] & ~a_reset_i & ~b_reset_i}};
  // VCS 2016.06 incorrectly orders assignments if these were 'assign' statements, so keep them
  //   in the always_comb...
  always_comb
    if (fast2slow_lp)
      begin
        a_ready_and_o = accept_input & b_ready_and_i;
        b_v_o         = a_v_i;
      end
    else
      begin
        a_ready_and_o = b_ready_and_i;
        b_v_o         = accept_input & a_v_i;
      end

  if ((a_period_p != 1) && (b_period_p != 1))
    $error("Only 1:N or N:1 division ratios are currently supported");

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_periodic)

