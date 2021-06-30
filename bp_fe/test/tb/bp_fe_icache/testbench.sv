`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

module testbench
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   // Tracing parameters
   , parameter cce_trace_p                 = 0
   , parameter lce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter icache_trace_p              = 0
   , parameter uce_p                       = 1

   , parameter trace_file_p = "test.tr"

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type

  , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
  , localparam trace_replay_data_width_lp = ptag_width_p + vaddr_width_p + 1
  , localparam trace_rom_addr_width_lp = 7

  , localparam yumi_min_delay_lp = 0
  , localparam yumi_max_delay_lp = 15
  )
  (output bit reset_i);

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  // Bit to deal with initial X->0 transition detection
  bit clk_i;
  bit dram_clk_i, dram_reset_i;

  `ifdef VERILATOR
    bsg_nonsynth_dpi_clock_gen
  `else
    bsg_nonsynth_clock_gen
  `endif
   #(.cycle_time_p(`BP_SIM_CLK_PERIOD))
   clock_gen
    (.o(clk_i));

  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(20)
     )
   reset_gen
    (.clk_i(clk_i)
     ,.async_reset_o(reset_i)
     );

  `ifdef VERILATOR
    bsg_nonsynth_dpi_clock_gen
  `else
    bsg_nonsynth_clock_gen
  `endif
   #(.cycle_time_p(`dram_pkg::tck_ps))
   dram_clock_gen
    (.o(dram_clk_i));

  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(10)
     )
   dram_reset_gen
    (.clk_i(dram_clk_i)
     ,.async_reset_o(dram_reset_i)
     );

  bp_cfg_bus_s cfg_bus_cast_li;
  logic [cfg_bus_width_lp-1:0] cfg_bus_li;
  assign cfg_bus_li = cfg_bus_cast_li;

  logic mem_cmd_v_lo, mem_resp_v_lo;
  logic mem_cmd_ready_and_lo, mem_resp_yumi_li;
  bp_bedrock_cce_mem_msg_s mem_cmd_lo, mem_resp_lo;

  logic [trace_replay_data_width_lp-1:0] trace_data_lo;
  logic trace_v_lo;
  logic dut_ready_lo;

  logic [trace_replay_data_width_lp-1:0] trace_data_li;
  logic trace_v_li, trace_ready_lo;

  logic [instr_width_gp-1:0] icache_data_lo;
  logic icache_data_v_lo, icache_ready_li;

  logic [trace_rom_addr_width_lp-1:0] trace_rom_addr_lo;
  logic [trace_replay_data_width_lp+3:0] trace_rom_data_li;

  logic [vaddr_width_p-1:0] vaddr_li;
  logic [ptag_width_p-1:0] ptag_li;

  always_comb begin
    cfg_bus_cast_li = '0;
    cfg_bus_cast_li.freeze = '0;
    cfg_bus_cast_li.core_id = '0;
    cfg_bus_cast_li.icache_id = '0;
    cfg_bus_cast_li.icache_mode = e_lce_mode_normal;
    cfg_bus_cast_li.cce_mode = e_cce_mode_normal;
  end

  assign ptag_li       = trace_data_lo[0+:(ptag_width_p)];
  assign vaddr_li      = trace_data_lo[ptag_width_p+:vaddr_width_p];
  wire uncached_li     = trace_data_lo[(ptag_width_p+vaddr_width_p)+:1];
  wire nonidem_li      = '0;
  wire trace_yumi_li   = trace_v_lo & dut_ready_lo;

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
  logic [instr_width_gp-1:0] fifo_data_lo;
  assign fifo_yumi_li = fifo_random_yumi_lo & trace_ready_lo;
  assign trace_v_li = fifo_yumi_li;
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
    #(.width_p(instr_width_gp)
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
   wrapper
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_li)

     ,.vaddr_i(vaddr_li)
     ,.vaddr_v_i(trace_v_lo)
     ,.vaddr_ready_o(dut_ready_lo)

     ,.ptag_i(ptag_li)
     ,.ptag_v_i(trace_v_lo)

     ,.uncached_i(uncached_li)
     ,.nonidem_i(nonidem_li)
     ,.data_o(icache_data_lo)
     ,.data_v_o(icache_data_v_lo)

     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_yumi_o(mem_resp_yumi_li)

     ,.mem_cmd_o(mem_cmd_lo)
     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_ready_i(mem_cmd_ready_and_lo)
    );

  // Memory
  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(1)
     ,.dram_type_p(dram_type_p)
     ,.mem_els_p(2**20)
     )
    mem
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mem_cmd_i(mem_cmd_lo)
    ,.mem_cmd_v_i(mem_cmd_v_lo)
    ,.mem_cmd_ready_and_o(mem_cmd_ready_and_lo)

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
     ,.assoc_p(assoc_p)
     ,.sets_p(sets_p)
     ,.block_width_p(block_width_p)
     ,.fill_width_p(fill_width_p)
     ,.trace_file_p("icache"))
    icache_tracer
      (.clk_i(clk_i & (testbench.icache_trace_p == 1))
      ,.reset_i(reset_i)

      ,.freeze_i(cfg_bus_cast_i.freeze)
      ,.mhartid_i(cfg_bus_cast_i.core_id)

      ,.v_tl_r(v_tl_r)

      ,.v_tv_r(v_tv_r)
      ,.addr_tv_r(paddr_tv_r)
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
      );

  // CCE tracer
  if (uce_p == 0) begin
    bind bp_lce
      bp_me_nonsynth_lce_tracer
       #(.bp_params_p(bp_params_p)
         ,.sets_p(sets_p)
         ,.assoc_p(assoc_p)
         ,.block_width_p(block_width_p)
         )
       bp_lce_tracer
         (.clk_i(clk_i & (testbench.lce_trace_p == 1))
          ,.reset_i(reset_i)

          ,.lce_id_i(lce_id_i)
          ,.lce_req_i(lce_req_o)
          ,.lce_req_v_i(lce_req_v_o)
          ,.lce_req_ready_and_i(lce_req_ready_then_i)
          ,.lce_resp_i(lce_resp_o)
          ,.lce_resp_v_i(lce_resp_v_o)
          ,.lce_resp_ready_and_i(lce_resp_ready_then_i)
          ,.lce_cmd_i(lce_cmd_i)
          ,.lce_cmd_v_i(lce_cmd_v_i)
          ,.lce_cmd_ready_and_i(lce_cmd_yumi_o)
          ,.lce_cmd_o_i(lce_cmd_o)
          ,.lce_cmd_o_v_i(lce_cmd_v_o)
          ,.lce_cmd_o_ready_and_i(lce_cmd_ready_then_i)
          );

    bind bp_cce_fsm
      bp_me_nonsynth_cce_tracer
        #(.bp_params_p(bp_params_p))
        bp_cce_tracer
         (.clk_i(clk_i & (testbench.cce_trace_p == 1))
          ,.reset_i(reset_i)
          ,.freeze_i(cfg_bus_cast_i.freeze)

          ,.cce_id_i(cfg_bus_cast_i.cce_id)

          // LCE-CCE Interface
          // BedRock Burst protocol: ready&valid
          ,.lce_req_header_i(lce_req_header_i)
          ,.lce_req_header_v_i(lce_req_header_v_i)
          ,.lce_req_header_ready_and_i(lce_req_header_ready_and_o)
          ,.lce_req_data_i(lce_req_data_i)
          ,.lce_req_data_v_i(lce_req_data_v_i)
          ,.lce_req_data_ready_and_i(lce_req_data_ready_and_o)

          ,.lce_resp_header_i(lce_resp_header_i)
          ,.lce_resp_header_v_i(lce_resp_header_v_i)
          ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and_o)
          ,.lce_resp_data_i(lce_resp_data_i)
          ,.lce_resp_data_v_i(lce_resp_data_v_i)
          ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and_o)

          ,.lce_cmd_header_i(lce_cmd_header_o)
          ,.lce_cmd_header_v_i(lce_cmd_header_v_o)
          ,.lce_cmd_header_ready_and_i(lce_cmd_header_ready_and_i)
          ,.lce_cmd_data_i(lce_cmd_data_o)
          ,.lce_cmd_data_v_i(lce_cmd_data_v_o)
          ,.lce_cmd_data_ready_and_i(lce_cmd_data_ready_and_i)

          // CCE-MEM Interface
          // BedRock Burst protocol: ready&valid
          ,.mem_resp_header_i(mem_resp_header_i)
          ,.mem_resp_header_v_i(mem_resp_header_v_i)
          ,.mem_resp_header_ready_and_i(mem_resp_header_ready_and_o)
          ,.mem_resp_data_i(mem_resp_data_i)
          ,.mem_resp_data_v_i(mem_resp_data_v_i)
          ,.mem_resp_data_ready_and_i(mem_resp_data_ready_and_o)

          ,.mem_cmd_header_i(mem_cmd_header_o)
          ,.mem_cmd_header_v_i(mem_cmd_header_v_o)
          ,.mem_cmd_header_ready_and_i(mem_cmd_header_ready_and_i)
          ,.mem_cmd_data_i(mem_cmd_data_o)
          ,.mem_cmd_data_v_i(mem_cmd_data_v_o)
          ,.mem_cmd_data_ready_and_i(mem_cmd_data_ready_and_i)

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
     ,.mem_cmd_ready_and_i(mem_cmd_ready_and_lo)

     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_yumi_i(mem_resp_yumi_li)
     );

  if(cce_block_width_p != icache_block_width_p)
    $error("Memory fetch block width does not match icache block width");

  `ifndef VERILATOR
    initial
      begin
        $assertoff();
        @(posedge clk_i);
        @(negedge reset_i);
        $asserton();
      end
  `endif

endmodule
