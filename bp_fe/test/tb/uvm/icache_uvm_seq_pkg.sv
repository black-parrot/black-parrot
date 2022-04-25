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
    rand logic [icache_pkt_width_lp-1:0]  icache_pkt_i;
    rand logic                            v_i;
    logic                                 ready_o;
    logic                                 reset_i;
    logic                                 clk_i;

    function new (string name = "input_transaction");
      super.new(name);

      //Default transaction values
      icache_pkt_i = '0;
      v_i = 1'b0;
      ready_o = 1'b0;
      reset_i = 1'b0;
      clk_i = 1'b0;
    endfunction : new

    function void do_copy(uvm_object rhs);
      input_transaction rhs_;

      if(!$cast(rhs_, rhs)) 
        begin
          uvm_report_error("do_copy:", "Cast failed");
          return;
        end
      super.do_copy(rhs);
        icache_pkt_i  = rhs_.icache_pkt_i;
        v_i           = rhs_.v_i;
        ready_o       = rhs_.ready_o;
        reset_i       = rhs_.reset_i;
        clk_i         = rhs_.clk_i;
    endfunction : do_copy

    function string convert2string();
      string s;
      s = super.convert2string();
      $sformat(s,
        "vaddr %d\t op_code %d\t v_i %d\t ready_o %d\t reset_i %d clk_i %d\n",
          icache_pkt_i[icache_pkt_width_lp-1:icache_pkt_width_lp-vaddr_width_p], 
          icache_pkt_i[icache_pkt_width_lp-vaddr_width_p-1:0], v_i, ready_o, reset_i, clk_i);
      return s;
    endfunction : convert2string

  endclass : input_transaction

  class tlb_transaction extends uvm_sequence_item;

    `uvm_object_utils(tlb_transaction)

    // transaction bits
    rand logic [ptag_width_p-1:0] ptag_i;
    rand logic                    ptag_v_i;
    rand logic                    ptag_uncached_i;
    rand logic                    ptag_dram_i;
    rand logic                    ptag_nonidem_i;

    function new (string name = "tlb_transaction");
      super.new(name);

      //Default transaction values
      ptag_i = '0;
      ptag_v_i = 1'b0;
      ptag_uncached_i = 1'b0;
      ptag_dram_i = 1'b0;
      ptag_nonidem_i = 1'b0;
    endfunction : new

    function void do_copy(uvm_object rhs);
      tlb_transaction rhs_;

      if(!$cast(rhs_, rhs)) 
        begin
          uvm_report_error("do_copy:", "Cast failed");
          return;
        end
      super.do_copy(rhs);
        ptag_i          = rhs_.ptag_i;
        ptag_v_i        = rhs_.ptag_v_i;
        ptag_uncached_i = rhs_.ptag_uncached_i;
        ptag_dram_i     = rhs_.ptag_dram_i;
        ptag_nonidem_i  = rhs_.ptag_nonidem_i;
    endfunction : do_copy

    function string convert2string();
    string s;
    s = super.convert2string();
    $sformat(s, "ptag_i %d\t ptag_v_i %d\t ptag_uncached_i %d\t ptag_dram_i %d\t ptag_nonidem_i %d\t",
              ptag_i, ptag_v_i, ptag_uncached_i, ptag_dram_i, ptag_nonidem_i);
    return s;
    endfunction : convert2string

  endclass : tlb_transaction

  class output_transaction extends uvm_sequence_item;
    `uvm_object_utils(output_transaction)

    // transaction bits
    logic [instr_width_gp-1:0] data_o;
    logic                      miss_v_o;
    logic                      data_v_o;
    longint                    tx_id;

    function new (string name = "output_transaction");
      super.new(name);

      //Default transaction values
      data_o   = '0;
      miss_v_o = 1'b0;
      data_v_o = 1'b0;
      tx_id    = '0;
    endfunction : new

    function void do_copy(uvm_object rhs);
      output_transaction rhs_;

      if(!$cast(rhs_, rhs)) 
        begin
          uvm_report_error("do_copy:", "Cast failed");
          return;
        end
      super.do_copy(rhs);
        data_o    = rhs_.data_o;
        miss_v_o  = rhs_.miss_v_o;
        data_v_o  = rhs_.data_v_o;
    endfunction : do_copy

    function string convert2string();
    string s;
    s = super.convert2string();
    $sformat(s, "data_o %d\t data_v_o %d\t miss_v_o %d\n",
              data_o, data_v_o, miss_v_o);
    return s;
    endfunction : convert2string

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
      output_transaction rhs_;

      if(!$cast(rhs_, rhs)) 
        begin
          return 0;
        end
      return(super.do_compare(rhs, comparer) && (data_o   == rhs_.data_o)
                                            && (data_v_o == rhs_.data_v_o));
    endfunction : do_compare

  endclass : output_transaction

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
    endfunction : new

    function void do_copy(uvm_object rhs);
      ce_transaction rhs_;

      if(!$cast(rhs_, rhs)) 
        begin
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
    endfunction : do_copy

    function string convert2string();
    string s;
    s = super.convert2string();
    $sformat(s, "cache_req_o %d\t cache_req_v_o %d\t cache_req_yumi_i %d\t cache_req_busy_i %d\n \
                cache_req_metadata_o %d\t cache_req_metadata_v_o %d\t cache_req_critical_tag_i %d\n \
                cache_req_critical_data_i %d\t cache_req_complete_i %d\n cache_req_credits_full_i \
                %d\t cache_req_credits_empty_i %d\n",
              cache_req_o, cache_req_v_o,
              cache_req_yumi_i, cache_req_busy_i, cache_req_metadata_o, cache_req_metadata_v_o,
              cache_req_critical_tag_i, cache_req_critical_data_i, cache_req_complete_i,
              cache_req_credits_empty_i, cache_req_credits_full_i);
    return s;
    endfunction : convert2string

  endclass : ce_transaction

  //.......................................................
  // Sequencer
  //.......................................................
  // Better to use class method to have sequencer show up in the componenet hierarchy
  class input_sequencer extends uvm_sequencer #(input_transaction);
    `uvm_component_utils(input_sequencer)

    function new (string name="input_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction : new
  endclass : input_sequencer

  class tlb_sequencer extends uvm_sequencer #(tlb_transaction);
    `uvm_component_utils(tlb_sequencer)

    function new (string name="tlb_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction : new
  endclass : tlb_sequencer

  class output_sequencer extends uvm_sequencer #(output_transaction);
    `uvm_component_utils(output_sequencer)

    function new (string name="output_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction : new
  endclass : output_sequencer

  class ce_sequencer extends uvm_sequencer #(ce_transaction);
    `uvm_component_utils(ce_sequencer)

    function new (string name="ce_m_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction : new
  endclass : ce_sequencer

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
      if (!tx.randomize() with {v_i==1'b1;}) 
        begin
          `uvm_error("input_sequence", "rand failure")
        end
      //assert (tx.randomize() with {v_i==1'b1;});
      finish_item(tx);

      // Wait for packet to actually be sent
      wait_for_item_done();
    endtask : body

  endclass : input_sequence

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
      tx.icache_pkt_i = '0;
      tx.v_i          = '0;
      finish_item(tx);
    endtask : body

  endclass : zero_sequence

  // Calls fetch instruction at given vaddr
  class fetch_sequence extends uvm_sequence #(input_transaction);
    `uvm_object_utils(fetch_sequence)
    input_transaction tx;
    bp_fe_icache_pkt_s seq_pkt;

    function new (string name = "fetch_sequence");
      super.new(name);
    endfunction: new

    task body;
      tx = input_transaction::type_id::create("tx");
      start_item(tx);
      seq_pkt.op = e_icache_fetch;
      tx.icache_pkt_i = seq_pkt;
      tx.v_i = 1'b1;
      `uvm_info("fetch_sequence", $psprintf("Generated fetch request with op %d\t vaddr %d\n", 
                seq_pkt.op, seq_pkt.vaddr), UVM_LOW);
      finish_item(tx);

      `uvm_info("fetch_sequence", "done", UVM_HIGH);
    endtask : body

  endclass : fetch_sequence

  // Calls fill instruction at given vaddr
  class fill_sequence extends uvm_sequence #(input_transaction);
    `uvm_object_utils(fill_sequence)
    input_transaction tx;
    bp_fe_icache_pkt_s seq_pkt;
    logic v_i = 1'b1;

    function new (string name = "fill_sequence");
      super.new(name);
    endfunction: new

    task body;
      tx = input_transaction::type_id::create("tx");

      `uvm_info("fill_sequence", "started", UVM_HIGH);

      start_item(tx);
      seq_pkt.op = e_icache_fill;
      tx.icache_pkt_i = seq_pkt;
      tx.v_i = v_i;
      `uvm_info("fill_sequence", $psprintf("Generated fill request with op %d\t vaddr %d\n", 
                seq_pkt.op, seq_pkt.vaddr), UVM_LOW);
      finish_item(tx);

      `uvm_info("fill_sequence", "done", UVM_HIGH);
    endtask : body

  endclass : fill_sequence

  // Sends a given ptag to the cache
  class tlb_zero_sequence extends uvm_sequence #(tlb_transaction);
    `uvm_object_utils(tlb_zero_sequence)
    tlb_transaction tx;

    function new (string name = "tlb_zero_sequence");
      super.new(name);
    endfunction: new

    task body;
      tx = tlb_transaction::type_id::create("tx");

      `uvm_info(get_type_name(), "started", UVM_HIGH);

      start_item(tx);
      tx.ptag_i = '0;
      tx.ptag_v_i = 1'b0;
      tx.ptag_uncached_i = 1'b0;
      tx.ptag_dram_i = 1'b0;
      tx.ptag_nonidem_i = 1'b0;
      finish_item(tx);

      `uvm_info(get_type_name(), "done", UVM_HIGH);
    endtask : body
  endclass : tlb_zero_sequence

  // Sends a given ptag to the cache
  class ptag_sequence extends uvm_sequence #(tlb_transaction);
    `uvm_object_utils(ptag_sequence)
    tlb_transaction tx;
    logic [ptag_width_p-1:0] ptag_i;
    bit is_cached = 1'b1;

    function new (string name = "ptag_sequence");
      super.new(name);
    endfunction: new

    task body;
      tx = tlb_transaction::type_id::create("tx");

      `uvm_info(get_type_name(), "started", UVM_HIGH);

      start_item(tx);
      tx.ptag_i = ptag_i;
      tx.ptag_v_i = 1'b1;
      tx.ptag_uncached_i = ~is_cached;
      tx.ptag_dram_i = 1'b1;
      tx.ptag_nonidem_i = 1'b0;
      `uvm_info(get_type_name(), $psprintf("Generated ptag sequence with ptag %d", ptag_i), UVM_LOW);
      finish_item(tx);

      `uvm_info(get_type_name(), "done", UVM_HIGH);
    endtask : body

  endclass : ptag_sequence

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

endclass : myvseq_base

class test_load_vseq extends myvseq_base;
  `uvm_object_utils(test_load_vseq);

  function new (string name = "test_load_vseq");
    super.new(name);
  endfunction: new

  task body();
    fill_sequence test_seq = fill_sequence::type_id::create("test_seq");
    zero_sequence z_seq = zero_sequence::type_id::create("z_seq");
    ptag_sequence ptag_seq = ptag_sequence::type_id::create("ptag_seq");
    tlb_zero_sequence tz_seq = tlb_zero_sequence::type_id::create("tz_seq");

    `uvm_info("test_load_vseq", "starting sequence", UVM_HIGH);

    // Ask for fill from 0, 4, and 8
    ptag_seq.ptag_i = 28'h0080000;
    fork
      for(int i = 0; i <= 8; i+=4) 
        begin
          test_seq.seq_pkt.vaddr = (1'b1 << 'd31) | i;
          test_seq.start(input_sequencer_h, this);
        end
      repeat(3) ptag_seq.start(tlb_sequencer_h, this);
    join

    // Do 2 cycles of nothing
    fork
      repeat(2) z_seq.start(input_sequencer_h, this);
      repeat(2) tz_seq.start(tlb_sequencer_h, this);
    join

    // Ask for fill from addresses 0,4,8,12,...,60
    fork
      begin
        for(int i = 0; i < 64; i+=4) 
          begin
            test_seq.seq_pkt.vaddr = (1'b1 << 'd31) | i;
            test_seq.start(input_sequencer_h, this);
          end
        test_seq.start(input_sequencer_h, this);
      end
      repeat(16) ptag_seq.start(tlb_sequencer_h, this);
    join

    // Do nothing after that
    fork
      z_seq.start(input_sequencer_h, this);
      tz_seq.start(tlb_sequencer_h, this);
    join

    `uvm_info("test_load_vseq", "sequence finished", UVM_HIGH);
  endtask : body
endclass : test_load_vseq

class test_uncached_load_vseq extends myvseq_base;
  `uvm_object_utils(test_uncached_load_vseq);

  function new (string name = "test_uncached_load_vseq");
    super.new(name);
  endfunction: new

  task body();
    fill_sequence test_seq = fill_sequence::type_id::create("test_seq");
    zero_sequence z_seq = zero_sequence::type_id::create("z_seq");
    ptag_sequence ptag_seq = ptag_sequence::type_id::create("ptag_seq");
    tlb_zero_sequence tz_seq = tlb_zero_sequence::type_id::create("tz_seq");

    test_seq.seq_pkt.vaddr = (1'b1 << 'd31) | 'h24;
    ptag_seq.ptag_i = 28'h0080000;
    ptag_seq.is_cached = 1'b0;

    `uvm_info("test_uncached_load_vseq", "starting sequence", UVM_HIGH);

    // Ask for fill from 0x24
    fork
      repeat(2) test_seq.start(input_sequencer_h, this);
      repeat(2) ptag_seq.start(tlb_sequencer_h, this);
    join

    // Do 2 cycles of nothing
    fork
      repeat(2) z_seq.start(input_sequencer_h, this);
      repeat(2) tz_seq.start(tlb_sequencer_h, this);
    join

    // Ask for fill from 0x24
    fork
      repeat(2) test_seq.start(input_sequencer_h, this);
      repeat(2) ptag_seq.start(tlb_sequencer_h, this);
    join

    // Do nothing after that
    fork
      z_seq.start(input_sequencer_h, this);
      tz_seq.start(tlb_sequencer_h, this);
    join

    `uvm_info("test_uncached_load_vseq", "sequence finished", UVM_HIGH);
  endtask : body

endclass : test_uncached_load_vseq

endpackage : icache_uvm_seq_pkg
`endif
