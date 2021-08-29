
`include "bsg_defines.v"

//
// This module acts as a flip-flop which latches for half of a cycle. This is
//   useful in niche applications where half cycle control signals are desired.
//
//      ---     ---     ---
// |___|   |___|   |___|
//     A   B   C
//
//  We achieve this by latching the signal 3 times and performing minimal logic
//    to generate the correct signal.
//

module bsg_dff_reset_half
 #(parameter `BSG_INV_PARAM(width_p))
  (input                        clk_i
   , input                      reset_i
   , input  [width_p-1:0]       data_i
   , output logic [width_p-1:0] data_half_o
   , output logic [width_p-1:0] data_full_o
   );

   logic [width_p-1:0] data_r;
   always_ff @(posedge clk_i)
     if (reset_i)
       data_r <= '0;
     else
       data_r <= data_i;

   logic [width_p-1:0] data_r_nr;
   always_ff @(negedge clk_i)
     if (reset_i)
       data_r_nr <= '0;
     else
       data_r_nr <= data_r;

   logic [width_p-1:0] data_r_pxor;
   always_ff @(posedge clk_i)
     if (reset_i)
       data_r_pxor <= '0;
     else
       data_r_pxor <= data_r_pxor ^ data_r_nr;

   logic [width_p-1:0] data_r_nxor;
   always_ff @(negedge clk_i)
     if (reset_i)
       data_r_nxor <= '0;
     else
       data_r_nxor <= data_r_nxor ^ data_r;

   assign data_half_o = data_r & (data_r ^ data_r_nxor ^ data_r_pxor);
   assign data_full_o = data_r;

endmodule

`BSG_ABSTRACT_MODULE(bsg_dff_reset_half)

