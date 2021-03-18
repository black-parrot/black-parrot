/**
 *  bp_fe_icache_axe_trace_gen.v
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_icache_axe_trace_gen
  #(parameter id_p="inv"
    ,parameter addr_width_p="inv"
    ,parameter data_width_p="inv"
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
  )
  (
    input clk_i
    ,input v_i
    ,input [data_width_p-1:0] data_i
    ,input [addr_width_p-1:0] addr_i
  );

  // synopsys translate_off
  logic [addr_width_p-1:0] addr;
  assign addr = addr_i>>(lg_data_mask_width_lp-1);

  always_ff @ (posedge clk_i) begin
    if (v_i) begin
      $display("#AXE %0d: M[%0d] == %0d", id_p, addr, data_i);
    end
  end

  // synopsys translate_on

endmodule
