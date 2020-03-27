module testbench
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_fe_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_fe_icache_pkg::*;
  import bp_me_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   // Tracing parameters
   , parameter cce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter icache_trace_p              = 0
   , parameter preload_mem_p               = 1

   , parameter mem_zero_p         = 1
   , parameter mem_load_p         = preload_mem_p
   , parameter mem_file_p         = "prog.mem"
   , parameter mem_cap_in_bytes_p = 2**25
   , parameter [paddr_width_p-1:0] mem_offset_p = paddr_width_p'(32'h8000_0000)

   // Number of elements in the fake BlackParrot memory
   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 1
   , parameter use_dramsim2_latency_p = 0
   
   , parameter max_latency_p = 15
   
   , parameter dram_clock_period_in_ps_p = 1000
   , parameter dram_cfg_p                = "dram_ch.ini"
   , parameter dram_sys_cfg_p            = "dram_sys.ini"
   , parameter dram_capacity_p           = 16384

  // I-Cache Widths
  `declare_bp_fe_tag_widths(icache_assoc_p, icache_sets_p, lce_id_width_p, cce_id_width_p, dword_width_p, paddr_width_p)
  `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache)
  
  // LCE-CCE Interface Widths
  `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  
  // CCE-MEM Interface Widths
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  
  , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
  , localparam page_offset_width_lp = bp_page_offset_width_gp
  , localparam ptag_width_lp = (paddr_width_p - page_offset_width_lp)
  , localparam trace_replay_data_width_lp = ptag_width_lp + vaddr_width_p + 1
  , localparam trace_rom_addr_width_lp = 7
  )
  ( input clk_i
  , input reset_i
  );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);

  bp_cfg_bus_s cfg_bus_cast_li;
  logic [cfg_bus_width_lp-1:0] cfg_bus_li;
  assign cfg_bus_li = cfg_bus_cast_li;

  logic mem_cmd_v_lo, mem_resp_v_lo;
  logic mem_cmd_ready_lo, mem_resp_ready_lo;
  logic [cce_mem_msg_width_lp-1:0] mem_cmd_lo, mem_resp_lo;
 
  logic [trace_replay_data_width_lp-1:0] trace_data_lo;
  logic trace_v_lo;
  logic dut_ready_lo;

  logic [trace_replay_data_width_lp-1:0] trace_data_li;
  logic trace_v_li, trace_ready_lo;

  logic [instr_width_p-1:0] icache_data_lo;
  logic icache_data_v_lo;

  logic [trace_rom_addr_width_lp-1:0] trace_rom_addr_lo;
  logic [trace_replay_data_width_lp+3:0] trace_rom_data_li;

  logic [vaddr_width_p-1:0] vaddr_li;
  logic [ptag_width_lp-1:0] ptag_li;
  logic uncached_li;

  logic switch_cce_mode;
  always_comb begin
    cfg_bus_cast_li = '0;
    cfg_bus_cast_li.freeze = '0;
    cfg_bus_cast_li.core_id = '0;
    cfg_bus_cast_li.icache_id = '0;
    cfg_bus_cast_li.icache_mode = e_lce_mode_normal;
    cfg_bus_cast_li.cce_mode = switch_cce_mode ? e_cce_mode_normal : e_cce_mode_uncached;
  end
 
  logic [6:0] count_lo;
  localparam counter_max_val_lp = icache_sets_p + 1;

  bsg_counter_clear_up
    #(.max_val_p(counter_max_val_lp)
     ,.init_val_p(0)
     )
     sync_counter
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(~switch_cce_mode)

     ,.count_o(count_lo)
     );

  assign switch_cce_mode = (count_lo == counter_max_val_lp);

  assign ptag_li = trace_data_lo[0+:(ptag_width_lp)];
  assign vaddr_li = trace_data_lo[ptag_width_lp+:vaddr_width_p];
  assign uncached_li = trace_data_lo[(ptag_width_lp+vaddr_width_p)+:1];
  assign trace_yumi_li = trace_v_lo & dut_ready_lo;

  logic [15:0] count_sim;
  always_ff @(posedge clk_i) begin
    if (reset_i)
      count_sim <= 16'd0;
    else
      count_sim <= count_sim + 1'b1;
  end

  always_comb begin
    if(count_sim == 16'd65535)
      $finish;
  end

  // Trace replay
  bsg_trace_replay
  #(.payload_width_p(trace_replay_data_width_lp)
   ,.rom_addr_width_p(trace_rom_addr_width_lp)
   )
   tr_replay
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(switch_cce_mode)

   ,.v_i(trace_v_li)
   ,.data_i(trace_data_li)
   ,.ready_o(trace_ready_lo)

   ,.v_o(trace_v_lo)
   ,.data_o(trace_data_lo)
   ,.yumi_i(trace_yumi_li)

   ,.rom_addr_o(trace_rom_addr_lo)
   ,.rom_data_i(trace_rom_data_li)

   ,.done_o()
   ,.error_o()
   );

  mem_test_trace_rom
    #(.width_p(trace_replay_data_width_lp+4)
     ,.addr_width_p(trace_rom_addr_width_lp)
     )
    ROM
    (.addr_i(trace_rom_addr_lo)
    ,.data_o(trace_rom_data_li)
    );

  logic [trace_replay_data_width_lp+3:0] test;
  assign test = trace_rom_data_li;

  // Output FIFO
  logic fifo_yumi_li;
  logic [instr_width_p-1:0] fifo_data_lo;
  assign fifo_yumi_li = trace_v_li & trace_ready_lo;
  assign trace_data_li = {'0, fifo_data_lo};

  bsg_two_fifo 
    #(.width_p(instr_width_p))
    output_fifo 
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    // from icache
    ,.v_i(icache_data_v_lo)
    ,.ready_o(icache_ready_li)
    ,.data_i(icache_data_lo)

    // to trace replay
    ,.v_o(trace_v_li)
    ,.yumi_i(fifo_yumi_li)
    ,.data_o(fifo_data_lo)
    );

  // Subsystem under test
  wrapper
   #(.bp_params_p(bp_params_p))
   dut
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_li)
     
     ,.vaddr_i(vaddr_li)
     ,.vaddr_v_i(trace_v_lo)
     ,.vaddr_ready_o(dut_ready_lo)
     
     ,.ptag_i(ptag_li)
     ,.ptag_v_i(trace_v_lo)

     ,.uncached_i(uncached_li)
     ,.data_o(icache_data_lo)
     ,.data_v_o(icache_data_v_lo)

     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_ready_o(mem_resp_ready_lo)

     ,.mem_cmd_o(mem_cmd_lo)
     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_yumi_i(mem_cmd_v_lo & mem_cmd_ready_lo)
    );

  // Memory
  bp_mem
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
    mem
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
 
    ,.mem_cmd_i(mem_cmd_lo)
    ,.mem_cmd_v_i(mem_cmd_v_lo)
    ,.mem_cmd_ready_o(mem_cmd_ready_lo)
 
    ,.mem_resp_o(mem_resp_lo)
    ,.mem_resp_v_o(mem_resp_v_lo)
    ,.mem_resp_yumi_i(mem_resp_v_lo & mem_resp_ready_lo)
    );

  // I$ tracer
  bind bp_fe_icache
    bp_nonsynth_cache_tracer
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.trace_file_p("icache"))
    icache_tracer
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      
      ,.freeze_i(cfg_bus_cast_i.freeze)
      ,.mhartid_i(cfg_bus_cast_i.core_id)
      
      ,.v_tl_r(v_tl_r)

      ,.v_tv_r(v_tv_r)
      ,.addr_tv_r(addr_tv_r)
      ,.lr_miss_tv(1'b0)
      ,.sc_op_tv_r(1'b0)
      ,.sc_success(1'b0)

      ,.cache_req_o(cache_req_o)
      ,.cache_req_v_o(cache_req_v_o)
      ,.cache_req_metadata_o(cache_req_metadata_o)
      ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
      ,.cache_req_complete_i(cache_req_complete_i)
      
      ,.v_o(data_v_o)
      ,.load_data(dword_width_p'(data_o))
      ,.store_data(dword_width_p'(0))
      ,.cache_miss_o(miss_o)

      ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
      ,.data_mem_pkt_i(data_mem_pkt_i)
      ,.data_mem_pkt_ready_o(data_mem_pkt_ready_o)

      ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
      ,.tag_mem_pkt_i(tag_mem_pkt_i)
      ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_o)

      ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
      ,.stat_mem_pkt_i(stat_mem_pkt_i)
      ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_o)
      );

  // CCE tracer
  bind bp_cce_fsm
    bp_me_nonsynth_cce_tracer
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

  // Memory tracer
  bp_mem_nonsynth_tracer
   #(.bp_params_p(bp_params_p))
   bp_mem_tracer
    (.clk_i(clk_i & (testbench.dram_trace_p == 1))
     ,.reset_i(reset_i)

     ,.mem_cmd_i(mem_cmd_lo)
     ,.mem_cmd_v_i(mem_cmd_v_lo)
     ,.mem_cmd_ready_i(mem_cmd_ready_lo)

     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_yumi_i(mem_resp_v_lo & mem_resp_ready_lo)
     );

endmodule
