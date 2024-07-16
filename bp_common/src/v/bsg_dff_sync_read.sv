
`include "bsg_defines.sv"

// This module buffers data on a synchronous read, useful for buffering
//   things like an synchronous SRAM read
module bsg_dff_sync_read
 #(parameter `BSG_INV_PARAM(width_p)
   // Whether data is available synchronously or asynchronously
   , parameter bypass_p = 0
   )
  (input clk_i
   , input reset_i

   // v_n_i is high the cycle before the data comes in
   // The stored data will always be overwritten
   , input                      v_n_i
   , input [width_p-1:0]        data_i

   , output logic [width_p-1:0] data_o
   );

  logic v_r;
  bsg_dff
   #(.width_p(1))
   v_reg
    (.clk_i(clk_i)

     ,.data_i(v_n_i)
     ,.data_o(v_r)
     );

  if (bypass_p == 1)
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

`BSG_ABSTRACT_MODULE(bsg_dff_sync_read)

