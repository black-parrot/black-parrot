module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   , parameter mem_zero_p         = 1
   , parameter mem_load_p         = preload_mem_p
   , parameter mem_file_p         = "prog.mem"
   , parameter mem_cap_in_bytes_p = 2**25
   , parameter [paddr_width_p-1:0] mem_offset_p = paddr_width_p'(32'h8000_0000)

   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 1
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = 15

   , parameter dram_clock_period_in_ps_p = 1000
   , parameter dram_cfg_p                = "dram_ch.ini"
   , parameter dram_sys_cfg_p            = "dram_sys.ini"
   , parameter dram_capacity_p           = 16384

   // Tracing parameters
   , parameter icache_trace_p = 0
   , parameter cce_trace_p = 0
  )
  (input clk_i
   , input reset_i
  );

  logic [tr_ring_width_lp-1:0] tr_pkt_li, tr_pkt_lo;
  logic tr_pkt_v_li, tr_pkt_v_lo;
  logic tr_pkt_ready_lo, tr_pkt_yumi_li;

  logic [] rom_addr_li;
  logic [] rom_data_lo;

  bsg_fsb_node_trace_replay
  #(.ring_width_p(tr_ring_width_lp)
   ,.rom_addr_width_p()
   )
   tr_replay
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)

   ,.v_i(tr_pkt_v_li)
   ,.data_i(tr_pkt_li)
   ,.ready_o(tr_pkt_ready_lo)

   ,.v_o(tr_pkt_v_lo)
   ,.data_o(tr_pkt_lo)
   ,.yumi_i(tr_pkt_yumi_li)

   ,.rom_addr_o(rom_addr_li)
   ,.rom_data_i(rom_data_lo)

   ,.done_o()
   ,.error_o()
   );

  trace_rom #(.width_p(tr_ring_width_lp+4), .addr_width_p())
    ROM
      (.addr_i(rom_addr_li)
      ,.data_o(rom_data_lo)
      );

  wrapper
  #(.bp_params_p(bp_params_p)
    ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
    ,.mem_load_p(preload_mem_p)
    ,.mem_zero_p(mem_zero_p)
    ,.mem_file_p(mem_file_p)
    ,.mem_offset_p(mem_offset_p)

    ,.use_max_latency_p(use_max_latency_p)
    ,.use_random_latency_p(use_random_latency_p)
    ,.use_dramsim2_latency_p(use_dramsim2_latency_p)
    ,.max_latency_p(max_latency_p)

    ,.dram_clock_period_in_ps_p(dram_clock_period_in_ps_p)
    ,.dram_cfg_p(dram_cfg_p)
    ,.dram_sys_cfg_p(dram_sys_cfg_p)
    ,.dram_capacity_p(dram_capacity_p)
  )
  wrapper_inst
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)  // TODO: Where does this come from?

   ,.tr_pkt_i(tr_pkt_lo)
   ,.tr_pkt_v_i(tr_pkt_v_lo)
   ,.tr_pkt_yumi_o(tr_pkt_yumi_li)

   ,.tr_pkt_ready_i(tr_pkt_ready_lo)
   ,.tr_pkt_v_o(tr_pkt_v_li)
   ,.tr_pkt_o(tr_pkt_li) 
  );

  bind bp_fe_icache
    bp_fe_icache_nonsynth_tracer
    #(.bp_params_p(bp_params_p))
    icache_tracer
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.data_o(data_o)
      ,.data_v_o(data_v_o)
      ,.miss_o(miss_o)

      ,.v_tl_r(v_tl_r)
      ,.v_tv_r(v_tv_r)

      ,.cache_req_ready_i(cache_req_ready_i)
      ,.cache_req_o(cache_req_o)
      ,.cache_req_v_o(cache_req_v_o)
      ,.cache_req_metadata_o(cache_req_metadata_o)
      ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

      ,.cache_req_complete_i(cache_req_complete_i)

      ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
      ,.data_mem_pkt_i(data_mem_pkt_i)
      ,.data_mem_o(data_mem_o)
      ,.data_mem_pkt_ready_i(data_mem_pkt_ready_i)

      ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
      ,.tag_mem_pkt_i(tag_mem_pkt_i)
      ,.tag_mem_o(tag_mem_o)
      ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_o)

      ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
      ,.stat_mem_pkt_i(stat_mem_pkt_i)
      ,.stat_mem_o(stat_mem_o)
      ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_o)
      );

  bind bp_cce_fsm_top
    bp_cce_nonsynth_tracer
      #(.bp_params_p(bp_params_p))
      bp_cce_tracer
       (.clk_i(clk_i & (testbench.cce_trace_p == 1))
        ,.reset_i(reset_i)
        ,.freeze_i(bp_cce.cfg_bus_cast_i.freeze)

        ,.cce_id_i(bp_cce.cfg_bus_cast_i.cce_id)

        ,.lce_req_i(lce_req_i)
        ,.lce_req_v_i(lce_req_v_i)
        ,.lce_req_yumi_i(lce_req_yumi_o)

        ,.lce_resp_i(lce_resp_i)
        ,.lce_resp_v_i(lce_resp_v_i)
        ,.lce_resp_yumi_i(lce_resp_yumi_o)

        ,.lce_cmd_i(lce_cmd_o)
        ,.lce_cmd_v_i(lce_cmd_v_o)
        ,.lce_cmd_ready_i(lce_cmd_ready_i)

        ,.mem_resp_i(mem_resp_i)
        ,.mem_resp_v_i(mem_resp_v_i)
        ,.mem_resp_yumi_i(mem_resp_yumi_o)

        ,.mem_cmd_i(mem_cmd_o)
        ,.mem_cmd_v_i(mem_cmd_v_o)
        ,.mem_cmd_ready_i(mem_cmd_ready_i)
        );
endmodule
