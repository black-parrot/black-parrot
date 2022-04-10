// Devin Bidstrup 2022
// UVM Sequences for BP L1 ICache Testbench

`ifndef ICACHE_SEQ_PKG
`define ICACHE_SEQ_PKG

`include "uvm_macros.svh"
`include "icache_uvm_params_pkg.sv"

package icache_uvm_seq_pkg;

  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import uvm_pkg::*;
  import icache_uvm_params_pkg::*;

  //.......................................................
  // Transactions
  //.......................................................
  class input_transaction extends uvm_sequence_item;
    `uvm_object_utils(input_transaction)
  
    // transaction bits
    rand logic [cfg_bus_width_lp-1:0]     cfg_bus_i;
    rand logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
    rand logic                            v_i;
    logic                                 ready_o;
    logic                                 reset_i;

    function new (string name = "input_transaction");
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

  class tlb_transaction extends uvm_sequence_item;

    `uvm_object_utils(tlb_transaction)
    
    // transaction bits
    rand logic [ptag_width_p-1:0] ptag_i;
    rand logic                    ptag_v_i;
    rand logic                    ptag_uncached_i;
    rand logic                    ptag_dram_i;
    rand logic                    ptag_nonidem_i;
    rand logic                    poison_tl_i;

    function new (string name = "tlb_transaction");
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
    logic [instr_width_gp-1:0] data_o;
    logic                      miss_v_o;
    logic                      data_v_o;

    function new (string name = "output_transaction");
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

  class ce_transaction extends uvm_sequence_item;
    `uvm_object_utils(ce_transaction)
    
    // transaction bits
    logic [icache_req_width_lp-1:0]           cache_req_o;
    logic                                     cache_req_v_o;
    rand logic                                cache_req_yumi_i;
    rand logic                                cache_req_busy_i;
    logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o;
    logic                                     cache_req_metadata_v_o;
    rand logic                                cache_req_critical_tag_i;
    rand logic                                cache_req_critical_data_i;
    rand logic                                cache_req_complete_i;
    rand logic                                cache_req_credits_empty_i;
    rand logic                                cache_req_credits_full_i;

    function new (string name = "ce_transaction");
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
  // Sequencer
  //.......................................................
  // typedef uvm_sequencer #(input_transaction)  input_sequencer;
  // typedef uvm_sequencer #(tlb_transaction)    tlb_sequencer;
  // typedef uvm_sequencer #(output_transaction) output_sequencer;
  // typedef uvm_sequencer #(ce_transaction)    ce_sequencer;

  // Better to use class method to have sequencer show up in the componenet hierarchy
  class input_sequencer extends uvm_sequencer #(input_transaction);
    `uvm_component_utils(input_sequencer)

    function new (string name="input_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction: new
  endclass: input_sequencer

  class tlb_sequencer extends uvm_sequencer #(tlb_transaction);
    `uvm_component_utils(tlb_sequencer)

    function new (string name="tlb_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction: new
  endclass: tlb_sequencer

  class output_sequencer extends uvm_sequencer #(output_transaction);
    `uvm_component_utils(output_sequencer)

    function new (string name="output_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction: new
  endclass: output_sequencer

  class ce_sequencer extends uvm_sequencer #(ce_transaction);
    `uvm_component_utils(ce_sequencer)

    function new (string name="ce_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction: new
  endclass: ce_sequencer

  //.......................................................
  // Sequences
  //.......................................................
  // Basic randomized input sequence stimulus
  class input_sequence extends uvm_sequence #(input_transaction);
    `uvm_object_utils(input_sequence)
    input_transaction tx;
    
    function new (string name = "input_sequence");
      super.new(name);
    endfunction: new

    task body;
      tx = input_transaction::type_id::create("tx");
      start_item(tx);
      if (!tx.randomize() with {v_i==1'b1;}) begin
        `uvm_error("input_sequence", "rand failure")
      end
      //assert (tx.randomize() with {v_i==1'b1;});
      finish_item(tx);
      
      // Wait for packet to actually be sent
      wait_for_item_done();
    endtask: body
  
  endclass: input_sequence

  // Sequence that sets all inputs to zero
  class zero_sequence extends uvm_sequence #(input_transaction);
    `uvm_object_utils(zero_sequence)
    
    function new (string name = "zero_sequence");
      super.new(name);
    endfunction: new

    task body;
      input_transaction tx;
      tx = input_transaction::type_id::create("tx");
      start_item(tx);
      tx.cfg_bus_i    = '0;
      tx.icache_pkt_i = '0;
      tx.v_i          = '0;
      tx.reset_i      = '0;
      finish_item(tx);

      // Wait for packet to actually be sent
      wait_for_item_done();
    endtask: body
  
  endclass: zero_sequence

  class load_sequence extends uvm_sequence #(input_transaction);
    `uvm_object_utils(load_sequence)
    input_transaction tx;
    bp_fe_icache_pkt_s temp_pkt;
    
    function new (string name = "input_sequence");
      super.new(name);
      `uvm_info("load_sequence", "creating sequence", UVM_HIGH);
    endfunction: new

    task body;
      tx = input_transaction::type_id::create("tx");
      for(int i = 0; i < 64; i+=4) begin
       `uvm_info("load_sequence", "starting sequence", UVM_HIGH); 
        start_item(tx);        
        temp_pkt.op = e_icache_fetch;
        temp_pkt.vaddr = (1'b1 << 31) | i;
        tx.icache_pkt_i = temp_pkt;
        `uvm_info("load_sequence", $psprintf("Generated fetch request with op %d\t vaddr %d\n", temp_pkt.op, temp_pkt.vaddr), UVM_MEDIUM);
        finish_item(tx);

        // Wait for packet to actually be sent
        wait_for_item_done();
      end

    endtask: body
  endclass: load_sequence

  // //.......................................................
  // // Hierarchical Sequences
  // //......................................................
  // Sequences a random number of randomized input sequences.
  class seq_of_inputs extends uvm_sequence #(input_transaction);
    `uvm_object_utils(seq_of_inputs)

    // rand int n;
    // constraint how_many_inputs { n inside {[4:6]}; }
    int n = 4;

    function new (string name = "seq_of_inputs");
      super.new(name);
    endfunction: new

    task body;
      `uvm_info("seq_of_inputs", $psprintf("N is %d", n), UVM_NONE);
      repeat(n)
      begin
        input_sequence seq;
        seq = input_sequence::type_id::create("seq");
        seq.start(m_sequencer, this);
      end
    endtask: body
  endclass: seq_of_inputs

  // Sequences a fixed number of zero inputs
  class seq_of_zeros#(cycles = 10) extends uvm_sequence #(input_transaction);
    `uvm_object_utils(seq_of_zeros#(cycles))

    function new (string name = "seq_of_zeros");
      super.new(name);
    endfunction: new

    task body;
      `uvm_info("seq_of_zeros", $psprintf("cycles is %d", cycles), UVM_HIGH);
      repeat(cycles)
      begin
        zero_sequence zseq;
        zseq = zero_sequence::type_id::create("zseq");
        zseq.start(m_sequencer, this);
      end
    endtask: body
  endclass: seq_of_zeros

  // Sequences a random number of randomized input sequences.
  class seq_of_commands extends uvm_sequence #(input_transaction);
    `uvm_object_utils(seq_of_commands)

    localparam zero_space = 4;
    rand int n;
    constraint how_many_commands { n inside {[2:4]}; }

    seq_of_inputs seqOI;
    seq_of_zeros#(zero_space) seqOZ;


    function new (string name = "seq_of_commands");
      super.new(name);
    endfunction: new

    task body;
      uvm_phase p = get_starting_phase();
      if(p) p.get_objection().display_objections(this, 1);
      `uvm_info("seq_of_commands", $psprintf("N is %d", n), UVM_NONE);
      repeat(n)
      begin
        seqOI = seq_of_inputs::type_id::create("seqOI");
        seqOZ = seq_of_zeros#(zero_space)::type_id::create("seqOZ");
        seqOI.start(m_sequencer, this);
        seqOZ.start(.sequencer(m_sequencer), .parent_sequence(this));
      end
    endtask: body
  endclass: seq_of_commands

// //.......................................................
// // Virtual Sequences
// //......................................................
class myvseq_base extends uvm_sequence#(uvm_sequence_item);
  `uvm_object_utils(myvseq_base);
  
  input_sequencer   input_sequencer_h;
  tlb_sequencer     tlb_sequencer_h;
  output_sequencer  output_sequencer_h;
  ce_sequencer      ce_sequencer_h;

  function new (string name = "myvseq_base");
    super.new(name);
  endfunction: new

endclass: myvseq_base

class test_load_vseq extends myvseq_base;
  `uvm_object_utils(test_load_vseq);

  function new (string name = "test_vseq");
    super.new(name);
  endfunction: new

  task body();
    load_sequence test_seq = load_sequence::type_id::create("test_seq");
    `uvm_info("test_load_vseq", "starting sequence", UVM_HIGH);
    test_seq.start(input_sequencer_h, this);
    `uvm_info("test_load_vseq", "sequence finished", UVM_HIGH);
  endtask: body
endclass: test_load_vseq

endpackage: icache_uvm_seq_pkg
`endif
