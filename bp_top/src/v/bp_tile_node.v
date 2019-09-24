/**
 *
 * bp_tile_node.v
 *
 */

module bp_tile_node
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   )
  (input                                         core_clk_i
   , input                                       core_reset_i

   , input                                       coh_clk_i
   , input                                       coh_reset_i

   , input                                       mem_clk_i
   , input                                       mem_reset_i

   , input [proc_cfg_width_lp-1:0]               proc_cfg_i

   // Memory side connection
   , input [mem_noc_cord_width_p-1:0]            my_cord_i
   , input [mem_noc_cid_width_p-1:0]             my_cid_i
   , input [mem_noc_cord_width_p-1:0]            dram_cord_i
   , input [mem_noc_cord_width_p-1:0]            mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]            host_cord_i

   // Config channel
   , input                                       cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                cfg_addr_i
   , input [cfg_data_width_p-1:0]                cfg_data_i

   // Interrupts
   , input                                       timer_int_i
   , input                                       software_int_i
   , input                                       external_int_i

   // Connected to other tiles on east and west
   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_req_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_req_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_cmd_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_cmd_link_o

   , input [S:W][coh_noc_ral_link_width_lp-1:0]  coh_lce_resp_link_i
   , output [S:W][coh_noc_ral_link_width_lp-1:0] coh_lce_resp_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0] mem_cmd_link_o

   , input [S:W][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_i
   , output [S:W][mem_noc_ral_link_width_lp-1:0] mem_resp_link_o
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

bp_proc_cfg_s proc_cfg_cast_i;
assign proc_cfg_cast_i = proc_cfg_i;

// Declare the routing links
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

// Tile-side coherence connections
bp_coh_ready_and_link_s core_lce_req_link_li, core_lce_req_link_lo;
bp_coh_ready_and_link_s core_lce_cmd_link_li, core_lce_cmd_link_lo;
bp_coh_ready_and_link_s core_lce_resp_link_li, core_lce_resp_link_lo;

// Tile side membus connections
bp_mem_ready_and_link_s core_mem_cmd_link_li, core_mem_cmd_link_lo;
bp_mem_ready_and_link_s core_mem_resp_link_li, core_mem_resp_link_lo;

  bp_tile
   #(.cfg_p(cfg_p))
   tile
    (.clk_i(core_clk_i)
     ,.reset_i(core_reset_i)

     ,.proc_cfg_i(proc_cfg_i)

     // CCE-MEM IF
     ,.my_cord_i(my_cord_i)
     ,.my_cid_i('0)
     ,.dram_cord_i(dram_cord_i)
     ,.mmio_cord_i(mmio_cord_i)
     ,.host_cord_i(host_cord_i)

     ,.cfg_w_v_i(cfg_w_v_i)
     ,.cfg_addr_i(cfg_addr_i)
     ,.cfg_data_i(cfg_data_i)

     ,.timer_int_i(timer_int_i)
     ,.software_int_i(software_int_i)
     ,.external_int_i(external_int_i)

     ,.lce_req_link_i(core_lce_req_link_li)
     ,.lce_req_link_o(core_lce_req_link_lo)

     ,.lce_cmd_link_i(core_lce_cmd_link_li)
     ,.lce_cmd_link_o(core_lce_cmd_link_lo)

     ,.lce_resp_link_i(core_lce_resp_link_li)
     ,.lce_resp_link_o(core_lce_resp_link_lo)

     ,.cmd_link_i(core_mem_cmd_link_li)
     ,.resp_link_i(core_mem_resp_link_li)

     ,.cmd_link_o(core_mem_cmd_link_lo)
     ,.resp_link_o(core_mem_resp_link_lo)
     );

// Network-side coherence connections
bp_coh_ready_and_link_s coh_lce_req_link_li, coh_lce_req_link_lo;
bp_coh_ready_and_link_s coh_lce_cmd_link_li, coh_lce_cmd_link_lo;
bp_coh_ready_and_link_s coh_lce_resp_link_li, coh_lce_resp_link_lo;

// Network side membus connections
bp_mem_ready_and_link_s mem_cmd_link_li, mem_cmd_link_lo;
bp_mem_ready_and_link_s mem_resp_link_li, mem_resp_link_lo;

  if (async_coh_clk_p == 1)
    begin : coh_async
      logic core_lce_req_full_lo;
      assign core_lce_req_link_li.ready_and_rev = ~core_lce_req_full_lo;
      wire core_lce_req_enq_li = core_lce_req_link_lo.v & core_lce_req_link_li.ready_and_rev;
      wire coh_lce_req_deq_li = coh_lce_req_link_li.v & coh_lce_req_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(coh_noc_flit_width_p)
         )
       lce_req_link_async_fifo_to_rtr
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_i)
         ,.w_enq_i(core_lce_req_enq_li)
         ,.w_data_i(core_lce_req_link_lo.data)
         ,.w_full_o(core_lce_req_full_lo)

         ,.r_clk_i(coh_clk_i)
         ,.r_reset_i(coh_reset_i)
         ,.r_deq_i(coh_lce_req_deq_li)
         ,.r_data_o(coh_lce_req_link_li.data)
         ,.r_valid_o(coh_lce_req_link_li.v)
         );

      logic core_lce_cmd_full_lo;
      assign core_lce_cmd_link_li.ready_and_rev = ~core_lce_cmd_full_lo;
      wire core_lce_cmd_enq_li = core_lce_cmd_link_lo.v & core_lce_cmd_link_li.ready_and_rev;
      wire coh_lce_cmd_deq_li = coh_lce_cmd_link_li.v & coh_lce_cmd_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(coh_noc_flit_width_p)
         )
       lce_cmd_link_async_fifo_to_rtr
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_i)
         ,.w_enq_i(core_lce_cmd_enq_li)
         ,.w_data_i(core_lce_cmd_link_lo.data)
         ,.w_full_o(core_lce_cmd_full_lo)

         ,.r_clk_i(coh_clk_i)
         ,.r_reset_i(coh_reset_i)
         ,.r_deq_i(coh_lce_cmd_deq_li)
         ,.r_data_o(coh_lce_cmd_link_li.data)
         ,.r_valid_o(coh_lce_cmd_link_li.v)
         );

      logic core_lce_resp_full_lo;
      assign core_lce_resp_link_li.ready_and_rev = ~core_lce_resp_full_lo;
      wire core_lce_resp_enq_li = core_lce_resp_link_lo.v & core_lce_resp_link_li.ready_and_rev;
      wire coh_lce_resp_deq_li = coh_lce_resp_link_li.v & coh_lce_resp_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(coh_noc_flit_width_p)
         )
       lce_resp_link_async_fifo_to_rtr
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_i)
         ,.w_enq_i(core_lce_resp_enq_li)
         ,.w_data_i(core_lce_resp_link_lo.data)
         ,.w_full_o(core_lce_resp_full_lo)

         ,.r_clk_i(coh_clk_i)
         ,.r_reset_i(coh_reset_i)
         ,.r_deq_i(coh_lce_resp_deq_li)
         ,.r_data_o(coh_lce_resp_link_li.data)
         ,.r_valid_o(coh_lce_resp_link_li.v)
         );

      logic coh_lce_req_full_lo;
      assign coh_lce_req_link_li.ready_and_rev = ~coh_lce_req_full_lo;
      wire coh_lce_req_enq_li = coh_lce_req_link_lo.v & coh_lce_req_link_li.ready_and_rev;
      wire core_lce_req_deq_li = core_lce_req_link_li.v & core_lce_req_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(coh_noc_flit_width_p)
         )
       lce_req_link_async_fifo_from_rtr
        (.w_clk_i(coh_clk_i)
         ,.w_reset_i(coh_reset_i)
         ,.w_enq_i(coh_lce_req_enq_li)
         ,.w_data_i(coh_lce_req_link_lo.data)
         ,.w_full_o(coh_lce_req_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_i)
         ,.r_deq_i(core_lce_req_deq_li)
         ,.r_data_o(core_lce_req_link_li.data)
         ,.r_valid_o(core_lce_req_link_li.v)
         );

      logic coh_lce_cmd_full_lo;
      assign coh_lce_cmd_link_li.ready_and_rev = ~coh_lce_cmd_full_lo;
      wire coh_lce_cmd_enq_li = coh_lce_cmd_link_lo.v & coh_lce_cmd_link_li.ready_and_rev;
      wire core_lce_cmd_deq_li = core_lce_cmd_link_li.v & core_lce_cmd_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(coh_noc_flit_width_p)
         )
       lce_cmd_link_async_fifo_from_rtr
        (.w_clk_i(coh_clk_i)
         ,.w_reset_i(coh_reset_i)
         ,.w_enq_i(coh_lce_cmd_enq_li)
         ,.w_data_i(coh_lce_cmd_link_lo.data)
         ,.w_full_o(coh_lce_cmd_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_i)
         ,.r_deq_i(core_lce_cmd_deq_li)
         ,.r_data_o(core_lce_cmd_link_li.data)
         ,.r_valid_o(core_lce_cmd_link_li.v)
         );

      logic coh_lce_resp_full_lo;
      assign coh_lce_resp_link_li.ready_and_rev = ~coh_lce_resp_full_lo;
      wire coh_lce_resp_enq_li = coh_lce_resp_link_lo.v & coh_lce_resp_link_li.ready_and_rev;
      wire core_lce_resp_deq_li = core_lce_resp_link_li.v & core_lce_resp_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(coh_noc_flit_width_p)
         )
       lce_resp_link_async_fifo_from_rtr
        (.w_clk_i(coh_clk_i)
         ,.w_reset_i(coh_reset_i)
         ,.w_enq_i(coh_lce_resp_enq_li)
         ,.w_data_i(coh_lce_resp_link_lo.data)
         ,.w_full_o(coh_lce_resp_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_i)
         ,.r_deq_i(core_lce_resp_deq_li)
         ,.r_data_o(core_lce_resp_link_li.data)
         ,.r_valid_o(core_lce_resp_link_li.v)
         );
    end
  else
    begin : coh_sync
      assign coh_lce_req_link_li  = core_lce_req_link_lo;
      assign coh_lce_cmd_link_li  = core_lce_cmd_link_lo;
      assign coh_lce_resp_link_li = core_lce_resp_link_lo;

      assign core_lce_req_link_li  = coh_lce_req_link_lo;
      assign core_lce_cmd_link_li  = coh_lce_cmd_link_lo;
      assign core_lce_resp_link_li = coh_lce_resp_link_lo;
    end

  if (async_mem_clk_p == 1)
    begin : mem_async
      logic core_mem_cmd_full_lo;
      assign core_mem_cmd_link_li.ready_and_rev = ~core_mem_cmd_full_lo;
      wire core_mem_cmd_enq_li = core_mem_cmd_link_lo.v & core_mem_cmd_link_li.ready_and_rev;
      wire mem_cmd_deq_li = mem_cmd_link_li.v & mem_cmd_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(mem_noc_flit_width_p)
         )
       mem_cmd_link_async_fifo_to_rtr
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_i)
         ,.w_enq_i(core_mem_cmd_enq_li)
         ,.w_data_i(core_mem_cmd_link_lo.data)
         ,.w_full_o(core_mem_cmd_full_lo)

         ,.r_clk_i(mem_clk_i)
         ,.r_reset_i(mem_reset_i)
         ,.r_deq_i(mem_cmd_deq_li)
         ,.r_data_o(mem_cmd_link_li.data)
         ,.r_valid_o(mem_cmd_link_li.v)
         );

      logic core_mem_resp_full_lo;
      assign core_mem_resp_link_li.ready_and_rev = ~core_mem_resp_full_lo;
      wire core_mem_resp_enq_li = core_mem_resp_link_lo.v & core_mem_resp_link_li.ready_and_rev;
      wire mem_resp_deq_li = mem_resp_link_li.v & mem_resp_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(mem_noc_flit_width_p)
         )
       mem_resp_link_async_fifo_to_rtr
        (.w_clk_i(core_clk_i)
         ,.w_reset_i(core_reset_i)
         ,.w_enq_i(core_mem_resp_enq_li)
         ,.w_data_i(core_mem_resp_link_lo.data)
         ,.w_full_o(core_mem_resp_full_lo)

         ,.r_clk_i(mem_clk_i)
         ,.r_reset_i(mem_reset_i)
         ,.r_deq_i(mem_resp_deq_li)
         ,.r_data_o(mem_resp_link_li.data)
         ,.r_valid_o(mem_resp_link_li.v)
         );

      logic mem_cmd_full_lo;
      assign mem_cmd_link_li.ready_and_rev = ~mem_cmd_full_lo;
      wire mem_cmd_enq_li = mem_cmd_link_lo.v & mem_cmd_link_li.ready_and_rev;
      wire core_mem_cmd_deq_li = core_mem_cmd_link_li.v & core_mem_cmd_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(mem_noc_flit_width_p)
         )
       mem_cmd_link_async_fifo_from_rtr
        (.w_clk_i(mem_clk_i)
         ,.w_reset_i(mem_reset_i)
         ,.w_enq_i(mem_cmd_enq_li)
         ,.w_data_i(mem_cmd_link_lo.data)
         ,.w_full_o(mem_cmd_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_i)
         ,.r_deq_i(core_mem_cmd_deq_li)
         ,.r_data_o(core_mem_cmd_link_li.data)
         ,.r_valid_o(core_mem_cmd_link_li.v)
         );

      logic mem_resp_full_lo;
      assign mem_resp_link_li.ready_and_rev = ~mem_resp_full_lo;
      wire mem_resp_enq_li = mem_resp_link_lo.v & mem_resp_link_li.ready_and_rev;
      wire core_mem_resp_deq_li = core_mem_resp_link_li.v & core_mem_resp_link_lo.ready_and_rev;
      bsg_async_fifo
       #(.lg_size_p(3)
         ,.width_p(mem_noc_flit_width_p)
         )
       mem_resp_link_async_fifo_from_rtr
        (.w_clk_i(mem_clk_i)
         ,.w_reset_i(mem_reset_i)
         ,.w_enq_i(mem_resp_enq_li)
         ,.w_data_i(mem_resp_link_lo.data)
         ,.w_full_o(mem_resp_full_lo)

         ,.r_clk_i(core_clk_i)
         ,.r_reset_i(core_reset_i)
         ,.r_deq_i(core_mem_resp_deq_li)
         ,.r_data_o(core_mem_resp_link_li.data)
         ,.r_valid_o(core_mem_resp_link_li.v)
         );

    end
  else
    begin : io_sync
      assign mem_cmd_link_li  = core_mem_cmd_link_lo;
      assign mem_resp_link_li = core_mem_resp_link_lo;

      assign core_mem_cmd_link_li  = mem_cmd_link_lo;
      assign core_mem_resp_link_li = mem_resp_link_lo;
    end

  logic [coh_noc_cord_width_p-1:0] lce_cord_li;
  bp_me_lce_id_to_cord
   #(.cfg_p(cfg_p))
   router_cord
    (.lce_id_i(proc_cfg_cast_i.icache_id)
     ,.lce_cord_o(lce_cord_li)
     ,.lce_cid_o()
     );

  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   lce_req_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.link_i({coh_lce_req_link_i, coh_lce_req_link_li})
     ,.link_o({coh_lce_req_link_o, coh_lce_req_link_lo})

     ,.my_cord_i(lce_cord_li)
     );

  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   lce_cmd_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.link_i({coh_lce_cmd_link_i, coh_lce_cmd_link_li})
     ,.link_o({coh_lce_cmd_link_o, coh_lce_cmd_link_lo})

     ,.my_cord_i(lce_cord_li)
     );

  bsg_wormhole_router
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.dims_p(coh_noc_dims_p)
     ,.cord_markers_pos_p(coh_noc_cord_markers_pos_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   lce_resp_router
    (.clk_i(coh_clk_i)
     ,.reset_i(coh_reset_i)

     ,.link_i({coh_lce_resp_link_i, coh_lce_resp_link_li})
     ,.link_o({coh_lce_resp_link_o, coh_lce_resp_link_lo})

     ,.my_cord_i(lce_cord_li)
     );

  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   mem_cmd_router 
   (.clk_i(mem_clk_i)
    ,.reset_i(mem_reset_i)
    ,.my_cord_i(my_cord_i)
    ,.link_i({mem_cmd_link_i, mem_cmd_link_li})
    ,.link_o({mem_cmd_link_o, mem_cmd_link_lo})
    );
  
  bsg_wormhole_router
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.dims_p(mem_noc_dims_p)
     ,.cord_markers_pos_p(mem_noc_cord_markers_pos_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   mem_resp_router 
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)
     ,.my_cord_i(my_cord_i)
     ,.link_i({mem_resp_link_i, mem_resp_link_li})
     ,.link_o({mem_resp_link_o, mem_resp_link_lo})
     );

endmodule

