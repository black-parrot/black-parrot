// Devin Bidstrup 2022
// UVM Top-Level Testbench for BP L1 ICache Testbench

`include "uvm_macros.svh"

`include "icache_uvm_cfg_pkg.sv"
`include "icache_uvm_seq_pkg.sv"
`include "icache_uvm_tests_pkg.sv"
`include "icache_uvm_comp_pkg.sv"
`include "icache_uvm_subs_pkg.sv"
import icache_uvm_cfg_pkg::*;
import icache_uvm_seq_pkg::*;
import icache_uvm_tests_pkg::*;
import icache_uvm_comp_pkg::*;
import icache_uvm_subs_pkg::*;

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_fe_icache_defines.svh"
`include "bp_fe_icache_pkgdef.svh"
`include "bp_top_defines.svh"
//`include "bp_common_pkg.sv"
`include "bp_common_aviary_defines.svh"
`include "bp_common_aviary_pkgdef.svh"
`include "bp_common_cache_engine_if.svh"
import bp_common_pkg::*;
import bp_fe_pkg::*;
import bp_me_pkg::*;
import icache_uvm_tests_pkg::*;

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

//.......................................................
// DUT Interfaces
//.......................................................
// Used for communication between the cache and the UVM testbench
interface icache_if #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    , parameter vif_type chosen_if = INPUT
    //local parameters
    `declare_bp_proc_params(bp_params_p))
    (input logic clk,
     input logic reset_i);
  localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p);
  case (chosen_if)
    INPUT : begin
      //logic [cfg_bus_width_lp-1:0]     cfg_bus_i;
      logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
      bit                              v_i;
      bit                              ready_o;
    end
    TLB : begin
      logic [ptag_width_p-1:0]       ptag_i;
      bit                            ptag_v_i;
      bit                            ptag_uncached_i;
      bit                            ptag_dram_i;
      bit                            ptag_nonidem_i;
      //bit                            poison_tl_i;
    end
    OUTPUT : begin
      logic [instr_width_gp-1:0]                data_o;
      logic                                     data_v_o;
      logic                                     miss_v_o;
    end
    CE : begin
      logic [icache_req_width_lp-1:0]           cache_req_o;
      bit                                       cache_req_v_o;
      bit                                       cache_req_yumi_i;
      bit                                       cache_req_busy_i;
      logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o;
      bit                                       cache_req_metadata_v_o;
      bit                                       cache_req_critical_tag_i;
      bit                                       cache_req_critical_data_i;
      bit                                       cache_req_complete_i;
      bit                                       cache_req_credits_full_i;
      bit                                       cache_req_credits_empty_i;

      // VCS says this feature is not yet implemented
      // modport bp_fe_icache (input cache_req_yumi_i, cache_req_busy_i, 
      //                      cache_req_critical_tag_i, cache_req_critical_data_i, cache_req_complete_i,
      //                      cache_req_credits_full_i, cache_req_credits_empty_i,
      //                      output cache_req_o, cache_req_v_o, 
      //                      cache_req_metadata_o, cache_req_metadata_v_o);
      // modport bp_uce      (output cache_req_yumi_i, cache_req_busy_i, 
      //                      cache_req_critical_tag_i, cache_req_critical_data_i, cache_req_complete_i,
      //                      cache_req_credits_full_i, cache_req_credits_empty_i,
      //                      input cache_req_o, cache_req_v_o,
      //                      cache_req_metadata_o, cache_req_metadata_v_o);
    end
  endcase
endinterface: icache_if

// Used for communication between UCE and RAM
interface ram_if;
  
  logic mem_cmd_v_lo, mem_resp_v_li;
  logic mem_cmd_ready_and_li, mem_resp_ready_and_lo, mem_cmd_last_lo, mem_resp_last_li;
  bp_bedrock_cce_mem_header_s mem_cmd_header_lo, mem_resp_header_li;
  logic [l2_fill_width_p-1:0] mem_cmd_data_lo, mem_resp_data_li;

  // VCS says this feature is not yet implemented
  // modport bp_nonsynth_mem (input mem_cmd_v_lo, mem_resp_ready_and_lo, 
  //                          mem_cmd_last_lo, mem_cmd_header_lo, mem_cmd_data_lo,
  //                          output mem_resp_v_li, mem_cmd_ready_and_li, 
  //                          mem_resp_last_li, mem_resp_header_li, mem_resp_data_li);
  
  // modport bp_uce          (output mem_cmd_v_lo, mem_resp_ready_and_lo, 
  //                          mem_cmd_last_lo, mem_cmd_header_lo, mem_cmd_data_lo,
  //                          input mem_resp_v_li, mem_cmd_ready_and_li, 
  //                          mem_resp_last_li, mem_resp_header_li, mem_resp_data_li);
endinterface: ram_if

//.......................................................
// Top
//.......................................................
module top #(parameter bp_params_e bp_params_p = e_bp_default_cfg //BP_CFG_FLOWVAR instead?
   , parameter assoc_p = 8
   , parameter sets_p = 64
   , parameter block_width_p = 512
   , parameter fill_width_p = 512
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)

   // Calculated parameters
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   );

  import uvm_pkg::*;
  
  // PARAMETERS

  // Defined in bp_params_p
  //  , parameter dword_width_gp = 
  //  , parameter vaddr_width_p  = 
  //  , parameter ctag_width_p = 
  //  , parameter paddr_width_p = 
  //  , parameter icache_data_mem_pkt_width_lp = 
  //  , parameter icache_tag_mem_pkt_width_lp = 
  //  , parameter icache_stat_mem_pkt_width_lp =
  //  , parameter icache_tag_info_width_lp =
  //  , parameter icache_stat_info_width_lp =
  //    localparam l2_fill_width_p = 
  //  , parameter dram_type_p = 

  // localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  // `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  // for uce
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);

  // Fill Interfaces
  logic data_mem_pkt_v_li, tag_mem_pkt_v_li, stat_mem_pkt_v_li;
  logic data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
  logic [icache_data_mem_pkt_width_lp-1:0] data_mem_pkt_li;
  logic [icache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_li;
  logic [icache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_li;
  logic [block_width_p-1:0] data_mem_lo;
  logic [icache_tag_info_width_lp-1:0] tag_mem_lo;
  logic [icache_stat_info_width_lp-1:0] stat_mem_lo;

  //bits for clk and rst
  bit clk_i, reset_i;

  // Interface definitions
  icache_if #(INPUT) cache_input_if_h(clk_i, reset_i);
  icache_if #(TLB) cache_tlb_if_h(clk_i, reset_i);
  icache_if #(OUTPUT) cache_output_if_h(clk_i, reset_i);
  icache_if #(CE) cache_ce_if_h(clk_i, reset_i);
  ram_if ram_if_h;

  //I CACHE
  bp_fe_icache
   #(.bp_params_p(bp_params_p)
     ,.sets_p(sets_p)
     ,.assoc_p(assoc_p)
     ,.block_width_p(block_width_p)
     ,.fill_width_p(fill_width_p)
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
       ,.assoc_p(assoc_p)
       ,.sets_p(sets_p)
       ,.block_width_p(block_width_p)
       ,.fill_width_p(fill_width_p)
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
       ,.cache_req_credits_full_o(cache_ce_if_h.cache_req_credits_full_is)
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
  // Clock and reset generator
  // initial
  // begin
  //   cache_input_if_h.clk = 0;
  //   forever #25 cache_input_if_h.clk = ~cache_input_if_h.clk;
  // end

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

  // Assign clk and reset to the interfaces
  // assign cache_input_if_h.clk_i = clk_i;
  // assign cache_tlb_if_h.clk_i = clk_i;
  // assign cache_output_if_h.clk_i = clk_i;
  // assign cache_ce_if_h.clk_i = clk_i;
  // assign cache_input_if_h.reset_i = reset_i;
  // assign cache_tlb_if_h.reset_i = reset_i;
  // assign cache_output_if_h.reset_i = reset_i;
  // assign cache_ce_if_h.reset_i = reset_i;

  initial
  begin: blk
    uvm_config_db #(virtual icache_if)::set(null, "uvm_test_top", "dut_input_vi", cache_input_if_h);
    uvm_config_db #(virtual icache_if)::set(null, "uvm_test_top", "dut_tlb_vi", cache_tlb_if_h);
    uvm_config_db #(virtual icache_if)::set(null, "uvm_test_top", "dut_output_vi", cache_output_if_h);
    uvm_config_db #(virtual icache_if)::set(null, "uvm_test_top", "dut_ce_vi", cache_ce_if_h);
    
    uvm_top.finish_on_completion  = 1;
    
    run_test("base_test");
  end

endmodule: top

