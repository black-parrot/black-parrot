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
 import bp_be_pkg::*;
 #();

  bit clk, reset;
  bit dram_clk, dram_reset;
  
  `ifdef VERILATOR
    bsg_nonsynth_dpi_clock_gen
  `else
    bsg_nonsynth_clock_gen
  `endif
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
  
  `ifdef VERILATOR
    bsg_nonsynth_dpi_clock_gen
  `else
    bsg_nonsynth_clock_gen
  `endif
   #(.cycle_time_p(`dram_pkg::tck_ps))
   dram_clock_gen
    (.o(dram_clk));
  
  bsg_nonsynth_reset_gen
   #(.num_clocks_p(1)
     ,.reset_cycles_lo_p(0)
     ,.reset_cycles_hi_p(10)
     )
   dram_reset_gen
    (.clk_i(dram_clk)
     ,.async_reset_o(dram_reset)
     );
  
  testbench
   tb
    (.clk_i(clk)
     ,.reset_i(reset)
     ,.dram_clk_i(dram_clk)
     ,.dram_reset_i(dram_reset)
     );
  
  initial
    begin
      `if VERILATOR
        $assertoff();
        @(posedge clk);
        @(negedge reset);
        $asserton();
      `endif
    end

endmodule

