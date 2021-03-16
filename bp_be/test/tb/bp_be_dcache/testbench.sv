/**
  *
  * testbench.v
  *
  */

module testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

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
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dcache_pkt_width_lp = $bits(bp_be_dcache_pkt_s)
   , localparam trace_replay_data_width_lp = ptag_width_p + dcache_pkt_width_lp + 1 // The 1 extra bit is for uncached accesses
   , localparam trace_rom_addr_width_lp = 8

   , localparam yumi_min_delay_lp = 0
   , localparam yumi_max_delay_lp = 15
   )
  (input   bit clk_i
   , input bit reset_i
   , input bit dram_clk_i
   , input bit dram_reset_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  bp_cfg_bus_s cfg_bus_cast_li;
  logic [cfg_bus_width_lp-1:0] cfg_bus_li;
  assign cfg_bus_li = cfg_bus_cast_li;

  logic mem_cmd_v_lo, mem_resp_v_lo;
  logic mem_cmd_ready_lo, mem_resp_yumi_lo;
  bp_bedrock_cce_mem_msg_s mem_cmd_lo, mem_resp_lo;

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

     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_yumi_o(mem_resp_yumi_lo)

     ,.mem_cmd_v_o(mem_cmd_v_lo)
     ,.mem_cmd_o(mem_cmd_lo)
     ,.mem_cmd_ready_i(mem_cmd_ready_lo)
     );

  // Memory
  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(0)
     ,.dram_type_p(dram_type_p)
     ,.mem_els_p(2**20)
     )
   mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(mem_cmd_lo)
     ,.mem_cmd_v_i(mem_cmd_v_lo)
     ,.mem_cmd_ready_o(mem_cmd_ready_lo)

     ,.mem_resp_o(mem_resp_lo)
     ,.mem_resp_v_o(mem_resp_v_lo)
     ,.mem_resp_yumi_i(mem_resp_yumi_lo)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

  // Tracers
  bind bp_be_dcache
    bp_nonsynth_cache_tracer
     #(.bp_params_p(bp_params_p)
      ,.sets_p(dcache_sets_p)
      ,.assoc_p(dcache_assoc_p)
      ,.block_width_p(dcache_block_width_p)
      ,.fill_width_p(dcache_fill_width_p)
      ,.trace_file_p("dcache"))
     dcache_tracer
      (.clk_i(clk_i & (testbench.dcache_trace_p == 1))
       ,.reset_i(reset_i)

       ,.freeze_i(cfg_bus_cast_i.freeze)
       ,.mhartid_i(cfg_bus_cast_i.core_id)

       ,.v_tl_r(v_tl_r)

       ,.v_tv_r(v_tv_r)
       ,.addr_tv_r(paddr_tv_r)
       ,.lr_miss_tv(lr_miss_tv)
       ,.sc_op_tv_r(decode_tv_r.sc_op)
       ,.sc_success(sc_success)

       ,.cache_req_v_o(cache_req_v_o)
       ,.cache_req_o(cache_req_o)
       ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
       ,.cache_req_metadata_o(cache_req_metadata_o)
       ,.cache_req_complete_i(cache_req_complete_i)

       ,.v_o(early_v_o)
       ,.load_data(early_data_o[0+:65])
       ,.store_data(st_data_tv_r[0+:64])
       ,.wt_req(wt_req)
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

  if (uce_p == 0) begin
    bind bp_lce
      bp_me_nonsynth_lce_tracer
       #(.bp_params_p(bp_params_p)
         ,.sets_p(dcache_sets_p)
         ,.assoc_p(dcache_assoc_p)
         ,.block_width_p(dcache_block_width_p)
         )
       bp_lce_tracer
         (.clk_i(clk_i & (testbench.lce_trace_p == 1))
          ,.reset_i(reset_i)

          ,.lce_id_i(lce_id_i)
          ,.lce_req_i(lce_req_o)
          ,.lce_req_v_i(lce_req_v_o)
          ,.lce_req_ready_i(lce_req_ready_i)
          ,.lce_resp_i(lce_resp_o)
          ,.lce_resp_v_i(lce_resp_v_o)
          ,.lce_resp_ready_i(lce_resp_ready_i)
          ,.lce_cmd_i(lce_cmd_i)
          ,.lce_cmd_v_i(lce_cmd_v_i)
          ,.lce_cmd_yumi_i(lce_cmd_yumi_o)
          ,.lce_cmd_o_i(lce_cmd_o)
          ,.lce_cmd_o_v_i(lce_cmd_v_o)
          ,.lce_cmd_o_ready_i(lce_cmd_ready_i)
          );

    bind bp_cce_fsm
      bp_me_nonsynth_cce_tracer
        #(.bp_params_p(bp_params_p))
        bp_cce_tracer
         (.clk_i(clk_i & (testbench.cce_trace_p == 1))
          ,.reset_i(reset_i)

          ,.freeze_i(cfg_bus_cast_i.freeze)
          ,.cce_id_i(cfg_bus_cast_i.cce_id)

          // To CCE
          ,.lce_req_i(lce_req_i)
          ,.lce_req_v_i(lce_req_v_i)
          ,.lce_req_yumi_i(lce_req_yumi_o)

          ,.lce_resp_i(lce_resp_i)
          ,.lce_resp_v_i(lce_resp_v_i)
          ,.lce_resp_yumi_i(lce_resp_yumi_o)

          // From CCE
          ,.lce_cmd_i(lce_cmd_o)
          ,.lce_cmd_v_i(lce_cmd_v_o)
          ,.lce_cmd_ready_i(lce_cmd_ready_i)

          // To CCE
          ,.mem_resp_i(mem_resp_i)
          ,.mem_resp_v_i(mem_resp_v_i)
          ,.mem_resp_yumi_i(mem_resp_yumi_o)

          // From CCE
          ,.mem_cmd_i(mem_cmd_o)
          ,.mem_cmd_v_i(mem_cmd_v_o)
          ,.mem_cmd_ready_i(mem_cmd_ready_i)
          );
  end

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
     ,.mem_resp_yumi_i(mem_resp_yumi_lo)
     );

  // Assertions
  if(uce_p == 0 && l1_writethrough_p == 1)
    $error("Writethrough cache with CCE not yet supported");
  if(cce_block_width_p != dcache_block_width_p)
    $error("Memory fetch block width does not match D$ block width");
  if(num_caches_p == 0)
    $error("Please provide a valid number of caches");
  if((uce_p == 1) && (num_caches_p > 1))
    $error("UCE does not support multi-cache testing");

endmodule
