// =============================================================================
// Testbench: bp_cce_pending_bits — Bug Fix Verification
//
// Tests both the ORIGINAL (buggy) and FIXED (saturating) counter logic.
//
// Run with: iverilog -g2012 -o tb_pending_bits tb_pending_bits.sv && ./tb_pending_bits
// =============================================================================

module tb_pending_bits;

  localparam WIDTH_P           = 3;
  localparam NUM_WAY_GROUPS_P  = 4;
  localparam LG_NUM_WAY_GROUPS = $clog2(NUM_WAY_GROUPS_P);

  logic clk, reset;

  // Write path
  logic                          w_v_i;
  logic [LG_NUM_WAY_GROUPS-1:0]  w_wg;
  logic                          pending_i;
  logic                          clear_i;

  // Read path
  logic [LG_NUM_WAY_GROUPS-1:0]  r_wg;
  logic                          r_v_i;
  logic                          pending_o_buggy;
  logic                          pending_o_fixed;

  // ========== ORIGINAL (BUGGY) counter ==========
  logic [NUM_WAY_GROUPS_P-1:0][WIDTH_P-1:0] buggy_r, buggy_n;

  always_ff @(posedge clk) begin
    if (reset) buggy_r <= '0;
    else       buggy_r <= buggy_n;
  end

  always_comb begin
    buggy_n = buggy_r;
    if (w_v_i) begin
      if (clear_i)
        buggy_n[w_wg] = '0;
      else if (pending_i)
        buggy_n[w_wg] = buggy_r[w_wg] + 'd1;  // NO saturation
      else
        buggy_n[w_wg] = buggy_r[w_wg] - 'd1;  // NO saturation
    end
  end

  assign pending_o_buggy = (r_v_i & w_v_i & (w_wg == r_wg))
    ? ~(buggy_n[r_wg] == 0)
    : ~(buggy_r[r_wg] == 0);

  // ========== FIXED (SATURATING) counter ==========
  logic [NUM_WAY_GROUPS_P-1:0][WIDTH_P-1:0] fixed_r, fixed_n;

  always_ff @(posedge clk) begin
    if (reset) fixed_r <= '0;
    else       fixed_r <= fixed_n;
  end

  always_comb begin
    fixed_n = fixed_r;
    if (w_v_i) begin
      if (clear_i)
        fixed_n[w_wg] = '0;
      else if (pending_i) begin
        if (fixed_r[w_wg] != {WIDTH_P{1'b1}})        // saturate at max
          fixed_n[w_wg] = fixed_r[w_wg] + 'd1;
      end else begin
        if (fixed_r[w_wg] != '0)                      // saturate at zero
          fixed_n[w_wg] = fixed_r[w_wg] - 'd1;
      end
    end
  end

  assign pending_o_fixed = (r_v_i & w_v_i & (w_wg == r_wg))
    ? ~(fixed_n[r_wg] == 0)
    : ~(fixed_r[r_wg] == 0);

  // ---- Clock ----
  initial clk = 0;
  always #5 clk = ~clk;

  // ---- Helper tasks ----
  task automatic do_reset();
    reset = 1; w_v_i = 0; pending_i = 0; clear_i = 0; r_v_i = 0; w_wg = 0; r_wg = 0;
    @(posedge clk); @(posedge clk);
    reset = 0;
    @(posedge clk);
  endtask

  task automatic write_inc(input logic [LG_NUM_WAY_GROUPS-1:0] wg);
    @(posedge clk);
    w_v_i = 1; w_wg = wg; pending_i = 1; clear_i = 0;
    @(posedge clk);
    w_v_i = 0; pending_i = 0;
  endtask

  task automatic write_dec(input logic [LG_NUM_WAY_GROUPS-1:0] wg);
    @(posedge clk);
    w_v_i = 1; w_wg = wg; pending_i = 0; clear_i = 0;
    @(posedge clk);
    w_v_i = 0;
  endtask

  task automatic read_pending(input logic [LG_NUM_WAY_GROUPS-1:0] wg);
    @(posedge clk);
    r_v_i = 1; r_wg = wg;
    #1; // let combinational settle
    @(posedge clk);
    r_v_i = 0;
  endtask

  integer pass = 0, fail = 0;

  initial begin
    $display("");
    $display("================================================================");
    $display("  Testbench: bp_cce_pending_bits — Fix Verification");
    $display("  Counter width: %0d bits (range 0-%0d)", WIDTH_P, (1<<WIDTH_P)-1);
    $display("================================================================");
    $display("");

    // =================================================================
    // TEST 1: Overflow — 8 increments on a 3-bit counter
    // =================================================================
    $display("--- TEST 1: Counter Overflow (8 increments) ---");
    do_reset();
    for (int i = 0; i < 8; i++) write_inc(2'b00);

    read_pending(2'b00);
    $display("  BUGGY  counter[0] = %0d, pending_o = %0b", buggy_r[0], pending_o_buggy);
    $display("  FIXED  counter[0] = %0d, pending_o = %0b", fixed_r[0], pending_o_fixed);

    if (buggy_r[0] == 0 && fixed_r[0] == 7) begin
      $display("  >> PASS: Buggy wraps to 0, Fixed saturates at 7.");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    // TEST 2: Underflow — decrement from 0
    // =================================================================
    $display("--- TEST 2: Counter Underflow (decrement from 0) ---");
    do_reset();
    write_dec(2'b01);

    read_pending(2'b01);
    $display("  BUGGY  counter[1] = %0d, pending_o = %0b", buggy_r[1], pending_o_buggy);
    $display("  FIXED  counter[1] = %0d, pending_o = %0b", fixed_r[1], pending_o_fixed);

    if (buggy_r[1] == 7 && fixed_r[1] == 0) begin
      $display("  >> PASS: Buggy wraps to 7, Fixed stays at 0.");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    // TEST 3: Overflow → coherence violation scenario
    // =================================================================
    $display("--- TEST 3: Overflow Coherence Violation ---");
    do_reset();
    for (int i = 0; i < 8; i++) write_inc(2'b10);

    read_pending(2'b10);
    $display("  BUGGY  pending_o = %0b (8 txns in-flight, should be 1)", pending_o_buggy);
    $display("  FIXED  pending_o = %0b (8 txns in-flight, should be 1)", pending_o_fixed);

    if (pending_o_buggy == 0 && pending_o_fixed == 1) begin
      $display("  >> PASS: Buggy falsely says FREE, Fixed correctly says BUSY.");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    // TEST 4: Underflow → stuck-busy scenario
    // =================================================================
    $display("--- TEST 4: Underflow Cascading — Counter Recovery ---");
    do_reset();
    write_dec(2'b11);       // underflow
    write_inc(2'b11);       // then increment once

    read_pending(2'b11);
    $display("  BUGGY  counter[3] = %0d, pending_o = %0b (should be 1/free)",
             buggy_r[3], pending_o_buggy);
    $display("  FIXED  counter[3] = %0d, pending_o = %0b (should be 1/busy)",
             fixed_r[3], pending_o_fixed);

    if (buggy_r[3] == 0 && fixed_r[3] == 1) begin
      $display("  >> PASS: Buggy corrupted (7+1=0), Fixed is correct (0→0→+1=1).");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    // TEST 5: Normal operation — inc 3, dec 2, check pending
    // =================================================================
    $display("--- TEST 5: Normal Operation (no edge cases) ---");
    do_reset();
    write_inc(2'b00); write_inc(2'b00); write_inc(2'b00);
    write_dec(2'b00); write_dec(2'b00);

    read_pending(2'b00);
    $display("  BUGGY  counter[0] = %0d, pending_o = %0b", buggy_r[0], pending_o_buggy);
    $display("  FIXED  counter[0] = %0d, pending_o = %0b", fixed_r[0], pending_o_fixed);

    if (buggy_r[0] == 1 && fixed_r[0] == 1 && pending_o_buggy == 1 && pending_o_fixed == 1) begin
      $display("  >> PASS: Both agree — counter=1, pending=1. Normal path works.");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    // TEST 6: Normal operation — inc 2, dec 2, check not-pending
    // =================================================================
    $display("--- TEST 6: Normal Operation — Drain to Zero ---");
    do_reset();
    write_inc(2'b00); write_inc(2'b00);
    write_dec(2'b00); write_dec(2'b00);

    read_pending(2'b00);
    $display("  BUGGY  counter[0] = %0d, pending_o = %0b", buggy_r[0], pending_o_buggy);
    $display("  FIXED  counter[0] = %0d, pending_o = %0b", fixed_r[0], pending_o_fixed);

    if (buggy_r[0] == 0 && fixed_r[0] == 0 && pending_o_buggy == 0 && pending_o_fixed == 0) begin
      $display("  >> PASS: Both agree — counter=0, pending=0. Drain works.");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    // TEST 7: Clear overrides everything
    // =================================================================
    $display("--- TEST 7: Clear Overrides ---");
    do_reset();
    write_inc(2'b00); write_inc(2'b00); write_inc(2'b00);
    // Now clear
    @(posedge clk);
    w_v_i = 1; w_wg = 2'b00; clear_i = 1; pending_i = 1; // clear + pending both set
    @(posedge clk);
    w_v_i = 0; clear_i = 0; pending_i = 0;

    read_pending(2'b00);
    $display("  BUGGY  counter[0] = %0d", buggy_r[0]);
    $display("  FIXED  counter[0] = %0d", fixed_r[0]);

    if (buggy_r[0] == 0 && fixed_r[0] == 0) begin
      $display("  >> PASS: Clear correctly resets to 0 even with pending_i=1.");
      pass++;
    end else begin
      $display("  >> UNEXPECTED result."); fail++;
    end
    $display("");

    // =================================================================
    $display("================================================================");
    $display("  RESULTS: %0d PASSED, %0d FAILED", pass, fail);
    $display("================================================================");
    $display("");
    $finish;
  end

endmodule
