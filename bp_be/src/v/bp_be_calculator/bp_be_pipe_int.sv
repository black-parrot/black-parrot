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

   , localparam reservation_width_lp = `bp_be_reservation_width(vaddr_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input                                  en_i
   , input [reservation_width_lp-1:0]       reservation_i
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
  bp_be_reservation_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc;
  wire [dword_width_gp-1:0] rs1 = reservation.isrc1;
  wire [dword_width_gp-1:0] rs2 = reservation.isrc2;
  wire [dword_width_gp-1:0] imm = reservation.isrc3;
  wire word_op = (decode.int_tag == e_int_word);

  // Sign-extend PC for calculation
  wire [dword_width_gp-1:0] pc_sext_li = `BSG_SIGN_EXTEND(pc, dword_width_gp);
  wire [dword_width_gp-1:0] pc_plus4   = pc_sext_li + dword_width_gp'(4);

  wire [dword_width_gp-1:0] src1  = decode.src1_sel  ? pc_sext_li : rs1;
  wire [dword_width_gp-1:0] src2  = decode.src2_sel  ? imm        : rs2;

  wire [rv64_shamt_width_gp-1:0] shamt = word_op ? src2[0+:rv64_shamtw_width_gp] : src2[0+:rv64_shamt_width_gp];

  // ALU
  logic [dword_width_gp-1:0] alu_result;
  always_comb
    unique case (decode.fu_op)
      e_int_op_add       : alu_result = src1 +  src2;
      e_int_op_sub       : alu_result = src1 -  src2;
      e_int_op_xor       : alu_result = src1 ^  src2;
      e_int_op_or        : alu_result = src1 |  src2;
      e_int_op_and       : alu_result = src1 &  src2;
      e_int_op_sll       : alu_result = src1 << shamt;
      e_int_op_srl       : alu_result = word_op ? $unsigned(src1[0+:word_width_gp]) >>> shamt : $unsigned(src1) >>> shamt;
      // TODO: not a final solution
      e_int_op_sra       : alu_result = word_op ? $signed(src1[0+:word_width_gp]) >>> shamt : $signed(src1) >>> shamt;
      e_int_op_pass_src2 : alu_result = src2;
      e_int_op_pass_one  : alu_result = 1'b1;
      e_int_op_pass_zero : alu_result = 1'b0;

      // Single bit results
      e_int_op_eq   : alu_result = (dword_width_gp)'(src1 == src2);
      e_int_op_ne   : alu_result = (dword_width_gp)'(src1 != src2);
      e_int_op_slt  : alu_result = (dword_width_gp)'($signed(src1) <  $signed(src2));
      e_int_op_sltu : alu_result = (dword_width_gp)'(src1 <  src2);
      e_int_op_sge  : alu_result = (dword_width_gp)'($signed(src1) >= $signed(src2));
      e_int_op_sgeu : alu_result = (dword_width_gp)'(src1 >= src2);
      default       : alu_result = '0;
    endcase

  wire [vaddr_width_p-1:0] baddr = decode.baddr_sel ? rs1 : pc;
  wire [vaddr_width_p-1:0] taken_raw = baddr + imm;
  wire [vaddr_width_p-1:0] taken_tgt = {taken_raw[vaddr_width_p-1:1], 1'b0};
  wire [vaddr_width_p-1:0] ntaken_tgt = pc + (decode.compressed ? 4'd2 : 4'd4);

  logic [dpath_width_gp-1:0] ird_data_lo;
  wire [dpath_width_gp-1:0] br_result = dpath_width_gp'($signed(ntaken_tgt));
  wire [dword_width_gp-1:0] int_result = decode.branch_v ? br_result : alu_result;
  bp_be_int_box
   #(.bp_params_p(bp_params_p))
   box
    (.raw_i(int_result)
     ,.tag_i(decode.int_tag)
     ,.unsigned_i(1'b0)
     ,.reg_o(ird_data_lo)
     );

  assign data_o = ird_data_lo;
  assign v_o    = en_i & reservation.v & reservation.decode.pipe_int_v;

  assign instr_misaligned_v_o = en_i & btaken_o & (taken_tgt[1:0] != 2'b00) & !compressed_support_p;

  assign branch_o = decode.branch_v;
  assign btaken_o = decode.branch_v & (decode.jump_v | alu_result[0]);
  assign npc_o = btaken_o ? taken_tgt : ntaken_tgt;

endmodule

