
module bp_clint_node
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                core_clk_i
   , input                                              core_reset_i

   , input                                              mem_clk_i
   , input                                              mem_reset_i

   , input [mem_noc_cord_width_p-1:0]                   my_cord_i

   // Local interrupts
   , output [num_core_p-1:0]                            soft_irq_o
   , output [num_core_p-1:0]                            timer_irq_o
   , output [num_core_p-1:0]                            external_irq_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]         mem_cmd_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]        mem_cmd_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]         mem_resp_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]        mem_resp_link_o
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

// Core side links
mem_noc_ral_link_s clint_cmd_link_li, clint_cmd_link_lo;
mem_noc_ral_link_s clint_resp_link_li, clint_resp_link_lo;

  bp_clint
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)
  
     ,.my_cord_i(my_cord_i)
  
     ,.soft_irq_o(soft_irq_o)
     ,.timer_irq_o(timer_irq_o)
     ,.external_irq_o(external_irq_o)
  
     ,.cmd_link_i(clint_cmd_link_li)
     ,.cmd_link_o(clint_cmd_link_lo)
  
     ,.resp_link_i(clint_resp_link_li)
     ,.resp_link_o(clint_resp_link_lo)
     );

// Network side links
mem_noc_ral_link_s mem_cmd_link_li, mem_cmd_link_lo;
mem_noc_ral_link_s mem_resp_link_li, mem_resp_link_lo;

if (async_mem_clk_p == 1)
  begin : async_mem
    bsg_async_noc_link
     #(.width_p(coh_noc_flit_width_p)
       ,.lg_size_p(3)
       )
     mem_cmd_link
      (.aclk_i(core_clk_i)
       ,.areset_i(core_reset_i)

       ,.bclk_i(mem_clk_i)
       ,.breset_i(mem_reset_i)

       ,.alink_i(clint_cmd_link_lo)
       ,.alink_o(clint_cmd_link_li)

       ,.blink_i(mem_cmd_link_li)
       ,.blink_o(mem_cmd_link_lo)
       );

    bsg_async_noc_link
     #(.width_p(coh_noc_flit_width_p)
       ,.lg_size_p(3)
       )
     mem_resp_link
      (.aclk_i(core_clk_i)
       ,.areset_i(core_reset_i)

       ,.bclk_i(mem_clk_i)
       ,.breset_i(mem_reset_i)

       ,.alink_i(clint_resp_link_lo)
       ,.alink_o(clint_resp_link_li)

       ,.blink_i(mem_resp_link_li)
       ,.blink_o(mem_resp_link_lo)
       );
    end
  else
    begin : sync_mem
      assign mem_cmd_link_lo  = clint_cmd_link_lo;
      assign mem_resp_link_lo = clint_resp_link_lo;

      assign clint_cmd_link_li  = mem_cmd_link_li;
      assign clint_resp_link_li = mem_resp_link_li;
    end

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictXY | XY_Allow_S)
     )
   mem_cmd_router
   (.clk_i(mem_clk_i)
    ,.reset_i(mem_reset_i)
    ,.my_cord_i(my_cord_i)
    ,.link_i({mem_cmd_link_i, mem_cmd_link_lo})
    ,.link_o({mem_cmd_link_o, mem_cmd_link_li})
    );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(0)
     ,.routing_matrix_p(StrictXY | XY_Allow_S)
     )
   mem_resp_router
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)
     ,.my_cord_i(my_cord_i)
     ,.link_i({mem_resp_link_i, mem_resp_link_lo})
     ,.link_o({mem_resp_link_o, mem_resp_link_li})
     );

endmodule

