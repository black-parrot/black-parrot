/**
 *
 * test_bp.v
 *
 */

module test_bp
 import bp_common_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cce_pkg::*;
 #( parameter bp_first_pc_p     = "inv"
   , parameter mem_els_p        = "inv"

   , parameter boot_rom_width_p = "inv"
   , parameter boot_rom_els_p   = "inv"

   , parameter trace_ring_width_p     = "inv"
   , parameter trace_rom_addr_width_p = "inv"
   );

logic clk, reset;

bsg_nonsynth_clock_gen 
 #(.cycle_time_p(`BSG_CORE_CLOCK_PERIOD))
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
 #(.bp_first_pc_p(bp_first_pc_p)
   ,.mem_els_p(mem_els_p)
   ,.boot_rom_width_p(boot_rom_width_p)
   ,.boot_rom_els_p(boot_rom_els_p)
   ,.trace_ring_width_p(trace_ring_width_p)
   ,.trace_rom_addr_width_p(trace_rom_addr_width_p)
   )
 tb
  (.clk_i(clk)
   ,.reset_i(reset)
   );

endmodule : test_bp

