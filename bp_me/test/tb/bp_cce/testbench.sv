/**
  *
  * testbench.v
  *
  */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

`ifndef BP_CFG_FLOWVAR
"BSG-ERROR BP_CFG_FLOWVAR must be set"
`endif

module testbench
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bp_me_nonsynth_pkg::*;
 #(parameter bp_params_e bp_params_p = `BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   // sim parameters
   , parameter sim_clock_period_p          = 0
   , parameter sim_reset_cycles_lo_p       = 0
   , parameter sim_reset_cycles_hi_p       = 0

   , parameter tb_clock_period_p           = 0
   , parameter tb_reset_cycles_lo_p        = 0
   , parameter tb_reset_cycles_hi_p        = 0

   , parameter instr_count = 1
   , parameter cce_mode_p = 0 // 0 == normal, 1 == uncached only
   , parameter lce_mode_p = 0
   , parameter me_test_p = 0

   , parameter lce_trace_p = 0
   , parameter cce_trace_p = 0
   , parameter dram_trace_p = 0

   // size of CCE-Memory buffers for cmd/resp messages
   // for this testbench (one LCE, one CCE, one memory) only need enough space to hold as many
   // cmds/responses can be generated for a single LCE request
   // 32 = 4 * 8-beat messages
   , parameter mem_buffer_els_lp         = 32

   , localparam lg_num_lce_lp = `BSG_SAFE_CLOG2(num_lce_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   `declare_bp_cache_engine_generic_if_widths(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, icache_data_width_p, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p, cache)

   // LCE Trace Replay Width
   , localparam trace_replay_data_width_lp=`bp_me_nonsynth_tr_pkt_width(paddr_width_p, dword_width_gp)
   , localparam trace_rom_addr_width_lp = 20
   );

  if (l2_data_width_p != bedrock_fill_width_p)
    $error("L2 data width must match bedrock data width");

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_me_nonsynth_tr_pkt_s(paddr_width_p, dword_width_gp);

  // Bit to deal with initial X->0 transition detection
  bit dut_clk, dut_reset;

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(sim_clock_period_p))
   clock_gen
    (.o(dut_clk));

  bsg_nonsynth_reset_gen
    #(.reset_cycles_lo_p(sim_reset_cycles_lo_p), .reset_cycles_hi_p(sim_reset_cycles_hi_p))
    reset_gen
     (.clk_i(dut_clk)
      ,.async_reset_o(dut_reset)
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
  logic [bedrock_fill_width_p-1:0] mem_fwd_data, mem_rev_data;
  logic mem_rev_v, mem_rev_ready_and;
  logic mem_fwd_v, mem_fwd_ready_and;

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
  logic [num_lce_p-1:0][bedrock_fill_width_p-1:0] lce_req_data;
  logic [num_lce_p-1:0] lce_req_v, lce_req_ready_and;
  wire [num_lce_p-1:0] lce_req_dst = '0;
  // LCE-CCE request interface (from xbar to CCE)
  bp_bedrock_lce_req_header_s cce_lce_req_header_li;
  logic [bedrock_fill_width_p-1:0] cce_lce_req_data_li;
  logic cce_lce_req_v_li, cce_lce_req_ready_and_lo;

  // LCE-CCE response interface (from LCE to xbar)
  bp_bedrock_lce_resp_header_s [num_lce_p-1:0] lce_resp_header;
  logic [num_lce_p-1:0][bedrock_fill_width_p-1:0] lce_resp_data;
  logic [num_lce_p-1:0] lce_resp_v, lce_resp_ready_and;
  wire [num_lce_p-1:0] lce_resp_dst = '0;
  // LCE-CCE response interface (from xbar to CCE)
  bp_bedrock_lce_resp_header_s cce_lce_resp_header_li;
  logic [bedrock_fill_width_p-1:0] cce_lce_resp_data_li;
  logic cce_lce_resp_v_li, cce_lce_resp_ready_and_lo;

  // LCE-CCE command interface (from xbar to LCE)
  bp_bedrock_lce_cmd_header_s [num_lce_p-1:0] lce_cmd_header_li;
  logic [num_lce_p-1:0][bedrock_fill_width_p-1:0] lce_cmd_data_li;
  logic [num_lce_p-1:0] lce_cmd_v_li, lce_cmd_ready_and_lo;

  // LCE-CCE fill interface (from xbar to LCE)
  bp_bedrock_lce_fill_header_s [num_lce_p-1:0] lce_fill_header_li;
  logic [num_lce_p-1:0][bedrock_fill_width_p-1:0] lce_fill_data_li;
  logic [num_lce_p-1:0] lce_fill_v_li, lce_fill_ready_and_lo;

  // LCE-CCE fill out interface (from LCE to buffer)
  bp_bedrock_lce_fill_header_s [num_lce_p-1:0] lce_fill_out_header;
  logic [num_lce_p-1:0][bedrock_fill_width_p-1:0] lce_fill_out_data;
  logic [num_lce_p-1:0] lce_fill_out_v, lce_fill_out_ready_and;
  // from buffer to xbar
  bp_bedrock_lce_fill_header_s [num_lce_p-1:0] buf_lce_fill_out_header;
  logic [num_lce_p-1:0][lg_num_lce_lp-1:0] lce_fill_out_dst;
  logic [num_lce_p-1:0][bedrock_fill_width_p-1:0] buf_lce_fill_out_data;
  logic [num_lce_p-1:0] buf_lce_fill_out_v, buf_lce_fill_out_ready_and;

  // LCE-CCE command interface (from CCE to xbar)
  bp_bedrock_lce_cmd_header_s cce_lce_cmd_header_lo;
  logic [bedrock_fill_width_p-1:0] cce_lce_cmd_data_lo;
  logic cce_lce_cmd_v_lo, cce_lce_cmd_ready_and_li;
  wire [lg_num_lce_lp-1:0] lce_cmd_dst_lo = cce_lce_cmd_header_lo.payload.dst_id[0+:lg_num_lce_lp];

  // Req Crossbar
  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.stream_mask_p(lce_req_stream_mask_gp)
     ,.num_source_p(num_lce_p)
     ,.num_sink_p(num_cce_p)
     )
   req_xbar
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.msg_header_i(lce_req_header)
     ,.msg_data_i(lce_req_data)
     ,.msg_v_i(lce_req_v)
     ,.msg_ready_and_o(lce_req_ready_and)
     ,.msg_dst_i(lce_req_dst)

     ,.msg_header_o(cce_lce_req_header_li)
     ,.msg_data_o(cce_lce_req_data_li)
     ,.msg_v_o(cce_lce_req_v_li)
     ,.msg_ready_and_i(cce_lce_req_ready_and_lo)
     );

  // Resp Crossbar
  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(lce_resp_payload_width_lp)
     ,.stream_mask_p(lce_resp_stream_mask_gp)
     ,.num_source_p(num_lce_p)
     ,.num_sink_p(num_cce_p)
     )
   rev_xbar
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.msg_header_i(lce_resp_header)
     ,.msg_data_i(lce_resp_data)
     ,.msg_v_i(lce_resp_v)
     ,.msg_ready_and_o(lce_resp_ready_and)
     ,.msg_dst_i(lce_resp_dst)

     ,.msg_header_o(cce_lce_resp_header_li)
     ,.msg_data_o(cce_lce_resp_data_li)
     ,.msg_v_o(cce_lce_resp_v_li)
     ,.msg_ready_and_i(cce_lce_resp_ready_and_lo)
     );

  // Fill Crossbar
  // from LCE fill out to LCE fill in
  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(lce_fill_payload_width_lp)
     ,.stream_mask_p(lce_fill_stream_mask_gp)
     ,.num_source_p(num_lce_p)
     ,.num_sink_p(num_lce_p)
     )
   fill_xbar
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.msg_header_i(buf_lce_fill_out_header)
     ,.msg_data_i(buf_lce_fill_out_data)
     ,.msg_v_i(buf_lce_fill_out_v)
     ,.msg_ready_and_o(buf_lce_fill_out_ready_and)
     ,.msg_dst_i(lce_fill_out_dst)

     ,.msg_header_o(lce_fill_header_li)
     ,.msg_data_o(lce_fill_data_li)
     ,.msg_v_o(lce_fill_v_li)
     ,.msg_ready_and_i(lce_fill_ready_and_lo)
     );


  // Cmd Crossbar
  // from CCE to LCE cmd in
  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.stream_mask_p(lce_cmd_stream_mask_gp)
     ,.num_source_p(num_cce_p)
     ,.num_sink_p(num_lce_p)
     )
   fwd_xbar
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.msg_header_i(cce_lce_cmd_header_lo)
     ,.msg_data_i(cce_lce_cmd_data_lo)
     ,.msg_v_i(cce_lce_cmd_v_lo)
     ,.msg_ready_and_o(cce_lce_cmd_ready_and_li)
     ,.msg_dst_i(lce_cmd_dst_lo)

     ,.msg_header_o(lce_cmd_header_li)
     ,.msg_data_o(lce_cmd_data_li)
     ,.msg_v_o(lce_cmd_v_li)
     ,.msg_ready_and_i(lce_cmd_ready_and_lo)
     );

  `declare_bp_cache_engine_generic_if(paddr_width_p, icache_tag_width_p, icache_sets_p, icache_assoc_p, icache_data_width_p, icache_block_width_p, icache_fill_width_p, icache_req_id_width_p, cache);

  bp_cache_req_s [num_lce_p-1:0] cache_req_lo;
  logic [num_lce_p-1:0] cache_req_v_lo, cache_req_yumi_li, cache_req_lock_li;
  bp_cache_req_metadata_s [num_lce_p-1:0] cache_req_metadata_lo;
  logic [num_lce_p-1:0] cache_req_metadata_v_lo;
  logic [num_lce_p-1:0] cache_req_id_li;
  logic [num_lce_p-1:0] cache_req_critical_li, cache_req_last_li;
  logic [num_lce_p-1:0] cache_req_credits_full_li, cache_req_credits_empty_li;

  bp_cache_tag_mem_pkt_s [num_lce_p-1:0] tag_mem_pkt_li;
  logic [num_lce_p-1:0] tag_mem_pkt_v_li;
  logic [num_lce_p-1:0] tag_mem_pkt_yumi_lo;
  bp_cache_tag_info_s [num_lce_p-1:0] tag_mem_lo;

  bp_cache_data_mem_pkt_s [num_lce_p-1:0] data_mem_pkt_li;
  logic [num_lce_p-1:0] data_mem_pkt_v_li;
  logic [num_lce_p-1:0] data_mem_pkt_yumi_lo;
  logic [num_lce_p-1:0][bedrock_block_width_p-1:0] data_mem_lo;

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
      (.clk_i(dut_clk)
       ,.reset_i(dut_reset)
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
    // EDIT: Verilator 5.030 seems to have a regression here:
    //   https://github.com/verilator/verilator/issues/1328
    localparam logic [7:0] id_lp = i;
    //localparam string trace_file_lp = {trace_file_p, "_", id_lp+8'h30, ".tr"};
    localparam trace_file_lp = {"test_", id_lp+8'h30, ".tr"};

    initial $display("trace file is %s", trace_file_lp);
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
       ,.data_width_p(icache_data_width_p)
       ,.sets_p(icache_sets_p)
       ,.assoc_p(icache_assoc_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       )
     cache
      (.clk_i(dut_clk)
       ,.reset_i(dut_reset)

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
       ,.cache_req_yumi_i(cache_req_yumi_li[i])
       ,.cache_req_lock_i(cache_req_lock_li[i])
       ,.cache_req_metadata_o(cache_req_metadata_lo[i])
       ,.cache_req_metadata_v_o(cache_req_metadata_v_lo[i])
       ,.cache_req_id_i(cache_req_id_li[i])
       ,.cache_req_critical_i(cache_req_critical_li[i])
       ,.cache_req_last_i(cache_req_last_li[i])
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
                                ,data: tr_pkt_li[i].data};

    // LCE
    bp_lce
     #(.bp_params_p(bp_params_p)
       ,.assoc_p(icache_assoc_p)
       ,.sets_p(icache_sets_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       ,.data_width_p(icache_data_width_p)
       ,.id_width_p(icache_req_id_width_p)
       ,.timeout_max_limit_p(4)
       ,.credits_p(coh_noc_max_credits_p)
       ,.tag_width_p(icache_tag_width_p)
       )
     lce
      (.clk_i(dut_clk)
       ,.reset_i(dut_reset)

       ,.did_i('0)
       ,.lce_id_i(lce_id_width_p'(i))
       ,.lce_mode_i(cfg_bus_lo.icache_mode)

       ,.cache_req_i(cache_req_lo[i])
       ,.cache_req_v_i(cache_req_v_lo[i])
       ,.cache_req_yumi_o(cache_req_yumi_li[i])
       ,.cache_req_lock_o(cache_req_lock_li[i])
       ,.cache_req_metadata_i(cache_req_metadata_lo[i])
       ,.cache_req_metadata_v_i(cache_req_metadata_v_lo[i])
       ,.cache_req_id_o(cache_req_id_li[i])
       ,.cache_req_critical_o(cache_req_critical_li[i])
       ,.cache_req_last_o(cache_req_last_li[i])
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
       ,.lce_req_data_o(lce_req_data[i])
       ,.lce_req_v_o(lce_req_v[i])
       ,.lce_req_ready_and_i(lce_req_ready_and[i])

       ,.lce_cmd_header_i(lce_cmd_header_li[i])
       ,.lce_cmd_data_i(lce_cmd_data_li[i])
       ,.lce_cmd_v_i(lce_cmd_v_li[i])
       ,.lce_cmd_ready_and_o(lce_cmd_ready_and_lo[i])

       ,.lce_fill_header_i(lce_fill_header_li[i])
       ,.lce_fill_data_i(lce_fill_data_li[i])
       ,.lce_fill_v_i(lce_fill_v_li[i])
       ,.lce_fill_ready_and_o(lce_fill_ready_and_lo[i])

       ,.lce_fill_header_o(lce_fill_out_header[i])
       ,.lce_fill_data_o(lce_fill_out_data[i])
       ,.lce_fill_v_o(lce_fill_out_v[i])
       ,.lce_fill_ready_and_i(lce_fill_out_ready_and[i])

       ,.lce_resp_header_o(lce_resp_header[i])
       ,.lce_resp_data_o(lce_resp_data[i])
       ,.lce_resp_v_o(lce_resp_v[i])
       ,.lce_resp_ready_and_i(lce_resp_ready_and[i])
       );

    // LCE Fill Out Data Buffer
    bsg_fifo_1r1w_small
    #(.width_p($bits(bp_bedrock_lce_fill_header_s)+bedrock_fill_width_p)
      ,.els_p(16)
      )
    lce_fill_out_data_buffer
     (.clk_i(dut_clk)
      ,.reset_i(dut_reset)
      // from LCE
      ,.v_i(lce_fill_out_v[i])
      ,.data_i({lce_fill_out_data[i], lce_fill_out_header[i]})
      ,.ready_param_o(lce_fill_out_ready_and[i])
      // to xbar
      ,.v_o(buf_lce_fill_out_v[i])
      ,.data_o({buf_lce_fill_out_data[i], buf_lce_fill_out_header[i]})
      ,.yumi_i(buf_lce_fill_out_v[i] & buf_lce_fill_out_ready_and[i])
      );
    assign lce_fill_out_dst[i] = buf_lce_fill_out_header[i].payload.dst_id[0+:lg_num_lce_lp];
  end

  // CCE
  wrapper
  #(.bp_params_p(bp_params_p))
  wrapper
   (.clk_i(dut_clk)
    ,.reset_i(dut_reset)

    ,.cfg_bus_i(cfg_bus_lo)

    ,.ucode_v_i(cce_ucode_v_li)
    ,.ucode_w_i(cce_ucode_w_li)
    ,.ucode_addr_i(cce_ucode_addr_li)
    ,.ucode_data_i(cce_ucode_data_li)
    ,.ucode_data_o(cce_ucode_data_lo)

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    ,.lce_req_header_i(cce_lce_req_header_li)
    ,.lce_req_data_i(cce_lce_req_data_li)
    ,.lce_req_v_i(cce_lce_req_v_li)
    ,.lce_req_ready_and_o(cce_lce_req_ready_and_lo)

    ,.lce_cmd_header_o(cce_lce_cmd_header_lo)
    ,.lce_cmd_data_o(cce_lce_cmd_data_lo)
    ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
    ,.lce_cmd_ready_and_i(cce_lce_cmd_ready_and_li)

    ,.lce_resp_header_i(cce_lce_resp_header_li)
    ,.lce_resp_data_i(cce_lce_resp_data_li)
    ,.lce_resp_v_i(cce_lce_resp_v_li)
    ,.lce_resp_ready_and_o(cce_lce_resp_ready_and_lo)

    // CCE-MEM Interface
    // BedRock Stream protocol: ready&valid
    ,.mem_rev_header_i(mem_rev_header)
    ,.mem_rev_data_i(mem_rev_data)
    ,.mem_rev_v_i(mem_rev_v)
    ,.mem_rev_ready_and_o(mem_rev_ready_and)

    ,.mem_fwd_header_o(mem_fwd_header)
    ,.mem_fwd_data_o(mem_fwd_data)
    ,.mem_fwd_v_o(mem_fwd_v)
    ,.mem_fwd_ready_and_i(mem_fwd_ready_and)
  );

  // Memory Fwd Buffer
  bp_bedrock_mem_fwd_header_s mem_fwd_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li, mem_fwd_yumi_li;
  bsg_fifo_1r1w_small
  #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p)
    ,.els_p(mem_buffer_els_lp)
    )
  mem_fwd_stream_buffer
   (.clk_i(dut_clk)
    ,.reset_i(dut_reset)
    // from CCE
    ,.v_i(mem_fwd_v)
    ,.ready_param_o(mem_fwd_ready_and)
    ,.data_i({mem_fwd_data, mem_fwd_header})
    // to memory
    ,.v_o(mem_fwd_v_lo)
    ,.yumi_i(mem_fwd_yumi_li)
    ,.data_o({mem_fwd_data_lo, mem_fwd_lo})
    );
  assign mem_fwd_yumi_li = mem_fwd_v_lo & mem_fwd_ready_and_li;

  // Memory Rev Buffer
  bp_bedrock_mem_rev_header_s mem_rev_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo, mem_rev_yumi_lo;
  bsg_fifo_1r1w_small
  #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+bedrock_fill_width_p)
    ,.els_p(mem_buffer_els_lp)
    )
  mem_rev_stream_buffer
   (.clk_i(dut_clk)
    ,.reset_i(dut_reset)
    // from memory
    ,.v_i(mem_rev_v_li)
    ,.ready_param_o(mem_rev_ready_and_lo)
    ,.data_i({mem_rev_data_li, mem_rev_li})
    // to CCE
    ,.v_o(mem_rev_v)
    ,.yumi_i(mem_rev_yumi_lo)
    ,.data_o({mem_rev_data, mem_rev_header})
    );
  assign mem_rev_yumi_lo = mem_rev_v & mem_rev_ready_and;

  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p))
   mem
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.mem_fwd_header_i(mem_fwd_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_v_i(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_li)

     ,.mem_rev_header_o(mem_rev_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_v_o(mem_rev_v_li)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_lo)
     );

  // Config
  // TODO: not sure why regular config loader doesn't work here
  bp_bedrock_mem_fwd_header_s cfg_mem_fwd_lo;
  logic [bedrock_fill_width_p-1:0] cfg_mem_fwd_data_lo;
  logic cfg_mem_fwd_v_lo, cfg_mem_fwd_ready_and_li;
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
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.lce_id_i('0)

     ,.mem_fwd_header_o(cfg_mem_fwd_lo)
     ,.mem_fwd_data_o(cfg_mem_fwd_data_lo)
     ,.mem_fwd_v_o(cfg_mem_fwd_v_lo)
     ,.mem_fwd_yumi_i(cfg_mem_fwd_ready_and_li & cfg_mem_fwd_v_lo)

     ,.mem_rev_header_i('0)
     ,.mem_rev_data_i('0)
     ,.mem_rev_v_i(cfg_mem_rev_v_lo)
     ,.mem_rev_ready_and_o()

     ,.done_o(cfg_loader_done_lo)
     );

  logic [coh_noc_cord_width_p-1:0] cord_li = {{coh_noc_y_cord_width_p'(1'b1)}, {coh_noc_x_cord_width_p'('0)}};
  bp_me_cfg_slice
   #(.bp_params_p(bp_params_p))
   cfgs
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.mem_fwd_header_i(cfg_mem_fwd_lo)
     ,.mem_fwd_data_i(cfg_mem_fwd_data_lo)
     ,.mem_fwd_v_i(cfg_mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(cfg_mem_fwd_ready_and_li)

     ,.mem_rev_header_o()
     ,.mem_rev_data_o()
     ,.mem_rev_v_o(cfg_mem_rev_v_lo)
     ,.mem_rev_ready_and_i(cfg_mem_rev_v_lo)

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

  // Tracers and binds

  wire lce_trace_en_li = testbench.lce_trace_p;
  bind bp_lce
    bp_me_nonsynth_lce_tracer
      #(.bp_params_p(bp_params_p), .trace_str_p("lce")
        ,.sets_p(sets_p)
        ,.assoc_p(assoc_p)
        ,.block_width_p(block_width_p)
        ,.fill_width_p(fill_width_p)
        ,.data_width_p(data_width_p)
        )
      lce_tracer
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.en_i(testbench.lce_trace_en_li)
        );

  wire cce_trace_en_li = testbench.cce_trace_p;
  bind bp_cce_wrapper
    bp_me_nonsynth_cce_tracer
      #(.bp_params_p(bp_params_p), .trace_str_p("cce"))
      cce_tracer
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.en_i(testbench.cce_trace_en_li)
        );

  wire dram_trace_en_li = testbench.dram_trace_p;
  bind bp_nonsynth_dram
    bp_nonsynth_dram_tracer
     #(.num_dma_p(num_dma_p)
       ,.dma_addr_width_p(dma_addr_width_p)
       ,.dma_data_width_p(dma_data_width_p)
       ,.dma_burst_len_p(dma_burst_len_p)
       ,.dma_mask_width_p(dma_mask_width_p)
       ,.trace_str_p("dram")
       )
     dram_tracer
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.dram_trace_en_li)
       );

  wire waveform_en_li = 1'b1;
  bsg_nonsynth_waveform_tracer
   tracer
    (.clk_i(testbench.dut_clk)
     ,.reset_i(testbench.dut_reset)
     ,.en_i(testbench.waveform_en_li)
     );

  wire assert_en_li = 1'b1;
  bsg_nonsynth_assert
   _assert
    (.clk_i(testbench.dut_clk)
     ,.reset_i(testbench.dut_reset)
     ,.en_i(testbench.assert_en_li)
     );

  wire ifverif_en_li = 1'b1;
  bp_nonsynth_if_verif
   #(.bp_params_p(bp_params_p))
   if_verif
    (.clk_i(testbench.dut_clk)
     ,.reset_i(testbench.dut_reset)
     ,.en_i(testbench.ifverif_en_li)
     );

  // Program done info
  localparam max_clock_cnt_lp    = 2**30-1;
  localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
  logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_clock_cnt_lp)
     ,.init_val_p(0)
     )
   clock_counter
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.clear_i(dut_reset)
     ,.up_i(1'b1)

     ,.count_o(clock_cnt)
     );

  always_ff @(negedge dut_clk) begin
    if (&tr_done_lo) begin
      $display("[BSG-PASS]");
      $finish;
    end
  end

  final begin
      $display("Bytes: %d Clocks: %d mBPC: %d "
               , instr_count*64
               , clock_cnt
               , (instr_count*64*1000) / clock_cnt
               );
  end

endmodule

