module wrapper
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   , parameter mem_zero_p         = 1
   , parameter mem_load_p         = preload_mem_p
   , parameter mem_file_p         = "prog.mem"
   , parameter mem_cap_in_bytes_p = 2**25
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

  `declare_bp_proc_params(bp_params_p)

  // I-Cache Widths
  `declare_bp_fe_tag_widths(lce_assoc_p, lce_sets_p, lce_id_width_p,
       cce_id_width_p, dword_width_p, paddr_width_p)
  `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p,
       lce_sets_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  
  // LCE-CCE Interface Widths
  `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p,
       paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  
  // CCE-MEM Interface Widths
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p,
      lce_id_width_p, lce_assoc_p)
  
  , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
  , localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
  , localparam way_id_width_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
  , localparam block_size_in_words_lp=lce_assoc_p
  , localparam data_mask_width_lp=(dword_width_p>>3)
  , localparam ptag_width_lp = (paddr_width_p-bp_page_offset_width_gp)
  , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p+ptag_width_lp) // TODO: Change width
  , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
  , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
  , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_p)
  , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
  , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)
  , localparam bp_be_dcache_stat_width_lp=`bp_be_dcache_stat_info_width(lce_assoc_p)
  
  )
  ( input                             clk_i
  , input                             reset_i

  , input [cfg_bus_width_lp-1:0]      cfg_bus_i
  
  , input [tr_ring_width_lp-1:0] tr_pkt_i
  , input tr_pkt_v_i
  , output logic tr_pkt_yumi_o

  , input tr_pkt_ready_i
  , output logic tr_pkt_v_o
  , output logic [tr_ring_width_lp-1:0] tr_pkt_o
  );

  logic [ptag_width_lp-1:0] ptag_li;
  assign {vaddr_i, ptag_li} = tr_pkt_i[0+:(vaddr_width_p+ptag_width_lp)];
  logic rolly_ready_lo;
  assign tr_pkt_yumi_o = tr_pkt_v_i & rolly_ready_lo;

  logic [ptag_width_lp-1:0] rolly_ptag_lo;
  logic rolly_v_lo;
  logic rolly_yumi_li;
  logic icache_ready_lo;
  assign rolly_yumi_li = rolly_v_lo & icache_ready_lo;

  logic icache_miss_lo;

  // outputs from icache
  logic icache_data_v_lo;
  logic [instr_width_p-1:0] icache_data_lo;

  bsg_fifo_1r1w_rolly
   #(.width_p(vaddr_width_p+ptag_width_lp)
    ,.els_p(8)
    )
    rolly_icache (
     .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clr_v_i(1'b0)
     ,.deq_v_i(icache_data_v_lo)
     ,.roll_v_i(icache_miss_lo)

     ,.data_i({ptag_li, vaddr_i})
     ,.v_i(tr_pkt_v_i)
     ,.ready_o(rolly_ready_lo)

     ,.data_o({rolly_ptag_lo, rolly_vaddr_lo})
     ,.v_o(rolly_v_lo)
     ,.yumi_i(rolly_yumi_li)
    )

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

  bp_cce_mem_msg_s proc_mem_cmd_lo;
  logic proc_mem_cmd_v_lo, proc_mem_cmd_yumi_li;
  bp_cce_mem_msg_s proc_mem_resp_li;
  logic proc_mem_resp_v_li, proc_mem_resp_ready_lo;

  icache_lce_cce
   #(.bp_params_p(bp_params_p))
   dut
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)
     
     ,.vaddr_i(rolly_vaddr_lo)
     ,.vaddr_v_i(rolly_v_lo)
     ,.fencei_v_i(fencei_v_i)
     ,.vaddr_ready_o(icache_ready_lo)
     
     ,.ptag_i(rolly_ptag_lo)
     ,.ptag_v_i(rolly_v_lo)
     ,.uncached_i(icache_ptag_li[ptag_width_lp-1])
     ,.poison_i(icache_miss_lo)

     ,.data_o(icache_data_lo)
     ,.data_v_o(icache_data_v_lo)
     ,.miss_o(icache_miss_lo)

     ,.mem_resp_i(proc_mem_resp_li)
     ,.mem_resp_v_i(proc_mem_resp_v_li)
     ,.mem_resp_ready_o(proc_mem_resp_ready_lo)

     ,.mem_cmd_o(proc_mem_cmd_lo)
     ,.mem_cmd_v_o(proc_mem_cmd_v_lo)
     ,.mem_cmd_yumi_i(proc_mem_cmd_yumi_li)
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
   
     ,.mem_cmd_i(proc_mem_cmd_lo)
     ,.mem_cmd_v_i(proc_mem_cmd_v_lo)
     ,.mem_cmd_yumi_o(proc_mem_cmd_yumi_li)
   
     ,.mem_resp_o(proc_mem_resp_li)
     ,.mem_resp_v_o(proc_mem_resp_v_li)
     ,.mem_resp_ready_i(proc_mem_resp_ready_lo)
    );

  assign tr_pkt_o = {(tr_ring_width_lp-instr_width_p){1'b0}, icache_data_lo};
  assign tr_pkt_v_o = icache_data_v_lo;

endmodule
