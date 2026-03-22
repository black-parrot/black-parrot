
`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_nonsynth_icache_tracer
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter string trace_str_p = ""

   // Default to icache parameters, but can override if needed
   , parameter features_p    = icache_features_p
   , parameter sets_p        = icache_sets_p
   , parameter assoc_p       = icache_assoc_p
   , parameter block_width_p = icache_block_width_p
   , parameter fill_width_p  = icache_fill_width_p
   , parameter data_width_p  = icache_data_width_p
   , parameter tag_width_p   = icache_tag_width_p
   , parameter id_width_p    = icache_req_id_width_p

   `declare_bp_common_if_widths(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   `declare_bp_fe_icache_engine_if_widths(paddr_width_p, tag_width_p, sets_p, assoc_p, data_width_p, block_width_p, fill_width_p, id_width_p)
   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i
   , input                                            en_i
   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i
   );

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_fe_icache_engine_if(paddr_width_p, tag_width_p, sets_p, assoc_p, data_width_p, block_width_p, fill_width_p, id_width_p);
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);

  // snoop
  wire bp_cfg_bus_s cfg_bus = cfg_bus_i;
  wire bp_fe_icache_pkt_s icache_pkt = bp_fe_icache.icache_pkt_i;
  wire bp_fe_icache_req_s cache_req = bp_fe_icache.cache_req_o;
  wire bp_fe_icache_req_metadata_s cache_req_metadata = bp_fe_icache.cache_req_metadata_o;
  wire bp_fe_icache_data_mem_pkt_s data_mem_pkt = bp_fe_icache.data_mem_pkt_i;
  wire bp_fe_icache_tag_mem_pkt_s tag_mem_pkt = bp_fe_icache.tag_mem_pkt_i;
  wire bp_fe_icache_stat_mem_pkt_s stat_mem_pkt = bp_fe_icache.stat_mem_pkt_i;

  wire [block_width_p-1:0] data_mem_info = bp_fe_icache.data_mem_o;
  wire bp_fe_icache_tag_info_s tag_mem_info = bp_fe_icache.tag_mem_o;
  wire bp_fe_icache_stat_info_s stat_mem_info = bp_fe_icache.stat_mem_o;

  wire data_mem_pkt_yumi = bp_fe_icache.data_mem_pkt_yumi_o;
  wire tag_mem_pkt_yumi = bp_fe_icache.tag_mem_pkt_yumi_o;
  wire stat_mem_pkt_yumi = bp_fe_icache.stat_mem_pkt_yumi_o;

  wire cache_req_yumi = bp_fe_icache.cache_req_yumi_i;
  wire cache_req_critical = bp_fe_icache.cache_req_critical_i;
  wire cache_req_last = bp_fe_icache.cache_req_last_i;

  wire req_v = bp_fe_icache.yumi_o;
  wire [data_width_p-1:0] data_out = bp_fe_icache.data_o;
  wire hit_v = bp_fe_icache.hit_v_o & bp_fe_icache.yumi_i;
  wire miss_v = bp_fe_icache.miss_v_o & bp_fe_icache.yumi_i;
  wire fence_v = bp_fe_icache.fence_v_o & bp_fe_icache.yumi_i;

  wire [paddr_width_p-1:0] paddr_tv = bp_fe_icache.paddr_tv_r;
  wire [core_id_width_p-1:0] mhartid = cfg_bus.core_id;

  // process
  logic data_mem_ack_r, tag_mem_ack_r, stat_mem_ack_r, cache_req_ack_r;
  logic cache_req_critical_r, cache_req_last_r;
  bp_fe_icache_data_mem_pkt_s data_mem_pkt_r;
  bp_fe_icache_tag_mem_pkt_s tag_mem_pkt_r;
  bp_fe_icache_stat_mem_pkt_s stat_mem_pkt_r;
  bp_fe_icache_req_s cache_req_r;
  always_ff @(posedge clk_i)
    begin
      data_mem_ack_r <= data_mem_pkt_yumi;
      tag_mem_ack_r <= tag_mem_pkt_yumi;
      stat_mem_ack_r <= stat_mem_pkt_yumi;
      cache_req_ack_r <= cache_req_yumi;
      cache_req_critical_r <= cache_req_critical;
      cache_req_last_r <= cache_req_last;

      data_mem_pkt_r <= data_mem_pkt;
      tag_mem_pkt_r <= tag_mem_pkt;
      stat_mem_pkt_r <= stat_mem_pkt;
      cache_req_r <= cache_req;
    end

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, mhartid);
  always_ff @(posedge clk_i)
    if (do_init)
      begin
        $fdisplay(file,"==============================================");
        $fdisplay(file, "L1 cache features:");
        $fdisplay(file, "\te_cfg_enabled: %b", features_p[e_cfg_enabled]);
        $fdisplay(file, "\te_cfg_coherent: %b", features_p[e_cfg_coherent]);
        $fdisplay(file, "\te_cfg_writeback: %b", features_p[e_cfg_writeback]);
        $fdisplay(file, "\te_cfg_word_tracking: %b", features_p[e_cfg_word_tracking]);
        $fdisplay(file, "\te_cfg_lr_sc: %b", features_p[e_cfg_lr_sc]);
        $fdisplay(file, "\te_cfg_amo_swap: %b", features_p[e_cfg_amo_swap]);
        $fdisplay(file, "\te_cfg_amo_fetch_logic: %b", features_p[e_cfg_amo_fetch_logic]);
        $fdisplay(file, "\te_cfg_amo_fetch_arithmetic: %b", features_p[e_cfg_amo_fetch_arithmetic]);
        $fdisplay(file, "\te_cfg_hit_under_miss: %b", features_p[e_cfg_hit_under_miss]);
        $fdisplay(file, "\te_cfg_misaligned: %b", features_p[e_cfg_misaligned]);
        $fdisplay(file,"==============================================");
      end
    else if (is_go)
      begin
        if (req_v)
          $fdisplay(file, "%8t | req [%x]", $time, icache_pkt.vaddr);
        if (hit_v)
          $fdisplay(file, "%8t | hit [%x] == %x", $time, paddr_tv, data_out);
        if (miss_v)
          $fdisplay(file, "%8t | miss [%x]", $time, paddr_tv);
        if (fence_v)
          $fdisplay(file, "%8t | fence [%x]", $time, paddr_tv);
        if (cache_req_ack_r)
          $fdisplay(file, "%8t | cache_req\n\t\t\t%p\n\t\t\t%p", $time, cache_req_r, cache_req_metadata);
        if (data_mem_ack_r)
          $fdisplay(file, "%8t | data_mem_pkt [%b|%b]\n\t\t\t%p", $time, cache_req_critical_r, cache_req_last_r, data_mem_pkt_r);
        if (tag_mem_ack_r)
          $fdisplay(file, "%8t | tag_mem_pkt [%b|%b]\n\t\t\t%p", $time, cache_req_critical_r, cache_req_last_r, tag_mem_pkt_r);
        if (stat_mem_ack_r)
          $fdisplay(file, "%8t | stat_mem_pkt [%b|%b]\n\t\t\t%p", $time, cache_req_critical_r, cache_req_last_r, stat_mem_pkt_r);
      end

  always_ff @(negedge clk_i)
    assert (!is_go || ~bp_fe_icache.v_tv_r || $countones(bp_fe_icache.hit_v_tl) <= 1)
      else $error("%m multiple hit: %b at [%x]", bp_fe_icache.hit_v_tl, bp_fe_icache.ptag_i);

endmodule

