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
 import bp_me_pkg::*;
 import bp_me_nonsynth_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter cce_trace_p = 0
   , parameter cce_dir_trace_p = 0
   , parameter axe_trace_p = 0
   , parameter instr_count = 1
   , parameter cce_mode_p = 0 // 0 == normal, 1 == uncached only
   , parameter lce_trace_p = 0
   , parameter tr_trace_p = 0
   , parameter dram_trace_p = 0

   , parameter trace_file_p = "test"

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type

   // size of CCE-Memory buffers for cmd/resp messages
   // for this testbench (one LCE, one CCE, one memory) only need enough space to hold as many
   // cmds/responses can be generated for a single LCE request
   // 32 = 4 * 8-beat messages
   , parameter mem_buffer_els_lp         = 32

   , localparam lg_num_lce_lp = `BSG_SAFE_CLOG2(num_lce_p)

   // LCE Trace Replay Width
   , localparam trace_replay_data_width_lp=`bp_me_nonsynth_tr_pkt_width(paddr_width_p, dword_width_gp)
   , localparam trace_rom_addr_width_lp = 20

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, cache)
   )
  (output bit reset_i);

  if (l2_data_width_p != bedrock_data_width_p)
    $error("L2 data width must match bedrock data width");

  logic cce_trace_en, cce_dir_trace_en, axe_trace_en, lce_trace_en, tr_trace_en, dram_trace_en;
  assign cce_trace_en = cce_trace_p;
  assign cce_dir_trace_en = cce_dir_trace_p;
  assign axe_trace_en = axe_trace_p;
  assign lce_trace_en = lce_trace_p;
  assign tr_trace_en = tr_trace_p;
  assign dram_trace_en = dram_trace_p;

  export "DPI-C" function get_dram_period;
  export "DPI-C" function get_sim_period;

  function int get_dram_period();
    return (`dram_pkg::tck_ps);
  endfunction

  function int get_sim_period();
    return (`BP_SIM_CLK_PERIOD);
  endfunction

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_me_nonsynth_tr_pkt_s(paddr_width_p, dword_width_gp);

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

  // Config bus
  bp_cfg_bus_s             cfg_bus_lo;

  // CCE ucode interface
  logic cce_ucode_v_li;
  logic cce_ucode_w_li;
  logic [cce_pc_width_p-1:0] cce_ucode_addr_li;
  logic [cce_instr_width_gp-1:0] cce_ucode_data_li;
  logic [cce_instr_width_gp-1:0] cce_ucode_data_lo;

  // CCE Memory Interface - BedRock Stream
  bp_bedrock_mem_rev_header_s mem_rev_header;
  bp_bedrock_mem_fwd_header_s mem_fwd_header;
  logic [bedrock_data_width_p-1:0] mem_fwd_data, mem_rev_data;
  logic mem_rev_v, mem_rev_ready_and;
  logic mem_fwd_v, mem_fwd_ready_and;
  logic mem_fwd_last, mem_rev_last;

  // Cache trace replay interface
  logic [num_lce_p-1:0]                       tr_v_li, tr_ready_then_lo;
  bp_me_nonsynth_tr_pkt_s [num_lce_p-1:0]     tr_pkt_li, tr_pkt_lo, tr_pkt_masked;
  logic [num_lce_p-1:0]                       tr_v_lo, tr_yumi_li;
  logic [num_lce_p-1:0]tr_done_lo;
  logic [num_lce_p-1:0][trace_rom_addr_width_lp-1:0] trace_rom_addr_lo;
  logic [num_lce_p-1:0][trace_replay_data_width_lp+3:0] trace_rom_data_li;

  // Cache-LCE Interface

  // LCE-CCE request interface (from LCE to xbar)
  bp_bedrock_lce_req_header_s [num_lce_p-1:0] lce_req_header;
  logic [num_lce_p-1:0] lce_req_header_v, lce_req_header_ready_and, lce_req_has_data;
  logic [num_lce_p-1:0][bedrock_data_width_p-1:0] lce_req_data;
  logic [num_lce_p-1:0] lce_req_data_v, lce_req_data_ready_and, lce_req_last;
  wire [num_lce_p-1:0] lce_req_dst = '0;
  // LCE-CCE request interface (from xbar to CCE)
  bp_bedrock_lce_req_header_s cce_lce_req_header_li;
  logic cce_lce_req_header_v_li, cce_lce_req_header_ready_and_lo, cce_lce_req_has_data_li;
  logic [bedrock_data_width_p-1:0] cce_lce_req_data_li;
  logic cce_lce_req_data_v_li, cce_lce_req_data_ready_and_lo, cce_lce_req_last_li;

  // LCE-CCE response interface (from LCE to xbar)
  bp_bedrock_lce_resp_header_s [num_lce_p-1:0] lce_resp_header;
  logic [num_lce_p-1:0] lce_resp_header_v, lce_resp_header_ready_and, lce_resp_has_data;
  logic [num_lce_p-1:0][bedrock_data_width_p-1:0] lce_resp_data;
  logic [num_lce_p-1:0] lce_resp_data_v, lce_resp_data_ready_and, lce_resp_last;
  wire [num_lce_p-1:0] lce_resp_dst = '0;
  // LCE-CCE response interface (from xbar to CCE)
  bp_bedrock_lce_resp_header_s cce_lce_resp_header_li;
  logic cce_lce_resp_header_v_li, cce_lce_resp_header_ready_and_lo, cce_lce_resp_has_data_li;
  logic [bedrock_data_width_p-1:0] cce_lce_resp_data_li;
  logic cce_lce_resp_data_v_li, cce_lce_resp_data_ready_and_lo, cce_lce_resp_last_li;

  // LCE-CCE command interface (from xbar to LCE)
  bp_bedrock_lce_cmd_header_s [num_lce_p-1:0] lce_cmd_header_li;
  logic [num_lce_p-1:0] lce_cmd_header_v_li, lce_cmd_header_ready_and_lo, lce_cmd_has_data_li;
  logic [num_lce_p-1:0][bedrock_data_width_p-1:0] lce_cmd_data_li;
  logic [num_lce_p-1:0] lce_cmd_data_v_li, lce_cmd_data_ready_and_lo, lce_cmd_last_li;

  // LCE-CCE fill interface (from xbar to LCE)
  bp_bedrock_lce_fill_header_s [num_lce_p-1:0] lce_fill_header_li;
  logic [num_lce_p-1:0] lce_fill_header_v_li, lce_fill_header_ready_and_lo, lce_fill_has_data_li;
  logic [num_lce_p-1:0][bedrock_data_width_p-1:0] lce_fill_data_li;
  logic [num_lce_p-1:0] lce_fill_data_v_li, lce_fill_data_ready_and_lo, lce_fill_last_li;

  // LCE-CCE fill out interface (from LCE to buffer)
  bp_bedrock_lce_fill_header_s [num_lce_p-1:0] lce_fill_out_header;
  logic [num_lce_p-1:0] lce_fill_out_header_v, lce_fill_out_header_ready_and, lce_fill_out_has_data;
  logic [num_lce_p-1:0][bedrock_data_width_p-1:0] lce_fill_out_data;
  logic [num_lce_p-1:0] lce_fill_out_data_v, lce_fill_out_data_ready_and, lce_fill_out_last;
  // from buffer to xbar
  bp_bedrock_lce_fill_header_s [num_lce_p-1:0] buf_lce_fill_out_header;
  logic [num_lce_p-1:0] buf_lce_fill_out_header_v, buf_lce_fill_out_header_ready_and, buf_lce_fill_out_has_data;
  logic [num_lce_p-1:0][lg_num_lce_lp-1:0] lce_fill_out_dst;
  logic [num_lce_p-1:0][bedrock_data_width_p-1:0] buf_lce_fill_out_data;
  logic [num_lce_p-1:0] buf_lce_fill_out_data_v, buf_lce_fill_out_data_ready_and, buf_lce_fill_out_last;

  // LCE-CCE command interface (from CCE to xbar)
  bp_bedrock_lce_cmd_header_s cce_lce_cmd_header_lo;
  logic cce_lce_cmd_header_v_lo, cce_lce_cmd_header_ready_and_li, cce_lce_cmd_has_data_lo;
  logic [bedrock_data_width_p-1:0] cce_lce_cmd_data_lo;
  logic cce_lce_cmd_data_v_lo, cce_lce_cmd_data_ready_and_li, cce_lce_cmd_last_lo;
  wire [lg_num_lce_lp-1:0] lce_cmd_dst_lo = cce_lce_cmd_header_lo.payload.dst_id[0+:lg_num_lce_lp];

  // Req Crossbar
  bp_me_xbar_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.num_source_p(num_lce_p)
     ,.num_sink_p(num_cce_p)
     )
   req_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_req_header)
     ,.msg_header_v_i(lce_req_header_v)
     ,.msg_header_ready_and_o(lce_req_header_ready_and)
     ,.msg_has_data_i(lce_req_has_data)
     ,.msg_data_i(lce_req_data)
     ,.msg_data_v_i(lce_req_data_v)
     ,.msg_data_ready_and_o(lce_req_data_ready_and)
     ,.msg_last_i(lce_req_last)
     ,.msg_dst_i(lce_req_dst)

     ,.msg_header_o(cce_lce_req_header_li)
     ,.msg_header_v_o(cce_lce_req_header_v_li)
     ,.msg_header_ready_and_i(cce_lce_req_header_ready_and_lo)
     ,.msg_has_data_o(cce_lce_req_has_data_li)
     ,.msg_data_o(cce_lce_req_data_li)
     ,.msg_data_v_o(cce_lce_req_data_v_li)
     ,.msg_data_ready_and_i(cce_lce_req_data_ready_and_lo)
     ,.msg_last_o(cce_lce_req_last_li)
     );

  // Resp Crossbar
  bp_me_xbar_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(lce_resp_payload_width_lp)
     ,.num_source_p(num_lce_p)
     ,.num_sink_p(num_cce_p)
     )
   rev_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_resp_header)
     ,.msg_header_v_i(lce_resp_header_v)
     ,.msg_header_ready_and_o(lce_resp_header_ready_and)
     ,.msg_has_data_i(lce_resp_has_data)
     ,.msg_data_i(lce_resp_data)
     ,.msg_data_v_i(lce_resp_data_v)
     ,.msg_data_ready_and_o(lce_resp_data_ready_and)
     ,.msg_last_i(lce_resp_last)
     ,.msg_dst_i(lce_resp_dst)

     ,.msg_header_o(cce_lce_resp_header_li)
     ,.msg_header_v_o(cce_lce_resp_header_v_li)
     ,.msg_header_ready_and_i(cce_lce_resp_header_ready_and_lo)
     ,.msg_has_data_o(cce_lce_resp_has_data_li)
     ,.msg_data_o(cce_lce_resp_data_li)
     ,.msg_data_v_o(cce_lce_resp_data_v_li)
     ,.msg_data_ready_and_i(cce_lce_resp_data_ready_and_lo)
     ,.msg_last_o(cce_lce_resp_last_li)
     );

  // Fill Crossbar
  // from LCE fill out to LCE fill in
  bp_me_xbar_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(lce_fill_payload_width_lp)
     ,.num_source_p(num_lce_p)
     ,.num_sink_p(num_lce_p)
     )
   fill_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(buf_lce_fill_out_header)
     ,.msg_header_v_i(buf_lce_fill_out_header_v)
     ,.msg_header_ready_and_o(buf_lce_fill_out_header_ready_and)
     ,.msg_has_data_i(buf_lce_fill_out_has_data)
     ,.msg_data_i(buf_lce_fill_out_data)
     ,.msg_data_v_i(buf_lce_fill_out_data_v)
     ,.msg_data_ready_and_o(buf_lce_fill_out_data_ready_and)
     ,.msg_last_i(buf_lce_fill_out_last)
     ,.msg_dst_i(lce_fill_out_dst)

     ,.msg_header_o(lce_fill_header_li)
     ,.msg_header_v_o(lce_fill_header_v_li)
     ,.msg_header_ready_and_i(lce_fill_header_ready_and_lo)
     ,.msg_has_data_o(lce_fill_has_data_li)
     ,.msg_data_o(lce_fill_data_li)
     ,.msg_data_v_o(lce_fill_data_v_li)
     ,.msg_data_ready_and_i(lce_fill_data_ready_and_lo)
     ,.msg_last_o(lce_fill_last_li)
     );


  // Cmd Crossbar
  // from CCE to LCE cmd in
  bp_me_xbar_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_data_width_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.num_source_p(num_cce_p)
     ,.num_sink_p(num_lce_p)
     )
   fwd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(cce_lce_cmd_header_lo)
     ,.msg_header_v_i(cce_lce_cmd_header_v_lo)
     ,.msg_header_ready_and_o(cce_lce_cmd_header_ready_and_li)
     ,.msg_has_data_i(cce_lce_cmd_has_data_lo)
     ,.msg_data_i(cce_lce_cmd_data_lo)
     ,.msg_data_v_i(cce_lce_cmd_data_v_lo)
     ,.msg_data_ready_and_o(cce_lce_cmd_data_ready_and_li)
     ,.msg_last_i(cce_lce_cmd_last_lo)
     ,.msg_dst_i(lce_cmd_dst_lo)

     ,.msg_header_o(lce_cmd_header_li)
     ,.msg_header_v_o(lce_cmd_header_v_li)
     ,.msg_header_ready_and_i(lce_cmd_header_ready_and_lo)
     ,.msg_has_data_o(lce_cmd_has_data_li)
     ,.msg_data_o(lce_cmd_data_li)
     ,.msg_data_v_o(lce_cmd_data_v_li)
     ,.msg_data_ready_and_i(lce_cmd_data_ready_and_lo)
     ,.msg_last_o(lce_cmd_last_li)
     );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, cache);

  bp_cache_req_s [num_lce_p-1:0] cache_req_lo;
  logic [num_lce_p-1:0] cache_req_v_lo, cache_req_ready_and_li, cache_req_busy_li;
  bp_cache_req_metadata_s [num_lce_p-1:0] cache_req_metadata_lo;
  logic [num_lce_p-1:0] cache_req_metadata_v_lo;
  logic [num_lce_p-1:0] cache_req_critical_tag_li, cache_req_critical_data_li, cache_req_complete_li;
  logic [num_lce_p-1:0] cache_req_credits_full_li, cache_req_credits_empty_li;

  bp_cache_tag_mem_pkt_s [num_lce_p-1:0] tag_mem_pkt_li;
  logic [num_lce_p-1:0] tag_mem_pkt_v_li;
  logic [num_lce_p-1:0] tag_mem_pkt_yumi_lo;
  bp_cache_tag_info_s [num_lce_p-1:0] tag_mem_lo;

  bp_cache_data_mem_pkt_s [num_lce_p-1:0] data_mem_pkt_li;
  logic [num_lce_p-1:0] data_mem_pkt_v_li;
  logic [num_lce_p-1:0] data_mem_pkt_yumi_lo;
  logic [num_lce_p-1:0][cce_block_width_p-1:0] data_mem_lo;

  bp_cache_stat_mem_pkt_s [num_lce_p-1:0] stat_mem_pkt_li;
  logic [num_lce_p-1:0] stat_mem_pkt_v_li;
  logic [num_lce_p-1:0] stat_mem_pkt_yumi_lo;
  bp_cache_stat_info_s [num_lce_p-1:0] stat_mem_lo;

  for (genvar i = 0; i < num_lce_p; i++) begin : lce
    // Trace Replay Driver
    bsg_trace_replay
     #(.payload_width_p(trace_replay_data_width_lp)
       ,.rom_addr_width_p(trace_rom_addr_width_lp)
       ,.debug_p(2)
       )
     trace_replay
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(1'b1)

       ,.v_i(tr_v_li[i])
       ,.data_i(tr_pkt_masked[i])
       ,.ready_o(tr_ready_then_lo[i])

       ,.v_o(tr_v_lo[i])
       ,.yumi_i(tr_yumi_li[i])
       ,.data_o(tr_pkt_lo[i])

       ,.rom_addr_o(trace_rom_addr_lo[i])
       ,.rom_data_i(trace_rom_data_li[i])

       ,.done_o(tr_done_lo[i])
       ,.error_o()
       );

    // ugly hack to construct the test ROM filename_p input based on the genvar
    // seems to work in both vcs and verilator...
    localparam logic [7:0] id_lp = i;
    localparam string trace_file_lp = {trace_file_p, "_", id_lp+8'h30, ".tr"};
    bsg_nonsynth_test_rom
     #(.data_width_p(trace_replay_data_width_lp+4)
       ,.addr_width_p(trace_rom_addr_width_lp)
       ,.filename_p(trace_file_lp)
       )
     rom
      (.addr_i(trace_rom_addr_lo[i])
       ,.data_o(trace_rom_data_li[i])
       );

    // nonsynth cache
    bp_me_nonsynth_cache
     #(.bp_params_p(bp_params_p)
       ,.sets_p(icache_sets_p)
       ,.assoc_p(icache_assoc_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       )
     cache
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.id_i(lce_id_width_p'(i))

       ,.tr_pkt_i(tr_pkt_lo[i])
       // gate TR packets with freeze signal
       // system is ready for execution when freeze goes low
       ,.tr_pkt_v_i(tr_v_lo[i] & ~cfg_bus_lo.freeze)
       ,.tr_pkt_yumi_o(tr_yumi_li[i])

       ,.tr_pkt_v_o(tr_v_li[i])
       ,.tr_pkt_o(tr_pkt_li[i])
       ,.tr_pkt_ready_then_i(tr_ready_then_lo[i])

       ,.cache_req_o(cache_req_lo[i])
       ,.cache_req_v_o(cache_req_v_lo[i])
       ,.cache_req_ready_and_i(cache_req_ready_and_li[i])
       ,.cache_req_busy_i(cache_req_busy_li[i])
       ,.cache_req_metadata_o(cache_req_metadata_lo[i])
       ,.cache_req_metadata_v_o(cache_req_metadata_v_lo[i])
       ,.cache_req_complete_i(cache_req_complete_li[i])
       ,.cache_req_critical_tag_i(cache_req_critical_tag_li[i])
       ,.cache_req_critical_data_i(cache_req_critical_data_li[i])
       ,.cache_req_credits_full_i(cache_req_credits_full_li[i])
       ,.cache_req_credits_empty_i(cache_req_credits_empty_li[i])

       ,.tag_mem_pkt_i(tag_mem_pkt_li[i])
       ,.tag_mem_pkt_v_i(tag_mem_pkt_v_li[i])
       ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo[i])
       ,.tag_mem_o(tag_mem_lo[i])

       ,.data_mem_pkt_i(data_mem_pkt_li[i])
       ,.data_mem_pkt_v_i(data_mem_pkt_v_li[i])
       ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo[i])
       ,.data_mem_o(data_mem_lo[i])

       ,.stat_mem_pkt_v_i(stat_mem_pkt_v_li[i])
       ,.stat_mem_pkt_i(stat_mem_pkt_li[i])
       ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo[i])
       ,.stat_mem_o(stat_mem_lo[i])
       );

    assign tr_pkt_masked[i] = '{cmd: tr_pkt_li[i].cmd
                                ,paddr: tr_pkt_li[i].paddr
                                ,uncached: tr_pkt_li[i].uncached
                                ,data: (axe_trace_en) ? '0 : tr_pkt_li[i].data};

    // LCE
    bp_lce
     #(.bp_params_p(bp_params_p)
       ,.assoc_p(icache_assoc_p)
       ,.sets_p(icache_sets_p)
       ,.block_width_p(cce_block_width_p)
       ,.fill_width_p(bedrock_data_width_p)
       ,.timeout_max_limit_p(4)
       ,.credits_p(coh_noc_max_credits_p)
       ,.metadata_latency_p(0)
       )
     lce
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.lce_id_i(lce_id_width_p'(i))
       ,.lce_mode_i(cfg_bus_lo.icache_mode)

       ,.cache_req_i(cache_req_lo[i])
       ,.cache_req_v_i(cache_req_v_lo[i])
       ,.cache_req_ready_and_o(cache_req_ready_and_li[i])
       ,.cache_req_busy_o(cache_req_busy_li[i])
       ,.cache_req_metadata_i(cache_req_metadata_lo[i])
       ,.cache_req_metadata_v_i(cache_req_metadata_v_lo[i])
       ,.cache_req_critical_tag_o(cache_req_critical_tag_li[i])
       ,.cache_req_critical_data_o(cache_req_critical_data_li[i])
       ,.cache_req_complete_o(cache_req_complete_li[i])
       ,.cache_req_credits_full_o(cache_req_credits_full_li[i])
       ,.cache_req_credits_empty_o(cache_req_credits_empty_li[i])

       ,.tag_mem_pkt_o(tag_mem_pkt_li[i])
       ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li[i])
       ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo[i])
       ,.tag_mem_i(tag_mem_lo[i])

       ,.data_mem_pkt_o(data_mem_pkt_li[i])
       ,.data_mem_pkt_v_o(data_mem_pkt_v_li[i])
       ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo[i])
       ,.data_mem_i(data_mem_lo[i])

       ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li[i])
       ,.stat_mem_pkt_o(stat_mem_pkt_li[i])
       ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo[i])
       ,.stat_mem_i(stat_mem_lo[i])

       ,.lce_req_header_o(lce_req_header[i])
       ,.lce_req_header_v_o(lce_req_header_v[i])
       ,.lce_req_has_data_o(lce_req_has_data[i])
       ,.lce_req_header_ready_and_i(lce_req_header_ready_and[i])
       ,.lce_req_data_o(lce_req_data[i])
       ,.lce_req_data_v_o(lce_req_data_v[i])
       ,.lce_req_last_o(lce_req_last[i])
       ,.lce_req_data_ready_and_i(lce_req_data_ready_and[i])

       ,.lce_cmd_header_i(lce_cmd_header_li[i])
       ,.lce_cmd_header_v_i(lce_cmd_header_v_li[i])
       ,.lce_cmd_has_data_i(lce_cmd_has_data_li[i])
       ,.lce_cmd_header_ready_and_o(lce_cmd_header_ready_and_lo[i])
       ,.lce_cmd_data_i(lce_cmd_data_li[i])
       ,.lce_cmd_data_v_i(lce_cmd_data_v_li[i])
       ,.lce_cmd_last_i(lce_cmd_last_li[i])
       ,.lce_cmd_data_ready_and_o(lce_cmd_data_ready_and_lo[i])

       ,.lce_fill_header_i(lce_fill_header_li[i])
       ,.lce_fill_header_v_i(lce_fill_header_v_li[i])
       ,.lce_fill_has_data_i(lce_fill_has_data_li[i])
       ,.lce_fill_header_ready_and_o(lce_fill_header_ready_and_lo[i])
       ,.lce_fill_data_i(lce_fill_data_li[i])
       ,.lce_fill_data_v_i(lce_fill_data_v_li[i])
       ,.lce_fill_last_i(lce_fill_last_li[i])
       ,.lce_fill_data_ready_and_o(lce_fill_data_ready_and_lo[i])

       ,.lce_fill_header_o(lce_fill_out_header[i])
       ,.lce_fill_header_v_o(lce_fill_out_header_v[i])
       ,.lce_fill_has_data_o(lce_fill_out_has_data[i])
       ,.lce_fill_header_ready_and_i(lce_fill_out_header_ready_and[i])
       ,.lce_fill_data_o(lce_fill_out_data[i])
       ,.lce_fill_data_v_o(lce_fill_out_data_v[i])
       ,.lce_fill_last_o(lce_fill_out_last[i])
       ,.lce_fill_data_ready_and_i(lce_fill_out_data_ready_and[i])

       ,.lce_resp_header_o(lce_resp_header[i])
       ,.lce_resp_header_v_o(lce_resp_header_v[i])
       ,.lce_resp_has_data_o(lce_resp_has_data[i])
       ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and[i])
       ,.lce_resp_data_o(lce_resp_data[i])
       ,.lce_resp_data_v_o(lce_resp_data_v[i])
       ,.lce_resp_last_o(lce_resp_last[i])
       ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and[i])
       );

    // LCE Fill Out Header Buffer
    bsg_fifo_1r1w_small
    #(.width_p($bits(bp_bedrock_lce_fill_header_s)+1)
      ,.els_p(2)
      )
    lce_fill_out_header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from LCE
      ,.v_i(lce_fill_out_header_v[i])
      ,.data_i({lce_fill_out_has_data[i], lce_fill_out_header[i]})
      ,.ready_o(lce_fill_out_header_ready_and[i])
      // to xbar
      ,.v_o(buf_lce_fill_out_header_v[i])
      ,.data_o({buf_lce_fill_out_has_data[i], buf_lce_fill_out_header[i]})
      ,.yumi_i(buf_lce_fill_out_header_v[i] & buf_lce_fill_out_header_ready_and[i])
      );
    assign lce_fill_out_dst[i] = buf_lce_fill_out_header[i].payload.dst_id[0+:lg_num_lce_lp];

    // LCE Fill Out Data Buffer
    bsg_fifo_1r1w_small
    #(.width_p(bedrock_data_width_p+1)
      ,.els_p(16)
      )
    lce_fill_out_data_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // from LCE
      ,.v_i(lce_fill_out_data_v[i])
      ,.data_i({lce_fill_out_last[i], lce_fill_out_data[i]})
      ,.ready_o(lce_fill_out_data_ready_and[i])
      // to xbar
      ,.v_o(buf_lce_fill_out_data_v[i])
      ,.data_o({buf_lce_fill_out_last[i], buf_lce_fill_out_data[i]})
      ,.yumi_i(buf_lce_fill_out_data_v[i] & buf_lce_fill_out_data_ready_and[i])
      );
  end

  // CCE
  wrapper
  #(.bp_params_p(bp_params_p))
  wrapper
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i(cfg_bus_lo)

    ,.ucode_v_i(cce_ucode_v_li)
    ,.ucode_w_i(cce_ucode_w_li)
    ,.ucode_addr_i(cce_ucode_addr_li)
    ,.ucode_data_i(cce_ucode_data_li)
    ,.ucode_data_o(cce_ucode_data_lo)

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    ,.lce_req_header_i(cce_lce_req_header_li)
    ,.lce_req_header_v_i(cce_lce_req_header_v_li)
    ,.lce_req_header_ready_and_o(cce_lce_req_header_ready_and_lo)
    ,.lce_req_has_data_i(cce_lce_req_has_data_li)
    ,.lce_req_data_i(cce_lce_req_data_li)
    ,.lce_req_data_v_i(cce_lce_req_data_v_li)
    ,.lce_req_data_ready_and_o(cce_lce_req_data_ready_and_lo)
    ,.lce_req_last_i(cce_lce_req_last_li)

    ,.lce_cmd_header_o(cce_lce_cmd_header_lo)
    ,.lce_cmd_header_v_o(cce_lce_cmd_header_v_lo)
    ,.lce_cmd_header_ready_and_i(cce_lce_cmd_header_ready_and_li)
    ,.lce_cmd_has_data_o(cce_lce_cmd_has_data_lo)
    ,.lce_cmd_data_o(cce_lce_cmd_data_lo)
    ,.lce_cmd_data_v_o(cce_lce_cmd_data_v_lo)
    ,.lce_cmd_data_ready_and_i(cce_lce_cmd_data_ready_and_li)
    ,.lce_cmd_last_o(cce_lce_cmd_last_lo)

    ,.lce_resp_header_i(cce_lce_resp_header_li)
    ,.lce_resp_header_v_i(cce_lce_resp_header_v_li)
    ,.lce_resp_header_ready_and_o(cce_lce_resp_header_ready_and_lo)
    ,.lce_resp_has_data_i(cce_lce_resp_has_data_li)
    ,.lce_resp_data_i(cce_lce_resp_data_li)
    ,.lce_resp_data_v_i(cce_lce_resp_data_v_li)
    ,.lce_resp_data_ready_and_o(cce_lce_resp_data_ready_and_lo)
    ,.lce_resp_last_i(cce_lce_resp_last_li)

    // CCE-MEM Interface
    // BedRock Stream protocol: ready&valid
    ,.mem_rev_header_i(mem_rev_header)
    ,.mem_rev_data_i(mem_rev_data)
    ,.mem_rev_v_i(mem_rev_v)
    ,.mem_rev_ready_and_o(mem_rev_ready_and)
    ,.mem_rev_last_i(mem_rev_v & mem_rev_last)

    ,.mem_fwd_header_o(mem_fwd_header)
    ,.mem_fwd_data_o(mem_fwd_data)
    ,.mem_fwd_v_o(mem_fwd_v)
    ,.mem_fwd_ready_and_i(mem_fwd_ready_and)
    ,.mem_fwd_last_o(mem_fwd_last)
  );

  // Memory Fwd Buffer
  bp_bedrock_mem_fwd_header_s mem_fwd_lo;
  logic [bedrock_data_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li, mem_fwd_yumi_li, mem_fwd_last_lo;
  bsg_fifo_1r1w_small
  #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_data_width_p+1)
    ,.els_p(mem_buffer_els_lp)
    )
  mem_fwd_stream_buffer
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    // from CCE
    ,.v_i(mem_fwd_v)
    ,.ready_o(mem_fwd_ready_and)
    ,.data_i({mem_fwd_last, mem_fwd_data, mem_fwd_header})
    // to memory
    ,.v_o(mem_fwd_v_lo)
    ,.yumi_i(mem_fwd_yumi_li)
    ,.data_o({mem_fwd_last_lo, mem_fwd_data_lo, mem_fwd_lo})
    );
  assign mem_fwd_yumi_li = mem_fwd_v_lo & mem_fwd_ready_and_li;

  // Memory Rev Buffer
  bp_bedrock_mem_rev_header_s mem_rev_li;
  logic [bedrock_data_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo, mem_rev_last_li, mem_rev_yumi_lo;
  bsg_fifo_1r1w_small
  #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_data_width_p+1)
    ,.els_p(mem_buffer_els_lp)
    )
  mem_rev_stream_buffer
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    // from memory
    ,.v_i(mem_rev_v_li)
    ,.ready_o(mem_rev_ready_and_lo)
    ,.data_i({mem_rev_last_li, mem_rev_data_li, mem_rev_li})
    // to CCE
    ,.v_o(mem_rev_v)
    ,.yumi_i(mem_rev_yumi_lo)
    ,.data_o({mem_rev_last, mem_rev_data, mem_rev_header})
    );
  assign mem_rev_yumi_lo = mem_rev_v & mem_rev_ready_and;

  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(0)
     ,.dram_type_p(dram_type_p)
     )
   mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(mem_fwd_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_v_i(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_li)
     ,.mem_fwd_last_i(mem_fwd_v_lo & mem_fwd_last_lo)

     ,.mem_rev_header_o(mem_rev_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_v_o(mem_rev_v_li)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_lo)
     ,.mem_rev_last_o(mem_rev_last_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

  // Tracers and binds

  bind bp_nonsynth_mem
    bp_nonsynth_mem_tracer
     #(.bp_params_p(bp_params_p))
     bp_mem_tracer
      (.clk_i(clk_i & testbench.dram_trace_en)
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

  bind bp_lce
    bp_me_nonsynth_lce_tracer
      #(.bp_params_p(bp_params_p)
        ,.sets_p(sets_p)
        ,.assoc_p(assoc_p)
        ,.block_width_p(block_width_p)
        ,.fill_width_p(fill_width_p)
        )
      lce_tracer
       (.clk_i(clk_i & testbench.lce_trace_en)
        ,.reset_i(reset_i)
        ,.lce_id_i(lce_id_i)

        ,.lce_req_header_i(lce_req_header_o)
        ,.lce_req_header_v_i(lce_req_header_v_o)
        ,.lce_req_header_ready_and_i(lce_req_header_ready_and_i)
        ,.lce_req_data_i(lce_req_data_o)
        ,.lce_req_data_v_i(lce_req_data_v_o)
        ,.lce_req_data_ready_and_i(lce_req_data_ready_and_i)

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

        ,.lce_resp_header_i(lce_resp_header_o)
        ,.lce_resp_header_v_i(lce_resp_header_v_o)
        ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and_i)
        ,.lce_resp_data_i(lce_resp_data_o)
        ,.lce_resp_data_v_i(lce_resp_data_v_o)
        ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and_i)

        ,.cache_req_complete_i(cache_req_complete_o)
        ,.uc_store_req_complete_i(uc_store_req_complete_lo)
        );

  bind bp_me_nonsynth_cache
    bp_me_nonsynth_tr_tracer
      #(.bp_params_p(bp_params_p)
        ,.sets_p(sets_p)
        ,.block_width_p(block_width_p)
        )
      tr_tracer
       (.clk_i(clk_i & testbench.tr_trace_en)
        ,.reset_i(reset_i)
        ,.id_i(id_i)
        ,.tr_pkt_i(tr_pkt_i)
        ,.tr_pkt_v_i(tr_pkt_v_i)
        ,.tr_pkt_yumi_i(tr_pkt_yumi_o)
        ,.tr_pkt_o_i(tr_pkt_o)
        ,.tr_pkt_v_o_i(tr_pkt_v_o)
        ,.tr_pkt_ready_then_i(tr_pkt_ready_then_i)
        );

  bind bp_me_nonsynth_cache
    bp_me_nonsynth_axe_tracer
      #(.bp_params_p(bp_params_p)
        ,.block_width_p(block_width_p)
        )
      axe_tracer
       (.clk_i(clk_i & testbench.axe_trace_en)
        ,.reset_i(reset_i)
        ,.id_i(id_i)
        ,.load_commit_i(tr_pkt_v_o & load_op)
        ,.store_commit_i(tr_pkt_v_o & store_op)
        ,.addr_i(tr_pkt_r.paddr)
        ,.load_data_i(tr_pkt_cast_o.data)
        ,.store_data_i(tr_pkt_r.data)
        );

  bind bp_cce_wrapper
    bp_me_nonsynth_cce_tracer
      #(.bp_params_p(bp_params_p))
      cce_tracer
       (.clk_i(clk_i & testbench.cce_trace_en)
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

        ,.lce_cmd_header_i(lce_cmd_header_o)
        ,.lce_cmd_header_v_i(lce_cmd_header_v_o)
        ,.lce_cmd_header_ready_and_i(lce_cmd_header_ready_and_i)
        ,.lce_cmd_data_i(lce_cmd_data_o)
        ,.lce_cmd_data_v_i(lce_cmd_data_v_o)
        ,.lce_cmd_data_ready_and_i(lce_cmd_data_ready_and_i)

        ,.lce_resp_header_i(lce_resp_header_i)
        ,.lce_resp_header_v_i(lce_resp_header_v_i)
        ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and_o)
        ,.lce_resp_data_i(lce_resp_data_i)
        ,.lce_resp_data_v_i(lce_resp_data_v_i)
        ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and_o)

        // CCE-MEM Interface
        // BedRock Burst protocol: ready&valid
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

  bind bp_cce_dir
    bp_me_nonsynth_cce_dir_tracer
      #(.bp_params_p(bp_params_p))
      cce_dir_tracer
       (.clk_i(clk_i & testbench.cce_dir_trace_en)
        ,.reset_i(reset_i)

        ,.cce_id_i(cce_id_i)
        ,.addr_i(addr_i)
        ,.addr_bypass_i(addr_bypass_i)
        ,.lce_i(lce_i)
        ,.way_i(way_i)
        ,.lru_way_i(lru_way_i)
        ,.coh_state_i(coh_state_i)
        ,.addr_dst_gpr_i(addr_dst_gpr_i)
        ,.cmd_i(cmd_i)
        ,.r_v_i(r_v_i)
        ,.w_v_i(w_v_i)
        ,.busy_i(busy_o)
        ,.sharers_v_i(sharers_v_o)
        ,.sharers_hits_i(sharers_hits_o)
        ,.sharers_ways_i(sharers_ways_o)
        ,.sharers_coh_states_i(sharers_coh_states_o)
        ,.lru_v_i(lru_v_o)
        ,.lru_coh_state_i(lru_coh_state_o)
        ,.lru_addr_i(lru_addr_o)
        ,.addr_v_i(addr_v_o)
        ,.addr_o_i(addr_o)
        ,.addr_dst_gpr_o_i(addr_dst_gpr_o)
        );

  // CCE instruction tracer
  // this is connected to the instruction registered in the EX stage
  if (cce_type_p == e_cce_ucode) begin
    bind bp_cce
      bp_me_nonsynth_cce_inst_tracer
        #(.bp_params_p(bp_params_p)
          )
        cce_inst_tracer
        (.clk_i(clk_i & testbench.cce_trace_en)
         ,.reset_i(reset_i)
         ,.cce_id_i(cfg_bus_cast_i.cce_id)
         ,.pc_i(inst_decode.ex_pc_r)
         ,.instruction_v_i(inst_decode.inst_v_r)
         ,.instruction_i(inst_decode.inst_r)
         ,.stall_i(stall_lo)
         );

    bind bp_cce
      bp_me_nonsynth_cce_perf
        #(.bp_params_p(bp_params_p))
        cce_perf
        (.clk_i(clk_i & testbench.cce_trace_en)
         ,.reset_i(reset_i)
         ,.cce_id_i(cfg_bus_cast_i.cce_id)
         ,.req_start_i(req_start)
         ,.req_end_i(req_end)
         ,.lce_req_header_i(lce_req_header_cast_li)
         ,.cmd_send_i(lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
         ,.lce_cmd_header_i(lce_cmd_header_cast_o)
         ,.resp_receive_i(lce_resp_yumi)
         ,.lce_resp_header_i(lce_resp_header_cast_li)
         ,.mem_rev_receive_i(fsm_rev_yumi_lo & fsm_rev_last_li)
         ,.mem_rev_squash_i(fsm_rev_yumi_lo & fsm_rev_last_li & spec_bits_lo.squash)
         ,.mem_rev_header_i(fsm_rev_header_li)
         ,.mem_fwd_send_i(fsm_fwd_ready_and_li & fsm_fwd_v_lo & fsm_fwd_new_lo)
         ,.mem_fwd_header_i(fsm_fwd_header_lo)
         );
  end
  else if (cce_type_p == e_cce_fsm) begin
    bind bp_cce_fsm
      bp_me_nonsynth_cce_perf
        #(.bp_params_p(bp_params_p))
        cce_perf
        (.clk_i(clk_i & testbench.cce_trace_en)
         ,.reset_i(reset_i)
         ,.cce_id_i(cfg_bus_cast_i.cce_id)
         ,.req_start_i(lce_req_v & (state_r == e_ready))
         ,.req_end_i(state_r == e_ready)
         ,.lce_req_header_i(lce_req_header_cast_li)
         ,.cmd_send_i(lce_cmd_header_v_o & lce_cmd_header_ready_and_i)
         ,.lce_cmd_header_i(lce_cmd_header_cast_o)
         ,.resp_receive_i(lce_resp_yumi)
         ,.lce_resp_header_i(lce_resp_header_cast_li)
         ,.mem_rev_receive_i(fsm_rev_yumi_lo & fsm_rev_last_li)
         ,.mem_rev_squash_i(fsm_rev_yumi_lo & spec_bits_lo.squash & fsm_rev_last_li)
         ,.mem_rev_header_i(fsm_rev_header_li)
         ,.mem_fwd_send_i(fsm_fwd_ready_and_li & fsm_fwd_v_lo & fsm_fwd_new_lo)
         ,.mem_fwd_header_i(fsm_fwd_header_lo)
         );
  end


  // Config
  bp_bedrock_mem_fwd_header_s cfg_mem_fwd_lo;
  logic [dword_width_gp-1:0] cfg_mem_fwd_data_lo;
  logic cfg_mem_fwd_v_lo, cfg_mem_fwd_ready_and_li, cfg_mem_fwd_last_lo;
  logic cfg_mem_rev_v_lo;

  logic cfg_loader_done_lo;
  localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p);
  bp_me_nonsynth_cfg_loader
    #(.bp_params_p(bp_params_p)
      ,.inst_width_p($bits(bp_cce_inst_s))
      ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
      ,.inst_ram_els_p(num_cce_instr_ram_els_p)
      ,.skip_init_p(cce_mode_p)
      ,.clear_freeze_p(1'b1)
      )
    cfg_loader
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i('0)

     ,.io_fwd_header_o(cfg_mem_fwd_lo)
     ,.io_fwd_data_o(cfg_mem_fwd_data_lo)
     ,.io_fwd_v_o(cfg_mem_fwd_v_lo)
     ,.io_fwd_yumi_i(cfg_mem_fwd_ready_and_li & cfg_mem_fwd_v_lo)
     ,.io_fwd_last_o(cfg_mem_fwd_last_lo)

     ,.io_rev_header_i('0)
     ,.io_rev_data_i('0)
     ,.io_rev_v_i(cfg_mem_rev_v_lo)
     ,.io_rev_ready_and_o()
     ,.io_rev_last_i('0)

     ,.done_o(cfg_loader_done_lo)
     );

  logic [coh_noc_cord_width_p-1:0] cord_li = {{coh_noc_y_cord_width_p'(1'b1)}, {coh_noc_x_cord_width_p'('0)}};
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_fwd_header_i(cfg_mem_fwd_lo)
     ,.mem_fwd_data_i(cfg_mem_fwd_data_lo)
     ,.mem_fwd_v_i(cfg_mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(cfg_mem_fwd_ready_and_li)
     ,.mem_fwd_last_i(cfg_mem_fwd_last_lo)

     ,.mem_rev_header_o()
     ,.mem_rev_data_o()
     ,.mem_rev_v_o(cfg_mem_rev_v_lo)
     ,.mem_rev_ready_and_i(cfg_mem_rev_v_lo)
     ,.mem_rev_last_o()

     ,.cfg_bus_o(cfg_bus_lo)
     ,.did_i('0)
     ,.host_did_i('0)
     ,.cord_i(cord_li)

     ,.cce_ucode_v_o(cce_ucode_v_li)
     ,.cce_ucode_w_o(cce_ucode_w_li)
     ,.cce_ucode_addr_o(cce_ucode_addr_li)
     ,.cce_ucode_data_o(cce_ucode_data_li)
     ,.cce_ucode_data_i(cce_ucode_data_lo)
     );

  // Parameter Verification
  bp_nonsynth_if_verif
   #(.bp_params_p(bp_params_p))
   if_verif
    ();

  // Program done info
  localparam max_clock_cnt_lp    = 2**30-1;
  localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
  logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_clock_cnt_lp)
     ,.init_val_p(0)
     )
   clock_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(reset_i)
     ,.up_i(1'b1)

     ,.count_o(clock_cnt)
     );

  always_ff @(negedge clk_i) begin
    if (&tr_done_lo) begin
      $display("Bytes: %d Clocks: %d mBPC: %d "
               , instr_count*64
               , clock_cnt
               , (instr_count*64*1000) / clock_cnt
               );
      $display("Test PASSed");
      $finish();
    end
  end

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

