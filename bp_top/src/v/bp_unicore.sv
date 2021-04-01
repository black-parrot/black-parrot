
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_unicore
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   // Outgoing I/O
   , output logic [uce_mem_msg_width_lp-1:0]           io_cmd_o
   , output logic                                      io_cmd_v_o
   , input                                             io_cmd_ready_i

   , input [uce_mem_msg_width_lp-1:0]                  io_resp_i
   , input                                             io_resp_v_i
   , output logic                                      io_resp_yumi_o

   // Incoming I/O
   , input [uce_mem_msg_width_lp-1:0]                  io_cmd_i
   , input                                             io_cmd_v_i
   , output logic                                      io_cmd_yumi_o

   , output logic [uce_mem_msg_width_lp-1:0]           io_resp_o
   , output logic                                      io_resp_v_o
   , input                                             io_resp_ready_i

   // DRAM interface
   , output logic [dma_pkt_width_lp-1:0]               dma_pkt_o
   , output logic                                      dma_pkt_v_o
   , input                                             dma_pkt_yumi_i

   , input [l2_fill_width_p-1:0]                       dma_data_i
   , input                                             dma_data_v_i
   , output logic                                      dma_data_ready_and_o

   , output logic [l2_fill_width_p-1:0]                dma_data_o
   , output logic                                      dma_data_v_o
   , input                                             dma_data_yumi_i
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  `declare_bp_bedrock_mem_if(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce);
  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);

  bp_icache_req_s icache_req_lo;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_busy_li;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic icache_req_metadata_v_lo;
  logic icache_req_critical_li, icache_req_complete_li;
  logic icache_req_credits_full_li, icache_req_credits_empty_li;

  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_li;
  logic icache_tag_mem_pkt_v_li, icache_tag_mem_pkt_yumi_lo;
  bp_icache_tag_info_s icache_tag_mem_lo;

  bp_icache_data_mem_pkt_s icache_data_mem_pkt_li;
  logic icache_data_mem_pkt_v_li, icache_data_mem_pkt_yumi_lo;
  logic [icache_block_width_p-1:0] icache_data_mem_lo;

  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_li;
  logic icache_stat_mem_pkt_v_li, icache_stat_mem_pkt_yumi_lo;
  bp_icache_stat_info_s icache_stat_mem_lo;

  bp_dcache_req_s dcache_req_lo;
  logic dcache_req_v_lo, dcache_req_yumi_li, dcache_req_busy_li;
  bp_dcache_req_metadata_s dcache_req_metadata_lo;
  logic dcache_req_metadata_v_lo;
  logic dcache_req_critical_li, dcache_req_complete_li;
  logic dcache_req_credits_full_li, dcache_req_credits_empty_li;

  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_li;
  logic dcache_tag_mem_pkt_v_li, dcache_tag_mem_pkt_yumi_lo;
  bp_dcache_tag_info_s dcache_tag_mem_lo;

  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_li;
  logic dcache_data_mem_pkt_v_li, dcache_data_mem_pkt_yumi_lo;
  logic [dcache_block_width_p-1:0] dcache_data_mem_lo;

  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_li;
  logic dcache_stat_mem_pkt_v_li, dcache_stat_mem_pkt_yumi_lo;
  bp_dcache_stat_info_s dcache_stat_mem_lo;

  logic timer_irq_li, software_irq_li, external_irq_li;

  bp_bedrock_uce_mem_msg_s [2:0] proc_cmd_lo;
  logic [2:0] proc_cmd_v_lo, proc_cmd_yumi_li, proc_cmd_last_lo;
  bp_bedrock_uce_mem_msg_s [2:0] proc_resp_li;
  logic [2:0] proc_resp_v_li, proc_resp_ready_lo, proc_resp_last_li, proc_resp_yumi_lo;

  bp_bedrock_uce_mem_msg_s cfg_cmd_li;
  bp_bedrock_xce_mem_msg_s cfg_cmd;
  logic cfg_cmd_v_li, cfg_cmd_ready_lo;
  bp_bedrock_uce_mem_msg_s cfg_resp_lo;
  bp_bedrock_xce_mem_msg_s cfg_resp;
  logic cfg_resp_v_lo, cfg_resp_yumi_li;
  assign cfg_cmd = '{header: cfg_cmd_li.header
                    ,data: cfg_cmd_li.data[0+:dword_width_gp]
                    };
  assign cfg_resp_lo = '{header: cfg_resp.header
                        ,data: {uce_mem_data_width_lp/dword_width_gp{cfg_resp.data}}
                        };

  bp_bedrock_uce_mem_msg_s clint_cmd_li;
  bp_bedrock_xce_mem_msg_s clint_cmd;
  logic clint_cmd_v_li, clint_cmd_ready_lo;
  bp_bedrock_uce_mem_msg_s clint_resp_lo;
  bp_bedrock_xce_mem_msg_s clint_resp;
  logic clint_resp_v_lo, clint_resp_yumi_li;
  assign clint_cmd = '{header: clint_cmd_li.header
                      ,data: clint_cmd_li.data[0+:dword_width_gp]
                      };
  assign clint_resp_lo = '{header: clint_resp.header
                          ,data: {uce_mem_data_width_lp/dword_width_gp{clint_resp.data}}
                          };

  bp_bedrock_uce_mem_msg_s cache_cmd_li;
  logic cache_cmd_v_li, cache_cmd_ready_and_lo, cache_cmd_last_li;
  bp_bedrock_uce_mem_msg_s cache_resp_lo;
  logic cache_resp_v_lo, cache_resp_ready_and_li, cache_resp_last_lo;

  bp_bedrock_uce_mem_msg_s loopback_cmd_li;
  bp_bedrock_xce_mem_msg_s loopback_cmd;
  logic loopback_cmd_v_li, loopback_cmd_ready_lo;
  bp_bedrock_uce_mem_msg_s loopback_resp_lo;
  bp_bedrock_xce_mem_msg_s loopback_resp;
  logic loopback_resp_v_lo, loopback_resp_yumi_li;
  assign loopback_cmd = '{header: loopback_cmd_li.header
                         ,data: loopback_cmd_li.data[0+:dword_width_gp]
                         };
  assign loopback_resp_lo = '{header: loopback_resp.header
                             ,data: {uce_mem_data_width_lp/dword_width_gp{loopback_resp.data}}
                             };

  bp_cfg_bus_s cfg_bus_lo;
  bp_core_minimal
   #(.bp_params_p(bp_params_p))
   core_minimal
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_lo)

     ,.icache_req_o(icache_req_lo)
     ,.icache_req_v_o(icache_req_v_lo)
     ,.icache_req_yumi_i(icache_req_yumi_li)
     ,.icache_req_busy_i(icache_req_busy_li)
     ,.icache_req_metadata_o(icache_req_metadata_lo)
     ,.icache_req_metadata_v_o(icache_req_metadata_v_lo)
     ,.icache_req_complete_i(icache_req_complete_li)
     ,.icache_req_critical_i(icache_req_critical_li)
     ,.icache_req_credits_full_i(icache_req_credits_full_li)
     ,.icache_req_credits_empty_i(icache_req_credits_empty_li)

     ,.icache_tag_mem_pkt_i(icache_tag_mem_pkt_li)
     ,.icache_tag_mem_pkt_v_i(icache_tag_mem_pkt_v_li)
     ,.icache_tag_mem_pkt_yumi_o(icache_tag_mem_pkt_yumi_lo)
     ,.icache_tag_mem_o(icache_tag_mem_lo)

     ,.icache_data_mem_pkt_i(icache_data_mem_pkt_li)
     ,.icache_data_mem_pkt_v_i(icache_data_mem_pkt_v_li)
     ,.icache_data_mem_pkt_yumi_o(icache_data_mem_pkt_yumi_lo)
     ,.icache_data_mem_o(icache_data_mem_lo)

     ,.icache_stat_mem_pkt_v_i(icache_stat_mem_pkt_v_li)
     ,.icache_stat_mem_pkt_i(icache_stat_mem_pkt_li)
     ,.icache_stat_mem_pkt_yumi_o(icache_stat_mem_pkt_yumi_lo)
     ,.icache_stat_mem_o(icache_stat_mem_lo)

     ,.dcache_req_o(dcache_req_lo)
     ,.dcache_req_v_o(dcache_req_v_lo)
     ,.dcache_req_yumi_i(dcache_req_yumi_li)
     ,.dcache_req_busy_i(dcache_req_busy_li)
     ,.dcache_req_metadata_o(dcache_req_metadata_lo)
     ,.dcache_req_metadata_v_o(dcache_req_metadata_v_lo)
     ,.dcache_req_complete_i(dcache_req_complete_li)
     ,.dcache_req_critical_i(dcache_req_critical_li)
     ,.dcache_req_credits_full_i(dcache_req_credits_full_li)
     ,.dcache_req_credits_empty_i(dcache_req_credits_empty_li)

     ,.dcache_tag_mem_pkt_i(dcache_tag_mem_pkt_li)
     ,.dcache_tag_mem_pkt_v_i(dcache_tag_mem_pkt_v_li)
     ,.dcache_tag_mem_pkt_yumi_o(dcache_tag_mem_pkt_yumi_lo)
     ,.dcache_tag_mem_o(dcache_tag_mem_lo)

     ,.dcache_data_mem_pkt_i(dcache_data_mem_pkt_li)
     ,.dcache_data_mem_pkt_v_i(dcache_data_mem_pkt_v_li)
     ,.dcache_data_mem_pkt_yumi_o(dcache_data_mem_pkt_yumi_lo)
     ,.dcache_data_mem_o(dcache_data_mem_lo)

     ,.dcache_stat_mem_pkt_v_i(dcache_stat_mem_pkt_v_li)
     ,.dcache_stat_mem_pkt_i(dcache_stat_mem_pkt_li)
     ,.dcache_stat_mem_pkt_yumi_o(dcache_stat_mem_pkt_yumi_lo)
     ,.dcache_stat_mem_o(dcache_stat_mem_lo)

     ,.timer_irq_i(timer_irq_li)
     ,.software_irq_i(software_irq_li)
     ,.external_irq_i(external_irq_li)
     );

  wire [1:0][lce_id_width_p-1:0] lce_id_li = {cfg_bus_lo.dcache_id, cfg_bus_lo.icache_id};
  bp_uce
   #(.bp_params_p(bp_params_p)
    ,.uce_mem_data_width_p(uce_mem_data_width_lp)
    ,.assoc_p(dcache_assoc_p)
    ,.sets_p(dcache_sets_p)
    ,.block_width_p(dcache_block_width_p)
    ,.fill_width_p(dcache_fill_width_p)
    ,.data_mem_invert_clk_p(1)
    ,.tag_mem_invert_clk_p(1)
    ,.metadata_latency_p(1)
    )
   dcache_uce
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(lce_id_li[1])

    ,.cache_req_i(dcache_req_lo)
    ,.cache_req_v_i(dcache_req_v_lo)
    ,.cache_req_yumi_o(dcache_req_yumi_li)
    ,.cache_req_busy_o(dcache_req_busy_li)
    ,.cache_req_metadata_i(dcache_req_metadata_lo)
    ,.cache_req_metadata_v_i(dcache_req_metadata_v_lo)
    ,.cache_req_critical_o(dcache_req_critical_li)
    ,.cache_req_complete_o(dcache_req_complete_li)
    ,.cache_req_credits_full_o(dcache_req_credits_full_li)
    ,.cache_req_credits_empty_o(dcache_req_credits_empty_li)

    ,.tag_mem_pkt_o(dcache_tag_mem_pkt_li)
    ,.tag_mem_pkt_v_o(dcache_tag_mem_pkt_v_li)
    ,.tag_mem_pkt_yumi_i(dcache_tag_mem_pkt_yumi_lo)
    ,.tag_mem_i(dcache_tag_mem_lo)

    ,.data_mem_pkt_o(dcache_data_mem_pkt_li)
    ,.data_mem_pkt_v_o(dcache_data_mem_pkt_v_li)
    ,.data_mem_pkt_yumi_i(dcache_data_mem_pkt_yumi_lo)
    ,.data_mem_i(dcache_data_mem_lo)

    ,.stat_mem_pkt_o(dcache_stat_mem_pkt_li)
    ,.stat_mem_pkt_v_o(dcache_stat_mem_pkt_v_li)
    ,.stat_mem_pkt_yumi_i(dcache_stat_mem_pkt_yumi_lo)
    ,.stat_mem_i(dcache_stat_mem_lo)

    ,.mem_cmd_header_o(proc_cmd_lo[1].header)
    ,.mem_cmd_data_o(proc_cmd_lo[1].data[0+:dcache_fill_width_p])
    ,.mem_cmd_last_o(proc_cmd_last_lo[1])
    ,.mem_cmd_v_o(proc_cmd_v_lo[1])
    ,.mem_cmd_ready_and_i(proc_cmd_yumi_li[1])

    ,.mem_resp_header_i(proc_resp_li[1].header)
    ,.mem_resp_data_i(proc_resp_li[1].data[0+:dcache_fill_width_p])
    ,.mem_resp_last_i(proc_resp_last_li[1])
    ,.mem_resp_v_i(proc_resp_v_li[1])
    ,.mem_resp_ready_and_o(proc_resp_ready_lo[1])
    );

  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.uce_mem_data_width_p(uce_mem_data_width_lp)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     ,.metadata_latency_p(1)
     )
   icache_uce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_li[0])

     ,.cache_req_i(icache_req_lo)
     ,.cache_req_v_i(icache_req_v_lo)
     ,.cache_req_yumi_o(icache_req_yumi_li)
     ,.cache_req_busy_o(icache_req_busy_li)
     ,.cache_req_metadata_i(icache_req_metadata_lo)
     ,.cache_req_metadata_v_i(icache_req_metadata_v_lo)
     ,.cache_req_critical_o(icache_req_critical_li)
     ,.cache_req_complete_o(icache_req_complete_li)
     ,.cache_req_credits_full_o(icache_req_credits_full_li)
     ,.cache_req_credits_empty_o(icache_req_credits_empty_li)

     ,.tag_mem_pkt_o(icache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_o(icache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_i(icache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_i(icache_tag_mem_lo)

     ,.data_mem_pkt_o(icache_data_mem_pkt_li)
     ,.data_mem_pkt_v_o(icache_data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_i(icache_data_mem_pkt_yumi_lo)
     ,.data_mem_i(icache_data_mem_lo)

     ,.stat_mem_pkt_o(icache_stat_mem_pkt_li)
     ,.stat_mem_pkt_v_o(icache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_yumi_i(icache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(icache_stat_mem_lo)

     ,.mem_cmd_header_o(proc_cmd_lo[0].header)
     ,.mem_cmd_data_o(proc_cmd_lo[0].data[0+:icache_fill_width_p])
     ,.mem_cmd_last_o(proc_cmd_last_lo[0])
     ,.mem_cmd_v_o(proc_cmd_v_lo[0])
     ,.mem_cmd_ready_and_i(proc_cmd_yumi_li[0])

     ,.mem_resp_header_i(proc_resp_li[0].header)
     ,.mem_resp_data_i(proc_resp_li[0].data[0+:icache_fill_width_p])
     ,.mem_resp_last_i(proc_resp_last_li[0])
     ,.mem_resp_v_i(proc_resp_v_li[0])
     ,.mem_resp_ready_and_o(proc_resp_ready_lo[0])
     );

  bp_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(clint_cmd)
     ,.mem_cmd_v_i(clint_cmd_v_li)
     ,.mem_cmd_ready_o(clint_cmd_ready_lo)

     ,.mem_resp_o(clint_resp)
     ,.mem_resp_v_o(clint_resp_v_lo)
     ,.mem_resp_yumi_i(clint_resp_yumi_li)

     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.external_irq_o(external_irq_li)
     );

  bp_cfg
   #(.bp_params_p(bp_params_p))
   cfg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(cfg_cmd)
     ,.mem_cmd_v_i(cfg_cmd_v_li)
     ,.mem_cmd_ready_o(cfg_cmd_ready_lo)

     ,.mem_resp_o(cfg_resp)
     ,.mem_resp_v_o(cfg_resp_v_lo)
     ,.mem_resp_yumi_i(cfg_resp_yumi_li)

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i('0)
     ,.host_did_i('0)
     ,.cord_i({coh_noc_y_cord_width_p'(1), coh_noc_x_cord_width_p'(0)})

     ,.cce_ucode_v_o()
     ,.cce_ucode_w_o()
     ,.cce_ucode_addr_o()
     ,.cce_ucode_data_o()
     ,.cce_ucode_data_i('0)
     );

  // Assign incoming I/O as basically another UCE interface
  assign proc_cmd_lo[2] = io_cmd_i[0+:uce_mem_msg_width_lp];
  assign proc_cmd_v_lo[2] = io_cmd_v_i;
  assign io_cmd_yumi_o = proc_cmd_yumi_li[2];
  assign proc_cmd_last_lo[2] = io_cmd_v_i;

  assign proc_resp_ready_lo[2] = io_resp_ready_i;
  assign io_resp_o = uce_mem_msg_width_lp'(proc_resp_li[2]);
  assign io_resp_v_o = proc_resp_v_li[2] & io_resp_ready_i;
  wire io_resp_last_unused = proc_resp_last_li[2] & proc_resp_v_li[2]; 

  // Command arbitration logic
  // This is suboptimal for performance, because a blocked I/O channel will put backpressure on the
  //   cache.
  logic cmd_selected_last_li;
  wire cmd_arb_ready_li = &{cfg_cmd_ready_lo, clint_cmd_ready_lo, io_cmd_ready_i, cache_cmd_ready_and_lo, loopback_cmd_ready_lo};
  wire cmd_arb_unlock = |(proc_cmd_yumi_li & proc_cmd_last_lo);
  bsg_locking_arb_fixed
   #(.inputs_p(3)
   ,.lo_to_hi_p(0))
   cmd_arb
    (.clk_i(clk_i)
    ,.ready_i(cmd_arb_ready_li)

    ,.unlock_i(reset_i | cmd_arb_unlock)

    ,.reqs_i(proc_cmd_v_lo)
    ,.grants_o(proc_cmd_yumi_li)
    ); 
  assign cmd_selected_last_li = cmd_arb_unlock;

  bp_bedrock_uce_mem_msg_s proc_cmd_selected_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_bedrock_uce_mem_msg_s)), .els_p(3))
   cmd_select
    (.data_i(proc_cmd_lo)
     ,.sel_one_hot_i(proc_cmd_yumi_li)
     ,.data_o(proc_cmd_selected_lo)
     );
  assign {loopback_cmd_li, cache_cmd_li, io_cmd_o, clint_cmd_li, cfg_cmd_li} = {5{proc_cmd_selected_lo}};

  // Response arbitration logic
  // UCEs may send two commands as part of a writeback routine. Responses can come back in
  //   arbitrary orders, especially when considering CLINT or I/O responses
  // This is also suboptimal. Theoretically, we could dequeue into each fifo at once, but this
  //   would require more complex arbitration logic
  logic resp_selected_last_lo;
  logic loopback_resp_grant_li, cache_resp_grant_li, io_resp_grant_lo, clint_resp_grant_li, cfg_resp_grant_li;
  wire resp_arb_unlock = |{loopback_resp_yumi_li, (cache_resp_ready_and_li & cache_resp_last_lo), io_resp_yumi_o, clint_resp_yumi_li, cfg_resp_yumi_li};
  bsg_locking_arb_fixed
   #(.inputs_p(5)
   ,.lo_to_hi_p(0))
   resp_arb
    (.clk_i(clk_i)
    ,.ready_i(1'b1)

    ,.unlock_i(reset_i | resp_arb_unlock)

    ,.reqs_i({loopback_resp_v_lo, cache_resp_v_lo, io_resp_v_i, clint_resp_v_lo, cfg_resp_v_lo})
    ,.grants_o({loopback_resp_grant_li, cache_resp_grant_li, io_resp_grant_lo, clint_resp_grant_li, cfg_resp_grant_li})
    ); 
  assign resp_selected_last_lo = resp_arb_unlock;

  for (genvar i = 0; i < 3; i++)
    begin : resp_match
      bp_bedrock_uce_mem_payload_s proc_resp_selected_payload_li;
      assign proc_resp_selected_payload_li = proc_resp_li[i].header.payload;
      bsg_mux_one_hot
       #(.width_p($bits(bp_bedrock_uce_mem_msg_s)), .els_p(5))
       resp_select
        (.data_i({loopback_resp_lo, cache_resp_lo, io_resp_i, clint_resp_lo, cfg_resp_lo})
        ,.sel_one_hot_i({loopback_resp_grant_li, cache_resp_grant_li, io_resp_grant_lo, clint_resp_grant_li, cfg_resp_grant_li})
        ,.data_o(proc_resp_li[i])
        );

      wire any_resp_v_li = |{loopback_resp_v_lo, cache_resp_v_lo, io_resp_v_i, clint_resp_v_lo, cfg_resp_v_lo};
      assign proc_resp_v_li[i] = any_resp_v_li & (proc_resp_selected_payload_li.lce_id == i);
      assign proc_resp_yumi_lo[i] = proc_resp_v_li[i] & proc_resp_ready_lo[i];
      assign proc_resp_last_li[i] = resp_selected_last_lo;
    end
  assign cfg_resp_yumi_li        = |proc_resp_yumi_lo & cfg_resp_grant_li;
  assign clint_resp_yumi_li      = |proc_resp_yumi_lo & clint_resp_grant_li;
  assign io_resp_yumi_o          = |proc_resp_yumi_lo & io_resp_grant_lo;
  assign cache_resp_ready_and_li = |proc_resp_yumi_lo & cache_resp_grant_li;
  assign loopback_resp_yumi_li   = |proc_resp_yumi_lo & loopback_resp_grant_li;

  bp_local_addr_s local_addr_cast;
  assign local_addr_cast = proc_cmd_selected_lo.header.addr;
  wire [dev_id_width_gp-1:0] device_cmd_li = local_addr_cast.dev;

  wire local_cmd_li        = (proc_cmd_selected_lo.header.addr < dram_base_addr_gp);
  wire is_other_domain     = (proc_cmd_selected_lo.header.addr[paddr_width_p-1-:domain_width_p] != 0);
  wire is_cfg_cmd          = local_cmd_li & (device_cmd_li == cfg_dev_gp);
  wire is_clint_cmd        = local_cmd_li & (device_cmd_li == clint_dev_gp);
  wire is_io_cmd           = (local_cmd_li & (device_cmd_li inside {boot_dev_gp, host_dev_gp})) | is_other_domain;
  wire is_cache_cmd        = (~local_cmd_li & ~is_other_domain) || (local_cmd_li & (device_cmd_li == cache_dev_gp));
  wire is_loopback_cmd     = local_cmd_li & ~is_cfg_cmd & ~is_clint_cmd & ~is_io_cmd & ~is_cache_cmd;

  assign cfg_cmd_v_li      = is_cfg_cmd   & |proc_cmd_yumi_li;
  assign clint_cmd_v_li    = is_clint_cmd & |proc_cmd_yumi_li;
  assign io_cmd_v_o        = is_io_cmd    & |proc_cmd_yumi_li;
  assign cache_cmd_v_li    = is_cache_cmd & |proc_cmd_yumi_li;
  assign loopback_cmd_v_li = is_loopback_cmd & |proc_cmd_yumi_li;
  assign cache_cmd_last_li = cache_cmd_v_li & cmd_selected_last_li; // Only L2 will used the last signal

  bp_cce_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(loopback_cmd)
     ,.mem_cmd_v_i(loopback_cmd_v_li)
     ,.mem_cmd_ready_o(loopback_cmd_ready_lo)

     ,.mem_resp_o(loopback_resp)
     ,.mem_resp_v_o(loopback_resp_v_lo)
     ,.mem_resp_yumi_i(loopback_resp_yumi_li)
     );

  `declare_bsg_cache_pkt_s(caddr_width_p, l2_data_width_p);
  bsg_cache_pkt_s cache_pkt_li;
  logic cache_pkt_v_li, cache_pkt_ready_lo;
  logic [l2_data_width_p-1:0] cache_data_lo;
  logic cache_data_v_lo, cache_data_yumi_li;
  bp_me_cce_to_cache
   #(.bp_params_p(bp_params_p)
   ,.mem_data_width_p(uce_mem_data_width_lp))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(cache_cmd_li.header)
     ,.mem_cmd_data_i(cache_cmd_li.data)
     ,.mem_cmd_last_i(cache_cmd_last_li)
     ,.mem_cmd_v_i(cache_cmd_v_li)
     ,.mem_cmd_ready_and_o(cache_cmd_ready_and_lo)

     ,.mem_resp_header_o(cache_resp_lo.header)
     ,.mem_resp_data_o(cache_resp_lo.data)
     ,.mem_resp_last_o(cache_resp_last_lo)
     ,.mem_resp_v_o(cache_resp_v_lo)
     ,.mem_resp_ready_and_i(cache_resp_ready_and_li)
  
     ,.cache_pkt_o(cache_pkt_li)
     ,.cache_pkt_v_o(cache_pkt_v_li)
     ,.cache_pkt_ready_i(cache_pkt_ready_lo)

     ,.cache_data_i(cache_data_lo)
     ,.cache_v_i(cache_data_v_lo)
     ,.cache_yumi_o(cache_data_yumi_li)
     );

  
  bsg_cache
   #(.addr_width_p(caddr_width_p)
     ,.data_width_p(l2_data_width_p)
     ,.block_size_in_words_p(l2_block_size_in_words_p)
     ,.sets_p(l2_en_p ? l2_sets_p : 2)
     ,.ways_p(l2_en_p ? l2_assoc_p : 2)
     ,.amo_support_p(((amo_swap_p == e_l2) << e_cache_amo_swap)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_xor)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_and)
                     | ((amo_fetch_logic_p == e_l2) << e_cache_amo_or)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_add)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_min)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_max)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_minu)
                     | ((amo_fetch_arithmetic_p == e_l2) << e_cache_amo_maxu)
                     )
     ,.dma_data_width_p(l2_fill_width_p)
    )
   cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.cache_pkt_i(cache_pkt_li)
     ,.v_i(cache_pkt_v_li)
     ,.ready_o(cache_pkt_ready_lo)
  
     ,.data_o(cache_data_lo)
     ,.v_o(cache_data_v_lo)
     ,.yumi_i(cache_data_yumi_li)
  
     ,.dma_pkt_o(dma_pkt_o)
     ,.dma_pkt_v_o(dma_pkt_v_o)
     ,.dma_pkt_yumi_i(dma_pkt_yumi_i)
  
     ,.dma_data_i(dma_data_i)
     ,.dma_data_v_i(dma_data_v_i)
     ,.dma_data_ready_o(dma_data_ready_and_o)
  
     ,.dma_data_o(dma_data_o)
     ,.dma_data_v_o(dma_data_v_o)
     ,.dma_data_yumi_i(dma_data_yumi_i)
  
     ,.v_we_o()
     );

endmodule

