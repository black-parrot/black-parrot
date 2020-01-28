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
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   // Tracing parameters
   , parameter calc_trace_p                = 0
   , parameter cce_trace_p                 = 0
   , parameter cmt_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter npc_trace_p                 = 0
   , parameter dcache_trace_p              = 0
   , parameter vm_trace_p                  = 0
   , parameter preload_mem_p               = 0
   , parameter load_nbf_p                  = 0
   , parameter skip_init_p                 = 0

   , parameter mem_zero_p         = 1
   , parameter mem_file_p         = "prog.mem"
   , parameter mem_cap_in_bytes_p = 2**20
   , parameter [paddr_width_p-1:0] mem_offset_p = paddr_width_p'(32'h8000_0000)

   // Number of elements in the fake BlackParrot memory
   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 1
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = 15

   , parameter dram_clock_period_in_ps_p = 1000
   , parameter dram_cfg_p                = "dram_ch.ini"
   , parameter dram_sys_cfg_p            = "dram_sys.ini"
   , parameter dram_capacity_p           = 16384
   )
  (input clk_i
   , input reset_i
   );

`declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

bp_io_noc_ral_link_s [E:P] cmd_link_li, cmd_link_lo;
bp_io_noc_ral_link_s [E:P] resp_link_li, resp_link_lo;

bp_cce_mem_msg_s dram_cmd_li;
logic            dram_cmd_v_li, dram_cmd_yumi_lo;
bp_cce_mem_msg_s dram_resp_lo;
logic            dram_resp_v_lo, dram_resp_ready_li;

bp_io_noc_ral_link_s proc_cmd_link_li, proc_cmd_link_lo;
bp_io_noc_ral_link_s proc_resp_link_li, proc_resp_link_lo;

bp_mem_noc_ral_link_s dram_cmd_link_lo, dram_resp_link_li;

bp_cce_mem_msg_s       host_cmd_li;
logic                  host_cmd_v_li, host_cmd_yumi_lo;
bp_cce_mem_msg_s       host_resp_lo;
logic                  host_resp_v_lo, host_resp_ready_li;

bp_cce_mem_msg_s       load_cmd_lo;
logic                  load_cmd_v_lo, load_cmd_ready_li;
bp_cce_mem_msg_s       load_resp_li;
logic                  load_resp_v_li, load_resp_yumi_lo;

bp_cce_mem_msg_s       cfg_cmd_lo;
logic                  cfg_cmd_v_lo, cfg_cmd_ready_li;
bp_cce_mem_msg_s       cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

bp_cce_mem_msg_s       nbf_cmd_lo;
logic                  nbf_cmd_v_lo, nbf_cmd_ready_li;
bp_cce_mem_msg_s       nbf_resp_li;
logic                  nbf_resp_v_li, nbf_resp_ready_lo;

wire [io_noc_did_width_p-1:0] dram_did_li = '1;
wire [io_noc_did_width_p-1:0] proc_did_li = 1;

bp_io_noc_ral_link_s stub_cmd_link_li, stub_resp_link_li;
bp_io_noc_ral_link_s stub_cmd_link_lo, stub_resp_link_lo;
assign stub_cmd_link_li  = '0;
assign stub_resp_link_li = '0;

// Chip
wrapper
 #(.bp_params_p(bp_params_p))
 wrapper
  (.core_clk_i(clk_i)
   ,.core_reset_i(reset_i)
   
   ,.coh_clk_i(clk_i)
   ,.coh_reset_i(reset_i)

   ,.io_clk_i(clk_i)
   ,.io_reset_i(reset_i)

   ,.mem_clk_i(clk_i)
   ,.mem_reset_i(reset_i)

   ,.my_did_i(proc_did_li)

   ,.io_cmd_link_i({proc_cmd_link_li, stub_cmd_link_li})
   ,.io_cmd_link_o({proc_cmd_link_lo, stub_cmd_link_lo})

   ,.io_resp_link_i({proc_resp_link_li, stub_resp_link_li})
   ,.io_resp_link_o({proc_resp_link_lo, stub_resp_link_lo})

   ,.dram_cmd_link_o(dram_cmd_link_lo)
   ,.dram_resp_link_i(dram_resp_link_li)
   );

  bind bp_be_top
    bp_nonsynth_commit_tracer
     #(.bp_params_p(bp_params_p))
     commit_tracer
      (.clk_i(clk_i & (testbench.cmt_trace_p == 1))
       ,.reset_i(reset_i)
       ,.freeze_i(be_checker.scheduler.int_regfile.cfg_bus.freeze)

       ,.mhartid_i(be_checker.scheduler.int_regfile.cfg_bus.core_id)

       ,.commit_v_i(be_calculator.commit_pkt.instret)
       ,.commit_pc_i(be_calculator.commit_pkt.pc)
       ,.commit_instr_i(be_calculator.commit_pkt.instr)

       ,.rd_w_v_i(be_calculator.wb_pkt.rd_w_v)
       ,.rd_addr_i(be_calculator.wb_pkt.rd_addr)
       ,.rd_data_i(be_calculator.wb_pkt.rd_data)
       );

  bind bp_be_director
    bp_be_nonsynth_npc_tracer
     #(.bp_params_p(bp_params_p))
     npc_tracer
      (.clk_i(clk_i & (testbench.npc_trace_p == 1))
       ,.reset_i(reset_i)
       ,.freeze_i(be_checker.scheduler.int_regfile.cfg_bus.freeze)

       ,.mhartid_i(be_checker.scheduler.int_regfile.cfg_bus.core_id)

       ,.npc_w_v(npc_w_v)
       ,.npc_n(npc_n)
       ,.npc_r(npc_r)
       ,.expected_npc_o(expected_npc_o)

       ,.fe_cmd_i(fe_cmd)
       ,.fe_cmd_v(fe_cmd_v)

       ,.commit_pkt_i(commit_pkt)
       );

  bind bp_be_dcache
    bp_be_nonsynth_dcache_tracer
     #(.bp_params_p(bp_params_p))
     dcache_tracer
      (.clk_i(clk_i & (testbench.dcache_trace_p == 1))
       ,.reset_i(reset_i)
       ,.freeze_i(cfg_bus_cast_i.freeze)

       ,.mhartid_i(cfg_bus_cast_i.core_id)

       ,.v_tv_r(v_tv_r)
       ,.cache_miss_o(cache_miss_o)

       ,.paddr_tv_r(paddr_tv_r)
       ,.uncached_tv_r(uncached_tv_r)
       ,.load_op_tv_r(load_op_tv_r)
       ,.store_op_tv_r(store_op_tv_r)
       ,.lr_op_tv_r(lr_op_tv_r)
       ,.sc_op_tv_r(sc_op_tv_r)
       ,.store_data(data_tv_r)
       ,.load_data(data_o)
       );

  bind bp_be_top
    bp_be_nonsynth_calc_tracer
     #(.bp_params_p(bp_params_p))
     calc_tracer
       // Workaround for verilator binding by accident
       // TODO: Figure out why tracing is always enabled
      (.clk_i(clk_i & (testbench.calc_trace_p == 1))
       ,.reset_i(reset_i)
       ,.freeze_i(be_checker.scheduler.int_regfile.cfg_bus.freeze)
  
       ,.mhartid_i(be_checker.scheduler.int_regfile.cfg_bus.core_id)

       ,.issue_pkt_i(be_checker.scheduler.issue_pkt)
       ,.issue_pkt_v_i(be_checker.scheduler.fe_queue_yumi_o)
  
       ,.fe_nop_v_i(be_calculator.exc_stage_n[0].fe_nop_v)
       ,.be_nop_v_i(be_calculator.exc_stage_n[0].be_nop_v)
       ,.me_nop_v_i(be_calculator.exc_stage_n[0].me_nop_v)
       ,.dispatch_pkt_i(be_calculator.dispatch_pkt)
  
       ,.ex1_br_tgt_i(be_calculator.calc_status.ex1_npc)
       ,.ex1_btaken_i(be_calculator.pipe_int.btaken)
       ,.iwb_result_i(be_calculator.comp_stage_n[3])
       ,.fwb_result_i(be_calculator.comp_stage_n[4])
  
       ,.cmt_trace_exc_i(be_calculator.exc_stage_n[1+:5])
  
       ,.trap_v_i(be_mem.csr.trap_pkt_cast_o._interrupt | be_mem.csr.trap_pkt_cast_o.exception)
       ,.mtvec_i(be_mem.csr.mtvec_n)
       ,.mtval_i(be_mem.csr.mtval_n[0+:vaddr_width_p])
       ,.ret_v_i(be_mem.csr.trap_pkt_cast_o.eret)
       ,.mepc_i(be_mem.csr.mepc_n[0+:vaddr_width_p])
       ,.mcause_i(be_mem.csr.mcause_n)
  
       ,.priv_mode_i(be_mem.csr.priv_mode_n)
       ,.mpp_i(be_mem.csr.mstatus_n.mpp)
       );

  bind bp_core
    bp_be_nonsynth_vm_tracer
    #(.bp_params_p(bp_params_p))
    vm_tracer
      (.clk_i(clk_i & (testbench.vm_trace_p == 1))
       ,.reset_i(reset_i)
       ,.freeze_i(be.be_checker.scheduler.int_regfile.cfg_bus.freeze)

       ,.mhartid_i(be.be_checker.scheduler.int_regfile.cfg_bus.core_id)

       ,.itlb_clear_i(fe.mem.itlb.flush_i)
       ,.itlb_fill_v_i(fe.mem.itlb.v_i & fe.mem.itlb.w_i)
       ,.itlb_vtag_i(fe.mem.itlb.vtag_i)
       ,.itlb_entry_i(fe.mem.itlb.entry_i)

       ,.dtlb_clear_i(be.be_mem.dtlb.flush_i)
       ,.dtlb_fill_v_i(be.be_mem.dtlb.v_i & be.be_mem.dtlb.w_i)
       ,.dtlb_vtag_i(be.be_mem.dtlb.vtag_i)
       ,.dtlb_entry_i(be.be_mem.dtlb.entry_i)
       );

// We rely on this for termination, so don't gate behind parameter
bind bp_be_top
  bp_be_nonsynth_perf
   #(.bp_params_p(bp_params_p))
   perf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mhartid_i(be_checker.scheduler.int_regfile.cfg_bus.core_id)

     ,.fe_nop_i(be_calculator.exc_stage_r[2].fe_nop_v)
     ,.be_nop_i(be_calculator.exc_stage_r[2].be_nop_v)
     ,.me_nop_i(be_calculator.exc_stage_r[2].me_nop_v)
     ,.poison_i(be_calculator.exc_stage_r[2].poison_v)
     ,.roll_i(be_calculator.exc_stage_r[2].roll_v)
     ,.instr_cmt_i(be_calculator.commit_pkt.instret)

     ,.program_finish_i(testbench.program_finish)
     );

  bp_mem_nonsynth_tracer
   #(.bp_params_p(bp_params_p))
   bp_mem_tracer
    (.clk_i(clk_i & (testbench.dram_trace_p == 1))
     ,.reset_i(reset_i)

     ,.mem_cmd_i(dram_cmd_li)
     ,.mem_cmd_v_i(dram_cmd_v_li)
     ,.mem_cmd_yumi_i(dram_cmd_yumi_lo)

     ,.mem_resp_i(dram_resp_lo)
     ,.mem_resp_v_i(dram_resp_v_lo)
     ,.mem_resp_ready_i(dram_resp_ready_li)
     );

  bind bp_cce
    bp_cce_nonsynth_tracer
      #(.bp_params_p(bp_params_p))
      bp_cce_tracer
       (.clk_i(clk_i & (testbench.cce_trace_p == 1))
        ,.reset_i(reset_i)
        ,.freeze_i(bp_cce.cfg_bus_cast_i.freeze)
  
        ,.cce_id_i(bp_cce.cfg_bus_cast_i.cce_id)
  
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

wire [io_noc_cord_width_p-1:0] dst_cord_lo = 1;

bp_me_cce_to_mem_link_bidir
 #(.bp_params_p(bp_params_p)
   ,.num_outstanding_req_p(io_noc_max_credits_p)
   ,.flit_width_p(io_noc_flit_width_p)
   ,.cord_width_p(io_noc_cord_width_p)
   ,.cid_width_p(io_noc_cid_width_p)
   ,.len_width_p(io_noc_len_width_p)
   )
 host_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(load_cmd_lo)
   ,.mem_cmd_v_i(load_cmd_v_lo)
   ,.mem_cmd_ready_o(load_cmd_ready_li)

   ,.mem_resp_o(load_resp_li)
   ,.mem_resp_v_o(load_resp_v_li)
   ,.mem_resp_yumi_i(load_resp_yumi_lo)

   ,.my_cord_i(io_noc_cord_width_p'(dram_did_li))
   ,.my_cid_i('0)
   ,.dst_cord_i(dst_cord_lo)
   ,.dst_cid_i('0)

   ,.mem_cmd_o(host_cmd_li)
   ,.mem_cmd_v_o(host_cmd_v_li)
   ,.mem_cmd_yumi_i(host_cmd_yumi_lo)

   ,.mem_resp_i(host_resp_lo)
   ,.mem_resp_v_i(host_resp_v_lo)
   ,.mem_resp_ready_o(host_resp_ready_li)

   ,.cmd_link_i(proc_cmd_link_lo)
   ,.cmd_link_o(proc_cmd_link_li)
   ,.resp_link_i(proc_resp_link_lo)
   ,.resp_link_o(proc_resp_link_li)
   );

bp_me_cce_to_mem_link_client
 #(.bp_params_p(bp_params_p)
   ,.num_outstanding_req_p(mem_noc_max_credits_p)
   ,.flit_width_p(mem_noc_flit_width_p)
   ,.cord_width_p(mem_noc_cord_width_p)
   ,.cid_width_p(mem_noc_cid_width_p)
   ,.len_width_p(mem_noc_len_width_p)
   )
 dram_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_o(dram_cmd_li)
   ,.mem_cmd_v_o(dram_cmd_v_li)
   ,.mem_cmd_yumi_i(dram_cmd_yumi_lo)

   ,.mem_resp_i(dram_resp_lo)
   ,.mem_resp_v_i(dram_resp_v_lo)
   ,.mem_resp_ready_o(dram_resp_ready_li)

   ,.cmd_link_i(dram_cmd_link_lo)
   ,.resp_link_o(dram_resp_link_li)
   );

bp_mem
 #(.bp_params_p(bp_params_p)
   ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
   ,.mem_load_p(preload_mem_p)
   ,.mem_zero_p(mem_zero_p)
   ,.mem_file_p(mem_file_p)
   ,.mem_offset_p(mem_offset_p)
 
   ,.use_max_latency_p(use_max_latency_p)
   ,.use_random_latency_p(use_random_latency_p)
   ,.use_dramsim2_latency_p(use_dramsim2_latency_p)
   ,.max_latency_p(max_latency_p)
 
   ,.dram_clock_period_in_ps_p(dram_clock_period_in_ps_p)
   ,.dram_cfg_p(dram_cfg_p)
   ,.dram_sys_cfg_p(dram_sys_cfg_p)
   ,.dram_capacity_p(dram_capacity_p)
   )
 mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
 
   ,.mem_cmd_i(dram_cmd_li)
   ,.mem_cmd_v_i(dram_cmd_v_li)
   ,.mem_cmd_yumi_o(dram_cmd_yumi_lo)
 
   ,.mem_resp_o(dram_resp_lo)
   ,.mem_resp_v_o(dram_resp_v_lo)
   ,.mem_resp_ready_i(dram_resp_ready_li)
   );

logic [num_core_p-1:0] program_finish;
bp_nonsynth_host
 #(.bp_params_p(bp_params_p))
 host_mmio
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.io_cmd_i(host_cmd_li)
   ,.io_cmd_v_i(host_cmd_v_li)
   ,.io_cmd_yumi_o(host_cmd_yumi_lo)

   ,.io_resp_o(host_resp_lo)
   ,.io_resp_v_o(host_resp_v_lo)
   ,.io_resp_ready_i(host_resp_ready_li)

   ,.program_finish_o(program_finish)
   );

logic nbf_done_lo, cfg_done_lo;
if (load_nbf_p)
  begin : nbf
    bp_nonsynth_nbf_loader
     #(.bp_params_p(bp_params_p))
     nbf_loader
      (.clk_i(clk_i)
       ,.reset_i(reset_i | ~cfg_done_lo)

       ,.io_cmd_o(nbf_cmd_lo)
       ,.io_cmd_v_o(nbf_cmd_v_lo)
       ,.io_cmd_yumi_i(nbf_cmd_ready_li & nbf_cmd_v_lo)

       ,.io_resp_i(nbf_resp_li)
       ,.io_resp_v_i(nbf_resp_v_li)
       ,.io_resp_ready_o(nbf_resp_ready_lo)

       ,.done_o(nbf_done_lo)
       );
  end
else
  begin : no_preload
    assign nbf_done_lo = 1'b1;
    
    assign nbf_cmd_lo = '0;
    assign nbf_cmd_v_lo = '0;
    assign nbf_resp_ready_lo = '0;
  end

localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p);
bp_cce_mmio_cfg_loader
  #(.bp_params_p(bp_params_p)
    ,.inst_width_p(`bp_cce_inst_width)
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p(skip_init_p)
    ,.clear_freeze_p(!load_nbf_p)
    )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.io_cmd_o(cfg_cmd_lo)
   ,.io_cmd_v_o(cfg_cmd_v_lo)
   ,.io_cmd_yumi_i(cfg_cmd_ready_li & cfg_cmd_v_lo)
   
   ,.io_resp_i(cfg_resp_li)
   ,.io_resp_v_i(cfg_resp_v_li)
   ,.io_resp_ready_o(cfg_resp_ready_lo)
   
   ,.done_o(cfg_done_lo)
  );

// CFG and NBF are mutex, so we can just use fixed arbitration here
always_comb
  if (~cfg_done_lo)
    begin
      load_cmd_lo = cfg_cmd_lo;
      load_cmd_v_lo = load_cmd_ready_li & cfg_cmd_v_lo;

      nbf_cmd_ready_li = 1'b0;
      cfg_cmd_ready_li = load_cmd_ready_li;

      nbf_resp_li = '0;
      nbf_resp_v_li = 1'b0;

      cfg_resp_li = load_resp_li;
      cfg_resp_v_li = cfg_resp_ready_lo & load_resp_v_li;

      load_resp_yumi_lo = cfg_resp_v_li;
    end
  else
    begin
      load_cmd_lo = nbf_cmd_lo;
      load_cmd_v_lo = load_cmd_ready_li & nbf_cmd_v_lo;

      nbf_cmd_ready_li = load_cmd_ready_li;
      cfg_cmd_ready_li = 1'b0;

      nbf_resp_li = load_resp_li;
      nbf_resp_v_li = nbf_resp_ready_lo & load_resp_v_li;

      cfg_resp_li = '0;
      cfg_resp_v_li = 1'b0;

      load_resp_yumi_lo = nbf_resp_v_li;
    end

bp_nonsynth_if_verif
 #(.bp_params_p(bp_params_p))
 if_verif
  ();

endmodule

