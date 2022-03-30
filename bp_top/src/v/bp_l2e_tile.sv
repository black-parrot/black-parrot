/**
 *
 * bp_l2e_tile.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.vh"
`include "bsg_noc_links.vh"

module bp_l2e_tile
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bp_top_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
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
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_resp_link_o

   , output logic [mem_noc_ral_link_width_lp-1:0]             mem_cmd_link_o
   , input [mem_noc_ral_link_width_lp-1:0]                    mem_resp_link_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  // Reset
  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  // Config bus
  bp_cfg_bus_s cfg_bus_lo;

  // LCE-CCE coherence network links
  bp_coh_ready_and_link_s lce_req_link_cast_i, lce_req_link_cast_o;
  bp_coh_ready_and_link_s lce_resp_link_cast_i, lce_resp_link_cast_o;
  bp_coh_ready_and_link_s lce_cmd_link_cast_i, lce_cmd_link_cast_o;
  assign lce_req_link_cast_i  = lce_req_link_i;
  assign lce_cmd_link_cast_i  = lce_cmd_link_i;
  assign lce_resp_link_cast_i = lce_resp_link_i;
  assign lce_req_link_o  = lce_req_link_cast_o;
  assign lce_cmd_link_o  = lce_cmd_link_cast_o;
  assign lce_resp_link_o = lce_resp_link_cast_o;

  // stub unused LCE-CCE connections
  assign lce_req_link_cast_o.v = '0;
  assign lce_req_link_cast_o.data = '0;
  assign lce_cmd_link_cast_o.ready_and_rev = '0;
  assign lce_resp_link_cast_o.v = '0;
  assign lce_resp_link_cast_o.data = '0;

  // CCE-side LCE-CCE network connections
  logic cce_lce_req_header_v, cce_lce_req_header_ready_and;
  logic cce_lce_req_data_v, cce_lce_req_data_ready_and;
  logic cce_lce_req_has_data, cce_lce_req_last;
  logic cce_lce_resp_header_v, cce_lce_resp_header_ready_and;
  logic cce_lce_resp_data_v, cce_lce_resp_data_ready_and;
  logic cce_lce_resp_has_data, cce_lce_resp_last;
  logic cce_lce_cmd_header_v, cce_lce_cmd_header_ready_and;
  logic cce_lce_cmd_data_v, cce_lce_cmd_data_ready_and;
  logic cce_lce_cmd_has_data, cce_lce_cmd_last;
  bp_bedrock_lce_req_header_s cce_lce_req_header;
  bp_bedrock_lce_resp_header_s cce_lce_resp_header;
  bp_bedrock_lce_cmd_header_s cce_lce_cmd_header;
  logic [bedrock_data_width_p-1:0] cce_lce_req_data, cce_lce_resp_data, cce_lce_cmd_data;

  `declare_bp_lce_cmd_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_cmd_header_s, cce_block_width_p);
  localparam lce_cmd_wh_pad_width_lp = `bp_bedrock_wormhole_packet_pad_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_cmd_header_s));

  // LCE to CCE request
  bp_me_wormhole_to_burst
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_payload_width_p(lce_req_payload_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     )
   cce_lce_req_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_req_link_cast_i.data)
    ,.link_v_i(lce_req_link_cast_i.v)
    ,.link_ready_and_o(lce_req_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(cce_lce_req_header)
    ,.pr_hdr_v_o(cce_lce_req_header_v)
    ,.pr_hdr_ready_and_i(cce_lce_req_header_ready_and)
    ,.pr_has_data_o(cce_lce_req_has_data)

    ,.pr_data_o(cce_lce_req_data)
    ,.pr_data_v_o(cce_lce_req_data_v)
    ,.pr_data_ready_and_i(cce_lce_req_data_ready_and)
    ,.pr_last_o(cce_lce_req_last)
    );

  // CCE to LCE command
  // encode the header into WH format
  bp_lce_cmd_wormhole_header_s cce_lce_cmd_wh_header_lo;
  bp_me_bedrock_wormhole_header_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cmd_encode
    (.header_i(cce_lce_cmd_header)
     ,.wh_header_o(cce_lce_cmd_wh_header_lo)
     ,.data_len_o(/* unused */)
     );

  bp_me_burst_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_header_width_lp)
     ,.pr_payload_width_p(lce_cmd_payload_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     )
   cce_lce_cmd_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.wh_hdr_i(cce_lce_cmd_wh_header_lo[0+:($bits(bp_lce_cmd_wormhole_header_s)-lce_cmd_wh_pad_width_lp)])
    ,.pr_hdr_v_i(cce_lce_cmd_header_v)
    ,.pr_hdr_ready_and_o(cce_lce_cmd_header_ready_and)
    ,.pr_has_data_i(cce_lce_cmd_has_data)

    ,.pr_data_i(cce_lce_cmd_data)
    ,.pr_data_v_i(cce_lce_cmd_data_v)
    ,.pr_data_ready_and_o(cce_lce_cmd_data_ready_and)
    ,.pr_last_i(cce_lce_cmd_last)

    ,.link_data_o(lce_cmd_link_cast_o.data)
    ,.link_v_o(lce_cmd_link_cast_o.v)
    ,.link_ready_and_i(lce_cmd_link_cast_i.ready_and_rev)
    );

  // LCE to CCE response
  bp_me_wormhole_to_burst
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_resp_header_width_lp)
     ,.pr_payload_width_p(lce_resp_payload_width_lp)
     ,.pr_data_width_p(bedrock_data_width_p)
     )
   cce_lce_resp_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_resp_link_cast_i.data)
    ,.link_v_i(lce_resp_link_cast_i.v)
    ,.link_ready_and_o(lce_resp_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(cce_lce_resp_header)
    ,.pr_hdr_v_o(cce_lce_resp_header_v)
    ,.pr_hdr_ready_and_i(cce_lce_resp_header_ready_and)
    ,.pr_has_data_o(cce_lce_resp_has_data)

    ,.pr_data_o(cce_lce_resp_data)
    ,.pr_data_v_o(cce_lce_resp_data_v)
    ,.pr_data_ready_and_i(cce_lce_resp_data_ready_and)
    ,.pr_last_o(cce_lce_resp_last)
    );

  // CCE-side CCE-Mem network connections
  bp_bedrock_mem_header_s mem_cmd_header_lo;
  logic [bedrock_data_width_p-1:0] mem_cmd_data_lo;
  logic mem_cmd_v_lo, mem_cmd_last_lo, mem_cmd_ready_and_li;
  bp_bedrock_mem_header_s mem_resp_header_li;
  logic [bedrock_data_width_p-1:0] mem_resp_data_li;
  logic mem_resp_v_li, mem_resp_ready_and_lo, mem_resp_last_li;

  // Device-side CCE-Mem network connections
  // dev_cmd[2:0] = {CCE loopback, CFG, memory (cache)}
  bp_bedrock_mem_header_s [2:0] dev_cmd_header_li;
  logic [2:0][bedrock_data_width_p-1:0] dev_cmd_data_li;
  logic [2:0] dev_cmd_v_li, dev_cmd_ready_and_lo, dev_cmd_last_li;
  bp_bedrock_mem_header_s [2:0] dev_resp_header_lo;
  logic [2:0][bedrock_data_width_p-1:0] dev_resp_data_lo;
  logic [2:0] dev_resp_v_lo, dev_resp_ready_and_li, dev_resp_last_lo;

  // Config
  logic cce_ucode_v_lo;
  logic cce_ucode_w_lo;
  logic [cce_pc_width_p-1:0] cce_ucode_addr_lo;
  logic [cce_instr_width_gp-1:0] cce_ucode_data_lo, cce_ucode_data_li;
  logic [bedrock_data_width_p-1:0] cfg_data_lo, cfg_data_li;
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[1])
     ,.mem_cmd_data_i(dev_cmd_data_li[1])
     ,.mem_cmd_v_i(dev_cmd_v_li[1])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[1])
     ,.mem_cmd_last_i(dev_cmd_last_li[1])

     ,.mem_resp_header_o(dev_resp_header_lo[1])
     ,.mem_resp_data_o(dev_resp_data_lo[1])
     ,.mem_resp_v_o(dev_resp_v_lo[1])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[1])
     ,.mem_resp_last_o(dev_resp_last_lo[1])

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

  // CCE-Mem Loopback
  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[2])
     ,.mem_cmd_data_i(dev_cmd_data_li[2])
     ,.mem_cmd_v_i(dev_cmd_v_li[2])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[2])
     ,.mem_cmd_last_i(dev_cmd_last_li[2])

     ,.mem_resp_header_o(dev_resp_header_lo[2])
     ,.mem_resp_data_o(dev_resp_data_lo[2])
     ,.mem_resp_v_o(dev_resp_v_lo[2])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[2])
     ,.mem_resp_last_o(dev_resp_last_lo[2])
     );

  // Select destination of CCE-Mem command from CCE
  logic [`BSG_SAFE_CLOG2(3)-1:0] mem_cmd_dst_lo;
  bp_local_addr_s local_addr;
  assign local_addr = mem_cmd_header_lo.addr;
  wire [dev_id_width_gp-1:0] device_cmd_li = local_addr.dev;
  wire local_cmd_li    = (mem_cmd_header_lo.addr < dram_base_addr_gp);

  wire is_cfg_cmd      = local_cmd_li & (device_cmd_li == cfg_dev_gp);
  wire is_mem_cmd      = ~local_cmd_li || (local_cmd_li & (device_cmd_li == cache_dev_gp));
  wire is_loopback_cmd = local_cmd_li & ~is_cfg_cmd & ~is_mem_cmd;

  bsg_encode_one_hot
   #(.width_p(3), .lo_to_hi_p(1))
   cmd_pe
    (.i({is_loopback_cmd, is_cfg_cmd, is_mem_cmd})
     ,.addr_o(mem_cmd_dst_lo)
     ,.v_o()
     );

  // All CCE-Mem network responses go to the CCE on this tile (id = 0 in xbar)
  wire [2:0] dev_resp_dst_lo = '0;

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.num_source_p(1)
     ,.num_sink_p(3)
     )
   cmd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.msg_header_i(mem_cmd_header_lo)
     ,.msg_data_i(mem_cmd_data_lo)
     ,.msg_v_i(mem_cmd_v_lo)
     ,.msg_ready_and_o(mem_cmd_ready_and_li)
     ,.msg_last_i(mem_cmd_last_lo)
     ,.msg_dst_i(mem_cmd_dst_lo)

     ,.msg_header_o(dev_cmd_header_li)
     ,.msg_data_o(dev_cmd_data_li)
     ,.msg_v_o(dev_cmd_v_li)
     ,.msg_ready_and_i(dev_cmd_ready_and_lo)
     ,.msg_last_o(dev_cmd_last_li)
     );

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.num_source_p(3)
     ,.num_sink_p(1)
     )
   resp_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.msg_header_i(dev_resp_header_lo)
     ,.msg_data_i(dev_resp_data_lo)
     ,.msg_v_i(dev_resp_v_lo)
     ,.msg_ready_and_o(dev_resp_ready_and_li)
     ,.msg_last_i(dev_resp_last_lo)
     ,.msg_dst_i(dev_resp_dst_lo)

     ,.msg_header_o(mem_resp_header_li)
     ,.msg_data_o(mem_resp_data_li)
     ,.msg_v_o(mem_resp_v_li)
     ,.msg_ready_and_i(mem_resp_ready_and_lo)
     ,.msg_last_o(mem_resp_last_li)
     );

  // CCE: Cache Coherence Engine
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

     // LCE-CCE Interface
     // BedRock Burst protocol: ready&valid
     ,.lce_req_header_i(cce_lce_req_header)
     ,.lce_req_header_v_i(cce_lce_req_header_v)
     ,.lce_req_header_ready_and_o(cce_lce_req_header_ready_and)
     ,.lce_req_has_data_i(cce_lce_req_has_data)
     ,.lce_req_data_i(cce_lce_req_data)
     ,.lce_req_data_v_i(cce_lce_req_data_v)
     ,.lce_req_data_ready_and_o(cce_lce_req_data_ready_and)
     ,.lce_req_last_i(cce_lce_req_last)

     ,.lce_resp_header_i(cce_lce_resp_header)
     ,.lce_resp_header_v_i(cce_lce_resp_header_v)
     ,.lce_resp_header_ready_and_o(cce_lce_resp_header_ready_and)
     ,.lce_resp_has_data_i(cce_lce_resp_has_data)
     ,.lce_resp_data_i(cce_lce_resp_data)
     ,.lce_resp_data_v_i(cce_lce_resp_data_v)
     ,.lce_resp_data_ready_and_o(cce_lce_resp_data_ready_and)
     ,.lce_resp_last_i(cce_lce_resp_last)

     ,.lce_cmd_header_o(cce_lce_cmd_header)
     ,.lce_cmd_header_v_o(cce_lce_cmd_header_v)
     ,.lce_cmd_header_ready_and_i(cce_lce_cmd_header_ready_and)
     ,.lce_cmd_has_data_o(cce_lce_cmd_has_data)
     ,.lce_cmd_data_o(cce_lce_cmd_data)
     ,.lce_cmd_data_v_o(cce_lce_cmd_data_v)
     ,.lce_cmd_data_ready_and_i(cce_lce_cmd_data_ready_and)
     ,.lce_cmd_last_o(cce_lce_cmd_last)

     // CCE-MEM Interface
     // BedRock Burst protocol: ready&valid
     ,.mem_resp_header_i(mem_resp_header_li)
     ,.mem_resp_data_i(mem_resp_data_li)
     ,.mem_resp_v_i(mem_resp_v_li)
     ,.mem_resp_ready_and_o(mem_resp_ready_and_lo)
     ,.mem_resp_last_i(mem_resp_last_li)

     ,.mem_cmd_header_o(mem_cmd_header_lo)
     ,.mem_cmd_data_o(mem_cmd_data_lo)
     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_ready_and_i(mem_cmd_ready_and_li)
     ,.mem_cmd_last_o(mem_cmd_last_lo)
     );

  // CCE-Mem network to L2 Cache adapter
  `declare_bsg_cache_dma_pkt_s(daddr_width_p);
  bsg_cache_dma_pkt_s [l2_banks_p-1:0] dma_pkt_lo;
  logic [l2_banks_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [l2_banks_p-1:0] dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_banks_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [l2_banks_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   l2s
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_header_i(dev_cmd_header_li[0])
     ,.mem_cmd_data_i(dev_cmd_data_li[0])
     ,.mem_cmd_v_i(dev_cmd_v_li[0])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[0])
     ,.mem_cmd_last_i(dev_cmd_last_li[0])

     ,.mem_resp_header_o(dev_resp_header_lo[0])
     ,.mem_resp_data_o(dev_resp_data_lo[0])
     ,.mem_resp_v_o(dev_resp_v_lo[0])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[0])
     ,.mem_resp_last_o(dev_resp_last_lo[0])

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_ready_and_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_and_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_ready_and_i(dma_data_yumi_li)
     );

  bp_mem_ready_and_link_s [l2_banks_p-1:0] dma_link_lo, dma_link_li;
  for (genvar i = 0; i < l2_banks_p; i++)
    begin : dma
      wire [mem_noc_cord_width_p-1:0] cord_li = my_cord_i[coh_noc_x_cord_width_p+:mem_noc_y_cord_width_p];
      wire [mem_noc_cid_width_p-1:0]   cid_li = i;

      bsg_cache_dma_to_wormhole
       #(.dma_addr_width_p(daddr_width_p)
         ,.dma_burst_len_p(l2_block_size_in_fill_p)

         ,.wh_flit_width_p(mem_noc_flit_width_p)
         ,.wh_cid_width_p(mem_noc_cid_width_p)
         ,.wh_len_width_p(mem_noc_len_width_p)
         ,.wh_cord_width_p(mem_noc_cord_width_p)
         )
       dma2wh
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.dma_pkt_i(dma_pkt_lo[i])
         ,.dma_pkt_v_i(dma_pkt_v_lo[i])
         ,.dma_pkt_yumi_o(dma_pkt_yumi_li[i])

         ,.dma_data_o(dma_data_li[i])
         ,.dma_data_v_o(dma_data_v_li[i])
         ,.dma_data_ready_and_i(dma_data_ready_and_lo[i])

         ,.dma_data_i(dma_data_lo[i])
         ,.dma_data_v_i(dma_data_v_lo[i])
         ,.dma_data_yumi_o(dma_data_yumi_li[i])

         ,.wh_link_sif_i(dma_link_li[i])
         ,.wh_link_sif_o(dma_link_lo[i])

         ,.my_wh_cord_i(cord_li)
         ,.my_wh_cid_i(cid_li)
         // TODO: Parameterizable?
         ,.dest_wh_cord_i('1)
         ,.dest_wh_cid_i('0)
         );
    end

  bsg_wormhole_concentrator
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.num_in_p(l2_banks_p)
     ,.hold_on_valid_p(1)
     )
   dma_concentrate
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(dma_link_lo)
     ,.links_o(dma_link_li)

     ,.concentrated_link_o(mem_cmd_link_o)
     ,.concentrated_link_i(mem_resp_link_i)
     );

endmodule

