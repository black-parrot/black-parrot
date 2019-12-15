/**
 *
 * Name:
 *   bp_be_pipe_fp.v
 * 
 * Description:
 *   Pipeline for RISC-V float instructions. Handles float and double computation.
 *
 * Notes:
 *
 */
module bp_be_pipe_fp
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  import bp_be_hardfloat_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   , localparam decode_width_lp    = `bp_be_decode_width
   // From RISC-V specifications
   , localparam reg_data_width_lp  = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input [instr_width_p-1:0]      instr_i
   , input [decode_width_lp-1:0]    decode_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i
   , input [reg_data_width_lp-1:0]  rs3_i

   // Pipeline result
   , output [reg_data_width_lp-1:0] data_o

   , input [2:0]                    frm_i
   , output [4:0]                   fflags_o
   );

// Cast input and output ports 
rv64_instr_s      instr;
bp_be_decode_s    decode;

assign instr = instr_i;
assign decode = decode_i;

// Module instantiations
rv64_frm_e frm_li;
assign frm_li = (instr.fields.ftype.rm == e_dyn) ? rv64_frm_e'(frm_i) : rv64_frm_e'(instr.fields.ftype.rm);

wire is_direct = (decode.fu_op inside {e_op_i2f, e_op_iu2f, e_op_imvf, e_op_fmvi});
bp_be_hardfloat_fpu
 fpu
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.a_i(rs1_i) //is_direct ? rs1_i : a_rec_li)
   ,.b_i(rs2_i) //b_rec_li)
   ,.c_i(rs3_i) //c_rec_li)

   ,.op_i(decode.fu_op.fu_op.fp_fu_op)
   ,.ipr_i(decode.ipr)
   ,.opr_i(decode.opr)
   ,.rm_i(frm_li)

   ,.o(data_o)
   ,.eflags_o(fflags_o)
   );

endmodule

