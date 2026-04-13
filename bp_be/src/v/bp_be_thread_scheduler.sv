/**
 * bp_be_thread_scheduler.sv
 *
 * Simple Round-Robin Thread Scheduler for Black Parrot
 *
 * Description:
 *   Implements a basic round-robin scheduling policy for multi-threaded execution.
 *   Each cycle, the scheduler advances to the next thread in a rotating pattern:
 *   Thread 0 → Thread 1 → ... → Thread N-1 → Thread 0 (repeat)
 *
 *   This scheduler is:
 *   - Deterministic: always follows the same pattern
 *   - Simple: no complex logic or state tracking
 *   - Fair: each thread gets equal opportunity
 *   - Suitable for validation and testing
 *
 *   More sophisticated schedulers could:
 *   - Stall on dependencies
 *   - Prioritize ready threads
 *   - Implement priority policies
 *   - Support dynamic migration
 *
 * Author: Black Parrot Multithreading Implementation
 * Date: February 2026
 */

`include "bp_common_defines.svh"

module bp_be_thread_scheduler
 import bp_common_pkg::*;
 #(parameter num_threads_p = 1
   , parameter thread_id_width_p = `BSG_SAFE_CLOG2(num_threads_p)
   )
  (input                                    clk_i
   , input                                  reset_i
   , input                                  csr_write_ctxt_v_i
   , input [thread_id_width_p-1:0]          csr_write_ctxt_data_i
   , output logic [thread_id_width_p-1:0]   thread_id_o
   );

  // Current thread register - stores which thread we're on
  logic [thread_id_width_p-1:0] current_thread_r;

  // Sequential logic: update on CSR write, hold otherwise
  // Phase 1.4: Software-controlled context switching (no auto-increment)
  always @(posedge clk_i) begin
    if (reset_i) begin
      // On reset, start with thread 0
      current_thread_r <= '0;
    end else if (csr_write_ctxt_v_i) begin
      // CSR write to CTXT (0x081) - jump to requested thread
      current_thread_r <= csr_write_ctxt_data_i;
      $display("[TSCHED @%0t] thread_id %0d -> %0d", $time, current_thread_r, csr_write_ctxt_data_i);
    end
    // else: Hold current thread (no auto-increment for Phase 1.4)
  end

  // Combinational output: current thread becomes thread_id_o
  assign thread_id_o = current_thread_r;

endmodule

`BSG_ABSTRACT_MODULE(bp_be_thread_scheduler)
