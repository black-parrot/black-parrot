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
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)
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

  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);
  bp_be_reservation_s reservation;
  bp_be_decode_s decode;
  rv64_instr_s instr;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc;
  wire [int_rec_width_gp-1:0] rs1 = reservation.isrc1;
  wire [int_rec_width_gp-1:0] rs2 = reservation.isrc2;
  wire [int_rec_width_gp-1:0] imm = reservation.isrc3;
  wire opw_v = (decode.irs1_tag == e_int_word);

  localparam num_bytes_lp = dword_width_gp>>3;
  localparam lg_bits_lp = `BSG_SAFE_CLOG2(dword_width_gp);

  // Shift calculation
  logic [rv64_shamt_width_gp-1:0] shamt, shamtn;
  wire [rv64_shamt_width_gp-1:0] shmask = {!opw_v, 5'b11111};
  assign shamt = (decode.irs2_r_v ? rs2 : imm) & shmask;
  assign shamtn = (opw_v ? 32 : 64) - shamt;

  // We need a separate adder here to do branch comparison + address calc
  wire [vaddr_width_p-1:0] baddr = decode.jr_v ? rs1 : pc;
  wire [vaddr_width_p-1:0] taken_raw = baddr + imm;
  wire [vaddr_width_p-1:0] taken_tgt = taken_raw & {{vaddr_width_p-1{1'b1}}, 1'b0};
  wire [vaddr_width_p-1:0] ntaken_tgt = pc + (reservation.size << 1'b1);
  wire [dword_width_gp-1:0] ntaken_data = `BSG_SIGN_EXTEND(ntaken_tgt, dword_width_gp);
  wire [dword_width_gp-1:0] pc_data = `BSG_SIGN_EXTEND(pc, dword_width_gp);

  logic [dword_width_gp-1:0] src1;
  wire [int_rec_width_gp-1:0] rs1_rev = {<<{rs1}};
  always_comb
    case (decode.src1_sel)
      e_src1_is_rs1     : src1 = decode.irs1_r_v ? rs1 : pc_data;
      e_src1_is_rs1_rev : src1 = rs1_rev >> 1'b1;
      e_src1_is_rs1_lsh : src1 = rs1 <<  shamt;
      e_src1_is_rs1_lshn: src1 = rs1 << shamtn;
      e_src1_is_zero    : src1 = '0;
      // e_src1_is_zero
      default : src1 = '0;
    endcase

  logic [dword_width_gp-1:0] src2;
  always_comb
    case (decode.src2_sel)
      e_src2_is_rs2     : src2 = decode.irs2_r_v ? rs2 : imm;
      e_src2_is_rs2n    : src2 = ~rs2;
      e_src2_is_rs1_rsh : src2 = $signed(rs1) >>>  shamt;
      e_src2_is_rs1_rshn: src2 = $signed(rs1) >>> shamtn;
      // e_src2_is_zero
      default : src2 = '0;
    endcase

  // Main adder
  logic carry;
  logic [dword_width_gp:0] sum;
  assign {carry, sum} = {src1[dword_width_gp-1], src1} + {src2[dword_width_gp-1], src2} + decode.carryin;
  wire sum_zero = ~|sum;
  wire sum_sign = sum[dword_width_gp];

  // Comparator (also used for branching)
  logic comp_result;
  always_comb
    unique case (decode.fu_op)
      // Comparator
      e_int_op_min  ,
      e_int_op_slt  : comp_result =  sum_sign;
      e_int_op_minu ,
      e_int_op_sltu : comp_result = !carry;
      e_int_op_max  ,
      e_int_op_sge  : comp_result = !sum_sign;
      e_int_op_maxu ,
      e_int_op_sgeu : comp_result = carry;

      e_int_op_ne   : comp_result = !sum_zero;
      // e_int_op_eq
      default : comp_result = sum_zero;
    endcase

  // Bitmanip
  logic [`BSG_WIDTH(dword_width_gp)-1:0] popcount;
  bsg_popcount
   #(.width_p(dword_width_gp))
   popc
    (.i(rs1[0+:dword_width_gp]), .o(popcount));

  logic [`BSG_WIDTH(word_width_gp)-1:0] clzh, clzl;
  wire [`BSG_WIDTH(dword_width_gp)-1:0] clz = !clzh[5] ? clzh : (!opw_v << 5) | clzl;
  bsg_counting_leading_zeros
   #(.width_p(word_width_gp))
   bclzh
    (.a_i(rs1[word_width_gp+:word_width_gp]), .num_zero_o(clzh));

  bsg_counting_leading_zeros
   #(.width_p(word_width_gp))
   bclzl
    (.a_i(rs1[0+:word_width_gp]), .num_zero_o(clzl));

  logic [num_bytes_lp-1:0][7:0] orcb;
  for (genvar i = 0; i < num_bytes_lp; i++)
    begin : rof_orcb
      assign orcb[i] = {8{|rs1[8*i+:8]}};
    end

  logic [num_bytes_lp-1:0][7:0] rev8;
  for (genvar i = 0; i < num_bytes_lp; i++)
    begin : rof_rev8
      assign rev8[i] = rs1[(7-i)*8+:8];
    end

  // ALU
  logic [dword_width_gp-1:0] alu_result;
  wire [lg_bits_lp-1:0] bindex = src2 & shmask;
  always_comb
    unique case (decode.fu_op)
      // Arithmetic
      e_int_op_add       : alu_result = sum;

      // Logic
      e_int_op_xor       : alu_result = src1 ^ src2;
      e_int_op_or        : alu_result = src1 | src2;
      e_int_op_and       : alu_result = src1 & src2;

      // Bitmanip
      e_int_op_cpop      : alu_result = popcount;
      e_int_op_clz       : alu_result = clz;
      e_int_op_max, e_int_op_maxu, e_int_op_min, e_int_op_minu
                         : alu_result = comp_result ? rs1 : rs2;
      e_int_op_orcb      : alu_result = orcb;
      e_int_op_rev8      : alu_result = rev8;

      // Bit ops
      e_int_op_bclr      : alu_result = rs1 & ~(1'b1 << bindex);
      e_int_op_bext      : alu_result = (rs1 >> bindex) & 1'b1;
      e_int_op_binv      : alu_result = rs1 ^ (1'b1 << bindex);
      e_int_op_bset      : alu_result = rs1 | (1'b1 << bindex);

      // Comparator
      default : alu_result = comp_result;
    endcase

  logic [dpath_width_gp-1:0] ird_data_lo;
  bp_be_int_box
   #(.bp_params_p(bp_params_p))
   box
    (.raw_i(alu_result)
     ,.tag_i(decode.ird_tag)
     ,.unsigned_i(1'b0)
     ,.reg_o(ird_data_lo)
     );

  assign data_o = (decode.j_v | decode.jr_v) ? ntaken_data : ird_data_lo;
  assign v_o    = en_i & reservation.v & reservation.decode.pipe_int_v;

  assign instr_misaligned_v_o = en_i & btaken_o & (taken_tgt[1:0] != 2'b00) & ~|compressed_support_p;

  assign branch_o = decode.br_v | decode.j_v | decode.jr_v;
  assign btaken_o = (decode.br_v & comp_result) || decode.j_v || decode.jr_v;
  assign npc_o = btaken_o ? taken_tgt : ntaken_tgt;

endmodule

