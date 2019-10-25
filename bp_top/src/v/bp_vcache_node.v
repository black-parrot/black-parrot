
module bp_vcache_node
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   , localparam bsg_cache_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(vcache_addr_width_p)
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
   , output logic [bsg_cache_dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic dma_pkt_v_o
   , input dma_pkt_yumi_i
     
   , input [dword_width_p-1:0] dma_data_i
   , input dma_data_v_i
   , output logic dma_data_ready_o
     
   , output logic [dword_width_p-1:0] dma_data_o
   , output logic dma_data_v_o
   , input dma_data_yumi_i
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

// Core side links
mem_noc_ral_link_s vcache_cmd_link_li, vcache_cmd_link_lo;
mem_noc_ral_link_s vcache_resp_link_li, vcache_resp_link_lo;


  // mem_link_to_vcache
  //
  //
bp_cce_mem_msg_s       mem_resp_lo;
logic                  mem_resp_v_lo, mem_resp_ready_li;
bp_cce_mem_msg_s       mem_cmd_li;
logic                  mem_cmd_v_li, mem_cmd_yumi_lo;
  
bp_me_cce_to_wormhole_link_client
 #(.bp_params_p(bp_params_p))
  client_link
  (.clk_i(core_clk_i)
  ,.reset_i(core_reset_i)

  ,.mem_cmd_o(mem_cmd_li)
  ,.mem_cmd_v_o(mem_cmd_v_li)
  ,.mem_cmd_yumi_i(mem_cmd_yumi_lo)

  ,.mem_resp_i(mem_resp_lo)
  ,.mem_resp_v_i(mem_resp_v_lo)
  ,.mem_resp_ready_o(mem_resp_ready_li)

  ,.my_cord_i(my_cord_i)
  ,.my_cid_i('0)
     
  ,.cmd_link_i(vcache_cmd_link_li)
  ,.cmd_link_o(vcache_cmd_link_lo)

  ,.resp_link_i(vcache_resp_link_li)
  ,.resp_link_o(vcache_resp_link_lo)
  );
  
`declare_bsg_cache_pkt_s(vcache_addr_width_p, dword_width_p);
bsg_cache_pkt_s cache_pkt;
logic cache_v_li;
logic cache_ready_lo;
logic [dword_width_p-1:0] cache_data_lo;
logic cache_v_lo;
logic cache_yumi_li;

bp_me_cce_to_cache
  #(.bp_params_p(bp_params_p)
    ,.sets_p(vcache_sets_p)
    ,.ways_p(vcache_ways_p)
  )
cce_to_cache
  (.clk_i(core_clk_i)
    ,.reset_i(core_reset_i)

    ,.mem_cmd_i(mem_cmd_li)
    ,.mem_cmd_v_i(mem_cmd_v_li)
    ,.mem_cmd_yumi_o(mem_cmd_yumi_lo)
    
    ,.mem_resp_o(mem_resp_lo)
    ,.mem_resp_v_o(mem_resp_v_lo)
    ,.mem_resp_ready_i(mem_resp_ready_li)

    ,.cache_pkt_o(cache_pkt)
    ,.v_o(cache_v_li)
    ,.ready_i(cache_ready_lo)
  
    ,.data_i(cache_data_lo)
    ,.v_i(cache_v_lo)
    ,.yumi_o(cache_yumi_li)
  );

  // vcache
  //
  //
bsg_cache #(.addr_width_p(vcache_addr_width_p)
           ,.data_width_p(dword_width_p)
           ,.block_size_in_words_p(cce_block_width_p/dword_width_p)
           ,.sets_p(vcache_sets_p)
           ,.ways_p(vcache_ways_p)
           )
  cache
    (.clk_i(core_clk_i)
    ,.reset_i(core_reset_i)
    
    ,.cache_pkt_i(cache_pkt)
    ,.v_i(cache_v_li)
    ,.ready_o(cache_ready_lo)
    ,.data_o(cache_data_lo)
    ,.v_o(cache_v_lo)
    ,.yumi_i(cache_yumi_li)
    
    ,.dma_pkt_o(dma_pkt_o)
    ,.dma_pkt_v_o(dma_pkt_v_o)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_i)
    ,.dma_data_i(dma_data_i)
    ,.dma_data_v_i(dma_data_v_i)
    ,.dma_data_ready_o(dma_data_ready_o)
    ,.dma_data_o(dma_data_o)
    ,.dma_data_v_o(dma_data_v_o)
    ,.dma_data_yumi_i(dma_data_yumi_i)
    
    ,.v_we_o()
    );

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
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
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
     ,.reverse_order_p(1)
     ,.routing_matrix_p(StrictYX)
     )
   mem_resp_router
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)
     ,.my_cord_i(my_cord_i)
     ,.link_i({mem_resp_link_i, mem_resp_link_lo})
     ,.link_o({mem_resp_link_o, mem_resp_link_li})
     );

endmodule

