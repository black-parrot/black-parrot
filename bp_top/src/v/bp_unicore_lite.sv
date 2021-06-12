
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

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)
   )
  (input                                               clk_i
   , input                                             reset_i

   // Outgoing I/O
   , output logic [uce_mem_msg_header_width_lp-1:0]    io_cmd_header_o
   , output logic [uce_mem_data_width_lp-1:0]          io_cmd_data_o
   , output logic                                      io_cmd_v_o
   , input                                             io_cmd_ready_and_i
   , output logic                                      io_cmd_last_o

   , input [uce_mem_msg_header_width_lp-1:0]           io_resp_header_i
   , input [uce_mem_data_width_lp-1:0]                 io_resp_data_i
   , input                                             io_resp_v_i
   , output logic                                      io_resp_yumi_o
   , input                                             io_resp_last_i

   // Incoming I/O
   , input [uce_mem_msg_header_width_lp-1:0]           io_cmd_header_i
   , input [uce_mem_data_width_lp-1:0]                 io_cmd_data_i
   , input                                             io_cmd_v_i
   , output logic                                      io_cmd_yumi_o
   , input                                             io_cmd_last_i

   , output logic [uce_mem_msg_header_width_lp-1:0]    io_resp_header_o
   , output logic [uce_mem_data_width_lp-1:0]          io_resp_data_o
   , output logic                                      io_resp_v_o
   , input                                             io_resp_ready_and_i
   , output logic                                      io_resp_last_o

   // Outgoing BP Stream Mem Bus
   , output logic [uce_mem_msg_header_width_lp-1:0]    mem_cmd_header_o
   , output logic [uce_mem_data_width_lp-1:0]          mem_cmd_data_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_and_i
   , output logic                                      mem_cmd_last_o

   , input [uce_mem_msg_header_width_lp-1:0]           mem_resp_header_i
   , input [uce_mem_data_width_lp-1:0]                 mem_resp_data_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_ready_and_o
   , input                                             mem_resp_last_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_bedrock_mem_if(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);
  `bp_cast_o(bp_bedrock_uce_mem_msg_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_uce_mem_msg_header_s, mem_resp_header);
  `bp_cast_o(bp_bedrock_uce_mem_msg_header_s, io_cmd_header);
  `bp_cast_i(bp_bedrock_uce_mem_msg_header_s, io_resp_header);
  `bp_cast_i(bp_bedrock_uce_mem_msg_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_uce_mem_msg_header_s, io_resp_header);

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

  // proc_cmd[2:0] = {IO cmd, BE UCE, FE UCE}
  bp_bedrock_uce_mem_msg_header_s [2:0] proc_cmd_header_lo;
  logic [2:0][uce_mem_data_width_lp-1:0] proc_cmd_data_lo;
  logic [2:0] proc_cmd_v_lo, proc_cmd_yumi_li, proc_cmd_last_lo;
  bp_bedrock_uce_mem_msg_header_s [2:0] proc_resp_header_li;
  logic [2:0][uce_mem_data_width_lp-1:0] proc_resp_data_li;
  logic [2:0] proc_resp_v_li, proc_resp_yumi_lo, proc_resp_last_li;

  // dev_cmd[4:0] = {CCE loopback, Mem cmd, IO cmd, CLINT, CFG}
  bp_bedrock_uce_mem_msg_header_s [4:0] dev_cmd_header_li;
  logic [4:0][uce_mem_data_width_lp-1:0] dev_cmd_data_li;
  logic [4:0] dev_cmd_v_li, dev_cmd_ready_and_lo, dev_cmd_last_li;
  bp_bedrock_uce_mem_msg_header_s [4:0] dev_resp_header_lo;
  logic [4:0][uce_mem_data_width_lp-1:0] dev_resp_data_lo;
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
    ,.mem_cmd_data_o(proc_cmd_data_lo[1])
    ,.mem_cmd_v_o(proc_cmd_v_lo[1])
    ,.mem_cmd_yumi_i(proc_cmd_yumi_li[1])
    ,.mem_cmd_last_o(proc_cmd_last_lo[1])

    ,.mem_resp_header_i(proc_resp_header_li[1])
    ,.mem_resp_data_i(proc_resp_data_li[1])
    ,.mem_resp_v_i(proc_resp_v_li[1])
    ,.mem_resp_yumi_o(proc_resp_yumi_lo[1])
    ,.mem_resp_last_i(proc_resp_last_li[1])
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
     ,.mem_cmd_data_o(proc_cmd_data_lo[0])
     ,.mem_cmd_v_o(proc_cmd_v_lo[0])
     ,.mem_cmd_yumi_i(proc_cmd_yumi_li[0])
     ,.mem_cmd_last_o(proc_cmd_last_lo[0])

     ,.mem_resp_header_i(proc_resp_header_li[0])
     ,.mem_resp_data_i(proc_resp_data_li[0])
     ,.mem_resp_v_i(proc_resp_v_li[0])
     ,.mem_resp_yumi_o(proc_resp_yumi_lo[0])
     ,.mem_resp_last_i(proc_resp_last_li[0])
     );

  // Assign incoming I/O as basically another UCE interface
  assign proc_cmd_header_lo[2] = io_cmd_header_cast_i;
  assign proc_cmd_data_lo[2] = io_cmd_data_i;
  assign proc_cmd_v_lo[2] = io_cmd_v_i;
  assign io_cmd_yumi_o = proc_cmd_yumi_li[2];
  assign proc_cmd_last_lo[2] = io_cmd_last_i;

  assign io_resp_header_cast_o = proc_resp_header_li[2];
  assign io_resp_data_o = proc_resp_data_li[2];
  assign io_resp_v_o = proc_resp_v_li[2];
  assign proc_resp_yumi_lo[2] = io_resp_ready_and_i & io_resp_v_o;
  assign io_resp_last_o = proc_resp_last_li[2];

  // Assign I/O and mem as another device
  assign io_cmd_header_cast_o = dev_cmd_header_li[2];
  assign io_cmd_data_o = dev_cmd_data_li[2];
  assign io_cmd_v_o = dev_cmd_v_li[2];
  assign dev_cmd_ready_and_lo[2] = io_cmd_ready_and_i;
  assign io_cmd_last_o = dev_cmd_last_li[2];

  assign mem_cmd_header_cast_o = dev_cmd_header_li[3];
  assign mem_cmd_data_o = dev_cmd_data_li[3];
  assign mem_cmd_v_o = dev_cmd_v_li[3];
  assign dev_cmd_ready_and_lo[3] = mem_cmd_ready_and_i;
  assign mem_cmd_last_o = dev_cmd_last_li[3];

  assign dev_resp_header_lo[2] = io_resp_header_cast_i;
  assign dev_resp_data_lo[2] = io_resp_data_i;
  assign dev_resp_v_lo[2] = io_resp_v_i;
  assign io_resp_yumi_o = dev_resp_ready_and_li[2] & dev_resp_v_lo[2];
  assign dev_resp_last_lo[2] = io_resp_last_i;

  assign dev_resp_header_lo[3] = mem_resp_header_cast_i;
  assign dev_resp_data_lo[3] = mem_resp_data_i;
  assign dev_resp_v_lo[3] = mem_resp_v_i;
  assign mem_resp_ready_and_o = dev_resp_ready_and_li[3];
  assign dev_resp_last_lo[3] = mem_resp_last_i;

  // Select destination of commands
  logic [2:0][`BSG_SAFE_CLOG2(5)-1:0] proc_cmd_dst_lo;
  for (genvar i = 0; i < 3; i++)
    begin : cmd_dest
      bp_local_addr_s local_addr;
      assign local_addr = proc_cmd_header_lo[i].addr;
      wire [dev_id_width_gp-1:0] device_cmd_li = local_addr.dev;
      wire local_cmd_li    = (proc_cmd_header_lo[i].addr < dram_base_addr_gp);
      wire is_other_hio    = (proc_cmd_header_lo[i].addr[paddr_width_p-1-:hio_width_p] != 0);

      wire is_cfg_cmd      = local_cmd_li & (device_cmd_li == cfg_dev_gp);
      wire is_clint_cmd    = local_cmd_li & (device_cmd_li == clint_dev_gp);
      wire is_io_cmd       = (local_cmd_li & (device_cmd_li inside {boot_dev_gp, host_dev_gp})) | is_other_hio;
      wire is_mem_cmd      = (~local_cmd_li & ~is_other_hio) || (local_cmd_li & (device_cmd_li == cache_dev_gp));
      wire is_loopback_cmd = local_cmd_li & ~is_cfg_cmd & ~is_clint_cmd & ~is_io_cmd & ~is_mem_cmd;

      bsg_encode_one_hot
       #(.width_p(5), .lo_to_hi_p(1))
       cmd_pe
        (.i({is_loopback_cmd, is_mem_cmd, is_io_cmd, is_clint_cmd, is_cfg_cmd})
         ,.addr_o(proc_cmd_dst_lo[i])
         ,.v_o()
         );
    end

  // Select destination of responses. Were there a way to transpose structs...
  logic [4:0][`BSG_SAFE_CLOG2(3)-1:0] dev_resp_dst_lo;
  assign dev_resp_dst_lo[4] = dev_resp_header_lo[4].payload.lce_id;
  assign dev_resp_dst_lo[3] = dev_resp_header_lo[3].payload.lce_id;
  assign dev_resp_dst_lo[2] = dev_resp_header_lo[2].payload.lce_id;
  assign dev_resp_dst_lo[1] = dev_resp_header_lo[1].payload.lce_id;
  assign dev_resp_dst_lo[0] = dev_resp_header_lo[0].payload.lce_id;

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(uce_mem_data_width_lp)
     ,.num_source_p(3)
     ,.num_sink_p(5)
     )
   stream_arb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cmd_header_i(proc_cmd_header_lo)
     ,.cmd_data_i(proc_cmd_data_lo)
     ,.cmd_v_i(proc_cmd_v_lo)
     ,.cmd_yumi_o(proc_cmd_yumi_li)
     ,.cmd_last_i(proc_cmd_last_lo)
     ,.cmd_dst_i(proc_cmd_dst_lo)

     ,.resp_header_o(proc_resp_header_li)
     ,.resp_data_o(proc_resp_data_li)
     ,.resp_v_o(proc_resp_v_li)
     ,.resp_ready_and_i(proc_resp_yumi_lo)
     ,.resp_last_o(proc_resp_last_li)

     ,.cmd_header_o(dev_cmd_header_li)
     ,.cmd_data_o(dev_cmd_data_li)
     ,.cmd_v_o(dev_cmd_v_li)
     ,.cmd_ready_and_i(dev_cmd_ready_and_lo)
     ,.cmd_last_o(dev_cmd_last_li)

     ,.resp_header_i(dev_resp_header_lo)
     ,.resp_data_i(dev_resp_data_lo)
     ,.resp_v_i(dev_resp_v_lo)
     ,.resp_yumi_o(dev_resp_ready_and_li)
     ,.resp_last_i(dev_resp_last_lo)
     ,.resp_dst_i(dev_resp_dst_lo)
     );

  logic [dword_width_gp-1:0] cfg_data_lo, cfg_data_li;
  bp_me_cfg
   #(.bp_params_p(bp_params_p))
   cfg
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
     ,.did_i('0)
     ,.host_did_i('0)
     // TODO: Bring in top level from multi-unicore setup
     ,.cord_i({coh_noc_y_cord_width_p'(1), coh_noc_x_cord_width_p'(0)})

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
     ,.reset_i(reset_i)

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

     ,.timer_irq_o(timer_irq_li)
     ,.software_irq_o(software_irq_li)
     ,.external_irq_o(external_irq_li)
     );
  assign clint_data_li = dev_cmd_data_li[1];
  assign dev_resp_data_lo[1] = clint_data_lo;

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

