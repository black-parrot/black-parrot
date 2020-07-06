/**
 *
 * Name:
 *   bp_be_pipe_int.v
 *
 * Description:
 *   Pipeline for RISC-V integer instructions. Handles integer computation.
 *
 * Notes:
 *
 */
module bp_be_pipe_int
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i

   // Pipeline results
   , output [dword_width_p-1:0]    data_o
   );

  // Suppress unused signal warning
  wire unused0 = clk_i;
  wire unused1 = reset_i;

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_p-1:0] rs1 = reservation.rs1[0+:dword_width_p];
  wire [dword_width_p-1:0] rs2 = reservation.rs2[0+:dword_width_p];
  wire [dword_width_p-1:0] imm = reservation.imm[0+:dword_width_p];

  // Sign-extend PC for calculation
  wire [dword_width_p-1:0] pc_sext_li = dword_width_p'($signed(pc));
  wire [dword_width_p-1:0] pc_plus4   = pc_sext_li + dword_width_p'(4);

  wire [dword_width_p-1:0] src1  = decode.src1_sel  ? pc_sext_li : rs1;
  wire [dword_width_p-1:0] src2  = decode.src2_sel  ? imm        : rs2;
  wire [dword_width_p-1:0] baddr = decode.baddr_sel ? src1       : pc_sext_li;

  // Perform the actual ALU computation
  logic [dword_width_p-1:0] alu_result;
  bp_be_int_alu
   alu
    (.src1_i(src1)
     ,.src2_i(src2)
     ,.op_i(decode.fu_op)
     ,.opw_v_i(decode.opw_v)

     ,.result_o(alu_result)
     );

  assign data_o = alu_result;

endmodule

