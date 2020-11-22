/**
  *
  * testbench.v
  *
  */

`include "bsg_noc_links.vh"

module testbench
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   // TRACE enable parameters
   , parameter icache_trace_p              = 0
   , parameter dcache_trace_p              = 0
   , parameter lce_trace_p                 = 0
   , parameter cce_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter vm_trace_p                  = 0
   , parameter cmt_trace_p                 = 0
   , parameter core_profile_p              = 0
   , parameter pc_profile_p                = 0
   , parameter br_profile_p                = 0
   , parameter cosim_p                     = 0

   // COSIM parameters 
   , parameter checkpoint_p                = 0
   , parameter cosim_memsize_p             = 0
   , parameter cosim_cfg_file_p            = "prog.cfg"
   , parameter cosim_instr_p               = 0
   , parameter warmup_instr_p              = 0

   // DRAM parameters
   , parameter preload_mem_p               = 0
   , parameter use_ddr_p                   = 0
   , parameter use_dramsim3_p              = 0
   , parameter dram_fixed_latency_p        = 0
   , parameter [paddr_width_p-1:0] mem_offset_p = dram_base_addr_gp
   , parameter mem_cap_in_bytes_p = 2**27
   , parameter mem_file_p         = "prog.mem"
   )
  (input clk_i
   , input reset_i
   , input dram_clk_i
   , input dram_reset_i
   );

  import "DPI-C" context function bit get_finish(int hartid);
  export "DPI-C" function get_dram_period;
  export "DPI-C" function get_sim_period;
  
  function int get_dram_period();
    return (`dram_pkg::tck_ps);
  endfunction
  
  function int get_sim_period();
    return (`BP_SIM_CLK_PERIOD);
  endfunction
  
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  
  bp_bedrock_cce_mem_msg_s proc_mem_cmd_lo;
  logic proc_mem_cmd_v_lo, proc_mem_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s proc_mem_resp_li;
  logic proc_mem_resp_v_li, proc_mem_resp_yumi_lo;
  
  bp_bedrock_cce_mem_msg_s proc_io_cmd_lo;
  logic proc_io_cmd_v_lo, proc_io_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s proc_io_resp_li;
  logic proc_io_resp_v_li, proc_io_resp_yumi_lo;
  
  bp_bedrock_cce_mem_msg_s io_cmd_lo;
  logic io_cmd_v_lo, io_cmd_ready_li;
  bp_bedrock_cce_mem_msg_s io_resp_li;
  logic io_resp_v_li, io_resp_yumi_lo;
  
  bp_bedrock_cce_mem_msg_s load_cmd_lo;
  logic load_cmd_v_lo, load_cmd_yumi_li;
  bp_bedrock_cce_mem_msg_s load_resp_li;
  logic load_resp_v_li, load_resp_ready_lo;


  wrapper
   #(.bp_params_p(bp_params_p))
   wrapper
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.io_cmd_o(proc_io_cmd_lo)
     ,.io_cmd_v_o(proc_io_cmd_v_lo)
     ,.io_cmd_ready_i(proc_io_cmd_ready_li)
  
     ,.io_resp_i(proc_io_resp_li)
     ,.io_resp_v_i(proc_io_resp_v_li)
     ,.io_resp_yumi_o(proc_io_resp_yumi_lo)
  
     ,.io_cmd_i(load_cmd_lo)
     ,.io_cmd_v_i(load_cmd_v_lo)
     ,.io_cmd_yumi_o(load_cmd_yumi_li)
  
     ,.io_resp_o(load_resp_li)
     ,.io_resp_v_o(load_resp_v_li)
     ,.io_resp_ready_i(load_resp_ready_lo)
  
     ,.mem_cmd_o(proc_mem_cmd_lo)
     ,.mem_cmd_v_o(proc_mem_cmd_v_lo)
     ,.mem_cmd_ready_i(proc_mem_cmd_ready_li)
  
     ,.mem_resp_i(proc_mem_resp_li)
     ,.mem_resp_v_i(proc_mem_resp_v_li)
     ,.mem_resp_yumi_o(proc_mem_resp_yumi_lo)
     );
  
  bp_mem
   #(.bp_params_p(bp_params_p)
     ,.mem_offset_p(mem_offset_p)
     ,.mem_load_p(preload_mem_p)
     ,.mem_file_p(mem_file_p)
     ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
     ,.use_ddr_p(use_ddr_p)
     ,.use_dramsim3_p(use_dramsim3_p)
     ,.dram_fixed_latency_p(dram_fixed_latency_p)
     )
   mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.mem_cmd_i(proc_mem_cmd_lo)
     ,.mem_cmd_v_i(proc_mem_cmd_ready_li & proc_mem_cmd_v_lo)
     ,.mem_cmd_ready_o(proc_mem_cmd_ready_li)
  
     ,.mem_resp_o(proc_mem_resp_li)
     ,.mem_resp_v_o(proc_mem_resp_v_li)
     ,.mem_resp_yumi_i(proc_mem_resp_yumi_lo)
  
     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );
  
  bp_nonsynth_nbf_loader
   #(.bp_params_p(bp_params_p))
   nbf_loader
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.lce_id_i(lce_id_width_p'('b10))
      
     ,.io_cmd_o(load_cmd_lo)
     ,.io_cmd_v_o(load_cmd_v_lo)
     ,.io_cmd_yumi_i(load_cmd_yumi_li)
  
     ,.io_resp_i(load_resp_li)
     ,.io_resp_v_i(load_resp_v_li)
     ,.io_resp_ready_o(load_resp_ready_lo)
     );
  
  logic cosim_en_lo;
  logic icache_trace_en_lo;
  logic dcache_trace_en_lo;
  logic lce_trace_en_lo;
  logic cce_trace_en_lo;
  logic dram_trace_en_lo;
  logic vm_trace_en_lo;
  logic cmt_trace_en_lo;
  logic core_profile_en_lo;
  logic pc_profile_en_lo;
  logic branch_profile_en_lo;
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
     ,.pc_profile_p(pc_profile_p)
     ,.br_profile_p(br_profile_p)
     ,.cosim_p(cosim_p)
     )
   host
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.io_cmd_i(proc_io_cmd_lo)
     ,.io_cmd_v_i(proc_io_cmd_v_lo & proc_io_cmd_ready_li)
     ,.io_cmd_ready_o(proc_io_cmd_ready_li)
  
     ,.io_resp_o(proc_io_resp_li)
     ,.io_resp_v_o(proc_io_resp_v_li)
     ,.io_resp_yumi_i(proc_io_resp_yumi_lo)

     ,.icache_trace_en_o(icache_trace_en_lo)
     ,.dcache_trace_en_o(dcache_trace_en_lo)
     ,.lce_trace_en_o(lce_trace_en_lo)
     ,.cce_trace_en_o(cce_trace_en_lo)
     ,.dram_trace_en_o(dram_trace_en_lo)
     ,.vm_trace_en_o(vm_trace_en_lo)
     ,.cmt_trace_en_o(cmt_trace_en_lo)
     ,.core_profile_en_o(core_profile_en_lo)
     ,.branch_profile_en_o(branch_profile_en_lo)
     ,.pc_profile_en_o(pc_profile_en_lo)
     ,.cosim_en_o(cosim_en_lo)
     );

  bind bp_be_top
    bp_nonsynth_perf
     #(.bp_params_p(bp_params_p))
     perf
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)
       ,.warmup_instr_i(testbench.warmup_instr_p)
  
       ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)
  
       ,.commit_v_i(calculator.commit_pkt.instret)
       ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
       );

  bind bp_be_top
    bp_nonsynth_watchdog
     #(.bp_params_p(bp_params_p)
       ,.timeout_cycles_p(100000)
       ,.heartbeat_instr_p(100000)
       )
     watchdog
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

       ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

       ,.npc_i(director.npc_r)
       ,.instret_i(calculator.commit_pkt.instret)
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
  
       ,.decode_i(calculator.reservation_n.decode)
  
       ,.commit_v_i(calculator.commit_pkt.instret)
       ,.commit_pc_i(calculator.commit_pkt.pc)
       ,.commit_instr_i(calculator.commit_pkt.instr)
  
       ,.ird_w_v_i(scheduler.iwb_pkt.ird_w_v)
       ,.ird_addr_i(scheduler.iwb_pkt.rd_addr)
       ,.ird_data_i(scheduler.iwb_pkt.rd_data)
  
       ,.frd_w_v_i(scheduler.fwb_pkt.frd_w_v)
       ,.frd_addr_i(scheduler.fwb_pkt.rd_addr)
       ,.frd_data_i(scheduler.fwb_pkt.rd_data)
  
       ,.trap_v_i(calculator.pipe_sys.csr.commit_pkt_cast_o.exception | calculator.pipe_sys.csr.commit_pkt_cast_o._interrupt)
       ,.cause_i((calculator.pipe_sys.csr.priv_mode_n == `PRIV_MODE_S)
                 ? calculator.pipe_sys.csr.scause_li
                 : calculator.pipe_sys.csr.mcause_li
                 )
       ,.is_debug_mode_i(calculator.pipe_sys.csr.is_debug_mode)
       );

  bind bp_be_dcache
    bp_nonsynth_cache_tracer
     #(.bp_params_p(bp_params_p)
      ,.assoc_p(dcache_assoc_p)
      ,.sets_p(dcache_sets_p)
      ,.block_width_p(dcache_block_width_p)
      ,.fill_width_p(dcache_fill_width_p)
      ,.trace_file_p("dcache"))
     dcache_tracer
      (.clk_i(clk_i & testbench.dcache_trace_en_lo)
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

       ,.cache_req_metadata_o(cache_req_metadata_o)
       ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
        
       ,.cache_req_complete_i(cache_req_complete_i)

       ,.v_o(early_v_o)
       ,.load_data(early_data_o[0+:65])
       ,.cache_miss_o('0)
       ,.wt_req(wt_req)
       ,.store_data(data_tv_r[0+:dword_width_p])

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

  bind bp_fe_icache
    bp_nonsynth_cache_tracer
     #(.bp_params_p(bp_params_p)
      ,.assoc_p(icache_assoc_p)
      ,.sets_p(icache_sets_p)
      ,.block_width_p(icache_block_width_p)
      ,.fill_width_p(icache_fill_width_p)
      ,.trace_file_p("icache"))
     icache_tracer
      (.clk_i(clk_i & testbench.icache_trace_en_lo)
       ,.reset_i(reset_i)

       ,.freeze_i(cfg_bus_cast_i.freeze)
       ,.mhartid_i(cfg_bus_cast_i.core_id)

       ,.v_tl_r(v_tl_r)

       ,.v_tv_r(v_tv_r)
       ,.addr_tv_r(addr_tv_r)
       ,.lr_miss_tv(1'b0)
       ,.sc_op_tv_r(1'b0)
       ,.sc_success(1'b0)

       ,.cache_req_v_o(cache_req_v_o)
       ,.cache_req_o(cache_req_o)

       ,.cache_req_metadata_o(cache_req_metadata_o)
       ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

       ,.cache_req_complete_i(cache_req_complete_i)

       ,.v_o(data_v_o)
       ,.load_data(65'(data_o))
       ,.cache_miss_o('0)
       ,.wt_req()
       ,.store_data(dword_width_p'(0))

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

  bind bp_core_minimal
    bp_nonsynth_vm_tracer
     #(.bp_params_p(bp_params_p))
     vm_tracer
      (.clk_i(clk_i & testbench.vm_trace_en_lo)
       ,.reset_i(reset_i)
       ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

       ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

       ,.itlb_clear_i(fe.itlb.flush_i)
       ,.itlb_fill_v_i(fe.itlb.v_i & fe.itlb.w_i)
       ,.itlb_vtag_i(fe.itlb.vtag_i)
       ,.itlb_entry_i(fe.itlb.entry_i)
       ,.itlb_cam_r_v_i(fe.itlb.cam.r_v_i)

       ,.dtlb_clear_i(be.calculator.pipe_mem.dtlb.flush_i)
       ,.dtlb_fill_v_i(be.calculator.pipe_mem.dtlb.v_i & be.calculator.pipe_mem.dtlb.w_i)
       ,.dtlb_vtag_i(be.calculator.pipe_mem.dtlb.vtag_i)
       ,.dtlb_entry_i(be.calculator.pipe_mem.dtlb.entry_i)
       ,.dtlb_cam_r_v_i(be.calculator.pipe_mem.dtlb.cam.r_v_i)
       );

  bind bp_core_minimal
    bp_nonsynth_core_profiler
     #(.bp_params_p(bp_params_p))
     core_profiler
      (.clk_i(clk_i & testbench.core_profile_en_lo)
       ,.reset_i(reset_i)
       ,.freeze_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

       ,.mhartid_i(be.calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

       ,.fe_wait_stall(fe.pc_gen.is_wait)
       ,.fe_queue_stall(~fe.pc_gen.fe_queue_ready_i)

       ,.itlb_miss(fe.itlb_miss_r)
       ,.icache_miss(~fe.icache.ready_o)
       ,.icache_rollback(fe.pc_gen.icache_miss)
       ,.icache_fence(fe.icache.fencei_req)
       ,.branch_override(fe.pc_gen.ovr_taken & ~fe.pc_gen.ovr_ret)
       ,.ret_override(fe.pc_gen.ovr_ret)

       ,.fe_cmd(fe.pc_gen.fe_cmd_yumi_o & ~fe.pc_gen.attaboy_v)
       ,.fe_cmd_fence(be.director.suppress_iss_o)

       ,.mispredict(be.director.npc_mismatch_v)

       ,.dtlb_miss(be.calculator.pipe_mem.dtlb_miss_v)
       ,.dcache_miss(~be.calculator.pipe_mem.dcache.ready_o)
       ,.dcache_rollback(be.scheduler.commit_pkt.rollback)
       ,.long_haz(be.detector.long_haz_v)
       ,.exception(be.director.commit_pkt.exception | be.director.commit_pkt.satp)
       ,.eret(be.director.commit_pkt.eret)
       ,._interrupt(be.director.commit_pkt._interrupt)
       ,.control_haz(be.detector.control_haz_v)
       ,.data_haz(be.detector.data_haz_v)
       ,.load_dep((be.detector.dep_status_r[0].emem_iwb_v
                   | be.detector.dep_status_r[0].fmem_iwb_v
                   | be.detector.dep_status_r[1].fmem_iwb_v
                   | be.detector.dep_status_r[0].emem_fwb_v
                   | be.detector.dep_status_r[0].fmem_fwb_v
                   | be.detector.dep_status_r[1].fmem_fwb_v
                   ) & be.detector.data_haz_v
                  )
       ,.mul_dep((be.detector.dep_status_r[0].mul_iwb_v
                  | be.detector.dep_status_r[1].mul_iwb_v
                  | be.detector.dep_status_r[2].mul_iwb_v
                  ) & be.detector.data_haz_v
                 )
       ,.struct_haz(be.detector.struct_haz_v)
       ,.reservation(be.calculator.reservation_n)
       ,.commit_pkt(be.calculator.commit_pkt)
       );

  bp_mem_nonsynth_tracer
   #(.bp_params_p(bp_params_p))
   bp_mem_tracer
    (.clk_i(clk_i & testbench.dram_trace_en_lo)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(proc_mem_cmd_lo)
     ,.mem_cmd_v_i(proc_mem_cmd_v_lo & proc_mem_cmd_ready_li)
     ,.mem_cmd_ready_i(proc_mem_cmd_ready_li)

     ,.mem_resp_i(proc_mem_resp_li)
     ,.mem_resp_v_i(proc_mem_resp_v_li)
     ,.mem_resp_yumi_i(proc_mem_resp_yumi_lo)
     );

  bind bp_be_top
    bp_nonsynth_pc_profiler
     #(.bp_params_p(bp_params_p))
     pc_profiler
      (.clk_i(clk_i & testbench.pc_profile_en_lo)
       ,.reset_i(reset_i)
       ,.freeze_i(calculator.pipe_sys.csr.cfg_bus_cast_i.freeze)

       ,.mhartid_i(calculator.pipe_sys.csr.cfg_bus_cast_i.core_id)

       ,.commit_pkt(calculator.commit_pkt)
       );

  bind bp_be_top
    bp_nonsynth_branch_profiler
     #(.bp_params_p(bp_params_p))
     branch_profiler
      (.clk_i(clk_i & testbench.branch_profile_en_lo)
       ,.reset_i(reset_i)
       ,.freeze_i(detector.cfg_bus_cast_i.freeze)

       ,.mhartid_i(detector.cfg_bus_cast_i.core_id)

       ,.fe_cmd_o(director.fe_cmd_o)
       ,.fe_cmd_yumi_i(director.fe_cmd_yumi_i)

       ,.commit_v_i(calculator.commit_pkt.instret)
       );

  if (multicore_p)
    begin
      bind bp_cce_wrapper
        bp_me_nonsynth_cce_tracer
         #(.bp_params_p(bp_params_p))
         cce_tracer
          (.clk_i(clk_i & testbench.cce_trace_en_lo)
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

      bind bp_lce
        bp_me_nonsynth_lce_tracer
          #(.bp_params_p(bp_params_p)
            ,.sets_p(sets_p)
            ,.assoc_p(assoc_p)
            ,.block_width_p(block_width_p)
            )
          lce_tracer
          (.clk_i(clk_i & testbench.lce_trace_en_lo)
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
    end

  bp_nonsynth_if_verif
   #(.bp_params_p(bp_params_p))
   if_verif
    ();

endmodule
