/**
 *
 * Name:
 *   bp_be_pipe_aux.v
 * 
 * Description:
 *
 * Notes:
 *   
 */
module bp_be_pipe_aux
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter dword_width_p = 64
   , parameter instr_width_p = 32
   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   , localparam exception_width_lp   = `bp_be_exception_width
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input [decode_width_lp-1:0]    decode_i
   , input [instr_width_p-1:0]      instr_i
   , input [dword_width_p-1:0]      rs1_i
   , input [dword_width_p-1:0]      rs2_i

   // Pipeline results
   , output [dword_width_p-1:0]     data_o

   , input [2:0]                    frm_i
   , output [4:0]                   fflags_o
   );

// Cast input and output ports 
rv64_instr_s      instr;
bp_be_decode_s    decode;

assign instr = instr_i;
assign decode = decode_i;

// Suppress unused signal warning
wire unused0 = clk_i;
wire unused1 = reset_i;

rv64_frm_e frm_li;
assign frm_li = (instr.fields.ftype.rm == e_dyn) ? rv64_frm_e'(frm_i) : rv64_frm_e'(instr.fields.ftype.rm);

// Perform the actual ALU computation
bp_be_hardfloat_fpu_aux
 fpu
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.a_i(rs1_i)
   ,.b_i(rs2_i)

   ,.op_i(decode.fu_op.fu_op.fp_fu_op)
   ,.ipr_i(decode.ipr)
   ,.opr_i(decode.opr)
   ,.rm_i(frm_li)

   ,.o(data_o)
   ,.eflags_o(fflags_o)
   );

endmodule

