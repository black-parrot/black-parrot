
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_reservation
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam reservation_width_lp = `bp_be_reservation_width(vaddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [dispatch_pkt_width_lp-1:0]       dispatch_pkt_i
   , input [2:0][dpath_width_gp-1:0]         bypass_rs_i

   , output logic [reservation_width_lp-1:0] reservation_o
   );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `bp_cast_i(bp_be_dispatch_pkt_s, dispatch_pkt);
  `bp_cast_o(bp_be_reservation_s, reservation);

  // TODO: Input boxing
  bp_be_dispatch_pkt_s dispatch_pkt_n, dispatch_pkt_r;
  always_comb
    begin
      dispatch_pkt_n     = dispatch_pkt_cast_i;
      dispatch_pkt_n.rs1 = bypass_rs_i[0];
      dispatch_pkt_n.rs2 = bypass_rs_i[1];
      dispatch_pkt_n.imm = bypass_rs_i[2];
    end

  bsg_dff
   #(.width_p(dispatch_pkt_width_lp))
   dispatch_pkt_reg
    (.clk_i(clk_i)
     ,.data_i(dispatch_pkt_n)
     ,.data_o(dispatch_pkt_r)
     );

  // Output unboxing
  // TODO: Investigate retiming potential
  bp_be_decode_s decode;
  assign decode = dispatch_pkt_r.decode;

  bp_hardfloat_rec_dp_s frs1;
  bp_be_fp_unbox
   #(.bp_params_p(bp_params_p))
   frs1_unbox
    (.reg_i(dispatch_pkt_r.rs1)
     ,.tag_i(decode.frs1_tag)
     ,.raw_i(decode.fmove_v)
     ,.val_o(frs1)
     );

  bp_hardfloat_rec_dp_s frs2;
  bp_be_fp_unbox
   #(.bp_params_p(bp_params_p))
   frs2_unbox
    (.reg_i(dispatch_pkt_r.rs2)
     ,.tag_i(decode.frs2_tag)
     ,.raw_i(decode.fmove_v)
     ,.val_o(frs2)
     );

  bp_hardfloat_rec_dp_s frs3;
  bp_be_fp_unbox
   #(.bp_params_p(bp_params_p))
   frs3_unbox
    (.reg_i(dispatch_pkt_r.imm)
     ,.tag_i(decode.frs3_tag)
     ,.raw_i(decode.fmove_v)
     ,.val_o(frs3)
     );

  logic [int_rec_width_gp-1:0] rs1;
  bp_be_int_unbox
   #(.bp_params_p(bp_params_p))
   irs1_unbox
    (.reg_i(dispatch_pkt_r.rs1)
     ,.tag_i(decode.irs1_tag)
     ,.unsigned_i(decode.irs1_unsigned)
     ,.val_o(rs1)
     );

  logic [int_rec_width_gp-1:0] rs2;
  bp_be_int_unbox
   #(.bp_params_p(bp_params_p))
   irs2_unbox
    (.reg_i(dispatch_pkt_r.rs2)
     ,.tag_i(decode.irs2_tag)
     ,.unsigned_i(decode.irs2_unsigned)
     ,.val_o(rs2)
     );

  wire [int_rec_width_gp-1:0] imm = dispatch_pkt_r.imm;

  bp_be_reservation_s reservation;
  always_comb
    begin
      reservation = '0;
      reservation.v      = dispatch_pkt_r.v;
      reservation.pc     = dispatch_pkt_r.pc;
      reservation.instr  = dispatch_pkt_r.instr;
      reservation.decode = dispatch_pkt_r.decode;
      reservation.size   = dispatch_pkt_r.size;
      reservation.count  = dispatch_pkt_r.count;

      reservation.isrc1  = rs1;
      reservation.isrc2  = rs2;
      reservation.isrc3  = imm;
      reservation.fsrc1  = frs1;
      reservation.fsrc2  = frs2;
      reservation.fsrc3  = frs3;
    end

  assign reservation_cast_o = reservation;
 
endmodule

