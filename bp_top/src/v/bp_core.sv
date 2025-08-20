
/**
 *
 * bp_core.sv
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.svh"
`include "bsg_noc_links.svh"

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
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p, l2_block_size_in_words_p)
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
   , input [mem_noc_did_width_p-1:0]                     my_did_i
   , input [mem_noc_did_width_p-1:0]                     host_did_i
   , input [coh_noc_cord_width_p-1:0]                    my_cord_i

   , output logic [1:0][lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [1:0][icache_fill_width_p-1:0]         lce_req_data_o
   , output logic [1:0]                                  lce_req_v_o
   , input [1:0]                                         lce_req_ready_and_i

   , input [1:0][lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input [1:0][icache_fill_width_p-1:0]                lce_cmd_data_i
   , input [1:0]                                         lce_cmd_v_i
   , output logic [1:0]                                  lce_cmd_ready_and_o

   , input [1:0][lce_fill_header_width_lp-1:0]           lce_fill_header_i
   , input [1:0][icache_fill_width_p-1:0]                lce_fill_data_i
   , input [1:0]                                         lce_fill_v_i
   , output logic [1:0]                                  lce_fill_ready_and_o

   , output logic [1:0][lce_fill_header_width_lp-1:0]    lce_fill_header_o
   , output logic [1:0][icache_fill_width_p-1:0]         lce_fill_data_o
   , output logic [1:0]                                  lce_fill_v_o
   , input [1:0]                                         lce_fill_ready_and_i

   , output logic [1:0][lce_resp_header_width_lp-1:0]    lce_resp_header_o
   , output logic [1:0][icache_fill_width_p-1:0]         lce_resp_data_o
   , output logic [1:0]                                  lce_resp_v_o
   , input [1:0]                                         lce_resp_ready_and_i

   , input [mem_fwd_header_width_lp-1:0]                 mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]                    mem_fwd_data_i
   , input                                               mem_fwd_v_i
   , output logic                                        mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]          mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]             mem_rev_data_o
   , output logic                                        mem_rev_v_o
   , input                                               mem_rev_ready_and_i

   , output logic [l2_slices_p-1:0][l2_banks_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [l2_slices_p-1:0][l2_banks_p-1:0]                       dma_pkt_v_o
   , input [l2_slices_p-1:0][l2_banks_p-1:0]                              dma_pkt_ready_and_i

   , input [l2_slices_p-1:0][l2_banks_p-1:0][l2_fill_width_p-1:0]         dma_data_i
   , input [l2_slices_p-1:0][l2_banks_p-1:0]                              dma_data_v_i
   , output logic [l2_slices_p-1:0][l2_banks_p-1:0]                       dma_data_ready_and_o

   , output logic [l2_slices_p-1:0][l2_banks_p-1:0][l2_fill_width_p-1:0]  dma_data_o
   , output logic [l2_slices_p-1:0][l2_banks_p-1:0]                       dma_data_v_o
   , input [l2_slices_p-1:0][l2_banks_p-1:0]                              dma_data_ready_and_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  // Only CCE acts as a proc for multicore
  localparam cce_proc_id_lp     =                      0;
  localparam num_proc_lp        = cce_proc_id_lp     + 1;
  localparam lg_num_proc_lp     = `BSG_SAFE_CLOG2(num_proc_lp);

  localparam cfg_dev_id_lp      =                      0;
  localparam clint_dev_id_lp    = cfg_dev_id_lp      + 1;
  localparam l2s_dev_base_id_lp = clint_dev_id_lp    + 1;
  localparam loopback_dev_id_lp = l2s_dev_base_id_lp + l2_slices_p;
  localparam num_dev_lp         = loopback_dev_id_lp + 1;
  localparam lg_num_dev_lp      = `BSG_SAFE_CLOG2(num_dev_lp);

  // {CCE}
  bp_bedrock_mem_fwd_header_s [num_proc_lp-1:0] proc_fwd_header_lo;
  logic [num_proc_lp-1:0][bedrock_fill_width_p-1:0] proc_fwd_data_lo;
  logic [num_proc_lp-1:0] proc_fwd_v_lo, proc_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s [num_proc_lp-1:0] proc_rev_header_li;
  logic [num_proc_lp-1:0][bedrock_fill_width_p-1:0] proc_rev_data_li;
  logic [num_proc_lp-1:0] proc_rev_v_li, proc_rev_ready_and_lo;

  // Device-side CCE-Mem network connections
  // {LOOPBACK, L2, CLINT, CFG}
  bp_bedrock_mem_fwd_header_s [num_dev_lp-1:0] dev_fwd_header_li;
  logic [num_dev_lp-1:0][bedrock_fill_width_p-1:0] dev_fwd_data_li;
  logic [num_dev_lp-1:0] dev_fwd_v_li, dev_fwd_ready_and_lo;
  bp_bedrock_mem_rev_header_s [num_dev_lp-1:0] dev_rev_header_lo;
  logic [num_dev_lp-1:0][bedrock_fill_width_p-1:0] dev_rev_data_lo;
  logic [num_dev_lp-1:0] dev_rev_v_lo, dev_rev_ready_and_li;

  bp_cfg_bus_s cfg_bus_lo;
  logic debug_irq_li, timer_irq_li, software_irq_li, m_external_irq_li, s_external_irq_li;
  bp_core_lite
   #(.bp_params_p(bp_params_p))
   core_lite
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.lce_req_header_o(lce_req_header_o)
     ,.lce_req_data_o(lce_req_data_o)
     ,.lce_req_v_o(lce_req_v_o)
     ,.lce_req_ready_and_i(lce_req_ready_and_i)

     ,.lce_cmd_header_i(lce_cmd_header_i)
     ,.lce_cmd_data_i(lce_cmd_data_i)
     ,.lce_cmd_v_i(lce_cmd_v_i)
     ,.lce_cmd_ready_and_o(lce_cmd_ready_and_o)

     ,.lce_resp_header_o(lce_resp_header_o)
     ,.lce_resp_data_o(lce_resp_data_o)
     ,.lce_resp_v_o(lce_resp_v_o)
     ,.lce_resp_ready_and_i(lce_resp_ready_and_i)

     ,.lce_fill_header_i(lce_fill_header_i)
     ,.lce_fill_data_i(lce_fill_data_i)
     ,.lce_fill_v_i(lce_fill_v_i)
     ,.lce_fill_ready_and_o(lce_fill_ready_and_o)

     ,.lce_fill_header_o(lce_fill_header_o)
     ,.lce_fill_data_o(lce_fill_data_o)
     ,.lce_fill_v_o(lce_fill_v_o)
     ,.lce_fill_ready_and_i(lce_fill_ready_and_i)

     ,.debug_irq_i(debug_irq_li)
     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.m_external_irq_i(m_external_irq_li)
     ,.s_external_irq_i(s_external_irq_li)
     );

  // CCE drives all local memory requests
  assign proc_fwd_header_lo[cce_proc_id_lp] = mem_fwd_header_i;
  assign proc_fwd_data_lo[cce_proc_id_lp] = mem_fwd_data_i;
  assign proc_fwd_v_lo[cce_proc_id_lp] = mem_fwd_v_i;
  assign mem_fwd_ready_and_o = proc_fwd_ready_and_li[cce_proc_id_lp];

  assign mem_rev_header_o = proc_rev_header_li[cce_proc_id_lp];
  assign mem_rev_data_o = proc_rev_data_li[cce_proc_id_lp];
  assign mem_rev_v_o = proc_rev_v_li[cce_proc_id_lp];
  assign proc_rev_ready_and_lo[cce_proc_id_lp] = mem_rev_ready_and_i;

  // Select destination of CCE-Mem command from CCE
  logic [num_proc_lp-1:0][lg_num_dev_lp-1:0] proc_fwd_dst_lo;
  for (genvar i = 0; i < num_proc_lp; i++)
    begin : fwd_dest
      bp_local_addr_s local_addr;
      assign local_addr = proc_fwd_header_lo[i].addr;
      wire [dev_id_width_gp-1:0] device_fwd_li = local_addr.dev;
      wire is_local        = (local_addr < dram_base_addr_gp);

      wire is_cfg_fwd      = is_local & (device_fwd_li == cfg_dev_gp);
      wire is_clint_fwd    = is_local & (device_fwd_li == clint_dev_gp);

      wire is_l2s_fwd      = ~is_local;
      wire is_loopback_fwd = is_local & ~is_cfg_fwd & ~is_clint_fwd & ~is_l2s_fwd;

      localparam lg_l2_slices_lp = `BSG_SAFE_CLOG2(l2_slices_p);
      logic [lg_l2_slices_lp-1:0] slice_id;
      bp_me_dram_hash_encode
       #(.bp_params_p(bp_params_p))
       slice_select
        (.paddr_i(local_addr)
         ,.data_i()

         ,.dram_o()
         ,.daddr_o()
         ,.slice_o(slice_id)
         ,.bank_o()
         ,.data_o()
         );

      logic [l2_slices_p-1:0] is_l2s_slice_fwd;
      bsg_decode_with_v
       #(.num_out_p(l2_slices_p))
       slice_decode
        (.i(slice_id)
         ,.v_i(is_l2s_fwd)
         ,.o(is_l2s_slice_fwd)
         );

      wire [num_dev_lp-1:0] proc_fwd_dst_sel =
        (is_cfg_fwd << cfg_dev_id_lp)
        | (is_clint_fwd << clint_dev_id_lp)
        | (is_l2s_slice_fwd << l2s_dev_base_id_lp)
        | (is_loopback_fwd << loopback_dev_id_lp);

      bsg_encode_one_hot
       #(.width_p(num_dev_lp), .lo_to_hi_p(1))
       fwd_pe
        (.i(proc_fwd_dst_sel)
         ,.addr_o(proc_fwd_dst_lo[i])
         ,.v_o()
         );
    end

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.stream_mask_p(mem_fwd_stream_mask_gp)
     ,.num_source_p(num_proc_lp)
     ,.num_sink_p(num_dev_lp)
     )
   fwd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(proc_fwd_header_lo)
     ,.msg_data_i(proc_fwd_data_lo)
     ,.msg_v_i(proc_fwd_v_lo)
     ,.msg_ready_and_o(proc_fwd_ready_and_li)
     ,.msg_dst_i(proc_fwd_dst_lo)

     ,.msg_header_o(dev_fwd_header_li)
     ,.msg_data_o(dev_fwd_data_li)
     ,.msg_v_o(dev_fwd_v_li)
     ,.msg_ready_and_i(dev_fwd_ready_and_lo)
     );

  // All CCE-Mem network responses go to the CCE on this tile (id = 0 in xbar)
  wire [num_dev_lp-1:0][lg_num_proc_lp-1:0] dev_rev_dst_lo = '0;
  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.stream_mask_p(mem_rev_stream_mask_gp)
     ,.num_source_p(num_dev_lp)
     ,.num_sink_p(num_proc_lp)
     )
   rev_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(dev_rev_header_lo)
     ,.msg_data_i(dev_rev_data_lo)
     ,.msg_v_i(dev_rev_v_lo)
     ,.msg_ready_and_o(dev_rev_ready_and_li)
     ,.msg_dst_i(dev_rev_dst_lo)

     ,.msg_header_o(proc_rev_header_li)
     ,.msg_data_o(proc_rev_data_li)
     ,.msg_v_o(proc_rev_v_li)
     ,.msg_ready_and_i(proc_rev_ready_and_lo)
     );

  // Config
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[cfg_dev_id_lp])
     ,.mem_fwd_data_i(dev_fwd_data_li[cfg_dev_id_lp])
     ,.mem_fwd_v_i(dev_fwd_v_li[cfg_dev_id_lp])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[cfg_dev_id_lp])

     ,.mem_rev_header_o(dev_rev_header_lo[cfg_dev_id_lp])
     ,.mem_rev_data_o(dev_rev_data_lo[cfg_dev_id_lp])
     ,.mem_rev_v_o(dev_rev_v_lo[cfg_dev_id_lp])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[cfg_dev_id_lp])

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
   clints
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.mem_fwd_header_i(dev_fwd_header_li[clint_dev_id_lp])
     ,.mem_fwd_data_i(dev_fwd_data_li[clint_dev_id_lp])
     ,.mem_fwd_v_i(dev_fwd_v_li[clint_dev_id_lp])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[clint_dev_id_lp])

     ,.mem_rev_header_o(dev_rev_header_lo[clint_dev_id_lp])
     ,.mem_rev_data_o(dev_rev_data_lo[clint_dev_id_lp])
     ,.mem_rev_v_o(dev_rev_v_lo[clint_dev_id_lp])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[clint_dev_id_lp])

     ,.debug_irq_o(debug_irq_li)
     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.m_external_irq_o(m_external_irq_li)
     ,.s_external_irq_o(s_external_irq_li)
     );

  // CCE-Mem network to L2 Cache adapter
  for (genvar i = 0; i < l2_slices_p; i++)
    begin : slices
      bp_me_cache_slice
       #(.bp_params_p(bp_params_p))
       l2s
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.mem_fwd_header_i(dev_fwd_header_li[l2s_dev_base_id_lp+i])
         ,.mem_fwd_data_i(dev_fwd_data_li[l2s_dev_base_id_lp+i])
         ,.mem_fwd_v_i(dev_fwd_v_li[l2s_dev_base_id_lp+i])
         ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[l2s_dev_base_id_lp+i])

         ,.mem_rev_header_o(dev_rev_header_lo[l2s_dev_base_id_lp+i])
         ,.mem_rev_data_o(dev_rev_data_lo[l2s_dev_base_id_lp+i])
         ,.mem_rev_v_o(dev_rev_v_lo[l2s_dev_base_id_lp+i])
         ,.mem_rev_ready_and_i(dev_rev_ready_and_li[l2s_dev_base_id_lp+i])

         ,.dma_pkt_o(dma_pkt_o[i])
         ,.dma_pkt_v_o(dma_pkt_v_o[i])
         ,.dma_pkt_ready_and_i(dma_pkt_ready_and_i[i])

         ,.dma_data_i(dma_data_i[i])
         ,.dma_data_v_i(dma_data_v_i[i])
         ,.dma_data_ready_and_o(dma_data_ready_and_o[i])

         ,.dma_data_o(dma_data_o[i])
         ,.dma_data_v_o(dma_data_v_o[i])
         ,.dma_data_ready_and_i(dma_data_ready_and_i[i])
         );
    end

  // Loopback
  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(dev_fwd_header_li[loopback_dev_id_lp])
     ,.mem_fwd_data_i(dev_fwd_data_li[loopback_dev_id_lp])
     ,.mem_fwd_v_i(dev_fwd_v_li[loopback_dev_id_lp])
     ,.mem_fwd_ready_and_o(dev_fwd_ready_and_lo[loopback_dev_id_lp])

     ,.mem_rev_header_o(dev_rev_header_lo[loopback_dev_id_lp])
     ,.mem_rev_data_o(dev_rev_data_lo[loopback_dev_id_lp])
     ,.mem_rev_v_o(dev_rev_v_lo[loopback_dev_id_lp])
     ,.mem_rev_ready_and_i(dev_rev_ready_and_li[loopback_dev_id_lp])
     );

endmodule

