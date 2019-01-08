/**
 *  bp_dcache_axe_trace_gen.v
 */

module bp_dcache_axe_trace_gen
  #(parameter id_p="inv"
    ,parameter addr_width_p="inv"
    ,parameter data_width_p="inv"
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
  )
  (
    input clk_i
    ,input v_i
    ,input [data_width_p-1:0] store_data_i
    ,input [data_width_p-1:0] load_data_i
    ,input [addr_width_p-1:0] addr_i
    ,input store_i
    ,input load_i
  );

  // synopsys translate_off 
  logic [addr_width_p-1:0] addr;
  assign addr = addr_i>>lg_data_mask_width_lp;

  always_ff @ (posedge clk_i) begin
    if (v_i) begin
      if (store_i) begin
        $display("#AXE %0d: M[%0d] := %0d", id_p, addr, store_data_i);
      end
      else if (load_i) begin
        $display("#AXE %0d: M[%0d] == %0d", id_p, addr, load_data_i);
      end
    end
  end

  // synopsys translate_on

endmodule
