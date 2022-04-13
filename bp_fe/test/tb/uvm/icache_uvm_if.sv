// Devin Bidstrup 2022
// UVM Interfaces for BP L1 ICache Testbench

`ifndef ICACHE_UVM_IF_PKG
`define ICACHE_UVM_IF_PKG

`include "icache_uvm_cfg_pkg.sv"
`include "icache_uvm_params_pkg.sv"

//.......................................................
// DUT Interfaces
//.......................................................
// Used for communicating the inputs between the cache and the UVM testbench
interface input_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  import icache_uvm_params_pkg::*;
    (input logic clk_i,
     input logic reset_i);
  
  bit   [cfg_bus_width_lp-1:0]     cfg_bus_i;
  logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
  logic                            v_i;
  logic                            ready_o;
endinterface: input_icache_if

// Used for communication between the cache and the TLB
interface tlb_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  import icache_uvm_params_pkg::*;
    (input logic clk_i,
     input logic reset_i);
  
  logic [ptag_width_p-1:0] ptag_i;
  logic                    ptag_v_i;
  logic                    ptag_uncached_i;
  logic                    ptag_dram_i;
  logic                    ptag_nonidem_i;
  bit                      poison_tl_i;
endinterface: tlb_icache_if

// Used for communicating outputs between the cache and the UVM testbench
interface output_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  import icache_uvm_params_pkg::*;
    (input logic clk_i,
     input logic reset_i);
  
  logic [instr_width_gp-1:0]                data_o;
  logic                                     data_v_o;
  logic                                     miss_v_o;
  
endinterface: output_icache_if

// Used for communicatio between the cache and the coherence engine (e.g. UCE)
interface ce_icache_if 
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  import icache_uvm_params_pkg::*;
    (input logic clk_i,
     input logic reset_i);

  logic [icache_req_width_lp-1:0]           cache_req_o;
  logic                                     cache_req_v_o;
  logic                                     cache_req_yumi_i;
  logic                                     cache_req_busy_i;
  logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o;
  logic                                     cache_req_metadata_v_o;
  logic                                     cache_req_critical_tag_i;
  logic                                     cache_req_critical_data_i;
  logic                                     cache_req_complete_i;
  logic                                     cache_req_credits_full_i;
  logic                                     cache_req_credits_empty_i;
endinterface: ce_icache_if

// Used for communication between UCE and RAM
interface ram_if;
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_me_pkg::*;
  import icache_uvm_params_pkg::*;

  logic mem_cmd_v_lo, mem_resp_v_li;
  logic mem_cmd_ready_and_li, mem_resp_ready_and_lo, mem_cmd_last_lo, mem_resp_last_li;
  bp_bedrock_cce_mem_header_s mem_cmd_header_lo, mem_resp_header_li;
  logic [l2_fill_width_p-1:0] mem_cmd_data_lo, mem_resp_data_li;

endinterface: ram_if
`endif
