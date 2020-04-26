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
module bp_be_pipe_ctrl
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p = "inv"

   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   , localparam exception_width_lp   = `bp_be_exception_width
   // From RISC-V specifications
   , localparam dword_width_p = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input [decode_width_lp-1:0]    decode_i
   , input [vaddr_width_p-1:0]      pc_i
   , input [dword_width_p-1:0]      rs1_i
   , input [dword_width_p-1:0]      rs2_i
   , input [dword_width_p-1:0]      imm_i

   , output [dword_width_p-1:0]     data_o
   , output [vaddr_width_p-1:0]     br_tgt_o
   , output                         btaken_o
   );

// Cast input and output ports 
bp_be_decode_s decode;

assign decode = decode_i;

// Suppress unused signal warning
wire unused0 = clk_i;
wire unused1 = reset_i;

logic [vaddr_width_p-1:0] baddr, taken_tgt, ntaken_tgt;
logic btaken;
always_comb
  if (decode.pipe_ctrl_v)
    case (decode.fu_op)
      e_ctrl_op_beq  : btaken = (rs1_i == rs2_i);
      e_ctrl_op_bne  : btaken = (rs1_i != rs2_i);
      e_ctrl_op_blt  : btaken = ($signed(rs1_i) < $signed(rs2_i));
      e_ctrl_op_bltu : btaken = (rs1_i < rs2_i);
      e_ctrl_op_bge  : btaken = ($signed(rs1_i) >= $signed(rs2_i));
      e_ctrl_op_bgeu : btaken = rs1_i >= rs2_i;
      e_ctrl_op_jalr
      ,e_ctrl_op_jal : btaken = 1'b1;
       default       : btaken = 1'b0;
    endcase
  else
    begin
      btaken = 1'b0;
    end

assign baddr = decode.baddr_sel ? rs1_i : pc_i;
assign taken_tgt = baddr + imm_i;
assign ntaken_tgt = pc_i + 4'd4;

assign data_o   = vaddr_width_p'($signed(ntaken_tgt));
assign br_tgt_o = btaken ? taken_tgt : ntaken_tgt;
assign btaken_o = btaken;

endmodule

