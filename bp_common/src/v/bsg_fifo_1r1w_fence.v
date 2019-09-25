

module bsg_fifo_1r1w_fence
 #(parameter width_p = "inv"
   , parameter els_p = "inv"

   // Default parameters
   , parameter ready_THEN_valid_p = 0
   )
  (input                  clk_i
   , input                reset_i

   , input                fence_set_i
   , input                fence_clr_i
   , output               fence_o

   , input [width_p-1:0]  data_i
   , input                v_i
   , output               ready_o

   , output [width_p-1:0] data_o
   , output               v_o
   , input                yumi_i
   );

  bsg_fifo_1r1w_small
   #(.width_p(width_p)
     ,.els_p(els_p)
     ,.ready_THEN_valid_p(ready_THEN_valid_p)
     )
   fe_cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(data_i)
     ,.v_i(v_i)
     ,.ready_o(ready_o)

     ,.data_o(data_o)
     ,.v_o(v_o)
     ,.yumi_i(yumi_i)
     );

  logic fence_r;
  bsg_dff_reset_en
   #(.width_p(1))
   fence_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(fence_set_i | fence_clr_i)

     ,.data_i(fence_set_i)
     ,.data_o(fence_r)
     );

  assign fence_o = fence_r;

endmodule

