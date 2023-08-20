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
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_int
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input                                  en_i
   , input [dispatch_pkt_width_lp-1:0]      reservation_i
   , input                                  flush_i

   // Pipeline results
   , output logic [dpath_width_gp-1:0]      data_o
   , output logic                           v_o
   , output logic                           branch_o
   , output logic                           btaken_o
   , output logic [vaddr_width_p-1:0]       npc_o
   , output logic                           instr_misaligned_v_o
   );

  // Suppress unused signal warning
  wire unused = &{clk_i, reset_i, flush_i};

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;
  bp_be_branch_pkt_s br_pkt;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_gp-1:0] rs1 = reservation.rs1[0+:dword_width_gp];
  wire [dword_width_gp-1:0] rs2 = reservation.rs2[0+:dword_width_gp];
  wire [dword_width_gp-1:0] imm = reservation.imm[0+:dword_width_gp];

  // Sign-extend PC for calculation
  wire [dword_width_gp-1:0] pc_sext_li = `BSG_SIGN_EXTEND(pc, dword_width_gp);
  wire [dword_width_gp-1:0] pc_plus4   = pc_sext_li + dword_width_gp'(4);

  wire [dword_width_gp-1:0] src1  = decode.src1_sel  ? pc_sext_li : rs1;
  wire [dword_width_gp-1:0] src2  = decode.src2_sel  ? imm        : rs2;

  wire [rv64_shamt_width_gp-1:0] shamt = decode.opw_v ? src2[0+:rv64_shamtw_width_gp] : src2[0+:rv64_shamt_width_gp];

  // Shift the operands to the high bits of the ALU in order to reuse 64-bit operators
  wire [dword_width_gp-1:0] final_src1 = decode.opw_v ? (src1 << word_width_gp) : src1;
  wire [dword_width_gp-1:0] final_src2 = decode.opw_v ? (src2 << word_width_gp) : src2;

  // ALU
  logic [dword_width_gp-1:0] alu_result;
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
      e_int_op_pass_one  : alu_result = 1'b1;
      e_int_op_pass_zero : alu_result = 1'b0;

      // Single bit results
      e_int_op_eq   : alu_result = (dword_width_gp)'(final_src1 == final_src2);
      e_int_op_ne   : alu_result = (dword_width_gp)'(final_src1 != final_src2);
      e_int_op_slt  : alu_result = (dword_width_gp)'($signed(final_src1) <  $signed(final_src2));
      e_int_op_sltu : alu_result = (dword_width_gp)'(final_src1 <  final_src2);
      e_int_op_sge  : alu_result = (dword_width_gp)'($signed(final_src1) >= $signed(final_src2));
      e_int_op_sgeu : alu_result = (dword_width_gp)'(final_src1 >= final_src2);
      default       : alu_result = '0;
    endcase

  wire [vaddr_width_p-1:0] baddr = decode.baddr_sel ? rs1 : pc;
  wire [vaddr_width_p-1:0] taken_raw = baddr + imm;
  wire [vaddr_width_p-1:0] taken_tgt = {taken_raw[vaddr_width_p-1:1], 1'b0};
  wire [vaddr_width_p-1:0] ntaken_tgt = pc + (decode.compressed ? 4'd2 : 4'd4);

  wire [dpath_width_gp-1:0] br_result = vaddr_width_p'($signed(ntaken_tgt));

  // Shift back the ALU result from the top field for word width operations
  wire [dword_width_gp-1:0] opw_result = $signed(alu_result) >>> word_width_gp;
  assign data_o = decode.branch_v ? br_result : decode.opw_v ? opw_result : alu_result;
  assign v_o    = en_i & reservation.v & reservation.decode.pipe_int_v;

  assign instr_misaligned_v_o = en_i & btaken_o & (taken_tgt[1:0] != 2'b00) & !compressed_support_p;

  assign branch_o = decode.branch_v;
  assign btaken_o = decode.branch_v & (decode.jump_v | alu_result[0]);
  assign npc_o = btaken_o ? taken_tgt : ntaken_tgt;

endmodule

