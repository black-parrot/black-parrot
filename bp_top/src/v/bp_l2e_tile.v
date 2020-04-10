
module bp_l2e_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // Memory side connection
   , input [io_noc_did_width_p-1:0]                           my_did_i
   , input [mem_noc_cord_width_p-1:0]                         my_cord_i

   // Connected to other tiles on east and west
   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_resp_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                    mem_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                   mem_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                    mem_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                   mem_resp_link_o
   );

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

// Cast the routing links
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

bp_coh_ready_and_link_s lce_req_link_cast_i, lce_req_link_cast_o;
bp_coh_ready_and_link_s lce_resp_link_cast_i, lce_resp_link_cast_o;
bp_coh_ready_and_link_s lce_cmd_link_cast_i, lce_cmd_link_cast_o;

assign lce_req_link_cast_i  = lce_req_link_i;
assign lce_cmd_link_cast_i  = lce_cmd_link_i;
assign lce_resp_link_cast_i = lce_resp_link_i;

assign lce_req_link_o  = lce_req_link_cast_o;
assign lce_cmd_link_o  = lce_cmd_link_cast_o;
assign lce_resp_link_o = lce_resp_link_cast_o;

// CCE connections
bp_lce_cce_req_s  cce_lce_req_li;
logic             cce_lce_req_v_li, cce_lce_req_yumi_lo;
bp_lce_cmd_s      cce_lce_cmd_lo;
logic             cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;
bp_lce_cce_resp_s cce_lce_resp_li;
logic             cce_lce_resp_v_li, cce_lce_resp_yumi_lo;

// Mem connections
bp_cce_mem_msg_s       cce_mem_cmd_lo;
logic                  cce_mem_cmd_v_lo, cce_mem_cmd_ready_li;
bp_cce_mem_msg_s       cce_mem_resp_li;
logic                  cce_mem_resp_v_li, cce_mem_resp_yumi_lo;

bp_cce_mem_msg_s       cache_mem_cmd_li;
logic                  cache_mem_cmd_v_li, cache_mem_cmd_ready_lo;
bp_cce_mem_msg_s       cache_mem_resp_lo;
logic                  cache_mem_resp_v_lo, cache_mem_resp_yumi_li;

bp_cce_mem_msg_s       cfg_mem_cmd_li;
logic                  cfg_mem_cmd_v_li, cfg_mem_cmd_ready_lo;
bp_cce_mem_msg_s       cfg_mem_resp_lo;
logic                  cfg_mem_resp_v_lo, cfg_mem_resp_yumi_li;
bp_cfg_bus_s cfg_bus_lo;
logic [cce_instr_width_p-1:0] cfg_cce_ucode_data_li;
bp_cfg_buffered
 #(.bp_params_p(bp_params_p))
 cfg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(cfg_mem_cmd_li)
   ,.mem_cmd_v_i(cfg_mem_cmd_v_li)
   ,.mem_cmd_ready_o(cfg_mem_cmd_ready_lo)

   ,.mem_resp_o(cfg_mem_resp_lo)
   ,.mem_resp_v_o(cfg_mem_resp_v_lo)
   ,.mem_resp_yumi_i(cfg_mem_resp_yumi_li)

   ,.cfg_bus_o(cfg_bus_lo)
   ,.did_i(my_did_i)
   ,.cord_i(my_cord_i)
   ,.irf_data_i()
   ,.npc_data_i()
   ,.csr_data_i()
   ,.priv_data_i()
   ,.cce_ucode_data_i(cfg_cce_ucode_data_li)
   );

bp_cce_wrapper
 #(.bp_params_p(bp_params_p))
 cce
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_lo)
   ,.cfg_cce_ucode_data_o(cfg_cce_ucode_data_li)

   ,.lce_req_i(cce_lce_req_li)
   ,.lce_req_v_i(cce_lce_req_v_li)
   ,.lce_req_yumi_o(cce_lce_req_yumi_lo)

   ,.lce_cmd_o(cce_lce_cmd_lo)
   ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready_li)

   ,.lce_resp_i(cce_lce_resp_li)
   ,.lce_resp_v_i(cce_lce_resp_v_li)
   ,.lce_resp_yumi_o(cce_lce_resp_yumi_lo)

   ,.mem_cmd_o(cce_mem_cmd_lo)
   ,.mem_cmd_v_o(cce_mem_cmd_v_lo)
   ,.mem_cmd_ready_i(cce_mem_cmd_ready_li)

   ,.mem_resp_i(cce_mem_resp_li)
   ,.mem_resp_v_i(cce_mem_resp_v_li)
   ,.mem_resp_yumi_o(cce_mem_resp_yumi_lo)
   );

`declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_req_packet_s);
`declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_width_lp, lce_cmd_packet_s);
`declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_resp_width_lp, lce_resp_packet_s);

bp_coh_ready_and_link_s cce_lce_req_link_li, cce_lce_req_link_lo;
bp_coh_ready_and_link_s cce_lce_cmd_link_li, cce_lce_cmd_link_lo;
bp_coh_ready_and_link_s cce_lce_resp_link_li, cce_lce_resp_link_lo;

  lce_req_packet_s cce_lce_req_packet_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_req_adapter_out
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_i(lce_req_link_i)
    ,.link_o(cce_lce_req_link_lo)

    ,.packet_o(cce_lce_req_packet_li)
    ,.v_o(cce_lce_req_v_li)
    ,.yumi_i(cce_lce_req_yumi_lo)
    );
  assign cce_lce_req_li = cce_lce_req_packet_li.payload;

  lce_cmd_packet_s cce_lce_cmd_packet_lo;
  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cmd_encode
    (.payload_i(cce_lce_cmd_lo)
     ,.packet_o(cce_lce_cmd_packet_lo)
     );

  bsg_wormhole_router_adapter_in
   #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cmd_adapter_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(cce_lce_cmd_packet_lo)
     ,.v_i(cce_lce_cmd_v_lo)
     ,.ready_o(cce_lce_cmd_ready_li)

     ,.link_i(cce_lce_cmd_link_li)
     ,.link_o(cce_lce_cmd_link_lo)
     );

  lce_resp_packet_s cce_lce_resp_packet_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p($bits(lce_resp_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_resp_adapter_out
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_i(lce_resp_link_i)
    ,.link_o(cce_lce_resp_link_lo)

    ,.packet_o(cce_lce_resp_packet_li)
    ,.v_o(cce_lce_resp_v_li)
    ,.yumi_i(cce_lce_resp_yumi_lo)
    );
  assign cce_lce_resp_li = cce_lce_resp_packet_li.payload;

  /* TODO: Extract local memory map to module */
  localparam cfg_device_id_lp   = 2;
  wire local_cmd_li    = (cce_mem_cmd_lo.addr < 32'h8000_0000);
  wire [3:0] device_li =  cce_mem_cmd_lo.addr[20+:4];

  assign cce_mem_cmd_ready_li = cache_mem_cmd_ready_lo & cfg_mem_cmd_ready_lo;

  assign cache_mem_cmd_li     = cce_mem_cmd_lo;
  assign cache_mem_cmd_v_li   = cce_mem_cmd_v_lo & ~local_cmd_li;

  assign cfg_mem_cmd_li       = cce_mem_cmd_lo;
  assign cfg_mem_cmd_v_li     = cce_mem_cmd_v_lo &  local_cmd_li & (device_li == 4'd1);

  bsg_arb_fixed
   #(.inputs_p(2)
     ,.lo_to_hi_p(1)
     )
   resp_arb
    (.ready_i(cce_mem_resp_yumi_lo)
     ,.reqs_i({cfg_mem_resp_v_lo, cache_mem_resp_v_lo})
     ,.grants_o({cfg_mem_resp_yumi_li, cache_mem_resp_yumi_li})
     );
  assign cce_mem_resp_v_li = cache_mem_resp_v_lo | cfg_mem_resp_v_lo;
  assign cce_mem_resp_li = cache_mem_resp_v_lo
                           ? cache_mem_resp_lo
                           : cfg_mem_resp_lo;

  bp_cce_mem_msg_s dma_mem_cmd_lo;
  logic dma_mem_cmd_v_lo, dma_mem_cmd_ready_li;
  bp_cce_mem_msg_s dma_mem_resp_li;
  logic dma_mem_resp_v_li, dma_mem_resp_ready_lo;
  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   l2s
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(cache_mem_cmd_li)
     ,.mem_cmd_v_i(cache_mem_cmd_v_li)
     ,.mem_cmd_ready_o(cache_mem_cmd_ready_lo)

     ,.mem_resp_o(cache_mem_resp_lo)
     ,.mem_resp_v_o(cache_mem_resp_v_lo)
     ,.mem_resp_yumi_i(cache_mem_resp_yumi_li)

     ,.mem_cmd_o(dma_mem_cmd_lo)
     ,.mem_cmd_v_o(dma_mem_cmd_v_lo)
     ,.mem_cmd_yumi_i(dma_mem_cmd_ready_li & dma_mem_cmd_v_lo)

     ,.mem_resp_i(dma_mem_resp_li)
     ,.mem_resp_v_i(dma_mem_resp_v_li)
     ,.mem_resp_ready_o(dma_mem_resp_ready_lo)
     );

  localparam dram_y_cord_lp = ic_y_dim_p + cc_y_dim_p + mc_y_dim_p;
  wire [io_noc_did_width_p-1:0]  dst_did_li  = my_did_i;
  wire [mem_noc_cord_width_p-1:0] dst_cord_li = 
      {mem_noc_y_cord_width_p'(dram_y_cord_lp), my_cord_i[0+:mem_noc_x_cord_width_p]};
  bp_me_cce_to_wormhole_link_master
   #(.bp_params_p(bp_params_p))
   dma_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(dma_mem_cmd_lo)
     ,.mem_cmd_v_i(dma_mem_cmd_v_lo)
     ,.mem_cmd_ready_o(dma_mem_cmd_ready_li)

     ,.mem_resp_o(dma_mem_resp_li)
     ,.mem_resp_v_o(dma_mem_resp_v_li)
     ,.mem_resp_yumi_i(dma_mem_resp_ready_lo & dma_mem_resp_v_li)

     ,.my_did_i(my_did_i)
     ,.my_cord_i(my_cord_i)
     ,.dst_did_i(dst_did_li)
     ,.dst_cord_i(dst_cord_li)

     ,.cmd_link_i(mem_cmd_link_i)
     ,.cmd_link_o(mem_cmd_link_o)

     ,.resp_link_i(mem_resp_link_i)
     ,.resp_link_o(mem_resp_link_o)
     );

endmodule

