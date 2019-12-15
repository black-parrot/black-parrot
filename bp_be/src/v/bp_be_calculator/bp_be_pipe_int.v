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
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p = "inv"
   
   , parameter dword_width_p = 64
   , parameter instr_width_p = 32
   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input [decode_width_lp-1:0]    decode_i
   , input [instr_width_p-1:0]      instr_i
   , input [vaddr_width_p-1:0]      pc_i
   , input [dword_width_p-1:0]      rs1_i
   , input [dword_width_p-1:0]      rs2_i
   , input [dword_width_p-1:0]      imm_i

   // Pipeline results
   , output [reg_data_width_lp-1:0] data_o

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

// Sign-extend PC for calculation
wire [dword_width_p-1:0] pc_sext_li = dword_width_p'($signed(pc_i));

// Submodule connections
rv64_fflags_s fpu_eflags;
logic [dword_width_p-1:0] src1, src2, baddr, alu_result, fpu_result, result;
logic [dword_width_p-1:0] pc_plus4;
logic [dword_width_p-1:0] data_lo;

rv64_frm_e frm_li;
assign frm_li = (instr.fields.ftype.rm == e_dyn) ? rv64_frm_e'(frm_i) : rv64_frm_e'(instr.fields.ftype.rm);

// Perform the actual ALU computation
bp_be_int_alu 
 alu
  (.src1_i(src1)
   ,.src2_i(src2)
   ,.op_i(decode.fu_op)
   ,.opw_v_i(decode.opw_v)

   ,.result_o(alu_result)
   );

bp_be_hardfloat_fpu_int
 fpu
  (.a_i(rs1_i)
   ,.b_i(rs2_i)

   ,.op_i(decode.fu_op.fu_op.fp_fu_op)
   ,.ipr_i(decode.ipr)
   ,.opr_i(decode.opr)
   ,.rm_i(frm_li)

   ,.o(fpu_result)
   ,.eflags_o(fpu_eflags)
   );

always_comb 
  begin 
    src1     = decode.src1_sel  ? pc_sext_li : rs1_i;
    src2     = decode.src2_sel  ? imm_i      : rs2_i;
    baddr    = decode.baddr_sel ? src1       : pc_sext_li;
    pc_plus4 = pc_sext_li + dword_width_p'(4);

    case (decode.result_sel)
      e_result_from_pc_plus4: result = pc_plus4;
      e_result_from_fpu_int : result = fpu_result;
      default               : result = alu_result;
    endcase
  end

assign data_o = result;
assign fflags_o = fpu_eflags;

endmodule

