/**
 * bp_be_pipe_int_sequence.sv
 * UVM sequences for bp_be_pipe_int testbench.
 * Provides:
 *   - bp_be_pipe_int_rand_seq   : fully random constrained stimulus
 *   - bp_be_pipe_int_alu_seq    : targeted ALU op coverage
 *   - bp_be_pipe_int_branch_seq : targeted branch/jump coverage
 *   - bp_be_pipe_int_flush_seq  : flush behaviour
 */
`ifndef BP_BE_PIPE_INT_SEQUENCE_SV
`define BP_BE_PIPE_INT_SEQUENCE_SV

//--------------------------------------------------------------------
// Base sequence
//--------------------------------------------------------------------
class bp_be_pipe_int_base_seq extends uvm_sequence #(bp_be_pipe_int_transaction);
  `uvm_object_utils(bp_be_pipe_int_base_seq)

  int unsigned num_transactions = 200;

  function new(string name = "bp_be_pipe_int_base_seq");
    super.new(name);
  endfunction
endclass

//--------------------------------------------------------------------
// 1. Random sequence — default workhorse
//--------------------------------------------------------------------
class bp_be_pipe_int_rand_seq extends bp_be_pipe_int_base_seq;
  `uvm_object_utils(bp_be_pipe_int_rand_seq)

  function new(string name = "bp_be_pipe_int_rand_seq");
    super.new(name);
  endfunction

  task body();
    bp_be_pipe_int_transaction tr;
    repeat(num_transactions) begin
      tr = bp_be_pipe_int_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize())
        `uvm_fatal("SEQ", "Randomization failed")
      finish_item(tr);
    end
  endtask
endclass

//--------------------------------------------------------------------
// 2. ALU coverage sequence — walks through every fu_op value
//--------------------------------------------------------------------
class bp_be_pipe_int_alu_seq extends bp_be_pipe_int_base_seq;
  `uvm_object_utils(bp_be_pipe_int_alu_seq)

  function new(string name = "bp_be_pipe_int_alu_seq");
    super.new(name);
  endfunction

  task body();
    bp_be_pipe_int_transaction tr;
    // Send 10 transactions per fu_op value (0-15)
    for (int op = 0; op < 16; op++) begin
      repeat(10) begin
        tr = bp_be_pipe_int_transaction::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {
              fu_op      == op;
              pipe_int_v == 1'b1;
              en_i       == 1'b1;
              v          == 1'b1;
              flush_i    == 1'b0;
              br_v       == 1'b0;
              j_v        == 1'b0;
              jr_v       == 1'b0;
            })
          `uvm_fatal("SEQ", "ALU seq randomization failed")
        finish_item(tr);
      end
    end
  endtask
endclass

//--------------------------------------------------------------------
// 3. Branch/jump sequence — exercises npc and btaken logic
//--------------------------------------------------------------------
class bp_be_pipe_int_branch_seq extends bp_be_pipe_int_base_seq;
  `uvm_object_utils(bp_be_pipe_int_branch_seq)

  function new(string name = "bp_be_pipe_int_branch_seq");
    super.new(name);
  endfunction

  task body();
    bp_be_pipe_int_transaction tr;

    // --- Conditional branches (br_v=1) ---
    repeat(50) begin
      tr = bp_be_pipe_int_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
            pipe_int_v == 1'b1;
            en_i       == 1'b1;
            v          == 1'b1;
            flush_i    == 1'b0;
            br_v       == 1'b1;
            j_v        == 1'b0;
            jr_v       == 1'b0;
            // Use eq/ne/slt for comparison ops
            fu_op inside {4'd8, 4'd9, 4'd10, 4'd11};
          })
        `uvm_fatal("SEQ", "Branch seq randomization failed")
      finish_item(tr);
    end

    // --- JAL (j_v=1) ---
    repeat(30) begin
      tr = bp_be_pipe_int_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
            pipe_int_v == 1'b1;
            en_i       == 1'b1;
            v          == 1'b1;
            flush_i    == 1'b0;
            br_v       == 1'b0;
            j_v        == 1'b1;
            jr_v       == 1'b0;
          })
        `uvm_fatal("SEQ", "JAL seq randomization failed")
      finish_item(tr);
    end

    // --- JALR (jr_v=1) ---
    repeat(30) begin
      tr = bp_be_pipe_int_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {
            pipe_int_v == 1'b1;
            en_i       == 1'b1;
            v          == 1'b1;
            flush_i    == 1'b0;
            br_v       == 1'b0;
            j_v        == 1'b0;
            jr_v       == 1'b1;
          })
        `uvm_fatal("SEQ", "JALR seq randomization failed")
      finish_item(tr);
    end
  endtask
endclass

//--------------------------------------------------------------------
// 4. Flush sequence — verifies pipeline flushes cleanly
//--------------------------------------------------------------------
class bp_be_pipe_int_flush_seq extends bp_be_pipe_int_base_seq;
  `uvm_object_utils(bp_be_pipe_int_flush_seq)

  function new(string name = "bp_be_pipe_int_flush_seq");
    super.new(name);
  endfunction

  task body();
    bp_be_pipe_int_transaction tr;
    // Interleave normal transactions with flush pulses
    repeat(20) begin
      // 5 normal
      repeat(5) begin
        tr = bp_be_pipe_int_transaction::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with {flush_i == 1'b0; pipe_int_v == 1'b1;})
          `uvm_fatal("SEQ", "Flush seq normal randomization failed")
        finish_item(tr);
      end
      // 1 flush
      tr = bp_be_pipe_int_transaction::type_id::create("tr");
      start_item(tr);
      if (!tr.randomize() with {flush_i == 1'b1;})
        `uvm_fatal("SEQ", "Flush seq flush randomization failed")
      finish_item(tr);
    end
  endtask
endclass

`endif
