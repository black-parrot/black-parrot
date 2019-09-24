
module bp_mmio_node
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                           core_clk_i
   , input                                         core_reset_i

   , input                                         mem_clk_i
   , input                                         mem_reset_i

   , input [mem_noc_cord_width_p-1:0]              my_cord_i
   , input [mem_noc_cid_width_p-1:0]               my_cid_i

   // Core config link
   , output [num_core_p-1:0]                       cfg_w_v_o
   , output [num_core_p-1:0][cfg_addr_width_p-1:0] cfg_addr_o
   , output [num_core_p-1:0][cfg_data_width_p-1:0] cfg_data_o

   // Local interrupts
   , output [num_core_p-1:0]                       soft_irq_o
   , output [num_core_p-1:0]                       timer_irq_o
   , output [num_core_p-1:0]                       external_irq_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]    mem_cmd_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]   mem_cmd_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]    mem_resp_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0]   mem_resp_link_o
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

// Core side links
mem_noc_ral_link_s mmio_cmd_link_li, mmio_cmd_link_lo;
mem_noc_ral_link_s mmio_resp_link_li, mmio_resp_link_lo;

  bp_mmio_enclave
   #(.cfg_p(cfg_p))
   mmio
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)
  
     ,.my_cord_i(my_cord_i)
     ,.my_cid_i(my_cid_i)
  
     ,.cfg_w_v_o(cfg_w_v_o)
     ,.cfg_addr_o(cfg_addr_o)
     ,.cfg_data_o(cfg_data_o)
  
     ,.soft_irq_o(soft_irq_o)
     ,.timer_irq_o(timer_irq_o)
     ,.external_irq_o(external_irq_o)
  
     ,.cmd_link_i(mmio_cmd_link_li)
     ,.cmd_link_o(mmio_cmd_link_lo)
  
     ,.resp_link_i(mmio_resp_link_li)
     ,.resp_link_o(mmio_resp_link_lo)
     );

// Network side links
mem_noc_ral_link_s mem_cmd_link_li, mem_cmd_link_lo;
mem_noc_ral_link_s mem_resp_link_li, mem_resp_link_lo;

if (async_mem_clk_p == 1)
  begin : async_mem
    logic mmio_cmd_full_lo;
    assign mmio_cmd_link_li.ready_and_rev = ~mmio_cmd_full_lo;
    wire mmio_cmd_enq_li = mmio_cmd_link_lo.v & mmio_cmd_link_li.ready_and_rev;
    wire mem_cmd_deq_li = mem_cmd_link_lo.v & mem_cmd_link_li.ready_and_rev;
    bsg_async_fifo
     #(.lg_size_p(3)
       ,.width_p(mem_noc_flit_width_p)
       )
     mem_cmd_link_async_fifo_to_rtr
      (.w_clk_i(core_clk_i)
       ,.w_reset_i(core_reset_i)
       ,.w_enq_i(mmio_cmd_enq_li)
       ,.w_data_i(mmio_cmd_link_lo.data)
       ,.w_full_o(mmio_cmd_full_lo)

       ,.r_clk_i(mem_clk_i)
       ,.r_reset_i(mem_reset_i)
       ,.r_deq_i(mem_cmd_deq_li)
       ,.r_data_o(mem_cmd_link_lo.data)
       ,.r_valid_o(mem_cmd_link_lo.v)
       );

    logic mmio_resp_full_lo;
    assign mmio_resp_link_li.ready_and_rev = ~mmio_resp_full_lo;
    wire mmio_resp_enq_li = mmio_resp_link_lo.v & mmio_resp_link_li.ready_and_rev;
    wire mem_resp_deq_li = mem_resp_link_lo.v & mem_resp_link_li.ready_and_rev;
    bsg_async_fifo
     #(.lg_size_p(3)
       ,.width_p(mem_noc_flit_width_p)
       )
     mem_resp_link_async_fifo_to_rtr
      (.w_clk_i(core_clk_i)
       ,.w_reset_i(core_reset_i)
       ,.w_enq_i(mmio_resp_enq_li)
       ,.w_data_i(mmio_resp_link_lo.data)
       ,.w_full_o(mmio_resp_full_lo)
    
       ,.r_clk_i(mem_clk_i)
       ,.r_reset_i(mem_reset_i)
       ,.r_deq_i(mem_resp_deq_li)
       ,.r_data_o(mem_resp_link_lo.data)
       ,.r_valid_o(mem_resp_link_lo.v)
       );
    
    logic mem_cmd_full_lo;
    assign mem_cmd_link_lo.ready_and_rev = ~mem_cmd_full_lo;
    wire mem_cmd_enq_li = mem_cmd_link_li.v & mem_cmd_link_lo.ready_and_rev;
    wire mmio_cmd_deq_li = mmio_cmd_link_li.v & mmio_cmd_link_lo.ready_and_rev;
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
       ,.r_deq_i(mmio_cmd_deq_li)
       ,.r_data_o(mmio_cmd_link_li.data)
       ,.r_valid_o(mmio_cmd_link_li.v)
       );

    logic mem_resp_full_lo;
    assign mem_resp_link_lo.ready_and_rev = ~mem_resp_full_lo;
    wire mem_resp_enq_li = mem_resp_link_li.v & mem_resp_link_lo.ready_and_rev;
    wire mmio_resp_deq_li = mmio_resp_link_li.v & mmio_resp_link_lo.ready_and_rev;
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
       ,.r_deq_i(mmio_resp_deq_li)
       ,.r_data_o(mmio_resp_link_li.data)
       ,.r_valid_o(mmio_resp_link_li.v)
       );
    end
  else
    begin : sync_mem
      assign mem_cmd_link_lo  = mmio_cmd_link_lo;
      assign mem_resp_link_lo = mmio_resp_link_lo;

      assign mmio_cmd_link_li  = mem_cmd_link_li;
      assign mmio_resp_link_li = mem_resp_link_li;
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

