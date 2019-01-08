/**
 *
 * bp_be_int_alu.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_int_alu 
 #(localparam fu_op_width_lp=`bp_be_fu_op_width
   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   ,localparam word_width_lp=RV64_word_width_gp
   ,localparam shamt_width_lp=6
   ,localparam shamtw_width_lp=5
   )
  (input logic [reg_data_width_lp-1:0]   src1_i
   ,input logic [reg_data_width_lp-1:0]  src2_i

   ,input logic [fu_op_width_lp-1:0]     op_i
   ,input logic                          op32_v_i
   ,input logic                          toggle_v_i

   ,output logic [reg_data_width_lp-1:0] result_o
   );

logic signed [reg_data_width_lp-1:0] src1_signed, src2_signed, result, result_toggled;
logic signed [word_width_lp-1:0] src1_w_signed, src2_w_signed, result_w;

assign src1_signed = $signed(src1_i);
assign src2_signed = $signed(src2_i);
assign src1_w_signed = $signed(src1_i[0+:word_width_lp]);
assign src2_w_signed = $signed(src2_i[0+:word_width_lp]);

always_comb begin
    case(op_i)
        e_int_op_add : result_w = src1_w_signed + src2_w_signed;
        e_int_op_sub : result_w = src1_w_signed - src2_w_signed;
        e_int_op_sll : result_w = (src1_w_signed << src2_i[0+:shamtw_width_lp]);
        e_int_op_srl : result_w = (src1_w_signed >>  src2_i[0+:shamtw_width_lp]);
        e_int_op_sra : result_w = (src1_w_signed >>> src2_i[0+:shamtw_width_lp]);
        default : result_w = 'X;
    endcase

    case(op_i)
        e_int_op_add       : result = src1_signed + src2_signed;
        e_int_op_sub       : result = src1_signed - src2_signed;
        e_int_op_slt       : result = {{63{'0}}, (src1_signed < src2_signed)};
        e_int_op_sltu      : result = {{63{'0}}, (src1_i < src2_i)};
        e_int_op_xor       : result = src1_signed ^ src2_signed;
        e_int_op_or        : result = src1_signed | src2_signed;
        e_int_op_and       : result = src1_signed & src2_signed;
        e_int_op_sll       : result = (src1_signed << src2_i[0+:shamt_width_lp]);
        e_int_op_srl       : result = (src1_signed >>  src2_i[0+:shamt_width_lp]);
        e_int_op_sra       : result = (src1_signed >>> src2_i[0+:shamt_width_lp]);
        e_int_op_eq        : result = (src1_signed == src2_signed) ? 64'b1 : 64'b0;
        e_int_op_pass_src2 : result = src2_signed;
        default : result = 'X;
    endcase

    result_toggled = {{(reg_data_width_lp-1){1'b0}}, {result[0] ^ 1'b1}};

    result_o = op32_v_i ? {{32{result_w[31]}},result_w} : toggle_v_i ? result_toggled : result;
end

endmodule : bp_be_int_alu

