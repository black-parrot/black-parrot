// UVM Top-Level Testbench for BP L1 ICache

`include "uvm_macros.svh"

`include "icache_uvm_if.sv"

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

//.......................................................
// UVM Top Testbench
//.......................................................
module testbench;
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  import uvm_pkg::*;
  import icache_uvm_params_pkg::*;
  import icache_uvm_tests_pkg::*;

  // Fill Interfaces
  logic data_mem_pkt_v_li, tag_mem_pkt_v_li, stat_mem_pkt_v_li;
  logic data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
  logic [icache_data_mem_pkt_width_lp-1:0] data_mem_pkt_li;
  logic [icache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_li;
  logic [icache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_li;
  logic [icache_block_width_p-1:0] data_mem_lo;
  logic [icache_tag_info_width_lp-1:0] tag_mem_lo;
  logic [icache_stat_info_width_lp-1:0] stat_mem_lo;

  //bits for clk and rst
  logic clk_i, reset_i;
  logic dram_clk_i, dram_reset_i;

  // Interface definitions
  input_icache_if   cache_input_if_h (clk_i, reset_i);
  tlb_icache_if     cache_tlb_if_h   (clk_i, reset_i);
  output_icache_if  cache_output_if_h(clk_i, reset_i);
  ce_icache_if      cache_ce_if_h    (clk_i, reset_i);
  ram_if            ram_if_h         (clk_i, reset_i);

  //I CACHE
  bp_fe_icache
   #(.bp_params_p(bp_params_p)
     ,.coherent_p(1'b0)
     ,.sets_p(icache_sets_p)
     ,.assoc_p(icache_assoc_p)
     ,.block_width_p(icache_block_width_p)
     ,.fill_width_p(icache_fill_width_p)
     )
   bp_fe_icache_dut
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

    // Unused except for tracers
     ,.cfg_bus_i()

    // Input Interface
     ,.icache_pkt_i(cache_input_if_h.icache_pkt_i)
     ,.v_i(cache_input_if_h.v_i) //rolly_yumi_li
     ,.ready_o(cache_input_if_h.ready_o) //icache_ready_lo
    
    // TLB and PMA Interface
     ,.ptag_i(cache_tlb_if_h.ptag_i) //rolly_ptag_r
     ,.ptag_v_i(cache_tlb_if_h.ptag_v_i) //ptag_v_r
     ,.ptag_uncached_i(cache_tlb_if_h.ptag_uncached_i) //uncached_r
     ,.ptag_nonidem_i(cache_tlb_if_h.ptag_nonidem_i) //nonidem_r
     ,.ptag_dram_i(cache_tlb_if_h.ptag_dram_i) //dram_r
     ,.poison_tl_i(1'b0)

    // Data Output Interface
     ,.data_o(cache_output_if_h.data_o)
     ,.data_v_o(cache_output_if_h.data_v_o)
     ,.miss_v_o(cache_output_if_h.miss_v_o)

    // Cache Engine Interface
     ,.cache_req_o(cache_ce_if_h.cache_req_o)
     ,.cache_req_v_o(cache_ce_if_h.cache_req_v_o)
     ,.cache_req_yumi_i(cache_ce_if_h.cache_req_yumi_i)
     ,.cache_req_busy_i(cache_ce_if_h.cache_req_busy_i)
     ,.cache_req_metadata_o(cache_ce_if_h.cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_ce_if_h.cache_req_metadata_v_o)
     ,.cache_req_critical_tag_i(cache_ce_if_h.cache_req_critical_tag_i)
     ,.cache_req_critical_data_i(cache_ce_if_h.cache_req_critical_data_i)
     ,.cache_req_complete_i(cache_ce_if_h.cache_req_complete_i)
     ,.cache_req_credits_full_i(cache_ce_if_h.cache_req_credits_full_i)
     ,.cache_req_credits_empty_i(cache_ce_if_h.cache_req_credits_empty_i)

     ,.data_mem_pkt_v_i(data_mem_pkt_v_li)
     ,.data_mem_pkt_i(data_mem_pkt_li)
     ,.data_mem_o(data_mem_lo)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo)

     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_li)
     ,.tag_mem_pkt_i(tag_mem_pkt_li)
     ,.tag_mem_o(tag_mem_lo)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo)

     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_li)
     ,.stat_mem_pkt_i(stat_mem_pkt_li)
     ,.stat_mem_o(stat_mem_lo)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo)
     );

  //UCE
  bp_uce
     #(.bp_params_p(bp_params_p)
       ,.uce_mem_data_width_p(l2_fill_width_p)
       ,.assoc_p(icache_assoc_p)
       ,.sets_p(icache_sets_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       )
     icache_uce
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.lce_id_i('0)

       ,.cache_req_i(cache_ce_if_h.cache_req_o)
       ,.cache_req_v_i(cache_ce_if_h.cache_req_v_o)
       ,.cache_req_yumi_o(cache_ce_if_h.cache_req_yumi_i)
       ,.cache_req_busy_o(cache_ce_if_h.cache_req_busy_i)
       ,.cache_req_metadata_i(cache_ce_if_h.cache_req_metadata_o)
       ,.cache_req_metadata_v_i(cache_ce_if_h.cache_req_metadata_v_o)
       ,.cache_req_critical_tag_o(cache_ce_if_h.cache_req_critical_tag_i)
       ,.cache_req_critical_data_o(cache_ce_if_h.cache_req_critical_data_i)
       ,.cache_req_complete_o(cache_ce_if_h.cache_req_complete_i)
       ,.cache_req_credits_full_o(cache_ce_if_h.cache_req_credits_full_i)
       ,.cache_req_credits_empty_o(cache_ce_if_h.cache_req_credits_empty_i)

       ,.tag_mem_pkt_o(tag_mem_pkt_li)
       ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li)
       ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)
       ,.tag_mem_i(tag_mem_lo)

       ,.data_mem_pkt_o(data_mem_pkt_li)
       ,.data_mem_pkt_v_o(data_mem_pkt_v_li)
       ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)
       ,.data_mem_i(data_mem_lo)

       ,.stat_mem_pkt_o(stat_mem_pkt_li)
       ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li)
       ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)
       ,.stat_mem_i(stat_mem_lo)

       ,.mem_cmd_header_o(ram_if_h.mem_cmd_header_lo)
       ,.mem_cmd_data_o(ram_if_h.mem_cmd_data_lo)
       ,.mem_cmd_v_o(ram_if_h.mem_cmd_v_lo)
       ,.mem_cmd_ready_and_i(ram_if_h.mem_cmd_ready_and_li)
       ,.mem_cmd_last_o(ram_if_h.mem_cmd_last_lo)

       ,.mem_resp_header_i(ram_if_h.mem_resp_header_li)
       ,.mem_resp_data_i(ram_if_h.mem_resp_data_li)
       ,.mem_resp_v_i(ram_if_h.mem_resp_v_li)
       ,.mem_resp_ready_and_o(ram_if_h.mem_resp_ready_and_lo)
       ,.mem_resp_last_i(ram_if_h.mem_resp_last_li)
       );
  
  // Memory
  bp_nonsynth_mem
   #(.bp_params_p(bp_params_p)
     ,.preload_mem_p(1)
     ,.dram_type_p(dram_type_p)
     ,.mem_els_p(2**20)
     )
    mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_header_i(ram_if_h.mem_cmd_header_lo)
     ,.mem_cmd_data_i(ram_if_h.mem_cmd_data_lo)
     ,.mem_cmd_v_i(ram_if_h.mem_cmd_v_lo)
     ,.mem_cmd_ready_and_o(ram_if_h.mem_cmd_ready_and_li)
     ,.mem_cmd_last_i(ram_if_h.mem_cmd_last_lo)

     ,.mem_resp_header_o(ram_if_h.mem_resp_header_li)
     ,.mem_resp_data_o(ram_if_h.mem_resp_data_li)
     ,.mem_resp_v_o(ram_if_h.mem_resp_v_li)
     ,.mem_resp_ready_and_i(ram_if_h.mem_resp_ready_and_lo)
     ,.mem_resp_last_o(ram_if_h.mem_resp_last_li)

     ,.dram_clk_i(dram_clk_i)
     ,.dram_reset_i(dram_reset_i)
     );
  
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

  initial
  begin
    uvm_config_db #(virtual input_icache_if)::set(null, "uvm_test_top", "dut_input_vi", cache_input_if_h);
    uvm_config_db #(virtual tlb_icache_if)::set(null, "uvm_test_top", "dut_tlb_vi", cache_tlb_if_h);
    uvm_config_db #(virtual output_icache_if)::set(null, "uvm_test_top", "dut_output_vi", cache_output_if_h);
    uvm_config_db #(virtual ce_icache_if)::set(null, "uvm_test_top", "dut_ce_vi", cache_ce_if_h);
    uvm_config_db #(virtual ram_if)::set(null, "uvm_test_top", "dut_ram_vi", ram_if_h); 
    uvm_top.finish_on_completion  = 1;
    
    // run test specified on command line
    run_test();
  end

endmodule
