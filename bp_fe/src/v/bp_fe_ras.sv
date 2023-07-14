/*
 * bp_fe_ras.sv
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_ras
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input                                clk_i
   , input                              reset_i

   , output logic                       init_done_o

   , input                              restore_i
   , input [ras_idx_width_p-1:0]        w_base_i
   , input [ras_idx_width_p-1:0]        w_cnt_i

   , input                              call_i
   , input [vaddr_width_p-1:0]          addr_i

   , output logic                       v_o
   , output logic [vaddr_width_p-1:0]   tgt_o
   , output logic [ras_idx_width_p-1:0] base_o
   , output logic [ras_idx_width_p-1:0] cnt_o
   , input                              return_i
   );

  localparam ras_els_lp = 2**ras_idx_width_p;
  logic [ras_idx_width_p-1:0] bptr_n, bptr_r;
  logic [ras_idx_width_p-1:0] cnt_n, cnt_r;

  wire [ras_idx_width_p-1:0] wptr = bptr_r + cnt_r; // wptr leads the base by the count
  wire [ras_idx_width_p-1:0] rptr = wptr - 1'b1;    // rptr always lags wptr by 1

  // Assume POT RAS for now, implement circular pointers if this is onerous
  wire empty = (cnt_r == '0);
  wire full  = (cnt_r == '1);

  // We assume overflow is desired (to get latest entries)
  // We assume underflow is benign (would need RAS/
  assign bptr_n = restore_i ? w_base_i : (bptr_r + (call_i & ~return_i & full));
  assign cnt_n  = restore_i ? w_cnt_i  : (cnt_r + (call_i & ~full) - (return_i & ~empty));
  bsg_dff_reset_en
   #(.width_p(2*ras_idx_width_p))
   ptr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(restore_i | call_i | return_i)
     ,.data_i({bptr_n, cnt_n})
     ,.data_o({bptr_r, cnt_r})
     );

  // Needs to push/pop at the same time to comply with RISC-V hints, preventing
  //   hardening. But, we expect this to be a fairly small structure
  bsg_mem_1r1w
   #(.width_p(vaddr_width_p), .els_p(ras_els_lp), .read_write_same_addr_p(1))
   mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(call_i)
     ,.w_addr_i(wptr)
     ,.w_data_i(addr_i)
     ,.r_v_i(return_i)
     ,.r_addr_i(rptr)
     ,.r_data_o(tgt_o)
     );
  assign base_o = bptr_r;
  assign cnt_o = cnt_r;
  assign v_o = ~empty;

  // We use count for valid, so we're immediately ready to go
  assign init_done_o = 1'b1;

endmodule

