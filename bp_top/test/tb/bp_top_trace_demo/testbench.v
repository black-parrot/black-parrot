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
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Tracing parameters
   , parameter calc_trace_p                = 0
   , parameter cce_trace_p                 = 0
   , parameter cmt_trace_p                 = 0
   , parameter dram_trace_p                = 0
   , parameter npc_trace_p                 = 0
   , parameter dcache_trace_p              = 0
   , parameter skip_init_p                 = 0

   , parameter mem_load_p         = 1
   , parameter mem_file_p         = "prog.mem"
   , parameter mem_cap_in_bytes_p = 2**20
   , parameter [paddr_width_p-1:0] mem_offset_p = paddr_width_p'(32'h8000_0000)

   // Number of elements in the fake BlackParrot memory
   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 1
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = 15

   , parameter dram_clock_period_in_ps_p = 1000
   , parameter dram_bp_params_p                = "dram_ch.ini"
   , parameter dram_sys_bp_params_p            = "dram_sys.ini"
   , parameter dram_capacity_p           = 16384
   )
  (input clk_i
   , input reset_i
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

bsg_ready_and_link_sif_s cmd_link_li, cmd_link_lo;
bsg_ready_and_link_sif_s resp_link_li, resp_link_lo;

bp_cce_mem_msg_s       mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;
bp_cce_mem_msg_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;

bp_cce_mem_msg_s       dram_resp_lo;
logic                  dram_resp_v_lo, dram_resp_ready_li;
bp_cce_mem_msg_s       dram_cmd_li;
logic                  dram_cmd_v_li, dram_cmd_yumi_lo;

bp_cce_mem_msg_s       host_resp_lo;
logic                  host_resp_v_lo, host_resp_ready_li;
bp_cce_mem_msg_s       host_cmd_li;
logic                  host_cmd_v_li, host_cmd_yumi_lo;

bp_cce_mem_msg_s       cfg_cmd_lo;
logic                  cfg_cmd_v_lo, cfg_cmd_ready_li;
bp_cce_mem_msg_s       cfg_resp_li;
logic                  cfg_resp_v_li, cfg_resp_ready_lo;

logic [mem_noc_cord_width_p-1:0] dram_cord_lo, clint_cord_lo, host_cord_lo;
logic [num_core_p-1:0][mem_noc_cord_width_p-1:0] tile_cord_lo;
logic [num_mem_p-1:0][mem_noc_cord_width_p-1:0] mem_cord_lo;

assign clint_cord_lo[0+:mem_noc_x_cord_width_p]                      = clint_x_pos_p;
assign clint_cord_lo[mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p] = '0;
assign dram_cord_lo[0+:mem_noc_x_cord_width_p]                      = mem_noc_x_dim_p+2;
assign dram_cord_lo[mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p] = '0;
assign host_cord_lo[0+:mem_noc_x_cord_width_p]                      = mem_noc_x_dim_p+2;
assign host_cord_lo[mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p] = '0;

for (genvar j = 0; j < mem_noc_y_dim_p; j++)
  begin : y
    for (genvar i = 0; i < mem_noc_x_dim_p; i++)
      begin : x
        localparam idx = j*mem_noc_x_dim_p + i;
        assign tile_cord_lo[idx][0+:mem_noc_x_cord_width_p] = i+1;
        assign tile_cord_lo[idx][mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p] = j+1;
      end
  end
for (genvar i = 0; i < num_mem_p; i++)
  begin : x
    assign mem_cord_lo[i][0+:mem_noc_x_cord_width_p] = i;
    assign mem_cord_lo[i][mem_noc_x_cord_width_p+:mem_noc_y_cord_width_p] = '0;
  end

// Chip
wrapper
 #(.bp_params_p(bp_params_p))
 wrapper
  (.core_clk_i(clk_i)
   ,.core_reset_i(reset_i)
   
   ,.coh_clk_i(clk_i)
   ,.coh_reset_i(reset_i)

   ,.mem_clk_i(clk_i)
   ,.mem_reset_i(reset_i)

   ,.mem_cord_i(mem_cord_lo)
   ,.tile_cord_i(tile_cord_lo)
   ,.dram_cord_i(dram_cord_lo)
   ,.clint_cord_i(clint_cord_lo)
   ,.host_cord_i(host_cord_lo)

   ,.prev_cmd_link_i('0)
   ,.prev_cmd_link_o()

   ,.prev_resp_link_i('0)
   ,.prev_resp_link_o()

   ,.next_cmd_link_i(cmd_link_lo)
   ,.next_cmd_link_o(cmd_link_li)

   ,.next_resp_link_i(resp_link_lo)
   ,.next_resp_link_o(resp_link_li)
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
     tracer
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

  bind bp_cce_top
    bp_cce_nonsynth_tracer
      #(.bp_params_p(bp_params_p))
      bp_cce_tracer
       (.clk_i(clk_i & (testbench.cce_trace_p == 1))
        ,.reset_i(reset_i)
        ,.freeze_i(bp_cce.inst_ram.cfg_bus_cast_i.freeze)
  
        ,.cce_id_i(bp_cce.inst_ram.cfg_bus_cast_i.cce_id)
  
        // To CCE
        ,.lce_req_i(lce_req_to_cce)
        ,.lce_req_v_i(lce_req_v_to_cce)
        ,.lce_req_yumi_i(lce_req_yumi_from_cce)
        ,.lce_resp_i(lce_resp_to_cce)
        ,.lce_resp_v_i(lce_resp_v_to_cce)
        ,.lce_resp_yumi_i(lce_resp_yumi_from_cce)
  
        // From CCE
        ,.lce_cmd_i(lce_cmd_o)
        ,.lce_cmd_v_i(lce_cmd_v_o)
        ,.lce_cmd_ready_i(lce_cmd_ready_i)
  
        // To CCE
        ,.mem_resp_i(mem_resp_to_cce)
        ,.mem_resp_v_i(mem_resp_v_to_cce)
        ,.mem_resp_yumi_i(mem_resp_yumi_from_cce)
  
        // From CCE
        ,.mem_cmd_i(mem_cmd_from_cce)
        ,.mem_cmd_v_i(mem_cmd_v_from_cce)
        ,.mem_cmd_ready_i(mem_cmd_ready_to_cce)
        );

wire [mem_noc_cord_width_p-1:0] cfg_cmd_core_lo = cfg_cmd_lo.addr[cfg_addr_width_p+:cfg_core_width_p];
wire [mem_noc_cord_width_p-1:0] dst_cord_lo = cfg_cmd_v_lo ? tile_cord_lo[cfg_cmd_core_lo] : '0;
wire [mem_noc_cid_width_p-1:0]  dst_cid_lo = mem_noc_cid_width_p'(1);

// DRAM + link 
bp_me_cce_to_wormhole_link_bidir
 #(.bp_params_p(bp_params_p))
  bidir_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(cfg_cmd_lo)
  ,.mem_cmd_v_i(cfg_cmd_ready_li & cfg_cmd_v_lo)
  ,.mem_cmd_ready_o(cfg_cmd_ready_li)

  ,.mem_resp_o(cfg_resp_li)
  ,.mem_resp_v_o(cfg_resp_v_li)
  ,.mem_resp_yumi_i(cfg_resp_ready_lo & cfg_resp_v_li)

  ,.mem_cmd_o(mem_cmd_lo)
  ,.mem_cmd_v_o(mem_cmd_v_lo)
  ,.mem_cmd_yumi_i(mem_cmd_yumi_li)

  ,.mem_resp_i(mem_resp_li)
  ,.mem_resp_v_i(mem_resp_v_li)
  ,.mem_resp_ready_o(mem_resp_ready_lo)

  ,.my_cord_i(dram_cord_lo)
  ,.my_cid_i(mem_noc_cid_width_p'(0))
  ,.dst_cord_i(dst_cord_lo)
  ,.dst_cid_i(dst_cid_lo)
     
  ,.cmd_link_i(cmd_link_li)
  ,.cmd_link_o(cmd_link_lo)

  ,.resp_link_i(resp_link_li)
  ,.resp_link_o(resp_link_lo)
  );

bp_mem
#(.bp_params_p(bp_params_p)
  ,.mem_cap_in_bytes_p(mem_cap_in_bytes_p)
  ,.mem_load_p(mem_load_p)
  ,.mem_file_p(mem_file_p)
  ,.mem_offset_p(mem_offset_p)

  ,.use_max_latency_p(use_max_latency_p)
  ,.use_random_latency_p(use_random_latency_p)
  ,.use_dramsim2_latency_p(use_dramsim2_latency_p)
  ,.max_latency_p(max_latency_p)

  ,.dram_clock_period_in_ps_p(dram_clock_period_in_ps_p)
  ,.dram_bp_params_p(dram_bp_params_p)
  ,.dram_sys_bp_params_p(dram_sys_bp_params_p)
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

   ,.mem_cmd_i(host_cmd_li)
   ,.mem_cmd_v_i(host_cmd_v_li)
   ,.mem_cmd_yumi_o(host_cmd_yumi_lo)

   ,.mem_resp_o(host_resp_lo)
   ,.mem_resp_v_o(host_resp_v_lo)
   ,.mem_resp_ready_i(host_resp_ready_li)

   ,.program_finish_o(program_finish)
   );

bp_nonsynth_if_verif
 #(.bp_params_p(bp_params_p))
 if_verif
  ();

// MMIO arbitration 
//   Should this be on its own I/O router?
logic req_outstanding_r;
bsg_dff_reset_en
 #(.width_p(1))
 req_outstanding_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(mem_cmd_yumi_li | mem_resp_v_li)

   ,.data_i(mem_cmd_yumi_li)
   ,.data_o(req_outstanding_r)
   );

wire host_cmd_not_dram      = mem_cmd_v_lo & (mem_cmd_lo.addr < dram_base_addr_gp);

assign host_cmd_li          = mem_cmd_lo;
assign host_cmd_v_li        = mem_cmd_v_lo & host_cmd_not_dram & ~req_outstanding_r;
assign dram_cmd_li          = mem_cmd_lo;
assign dram_cmd_v_li        = mem_cmd_v_lo & ~host_cmd_not_dram & ~req_outstanding_r;
assign mem_cmd_yumi_li      = host_cmd_not_dram 
                              ? host_cmd_yumi_lo 
                              : dram_cmd_yumi_lo;

assign mem_resp_li = host_resp_v_lo ? host_resp_lo : dram_resp_lo;
assign mem_resp_v_li = host_resp_v_lo | dram_resp_v_lo;
assign host_resp_ready_li = mem_resp_ready_lo;
assign dram_resp_ready_li = mem_resp_ready_lo;

localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p);
bp_cce_mmio_cfg_loader
  #(.bp_params_p(bp_params_p)
    ,.inst_width_p(`bp_cce_inst_width)
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p(skip_init_p)
  )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.mem_cmd_o(cfg_cmd_lo)
   ,.mem_cmd_v_o(cfg_cmd_v_lo)
   ,.mem_cmd_yumi_i(cfg_cmd_ready_li & cfg_cmd_v_lo)
   
   ,.mem_resp_i(cfg_resp_li)
   ,.mem_resp_v_i(cfg_resp_v_li)
   ,.mem_resp_ready_o(cfg_resp_ready_lo)
  );

endmodule

