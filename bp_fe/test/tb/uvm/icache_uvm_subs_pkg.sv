// UVM Subscribers for BP L1 ICache Testbench

`ifndef ICACHE_SUBS_PKG
`define ICACHE_SUBS_PKG

`include "uvm_macros.svh"

package icache_uvm_subs_pkg;

  import uvm_pkg :: *;
  import icache_uvm_params_pkg::*;
  import icache_uvm_seq_pkg::*;
  import bp_common_pkg::*;

  //.......................................................
  // Coverage Collector
  //.......................................................
  `uvm_analysis_imp_decl(_input)
  `uvm_analysis_imp_decl(_tlb)
  `uvm_analysis_imp_decl(_output)
  `uvm_analysis_imp_decl(_ce)
  `uvm_analysis_imp_decl(_ram)
  class icache_cov_col extends uvm_component;
    `uvm_component_utils(icache_cov_col)

    uvm_analysis_imp_input  #(input_transaction, icache_cov_col)  input_export;
    uvm_analysis_imp_tlb    #(tlb_transaction, icache_cov_col)    tlb_export;
    uvm_analysis_imp_output #(output_transaction, icache_cov_col) output_export;
    uvm_analysis_imp_ce     #(ce_transaction, icache_cov_col)     ce_export;
    uvm_analysis_imp_ram    #(ram_transaction, icache_cov_col)    ram_export;

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

    logic                                     mem_cmd_v_lo;
    logic                                     mem_resp_v_li;
    logic                                     mem_cmd_ready_and_li;
    logic                                     mem_resp_ready_and_lo;
    logic                                     mem_cmd_last_lo;
    logic                                     mem_resp_last_li;
    bp_bedrock_cce_mem_header_s               mem_cmd_header_lo;
    bp_bedrock_cce_mem_header_s               mem_resp_header_li;
    logic [l2_fill_width_p-1:0]               mem_cmd_data_lo;
    logic [l2_fill_width_p-1:0]               mem_resp_data_li; 

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

    covergroup cover_ram;
      coverpoint mem_cmd_v_lo;
      coverpoint mem_resp_v_li;
      coverpoint mem_cmd_ready_and_li;
      coverpoint mem_resp_ready_and_lo;
      coverpoint mem_cmd_last_lo;
      coverpoint mem_resp_last_li;
      coverpoint mem_cmd_header_lo;
      coverpoint mem_resp_header_li;
      coverpoint mem_cmd_data_lo;
      coverpoint mem_resp_data_li;    
    endgroup : cover_ram

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cover_input  = new;
      cover_tlb    = new;
      cover_output = new;
      cover_ce     = new;
      cover_ram    = new;
    endfunction : new

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      input_export  = new("input_export",  this);
      tlb_export    = new("tlb_export",    this);
      output_export = new("output_export", this);
      ce_export     = new("ce_export",     this);
      ram_export    = new("ran_export",    this);
    endfunction : build_phase

    function void write_input(input_transaction t);
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

    endfunction : write_input

    function void write_tlb(tlb_transaction t);
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

    endfunction : write_tlb

    function void write_output(output_transaction t);
      //Print the received transacton
      `uvm_info("coverage_collector",
                $psprintf("Coverage collector received output tx %s",
                t.convert2string()), UVM_HIGH);

      //Sample coverage info
      data_o            = t.data_o;
      data_v_o 	        = t.data_v_o;
      miss_v_o          = t.miss_v_o;
      cover_output.sample();

    endfunction : write_output

    function void write_ce(ce_transaction t);
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

    endfunction : write_ce

    function void write_ram(ram_transaction t);
      //Print the reramived transacton
      `uvm_info("coverage_collector",
                $psprintf("Coverage collector reramived ram tx %s",
                t.convert2string()), UVM_HIGH);

      //Sample coverage info
      mem_cmd_v_lo          = t.mem_cmd_v_lo;
      mem_resp_v_li         = t.mem_resp_v_li;
      mem_cmd_ready_and_li  = t.mem_cmd_ready_and_li;
      mem_resp_ready_and_lo = t.mem_resp_ready_and_lo;
      mem_cmd_last_lo       = t.mem_cmd_last_lo;
      mem_resp_last_li      = t.mem_resp_last_li;
      mem_cmd_header_lo     = t.mem_cmd_header_lo;
      mem_resp_header_li    = t.mem_resp_header_li;
      mem_cmd_data_lo       = t.mem_cmd_data_lo;
      mem_resp_data_li      = t.mem_resp_data_li;
      cover_ram.sample();

    endfunction : write_ram
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
          if ((ip_tx.v_i == 1'b1 || tlb_tx.ptag_v_i == 1'b1) & ip_tx.ready_o == 1'b1)
            begin
              //Print the received transacton
              `uvm_info("predictor",
                      $psprintf("received input tx %s and tlb tx %s",
                      ip_tx.convert2string(), tlb_tx.convert2string()), UVM_HIGH);

              //Insert functional model here instead of fixed values
              result.data_v_o = 1'b1;
              result.data_o   = ip_tx.icache_pkt_i[icache_pkt_width_lp-vaddr_width_p +: 8];
              result.miss_v_o = 1'b0;
              result.tx_id[0 +: vaddr_width_p] = ip_tx.icache_pkt_i[icache_pkt_width_lp-1:
                                                icache_pkt_width_lp-vaddr_width_p];
              results_aport.write(result);
            end
        end
    endtask : run_phase
  endclass : icache_predictor

  //.......................................................
  // Comparator
  //.......................................................
  // Out of order comparator adapted from https://verificationacademy.com/cookbook/scoreboards
  // and then modified to suit our needs herein.
  class icache_comparator
    #(type T = output_transaction,
      type IDX = longint)
    extends uvm_component;

    typedef icache_comparator #(T, IDX) this_type;
    `uvm_component_param_utils(this_type)

    typedef T q_of_T[$];
    typedef IDX q_of_IDX[$];

    uvm_analysis_export #(T) dut_export, pred_export;

    protected uvm_tlm_analysis_fifo #(T) dut_fifo, pred_fifo;
    bit before_queued = 0;
    bit after_queued = 0;

    protected int m_matches, m_mismatches;

    protected q_of_T received_data[IDX];
    protected int rcv_count[IDX];

    protected process before_proc = null;
    protected process after_proc  = null;

    protected int total_missing;
    protected q_of_IDX missing_idxs;
    protected IDX missing_idx;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase( uvm_phase phase );
      dut_export = new("dut_export", this);
      pred_export = new("pred_export", this);
      dut_fifo = new("dut_fifo", this);
      pred_fifo = new("pred_fifo", this);
    endfunction : build_phase

    function void connect_phase( uvm_phase phase );
      dut_export.connect(dut_fifo.analysis_export);
      pred_export.connect(pred_fifo.analysis_export);
    endfunction : connect_phase

    // The component forks two concurrent instantiations of this task
    // Each instantiation monitors an input analysis fifo
    protected task get_data(ref uvm_tlm_analysis_fifo #(T) txn_fifo, input bit is_before);
      T txn_in, txn_data, txn_existing;
      IDX idx;
      string rs;
      q_of_T tmpq;
      bit need_to_compare;

      forever
        begin
          // Get the transaction object, block if no transaction available
          txn_data = T::type_id::create("txn_data");
          txn_fifo.get(txn_in);
          txn_data.copy(txn_in);
          if ((txn_data.data_v_o == 1'b1 | txn_data.miss_v_o == 1'b1) & (txn_data.tx_id != '0))
            begin
              idx = txn_data.tx_id;

              // Check to see if there is an existing object to compare
              need_to_compare = (rcv_count.exists(idx) &&
                                ((is_before && rcv_count[idx] > 0) ||
                                (!is_before && rcv_count[idx] < 0)));
              if (need_to_compare)
                begin
                  // Compare objects using compare() method of transaction
                  tmpq = received_data[idx];
                  txn_existing = tmpq.pop_front();
                  received_data[idx] = tmpq;
                  `uvm_info("comparator is comparing", $psprintf("Comparing %s to %s",
                    txn_data.convert2string(), txn_existing.convert2string()), UVM_MEDIUM);
                  if (txn_data.compare(txn_existing))
                    m_matches++;
                  else
                    m_mismatches++;

                  //Delete entries after the comparison
                  received_data.delete(idx);
                  rcv_count.delete(idx);
                end
              else
                begin
                  // If no compare happened, add the new entry
                  if (received_data.exists(idx))
                    tmpq = received_data[idx];
                  else
                    tmpq = {};

                  tmpq.push_back(txn_data);
                  received_data[idx] = tmpq;

                  // Update the index count
                  if (is_before)
                    if (rcv_count.exists(idx))
                      begin
                        rcv_count[idx]--;
                      end
                    else
                      begin
                        rcv_count[idx] = -1;
                      end
                  else
                    if (rcv_count.exists(idx))
                      begin
                        rcv_count[idx]++;
                      end
                    else
                      begin
                        rcv_count[idx] = 1;
                      end
                end
            end
        end // forever
    endtask

    virtual function int get_matches();
      return m_matches;
    endfunction : get_matches

    virtual function int get_mismatches();
      return m_mismatches;
    endfunction : get_mismatches

    virtual function int get_total_missing();
      int num_missing;
      foreach (rcv_count[i])
        begin
          num_missing += (rcv_count[i] < 0 ? -rcv_count[i] : rcv_count[i]);
        end
      return num_missing;
    endfunction : get_total_missing

    virtual function int get_total_missing_unique();
      int num_missing;
      foreach (rcv_count[i])
        begin
          if (rcv_count[i] != 0)
            begin
              num_missing++;
            end
        end
      return num_missing;
    endfunction : get_total_missing_unique

    virtual function q_of_IDX get_missing_indexes();
      q_of_IDX rv = rcv_count.find_index() with (item != 0);
      return rv;
    endfunction : get_missing_indexes;

    virtual function int get_missing_index_count(IDX i);
    // If count is < 0, more "before" txns were received
    // If count is > 0, more "after" txns were received
      if (rcv_count.exists(i))
        return rcv_count[i];
      else
        return 0;
    endfunction : get_missing_index_count;

    task run_phase( uvm_phase phase );
      fork
        get_data(dut_fifo, 1);
        get_data(pred_fifo, 0);
      join
    endtask : run_phase

    function void report_phase( uvm_phase phase);
      `uvm_info("Comparator", $sformatf("Matches:    %0d", get_matches()), UVM_LOW);
      `uvm_info("Comparator", $sformatf("Mismatches: %0d", get_mismatches()), UVM_LOW);
      total_missing = get_total_missing_unique();
      `uvm_info("Comparator", $sformatf("Total Missing:    %0d", total_missing), UVM_LOW);
      missing_idxs = get_missing_indexes();
      for (int i = 0; i < total_missing; i++)
        begin
          missing_idx = missing_idxs.pop_front();
          `uvm_info("Comparator", $sformatf("Miss Idx: %0x with count %0d", missing_idx,
                    get_missing_index_count(missing_idx)), UVM_MEDIUM);
        end
    endfunction : report_phase

  endclass : icache_comparator

  //.......................................................
  // Scoreboard
  //.......................................................
  class icache_scoreboard extends uvm_component;

    `uvm_component_utils(icache_scoreboard)

    uvm_analysis_imp_input  #(input_transaction,  icache_scoreboard) input_export;
    uvm_analysis_imp_tlb    #(tlb_transaction,    icache_scoreboard) tlb_export;
    uvm_analysis_imp_output #(output_transaction, icache_scoreboard) output_export;

    uvm_analysis_port #(input_transaction)  input_aport;
    uvm_analysis_port #(tlb_transaction)    tlb_aport;
    uvm_analysis_port #(output_transaction) output_aport;

    input_transaction  t_cpy_ip;
    tlb_transaction    t_cpy_tlb;
    output_transaction t_cpy_op;
    input_transaction inp_tx_q[$];
    input_transaction temp_tx, temp_tx_2;

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

      // Create queue to delay by two cycles
      temp_tx = input_transaction::type_id::create("temp_tx");
      temp_tx_2 = input_transaction::type_id::create("temp_tx_2");
      inp_tx_q.push_back(temp_tx);
      inp_tx_q.push_back(temp_tx);
    endfunction : build_phase

    function void write_input(input_transaction t);
      //Print the received transacton
      `uvm_info("scoreboard_ip",
                $psprintf("received input tx %s",
                t.convert2string()), UVM_HIGH);

      //Give input transaction to predictor
      t_cpy_ip = input_transaction::type_id::create("t_cpy_ip");
      t_cpy_ip.copy(t);
      input_aport.write(t_cpy_ip);

      //Add to queue to delay inputs transactions for the output by 2 cycles
      inp_tx_q.push_back(t_cpy_ip);
    endfunction : write_input

    function void write_tlb(tlb_transaction t);
      //Print the received transacton
      `uvm_info("scoreboard_tlb",
                $psprintf("received tlb tx %s",
                t.convert2string()), UVM_HIGH);

      //Give tlb transaction to predictor
      t_cpy_tlb = tlb_transaction::type_id::create("t_cpy_tlb");
      t_cpy_tlb.copy(t);
      tlb_aport.write(t_cpy_tlb);
    endfunction : write_tlb

    function void write_output(output_transaction t);
      //Print the received transacton
      `uvm_info("scoreboard_op",
                $psprintf("received output tx %s",
                t.convert2string()), UVM_HIGH);

      //Pop from input transaction queue
      temp_tx_2 = inp_tx_q.pop_front();

      //Drive output to OOO comparator
      if (t.data_v_o == 1'b1 | t.miss_v_o == 1'b1)
        begin
          t_cpy_op = output_transaction::type_id::create("t_cpy_op");
          t_cpy_op.copy(t);
          t_cpy_op.tx_id[0 +: vaddr_width_p] = temp_tx_2.icache_pkt_i[icache_pkt_width_lp-1:
                                               icache_pkt_width_lp-vaddr_width_p];
          `uvm_info("scoreboard_op_vaddr", $psprintf("%0x\n", t_cpy_op.tx_id), UVM_MEDIUM);
          output_aport.write(t_cpy_op);
        end
    endfunction : write_output

  endclass : icache_scoreboard

endpackage : icache_uvm_subs_pkg
`endif

