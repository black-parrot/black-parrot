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
   `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)

   // Tracing parameters
   , parameter cce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter icache_trace_p              = 0
   , parameter preload_mem_p               = 1
   , parameter random_yumi_p               = 0
   , parameter uce_p                       = 1

   , parameter trace_file_p = "test.tr"

   , parameter dram_fixed_latency_p = 0
   , parameter [paddr_width_p-1:0] mem_offset_p = dram_base_addr_gp
   , parameter mem_cap_in_bytes_p = 2**25
   , parameter mem_file_p = "prog.mem"

  , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
  , localparam page_offset_width_lp = bp_page_offset_width_gp
  , localparam ptag_width_lp = (paddr_width_p - page_offset_width_lp)
  , localparam trace_replay_data_width_lp = ptag_width_lp + vaddr_width_p + 1
  , localparam trace_rom_addr_width_lp = 7

  , localparam yumi_min_delay_lp = 0
  , localparam yumi_max_delay_lp = 15
  )
  ( input clk_i
  , input reset_i
  , input dram_clk_i
  , input dram_reset_i
  );

  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);

  bp_cfg_bus_s cfg_bus_cast_li;
  logic [cfg_bus_width_lp-1:0] cfg_bus_li;
  assign cfg_bus_li = cfg_bus_cast_li;

  logic mem_cmd_v_lo, mem_resp_v_lo;
  logic mem_cmd_ready_lo, mem_resp_yumi_li;
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
    cfg_bus_cast_li.cce_mode = e_cce_mode_normal;
  end

  assign ptag_li = trace_data_lo[0+:(ptag_width_lp)];
  assign vaddr_li = trace_data_lo[ptag_width_lp+:vaddr_width_p];
  assign uncached_li = trace_data_lo[(ptag_width_lp+vaddr_width_p)+:1];
  assign trace_yumi_li = trace_v_lo & dut_ready_lo;

  // Trace replay
  logic test_done_lo;
  bsg_trace_replay
  #(.payload_width_p(trace_replay_data_width_lp)
   ,.rom_addr_width_p(trace_rom_addr_width_lp)
   ,.debug_p(2)
   )
   tr_replay
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)

   ,.v_i(trace_v_li)
   ,.data_i(trace_data_li)
   ,.ready_o(trace_ready_lo)

   ,.v_o(trace_v_lo)
   ,.data_o(trace_data_lo)
   ,.yumi_i(trace_yumi_li)

   ,.rom_addr_o(trace_rom_addr_lo)
   ,.rom_data_i(trace_rom_data_li)

   ,.done_o(test_done_lo)
   ,.error_o()
   );

  always_ff @(negedge clk_i) begin
      if (test_done_lo) begin
        $display("PASS");
        $finish();
      end
    end

  bsg_nonsynth_test_rom
  #(.data_width_p(trace_replay_data_width_lp+4)
    ,.addr_width_p(trace_rom_addr_width_lp)
    ,.filename_p(trace_file_p)
    )
    ROM
    (.addr_i(trace_rom_addr_lo)
    ,.data_o(trace_rom_data_li)
    );

  // Output FIFO
  logic fifo_yumi_li, fifo_v_lo, fifo_random_yumi_lo;
  logic [instr_width_p-1:0] fifo_data_lo;
  assign fifo_yumi_li = (random_yumi_p == 1) ? (fifo_random_yumi_lo & trace_ready_lo) : (fifo_v_lo  & trace_ready_lo);
  assign trace_v_li = (random_yumi_p == 1) ? fifo_yumi_li : fifo_v_lo;
  assign trace_data_li = {'0, fifo_data_lo};

  bsg_nonsynth_random_yumi_gen
    #(.yumi_min_delay_p(yumi_min_delay_lp)
     ,.yumi_max_delay_p(yumi_max_delay_lp)
     )
     yumi_gen
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(fifo_v_lo)
     ,.yumi_o(fifo_random_yumi_lo)
     );

  // This fifo has 16 elements since maximum number of streaming hits is 16
  // Probably a side effect of the testing strategy.  Open for debate
  bsg_fifo_1r1w_small
    #(.width_p(instr_width_p)
     ,.els_p(16)
    )
    output_fifo
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    // from icache
    ,.v_i(icache_data_v_lo)
    ,.ready_o(icache_ready_li)
    ,.data_i(icache_data_lo)

    // to trace replay
    ,.v_o(fifo_v_lo)
    ,.yumi_i(fifo_yumi_li)
    ,.data_o(fifo_data_lo)
    );

  // Subsystem under test
  wrapper
   #(.bp_params_p(bp_params_p)
    ,.uce_p(uce_p)
   )
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
     ,.mem_resp_yumi_o(mem_resp_yumi_li)

     ,.mem_cmd_o(mem_cmd_lo)
     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_ready_i(mem_cmd_ready_lo)
    );

  // Memory
  bp_mem
   #(.bp_params_p(bp_params_p)
     ,.mem_offset_p(mem_offset_p)
     ,.mem_load_p(1)
     ,.mem_file_p(mem_file_p)
     ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
     ,.dram_fixed_latency_p(dram_fixed_latency_p)
     )
    mem
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_cmd_i(mem_cmd_lo)
    ,.mem_cmd_v_i(mem_cmd_v_lo)
    ,.mem_cmd_ready_o(mem_cmd_ready_lo)

    ,.mem_resp_o(mem_resp_lo)
    ,.mem_resp_v_o(mem_resp_v_lo)
    ,.mem_resp_yumi_i(mem_resp_yumi_li)

    ,.dram_clk_i(dram_clk_i)
    ,.dram_reset_i(dram_reset_i)
    );

  // I$ tracer
  bind bp_fe_icache
    bp_nonsynth_cache_tracer
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(icache_assoc_p)
     ,.sets_p(icache_sets_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
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

      ,.wt_req()

      ,.v_o(data_v_o)
      ,.load_data(65'(data_o))
      ,.store_data(64'(0))
      ,.cache_miss_o('0)

      ,.data_mem_v_i(data_mem_v_li)
      ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
      ,.data_mem_pkt_i(data_mem_pkt_i)
      ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)

      ,.tag_mem_v_i(tag_mem_v_li)
      ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
      ,.tag_mem_pkt_i(tag_mem_pkt_i)
      ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)

      ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
      ,.stat_mem_pkt_i(stat_mem_pkt_i)
      ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)

      ,.program_finish_i('0)
      );

  // CCE tracer
  if (uce_p == 0) begin
    bind bp_cce_fsm
      bp_me_nonsynth_cce_tracer
        #(.bp_params_p(bp_params_p))
        bp_cce_tracer
         (.clk_i(clk_i & (testbench.cce_trace_p == 1))
          ,.reset_i(reset_i)
          ,.freeze_i(cfg_bus_cast_i.freeze)

          ,.cce_id_i(cfg_bus_cast_i.cce_id)

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
  end

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
     ,.mem_resp_yumi_i(mem_resp_yumi_li)
     );

  if(cce_block_width_p != icache_block_width_p)
    $error("Memory fetch block width does not match icache block width");

endmodule
