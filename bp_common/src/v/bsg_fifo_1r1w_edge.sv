
`include "bsg_defines.sv"

// This module crosses between a negedge sender and a posedge receiver. This
//   could be (and has been) done with latches, but tool headaches lead us to
//   this solution instead.
// One could reasonably that if both interfaces are helpful, the intersection
//   of the handshake is valid and we can proceed normally. This issue is that
//   the data of the sender can change in the meantime (after the
//   intersection), so all sorts of weird bugs can arise. There may be a more
//   efficient way to do this, in which case users can swap out bsg_edge_cross
//   for a "hard" version.
module bsg_fifo_1r1w_edge
 #(parameter `BSG_INV_PARAM(width_p))
  (input                        clk_i
   , input                      reset_i

   , input [width_p-1:0]        data_i
   , input                      v_i
   , output logic               ready_and_o

   , output logic [width_p-1:0] data_o
   , output logic               v_o
   , input                      ready_and_i
   );

  wire send_clk =  clk_i;
  wire recv_clk = ~clk_i;

  logic ready_and_ext_r;
  bsg_dff
   #(.width_p(1))
   recv_reg
    (.clk_i(send_clk)
     ,.data_i(ready_and_i)
     ,.data_o(ready_and_ext_r)
     );

  assign ready_and_o = ready_and_ext_r;
  assign data_o = data_i;
  assign v_o = v_i;

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_edge)

