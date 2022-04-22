// Devin Bidstrup 2022
// UVM Subscribers for BP L1 ICache Testbench

`ifndef ICACHE_SUBS_PKG
`define ICACHE_SUBS_PKG

`include "icache_uvm_seq_pkg.sv"
`include "icache_uvm_params_pkg.sv"
`include "uvm_macros.svh"

package icache_uvm_subs_pkg;

  import uvm_pkg :: *;
  import icache_uvm_params_pkg::*;
  import icache_uvm_seq_pkg::*;
  import bp_common_pkg::*;

  //.......................................................
  // Coverage Collector
  //.......................................................
  `uvm_analysis_imp_decl(_INPUT)
  `uvm_analysis_imp_decl(_TLB)
  `uvm_analysis_imp_decl(_OUTPUT)
  `uvm_analysis_imp_decl(_CE)
  class icache_cov_col extends uvm_component;
    `uvm_component_utils(icache_cov_col)

    uvm_analysis_imp_INPUT  #(input_transaction, icache_cov_col)  input_export;
    uvm_analysis_imp_TLB    #(tlb_transaction, icache_cov_col)    tlb_export;
    uvm_analysis_imp_OUTPUT #(output_transaction, icache_cov_col) output_export;
    uvm_analysis_imp_CE     #(ce_transaction, icache_cov_col)     ce_export;

    logic                                     reset_i;
    logic [cfg_bus_width_lp-1:0]              cfg_bus_i;
    logic [icache_pkt_width_lp-1:0]           icache_pkt_i;
    logic                                     v_i;
    logic                                     ready_o;
    logic [ptag_width_p-1:0]                  ptag_i;
    logic                                     ptag_v_i;
    logic                                     ptag_uncached_i;
    logic                                     ptag_dram_i;
    logic                                     ptag_nonidem_i;
    logic                                     poison_tl_i;
    logic [instr_width_gp-1:0]                data_o;
    logic                                     data_v_o;
    logic                                     miss_v_o;
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


    covergroup cover_input;
      coverpoint icache_pkt_i 
      {
        bins range[10] = {[0:$]};
      }
      coverpoint v_i;
      coverpoint ready_o;
      coverpoint cfg_bus_i;
      coverpoint reset_i;

      input_cross: cross icache_pkt_i, v_i, ready_o;

    endgroup : cover_input

    covergroup cover_tlb;
      coverpoint ptag_i;
      coverpoint ptag_v_i;
      coverpoint ptag_uncached_i;
      coverpoint ptag_dram_i;
      coverpoint ptag_nonidem_i;
      coverpoint poison_tl_i;
    endgroup : cover_tlb

    covergroup cover_output;
      coverpoint data_o;
      coverpoint data_v_o;
      coverpoint miss_v_o;
    endgroup : cover_output

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
    endgroup : cover_ce

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cover_input  = new;
      cover_tlb    = new;
      cover_output = new;
      cover_ce     = new;
    endfunction : new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      input_export  = new("input_export", this);
      tlb_export    = new("tlb_export", this);
      output_export = new("output_export", this);
      ce_export     = new("ce_export", this);
    endfunction : build_phase

    function void write_INPUT(input_transaction t);
      //Print the received transacton
      `uvm_info("coverage_collector",
                $psprintf("Coverage collector received input tx %s",
                t.convert2string()), UVM_HIGH);

      //Sample coverage info
      reset_i       = t.reset_i;
      icache_pkt_i  = t.icache_pkt_i;
      v_i           = t.v_i;
      ready_o       = t.ready_o;
      cover_input.sample();

    endfunction : write_INPUT

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
      cover_output.sample();

    endfunction : write_OUTPUT

    function void write_CE(ce_transaction t);
      //Print the received transacton
      `uvm_info("coverage_collector",
                $psprintf("Coverage collector received ce tx %s",
                t.convert2string()), UVM_HIGH);

      //Sample coverage info
      cache_req_o                = t.cache_req_o;
      cache_req_v_o 	           = t.cache_req_v_o;
      cache_req_yumi_i           = t.cache_req_yumi_i;
      cache_req_busy_i           = t.cache_req_busy_i;
      cache_req_metadata_o       = t.cache_req_metadata_o;
      cache_req_metadata_v_o     = t.cache_req_metadata_v_o;
      cache_req_critical_tag_i   = t.cache_req_critical_tag_i;
      cache_req_critical_data_i  = t.cache_req_critical_data_i;
      cache_req_complete_i       = t.cache_req_complete_i;
      cache_req_credits_full_i   = t.cache_req_credits_full_i;
      cache_req_credits_empty_i  = t.cache_req_credits_empty_i;
      cover_ce.sample();

    endfunction : write_CE

  endclass : icache_cov_col

  // //.......................................................
  // // Predictor
  // //.......................................................
  class icache_predictor extends uvm_component;

    `uvm_component_utils(icache_predictor)

    uvm_analysis_port     #(input_transaction)  input_export;
    uvm_analysis_port     #(tlb_transaction)    tlb_export;
    uvm_analysis_port     #(output_transaction) results_aport;
    
    uvm_tlm_analysis_fifo #(input_transaction)  input_fifo;
    uvm_tlm_analysis_fifo #(tlb_transaction)    tlb_fifo;

    output_transaction result;
    int ip_tx_id_cntr = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      input_export  = new("input_export", this);
      tlb_export    = new("tlb_export", this);
      results_aport = new("results_aport", this);
      input_fifo    = new("input_fifo", this);
      tlb_fifo      = new("tlb_fifo", this);
      result        = output_transaction::type_id::create("result");
    endfunction : build_phase

    function void connect_phase (uvm_phase phase);
      input_export.connect(input_fifo.analysis_export);
      tlb_export  .connect(tlb_fifo.analysis_export);
    endfunction : connect_phase

    task run_phase (uvm_phase phase);
      input_transaction ip_tx;
      tlb_transaction   tlb_tx;
      forever 
        begin
          input_fifo.get(ip_tx);
          tlb_fifo.get(tlb_tx);
          if (ip_tx .v_i == 1'b1 || tlb_tx.ptag_v_i == 1'b1) 
            begin
              //Print the received transacton
              `uvm_info("predictor",
                      $psprintf("received input tx %s and tlb tx %s",
                      ip_tx.convert2string(), tlb_tx.convert2string()), UVM_HIGH);

              //Insert functional model here instead of fixed values
              result.data_v_o = 1'b1;
              result.data_o   = '1;
              result.miss_v_o = 1'b0;
              result.tx_id    = ip_tx_id_cntr++;

              results_aport.write(result);
            end
        end
    endtask : run_phase
  endclass : icache_predictor

  //.......................................................
  // Comparator
  //.......................................................
  `uvm_analysis_imp_decl(_PRED)
  `uvm_analysis_imp_decl(_DUT)
  class icache_comparator extends uvm_component;
    `uvm_component_utils(icache_comparator)

    uvm_analysis_imp_PRED #(output_transaction,icache_comparator) pred_export;
    uvm_analysis_imp_DUT  #(output_transaction,icache_comparator) dut_export;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      pred_export = new("input_export", this);
      dut_export  = new("tlb_export", this);
    endfunction : build_phase

    function void write_PRED(output_transaction t);
      //Print the received transacton
      `uvm_info("comparator_pred",
                $psprintf("received output tx %s with id %d",
                t.convert2string(), t.tx_id), UVM_HIGH);
    endfunction : write_PRED

    function void write_DUT(output_transaction t);
      //Print the received transacton
      `uvm_info("comparator_dut",
                $psprintf("received output tx %s with id %d",
                t.convert2string(), t.tx_id), UVM_HIGH);
    endfunction : write_DUT
  endclass : icache_comparator

  //.......................................................
  // Scoreboard
  //.......................................................
  class icache_scoreboard extends uvm_component;

    `uvm_component_utils(icache_scoreboard)

    uvm_analysis_imp_INPUT  #(input_transaction,  icache_scoreboard) input_export;
    uvm_analysis_imp_TLB    #(tlb_transaction,    icache_scoreboard) tlb_export;
    uvm_analysis_imp_OUTPUT #(output_transaction, icache_scoreboard) output_export;

    uvm_analysis_port #(input_transaction)  input_aport;
    uvm_analysis_port #(tlb_transaction)    tlb_aport;
    uvm_analysis_port #(output_transaction) output_aport;

    input_transaction  t_cpy_ip;
    tlb_transaction    t_cpy_tlb;
    output_transaction t_cpy_op;
    int op_tx_id_cntr = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      input_export  = new("input_export", this);
      tlb_export    = new("tlb_export", this);
      output_export = new("output_export", this);
      input_aport   = new("input_aport", this);
      tlb_aport     = new("tlb_aport", this);
      output_aport  = new("output_aport", this);
    endfunction : build_phase

    function void write_INPUT(input_transaction t);
      //Print the received transacton
      `uvm_info("scoreboard_ip",
                $psprintf("received input tx %s",
                t.convert2string()), UVM_HIGH);

      //Give input transaction to predictor
      t_cpy_ip = input_transaction::type_id::create("t_cpy_ip");
      t_cpy_ip.copy(t);
      input_aport.write(t_cpy_ip);
    endfunction : write_INPUT

    function void write_TLB(tlb_transaction t);
      //Print the received transacton
      `uvm_info("scoreboard_tlb",
                $psprintf("received tlb tx %s",
                t.convert2string()), UVM_HIGH);

      //Give tlb transaction to predictor
      t_cpy_tlb = tlb_transaction::type_id::create("t_cpy_tlb");
      t_cpy_tlb.copy(t);
      tlb_aport.write(t_cpy_tlb);
    endfunction : write_TLB

    function void write_OUTPUT(output_transaction t);
      //Print the received transacton
      `uvm_info("scoreboard_op",
                $psprintf("received output tx %s",
                t.convert2string()), UVM_HIGH);

      //Drive output to OOO comparator
      if (t.data_v_o == 1'b1 | t.miss_v_o == 1'b1) 
        begin
          t_cpy_op = output_transaction::type_id::create("t_cpy_op");
          t_cpy_op.copy(t);
          t_cpy_op.tx_id = op_tx_id_cntr++;
          output_aport.write(t_cpy_op);
        end
    endfunction : write_OUTPUT

  endclass : icache_scoreboard

endpackage : icache_uvm_subs_pkg
`endif
