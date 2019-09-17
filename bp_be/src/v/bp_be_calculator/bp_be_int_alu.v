/**
 *
 * Name:
 *   bp_be_int_alu.v
 * 
 * Description:
 *   Integer ALU for rv64i arithmetic instructions.
 *
 * Parameters:
 *
 * Inputs:
 *   src1_i           - Register operand data
 *   src2_i           - Register or immediate operand data
 *
 *   op_i             - Which operation to perform. Several operations are shared 
 *                        e.g. sltu is used for both compute + branch
 *   opw_v_i          - Whether the operation is word width
 *
 * Outputs:
 *   result_o         - The calculated result of the arithmetic operation
 *   
 * Keywords:
 *   calculator, alu, int, integer, rv64i
 *
 * Notes:
 *   Currently, we leave arithmetic optimization up to the compiler. For example, several 
 *     operations could be implemented by a single calculation and a bit toggle.
 *   This could synthesize as two seperately sized alus, if the compiler doesn't realize 
 *     that result and resultw are mutually exclusive.
 */

module bp_be_int_alu 
  import bp_be_pkg::*;
  import bp_common_rv64_pkg::*;
 #(// Generated parameters
   localparam fu_op_width_lp      = `bp_be_fu_op_width
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam word_width_lp     = rv64_word_width_gp
   , localparam shamt_width_lp    = rv64_shamt_width_gp
   , localparam shamtw_width_lp   = rv64_shamtw_width_gp
   )
  (// Source data
   input [reg_data_width_lp-1:0]    src1_i
   , input [reg_data_width_lp-1:0]  src2_i

   // Arithmetic operation metadata
   , input [fu_op_width_lp-1:0]     op_i
   , input                          opw_v_i

   // Result
   , output [reg_data_width_lp-1:0] result_o
   );

// Intermediate connections
// These are signed because we're doing math on them, most of which is signed
logic signed [reg_data_width_lp-1:0] src1_sgn   , src2_sgn;
logic signed [word_width_lp-1:0]     src1_w_sgn , src2_w_sgn;
logic signed [reg_data_width_lp-1:0] result_sgn ;
logic signed [word_width_lp-1:0]     resultw_sgn;
logic        [shamt_width_lp-1:0]    shamt;
logic        [shamtw_width_lp-1:0]   shamtw;
 
// Casting 
assign src1_sgn   = $signed(src1_i);
assign src2_sgn   = $signed(src2_i);
assign src1_w_sgn = $signed(src1_i[0+:word_width_lp]);
assign src2_w_sgn = $signed(src2_i[0+:word_width_lp]);

assign shamt      = src2_i[0+:shamt_width_lp];
assign shamtw     = src2_i[0+:shamtw_width_lp];

// The actual computation
always_comb 
  begin
    // These two case statements are mutually exclusive, but we separate them because they 
    //   assign to different results
    // Calculate result for 32-bit operations
    unique case (op_i)
      e_int_op_add : resultw_sgn = src1_w_sgn +   src2_w_sgn;
      e_int_op_sub : resultw_sgn = src1_w_sgn -   src2_w_sgn;
      e_int_op_sll : resultw_sgn = src1_w_sgn <<  shamtw;
      e_int_op_srl : resultw_sgn = src1_w_sgn >>  shamtw;
      e_int_op_sra : resultw_sgn = src1_w_sgn >>> shamtw;
      default      : resultw_sgn = '0;
    endcase
  
    // Calculate result for 64-bit operations
    unique case (op_i)
      e_int_op_add       : result_sgn = src1_sgn +   src2_sgn;
      e_int_op_sub       : result_sgn = src1_sgn -   src2_sgn;
      e_int_op_xor       : result_sgn = src1_sgn ^   src2_sgn;
      e_int_op_or        : result_sgn = src1_sgn |   src2_sgn;
      e_int_op_and       : result_sgn = src1_sgn &   src2_sgn;
      e_int_op_sll       : result_sgn = src1_sgn <<  shamt;
      e_int_op_srl       : result_sgn = src1_sgn >>  shamt;
      e_int_op_sra       : result_sgn = src1_sgn >>> shamt;
      e_int_op_pass_src2 : result_sgn =              src2_i;
  
      // Single bit results
      e_int_op_slt  : result_sgn = (reg_data_width_lp)'($unsigned(src1_sgn <  src2_sgn));
      e_int_op_sge  : result_sgn = (reg_data_width_lp)'($unsigned(src1_sgn >= src2_sgn));
      e_int_op_eq   : result_sgn = (reg_data_width_lp)'($unsigned(src1_i   == src2_i));
      e_int_op_ne   : result_sgn = (reg_data_width_lp)'($unsigned(src1_i   != src2_i));
      e_int_op_sltu : result_sgn = (reg_data_width_lp)'($unsigned(src1_i   <  src2_i));
      e_int_op_sgeu : result_sgn = (reg_data_width_lp)'($unsigned(src1_i   >= src2_i));
      default       : result_sgn = '0;
    endcase
  end

// Select between word and double word width results
assign result_o = opw_v_i ? reg_data_width_lp'(resultw_sgn) : result_sgn;

endmodule : bp_be_int_alu

