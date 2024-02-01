/**
  *
  * testbench.v
  *
  */

`include "bsg_noc_links.svh"

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

`ifndef BP_RT_CLK_PERIOD
`define BP_RT_CLK_PERIOD 100
`endif

module testbench
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   // TRACE enable parameters
   , parameter icache_trace_p              = 0
   , parameter dcache_trace_p              = 0
   , parameter lce_trace_p                 = 0
   , parameter cce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter vm_trace_p                  = 0
   , parameter cmt_trace_p                 = 0
   , parameter core_profile_p              = 0
   , parameter pc_gen_trace_p              = 0
   , parameter pc_profile_p                = 0
   , parameter br_profile_p                = 0
   , parameter cosim_p                     = 0
   , parameter dev_trace_p                 = 0

   // COSIM parameters
   , parameter checkpoint_p                = 0
   , parameter cosim_memsize_p             = 0
   , parameter cosim_cfg_file_p            = "prog.cfg"
   , parameter cosim_instr_p               = 0
   , parameter warmup_instr_p              = 0
   , parameter amo_en_p                    = 0

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type
   , parameter preload_mem_p               = 0

   // Synthesis parameters
   , parameter no_bind_p                   = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   )
  (output bit reset_i);

  export "DPI-C" function get_dram_period;
  export "DPI-C" function get_sim_period;

  function int get_dram_period();
    return (`dram_pkg::tck_ps);
  endfunction

  function int get_sim_period();
    return (`BP_SIM_CLK_PERIOD);
  endfunction

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

// Bit to deal with initial X->0 transition detection
  bit clk_i;
  bit rt_clk_i, cosim_clk_i, cosim_reset_i, dram_clk_i, dram_reset_i;

  bsg_nonsynth_clock_gen
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

  bsg_nonsynth_clock_gen
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

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(`BP_SIM_CLK_PERIOD/5))
   cosim_clk_gen
    (.o(cosim_clk_i));

  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(10)
     )
   cosim_reset_gen
    (.clk_i(cosim_clk_i)
     ,.async_reset_o(cosim_reset_i)
     );

  bsg_nonsynth_clock_gen
   #(.cycle_time_p(`BP_RT_CLK_PERIOD))
   rt_clk_gen
    (.o(rt_clk_i));

  bp_bedrock_mem_fwd_header_s proc_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] proc_fwd_data_lo;
  logic proc_fwd_v_lo, proc_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s proc_rev_header_li;
  logic [bedrock_fill_width_p-1:0] proc_rev_data_li;
  logic proc_rev_v_li, proc_rev_ready_and_lo;

  bp_bedrock_mem_fwd_header_s proc_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] proc_fwd_data_li;
  logic proc_fwd_v_li, proc_fwd_ready_and_lo;
  bp_bedrock_mem_rev_header_s proc_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] proc_rev_data_lo;
  logic proc_rev_v_lo, proc_rev_ready_and_li;

  `declare_bsg_cache_dma_pkt_s(daddr_width_p, l2_block_size_in_words_p);
  bsg_cache_dma_pkt_s [num_cce_p-1:0][l2_dmas_p-1:0] dma_pkt_lo;
  logic [num_cce_p-1:0][l2_dmas_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [num_cce_p-1:0][l2_dmas_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  logic [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [num_cce_p-1:0][l2_dmas_p-1:0] dma_data_v_li, dma_data_ready_and_lo;

  wire [mem_noc_did_width_p-1:0] proc_did_li = 1;
  wire [mem_noc_did_width_p-1:0] host_did_li = '1;
  wrapper
   #(.bp_params_p(bp_params_p))
   wrapper
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)

     ,.my_did_i(proc_did_li)
     ,.host_did_i(host_did_li)

     ,.mem_fwd_header_o(proc_fwd_header_lo)
     ,.mem_fwd_data_o(proc_fwd_data_lo)
     ,.mem_fwd_v_o(proc_fwd_v_lo)
     ,.mem_fwd_ready_and_i(proc_fwd_ready_and_li)

     ,.mem_rev_header_i(proc_rev_header_li)
     ,.mem_rev_data_i(proc_rev_data_li)
     ,.mem_rev_v_i(proc_rev_v_li)
     ,.mem_rev_ready_and_o(proc_rev_ready_and_lo)

     ,.mem_fwd_header_i(proc_fwd_header_li)
     ,.mem_fwd_data_i(proc_fwd_data_li)
     ,.mem_fwd_v_i(proc_fwd_v_li)
     ,.mem_fwd_ready_and_o(proc_fwd_ready_and_lo)

     ,.mem_rev_header_o(proc_rev_header_lo)
     ,.mem_rev_data_o(proc_rev_data_lo)
     ,.mem_rev_v_o(proc_rev_v_lo)
     ,.mem_rev_ready_and_i(proc_rev_ready_and_li)

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

  bp_nonsynth_dram
   #(.bp_params_p(bp_params_p)
     ,.num_dma_p(num_cce_p*l2_dmas_p)
     ,.preload_mem_p(preload_mem_p)
     ,.dram_type_p(dram_type_p)
     ,.mem_bytes_p(2**29)
     )
   dram
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dma_pkt_i(dma_pkt_lo)
     ,.dma_pkt_v_i(dma_pkt_v_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_li)

     ,.dma_data_o(dma_data_li)
     ,.dma_data_v_o(dma_data_v_li)
     ,.dma_data_ready_and_i(dma_data_ready_and_lo)

     ,.dma_data_i(dma_data_lo)
     ,.dma_data_v_i(dma_data_v_lo)
     ,.dma_data_yumi_o(dma_data_yumi_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );

  logic nbf_done_lo;
  wire [lce_id_width_p-1:0] io_lce_id_li = num_core_p*2+num_cacc_p+num_l2e_p+num_sacc_p+num_io_p;
  bp_nonsynth_nbf_loader
   #(.bp_params_p(bp_params_p))
   nbf_loader
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(io_lce_id_li)
     ,.did_i(host_did_li)

     ,.mem_fwd_header_o(proc_fwd_header_li)
     ,.mem_fwd_data_o(proc_fwd_data_li)
     ,.mem_fwd_v_o(proc_fwd_v_li)
     ,.mem_fwd_ready_and_i(proc_fwd_ready_and_lo)

     // NOTE: IO response ready_o is always high - acts as sink
     ,.mem_rev_header_i(proc_rev_header_lo)
     ,.mem_rev_data_i(proc_rev_data_lo)
     ,.mem_rev_v_i(proc_rev_v_lo)
     ,.mem_rev_ready_and_o(proc_rev_ready_and_li)

     ,.done_o(nbf_done_lo)
     );

  logic [num_core_p-1:0] finish_lo;
  logic cosim_en_lo;
  logic icache_trace_en_lo;
  logic dcache_trace_en_lo;
  logic lce_trace_en_lo;
  logic cce_trace_en_lo;
  logic dram_trace_en_lo;
  logic vm_trace_en_lo;
  logic cmt_trace_en_lo;
  logic core_profile_en_lo;
  logic pc_gen_trace_en_lo;
  logic pc_profile_en_lo;
  logic branch_profile_en_lo;
  logic dev_trace_en_lo;
  bp_nonsynth_host
   #(.bp_params_p(bp_params_p)
     ,.icache_trace_p(icache_trace_p)
     ,.dcache_trace_p(dcache_trace_p)
     ,.lce_trace_p(lce_trace_p)
     ,.cce_trace_p(cce_trace_p)
     ,.dram_trace_p(dram_trace_p)
     ,.vm_trace_p(vm_trace_p)
     ,.cmt_trace_p(cmt_trace_p)
     ,.core_profile_p(core_profile_p)
     ,.pc_gen_trace_p(pc_gen_trace_p)
     ,.pc_profile_p(pc_profile_p)
     ,.br_profile_p(br_profile_p)
     ,.cosim_p(cosim_p)
     ,.dev_trace_p(dev_trace_p)
     )
   host
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // data width = dword_width_gp on mem_fwd/rev ports
     ,.mem_fwd_header_i(proc_fwd_header_lo)
     ,.mem_fwd_data_i(proc_fwd_data_lo)
     ,.mem_fwd_v_i(proc_fwd_v_lo)
     ,.mem_fwd_ready_and_o(proc_fwd_ready_and_li)

     ,.mem_rev_header_o(proc_rev_header_li)
     ,.mem_rev_data_o(proc_rev_data_li)
     ,.mem_rev_v_o(proc_rev_v_li)
     ,.mem_rev_ready_and_i(proc_rev_ready_and_lo)

     ,.icache_trace_en_o(icache_trace_en_lo)
     ,.dcache_trace_en_o(dcache_trace_en_lo)
     ,.lce_trace_en_o(lce_trace_en_lo)
     ,.cce_trace_en_o(cce_trace_en_lo)
     ,.dram_trace_en_o(dram_trace_en_lo)
     ,.vm_trace_en_o(vm_trace_en_lo)
     ,.cmt_trace_en_o(cmt_trace_en_lo)
     ,.core_profile_en_o(core_profile_en_lo)
     ,.pc_gen_trace_en_o(pc_gen_trace_en_lo)
     ,.branch_profile_en_o(branch_profile_en_lo)
     ,.pc_profile_en_o(pc_profile_en_lo)
     ,.cosim_en_o(cosim_en_lo)
     ,.dev_trace_en_o(dev_trace_en_lo)
     ,.finish_o(finish_lo)
     );

  if (no_bind_p == 0)
    begin : do_bind
      bind bp_be_top
        bp_nonsynth_perf
         #(.bp_params_p(bp_params_p))
         perf
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)
           ,.warmup_instr_i(testbench.warmup_instr_p)

           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.commit_v_i(calculator.commit_pkt_cast_o.instret)
           ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
           );

      bind bp_be_top
        bp_nonsynth_watchdog
         #(.bp_params_p(bp_params_p)
           ,.stall_cycles_p(100000)
           ,.halt_cycles_p(10000)
           ,.heartbeat_instr_p(10000)
           )
         watchdog
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)
           ,.wfi_i(director.is_wait)

           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.npc_i(calculator.pipe_sys.csr.apc_r)
           ,.instret_i(calculator.commit_pkt_cast_o.instret)
           );


      bind bp_be_top
        bp_nonsynth_cosim
         #(.bp_params_p(bp_params_p))
         cosim
          (.clk_i(clk_i)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           // We want to pass these values as parameters, but cannot in Verilator 4.025
           // Parameter-resolved constants must not use dotted references
           ,.cosim_en_i(testbench.cosim_en_lo)
           ,.trace_en_i(testbench.cmt_trace_en_lo)
           ,.checkpoint_i(testbench.checkpoint_p == 1)
           ,.num_core_i(testbench.num_core_p)
           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)
           ,.config_file_i(testbench.cosim_cfg_file_p)
           ,.instr_cap_i(testbench.cosim_instr_p)
           ,.memsize_i(testbench.cosim_memsize_p)
           ,.amo_en_i(testbench.amo_en_p == 1)
           ,.finish_i(&testbench.finish_lo)

           ,.decode_i(calculator.dispatch_pkt_cast_i.decode)

           ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
           ,.commit_pkt_i(calculator.commit_pkt_cast_o)

           ,.priv_mode_i(calculator.pipe_sys.csr.priv_mode_r)
           ,.mstatus_i(calculator.pipe_sys.csr.mstatus_lo)
           ,.mcause_i(calculator.pipe_sys.csr.mcause_lo)
           ,.scause_i(calculator.pipe_sys.csr.scause_lo)

           ,.ird_w_v_i(scheduler.iwb_pkt_cast_i.ird_w_v)
           ,.ird_addr_i(scheduler.iwb_pkt_cast_i.rd_addr)
           ,.ird_data_i(scheduler.iwb_pkt_cast_i.rd_data)

           ,.frd_w_v_i(scheduler.fwb_pkt_cast_i.frd_w_v)
           ,.frd_addr_i(scheduler.fwb_pkt_cast_i.rd_addr)
           ,.frd_data_i(scheduler.fwb_pkt_cast_i.rd_data)

           ,.cache_req_yumi_i(calculator.pipe_mem.dcache.cache_req_yumi_i)
           ,.cache_req_nonblocking_i(calculator.pipe_mem.dcache.nonblocking_req)
           ,.cache_req_complete_i(calculator.pipe_mem.dcache.complete_recv)

           ,.cosim_clk_i(testbench.cosim_clk_i)
           ,.cosim_reset_i(testbench.cosim_reset_i)
           );

      bind bp_fe_icache
        bp_fe_nonsynth_icache_tracer
         #(.bp_params_p(bp_params_p)
           ,.assoc_p(assoc_p)
           ,.sets_p(sets_p)
           ,.block_width_p(block_width_p)
           ,.fill_width_p(fill_width_p)
           ,.tag_width_p(tag_width_p)
           ,.id_width_p(id_width_p)
           )
         icache_tracer
          (.clk_i(clk_i & testbench.icache_trace_en_lo)
           ,.freeze_i(cfg_bus_cast_i.freeze)
           ,.mhartid_i(cfg_bus_cast_i.core_id)
           ,.*
           );

      bind bp_be_dcache
        bp_be_nonsynth_dcache_tracer
         #(.bp_params_p(bp_params_p)
           ,.assoc_p(assoc_p)
           ,.sets_p(sets_p)
           ,.block_width_p(block_width_p)
           ,.fill_width_p(fill_width_p)
           ,.tag_width_p(tag_width_p)
           ,.id_width_p(id_width_p)
           )
         dcache_tracer
          (.clk_i(clk_i & testbench.dcache_trace_en_lo)
           ,.freeze_i(cfg_bus_cast_i.freeze)
           ,.mhartid_i(cfg_bus_cast_i.core_id)
           ,.*
           );

      bind bp_core_minimal
        bp_nonsynth_vm_tracer
         #(.bp_params_p(bp_params_p))
         vm_tracer
          (.clk_i(clk_i & testbench.vm_trace_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.itlb_clear_i(fe.immu.tlb.fence_i)
           ,.itlb_fill_v_i(fe.immu.tlb.w_v_li)
           ,.itlb_fill_g_i(fe.immu.tlb.entry_cast_i.gigapage)
           ,.itlb_fill_m_i(fe.immu.tlb.entry_cast_i.megapage)
           ,.itlb_vtag_i(fe.immu.tlb.vtag_i)
           ,.itlb_entry_i(fe.immu.tlb.entry_i)
           ,.itlb_r_v_i(fe.immu.tlb.r_v_li)

           ,.dtlb_clear_i(be.calculator.pipe_mem.dmmu.tlb.fence_i)
           ,.dtlb_fill_v_i(be.calculator.pipe_mem.dmmu.tlb.w_v_li)
           ,.dtlb_fill_g_i(be.calculator.pipe_mem.dmmu.tlb.entry_cast_i.gigapage)
           ,.dtlb_fill_m_i(be.calculator.pipe_mem.dmmu.tlb.entry_cast_i.megapage)
           ,.dtlb_vtag_i(be.calculator.pipe_mem.dmmu.tlb.vtag_i)
           ,.dtlb_entry_i(be.calculator.pipe_mem.dmmu.tlb.entry_i)
           ,.dtlb_r_v_i(be.calculator.pipe_mem.dmmu.tlb.r_v_li)
           );

      bind bp_core_minimal
        bp_nonsynth_core_profiler
         #(.bp_params_p(bp_params_p))
          core_profiler
          (.clk_i(clk_i & testbench.core_profile_en_lo)
          ,.reset_i(reset_i)
          ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

          ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

          ,.fe_queue_ready_and_i(fe.fe_queue_ready_and_i)

          ,.br_ovr_i(fe.pc_gen.ovr_btaken | fe.pc_gen.ovr_jmp)
          ,.ret_ovr_i(fe.pc_gen.ovr_ret)
          ,.realigner_i(fe.if2_instr_v & ~fe.fetch_instr_v_lo)

          ,.icache_data_v_i(fe.icache.data_v_o)
          ,.icache_v_i(fe.icache.v_i)
          ,.icache_yumi_i(fe.icache.yumi_o)

          ,.fe_cmd_nonattaboy_i(be.director.fe_cmd_v_li)
          ,.fe_queue_empty_i(be.scheduler.issue_queue.empty)

          ,.mispredict_i(be.director.npc_mismatch_v)
          ,.dcache_miss_i(be.calculator.pipe_mem.dcache.busy_o)
          ,.control_haz_i(be.detector.control_haz_v)
          ,.data_haz_i(be.detector.data_haz_v)
          ,.aux_dep_i((be.detector.dep_status_r[0].aux_iwb_v
                     | be.detector.dep_status_r[0].aux_fwb_v
                     ) & be.detector.data_haz_v
                    )
          ,.load_dep_i((be.detector.dep_status_r[0].emem_iwb_v
                        | be.detector.dep_status_r[0].fmem_iwb_v
                        | be.detector.dep_status_r[1].fmem_iwb_v
                        | be.detector.dep_status_r[0].emem_fwb_v
                        | be.detector.dep_status_r[0].fmem_fwb_v
                        | be.detector.dep_status_r[1].fmem_fwb_v
                        ) & be.detector.data_haz_v
                       )
          ,.mul_dep_i((be.detector.dep_status_r[0].mul_iwb_v
                       | be.detector.dep_status_r[1].mul_iwb_v
                       | be.detector.dep_status_r[2].mul_iwb_v
                       ) & be.detector.data_haz_v
                      )
          ,.fma_dep_i((be.detector.dep_status_r[0].fma_fwb_v
                     | be.detector.dep_status_r[1].fma_fwb_v
                     | be.detector.dep_status_r[2].fma_fwb_v
                     | be.detector.dep_status_r[3].fma_fwb_v
                     ) & be.detector.data_haz_v
                    )
          ,.sb_iraw_dep_i((be.detector.irs1_sb_raw_haz_v
                         | be.detector.irs2_sb_raw_haz_v
                         ) & be.detector.data_haz_v
                        )
          ,.sb_fraw_dep_i((be.detector.frs1_sb_raw_haz_v
                         | be.detector.frs2_sb_raw_haz_v
                         | be.detector.frs3_sb_raw_haz_v
                         ) & be.detector.data_haz_v
                        )
          ,.sb_iwaw_dep_i(be.detector.ird_sb_waw_haz_v & be.detector.data_haz_v)
          ,.sb_fwaw_dep_i(be.detector.frd_sb_waw_haz_v & be.detector.data_haz_v)
          ,.struct_haz_i(be.detector.struct_haz_v | be.scheduler.late_wb_yumi_o)
          ,.idiv_haz_i(be.detector.idiv_busy_i & be.detector.issue_pkt_cast_i.decode.pipe_long_v)
          ,.fdiv_haz_i(be.detector.fdiv_busy_i & be.detector.issue_pkt_cast_i.decode.pipe_long_v)
          ,.ptw_busy_i(be.scheduler.ptw_busy_lo)

          ,.retire_pkt_i(be.calculator.pipe_sys.retire_pkt)
          ,.commit_pkt_i(be.calculator.pipe_sys.commit_pkt_cast_o)
          );

      bind bp_fe_top
        bp_fe_nonsynth_pc_gen_tracer
         #(.bp_params_p(bp_params_p))
         pc_gen_tracer
          (.clk_i(clk_i & testbench.pc_gen_trace_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(cfg_bus_cast_i.freeze)

           ,.mhartid_i(cfg_bus_cast_i.core_id)

           ,.state_resume_i(controller.is_resume)
           ,.state_wait_i(controller.is_wait)

           ,.icache_spec_i(icache_spec_v_lo)
           ,.access_fault_i(instr_access_fault_r)
           ,.page_fault_i(instr_page_fault_r)
           ,.itlb_miss_i(itlb_miss_r)

           ,.src_redirect_i(pc_gen.redirect_v_i)
           ,.src_override_ntaken_i(pc_gen.ovr_ntaken)
           ,.src_override_ras_i(pc_gen.ovr_ret)
           ,.src_override_branch_i(pc_gen.ovr_btaken | pc_gen.ovr_jmp)
           ,.src_btb_taken_branch_i(pc_gen.btb_taken)

           ,.if2_pc_i(pc_gen.pc_if2_r)
           ,.if2_v_i(if2_instr_v)

           ,.fetch_v_i(fe_queue_ready_and_i & fe_queue_v_o)
           ,.fetch_pc_i(fetch_pc_lo)
           ,.fetch_instr_i(fetch_instr_lo)
           ,.fetch_partial_i(fetch_partial_lo)
           );

      bind bp_be_top
        bp_nonsynth_pc_profiler
         #(.bp_params_p(bp_params_p))
         pc_profiler
          (.clk_i(clk_i & testbench.pc_profile_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

           ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

           ,.commit_pkt(calculator.commit_pkt_cast_o)
           );

      bind bp_be_top
        bp_nonsynth_branch_profiler
         #(.bp_params_p(bp_params_p))
         branch_profiler
          (.clk_i(clk_i & testbench.branch_profile_en_lo)
           ,.reset_i(reset_i)
           ,.freeze_i(director.cfg_bus_cast_i.freeze)

           ,.mhartid_i(director.cfg_bus_cast_i.core_id)

           ,.fe_cmd_o(director.fe_cmd_o)
           ,.fe_cmd_yumi_i(director.fe_cmd_yumi_i)

           ,.commit_v_i(calculator.commit_pkt_cast_o.instret)
           );

      bind bp_me_clint_slice
        bp_me_nonsynth_dev_tracer
         #(.bp_params_p(bp_params_p)
           ,.trace_file_p("clint")
           )
         clint_tracer
          (.clk_i(clk_i & testbench.dev_trace_en_lo)
           ,.reset_i(reset_i)
           ,.id_i(cfg_bus_cast_i.core_id)
           ,.freeze_i(cfg_bus_cast_i.freeze)

           ,.mem_fwd_header_i(mem_fwd_header_i)
           ,.mem_fwd_data_i(mem_fwd_data_i)
           ,.mem_fwd_v_i(mem_fwd_v_i)
           ,.mem_fwd_ready_and_i(mem_fwd_ready_and_o)

           ,.mem_rev_header_i(mem_rev_header_o)
           ,.mem_rev_data_i(mem_rev_data_o)
           ,.mem_rev_v_i(mem_rev_v_o)
           ,.mem_rev_ready_and_i(mem_rev_ready_and_i)
           );

      if (cce_type_p != e_cce_uce)
        begin
          bind bp_cce_wrapper
            bp_me_nonsynth_cce_tracer
             #(.bp_params_p(bp_params_p))
             cce_tracer
              (.clk_i(clk_i & testbench.cce_trace_en_lo)
              ,.reset_i(reset_i)

              ,.cce_id_i(cfg_bus_cast_i.cce_id)

              // LCE-CCE Interface
              // BedRock Burst protocol: ready&valid
              ,.lce_req_header_i(lce_req_header_i)
              ,.lce_req_data_i(lce_req_data_i)
              ,.lce_req_v_i(lce_req_v_i)
              ,.lce_req_ready_and_i(lce_req_ready_and_o)

              ,.lce_cmd_header_i(lce_cmd_header_o)
              ,.lce_cmd_data_i(lce_cmd_data_o)
              ,.lce_cmd_v_i(lce_cmd_v_o)
              ,.lce_cmd_ready_and_i(lce_cmd_ready_and_i)

              ,.lce_resp_header_i(lce_resp_header_i)
              ,.lce_resp_data_i(lce_resp_data_i)
              ,.lce_resp_v_i(lce_resp_v_i)
              ,.lce_resp_ready_and_i(lce_resp_ready_and_o)

              // CCE-MEM Interface
              // BedRock Stream protocol: ready&valid
              ,.mem_rev_header_i(mem_rev_header_i)
              ,.mem_rev_data_i(mem_rev_data_i)
              ,.mem_rev_v_i(mem_rev_v_i)
              ,.mem_rev_ready_and_i(mem_rev_ready_and_o)

              ,.mem_fwd_header_i(mem_fwd_header_o)
              ,.mem_fwd_data_i(mem_fwd_data_o)
              ,.mem_fwd_v_i(mem_fwd_v_o)
              ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)
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
              (.clk_i(clk_i & testbench.lce_trace_en_lo)
              ,.reset_i(reset_i)

              ,.lce_id_i(lce_id_i)

              ,.lce_req_header_i(lce_req_header_o)
              ,.lce_req_data_i(lce_req_data_o)
              ,.lce_req_v_i(lce_req_v_o)
              ,.lce_req_ready_and_i(lce_req_ready_and_i)

              ,.lce_cmd_header_i(lce_cmd_header_i)
              ,.lce_cmd_data_i(lce_cmd_data_i)
              ,.lce_cmd_v_i(lce_cmd_v_i)
              ,.lce_cmd_ready_and_i(lce_cmd_ready_and_o)

              ,.lce_fill_header_i(lce_fill_header_i)
              ,.lce_fill_data_i(lce_fill_data_i)
              ,.lce_fill_v_i(lce_fill_v_i)
              ,.lce_fill_ready_and_i(lce_fill_ready_and_o)

              ,.lce_fill_o_header_i(lce_fill_header_o)
              ,.lce_fill_o_data_i(lce_fill_data_o)
              ,.lce_fill_o_v_i(lce_fill_v_o)
              ,.lce_fill_o_ready_and_i(lce_fill_ready_and_i)

              ,.lce_resp_header_i(lce_resp_header_o)
              ,.lce_resp_data_i(lce_resp_data_o)
              ,.lce_resp_v_i(lce_resp_v_o)
              ,.lce_resp_ready_and_i(lce_resp_ready_and_i)

              ,.cache_req_last_i(cache_req_last_o)
              );

          bind bp_cce_pending_bits
            bp_me_nonsynth_cce_pending_tracer
              #(.num_way_groups_p(num_way_groups_p)
                ,.cce_id_width_p(cce_id_width_p)
                ,.width_p(width_p)
                ,.paddr_width_p(paddr_width_p)
                )
              cce_pending_tracer
              (.clk_i(clk_i & testbench.cce_trace_en_lo)
              ,.reset_i(reset_i)
              ,.cce_id_i(cce_id_i)
              ,.pending_bits_i(pending_bits_r)
              ,.w_v_i(w_v_i)
              ,.w_wg_i(w_wg)
              ,.w_addr_i(w_addr_i)
              ,.pending_i(pending_i)
              ,.clear_i(clear_i)
              );

          // CCE instruction tracer
          // this is connected to the instruction registered in the EX stage
          if (cce_type_p == e_cce_ucode) begin
            bind bp_cce
              bp_me_nonsynth_cce_inst_tracer
                #(.bp_params_p(bp_params_p)
                  )
                cce_inst_tracer
                (.clk_i(clk_i & testbench.cce_trace_en_lo)
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
                (.clk_i(clk_i & testbench.cce_trace_en_lo)
                 ,.reset_i(reset_i)
                 ,.cce_id_i(cfg_bus_cast_i.cce_id)
                 ,.req_start_i(req_start)
                 ,.req_end_i(req_end)
                 ,.lce_req_header_i(fsm_req_header_li)
                 ,.cmd_send_i(fsm_cmd_v_lo)
                 ,.lce_cmd_header_i(fsm_cmd_header_lo)
                 ,.resp_receive_i(fsm_resp_yumi_lo)
                 ,.lce_resp_header_i(fsm_resp_header_li)
                 ,.mem_rev_receive_i(fsm_rev_yumi_lo & fsm_rev_last_li)
                 ,.mem_rev_squash_i(fsm_rev_yumi_lo & fsm_rev_last_li & spec_bits_lo.squash)
                 ,.mem_rev_header_i(fsm_rev_header_li)
                 ,.mem_fwd_send_i(fsm_fwd_v_lo & fsm_fwd_new_lo)
                 ,.mem_fwd_header_i(fsm_fwd_header_lo)
                 );
          end else if (cce_type_p == e_cce_fsm) begin
            bind bp_cce_fsm
              bp_me_nonsynth_cce_perf
                #(.bp_params_p(bp_params_p))
                cce_perf
                (.clk_i(clk_i & testbench.cce_trace_en_lo)
                 ,.reset_i(reset_i)
                 ,.cce_id_i(cfg_bus_cast_i.cce_id)
                 ,.req_start_i(lce_req_v_i & (state_r == e_ready))
                 ,.req_end_i(state_r == e_ready)
                 ,.lce_req_header_i(fsm_req_header_li)
                 ,.cmd_send_i(fsm_cmd_v_lo)
                 ,.lce_cmd_header_i(fsm_cmd_header_lo)
                 ,.resp_receive_i(fsm_resp_yumi_lo)
                 ,.lce_resp_header_i(fsm_resp_header_li)
                 ,.mem_rev_receive_i(fsm_rev_yumi_lo & fsm_rev_last_li)
                 ,.mem_rev_squash_i(fsm_rev_yumi_lo & spec_bits_lo.squash & fsm_rev_last_li)
                 ,.mem_rev_header_i(fsm_rev_header_li)
                 ,.mem_fwd_send_i(fsm_fwd_v_lo & fsm_fwd_new_lo)
                 ,.mem_fwd_header_i(fsm_fwd_header_lo)
                 );
          end
        end
    end

  bp_nonsynth_if_verif
   #(.bp_params_p(bp_params_p))
   if_verif
    ();

  if (dram_type_p == "axi" && (num_cce_p*l2_dmas_p) > 16)
    $error("AXI memory does not support >16 caches without increasing bsg_round_robin_arb size");

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
