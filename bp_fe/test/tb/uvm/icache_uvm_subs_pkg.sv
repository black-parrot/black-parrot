// Devin Bidstrup 2022
// UVM Subscribers for BP L1 ICache Testbench

`ifndef ICACHE_SUBS_PKG
`define ICACHE_SUBS_PKG

`include "icache_uvm_seq_pkg.sv"


`include "uvm_macros.svh"
import uvm_pkg::*;

//.......................................................
// Coverage Collector
//.......................................................
`uvm_analysis_imp_decl(_INPUT)
`uvm_analysis_imp_decl(_TLB)
`uvm_analysis_imp_decl(_OUTPUT)
`uvm_analysis_imp_decl(_CE)
class icache_cov_col #(parameter bp_params_e bp_params_p = e_bp_default_cfg
                         `declare_bp_proc_params(bp_params_p)
                         `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache)
                     , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
                     , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p))
                      extends uvm_component;

  `uvm_component_utils(icache_cov_col)

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  uvm_analysis_imp_INPUT  #(input_transaction, icache_cov_col)  input_export;
  uvm_analysis_imp_TLB    #(tlb_transaction, icache_cov_col)    tlb_export;
  uvm_analysis_imp_OUTPUT #(output_transaction, icache_cov_col) output_export;
  uvm_analysis_imp_CE     #(ce_transaction, icache_cov_col)     ce_export;

  bit                              reset_i;
  logic [cfg_bus_width_lp-1:0]     cfg_bus_i;
  logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
  bit                              v_i;
  bit                              ready_o;
  logic [ptag_width_p-1:0]       ptag_i;
  bit                            ptag_v_i;
  bit                            ptag_uncached_i;
  bit                            ptag_dram_i;
  bit                            ptag_nonidem_i;
  bit                            poison_tl_i;
  logic [instr_width_gp-1:0]                data_o;
  logic                                     data_v_o;
  logic                                     miss_v_o;
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


  covergroup cover_input;
    coverpoint icache_pkt_i {
      bins range[10] = {[0:$]};
    }
    coverpoint v_i;
    coverpoint ready_o;
    coverpoint cfg_bus_i;
    coverpoint reset_i;

    input_cross: cross icache_pkt_i, v_i, ready_o;

  endgroup: cover_input

  covergroup cover_tlb;
    coverpoint ptag_i;
    coverpoint ptag_v_i;
    coverpoint ptag_uncached_i;
    coverpoint ptag_dram_i;
    coverpoint ptag_nonidem_i;
    coverpoint poison_tl_i;
  endgroup: cover_tlb

  covergroup cover_output;
    coverpoint data_o;
    coverpoint data_v_o;
    coverpoint miss_v_o;
  endgroup: cover_output

  covergroup cover_ce;
    coverpoint cache_req_o;
    coverpoint cache_req_v_o;
    coverpoint cache_req_yumi_i;
    coverpoint cache_req_busy_i;
    coverpoint cache_req_metadata_o;
    coverpoint cache_req_metadata_v_o;
    coverpoint cache_req_critical_tag_i;
    coverpoint cache_req_critical_data_i;
    coverpoint cache_req_complete_i;
    coverpoint cache_req_credits_full_i;
    coverpoint cache_req_credits_empty_i;
  endgroup: cover_ce

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cover_input = new;  
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction: build_phase

  function void write_INPUT(input_transaction t);
    //Print the received transacton
    `uvm_info("coverage_collector", 
              $psprintf("Coverage collector received input tx %s", 
              t.convert2string()), UVM_HIGH);
    
    //Sample coverage info
    reset_i       = t.reset_i;
    cfg_bus_i 	  = t.cfg_bus_i;
    icache_pkt_i  = t.icache_pkt_i;
    v_i           = t.v_i;
    ready_o       = t.ready_o;
    cover_input.sample();
    
  endfunction: write_INPUT

  function void write_TLB(tlb_transaction t);
    //Print the received transacton
    `uvm_info("coverage_collector", 
              $psprintf("Coverage collector received tlb tx %s", 
              t.convert2string()), UVM_HIGH);

    //Sample coverage info
    ptag_i            = t.ptag_i;
    ptag_v_i 	        = t.ptag_v_i;
    ptag_uncached_i   = t.ptag_uncached_i;
    ptag_dram_i       = t.ptag_dram_i;
    ptag_nonidem_i    = t.ptag_nonidem_i;
    poison_tl_i       = t.poison_tl_i;
    cover_tlb.sample();

  endfunction : write_TLB

  function void write_OUTPUT(output_transaction t);
    //Print the received transacton
    `uvm_info("coverage_collector", 
              $psprintf("Coverage collector received output tx %s", 
              t.convert2string()), UVM_HIGH);

    //Sample coverage info
    data_o            = t.data_o;
    data_v_o 	        = t.data_v_o;
    miss_v_o          = t.miss_v_o;
    cover_tlb.sample();

  endfunction : write_OUTPUT

  function void write_CE(ce_transaction t);
    //Print the received transacton
    `uvm_info("coverage_collector", 
              $psprintf("Coverage collector received ce tx %s", 
              t.convert2string()), UVM_HIGH);

    //Sample coverage info
    cache_req_o                = t.cache_req_o;
    cache_req_v_o 	            = t.cache_req_v_o;
    cache_req_yumi_i           = t.cache_req_yumi_i;
    cache_req_busy_i           = t.cache_req_busy_i;
    cache_req_metadata_o       = t.cache_req_metadata_o;
    cache_req_metadata_v_o     = t.cache_req_metadata_v_o;
    cache_req_critical_tag_i   = t.cache_req_critical_tag_i;
    cache_req_critical_data_i  = t.cache_req_critical_data_i;
    cache_req_complete_i       = t.cache_req_complete_i;
    cache_req_credits_full_i   = t.cache_req_credits_full_i;
    cache_req_credits_empty_i  = t.cache_req_credits_empty_i;
    cover_tlb.sample();

  endfunction : write_CE

endclass: icache_cov_col

// //.......................................................
// // Predictor 
// //.......................................................
// class bp_be_dcache_predictor extends uvm_subscriber #(my_transaction);

//   `uvm_component_utils(bp_be_dcache_predictor)

// endclass:bp_be_dcache

// //.......................................................
// // Comparator
// //.......................................................
// `uvm_analysis_imp_decl(_PRED)
// `uvm_analysis_imp_decl(_DUT)
// class bp_be_dcache_comparator extends uvm_component;

//   `uvm_component_utils(bp_be_dcache_comparator)

//   uvm_analysis_imp_PRED #(my_transaction,bp_be_dcache) pred_export;
//   uvm_analysis_imp_DUT  #(my_transaction,bp_be_dcache) dut_export;

// endclass:bp_be_dcache

// //.......................................................
// // Scoreboard
// //.......................................................
// class bp_be_dcache_scoreboard extends uvm_subscriber#(my_transaction);

//   `uvm_component_utils(bp_be_dcache_scoreboard)
  
// endclass: bp_be_dcache_scoreboard

//endpackage : icache_uvm_subs_pkg
`endif
