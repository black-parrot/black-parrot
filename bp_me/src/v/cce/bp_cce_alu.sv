/**
 *
 * Name:
 *   bp_cce_alu.sv
 *
 * Description:
 *   A simple ALU for the CCE implementing addition, subtraction, logical shift, and bitwise
 *   operations (and, or, xor, negate).
 *
 *   Some microcode operations such as addi and inc are implemented via assembler/softwware
 *   transforms and appropriate source selection. For example, inc is really an add where opd_b_i
 *   is an immediate from the instruction (source select), and the immediate has value 1 (assembler
 *   transform). See bp_cce_inst.svh for SW supported operations.
 *
 *   The arithmetic width is parameterizable, and set based on the microarchitecture design.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_alu
  import bp_me_pkg::*;
  #(parameter `BSG_INV_PARAM(width_p))
  (input [width_p-1:0]                       opd_a_i
   , input [width_p-1:0]                     opd_b_i
   , input bp_cce_inst_alu_op_e              alu_op_i
   , output logic [width_p-1:0]              res_o
  );

  always_comb begin : alu
    unique case (alu_op_i)
      e_alu_add:  res_o = opd_a_i + opd_b_i;
      e_alu_sub:  res_o = opd_a_i - opd_b_i;
      e_alu_lsh:  res_o = opd_a_i << opd_b_i;
      e_alu_rsh:  res_o = opd_a_i >> opd_b_i;
      e_alu_and:  res_o = opd_a_i & opd_b_i;
      e_alu_or:   res_o = opd_a_i | opd_b_i;
      e_alu_xor:  res_o = opd_a_i ^ opd_b_i;
      e_alu_neg:  res_o = ~opd_a_i;
      e_alu_not:  res_o = !opd_a_i;
      e_alu_nand: res_o = !(opd_a_i & opd_b_i);
      e_alu_nor:  res_o = !(opd_a_i | opd_b_i);
      default:    res_o = '0;
    endcase
  end
endmodule

`BSG_ABSTRACT_MODULE(bp_cce_alu)
