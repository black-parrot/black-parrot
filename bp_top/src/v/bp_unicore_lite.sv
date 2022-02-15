
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_unicore_lite
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   , input [io_noc_did_width_p-1:0]                    my_did_i
   , input [io_noc_did_width_p-1:0]                    host_did_i
   , input [coh_noc_cord_width_p-1:0]                  my_cord_i

   // Outgoing I/O
   , output logic [mem_header_width_lp-1:0]            io_cmd_header_o
   , output logic [uce_fill_width_p-1:0]               io_cmd_data_o
   , output logic                                      io_cmd_v_o
   , input                                             io_cmd_ready_and_i
   , output logic                                      io_cmd_last_o

   , input [mem_header_width_lp-1:0]                   io_resp_header_i
   , input [uce_fill_width_p-1:0]                      io_resp_data_i
   , input                                             io_resp_v_i
   , output logic                                      io_resp_ready_and_o
   , input                                             io_resp_last_i

   // Incoming I/O
   , input [mem_header_width_lp-1:0]                   io_cmd_header_i
   , input [uce_fill_width_p-1:0]                      io_cmd_data_i
   , input                                             io_cmd_v_i
   , output logic                                      io_cmd_ready_and_o
   , input                                             io_cmd_last_i

   , output logic [mem_header_width_lp-1:0]            io_resp_header_o
   , output logic [uce_fill_width_p-1:0]               io_resp_data_o
   , output logic                                      io_resp_v_o
   , input                                             io_resp_ready_and_i
   , output logic                                      io_resp_last_o

   // Outgoing BP Stream Mem Bus
   , output logic [mem_header_width_lp-1:0]            mem_cmd_header_o
   , output logic [uce_fill_width_p-1:0]               mem_cmd_data_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_and_i
   , output logic                                      mem_cmd_last_o

   , input [mem_header_width_lp-1:0]                   mem_resp_header_i
   , input [uce_fill_width_p-1:0]                      mem_resp_data_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_ready_and_o
   , input                                             mem_resp_last_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `bp_cast_o(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_resp_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, io_resp_header);
  `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);

  bp_icache_req_s icache_req_lo;
  logic icache_req_v_lo, icache_req_yumi_li, icache_req_busy_li;
  bp_icache_req_metadata_s icache_req_metadata_lo;
  logic icache_req_metadata_v_lo;
  logic icache_req_critical_tag_li, icache_req_critical_data_li, icache_req_complete_li;
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
  logic dcache_req_critical_tag_li, dcache_req_critical_data_li, dcache_req_complete_li;
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

  bp_bedrock_mem_header_s [2:0] proc_cmd_header_lo;
  logic [2:0] proc_cmd_v_lo, proc_cmd_ready_and_li, proc_cmd_last_lo;
  bp_bedrock_mem_header_s [2:0] proc_resp_header_li;
  logic [2:0] proc_resp_v_li, proc_resp_ready_and_lo, proc_resp_last_li;

  // dev_cmd[4:0] = {CCE loopback, Mem cmd, IO cmd, CLINT, CFG}
  bp_bedrock_mem_header_s [4:0] dev_cmd_header_li;
  logic [4:0] dev_cmd_v_li, dev_cmd_ready_and_lo, dev_cmd_last_li;
  bp_bedrock_mem_header_s [4:0] dev_resp_header_lo;
  logic [4:0] dev_resp_v_lo, dev_resp_ready_and_li, dev_resp_last_lo;

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
     ,.icache_req_critical_tag_i(icache_req_critical_tag_li)
     ,.icache_req_critical_data_i(icache_req_critical_data_li)
     ,.icache_req_complete_i(icache_req_complete_li)
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
     ,.dcache_req_critical_tag_i(dcache_req_critical_tag_li)
     ,.dcache_req_critical_data_i(dcache_req_critical_data_li)
     ,.dcache_req_complete_i(dcache_req_complete_li)
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
  logic [uce_fill_width_p-1:0] icache_cmd_data_lo, icache_resp_data_li;
  bp_uce
   #(.bp_params_p(bp_params_p)
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
     ,.cache_req_critical_tag_o(icache_req_critical_tag_li)
     ,.cache_req_critical_data_o(icache_req_critical_data_li)
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

     ,.mem_cmd_header_o(proc_cmd_header_lo[0])
     ,.mem_cmd_data_o(icache_cmd_data_lo)
     ,.mem_cmd_v_o(proc_cmd_v_lo[0])
     ,.mem_cmd_ready_and_i(proc_cmd_ready_and_li[0])
     ,.mem_cmd_last_o(proc_cmd_last_lo[0])

     ,.mem_resp_header_i(proc_resp_header_li[0])
     ,.mem_resp_data_i(icache_resp_data_li)
     ,.mem_resp_v_i(proc_resp_v_li[0])
     ,.mem_resp_ready_and_o(proc_resp_ready_and_lo[0])
     ,.mem_resp_last_i(proc_resp_last_li[0])
     );

  logic [uce_fill_width_p-1:0] dcache_cmd_data_lo, dcache_resp_data_li;
  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p)
     ,.fill_width_p(uce_fill_width_p)
     ,.req_invert_clk_p(1)
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
    ,.cache_req_critical_tag_o(dcache_req_critical_tag_li)
    ,.cache_req_critical_data_o(dcache_req_critical_data_li)
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

    ,.mem_cmd_header_o(proc_cmd_header_lo[1])
    ,.mem_cmd_data_o(dcache_cmd_data_lo)
    ,.mem_cmd_v_o(proc_cmd_v_lo[1])
    ,.mem_cmd_ready_and_i(proc_cmd_ready_and_li[1])
    ,.mem_cmd_last_o(proc_cmd_last_lo[1])
    ,.mem_resp_header_i(proc_resp_header_li[1])
    ,.mem_resp_data_i(dcache_resp_data_li)
    ,.mem_resp_v_i(proc_resp_v_li[1])
    ,.mem_resp_ready_and_o(proc_resp_ready_and_lo[1])
    ,.mem_resp_last_i(proc_resp_last_li[1])
    );

  // Assign incoming I/O as basically another UCE interface
  assign proc_cmd_header_lo[2] = io_cmd_header_cast_i;
  assign proc_cmd_v_lo[2] = io_cmd_v_i;
  assign io_cmd_ready_and_o = proc_cmd_ready_and_li[2];
  assign proc_cmd_last_lo[2] = io_cmd_last_i;

  assign io_resp_header_cast_o = proc_resp_header_li[2];
  assign io_resp_v_o = proc_resp_v_li[2];
  assign proc_resp_ready_and_lo[2] = io_resp_ready_and_i & io_resp_v_o;
  assign io_resp_last_o = proc_resp_last_li[2];

  logic [dword_width_gp-1:0] cfg_resp_data_lo, cfg_cmd_data_li;
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(dev_cmd_header_li[0])
     ,.mem_cmd_data_i(cfg_cmd_data_li)
     ,.mem_cmd_v_i(dev_cmd_v_li[0])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[0])
     ,.mem_cmd_last_i(dev_cmd_last_li[0])

     ,.mem_resp_header_o(dev_resp_header_lo[0])
     ,.mem_resp_data_o(cfg_resp_data_lo)
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

  logic [dword_width_gp-1:0] clint_resp_data_lo, clint_cmd_data_li;
  bp_me_clint_slice
   #(.bp_params_p(bp_params_p))
   clint
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.id_i(cfg_bus_lo.core_id)

     ,.mem_cmd_header_i(dev_cmd_header_li[1])
     ,.mem_cmd_data_i(clint_cmd_data_li)
     ,.mem_cmd_v_i(dev_cmd_v_li[1])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[1])
     ,.mem_cmd_last_i(dev_cmd_last_li[1])

     ,.mem_resp_header_o(dev_resp_header_lo[1])
     ,.mem_resp_data_o(clint_resp_data_lo)
     ,.mem_resp_v_o(dev_resp_v_lo[1])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[1])
     ,.mem_resp_last_o(dev_resp_last_lo[1])
     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.external_irq_o(external_irq_li)
     );

  logic [dword_width_gp-1:0] loopback_resp_data_lo, loopback_cmd_data_li;
  bp_me_loopback
   #(.bp_params_p(bp_params_p))
   loopback
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(dev_cmd_header_li[2])
     ,.mem_cmd_data_i(loopback_cmd_data_li)
     ,.mem_cmd_v_i(dev_cmd_v_li[2])
     ,.mem_cmd_ready_and_o(dev_cmd_ready_and_lo[2])
     ,.mem_cmd_last_i(dev_cmd_last_li[2])

     ,.mem_resp_header_o(dev_resp_header_lo[2])
     ,.mem_resp_data_o(loopback_resp_data_lo)
     ,.mem_resp_v_o(dev_resp_v_lo[2])
     ,.mem_resp_ready_and_i(dev_resp_ready_and_li[2])
     ,.mem_resp_last_o(dev_resp_last_lo[2])
     );

  // Assign I/O and mem as another device
  assign mem_cmd_header_cast_o = dev_cmd_header_li[3];
  assign mem_cmd_v_o = dev_cmd_v_li[3];
  assign dev_cmd_ready_and_lo[3] = mem_cmd_ready_and_i;
  assign mem_cmd_last_o = dev_cmd_last_li[3];

  assign dev_resp_header_lo[3] = mem_resp_header_cast_i;
  assign dev_resp_v_lo[3] = mem_resp_v_i;
  assign mem_resp_ready_and_o = dev_resp_ready_and_li[3];
  assign dev_resp_last_lo[3] = mem_resp_last_i;

  assign io_cmd_header_cast_o = dev_cmd_header_li[4];
  assign io_cmd_v_o = dev_cmd_v_li[4];
  assign dev_cmd_ready_and_lo[4] = io_cmd_ready_and_i;
  assign io_cmd_last_o = dev_cmd_last_li[4];

  assign dev_resp_header_lo[4] = io_resp_header_cast_i;
  assign dev_resp_v_lo[4] = io_resp_v_i;
  assign io_resp_ready_and_o = dev_resp_ready_and_li[4];
  assign dev_resp_last_lo[4] = io_resp_last_i;

  // Select destination of commands
  localparam lg_num_dev_lp = `BSG_SAFE_CLOG2(5);
  logic [2:0][lg_num_dev_lp-1:0] proc_cmd_dst_lo;
  for (genvar i = 0; i < 3; i++)
    begin : cmd_dest
      bp_local_addr_s local_addr;
      assign local_addr = proc_cmd_header_lo[i].addr;
      wire [dev_id_width_gp-1:0] device_cmd_li = local_addr.dev;
      wire local_cmd_li    = (proc_cmd_header_lo[i].addr < dram_base_addr_gp);
      wire is_other_core   = local_cmd_li & (local_addr.tile != cfg_bus_lo.core_id);
      wire is_other_hio    = (proc_cmd_header_lo[i].addr[paddr_width_p-1-:hio_width_p] != 0);

      wire is_cfg_cmd      = local_cmd_li & (device_cmd_li == cfg_dev_gp);
      wire is_clint_cmd    = local_cmd_li & (device_cmd_li == clint_dev_gp);
      wire is_io_cmd       = (local_cmd_li & (device_cmd_li inside {boot_dev_gp, host_dev_gp}))
                             | is_other_hio | is_other_core;
      wire is_mem_cmd      = (~local_cmd_li & ~is_other_hio) || (local_cmd_li & (device_cmd_li == cache_dev_gp));
      wire is_loopback_cmd = local_cmd_li & ~is_cfg_cmd & ~is_clint_cmd & ~is_io_cmd & ~is_mem_cmd;

      bsg_encode_one_hot
       #(.width_p(5), .lo_to_hi_p(1))
       cmd_pe
        (.i({is_io_cmd, is_mem_cmd, is_loopback_cmd, is_clint_cmd, is_cfg_cmd})
         ,.addr_o(proc_cmd_dst_lo[i])
         ,.v_o()
         );
    end

  // Select destination of responses. Were there a way to transpose structs...
  localparam lg_num_proc_lp = `BSG_SAFE_CLOG2(4);
  logic [4:0][lg_num_proc_lp-1:0] dev_resp_dst_lo;
  assign dev_resp_dst_lo[4] = dev_resp_header_lo[4].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[3] = dev_resp_header_lo[3].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[2] = dev_resp_header_lo[2].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[1] = dev_resp_header_lo[1].payload.lce_id[0+:lg_num_proc_lp];
  assign dev_resp_dst_lo[0] = dev_resp_header_lo[0].payload.lce_id[0+:lg_num_proc_lp];

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.payload_mask_p(mem_cmd_payload_mask_gp)
     ,.num_source_p(3)
     ,.num_sink_p(5)
     // TODO: Parameterize for area/perf tradeoff
     ,.xbar_data_width_p(uce_fill_width_p)
     ,.source_data_width_p({uce_fill_width_p*3, uce_fill_width_p*2, uce_fill_width_p*1, 0})
     ,.sink_data_width_p({uce_fill_width_p*2+dword_width_gp*3, uce_fill_width_p*1+dword_width_gp*3, dword_width_gp*3, dword_width_gp*2, dword_width_gp*1, 0})
     )
   cmd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(proc_cmd_header_lo)
     ,.msg_data_i({io_cmd_data_i, dcache_cmd_data_lo, icache_cmd_data_lo})
     ,.msg_v_i(proc_cmd_v_lo)
     ,.msg_ready_and_o(proc_cmd_ready_and_li)
     ,.msg_last_i(proc_cmd_last_lo)
     ,.msg_dst_i(proc_cmd_dst_lo)

     ,.msg_header_o(dev_cmd_header_li)
     ,.msg_data_o({io_cmd_data_o, mem_cmd_data_o, loopback_cmd_data_li, clint_cmd_data_li, cfg_cmd_data_li})
     ,.msg_v_o(dev_cmd_v_li)
     ,.msg_ready_and_i(dev_cmd_ready_and_lo)
     ,.msg_last_o(dev_cmd_last_li)
     );

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.payload_mask_p(mem_resp_payload_mask_gp)
     ,.num_source_p(5)
     ,.num_sink_p(3)
     // TODO: Parameterize for area/perf tradeoff
     ,.xbar_data_width_p(uce_fill_width_p)
     ,.source_data_width_p({uce_fill_width_p*2+dword_width_gp*3, uce_fill_width_p*1+dword_width_gp*3, dword_width_gp*3, dword_width_gp*2, dword_width_gp*1, 0})
     ,.sink_data_width_p({uce_fill_width_p*3, uce_fill_width_p*2, uce_fill_width_p*1, 0})
     )
   resp_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(dev_resp_header_lo)
     ,.msg_data_i({io_resp_data_i, mem_resp_data_i, loopback_resp_data_lo, clint_resp_data_lo, cfg_resp_data_lo})
     ,.msg_v_i(dev_resp_v_lo)
     ,.msg_ready_and_o(dev_resp_ready_and_li)
     ,.msg_last_i(dev_resp_last_lo)
     ,.msg_dst_i(dev_resp_dst_lo)

     ,.msg_header_o(proc_resp_header_li)
     ,.msg_data_o({io_resp_data_o, dcache_resp_data_li, icache_resp_data_li})
     ,.msg_v_o(proc_resp_v_li)
     ,.msg_ready_and_i(proc_resp_ready_and_lo)
     ,.msg_last_o(proc_resp_last_li)
     );

endmodule

