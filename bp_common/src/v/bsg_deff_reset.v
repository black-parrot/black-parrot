
`include "bsg_defines.v"

//
// https://stackoverflow.com/questions/19605881/triggering-signal-on-both-edges-of-the-clock
//

module bsg_deff_reset
 #(parameter `BSG_INV_PARAM(width_p))
  (input                        clk_i
   , input                      reset_i
   , input  [width_p-1:0]       data_i
   , output logic [width_p-1:0] data_o
   );

   logic [width_p-1:0] data_r_pr, data_r_nr;
   always_ff @(posedge clk_i)
     if (reset_i)
       data_r_pr <= '0;
     else
       data_r_pr <= data_i ^ data_r_nr;

   always_ff @(negedge clk_i)
     if (reset_i)
       data_r_nr <= '0;
     else
       data_r_nr <= data_i ^ data_r_pr;

   assign data_o = data_r_pr ^ data_r_nr;

endmodule

`BSG_ABSTRACT_MODULE(bsg_deff_reset)

