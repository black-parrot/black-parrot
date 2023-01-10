/*
 * bp_fe_ras.sv
 *
 * TODO: Implement repair of stack
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_ras
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                              clk_i
   , input                            reset_i

   , input                            call_i
   , input                            return_i
   , input [vaddr_width_p-1:0]        addr_i

   , output logic [vaddr_width_p-1:0] tgt_o
   , output logic                     v_o
   );

  logic [vaddr_width_p-1:0] addr_r;
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p))
   addr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(call_i)

     ,.data_i(addr_i)
     ,.data_o(addr_r)
     );
  assign tgt_o = addr_r;

  logic v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(call_i)
     ,.clear_i(return_i)
     ,.data_o(v_r)
     );
  assign v_o = v_r;

endmodule

