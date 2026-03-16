/**
  *
  * testbench.v
  *
  */


`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"

`ifndef BP_CFG_FLOWVAR
"BSG-ERROR BP_CFG_FLOWVAR must be set"
`endif

module testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = `BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // tb parameters
   , parameter tb_clock_period_p           = 0
   , parameter tb_reset_cycles_lo_p        = 0
   , parameter tb_reset_cycles_hi_p        = 0

   // sim parameters
   , parameter sim_clock_period_p          = 0
   , parameter sim_reset_cycles_lo_p       = 0
   , parameter sim_reset_cycles_hi_p       = 0

   // watchdog parameters
   , parameter watchdog_enable_p           = 0
   , parameter stall_cycles_p              = 0
   , parameter halt_instr_p                = 0
   , parameter heartbeat_instr_p           = 0

   // cosim parameters
   , parameter cosim_trace_p               = 0
   , parameter cosim_check_p               = 0

   // perf parameters
   , parameter perf_enable_p               = 0
   , parameter warmup_instr_p              = 0
   , parameter max_instr_p                 = 0
   , parameter max_cycle_p                 = 0

   // trace parameters
   , parameter icache_trace_p              = 0
   , parameter dcache_trace_p              = 0
   , parameter vm_trace_p                  = 0
   , parameter uce_trace_p                 = 0
   , parameter lce_trace_p                 = 0
   , parameter cce_trace_p                 = 0
   , parameter dev_trace_p                 = 0
   , parameter dram_trace_p                = 0
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // Bit to deal with initial X->0 transition detection
  bit dut_clk, dut_reset;
  bit tb_clk, tb_reset;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_ready_and_lo;
  bp_bedrock_mem_rev_header_s mem_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_lo;
  logic mem_rev_v_lo, mem_rev_ready_and_li;

  `declare_bsg_cache_dma_pkt_s(daddr_width_p, l2_block_size_in_words_p);
  bsg_cache_dma_pkt_s [num_cce_p-1:0][l2_dmas_p-1:0] dma_pkt_lo;
  logic [num_cce_p-1:0][l2_dmas_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [num_cce_p-1:0][l2_dmas_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  logic [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [num_cce_p-1:0][l2_dmas_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  wire [mem_noc_did_width_p-1:0] proc_did_li = 1;
  wire [mem_noc_did_width_p-1:0] host_did_li = '1;
  wire [lce_id_width_p-1:0] host_lce_id_li = num_core_p*2+num_cacc_p+num_l2e_p+num_sacc_p+num_io_p;
  wrapper
   #(.bp_params_p(bp_params_p))
   wrapper
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.my_did_i(proc_did_li)
     ,.host_did_i(host_did_li)

     ,.mem_fwd_header_i(mem_fwd_header_li)
     ,.mem_fwd_data_i(mem_fwd_data_li)
     ,.mem_fwd_v_i(mem_fwd_v_li)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_lo)

     ,.mem_rev_header_o(mem_rev_header_lo)
     ,.mem_rev_data_o(mem_rev_data_lo)
     ,.mem_rev_v_o(mem_rev_v_lo)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_li)

     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_ready_and_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_and_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_ready_and_i(dma_data_yumi_li)
     );

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(sim_clock_period_p))
   dut_clock_gen
    (.o(dut_clk));

  bsg_nonsynth_reset_gen
   #(.reset_cycles_lo_p(sim_reset_cycles_lo_p), .reset_cycles_hi_p(sim_reset_cycles_hi_p))
   dut_reset_gen
    (.clk_i(dut_clk)
     ,.async_reset_o(dut_reset)
     );

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(tb_clock_period_p))
   tb_clock_gen
    (.o(tb_clk));

  bsg_nonsynth_reset_gen
   #(.reset_cycles_lo_p(tb_reset_cycles_lo_p), .reset_cycles_hi_p(tb_reset_cycles_hi_p))
   tb_reset_gen
    (.clk_i(tb_clk)
     ,.async_reset_o(tb_reset)
     );

  logic loader_done_lo;
  bp_nonsynth_cfg_loader
   #(.bp_params_p(bp_params_p), .ucode_str_p("ucode_mem"))
   loader
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.lce_id_i(host_lce_id_li)
     ,.did_i(host_did_li)

     ,.mem_fwd_header_o(mem_fwd_header_li)
     ,.mem_fwd_data_o(mem_fwd_data_li)
     ,.mem_fwd_v_o(mem_fwd_v_li)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_lo)

     ,.mem_rev_header_i(mem_rev_header_lo)
     ,.mem_rev_data_i(mem_rev_data_lo)
     ,.mem_rev_v_i(mem_rev_v_lo)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_li)

     ,.done_o(loader_done_lo)
     );

  bp_nonsynth_dram
   #(.num_dma_p(num_cce_p*l2_dmas_p)
     ,.dma_addr_width_p(daddr_width_p)
     ,.dma_data_width_p(l2_fill_width_p)
     ,.dma_burst_len_p(l2_block_size_in_fill_p)
     ,.dma_mask_width_p(l2_block_size_in_words_p)
     )
   dram
    (.clk_i(dut_clk)
     ,.reset_i(dut_reset)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_and_i(dma_data_ready_and_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)
     );

  bp_nonsynth_host
   #(.bp_params_p(bp_params_p))
   host
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

  wire perf_en_li = testbench.perf_enable_p;
  bind bp_be_csr
    bp_be_nonsynth_perf
     #(.bp_params_p(bp_params_p), .trace_str_p("perf"))
     perf
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.perf_en_li)
       ,.warmup_instr_pi(testbench.warmup_instr_p)
       ,.max_instr_pi(testbench.max_instr_p)
       ,.max_cycle_pi(testbench.max_cycle_p)
       );

  wire watchdog_en_li = testbench.watchdog_enable_p;
  bind bp_be_top
    bp_be_nonsynth_watchdog
     #(.bp_params_p(bp_params_p), .trace_str_p("watchdog"))
     watchdog
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.watchdog_en_li)
       ,.stall_cycles_pi(testbench.stall_cycles_p)
       ,.halt_instr_pi(testbench.halt_instr_p)
       ,.heartbeat_instr_pi(testbench.heartbeat_instr_p)
       );

  wire icache_tracer_en_li = testbench.icache_trace_p;
  bind bp_fe_icache
    bp_fe_nonsynth_icache_tracer
     #(.bp_params_p(bp_params_p), .trace_str_p("icache"))
     icache_tracer
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.icache_tracer_en_li)
       ,.cfg_bus_i(bp_fe_top.cfg_bus_i)
       );

  wire dcache_tracer_en_li = testbench.dcache_trace_p;
  bind bp_be_dcache
    bp_be_nonsynth_dcache_tracer
     #(.bp_params_p(bp_params_p), .trace_str_p("dcache"))
     dcache_tracer
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.dcache_tracer_en_li)
       ,.cfg_bus_i(bp_be_pipe_mem.cfg_bus_i)
       );

// v5.036: Unsupported: Bind with instance list
`ifndef VERILATOR
  wire immu_tracer_en_li = testbench.vm_trace_p;
  bind bp_mmu:immu bp_nonsynth_vm_tracer
   #(.bp_params_p(bp_params_p), .trace_str_p("immu"))
   immu_tracer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(testbench.immu_tracer_en_li)
     );

  wire dmmu_tracer_en_li = testbench.vm_trace_p;
  bind bp_mmu:dmmu bp_nonsynth_vm_tracer
   #(.bp_params_p(bp_params_p), .trace_str_p("dmmu"))
   dmmu_tracer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(testbench.dmmu_tracer_en_li)
     );
`endif

  wire cosim_en_li = 1'b1;
  bind bp_be_top
    bp_be_nonsynth_cosim
     #(.bp_params_p(bp_params_p), .trace_str_p("commit"))
     cosim
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.cosim_en_li)

       ,.trace_en_pi(testbench.cosim_trace_p)
       ,.check_en_pi(testbench.cosim_check_p)

       ,.cosim_clk_i(testbench.tb_clk)
       ,.cosim_reset_i(testbench.tb_reset)
       );

  wire uce_trace_en_li = testbench.uce_trace_p;
  bind bp_uce
    bp_me_nonsynth_uce_tracer
     #(.bp_params_p(bp_params_p), .trace_str_p("uce")
       ,.writeback_p(writeback_p)
       ,.assoc_p(assoc_p)
       ,.sets_p(sets_p)
       ,.block_width_p(block_width_p)
       ,.fill_width_p(fill_width_p)
       ,.data_width_p(data_width_p)
       ,.tag_width_p(tag_width_p)
       ,.id_width_p(id_width_p)
       )
     uce_tracer
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.uce_trace_en_li)
       );

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

// v5.036: Unsupported: Bind with instance list
`ifndef VERILATOR
  wire clint_trace_en_li = testbench.dev_trace_p;
  bind bp_me_bedrock_register:clints_register
    bp_me_nonsynth_dev_tracer
     #(.bp_params_p(bp_params_p), .trace_str_p("clint")
       ,.els_p(els_p)
       ,.reg_data_width_p(reg_data_width_p)
       ,.reg_addr_width_p(reg_addr_width_p)
       )
     clint_tracer
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.clint_trace_en_li)
       ,.cfg_bus_i(bp_me_clint_slice.cfg_bus_i)
       );

  wire cfg_trace_en_li = testbench.dev_trace_p;
  bind bp_me_bedrock_register:cfgs_register
    bp_me_nonsynth_dev_tracer
     #(.bp_params_p(bp_params_p), .trace_str_p("cfg")
       ,.els_p(els_p)
       ,.reg_data_width_p(reg_data_width_p)
       ,.reg_addr_width_p(reg_addr_width_p)
       )
     cfg_tracer
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(testbench.cfg_trace_en_li)
       ,.cfg_bus_i(bp_me_cfg_slice.cfg_bus_o)
       );
`endif

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
   #(.trace_str_p("bsg_trace"))
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

endmodule

