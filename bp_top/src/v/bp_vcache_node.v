
module bp_vcache_node
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
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                core_clk_i
   , input                                              core_reset_i

   , input                                              mem_clk_i
   , input                                              mem_reset_i

   , input [mem_noc_cord_width_p-1:0]                   my_cord_i

   , input [S:W][mem_noc_ral_link_width_lp-1:0]         mem_cmd_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]        mem_cmd_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]         mem_resp_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]        mem_resp_link_o
   // DMC controller ports
   // input
   // input
   // output
   // output
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

// Core side links
mem_noc_ral_link_s vcache_cmd_link_li, vcache_cmd_link_lo;
mem_noc_ral_link_s vcache_resp_link_li, vcache_resp_link_lo;


  // mem_link_to_vcache
  //
  //

  // vcache
  //
  //
  
  // TODO: remove stubs
  assign vcache_cmd_link_lo  = '0;
  assign vcache_resp_link_lo = '0;

// Network side links
mem_noc_ral_link_s mem_cmd_link_li, mem_cmd_link_lo;
mem_noc_ral_link_s mem_resp_link_li, mem_resp_link_lo;

if (async_mem_clk_p == 1)
  begin : async_mem
    logic vcache_cmd_full_lo;
    assign vcache_cmd_link_li.ready_and_rev = ~vcache_cmd_full_lo;
    wire vcache_cmd_enq_li = vcache_cmd_link_lo.v & vcache_cmd_link_li.ready_and_rev;
    wire mem_cmd_deq_li = mem_cmd_link_lo.v & mem_cmd_link_li.ready_and_rev;
    bsg_async_fifo
     #(.lg_size_p(3)
       ,.width_p(mem_noc_flit_width_p)
       )
     mem_cmd_link_async_fifo_to_rtr
      (.w_clk_i(core_clk_i)
       ,.w_reset_i(core_reset_i)
       ,.w_enq_i(vcache_cmd_enq_li)
       ,.w_data_i(vcache_cmd_link_lo.data)
       ,.w_full_o(vcache_cmd_full_lo)

       ,.r_clk_i(mem_clk_i)
       ,.r_reset_i(mem_reset_i)
       ,.r_deq_i(mem_cmd_deq_li)
       ,.r_data_o(mem_cmd_link_lo.data)
       ,.r_valid_o(mem_cmd_link_lo.v)
       );

    logic vcache_resp_full_lo;
    assign vcache_resp_link_li.ready_and_rev = ~vcache_resp_full_lo;
    wire vcache_resp_enq_li = vcache_resp_link_lo.v & vcache_resp_link_li.ready_and_rev;
    wire mem_resp_deq_li = mem_resp_link_lo.v & mem_resp_link_li.ready_and_rev;
    bsg_async_fifo
     #(.lg_size_p(3)
       ,.width_p(mem_noc_flit_width_p)
       )
     mem_resp_link_async_fifo_to_rtr
      (.w_clk_i(core_clk_i)
       ,.w_reset_i(core_reset_i)
       ,.w_enq_i(vcache_resp_enq_li)
       ,.w_data_i(vcache_resp_link_lo.data)
       ,.w_full_o(vcache_resp_full_lo)
    
       ,.r_clk_i(mem_clk_i)
       ,.r_reset_i(mem_reset_i)
       ,.r_deq_i(mem_resp_deq_li)
       ,.r_data_o(mem_resp_link_lo.data)
       ,.r_valid_o(mem_resp_link_lo.v)
       );
    
    logic mem_cmd_full_lo;
    assign mem_cmd_link_lo.ready_and_rev = ~mem_cmd_full_lo;
    wire mem_cmd_enq_li = mem_cmd_link_li.v & mem_cmd_link_lo.ready_and_rev;
    wire vcache_cmd_deq_li = vcache_cmd_link_li.v & vcache_cmd_link_lo.ready_and_rev;
    bsg_async_fifo
     #(.lg_size_p(3)
       ,.width_p(mem_noc_flit_width_p)
       )
     mem_cmd_link_async_fifo_from_rtr
      (.w_clk_i(mem_clk_i)
       ,.w_reset_i(mem_reset_i)
       ,.w_enq_i(mem_cmd_enq_li)
       ,.w_data_i(mem_cmd_link_li.data)
       ,.w_full_o(mem_cmd_full_lo)
    
       ,.r_clk_i(core_clk_i)
       ,.r_reset_i(core_reset_i)
       ,.r_deq_i(vcache_cmd_deq_li)
       ,.r_data_o(vcache_cmd_link_li.data)
       ,.r_valid_o(vcache_cmd_link_li.v)
       );

    logic mem_resp_full_lo;
    assign mem_resp_link_lo.ready_and_rev = ~mem_resp_full_lo;
    wire mem_resp_enq_li = mem_resp_link_li.v & mem_resp_link_lo.ready_and_rev;
    wire vcache_resp_deq_li = vcache_resp_link_li.v & vcache_resp_link_lo.ready_and_rev;
    bsg_async_fifo
     #(.lg_size_p(3)
       ,.width_p(mem_noc_flit_width_p)
       )
     mem_resp_link_async_fifo_from_rtr
      (.w_clk_i(mem_clk_i)
       ,.w_reset_i(mem_reset_i)
       ,.w_enq_i(mem_resp_enq_li)
       ,.w_data_i(mem_resp_link_li.data)
       ,.w_full_o(mem_resp_full_lo)
    
       ,.r_clk_i(core_clk_i)
       ,.r_reset_i(core_reset_i)
       ,.r_deq_i(vcache_resp_deq_li)
       ,.r_data_o(vcache_resp_link_li.data)
       ,.r_valid_o(vcache_resp_link_li.v)
       );
    end
  else
    begin : sync_mem
      assign mem_cmd_link_lo  = vcache_cmd_link_lo;
      assign mem_resp_link_lo = vcache_resp_link_lo;

      assign vcache_cmd_link_li  = mem_cmd_link_li;
      assign vcache_resp_link_li = mem_resp_link_li;
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

