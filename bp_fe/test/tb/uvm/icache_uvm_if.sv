// Devin Bidstrup 2022
// UVM Interfaces for BP L1 ICache Testbench

`ifndef ICACHE_UVM_IF_PKG
`define ICACHE_UVM_IF_PKG

`include "icache_uvm_cfg_pkg.sv"
//.......................................................
// DUT Interfaces
//.......................................................
// Used for communicating the inputs between the cache and the UVM testbench
interface input_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
    #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    //local parameters
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache)
    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
    , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p))
    (input logic clk_i,
     input logic reset_i);
  
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  
  bit clk = clk_i;
  bit reset = reset_i;
      
  logic [cfg_bus_width_lp-1:0]     cfg_bus_i;
  logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
  bit                              v_i;
  bit                              ready_o;
endinterface: input_icache_if

// Used for communication between the cache and the TLB
interface tlb_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
    #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    //local parameters
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache))
    (input logic clk_i,
     input logic reset_i);
  
  bit clk = clk_i;
  bit reset = reset_i;
  
  logic [ptag_width_p-1:0]       ptag_i;
  bit                            ptag_v_i;
  bit                            ptag_uncached_i;
  bit                            ptag_dram_i;
  bit                            ptag_nonidem_i;
  bit                            poison_tl_i;
endinterface: tlb_icache_if

// Used for communicating outputs between the cache and the UVM testbench
interface output_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
    #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    //local parameters
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache))
    (input logic clk_i,
     input logic reset_i);

  bit clk = clk_i;
  bit reset = reset_i;
  
  logic [instr_width_gp-1:0]                data_o;
  logic                                     data_v_o;
  logic                                     miss_v_o;
  
endinterface: output_icache_if

// Used for communicatio between the cache and the coherence engine (e.g. UCE)
interface ce_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
    #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    //local parameters
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache))
    (input logic clk_i,
     input logic reset_i);

  bit clk = clk_i;
  bit reset = reset_i;
  
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
endinterface: ce_icache_if

// Used for communication between UCE and RAM
interface ram_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce));
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);

  logic mem_cmd_v_lo, mem_resp_v_li;
  logic mem_cmd_ready_and_li, mem_resp_ready_and_lo, mem_cmd_last_lo, mem_resp_last_li;
  bp_bedrock_cce_mem_header_s mem_cmd_header_lo, mem_resp_header_li;
  logic [l2_fill_width_p-1:0] mem_cmd_data_lo, mem_resp_data_li;

endinterface: ram_if
`endif
