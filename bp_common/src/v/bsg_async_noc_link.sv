
`include "bsg_defines.sv"
`include "bsg_noc_links.svh"

module bsg_async_noc_link
 import bsg_noc_pkg::*;
 #(parameter `BSG_INV_PARAM(width_p)
   , parameter `BSG_INV_PARAM(lg_size_p)

   , parameter bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)
   )
  (input                                          aclk_i
   , input                                        areset_i

   , input                                        bclk_i
   , input                                        breset_i

   , input [bsg_ready_and_link_sif_width_lp-1:0]  alink_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] alink_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  blink_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] blink_o
   );

  `declare_bsg_ready_and_link_sif_s(width_p, bsg_ready_and_link_sif_s);

   bsg_ready_and_link_sif_s alink_cast_i, alink_cast_o;
   bsg_ready_and_link_sif_s blink_cast_i, blink_cast_o;

   assign alink_cast_i = alink_i;
   assign blink_cast_i = blink_i;

   assign alink_o = alink_cast_o;
   assign blink_o = blink_cast_o;

   logic alink_full_lo;
   assign alink_cast_o.ready_and_rev = ~alink_full_lo;
   wire alink_enq_li = alink_cast_i.v & alink_cast_o.ready_and_rev;
   wire blink_deq_li = blink_cast_o.v & blink_cast_i.ready_and_rev;
   bsg_async_fifo
    #(.width_p(width_p)
      ,.lg_size_p(lg_size_p)
      )
    link_a_to_b
     (.w_clk_i(aclk_i)
      ,.w_reset_i(areset_i)
      ,.w_enq_i(alink_enq_li)
      ,.w_data_i(alink_cast_i.data)
      ,.w_full_o(alink_full_lo)

      ,.r_clk_i(bclk_i)
      ,.r_reset_i(breset_i)
      ,.r_deq_i(blink_deq_li)
      ,.r_data_o(blink_cast_o.data)
      ,.r_valid_o(blink_cast_o.v)
      );

  logic blink_full_lo;
  assign blink_cast_o.ready_and_rev = ~blink_full_lo;
  wire blink_enq_li = blink_cast_i.v & blink_cast_o.ready_and_rev;
  wire alink_deq_li = alink_cast_o.v & alink_cast_i.ready_and_rev;
  bsg_async_fifo
   #(.width_p(width_p)
     ,.lg_size_p(lg_size_p)
     )
   link_b_to_a
    (.w_clk_i(bclk_i)
     ,.w_reset_i(breset_i)
     ,.w_enq_i(blink_enq_li)
     ,.w_data_i(blink_cast_i.data)
     ,.w_full_o(blink_full_lo)

     ,.r_clk_i(aclk_i)
     ,.r_reset_i(areset_i)
     ,.r_deq_i(alink_deq_li)
     ,.r_data_o(alink_cast_o.data)
     ,.r_valid_o(alink_cast_o.v)
     );

endmodule

`BSG_ABSTRACT_MODULE(bsg_async_noc_link)

