
module bp_be_pipe_long
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam wb_pkt_width_lp = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [dispatch_pkt_width_lp-1:0] reservation_i
   , input                             v_i
   , output                            ready_o

   , input                             flush_i

   , output [wb_pkt_width_lp-1:0]      wb_pkt_o
   , output                            v_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_dispatch_pkt_s reservation;
  rv64_instr_rtype_s instr;
  bp_be_decode_s decode;
  bp_be_wb_pkt_s wb_pkt;

  assign wb_pkt_o = wb_pkt;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr  = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dword_width_p-1:0] rs1 = reservation.rs1[0+:dword_width_p];
  wire [dword_width_p-1:0] rs2 = reservation.rs2[0+:dword_width_p];
  wire [dword_width_p-1:0] imm = reservation.imm[0+:dword_width_p];

  wire signed_div_li = decode.fu_op inside {e_mul_op_div, e_mul_op_rem};
  wire rem_not_div_li = decode.fu_op inside {e_mul_op_rem, e_mul_op_remu};

  logic [dword_width_p-1:0] op_a, op_b;
  always_comb
    begin
      op_a = decode.opw_v
             ? signed_div_li
               ? dword_width_p'($signed(rs1[0+:word_width_p]))
               : rs1[0+:word_width_p]
             : rs1;
      op_b = decode.opw_v
             ? signed_div_li
               ? dword_width_p'($signed(rs2[0+:word_width_p]))
               : rs2[0+:word_width_p]
             : rs2;
    end

  // We actual could exit early here
  logic [dword_width_p-1:0] quotient_lo, remainder_lo;
  logic idiv_ready_lo;
  logic v_lo;
  bsg_idiv_iterative
   #(.width_p(dword_width_p))
   idiv
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dividend_i(op_a)
     ,.divisor_i(op_b)
     ,.signed_div_i(signed_div_li)
     ,.v_i(v_i)
     ,.ready_o(idiv_ready_lo)

     ,.quotient_o(quotient_lo)
     ,.remainder_o(remainder_lo)
     ,.v_o(v_lo)
     // Because we currently freeze the pipe while a long latency op is executing,
     //   we ack immediately
     ,.yumi_i(v_lo)
     );

  logic opw_v_r;
  bp_be_fu_op_s fu_op_r;
  logic [reg_addr_width_p-1:0] rd_addr_r;
  logic rd_w_v_r;
  bsg_dff_reset_en
   #(.width_p(1+reg_addr_width_p+$bits(bp_be_fu_op_s)+1))
   wb_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i | flush_i)
     ,.en_i(v_i | v_lo)

     ,.data_i({v_i, instr.rd_addr, decode.fu_op, decode.opw_v})
     ,.data_o({rd_w_v_r, rd_addr_r, fu_op_r, opw_v_r})
     );

  logic [dword_width_p-1:0] rd_data_lo;
  always_comb
    if (opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      rd_data_lo = $signed(quotient_lo[0+:word_width_p]);
    else if (opw_v_r && fu_op_r inside {e_mul_op_rem, e_mul_op_remu})
      rd_data_lo = $signed(remainder_lo[0+:word_width_p]);
    else if (~opw_v_r && fu_op_r inside {e_mul_op_div, e_mul_op_divu})
      rd_data_lo = quotient_lo;
    else
      rd_data_lo = remainder_lo;

  assign wb_pkt.rd_w_v  = rd_w_v_r;
  assign wb_pkt.rd_addr = rd_addr_r;
  assign wb_pkt.rd_data = rd_data_lo;
  assign v_o = v_lo & rd_w_v_r;

  // Actually a "busy" signal
  assign ready_o = idiv_ready_lo & ~v_i;

endmodule

