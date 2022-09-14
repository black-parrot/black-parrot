/**
 *
 * Name:
 *   bp_unicore.sv
 *
 * Description:
 *   This is the top level module for a unicore BlackParrot processor.
 *
 *   The unicore contains:
 *   - a BlackParrot processor core and devices (config, clint, CCE loopback) in bp_unicore_lite
 *   - L2 cache slice in bsg_cache
 *   - core to cache adapter in bp_me_cce_to_cache
 *
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.vh"
`include "bsg_noc_links.vh"

module bp_unicore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bp_top_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)
   )
  (input                                                 clk_i
   , input                                               rt_clk_i
   , input                                               reset_i

   , input [io_noc_did_width_p-1:0]                      my_did_i
   , input [io_noc_did_width_p-1:0]                      host_did_i
   , input [coh_noc_cord_width_p-1:0]                    my_cord_i

   // Outgoing I/O
   , output logic [mem_header_width_lp-1:0]              mem_cmd_header_o
   , output logic [uce_fill_width_p-1:0]                 mem_cmd_data_o
   , output logic                                        mem_cmd_v_o
   , input                                               mem_cmd_ready_and_i
   , output logic                                        mem_cmd_last_o

   , input [mem_header_width_lp-1:0]                     mem_resp_header_i
   , input [uce_fill_width_p-1:0]                        mem_resp_data_i
   , input                                               mem_resp_v_i
   , output logic                                        mem_resp_ready_and_o
   , input                                               mem_resp_last_i

   // Incoming I/O
   , input [mem_header_width_lp-1:0]                     mem_cmd_header_i
   , input [uce_fill_width_p-1:0]                        mem_cmd_data_i
   , input                                               mem_cmd_v_i
   , output logic                                        mem_cmd_ready_and_o
   , input                                               mem_cmd_last_i

   , output logic [mem_header_width_lp-1:0]              mem_resp_header_o
   , output logic [uce_fill_width_p-1:0]                 mem_resp_data_o
   , output logic                                        mem_resp_v_o
   , input                                               mem_resp_ready_and_i
   , output logic                                        mem_resp_last_o

   // DRAM interface
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
  `bp_cast_o(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_resp_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, mem_resp_header);
  bp_cfg_bus_s cfg_bus_lo;

  localparam num_proc_lp = 3;
  localparam num_dev_lp  = 5;
  localparam lg_num_proc_lp = `BSG_SAFE_CLOG2(num_proc_lp);
  localparam lg_num_dev_lp = `BSG_SAFE_CLOG2(num_dev_lp);

  // {IO CMD, BE UCE, FE UCE}
  bp_bedrock_mem_header_s [num_proc_lp-1:0] proc_cmd_header_lo;
  logic [num_proc_lp-1:0][uce_fill_width_p-1:0] proc_cmd_data_lo;
  logic [num_proc_lp-1:0] proc_cmd_v_lo, proc_cmd_ready_and_li, proc_cmd_last_lo;
  bp_bedrock_mem_header_s [num_proc_lp-1:0] proc_resp_header_li;
  logic [num_proc_lp-1:0][uce_fill_width_p-1:0] proc_resp_data_li;
  logic [num_proc_lp-1:0] proc_resp_v_li, proc_resp_ready_and_lo, proc_resp_last_li;

  // {CCE loopback, IO CMD, L2 CMD, CLINT, CFG}
  bp_bedrock_mem_header_s [num_dev_lp-1:0] dev_cmd_header_li;
  logic [num_dev_lp-1:0][uce_fill_width_p-1:0] dev_cmd_data_li;
  logic [num_dev_lp-1:0] dev_cmd_v_li, dev_cmd_ready_and_lo, dev_cmd_last_li;
  bp_bedrock_mem_header_s [num_dev_lp-1:0] dev_resp_header_lo;
  logic [num_dev_lp-1:0][uce_fill_width_p-1:0] dev_resp_data_lo;
  logic [num_dev_lp-1:0] dev_resp_v_lo, dev_resp_ready_and_li, dev_resp_last_lo;

  logic debug_irq_li, timer_irq_li, software_irq_li, m_external_irq_li, s_external_irq_li;
  bp_unicore_lite
   #(.bp_params_p(bp_params_p))
   unicore_lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_cmd_header_o(proc_cmd_header_lo[0+:2])
     ,.mem_cmd_data_o(proc_cmd_data_lo[0+:2])
     ,.mem_cmd_v_o(proc_cmd_v_lo[0+:2])
     ,.mem_cmd_ready_and_i(proc_cmd_ready_and_li[0+:2])
     ,.mem_cmd_last_o(proc_cmd_last_lo[0+:2])

     ,.mem_resp_header_i(proc_resp_header_li[0+:2])
     ,.mem_resp_data_i(proc_resp_data_li[0+:2])
     ,.mem_resp_v_i(proc_resp_v_li[0+:2])
     ,.mem_resp_ready_and_o(proc_resp_ready_and_lo[0+:2])
     ,.mem_resp_last_i(proc_resp_last_li[0+:2])

     ,.debug_irq_i(debug_irq_li)
     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.m_external_irq_i(m_external_irq_li)
     ,.s_external_irq_i(s_external_irq_li)
     );

  // Assign incoming I/O as basically another UCE interface
  assign proc_cmd_header_lo[2] = mem_cmd_header_cast_i;
  assign proc_cmd_data_lo[2] = mem_cmd_data_i;
  assign proc_cmd_v_lo[2] = mem_cmd_v_i;
  assign mem_cmd_ready_and_o = proc_cmd_ready_and_li[2];
  assign proc_cmd_last_lo[2] = mem_cmd_last_i;

  assign mem_resp_header_cast_o = proc_resp_header_li[2];
  assign mem_resp_data_o = proc_resp_data_li[2];
  assign mem_resp_v_o = proc_resp_v_li[2];
  assign proc_resp_ready_and_lo[2] = mem_resp_ready_and_i;
  assign mem_resp_last_o = proc_resp_last_li[2];

  // Select destination of commands
  logic [num_proc_lp-1:0][lg_num_dev_lp-1:0] proc_cmd_dst_lo;
  for (genvar i = 0; i < num_proc_lp; i++)
    begin : cmd_dest
      bp_local_addr_s local_addr;
      assign local_addr = proc_cmd_header_lo[i].addr;
      wire [dev_id_width_gp-1:0] device_cmd_li = local_addr.dev;
      wire is_local        = (proc_cmd_header_lo[i].addr < dram_base_addr_gp);
      wire is_my_core      = is_local & (local_addr.tile == cfg_bus_lo.core_id);
      wire is_other_core   = is_local & (local_addr.tile != cfg_bus_lo.core_id);
      wire is_other_hio    = (proc_cmd_header_lo[i].addr[paddr_width_p-1-:hio_width_p] != 0);

      wire is_cfg_cmd      = is_my_core & is_local & (device_cmd_li == cfg_dev_gp);
      wire is_clint_cmd    = is_my_core & is_local & (device_cmd_li == clint_dev_gp);
      wire is_cache_cmd    = is_my_core & is_local & (device_cmd_li == cache_dev_gp);
      wire is_host_cmd     = is_my_core & is_local & (device_cmd_li == host_dev_gp);

      wire is_io_cmd       = is_host_cmd | is_other_hio | is_other_core;
      wire is_mem_cmd      = is_cache_cmd | (~is_local & ~is_io_cmd);
      wire is_loopback_cmd = ~is_cfg_cmd & ~is_clint_cmd & ~is_mem_cmd & ~is_io_cmd;

      bsg_encode_one_hot
       #(.width_p(num_dev_lp), .lo_to_hi_p(1))
       cmd_pe
        (.i({is_loopback_cmd, is_io_cmd, is_mem_cmd, is_clint_cmd, is_cfg_cmd})
         ,.addr_o(proc_cmd_dst_lo[i])
         ,.v_o()
         );
    end

  // Select destination of responses. Were there a way to transpose structs...
  logic [num_dev_lp-1:0][lg_num_proc_lp-1:0] dev_resp_dst_lo;
  assign dev_resp_dst_lo[4] = dev_resp_header_lo[4].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[3] = dev_resp_header_lo[3].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[2] = dev_resp_header_lo[2].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[1] = dev_resp_header_lo[1].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[0] = dev_resp_header_lo[0].payload.lce_id[0+:lg_num_proc_lp];

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(uce_fill_width_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.num_source_p(num_proc_lp)
     ,.num_sink_p(num_dev_lp)
     )
   cmd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(proc_cmd_header_lo)
     ,.msg_data_i(proc_cmd_data_lo)
     ,.msg_v_i(proc_cmd_v_lo)
     ,.msg_ready_and_o(proc_cmd_ready_and_li)
     ,.msg_last_i(proc_cmd_last_lo)
     ,.msg_dst_i(proc_cmd_dst_lo)

     ,.msg_header_o(dev_cmd_header_li)
     ,.msg_data_o(dev_cmd_data_li)
     ,.msg_v_o(dev_cmd_v_li)
     ,.msg_ready_and_i(dev_cmd_ready_and_lo)
     ,.msg_last_o(dev_cmd_last_li)
     );

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(uce_fill_width_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.num_source_p(num_dev_lp)
     ,.num_sink_p(num_proc_lp)
     )
   resp_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(dev_resp_header_lo)
     ,.msg_data_i(dev_resp_data_lo)
     ,.msg_v_i(dev_resp_v_lo)
     ,.msg_ready_and_o(dev_resp_ready_and_li)
     ,.msg_last_i(dev_resp_last_lo)
     ,.msg_dst_i(dev_resp_dst_lo)

     ,.msg_header_o(proc_resp_header_li)
     ,.msg_data_o(proc_resp_data_li)
     ,.msg_v_o(proc_resp_v_li)
     ,.msg_ready_and_i(proc_resp_ready_and_lo)
     ,.msg_last_o(proc_resp_last_li)
     );

  logic [dword_width_gp-1:0] cfg_data_lo, cfg_data_li;
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(dev_cmd_header_li[0])
     ,.mem_cmd_data_i(cfg_data_li)
     ,.mem_cmd_v_i(dev_cmd_v_li[0])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[0])
     ,.mem_cmd_last_i(dev_cmd_last_li[0])

     ,.mem_resp_header_o(dev_resp_header_lo[0])
     ,.mem_resp_data_o(cfg_data_lo)
     ,.mem_resp_v_o(dev_resp_v_lo[0])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[0])
     ,.mem_resp_last_o(dev_resp_last_lo[0])

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i(my_did_i)
     ,.host_did_i(host_did_i)
     ,.cord_i(my_cord_i)

     ,.cce_ucode_v_o()
     ,.cce_ucode_w_o()
     ,.cce_ucode_addr_o()
     ,.cce_ucode_data_o()
     ,.cce_ucode_data_i('0)
     );
  assign cfg_data_li = dev_cmd_data_li[0];
  assign dev_resp_data_lo[0] = cfg_data_lo;

  logic [dword_width_gp-1:0] clint_data_lo, clint_data_li;
  bp_me_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_cmd_header_i(dev_cmd_header_li[1])
     ,.mem_cmd_data_i(clint_data_li)
     ,.mem_cmd_v_i(dev_cmd_v_li[1])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[1])
     ,.mem_cmd_last_i(dev_cmd_last_li[1])

     ,.mem_resp_header_o(dev_resp_header_lo[1])
     ,.mem_resp_data_o(clint_data_lo)
     ,.mem_resp_v_o(dev_resp_v_lo[1])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[1])
     ,.mem_resp_last_o(dev_resp_last_lo[1])

     ,.debug_irq_o(debug_irq_li)
     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.m_external_irq_o(m_external_irq_li)
     ,.s_external_irq_o(s_external_irq_li)
     );
  assign clint_data_li = dev_cmd_data_li[1];
  assign dev_resp_data_lo[1] = clint_data_lo;

  bp_me_cache_slice
   #(.bp_params_p(bp_params_p))
   l2s
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(dev_cmd_header_li[2])
     ,.mem_cmd_data_i(dev_cmd_data_li[2])
     ,.mem_cmd_last_i(dev_cmd_last_li[2])
     ,.mem_cmd_v_i(dev_cmd_v_li[2])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[2])

     ,.mem_resp_header_o(dev_resp_header_lo[2])
     ,.mem_resp_data_o(dev_resp_data_lo[2])
     ,.mem_resp_last_o(dev_resp_last_lo[2])
     ,.mem_resp_v_o(dev_resp_v_lo[2])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[2])

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

  // Assign I/O as another device
  assign mem_cmd_header_cast_o = dev_cmd_header_li[3];
  assign mem_cmd_data_o = dev_cmd_data_li[3];
  assign mem_cmd_v_o = dev_cmd_v_li[3];
  assign dev_cmd_ready_and_lo[3] = mem_cmd_ready_and_i;
  assign mem_cmd_last_o = dev_cmd_last_li[3];

  assign dev_resp_header_lo[3] = mem_resp_header_cast_i;
  assign dev_resp_data_lo[3] = mem_resp_data_i;
  assign dev_resp_v_lo[3] = mem_resp_v_i;
  assign mem_resp_ready_and_o = dev_resp_ready_and_li[3];
  assign dev_resp_last_lo[3] = mem_resp_last_i;

  logic [dword_width_gp-1:0] loopback_data_lo, loopback_data_li;
  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(dev_cmd_header_li[4])
     ,.mem_cmd_data_i(loopback_data_li)
     ,.mem_cmd_v_i(dev_cmd_v_li[4])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[4])
     ,.mem_cmd_last_i(dev_cmd_last_li[4])
     ,.mem_resp_header_o(dev_resp_header_lo[4])
     ,.mem_resp_data_o(loopback_data_lo)
     ,.mem_resp_v_o(dev_resp_v_lo[4])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[4])
     ,.mem_resp_last_o(dev_resp_last_lo[4])
     );
  assign loopback_data_li = dev_cmd_data_li[4];
  assign dev_resp_data_lo[4] = loopback_data_lo;

endmodule

