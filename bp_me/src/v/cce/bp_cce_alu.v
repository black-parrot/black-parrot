/**
 * bp_cce_alu.v
 *
 * This ALU implements only addition, subtraction, less than comparison,
 * equality comparison, and less than or equality comparison. All operations
 * computed as (opd_a_i operator opd_b_i). Arithmetic overflow is undefined.
 *
 * Additional operations (INC, DEC, BGT, BGE, BF, BFZ, etc.) are supported via
 * software transformations, which allows the ALU to be simple.
 * e.g., BGE a, b target == BLE b, a target
 *
 */

`include "bsg_defines.v"
`include "bp_cce_inst_pkg.v"

module bp_cce_alu
  import bp_cce_inst_pkg::*;
  #(parameter width_p="inv"
  )
  (
    input logic                              v_i
    ,input logic [width_p-1:0]               opd_a_i
    ,input logic [width_p-1:0]               opd_b_i
    ,input bp_cce_inst_minor_alu_op_e        alu_op_i
    ,output logic                            v_o
    ,output logic [width_p-1:0]              res_o
    ,output logic                            branch_res_o
  );

  assign v_o = v_i;

  logic equal, less;
  assign equal = (opd_a_i == opd_b_i);
  assign less = (opd_a_i < opd_b_i);

  always_comb begin : branch_result
    if (v_i) begin
    case (alu_op_i)
      e_beq_op: branch_res_o = equal;
      e_bne_op: branch_res_o = !equal;
      e_blt_op: branch_res_o = less;
      e_ble_op: branch_res_o = less | equal;
      e_bi_op:  branch_res_o = 1'b1;
      default: branch_res_o = '0;
    endcase
    end else begin
      branch_res_o = '0;
    end
  end

  always_comb begin : arithmetic
    res_o = '0;
    if (v_i) begin
    case (alu_op_i)
      e_add_op: res_o = opd_a_i + opd_b_i;
      e_sub_op: res_o = opd_a_i - opd_b_i;
      default: res_o = '0;
    endcase
    end
  end
endmodule
