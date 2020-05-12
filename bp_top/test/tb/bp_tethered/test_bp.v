/**
 *
 * test_bp.v
 *
 */

`ifndef BP_SIM_CLK_PERIOD
`define BP_SIM_CLK_PERIOD 10
`endif

module test_bp
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
#();

logic clk, reset;

bsg_nonsynth_clock_gen 
 #(.cycle_time_p(`BP_SIM_CLK_PERIOD))
 clock_gen 
  (.o(clk));

bsg_nonsynth_reset_gen 
 #(.num_clocks_p(1)
   ,.reset_cycles_lo_p(0)
   ,.reset_cycles_hi_p(20)
   )
 reset_gen
  (.clk_i(clk)
   ,.async_reset_o(reset)
   );

testbench
 tb
  (.clk_i(clk)
   ,.reset_i(reset)
   );

initial 
  begin
    $assertoff();
    @(posedge clk);
    @(negedge reset);
    $asserton();
  end

endmodule : test_bp

