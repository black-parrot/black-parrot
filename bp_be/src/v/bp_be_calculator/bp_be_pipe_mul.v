/**
 *
 * Name:
 *   bp_be_pipe_mul.v
 * 
 * Description:
 *   Pipeline for RISC-V multiplication instructions.
 *
 * Notes:
 *   Does not handle high-half multiplication. These operations take up more than half
 *     of the area of a 64x64->128-bit multiplier, but are used rarely
 *   Must use retiming for good QoR.
 */
module bp_be_pipe_mul
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam latency_lp = 4
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i

   // Pipeline result
   , output [dword_width_p-1:0]        data_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  
  assign reservation = reservation_i;
  assign decode = reservation.decode;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_p-1:0] rs1 = reservation.rs1[0+:dword_width_p];
  wire [dword_width_p-1:0] rs2 = reservation.rs2[0+:dword_width_p];
  wire [dword_width_p-1:0] imm = reservation.imm[0+:dword_width_p];
  
  wire [dword_width_p-1:0] src1_w_sgn = dword_width_p'($signed(rs1[0+:word_width_p]));
  wire [dword_width_p-1:0] src2_w_sgn = dword_width_p'($signed(rs2[0+:word_width_p]));
  
  wire [dword_width_p-1:0] op_a = decode.opw_v ? src1_w_sgn : rs1;
  wire [dword_width_p-1:0] op_b = decode.opw_v ? src2_w_sgn : rs2;
  
  wire [dword_width_p-1:0] full_result = op_a * op_b;
  
  wire [dword_width_p-1:0] mul_lo = decode.opw_v ? dword_width_p'($signed(full_result[0+:word_width_p])) : full_result;
  
  bsg_dff_chain
   #(.width_p(dword_width_p)
     ,.num_stages_p(latency_lp-1)
     )
   retime_chain
    (.clk_i(clk_i)
  
     ,.data_i(mul_lo)
     ,.data_o(data_o)
     );

endmodule
