/**
 * testbench.sv
 *
 * Trace-replay based testbench for bp_be_dcache.
 *
 * Phase 1: Bare scaffold — DUT + UCE + memory instantiated with
 *          all stimulus tied off. Validates elaboration and the
 *          UCE init sequence (tag/stat memory clearing).
 *
 * Architecture:
 *   wrapper (bp_be_dcache) → bp_uce → bp_nonsynth_mem
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

`ifndef BP_CFG_FLOWVAR
"BSG-ERROR BP_CFG_FLOWVAR must be set"
`endif

module testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = `BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   // Sim parameters (driven by mk/Makefile.params)
   , parameter sim_clock_period_p          = 0
   , parameter sim_reset_cycles_lo_p       = 0
   , parameter sim_reset_cycles_hi_p       = 0

   , parameter tb_clock_period_p           = 0
   , parameter tb_reset_cycles_lo_p        = 0
   , parameter tb_reset_cycles_hi_p        = 0

   // D$ parameters — derived from the config
   , localparam sets_lp         = dcache_sets_p
   , localparam assoc_lp        = dcache_assoc_p
   , localparam block_width_lp  = dcache_block_width_p
   , localparam fill_width_lp   = dcache_fill_width_p
   , localparam data_width_lp   = dcache_data_width_p
   , localparam tag_width_lp    = dcache_tag_width_p
   , localparam id_width_lp     = dcache_req_id_width_p

   // Cache engine interface widths (needed for wire declarations)
   `declare_bp_be_dcache_engine_if_widths(paddr_width_p, tag_width_lp, sets_lp, assoc_lp, data_width_lp, block_width_lp, fill_width_lp, id_width_lp)

   // BedRock interface widths (for UCE ↔ memory)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   // D$ packet width
   , localparam dcache_pkt_width_lp = `bp_be_dcache_pkt_width(vaddr_width_p)

   // Writeback support — must match D$ features
   , localparam writeback_lp = dcache_features_p[e_cfg_writeback]
   );

  // Sanity check: L2 data width must match bedrock fill width
  if (l2_data_width_p != bedrock_fill_width_p)
    $error("L2 data width must match bedrock data width");

  //////////////////////////////////////////////////////////////////////////////
  // Clock and Reset
  //////////////////////////////////////////////////////////////////////////////

  // Use 'bit' type to avoid X→0 transition issues in VCS
  bit dut_clk, dut_reset;

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(sim_clock_period_p))
   clock_gen
    (.o(dut_clk));

  bsg_nonsynth_reset_gen
   #(.reset_cycles_lo_p(sim_reset_cycles_lo_p)
     ,.reset_cycles_hi_p(sim_reset_cycles_hi_p)
     )
   reset_gen
    (.clk_i(dut_clk)
     ,.async_reset_o(dut_reset)
     );

  //////////////////////////////////////////////////////////////////////////////
  // DUT (wrapper around bp_be_dcache)
  //////////////////////////////////////////////////////////////////////////////

  // D$ stimulus — 'for Phase 1
  logic [dcache_pkt_width_lp-1:0] dcache_pkt_li;
  logic                           dcache_v_li;
  logic [ptag_width_p-1:0]        ptag_li;
  logic                           ptag_v_li;
  logic                           ptag_uncached_li;
  logic                           ptag_dram_li;
  logic [data_width_lp-1:0]       st_data_li;
  logic                           flush_li;

  // D$ response outputs
  logic                           dcache_v_lo;
  logic [data_width_lp-1:0]       dcache_data_lo;
  logic [reg_addr_width_gp-1:0]   dcache_rd_addr_lo;
  logic                           dcache_busy_lo;
  logic                           dcache_ordered_lo;

  // Cache engine interface: DUT ↔ UCE
  logic [dcache_req_width_lp-1:0]          cache_req_lo;
  logic                                    cache_req_v_lo;
  logic                                    cache_req_yumi_li;
  logic                                    cache_req_lock_li;
  logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_lo;
  logic                                    cache_req_metadata_v_lo;
  logic [id_width_lp-1:0]                  cache_req_id_li;
  logic                                    cache_req_critical_li;
  logic                                    cache_req_last_li;
  logic                                    cache_req_credits_full_li;
  logic                                    cache_req_credits_empty_li;

  // Memory interface: DUT ↔ UCE (tag/data/stat SRAMs)
  logic                                    data_mem_pkt_v_li;
  logic [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_li;
  logic                                    data_mem_pkt_yumi_lo;
  logic [block_width_lp-1:0]               data_mem_lo;

  logic                                    tag_mem_pkt_v_li;
  logic [dcache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_li;
  logic                                    tag_mem_pkt_yumi_lo;
  logic [dcache_tag_info_width_lp-1:0]     tag_mem_lo;

  logic                                    stat_mem_pkt_v_li;
  logic [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_li;
  logic                                    stat_mem_pkt_yumi_lo;
  logic [dcache_stat_info_width_lp-1:0]    stat_mem_lo;

  // Phase 1: Tie off all stimulus
  assign dcache_pkt_li     = '0;
  assign dcache_v_li       = 1'b0;
  assign ptag_li           = '0;
  assign ptag_v_li         = 1'b0;
  assign ptag_uncached_li  = 1'b0;
  assign ptag_dram_li      = 1'b1;  // Important: treat as DRAM region
  assign st_data_li        = '0;
  assign flush_li          = 1'b0;

  wrapper
   #(.bp_params_p(bp_params_p))
   wrapper
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.busy_o(dcache_busy_lo)
     ,.ordered_o(dcache_ordered_lo)

     // Cycle 0: Request
     ,.dcache_pkt_i(dcache_pkt_li)
     ,.v_i(dcache_v_li)

     // Cycle 1: Tag Lookup
     ,.ptag_i(ptag_li)
     ,.ptag_v_i(ptag_v_li)
     ,.ptag_uncached_i(ptag_uncached_li)
     ,.ptag_dram_i(ptag_dram_li)
     ,.st_data_i(st_data_li)
     ,.flush_i(flush_li)

     // Cycle 2: Tag Verify
     ,.v_o(dcache_v_lo)
     ,.data_o(dcache_data_lo)
     ,.rd_addr_o(dcache_rd_addr_lo)
     ,.tag_o()
     ,.unsigned_o()
     ,.int_o()
     ,.float_o()
     ,.ptw_o()
     ,.ret_o()
     ,.late_o()

     // Cache Engine Interface
     ,.cache_req_o(cache_req_lo)
     ,.cache_req_v_o(cache_req_v_lo)
     ,.cache_req_yumi_i(cache_req_yumi_li)
     ,.cache_req_lock_i(cache_req_lock_li)
     ,.cache_req_metadata_o(cache_req_metadata_lo)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_lo)
     ,.cache_req_id_i(cache_req_id_li)
     ,.cache_req_critical_i(cache_req_critical_li)
     ,.cache_req_last_i(cache_req_last_li)
     ,.cache_req_credits_full_i(cache_req_credits_full_li)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_li)

     // Data mem
     ,.data_mem_pkt_v_i(data_mem_pkt_v_li)
     ,.data_mem_pkt_i(data_mem_pkt_li)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo)
     ,.data_mem_o(data_mem_lo)

     // Tag mem
     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_li)
     ,.tag_mem_pkt_i(tag_mem_pkt_li)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo)
     ,.tag_mem_o(tag_mem_lo)

     // Stat mem
     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_li)
     ,.stat_mem_pkt_i(stat_mem_pkt_li)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo)
     ,.stat_mem_o(stat_mem_lo)
     );

  //////////////////////////////////////////////////////////////////////////////
  // UCE (Cache Engine)
  //////////////////////////////////////////////////////////////////////////////

  // BedRock memory interface: UCE ↔ bp_nonsynth_mem
  logic [mem_fwd_header_width_lp-1:0]  mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0]     mem_fwd_data_lo;
  logic                                mem_fwd_v_lo;
  logic                                mem_fwd_ready_and_li;

  logic [mem_rev_header_width_lp-1:0]  mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0]     mem_rev_data_li;
  logic                                mem_rev_v_li;
  logic                                mem_rev_ready_and_lo;

  bp_uce
   #(.bp_params_p(bp_params_p)
     ,.writeback_p(writeback_lp)
     ,.assoc_p(assoc_lp)
     ,.sets_p(sets_lp)
     ,.block_width_p(block_width_lp)
     ,.fill_width_p(fill_width_lp)
     ,.data_width_p(data_width_lp)
     ,.tag_width_p(tag_width_lp)
     ,.id_width_p(id_width_lp)
     )
   uce
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.did_i('0)
     ,.lce_id_i('0)

     // Cache interface (connects to DUT)
     ,.cache_req_i(cache_req_lo)
     ,.cache_req_v_i(cache_req_v_lo)
     ,.cache_req_yumi_o(cache_req_yumi_li)
     ,.cache_req_lock_o(cache_req_lock_li)
     ,.cache_req_metadata_i(cache_req_metadata_lo)
     ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
     ,.cache_req_id_o(cache_req_id_li)
     ,.cache_req_critical_o(cache_req_critical_li)
     ,.cache_req_last_o(cache_req_last_li)
     ,.cache_req_credits_full_o(cache_req_credits_full_li)
     ,.cache_req_credits_empty_o(cache_req_credits_empty_li)

     // Tag mem (connects to DUT)
     ,.tag_mem_pkt_o(tag_mem_pkt_li)
     ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)
     ,.tag_mem_i(tag_mem_lo)

     // Data mem (connects to DUT)
     ,.data_mem_pkt_o(data_mem_pkt_li)
     ,.data_mem_pkt_v_o(data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)
     ,.data_mem_i(data_mem_lo)

     // Stat mem (connects to DUT)
     ,.stat_mem_pkt_o(stat_mem_pkt_li)
     ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li)
     ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(stat_mem_lo)

     // Memory interface (connects to bp_nonsynth_mem)
     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)
     );

  //////////////////////////////////////////////////////////////////////////////
  // Memory Model
  //////////////////////////////////////////////////////////////////////////////

  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p))
   mem
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.mem_fwd_header_i(mem_fwd_header_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_v_i(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_li)

     ,.mem_rev_header_o(mem_rev_header_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_v_o(mem_rev_v_li)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_lo)
     );

  //////////////////////////////////////////////////////////////////////////////
  // Non-synth utilities
  //////////////////////////////////////////////////////////////////////////////

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



  //////////////////////////////////////////////////////////////////////////////
  // Termination logic
  //
  // Phase 1: Run for a fixed number of cycles after reset.
  // The UCE init sequence takes dcache_sets_p cycles (~64 for default config).
  // We run for 512 cycles to be safe, then check that busy_o has deasserted
  // (meaning the UCE reached e_ready and released cache_req_lock).
  //////////////////////////////////////////////////////////////////////////////

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

  // Phase 1 termination: after 512 cycles, check busy_o
  localparam phase1_done_cycle_lp = 512;

  always_ff @(negedge dut_clk) begin
    if (~dut_reset & (clock_cnt == phase1_done_cycle_lp)) begin
      if (~dcache_busy_lo) begin
        $display("[BSG-PASS] Phase 1: Elaboration and reset complete. UCE init done, busy_o deasserted.");
        $finish;
      end else begin
        $display("[BSG-FAIL] Phase 1: D$ still busy after %0d cycles. UCE may not have completed init.", phase1_done_cycle_lp);
        $finish;
      end
    end
  end

endmodule
