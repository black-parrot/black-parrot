/**
 * bp_be_pipe_int_scoreboard.sv
 * UVM scoreboard for bp_be_pipe_int testbench.
 * Receives input transactions from the sequence and output
 * transactions from the monitor, computes expected results
 * independently, and compares against DUT outputs.
 *
 * Checks verified:
 *   1. v_o    : asserted iff en_i && reservation.v && pipe_int_v
 *   2. data_o : ALU result matches reference model
 *   3. branch_o / btaken_o : branch/jump decode correct
 *   4. npc_o  : next-PC correct for taken/not-taken
 *   5. instr_misaligned_v_o : misalignment detection
 */
`ifndef BP_BE_PIPE_INT_SCOREBOARD_SV
`define BP_BE_PIPE_INT_SCOREBOARD_SV

class bp_be_pipe_int_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(bp_be_pipe_int_scoreboard)

  // Receive observed DUT outputs
  uvm_analysis_imp #(bp_be_pipe_int_output_transaction,
                     bp_be_pipe_int_scoreboard) analysis_export;

  // Queue of input transactions sent by the sequence
  bp_be_pipe_int_transaction inp_q[$];

  // Counters
  int unsigned checks_passed;
  int unsigned checks_failed;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    checks_passed = 0;
    checks_failed = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export", this);
  endfunction

  // Called by agent to push input transactions in order
  function void write_input(bp_be_pipe_int_transaction tr);
    inp_q.push_back(tr);
  endfunction

  // Called by monitor via analysis port for each valid output
  function void write(bp_be_pipe_int_output_transaction obs);
    bp_be_pipe_int_transaction inp;
    logic [63:0] exp_data;
    logic        exp_v;
    logic        exp_branch, exp_btaken;
    logic [38:0] exp_npc;
    logic        exp_misaligned;

    if (inp_q.size() == 0) begin
      `uvm_error("SB", "Got output with empty input queue!")
      return;
    end

    inp = inp_q.pop_front();

    // 1. Compute expected v_o
    exp_v = inp.en_i & inp.v & inp.pipe_int_v;

    // 2. Reference ALU model
    exp_data = compute_alu(inp);

    // 3. Branch/jump
    exp_branch  = inp.br_v | inp.j_v | inp.jr_v;
    exp_btaken  = (inp.br_v & compute_comp(inp)) | inp.j_v | inp.jr_v;

    // 4. NPC
    begin
      logic [38:0] baddr, taken_raw, taken_tgt, ntaken_tgt;
      baddr      = inp.jr_v ? inp.rs1[38:0] : inp.pc;
      taken_raw  = baddr + inp.imm[38:0];
      taken_tgt  = taken_raw & 39'h7FFFFFFE; // clear bit 0
      ntaken_tgt = inp.pc + (inp.size << 1);
      exp_npc    = exp_btaken ? taken_tgt : ntaken_tgt;
    end

    // 5. Misalignment (compressed_support_p=0 in default cfg)
    begin
      logic [38:0] baddr2, taken2;
      baddr2 = inp.jr_v ? inp.rs1[38:0] : inp.pc;
      taken2 = (baddr2 + inp.imm[38:0]) & 39'h7FFFFFFE;
      exp_misaligned = inp.en_i & exp_btaken & (taken2[1:0] != 2'b00);
    end

    // Compare and report
    check_field("v_o",    obs.v_o,                  exp_v,         inp);
    check_field("branch", obs.branch_o,              exp_branch,    inp);
    check_field("btaken", obs.btaken_o,              exp_btaken,    inp);
    check_field("misalign",obs.instr_misaligned_v_o, exp_misaligned,inp);

    if (obs.v_o) begin
      check_field64("data_o", obs.data_o, exp_data, inp);
      check_npc("npc_o", obs.npc_o, exp_npc, inp);
    end
  endfunction

  //------------------------------------------------------------------
  // Reference ALU
  //------------------------------------------------------------------
  function automatic logic [63:0] compute_alu(bp_be_pipe_int_transaction t);
    logic [63:0] src1, src2, result;
    logic [5:0]  shamt;
    logic        opw_v;
    logic        comp;

    opw_v = t.irs1_tag; // 1 = word op

    // src1 mux (simplified — main cases)
    case (t.src1_sel)
      3'd0: src1 = t.rs1[63:0];  // e_src1_is_rs1
      3'd4: src1 = '0;            // e_src1_is_zero
      default: src1 = t.rs1[63:0];
    endcase

    // src2 mux
    case (t.src2_sel)
      3'd0: src2 = t.irs2_r_v ? t.rs2[63:0] : t.imm[63:0]; // e_src2_is_rs2
      3'd1: src2 = ~t.rs2[63:0];  // e_src2_is_rs2n
      default: src2 = t.imm[63:0];
    endcase

    shamt = (t.irs2_r_v ? t.rs2[5:0] : t.imm[5:0])
            & {!opw_v, 5'b11111};
    comp  = compute_comp(t);

    case (t.fu_op)
      4'd0:  result = src1 + src2 + t.carryin; // add
      4'd1:  result = src1 ^ src2;              // xor
      4'd2:  result = src1 | src2;              // or
      4'd3:  result = src1 & src2;              // and
      4'd10: result = {63'b0, comp};            // slt/sltu/eq/ne
      default: result = src1 + src2 + t.carryin;
    endcase

    // Word boxing: sign-extend [31:0] if word op
    if (opw_v)
      result = {{32{result[31]}}, result[31:0]};

    return result;
  endfunction

  function automatic logic compute_comp(bp_be_pipe_int_transaction t);
    logic [64:0] sum;
    logic        carry, sum_sign, sum_zero;
    logic [63:0] src1, src2;
    src1  = t.rs1[63:0];
    src2  = t.src2_sel == 3'd1 ? ~t.rs2[63:0] : t.rs2[63:0];
    sum   = {src1[63], src1} + {src2[63], src2} + t.carryin;
    carry     = sum[64];
    sum_sign  = sum[63];
    sum_zero  = ~|sum[63:0];
    case (t.fu_op)
      4'd10: return  sum_sign;  // slt
      4'd11: return !carry;     // sltu
      4'd8:  return !sum_zero;  // ne
      default: return sum_zero; // eq
    endcase
  endfunction

  //------------------------------------------------------------------
  // Check helpers
  //------------------------------------------------------------------
  function void check_field(string name, logic obs, logic exp,
                             bp_be_pipe_int_transaction inp);
    if (obs !== exp) begin
      `uvm_error("SB", $sformatf(
        "MISMATCH %s: got %0b exp %0b | %s", name, obs, exp,
        inp.convert2string()))
      checks_failed++;
    end else begin
      checks_passed++;
    end
  endfunction

  function void check_field64(string name, logic [63:0] obs,
                               logic [63:0] exp,
                               bp_be_pipe_int_transaction inp);
    if (obs !== exp) begin
      `uvm_error("SB", $sformatf(
        "MISMATCH %s: got 0x%0h exp 0x%0h | %s", name, obs, exp,
        inp.convert2string()))
      checks_failed++;
    end else begin
      checks_passed++;
    end
  endfunction

  function void check_npc(string name, logic [38:0] obs,
                           logic [38:0] exp,
                           bp_be_pipe_int_transaction inp);
    if (obs !== exp) begin
      `uvm_error("SB", $sformatf(
        "MISMATCH %s: got 0x%0h exp 0x%0h | %s", name, obs, exp,
        inp.convert2string()))
      checks_failed++;
    end else begin
      checks_passed++;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf(
      "SCOREBOARD SUMMARY: PASSED=%0d  FAILED=%0d",
      checks_passed, checks_failed), UVM_NONE)
    if (checks_failed > 0)
      `uvm_error("SB", "TEST FAILED — scoreboard mismatches detected")
    else
      `uvm_info("SB", "ALL CHECKS PASSED", UVM_NONE)
  endfunction

endclass
`endif
