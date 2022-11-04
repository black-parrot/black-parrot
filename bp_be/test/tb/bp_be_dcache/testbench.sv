/**
  *
  * testbench.v
  *
  */

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

module testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   // Tracing parameters
   , parameter cce_trace_p                 = 0
   , parameter lce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter dcache_trace_p              = 0
   , parameter random_yumi_p               = 0
   , parameter uce_p                       = 0
   , parameter wt_p                        = 0
   , parameter num_caches_p                = 1

   , parameter trace_file_p = "test.tr"

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type

   // Derived parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dcache_pkt_width_lp = `bp_be_dcache_pkt_width(vaddr_width_p)
   , localparam trace_replay_data_width_lp = ptag_width_p + dcache_pkt_width_lp + 1 // The 1 extra bit is for uncached accesses
   , localparam trace_rom_addr_width_lp = 8

   , localparam yumi_min_delay_lp = 0
   , localparam yumi_max_delay_lp = 15
   )
  (output bit reset_i);

  if ((uce_p == 0) && (l2_data_width_p != bedrock_data_width_p))
    $error("CCE requires L2 fill width same as bedrock data width");
  if ((uce_p == 0) && (dcache_fill_width_p != bedrock_data_width_p))
    $error("CCE requires $ fill width same as bedrock data width");
  if ((uce_p == 1) && (num_caches_p != 1))
    $error("UCE setup supports only 1 cache");
  if ((uce_p == 0) && (wt_p == 1))
    $error("CCE does not support writethrough caches");
  if (uce_p == 0 && dcache_writethrough_p == 1)
    $error("Writethrough cache with CCE not yet supported");
  if (cce_block_width_p != dcache_block_width_p)
    $error("Memory fetch block width does not match D$ block width");
  if (num_caches_p == 0)
    $error("Please provide a valid number of caches");

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

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

  logic mem_fwd_v_lo, mem_rev_v_li;
  logic mem_fwd_ready_and_lo, mem_rev_ready_and_li;
  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [l2_data_width_p-1:0] mem_fwd_data_lo, mem_rev_data_li;

  logic [num_caches_p-1:0][trace_replay_data_width_lp-1:0] trace_data_lo;
  logic [num_caches_p-1:0] trace_v_lo;
  logic [num_caches_p-1:0] dut_ready_lo;

  logic [num_caches_p-1:0][trace_replay_data_width_lp-1:0] trace_data_li;
  logic [num_caches_p-1:0] trace_v_li, trace_ready_lo;
  logic [num_caches_p-1:0][dword_width_gp-1:0] data_lo;
  logic [num_caches_p-1:0] v_lo;

  logic [num_caches_p-1:0][trace_rom_addr_width_lp-1:0] trace_rom_addr_lo;
  logic [num_caches_p-1:0][trace_replay_data_width_lp+3:0] trace_rom_data_li;

  logic [num_caches_p-1:0][dcache_pkt_width_lp-1:0] dcache_pkt_li;
  logic [num_caches_p-1:0][ptag_width_p-1:0] ptag_li;
  logic [num_caches_p-1:0] uncached_li;
  logic [num_caches_p-1:0] dcache_ready_li;

  logic [num_caches_p-1:0] fifo_yumi_li, fifo_v_lo, fifo_random_yumi_lo;
  logic [num_caches_p-1:0][dword_width_gp-1:0] fifo_data_lo;

  // Setting up the config bus
  // logic switch_cce_mode;
  always_comb begin
    cfg_bus_cast_li = '0;
    cfg_bus_cast_li.freeze = '0;
    cfg_bus_cast_li.core_id = '0;
    cfg_bus_cast_li.dcache_id = '0;
    cfg_bus_cast_li.dcache_mode = e_lce_mode_normal;
    cfg_bus_cast_li.cce_mode = e_cce_mode_normal;
  end

  logic [15:0] counter;
  always_ff @(posedge clk_i) begin
    if(reset_i)
      counter <= '0;
    else
      counter <= counter + 1'b1;
  end
  always_comb begin
    if(counter == 16'd65535) begin
      $display("FAIL: Timeout");
      $finish();
    end
  end

  logic [num_caches_p-1:0] test_done_lo;
  always_ff @(negedge clk_i) begin
    if (&test_done_lo) begin
      $display("PASS");
      $finish();
    end
  end

  for (genvar i = 0; i < num_caches_p; i++)
    begin : trace_replay
      // Trace Replay
      bsg_trace_replay
       #(.payload_width_p(trace_replay_data_width_lp)
         ,.rom_addr_width_p(trace_rom_addr_width_lp)
         ,.debug_p(2)
         )
       trace_replay
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.en_i(1'b1)

         ,.v_i(trace_v_li[i])
         ,.data_i(trace_data_li[i])
         ,.ready_o(trace_ready_lo[i])

         ,.v_o(trace_v_lo[i])
         ,.data_o(trace_data_lo[i])
         ,.yumi_i(dut_ready_lo[i] & trace_v_lo[i])

         ,.rom_addr_o(trace_rom_addr_lo[i])
         ,.rom_data_i(trace_rom_data_li[i])

         ,.done_o(test_done_lo[i])
         ,.error_o()
         );

      bsg_nonsynth_test_rom
       #(.data_width_p(trace_replay_data_width_lp+4)
         ,.addr_width_p(trace_rom_addr_width_lp)
         ,.filename_p(trace_file_p)
         )
       ROM
        (.addr_i(trace_rom_addr_lo[i])
         ,.data_o(trace_rom_data_li[i])
         );

      assign dcache_pkt_li[i] = trace_data_lo[i][0+:dcache_pkt_width_lp];
      // Slight hack, but makes all address "cacheable"
      assign ptag_li[i] = (32'h8000_0000 >> 12) | trace_data_lo[i][dcache_pkt_width_lp+:ptag_width_p];
      assign uncached_li[i] = trace_data_lo[i][(dcache_pkt_width_lp+ptag_width_p)+:1];

      // Output FIFO
      assign fifo_yumi_li[i] = (random_yumi_p == 1) ? (fifo_random_yumi_lo[i] & trace_ready_lo[i]) : (fifo_v_lo[i] & trace_ready_lo[i]);
      assign trace_v_li[i] = (random_yumi_p == 1) ? fifo_yumi_li[i] : fifo_v_lo[i];
      assign trace_data_li[i] = {'0, fifo_data_lo[i]};

      bsg_nonsynth_random_yumi_gen
       #(.yumi_min_delay_p(yumi_min_delay_lp)
         ,.yumi_max_delay_p(yumi_max_delay_lp)
         )
       yumi_gen
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.v_i(fifo_v_lo[i])
         ,.yumi_o(fifo_random_yumi_lo[i])
         );

      // We need an 8 FIFO because we might be receiving all data at once rather
      // than receive data at regular intervals. This is possible a side effect of
      // our testing strategy. Open for debate.
      bsg_fifo_1r1w_small
       #(.width_p(dword_width_gp), .els_p(8))
       output_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         // from dcache
         ,.v_i(v_lo[i])
         ,.ready_o(dcache_ready_li[i])
         ,.data_i(data_lo[i])

         // to trace replay
         ,.v_o(fifo_v_lo[i])
         ,.yumi_i(fifo_yumi_li[i])
         ,.data_o(fifo_data_lo[i])
         );
    end

  // Subsystem Under Test
  wrapper
   #(.bp_params_p(bp_params_p)
     ,.uce_p(uce_p)
     ,.wt_p(wt_p)
     ,.num_caches_p(num_caches_p)
     ,.sets_p(dcache_sets_p)
     ,.assoc_p(dcache_assoc_p)
     ,.block_width_p(dcache_block_width_p)
     ,.fill_width_p(dcache_fill_width_p)
     )
   wrapper
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_li)

     ,.dcache_pkt_i(dcache_pkt_li)
     ,.v_i(trace_v_lo)
     ,.ready_o(dut_ready_lo)

     ,.data_o(data_lo)
     ,.v_o(v_lo)

     ,.ptag_i(ptag_li)

     ,.uncached_i(uncached_li)

     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)
     ,.mem_fwd_last_o(mem_fwd_last_lo)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)
     ,.mem_rev_last_i(mem_rev_last_li)
     );

  // Memory
  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(0)
     ,.dram_type_p(dram_type_p)
     )
   mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(mem_fwd_header_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_v_i(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_li)
     ,.mem_fwd_last_i(mem_fwd_last_lo)

     ,.mem_rev_header_o(mem_rev_header_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_v_o(mem_rev_v_li)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_lo)
     ,.mem_rev_last_o(mem_rev_last_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

  // Tracers
  bind bp_be_dcache
    bp_be_nonsynth_dcache_tracer
     #(.bp_params_p(bp_params_p)
       ,.assoc_p(assoc_p)
       ,.sets_p(sets_p)
       ,.block_width_p(block_width_p)
       ,.fill_width_p(fill_width_p)
       )
     dcache_tracer
      (.clk_i(clk_i & (testbench.dcache_trace_p == 1))
       ,.freeze_i(cfg_bus_cast_i.freeze)
       ,.mhartid_i(cfg_bus_cast_i.core_id)
       ,.*
       );

  if (uce_p == 0) begin
    bind bp_lce
      bp_me_nonsynth_lce_tracer
       #(.bp_params_p(bp_params_p)
         ,.sets_p(sets_p)
         ,.assoc_p(assoc_p)
         ,.block_width_p(block_width_p)
         ,.fill_width_p(fill_width_p)
         )
       bp_lce_tracer
         (.clk_i(clk_i & (testbench.lce_trace_p == 1))
          ,.reset_i(reset_i)

          ,.lce_id_i(lce_id_i)

          ,.lce_req_header_i(lce_req_header_o)
          ,.lce_req_header_v_i(lce_req_header_v_o)
          ,.lce_req_header_ready_and_i(lce_req_header_ready_and_i)
          ,.lce_req_data_i(lce_req_data_o)
          ,.lce_req_data_v_i(lce_req_data_v_o)
          ,.lce_req_data_ready_and_i(lce_req_data_ready_and_i)

          ,.lce_resp_header_i(lce_resp_header_o)
          ,.lce_resp_header_v_i(lce_resp_header_v_o)
          ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and_i)
          ,.lce_resp_data_i(lce_resp_data_o)
          ,.lce_resp_data_v_i(lce_resp_data_v_o)
          ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and_i)

          ,.lce_cmd_header_i(lce_cmd_header_i)
          ,.lce_cmd_header_v_i(lce_cmd_header_v_i)
          ,.lce_cmd_header_ready_and_i(lce_cmd_header_ready_and_o)
          ,.lce_cmd_data_i(lce_cmd_data_i)
          ,.lce_cmd_data_v_i(lce_cmd_data_v_i)
          ,.lce_cmd_data_ready_and_i(lce_cmd_data_ready_and_o)

          ,.lce_fill_header_i(lce_fill_header_i)
          ,.lce_fill_header_v_i(lce_fill_header_v_i)
          ,.lce_fill_header_ready_and_i(lce_fill_header_ready_and_o)
          ,.lce_fill_data_i(lce_fill_data_i)
          ,.lce_fill_data_v_i(lce_fill_data_v_i)
          ,.lce_fill_data_ready_and_i(lce_fill_data_ready_and_o)

          ,.lce_fill_o_header_i(lce_fill_header_o)
          ,.lce_fill_o_header_v_i(lce_fill_header_v_o)
          ,.lce_fill_o_header_ready_and_i(lce_fill_header_ready_and_i)
          ,.lce_fill_o_data_i(lce_fill_data_o)
          ,.lce_fill_o_data_v_i(lce_fill_data_v_o)
          ,.lce_fill_o_data_ready_and_i(lce_fill_data_ready_and_i)

          ,.cache_req_complete_i(cache_req_complete_o)
          ,.uc_store_req_complete_i(uc_store_req_complete_lo)
          );

    bind bp_cce_fsm
      bp_me_nonsynth_cce_tracer
        #(.bp_params_p(bp_params_p))
        bp_cce_tracer
         (.clk_i(clk_i & (testbench.cce_trace_p == 1))
          ,.reset_i(reset_i)

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
          // BedRock Stream protocol: ready&valid
          ,.mem_rev_header_i(mem_rev_header_i)
          ,.mem_rev_data_i(mem_rev_data_i)
          ,.mem_rev_v_i(mem_rev_v_i)
          ,.mem_rev_ready_and_i(mem_rev_ready_and_o)
          ,.mem_rev_last_i(mem_rev_last_i)

          ,.mem_fwd_header_i(mem_fwd_header_o)
          ,.mem_fwd_data_i(mem_fwd_data_o)
          ,.mem_fwd_v_i(mem_fwd_v_o)
          ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)
          ,.mem_fwd_last_i(mem_fwd_last_o)
          );
  end

  bind bp_nonsynth_mem
    bp_nonsynth_mem_tracer
     #(.bp_params_p(bp_params_p))
     bp_mem_tracer
      (.clk_i(clk_i & (testbench.dram_trace_p == 1))
       ,.reset_i(reset_i)

       ,.mem_fwd_header_i(mem_fwd_header_i)
       ,.mem_fwd_data_i(mem_fwd_data_i)
       ,.mem_fwd_v_i(mem_fwd_v_i)
       ,.mem_fwd_ready_and_i(mem_fwd_ready_and_o)
       ,.mem_fwd_last_i(mem_fwd_last_i)

       ,.mem_rev_header_i(mem_rev_header_o)
       ,.mem_rev_data_i(mem_rev_data_o)
       ,.mem_rev_v_i(mem_rev_v_o)
       ,.mem_rev_ready_and_i(mem_rev_ready_and_i)
       ,.mem_rev_last_i(mem_rev_last_o)
       );

  // Parameter Verification
  bp_nonsynth_if_verif
   #(.bp_params_p(bp_params_p))
   if_verif
    ();

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
