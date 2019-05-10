/**
 *
 * test_bp.v
 *
 */

module test_bp
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter trace_p          = "inv"
  
   // Trace replay parameters
   , parameter trace_ring_width_p     = "inv"
   , parameter trace_rom_addr_width_p = "inv"
 );

logic clk, reset;

bsg_nonsynth_clock_gen 
 #(.cycle_time_p(10))
 clock_gen 
  (.o(clk));

bsg_nonsynth_reset_gen 
 #(.num_clocks_p(1)
   ,.reset_cycles_lo_p(1)
   ,.reset_cycles_hi_p(10)
   )
 reset_gen
  (.clk_i(clk)
   ,.async_reset_o(reset)
   );

testbench
 #(.trace_p(trace_p))
 tb
  (.clk_i(clk)
   ,.reset_i(reset)
   );

endmodule : test_bp

