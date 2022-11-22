
`include "bsg_defines.v"

/* TODO: This should be replaced by 'hard' implementations for FPGA and ASIC */

module bsg_edge_extend #(parameter `BSG_INV_PARAM(width_p))
  (input clk_i
   , input reset_i

   , input [width_p-1:0] data_i
   , output logic [width_p-1:0] data_o
   );

`ifdef VERILATOR
  bsg_deff_reset
   #(.width_p(width_p))
   edge_deff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(data_i)
     ,.data_o(data_o)
     );
`else
  bsg_dlatch
   #(.width_p(width_p), .i_know_this_is_a_bad_idea_p(1))
   edge_latch
    (.clk_i(clk_i)
     ,.data_i(data_i)
     ,.data_o(data_o)
     );
`endif

endmodule

