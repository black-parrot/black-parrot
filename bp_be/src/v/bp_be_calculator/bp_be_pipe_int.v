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
 import bp_be_hardfloat_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i

   // Pipeline results
   , output [dpath_width_p-1:0]        data_o
   );

  // Suppress unused signal warning
  wire unused0 = clk_i;
  wire unused1 = reset_i;

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_p-1:0] rs1 = reservation.rs1[0+:dword_width_p];
  wire [dword_width_p-1:0] rs2 = reservation.rs2[0+:dword_width_p];
  wire [dword_width_p-1:0] imm = reservation.imm[0+:dword_width_p];

  // Sign-extend PC for calculation
  wire [dword_width_p-1:0] pc_sext_li = dword_width_p'($signed(pc));
  wire [dword_width_p-1:0] pc_plus4   = pc_sext_li + dword_width_p'(4);

  wire [dword_width_p-1:0] src1  = decode.src1_sel  ? pc_sext_li : rs1;
  wire [dword_width_p-1:0] src2  = decode.src2_sel  ? imm        : rs2;

  wire [rv64_shamt_width_gp-1:0] shamt = decode.opw_v ? src2[0+:rv64_shamtw_width_gp] : src2[0+:rv64_shamt_width_gp];

  // Shift the operands to the high bits of the ALU in order to reuse 64-bit operators
  wire [dword_width_p-1:0] final_src1 = decode.opw_v ? (src1 << word_width_p) : src1;
  wire [dword_width_p-1:0] final_src2 = decode.opw_v ? (src2 << word_width_p) : src2;

  // ALU
  logic [dword_width_p-1:0] alu_result;
  always_comb
    unique case (decode.fu_op)
      e_int_op_add       : alu_result = final_src1 +   final_src2;
      e_int_op_sub       : alu_result = final_src1 -   final_src2;
      e_int_op_xor       : alu_result = final_src1 ^   final_src2;
      e_int_op_or        : alu_result = final_src1 |   final_src2;
      e_int_op_and       : alu_result = final_src1 &   final_src2;
      e_int_op_sll       : alu_result = final_src1 <<  shamt;
      e_int_op_srl       : alu_result = final_src1 >>  shamt;
      e_int_op_sra       : alu_result = $signed(final_src1) >>> shamt;
      e_int_op_pass_src2 : alu_result = final_src2;

      // Single bit results
      e_int_op_eq   : alu_result = (dword_width_p)'(final_src1 == final_src2);
      e_int_op_ne   : alu_result = (dword_width_p)'(final_src1 != final_src2);
      e_int_op_slt  : alu_result = (dword_width_p)'($signed(final_src1) <  $signed(final_src2));
      e_int_op_sltu : alu_result = (dword_width_p)'(final_src1 <  final_src2);
      e_int_op_sge  : alu_result = (dword_width_p)'($signed(final_src1) >= $signed(final_src2));
      e_int_op_sgeu : alu_result = (dword_width_p)'(final_src1 >= final_src2);
      default       : alu_result = '0;
    endcase

  // Shift back the ALU result from the top field for word width operations
  wire [dword_width_p-1:0] opw_result = $signed(alu_result) >>> word_width_p;
  assign data_o = decode.opw_v ? opw_result : alu_result;

endmodule

