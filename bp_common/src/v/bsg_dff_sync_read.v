
// This module buffers data on a synchronous read, useful for buffering
//   things like an synchronous SRAM read
module bsg_dff_sync_read
 #(parameter width_p = "inv"

   // Whether to bypass the read data so that it doesn't create a bubble
   , parameter bypass_p = 0
   )
  (input clk_i
   , input reset_i

   // v_n_i is high the cycle before the data comes in
   // The stored data will always be overwritten and valid always set, regardless
   //   of the current valid state or incoming yumi
   , input                      v_n_i
   , input [width_p-1:0]        data_i

   , output logic [width_p-1:0] data_o
   , output logic               v_o
   // yumi_i clears the valid signal
   , input                      yumi_i
   );

  logic v_r;
  bsg_dff
   #(.width_p(1))
   v_reg
    (.clk_i(clk_i)

     ,.data_i(v_n_i)
     ,.data_o(v_r)
     );

  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_o_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(v_r)
     ,.clear_i(yumi_i)
     ,.data_o(v_o)
     );

  if (bypass_p)
    begin : bypass
      bsg_dff_en_bypass
       #(.width_p(width_p))
       data_reg
        (.clk_i(clk_i)

        ,.en_i(v_r)
        ,.data_i(data_i)
        ,.data_o(data_o)
        );
    end
  else
    begin : no_bypass
      bsg_dff_en
       #(.width_p(width_p))
       data_reg
        (.clk_i(clk_i)

        ,.en_i(v_r)
        ,.data_i(data_i)
        ,.data_o(data_o)
        );
    end

endmodule

