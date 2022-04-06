// Devin Bidstrup 2022
// UVM Sequences for BP L1 ICache Testbench

`ifndef ICACHE_SEQ_PKG
`define ICACHE_SEQ_PKG

import uvm_pkg::*;
`include "uvm_macros.svh"
/*
`include "bp_common_aviary_pkgdef.svh"
`include "bp_common_aviary_defines.svh"
`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"
`include "bp_fe_icache_defines.svh"
`include "bp_fe_icache_pkgdef.svh"
`include "bp_top_defines.svh"
`include "bp_common_aviary_defines.svh"
`include "bp_common_aviary_pkgdef.svh"
`include "bp_common_cache_engine_if.svh"
*/
import bp_common_pkg::*;
import bp_fe_pkg::*;

//.......................................................
// Transactions
//.......................................................
class input_transaction #(parameter bp_params_e bp_params_p = e_bp_default_cfg
                         `declare_bp_proc_params(bp_params_p)
                         `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache))
  extends uvm_sequence_item;
  localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p);
  localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);

  `uvm_object_utils(input_transaction)
 
  // transaction bits
  rand logic [cfg_bus_width_lp-1:0]     cfg_bus_i;
  rand logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
  rand bit                              v_i;
  bit                                   ready_o;
  bit                                   reset_i;

  function new (string name = "");
    super.new(name);
  endfunction: new
  
  function void do_copy(uvm_object rhs);
    input_transaction rhs_;

    if(!$cast(rhs_, rhs)) begin
      uvm_report_error("do_copy:", "Cast failed");
      return;
    end
    super.do_copy(rhs);
      cfg_bus_i     = rhs_.cfg_bus_i;
      icache_pkt_i  = rhs_.icache_pkt_i;
      v_i           = rhs_.v_i;
      ready_o       = rhs_.ready_o;
      reset_i       = rhs_.reset_i;
   endfunction: do_copy

  function string convert2string();
   string s;
   s = super.convert2string();
   $sformat(s, 
     "icache_pkt_i %d\t v_i %d\t ready_o %d\t reset_i %d\n",
      icache_pkt_i, v_i, ready_o, reset_i);
   return s;
  endfunction: convert2string
  
endclass: input_transaction

class tlb_transaction #(parameter bp_params_e bp_params_p = e_bp_default_cfg
                      `declare_bp_proc_params(bp_params_p)) 
                      extends uvm_sequence_item;

  `uvm_object_utils(tlb_transaction)
  
  // transaction bits
  rand logic [ptag_width_p-1:0]       ptag_i;
  rand bit                            ptag_v_i;
  rand bit                            ptag_uncached_i;
  rand bit                            ptag_dram_i;
  rand bit                            ptag_nonidem_i;
  rand bit                            poison_tl_i;

  function new (string name = "");
    super.new(name);
  endfunction: new

  function void do_copy(uvm_object rhs);
    tlb_transaction rhs_;

    if(!$cast(rhs_, rhs)) begin
      uvm_report_error("do_copy:", "Cast failed");
      return;
    end
    super.do_copy(rhs);
      ptag_i          = rhs_.ptag_i;
      ptag_v_i        = rhs_.ptag_v_i;
      ptag_uncached_i = rhs_.ptag_uncached_i;
      ptag_dram_i     = rhs_.ptag_dram_i;
      ptag_nonidem_i  = rhs_.ptag_nonidem_i;
      poison_tl_i     = rhs_.poison_tl_i;
   endfunction: do_copy

  function string convert2string();
   string s;
   s = super.convert2string();
   $sformat(s, "ptag_i %d\t ptag_v_i %d\t ptag_uncached_i %d\t ptag_dram_i %d\t ptag_nonidem_i %d\t", 
            ptag_i, ptag_v_i, ptag_uncached_i, ptag_dram_i, ptag_nonidem_i);
   return s;
  endfunction: convert2string
  
endclass: tlb_transaction

class output_transaction extends uvm_sequence_item;

  `uvm_object_utils(output_transaction)
  
  // transaction bits
  logic [instr_width_gp-1:0]     data_o;
  bit                            miss_v_o;
  bit                            data_v_o;

  function new (string name = "");
    super.new(name);
  endfunction: new

  function void do_copy(uvm_object rhs);
    output_transaction rhs_;

    if(!$cast(rhs_, rhs)) begin
      uvm_report_error("do_copy:", "Cast failed");
      return;
    end
    super.do_copy(rhs);
      data_o    = rhs_.data_o;
      miss_v_o  = rhs_.miss_v_o;
      data_v_o  = rhs_.data_v_o;
   endfunction: do_copy

  function string convert2string();
   string s;
   s = super.convert2string();
   $sformat(s, "data_o %d\t data_v_o %d\t miss_v_o %d\n",
            data_o, data_v_o, miss_v_o);
   return s;
  endfunction: convert2string

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    output_transaction rhs_;

    if(!$cast(rhs_, rhs)) begin
      return 0;
    end
    return(super.do_compare(rhs, comparer) && (data_o   == rhs_.data_o)
                                           && (data_v_o == rhs_.data_v_o));
  endfunction: do_compare
  
endclass: output_transaction

class ce_transaction #(parameter bp_params_e bp_params_p = e_bp_default_cfg
                         `declare_bp_proc_params(bp_params_p)
                         `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache))
  extends uvm_sequence_item;
   localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p);

  `uvm_object_utils(ce_transaction)
  
  // transaction bits
  logic [icache_req_width_lp-1:0]           cache_req_o;
  bit                                       cache_req_v_o;
  rand bit                                  cache_req_yumi_i;
  rand bit                                  cache_req_busy_i;
  logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o;
  bit                                       cache_req_metadata_v_o;
  rand bit                                  cache_req_critical_tag_i;
  rand bit                                  cache_req_critical_data_i;
  rand bit                                  cache_req_complete_i;
  rand bit                                  cache_req_credits_empty_i;
  rand bit                                  cache_req_credits_full_i;

  function new (string name = "");
    super.new(name);
  endfunction: new

  function void do_copy(uvm_object rhs);
    ce_transaction rhs_;

    if(!$cast(rhs_, rhs)) begin
      uvm_report_error("do_copy:", "Cast failed");
      return;
    end
    super.do_copy(rhs);
      cache_req_o               = rhs_.cache_req_o;
      cache_req_v_o             = rhs_.cache_req_v_o;
      cache_req_yumi_i          = rhs_.cache_req_yumi_i;
      cache_req_busy_i          = rhs_.cache_req_busy_i;
      cache_req_metadata_o      = rhs_.cache_req_metadata_o;
      cache_req_metadata_v_o    = rhs_.cache_req_metadata_v_o;
      cache_req_critical_tag_i  = rhs_.cache_req_critical_tag_i;
      cache_req_critical_data_i = rhs_.cache_req_critical_data_i;
      cache_req_complete_i      = rhs_.cache_req_complete_i;
      cache_req_credits_empty_i = rhs_.cache_req_credits_empty_i;
      cache_req_credits_full_i  = rhs_.cache_req_credits_full_i;
   endfunction: do_copy

  function string convert2string();
   string s;
   s = super.convert2string();
   $sformat(s, "cache_req_o %d\t cache_req_v_o %d\t cache_req_yumi_i %d\t cache_req_busy_i %d\n cache_req_metadata_o %d\t cache_req_metadata_v_o %d\t cache_req_critical_tag_i %d\n cache_req_critical_data_i %d\t cache_req_complete_i %d\n cache_req_credits_full_i %d\t cache_req_credits_empty_i %d\n", 
            cache_req_o, cache_req_v_o,
            cache_req_yumi_i, cache_req_busy_i, cache_req_metadata_o, cache_req_metadata_v_o, 
            cache_req_critical_tag_i, cache_req_critical_data_i, cache_req_complete_i,
            cache_req_credits_empty_i, cache_req_credits_full_i);
   return s;
  endfunction: convert2string
  
endclass: ce_transaction

//.......................................................
// Sequence
//.......................................................
// Basic randomized input sequence stimulus
class input_sequence extends uvm_sequence #(input_transaction);

  `uvm_object_utils(input_sequence)
  
  function new (string name = "");
    super.new(name);
  endfunction: new

  task body;
    input_transaction tx;
    tx = input_transaction#()::type_id::create("tx");
    start_item(tx);
    assert (tx.randomize() with {v_i==1'b1;});
    finish_item(tx);

  endtask: body
 
endclass: input_sequence

// Sequence that sets all inputs to zero
class zero_sequence extends uvm_sequence #(input_transaction);

  `uvm_object_utils(zero_sequence)
  
  function new (string name = "");
    super.new(name);
  endfunction: new

  task body;
    input_transaction tx;
    tx = input_transaction#()::type_id::create("tx");
    start_item(tx);
    tx.cfg_bus_i    = '0;
    tx.icache_pkt_i = '0;
    tx.v_i          = '0;
    tx.ready_o      = '0;
    finish_item(tx);
  endtask: body
 
endclass: zero_sequence

// //.......................................................
// // Hierarchical Sequences
// //......................................................
// Sequences a random number of randomized input sequences.
 class seq_of_inputs extends uvm_sequence #(input_transaction);

  `uvm_object_utils(seq_of_inputs)

  rand int n;
  constraint how_many { n inside {[4:6]}; }

  function new (string name = "");
    super.new(name);
  endfunction: new

  task body;
    `uvm_info("seq", $psprintf("N is %d", n), UVM_NONE);
    repeat(n)
    begin
      input_sequence seq;
      seq = input_sequence::type_id::create("seq");
      seq.start(m_sequencer, this);
    end
  endtask: body
endclass: seq_of_inputs

// Sequences a random number of randomized input sequences.
 class seq_of_commands extends uvm_sequence #(input_transaction);

  `uvm_object_utils(seq_of_commands)

  rand int n;
  constraint how_many { n inside {[2:4]}; }

  function new (string name = "");
    super.new(name);
  endfunction: new

  task body;
    `uvm_info("seq", $psprintf("N is %d", n), UVM_NONE);
    repeat(n)
    begin
      seq_of_inputs seq;
      seq = seq_of_inputs::type_id::create("seq");
      seq.start(m_sequencer, this);

      repeat(4)
      begin
        zero_sequence zseq;
        zseq = zero_sequence::type_id::create("zseq");
        zseq.start(m_sequencer, this);
      end
    end
  endtask: body
endclass: seq_of_commands

//endpackage : icache_uvm_seq_pkg
`endif
