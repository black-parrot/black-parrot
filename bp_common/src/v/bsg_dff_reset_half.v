
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
 #(parameter width_p = "inv")
  (input                        clk_i
   , input                      reset_i
   , input  [width_p-1:0]       data_i
   , output logic [width_p-1:0] data_o
   );

   logic [width_p-1:0] data_r, data_r_nr, data_r_pr;

   always_ff @(posedge clk_i)
     if (reset_i)
       data_r <= '0;
     else
       data_r <= data_i;

   always_ff @(negedge clk_i)
     data_r_nr <= data_r;

   always_ff @(posedge clk_i)
     data_r_pr <= data_r;

   assign data_o = data_r & (data_r ^ data_r_nr ^ data_r_pr);

endmodule

