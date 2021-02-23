/**
 *
 * bp_l2e_tile.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_l2e_tile
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)

    , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // Memory side connection
   , input [io_noc_did_width_p-1:0]                           my_did_i
   , input [coh_noc_cord_width_p-1:0]                         my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_resp_link_o

   , output [mem_noc_ral_link_width_lp-1:0]                   mem_cmd_link_o
   , input [mem_noc_ral_link_width_lp-1:0]                    mem_resp_link_i
   );

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);

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
  bp_bedrock_lce_req_msg_s cce_lce_req_li;
  logic cce_lce_req_v_li, cce_lce_req_yumi_lo;
  bp_bedrock_lce_cmd_msg_s cce_lce_cmd_lo;
  logic cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;
  bp_bedrock_lce_resp_msg_s cce_lce_resp_li;
  logic cce_lce_resp_v_li, cce_lce_resp_yumi_lo;

  // Mem connections
  bp_bedrock_cce_mem_msg_s cce_mem_cmd_lo;
  logic cce_mem_cmd_v_lo, cce_mem_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s cce_mem_resp_li;
  logic cce_mem_resp_v_li, cce_mem_resp_yumi_lo;

  bp_bedrock_cce_mem_msg_s loopback_mem_cmd_li;
  bp_bedrock_xce_mem_msg_s loopback_mem_cmd;
  logic loopback_mem_cmd_v_li, loopback_mem_cmd_ready_lo;
  bp_bedrock_cce_mem_msg_s loopback_mem_resp_lo;
  bp_bedrock_xce_mem_msg_s loopback_mem_resp;
  logic loopback_mem_resp_v_lo, loopback_mem_resp_yumi_li;
  assign loopback_mem_cmd = '{header: loopback_mem_cmd_li.header
                             ,data: loopback_mem_cmd_li.data[0+:dword_width_gp]
                             };
  assign loopback_mem_resp_lo = '{header: loopback_mem_resp.header
                                 ,data: {cce_block_width_p/dword_width_gp{loopback_mem_resp.data}}
                                 };

  bp_bedrock_cce_mem_msg_s cache_mem_cmd_li;
  logic cache_mem_cmd_v_li, cache_mem_cmd_ready_lo;
  bp_bedrock_cce_mem_msg_s cache_mem_resp_lo;
  logic cache_mem_resp_v_lo, cache_mem_resp_yumi_li;

  bp_bedrock_cce_mem_msg_s cfg_mem_cmd_li;
  bp_bedrock_xce_mem_msg_s cfg_mem_cmd;
  logic cfg_mem_cmd_v_li, cfg_mem_cmd_ready_lo;
  bp_bedrock_cce_mem_msg_s cfg_mem_resp_lo;
  bp_bedrock_xce_mem_msg_s cfg_mem_resp;
  logic cfg_mem_resp_v_lo, cfg_mem_resp_yumi_li;
  assign cfg_mem_cmd = '{header: cfg_mem_cmd_li.header
                        ,data: cfg_mem_cmd_li.data[0+:dword_width_gp]
                        };
  assign cfg_mem_resp_lo = '{header: cfg_mem_resp.header
                            ,data: {cce_block_width_p/dword_width_gp{cfg_mem_resp.data}}
                            };

  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  bp_cfg_bus_s cfg_bus_lo;
  logic cce_ucode_v_lo;
  logic cce_ucode_w_lo;
  logic [cce_pc_width_p-1:0] cce_ucode_addr_lo;
  logic [cce_instr_width_gp-1:0] cce_ucode_data_lo, cce_ucode_data_li;
  bp_cfg
   #(.bp_params_p(bp_params_p))
   cfg
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_i(cfg_mem_cmd)
     ,.mem_cmd_v_i(cfg_mem_cmd_v_li)
     ,.mem_cmd_ready_o(cfg_mem_cmd_ready_lo)

     ,.mem_resp_o(cfg_mem_resp)
     ,.mem_resp_v_o(cfg_mem_resp_v_lo)
     ,.mem_resp_yumi_i(cfg_mem_resp_yumi_li)

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i(my_did_i)
     ,.host_did_i('0)
     ,.cord_i(my_cord_i)

     ,.cce_ucode_v_o(cce_ucode_v_lo)
     ,.cce_ucode_w_o(cce_ucode_w_lo)
     ,.cce_ucode_addr_o(cce_ucode_addr_lo)
     ,.cce_ucode_data_o(cce_ucode_data_lo)
     ,.cce_ucode_data_i(cce_ucode_data_li)
     );

  bp_cce_wrapper
   #(.bp_params_p(bp_params_p))
   cce
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.ucode_v_i(cce_ucode_v_lo)
     ,.ucode_w_i(cce_ucode_w_lo)
     ,.ucode_addr_i(cce_ucode_addr_lo)
     ,.ucode_data_i(cce_ucode_data_lo)
     ,.ucode_data_o(cce_ucode_data_li)

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

  `declare_bp_lce_req_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_req_msg_header_s, cce_block_width_p);
  localparam lce_req_wh_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_req_msg_header_s), cce_block_width_p);
  bp_lce_req_wormhole_packet_s [1:0] lce_req_packet_lo;
  bp_lce_req_wormhole_header_s [1:0] lce_req_header_lo;

  `declare_bp_lce_cmd_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_cmd_msg_header_s, cce_block_width_p);
  localparam lce_cmd_wh_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_cmd_msg_header_s), cce_block_width_p);
  bp_lce_cmd_wormhole_packet_s [1:0] lce_cmd_packet_lo, lce_cmd_packet_li;
  bp_lce_cmd_wormhole_header_s [1:0] lce_cmd_header_lo, lce_cmd_header_li;

  `declare_bp_lce_resp_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_resp_msg_header_s, cce_block_width_p);
  localparam lce_resp_wh_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_resp_msg_header_s), cce_block_width_p);

  bp_lce_req_wormhole_packet_s cce_lce_req_packet_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p(lce_req_wh_payload_width_lp)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_req_adapter_out
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_i(lce_req_link_cast_i)
    ,.link_o(lce_req_link_cast_o)

    ,.packet_o(cce_lce_req_packet_li)
    ,.v_o(cce_lce_req_v_li)
    ,.yumi_i(cce_lce_req_yumi_lo)
    );
  assign cce_lce_req_li = '{header: cce_lce_req_packet_li.header.msg_hdr, data: cce_lce_req_packet_li.data};

  bp_lce_cmd_wormhole_packet_s cce_lce_cmd_packet_lo;
  bp_lce_cmd_wormhole_header_s cce_lce_cmd_header_lo;
  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cmd_encode
    (.lce_cmd_header_i(cce_lce_cmd_lo.header)
     ,.wh_header_o(cce_lce_cmd_header_lo)
     );
  assign cce_lce_cmd_packet_lo = '{header: cce_lce_cmd_header_lo, data: cce_lce_cmd_lo.data};

  bsg_wormhole_router_adapter_in
   #(.max_payload_width_p(lce_cmd_wh_payload_width_lp)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_cmd_adapter_in
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.packet_i(cce_lce_cmd_packet_lo)
     ,.v_i(cce_lce_cmd_v_lo)
     ,.ready_o(cce_lce_cmd_ready_li)

     ,.link_i(lce_cmd_link_cast_i)
     ,.link_o(lce_cmd_link_cast_o)
     );

  bp_lce_resp_wormhole_packet_s cce_lce_resp_packet_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p(lce_resp_wh_payload_width_lp)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_resp_adapter_out
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_i(lce_resp_link_cast_i)
    ,.link_o(lce_resp_link_cast_o)

    ,.packet_o(cce_lce_resp_packet_li)
    ,.v_o(cce_lce_resp_v_li)
    ,.yumi_i(cce_lce_resp_yumi_lo)
    );
  assign cce_lce_resp_li = '{header: cce_lce_resp_packet_li.header.msg_hdr, data: cce_lce_resp_packet_li.data};

  bp_local_addr_s local_addr_cast;
  assign local_addr_cast = cce_mem_cmd_lo.header.addr;
  wire [dev_id_width_gp-1:0] device_cmd_li = local_addr_cast.dev;

  wire local_cmd_li        = (cce_mem_cmd_lo.header.addr < dram_base_addr_gp);
  wire is_cfg_cmd          = local_cmd_li & (device_cmd_li == cfg_dev_gp);
  wire is_cache_cmd        = ~local_cmd_li || (local_cmd_li & (device_cmd_li == cache_dev_gp));
  wire is_loopback_cmd     = local_cmd_li & ~is_cfg_cmd & ~is_cache_cmd;

  assign cfg_mem_cmd_v_li      = is_cfg_cmd   & cce_mem_cmd_v_lo;
  assign cache_mem_cmd_v_li    = is_cache_cmd & cce_mem_cmd_v_lo;
  assign loopback_mem_cmd_v_li = is_loopback_cmd & cce_mem_cmd_v_lo;

  assign cce_mem_cmd_ready_li = &{loopback_mem_cmd_ready_lo, cache_mem_cmd_ready_lo, cfg_mem_cmd_ready_lo};

  assign {loopback_mem_cmd_li, cache_mem_cmd_li, cfg_mem_cmd_li} = {3{cce_mem_cmd_lo}};

  bp_bedrock_cce_mem_msg_s mem_resp_selected_li;
  logic mem_resp_selected_v_li, mem_resp_selected_ready_lo;
  bsg_arb_fixed
   #(.inputs_p(3)
     ,.lo_to_hi_p(1)
     )
   resp_arb
    (.ready_i(mem_resp_selected_ready_lo)
     ,.reqs_i({loopback_mem_resp_v_lo, cfg_mem_resp_v_lo, cache_mem_resp_v_lo})
     ,.grants_o({loopback_mem_resp_yumi_li, cfg_mem_resp_yumi_li, cache_mem_resp_yumi_li})
     );

  bsg_mux_one_hot
   #(.width_p($bits(bp_bedrock_cce_mem_msg_s)), .els_p(3))
   resp_select
    (.data_i({loopback_mem_resp_lo, cfg_mem_resp_lo, cache_mem_resp_lo})
     ,.sel_one_hot_i({loopback_mem_resp_v_lo, cfg_mem_resp_v_lo, cache_mem_resp_v_lo})
     ,.data_o(mem_resp_selected_li)
     );

  assign mem_resp_selected_v_li = loopback_mem_resp_yumi_li | cache_mem_resp_yumi_li | cfg_mem_resp_yumi_li;
  bsg_two_fifo
   #(.width_p($bits(bp_bedrock_cce_mem_msg_s)))
   resp_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.data_i(mem_resp_selected_li)
     ,.v_i(mem_resp_selected_v_li)
     ,.ready_o(mem_resp_selected_ready_lo)

     ,.data_o(cce_mem_resp_li)
     ,.v_o(cce_mem_resp_v_li)
     ,.yumi_i(cce_mem_resp_yumi_lo)
     );

  bp_bedrock_cce_mem_msg_s dma_mem_cmd_lo;
  logic dma_mem_cmd_v_lo, dma_mem_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s dma_mem_resp_li;
  logic dma_mem_resp_v_li, dma_mem_resp_ready_lo, dma_mem_resp_yumi_lo;
  if (l2_en_p)
    begin : l2s
      bp_bedrock_cce_mem_msg_header_s dma_mem_cmd_header_lo;
      logic dma_mem_cmd_header_v_lo, dma_mem_cmd_header_ready_li;
      logic [dword_width_gp-1:0] dma_mem_cmd_data_lo;
      logic dma_mem_cmd_data_v_lo, dma_mem_cmd_data_ready_li;
      bp_bedrock_cce_mem_msg_header_s dma_mem_resp_header_li;
      logic dma_mem_resp_header_v_li, dma_mem_resp_header_ready_lo;
      logic [dword_width_gp-1:0] dma_mem_resp_data_li;
      logic dma_mem_resp_data_v_li, dma_mem_resp_data_ready_lo;
      bp_me_cache_slice
       #(.bp_params_p(bp_params_p))
       l2s
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.mem_cmd_i(cache_mem_cmd_li)
         ,.mem_cmd_v_i(cache_mem_cmd_v_li)
         ,.mem_cmd_ready_o(cache_mem_cmd_ready_lo)

         ,.mem_resp_o(cache_mem_resp_lo)
         ,.mem_resp_v_o(cache_mem_resp_v_lo)
         ,.mem_resp_yumi_i(cache_mem_resp_yumi_li)

         ,.mem_cmd_header_o(dma_mem_cmd_header_lo)
         ,.mem_cmd_header_v_o(dma_mem_cmd_header_v_lo)
         ,.mem_cmd_header_yumi_i(dma_mem_cmd_header_ready_li & dma_mem_cmd_header_v_lo)

         ,.mem_cmd_data_o(dma_mem_cmd_data_lo)
         ,.mem_cmd_data_v_o(dma_mem_cmd_data_v_lo)
         ,.mem_cmd_data_yumi_i(dma_mem_cmd_data_ready_li & dma_mem_cmd_data_v_lo)

         ,.mem_resp_header_i(dma_mem_resp_header_li)
         ,.mem_resp_header_v_i(dma_mem_resp_header_v_li)
         ,.mem_resp_header_ready_o(dma_mem_resp_header_ready_lo)

         ,.mem_resp_data_i(dma_mem_resp_data_li)
         ,.mem_resp_data_v_i(dma_mem_resp_data_v_li)
         ,.mem_resp_data_ready_o(dma_mem_resp_data_ready_lo)
         );

      bp_burst_to_lite
       #(.bp_params_p(bp_params_p)
         ,.in_data_width_p(dword_width_gp)
         ,.out_data_width_p(cce_block_width_p)
         ,.payload_mask_p(mem_cmd_payload_mask_gp)
         )
       burst2lite
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.mem_header_i(dma_mem_cmd_header_lo)
         ,.mem_header_v_i(dma_mem_cmd_header_v_lo)
         ,.mem_header_ready_and_o(dma_mem_cmd_header_ready_li)

         ,.mem_data_i(dma_mem_cmd_data_lo)
         ,.mem_data_v_i(dma_mem_cmd_data_v_lo)
         ,.mem_data_ready_and_o(dma_mem_cmd_data_ready_li)

         ,.mem_o(dma_mem_cmd_lo)
         ,.mem_v_o(dma_mem_cmd_v_lo)
         ,.mem_ready_and_i(dma_mem_cmd_ready_li)
         );

      bp_lite_to_burst
       #(.bp_params_p(bp_params_p)
         ,.in_data_width_p(cce_block_width_p)
         ,.out_data_width_p(dword_width_gp)
         ,.payload_mask_p(mem_resp_payload_mask_gp)
         )
       lite2burst
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.mem_i(dma_mem_resp_li)
         ,.mem_v_i(dma_mem_resp_v_li)
         ,.mem_ready_and_o(dma_mem_resp_ready_lo)

         ,.mem_header_o(dma_mem_resp_header_li)
         ,.mem_header_v_o(dma_mem_resp_header_v_li)
         ,.mem_header_ready_and_i(dma_mem_resp_header_ready_lo)

         ,.mem_data_o(dma_mem_resp_data_li)
         ,.mem_data_v_o(dma_mem_resp_data_v_li)
         ,.mem_data_ready_and_i(dma_mem_resp_data_ready_lo)
         );
      assign dma_mem_resp_yumi_lo = dma_mem_resp_ready_lo & dma_mem_resp_v_li;
    end
  else
    begin : no_l2s
      assign dma_mem_cmd_lo = cache_mem_cmd_li;
      assign dma_mem_cmd_v_lo = cache_mem_cmd_v_li;
      assign cache_mem_cmd_ready_lo = dma_mem_cmd_ready_li;

      assign cache_mem_resp_lo = dma_mem_resp_li;
      assign cache_mem_resp_v_lo = dma_mem_resp_v_li;
      assign dma_mem_resp_yumi_lo = cache_mem_resp_yumi_li;
    end

  bp_cce_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_i(loopback_mem_cmd)
     ,.mem_cmd_v_i(loopback_mem_cmd_v_li)
     ,.mem_cmd_ready_o(loopback_mem_cmd_ready_lo)

     ,.mem_resp_o(loopback_mem_resp)
     ,.mem_resp_v_o(loopback_mem_resp_v_lo)
     ,.mem_resp_yumi_i(loopback_mem_resp_yumi_li)
     );

  localparam dram_y_cord_lp = ic_y_dim_p + cc_y_dim_p + mc_y_dim_p;
  wire [mem_noc_cord_width_p-1:0] dst_cord_li = dram_y_cord_lp;
  bp_me_cce_to_mem_link_master
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     )
   dma_link
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_i(dma_mem_cmd_lo)
     ,.mem_cmd_v_i(dma_mem_cmd_v_lo)
     ,.mem_cmd_ready_o(dma_mem_cmd_ready_li)

     ,.mem_resp_o(dma_mem_resp_li)
     ,.mem_resp_v_o(dma_mem_resp_v_li)
     ,.mem_resp_yumi_i(dma_mem_resp_yumi_lo)

     ,.my_cord_i(my_cord_i[coh_noc_x_cord_width_p+:mem_noc_y_cord_width_p])
     // TODO: CID == noc cord right now (1 DMC per column)
     ,.my_cid_i(my_cord_i[0+:mem_noc_cid_width_p]-sac_x_dim_p[0+:mem_noc_cid_width_p])
     ,.dst_cord_i(dst_cord_li)
     ,.dst_cid_i('0)

     ,.cmd_link_o(mem_cmd_link_o)
     ,.resp_link_i(mem_resp_link_i)
     );

endmodule

