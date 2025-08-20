
//`define BSG_NONSYNTH_ASSERT_ENABLE

`include "bsg_defines.sv"

module bsg_nonsynth_assert
  (input                clk_i
   , input              reset_i
   , input              en_i
   );

`ifndef VERILATOR
`ifdef BSG_NONSYNTH_ASSERT_ENABLE

  initial
    begin
      $display("BSG-INFO: Turning off assertions at time [%t]", $time);
      $assertoff();
      wait(!reset_i);
      @(posedge clk_i);
      @(posedge clk_i);
      $display("BSG-INFO: Turning on assertions at time [%t]", $time);
      $asserton();
    end

`else
    initial
      begin
        $display("BSG-INFO: %m instantiated, but BSG_NONSYNTH_ASSERT_ENABLE=0");
      end
`endif
`endif

endmodule

