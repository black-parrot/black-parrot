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
module bp_be_pipe_ctl
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i

   , output [dpath_width_p-1:0]        data_o
   , output [vaddr_width_p-1:0]        br_tgt_o
   , output                            btaken_o
   );

  // Suppress unused signal warning
  wire unused0 = clk_i;
  wire unused1 = reset_i;

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  bp_be_decode_s decode;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_p-1:0] rs1 = reservation.rs1[0+:dword_width_p];
  wire [dword_width_p-1:0] rs2 = reservation.rs2[0+:dword_width_p];
  wire [dword_width_p-1:0] imm = reservation.imm[0+:dword_width_p];

  logic btaken;
  always_comb
    if (decode.pipe_ctl_v)
      case (decode.fu_op)
        e_ctrl_op_beq  : btaken = (rs1 == rs2);
        e_ctrl_op_bne  : btaken = (rs1 != rs2);
        e_ctrl_op_blt  : btaken = ($signed(rs1) < $signed(rs2));
        e_ctrl_op_bltu : btaken = (rs1 < rs2);
        e_ctrl_op_bge  : btaken = ($signed(rs1) >= $signed(rs2));
        e_ctrl_op_bgeu : btaken = rs1 >= rs2;
        e_ctrl_op_jalr
        ,e_ctrl_op_jal : btaken = 1'b1;
         default       : btaken = 1'b0;
      endcase
    else
      begin
        btaken = 1'b0;
      end

  wire [vaddr_width_p-1:0] baddr = decode.baddr_sel ? rs1 : pc;
  wire [vaddr_width_p-1:0] taken_tgt = baddr + imm;
  wire [vaddr_width_p-1:0] ntaken_tgt = pc + 4'd4;

  assign data_o   = vaddr_width_p'($signed(ntaken_tgt));
  assign br_tgt_o = btaken ? {taken_tgt[vaddr_width_p-1:1], 1'b0} : ntaken_tgt;
  assign btaken_o = btaken;

endmodule

