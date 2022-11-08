
/**
 *
 * bp_core.sv
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.vh"
`include "bsg_noc_links.vh"

module bp_core
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

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)
   )
  (input                                                 clk_i
   , input                                               rt_clk_i
   , input                                               reset_i

   , output logic [cfg_bus_width_lp-1:0]                 cfg_bus_o
   , output logic                                        cce_ucode_v_o
   , output logic                                        cce_ucode_w_o
   , output logic [cce_pc_width_p-1:0]                   cce_ucode_addr_o
   , output logic [cce_instr_width_gp-1:0]               cce_ucode_data_o
   , input [cce_instr_width_gp-1:0]                      cce_ucode_data_i

   // Memory side connection
   , input [io_noc_did_width_p-1:0]                      my_did_i
   , input [io_noc_did_width_p-1:0]                      host_did_i
   , input [coh_noc_cord_width_p-1:0]                    my_cord_i

   , output logic [1:0][lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [1:0]                                  lce_req_header_v_o
   , input [1:0]                                         lce_req_header_ready_and_i
   , output logic [1:0]                                  lce_req_has_data_o
   , output logic [1:0][icache_fill_width_p-1:0]         lce_req_data_o
   , output logic [1:0]                                  lce_req_data_v_o
   , input [1:0]                                         lce_req_data_ready_and_i
   , output logic [1:0]                                  lce_req_last_o

   , input [1:0][lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input [1:0]                                         lce_cmd_header_v_i
   , output logic [1:0]                                  lce_cmd_header_ready_and_o
   , input [1:0]                                         lce_cmd_has_data_i
   , input [1:0][icache_fill_width_p-1:0]                lce_cmd_data_i
   , input [1:0]                                         lce_cmd_data_v_i
   , output logic [1:0]                                  lce_cmd_data_ready_and_o
   , input [1:0]                                         lce_cmd_last_i

   , input [1:0][lce_fill_header_width_lp-1:0]           lce_fill_header_i
   , input [1:0]                                         lce_fill_header_v_i
   , output logic [1:0]                                  lce_fill_header_ready_and_o
   , input [1:0]                                         lce_fill_has_data_i
   , input [1:0][icache_fill_width_p-1:0]                lce_fill_data_i
   , input [1:0]                                         lce_fill_data_v_i
   , output logic [1:0]                                  lce_fill_data_ready_and_o
   , input [1:0]                                         lce_fill_last_i

   , output logic [1:0][lce_fill_header_width_lp-1:0]    lce_fill_header_o
   , output logic [1:0]                                  lce_fill_header_v_o
   , input [1:0]                                         lce_fill_header_ready_and_i
   , output logic [1:0]                                  lce_fill_has_data_o
   , output logic [1:0][icache_fill_width_p-1:0]         lce_fill_data_o
   , output logic [1:0]                                  lce_fill_data_v_o
   , input [1:0]                                         lce_fill_data_ready_and_i
   , output logic [1:0]                                  lce_fill_last_o

   , output logic [1:0][lce_resp_header_width_lp-1:0]    lce_resp_header_o
   , output logic [1:0]                                  lce_resp_header_v_o
   , input [1:0]                                         lce_resp_header_ready_and_i
   , output logic [1:0]                                  lce_resp_has_data_o
   , output logic [1:0][icache_fill_width_p-1:0]         lce_resp_data_o
   , output logic [1:0]                                  lce_resp_data_v_o
   , input [1:0]                                         lce_resp_data_ready_and_i
   , output logic [1:0]                                  lce_resp_last_o

   , input [mem_fwd_header_width_lp-1:0]                 mem_fwd_header_i
   , input [bedrock_data_width_p-1:0]                    mem_fwd_data_i
   , input                                               mem_fwd_v_i
   , output logic                                        mem_fwd_ready_and_o
   , input                                               mem_fwd_last_i

   , output logic [mem_rev_header_width_lp-1:0]          mem_rev_header_o
   , output logic [bedrock_data_width_p-1:0]             mem_rev_data_o
   , output logic                                        mem_rev_v_o
   , input                                               mem_rev_ready_and_i
   , output logic                                        mem_rev_last_o

   , output logic [l2_banks_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [l2_banks_p-1:0]                       dma_pkt_v_o
   , input [l2_banks_p-1:0]                              dma_pkt_ready_and_i

   , input [l2_banks_p-1:0][l2_fill_width_p-1:0]         dma_data_i
   , input [l2_banks_p-1:0]                              dma_data_v_i
   , output logic [l2_banks_p-1:0]                       dma_data_ready_and_o

   , output logic [l2_banks_p-1:0][l2_fill_width_p-1:0]  dma_data_o
   , output logic [l2_banks_p-1:0]                       dma_data_v_o
   , input [l2_banks_p-1:0]                              dma_data_ready_and_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);
  bp_cfg_bus_s cfg_bus_lo;

  logic debug_irq_li, timer_irq_li, software_irq_li, m_external_irq_li, s_external_irq_li;
  bp_core_lite
   #(.bp_params_p(bp_params_p))
   core_lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.lce_req_header_o(lce_req_header_o)
     ,.lce_req_header_v_o(lce_req_header_v_o)
     ,.lce_req_header_ready_and_i(lce_req_header_ready_and_i)
     ,.lce_req_has_data_o(lce_req_has_data_o)
     ,.lce_req_data_o(lce_req_data_o)
     ,.lce_req_data_v_o(lce_req_data_v_o)
     ,.lce_req_data_ready_and_i(lce_req_data_ready_and_i)
     ,.lce_req_last_o(lce_req_last_o)

     ,.lce_cmd_header_i(lce_cmd_header_i)
     ,.lce_cmd_header_v_i(lce_cmd_header_v_i)
     ,.lce_cmd_header_ready_and_o(lce_cmd_header_ready_and_o)
     ,.lce_cmd_has_data_i(lce_cmd_has_data_i)
     ,.lce_cmd_data_i(lce_cmd_data_i)
     ,.lce_cmd_data_v_i(lce_cmd_data_v_i)
     ,.lce_cmd_data_ready_and_o(lce_cmd_data_ready_and_o)
     ,.lce_cmd_last_i(lce_cmd_last_i)

     ,.lce_resp_header_o(lce_resp_header_o)
     ,.lce_resp_header_v_o(lce_resp_header_v_o)
     ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and_i)
     ,.lce_resp_has_data_o(lce_resp_has_data_o)
     ,.lce_resp_data_o(lce_resp_data_o)
     ,.lce_resp_data_v_o(lce_resp_data_v_o)
     ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and_i)
     ,.lce_resp_last_o(lce_resp_last_o)

     ,.lce_fill_header_i(lce_fill_header_i)
     ,.lce_fill_header_v_i(lce_fill_header_v_i)
     ,.lce_fill_header_ready_and_o(lce_fill_header_ready_and_o)
     ,.lce_fill_has_data_i(lce_fill_has_data_i)
     ,.lce_fill_data_i(lce_fill_data_i)
     ,.lce_fill_data_v_i(lce_fill_data_v_i)
     ,.lce_fill_data_ready_and_o(lce_fill_data_ready_and_o)
     ,.lce_fill_last_i(lce_fill_last_i)

     ,.lce_fill_header_o(lce_fill_header_o)
     ,.lce_fill_header_v_o(lce_fill_header_v_o)
     ,.lce_fill_header_ready_and_i(lce_fill_header_ready_and_i)
     ,.lce_fill_has_data_o(lce_fill_has_data_o)
     ,.lce_fill_data_o(lce_fill_data_o)
     ,.lce_fill_data_v_o(lce_fill_data_v_o)
     ,.lce_fill_data_ready_and_i(lce_fill_data_ready_and_i)
     ,.lce_fill_last_o(lce_fill_last_o)

     ,.debug_irq_i(debug_irq_li)
     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.m_external_irq_i(m_external_irq_li)
     ,.s_external_irq_i(s_external_irq_li)
     );

  // Device-side CCE-Mem network connections
  // dev_fwd[3:0] = {CCE loopback, CLINT, CFG, memory (cache)}
  bp_bedrock_mem_fwd_header_s [3:0] dev_fwd_header_li;
  logic [3:0][bedrock_data_width_p-1:0] dev_fwd_data_li;
  logic [3:0] dev_fwd_v_li, dev_fwd_ready_and_lo, dev_fwd_last_li;
  bp_bedrock_mem_rev_header_s [3:0] dev_rev_header_lo;
  logic [3:0][bedrock_data_width_p-1:0] dev_rev_data_lo;
  logic [3:0] dev_rev_v_lo, dev_rev_ready_and_li, dev_rev_last_lo;

  // Config
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[1])
     ,.mem_fwd_data_i(dev_fwd_data_li[1])
     ,.mem_fwd_v_i(dev_fwd_v_li[1])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[1])
     ,.mem_fwd_last_i(dev_fwd_last_li[1])

     ,.mem_rev_header_o(dev_rev_header_lo[1])
     ,.mem_rev_data_o(dev_rev_data_lo[1])
     ,.mem_rev_v_o(dev_rev_v_lo[1])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[1])
     ,.mem_rev_last_o(dev_rev_last_lo[1])

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i(my_did_i)
     ,.host_did_i(host_did_i)
     ,.cord_i(my_cord_i)

     ,.cce_ucode_v_o(cce_ucode_v_o)
     ,.cce_ucode_w_o(cce_ucode_w_o)
     ,.cce_ucode_addr_o(cce_ucode_addr_o)
     ,.cce_ucode_data_o(cce_ucode_data_o)
     ,.cce_ucode_data_i(cce_ucode_data_i)
     );
  assign cfg_bus_o = cfg_bus_lo;

  // CLINT
  bp_me_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_fwd_header_i(dev_fwd_header_li[2])
     ,.mem_fwd_data_i(dev_fwd_data_li[2])
     ,.mem_fwd_v_i(dev_fwd_v_li[2])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[2])
     ,.mem_fwd_last_i(dev_fwd_last_li[2])

     ,.mem_rev_header_o(dev_rev_header_lo[2])
     ,.mem_rev_data_o(dev_rev_data_lo[2])
     ,.mem_rev_v_o(dev_rev_v_lo[2])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[2])
     ,.mem_rev_last_o(dev_rev_last_lo[2])

     ,.debug_irq_o(debug_irq_li)
     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.m_external_irq_o(m_external_irq_li)
     ,.s_external_irq_o(s_external_irq_li)
     );

  // Loopback
  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[3])
     ,.mem_fwd_data_i(dev_fwd_data_li[3])
     ,.mem_fwd_v_i(dev_fwd_v_li[3])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[3])
     ,.mem_fwd_last_i(dev_fwd_last_li[3])

     ,.mem_rev_header_o(dev_rev_header_lo[3])
     ,.mem_rev_data_o(dev_rev_data_lo[3])
     ,.mem_rev_v_o(dev_rev_v_lo[3])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[3])
     ,.mem_rev_last_o(dev_rev_last_lo[3])
     );

  // Select destination of CCE-Mem command from CCE
  logic [`BSG_SAFE_CLOG2(4)-1:0] mem_fwd_dst_lo;
  bp_local_addr_s local_addr;
  assign local_addr = mem_fwd_header_cast_i.addr;
  wire [dev_id_width_gp-1:0] device_fwd_li = local_addr.dev;
  wire local_fwd_li    = (mem_fwd_header_cast_i.addr < dram_base_addr_gp);

  wire is_cfg_fwd      = local_fwd_li & (device_fwd_li == cfg_dev_gp);
  wire is_clint_fwd    = local_fwd_li & (device_fwd_li == clint_dev_gp);
  wire is_cache_fwd    = local_fwd_li & (device_fwd_li == cache_dev_gp);
  wire is_mem_fwd      = ~local_fwd_li || is_cache_fwd;
  wire is_loopback_fwd = local_fwd_li & ~is_cfg_fwd & ~is_clint_fwd & ~is_mem_fwd;

  bsg_encode_one_hot
   #(.width_p(4), .lo_to_hi_p(1))
   fwd_pe
    (.i({is_loopback_fwd, is_clint_fwd, is_cfg_fwd, is_mem_fwd})
     ,.addr_o(mem_fwd_dst_lo)
     ,.v_o()
     );

  // All CCE-Mem network responses go to the CCE on this tile (id = 0 in xbar)
  wire [3:0] dev_rev_dst_lo = '0;

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.num_source_p(1)
     ,.num_sink_p(4)
     )
   fwd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_cast_i)
     ,.msg_data_i(mem_fwd_data_i)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)
     ,.msg_last_i(mem_fwd_last_i)
     ,.msg_dst_i(mem_fwd_dst_lo)

     ,.msg_header_o(dev_fwd_header_li)
     ,.msg_data_o(dev_fwd_data_li)
     ,.msg_v_o(dev_fwd_v_li)
     ,.msg_ready_and_i(dev_fwd_ready_and_lo)
     ,.msg_last_o(dev_fwd_last_li)
     );

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.num_source_p(4)
     ,.num_sink_p(1)
     )
   rev_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(dev_rev_header_lo)
     ,.msg_data_i(dev_rev_data_lo)
     ,.msg_v_i(dev_rev_v_lo)
     ,.msg_ready_and_o(dev_rev_ready_and_li)
     ,.msg_last_i(dev_rev_last_lo)
     ,.msg_dst_i(dev_rev_dst_lo)

     ,.msg_header_o(mem_rev_header_cast_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)
     ,.msg_last_o(mem_rev_last_o)
     );

  // CCE-Mem network to L2 Cache adapter
  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   l2s
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[0])
     ,.mem_fwd_data_i(dev_fwd_data_li[0])
     ,.mem_fwd_v_i(dev_fwd_v_li[0])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[0])
     ,.mem_fwd_last_i(dev_fwd_last_li[0])

     ,.mem_rev_header_o(dev_rev_header_lo[0])
     ,.mem_rev_data_o(dev_rev_data_lo[0])
     ,.mem_rev_v_o(dev_rev_v_lo[0])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[0])
     ,.mem_rev_last_o(dev_rev_last_lo[0])

     ,.dma_pkt_o(dma_pkt_o)
     ,.dma_pkt_v_o(dma_pkt_v_o)
     ,.dma_pkt_ready_and_i(dma_pkt_ready_and_i)

     ,.dma_data_i(dma_data_i)
     ,.dma_data_v_i(dma_data_v_i)
     ,.dma_data_ready_and_o(dma_data_ready_and_o)

     ,.dma_data_o(dma_data_o)
     ,.dma_data_v_o(dma_data_v_o)
     ,.dma_data_ready_and_i(dma_data_ready_and_i)
     );

endmodule

