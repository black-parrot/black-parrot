/*
 * bp_fe_instr_scan.v
 *
 * Instr scan check if the intruction is aligned, compressed, or normal instruction.
 * The entire block is implemented in combinational logic, achieved within one cycle.
*/

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_instr_scan
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam instr_scan_width_lp = $bits(bp_fe_instr_scan_s)
   )
  (input                                    instr_v_i
   , input [1:0]                            mask_i
   , input [instr_width_gp-1:0]             instr_i

   , output logic [instr_scan_width_lp-1:0] scan_o
   );

  `bp_cast_i(rv64_instr_rtype_s, instr);
  `bp_cast_o(bp_fe_instr_scan_s, scan);
  
  rv64_cinstr_s cinstr_low_li, cinstr_high_li;
  assign cinstr_low_li = instr_i[0+:cinstr_width_gp];
  assign cinstr_high_li = instr_i[cinstr_width_gp+:cinstr_width_gp];

  logic dest_link, src_link, dest_src_eq;

  logic branch_found;
  always_comb
    begin
      scan_cast_o = '0;
      branch_found = 0;

      if (instr_v_i & mask_i[0])
        begin
          dest_link   = (instr_cast_i.rd_addr inside {32'h1, 32'h5});
          src_link    = (instr_cast_i.rs1_addr inside {32'h1, 32'h5});
          dest_src_eq = (instr_cast_i.rd_addr == instr_cast_i.rs1_addr);

          scan_cast_o.branch  = (instr_cast_i.opcode == `RV64_BRANCH_OP);
          scan_cast_o.jal     = (instr_cast_i.opcode == `RV64_JAL_OP);
          scan_cast_o.jalr    = (instr_cast_i.opcode == `RV64_JALR_OP);
          scan_cast_o.call    = (instr_cast_i.opcode inside {`RV64_JAL_OP, `RV64_JALR_OP}) && dest_link;
          scan_cast_o._return = (instr_cast_i.opcode == `RV64_JALR_OP) && src_link && !dest_src_eq;

          unique casez (instr_cast_i.opcode)
            `RV64_BRANCH_OP: scan_cast_o.imm20 = `rv64_signext_b_imm(instr_i);
            `RV64_JAL_OP   : scan_cast_o.imm20 = `rv64_signext_j_imm(instr_i);
            default : begin end
          endcase
          branch_found = |{scan_cast_o.branch, scan_cast_o.jal, scan_cast_o.jalr};
        end

      //
      // TODO: low and high branches....
      // Low and high should both calculate targets...
      // Instruction scan isn't making an opinion, just telling PC gen what's happening

      // Opportunity for multiple branch prediction, but for now just assume only 1 branch
      //   per 32b fetch packet
      if (compressed_support_p & instr_v_i & mask_i[0] & ~branch_found)
        begin
          dest_link   = cinstr_low_li inside {`RV64_CJALR};
          src_link    = (cinstr_low_li.t.crtype.rdrs1_addr inside {32'h1, 32'h5});
          dest_src_eq = (cinstr_low_li.t.crtype.rdrs1_addr == 5'h1);

          scan_cast_o.branch  = (cinstr_low_li inside {`RV64_CBEQZ, `RV64_CBNEZ});
          scan_cast_o.jal     = (cinstr_low_li inside {`RV64_CJ});
          scan_cast_o.jalr    = (cinstr_low_li inside {`RV64_CJR, `RV64_CJALR});
          scan_cast_o.call    = (cinstr_low_li inside {`RV64_CJALR});
          scan_cast_o._return = (cinstr_low_li inside {`RV64_CJR, `RV64_CJALR}) && src_link && !dest_src_eq;
          scan_cast_o.clow    = 1'b1;

          unique casez (cinstr_low_li)
            `RV64_CJ:
              scan_cast_o.imm20 = dword_width_gp'($signed({cinstr_low_li[12], cinstr_low_li[8], cinstr_low_li[10:9], cinstr_low_li[6], cinstr_low_li[7], cinstr_low_li[2], cinstr_low_li[11], cinstr_low_li[5:3], 1'b0}));
            `RV64_CBEQZ, `RV64_CBNEZ:
              scan_cast_o.imm20 = dword_width_gp'($signed({cinstr_low_li[12], cinstr_low_li[6:5], cinstr_low_li[2], cinstr_low_li[11:10], cinstr_low_li[4:3], 1'b0}));
            default: begin end
          endcase
          branch_found = |{scan_cast_o.branch, scan_cast_o.jal, scan_cast_o.jalr};
        end

      if (compressed_support_p & instr_v_i & mask_i[1] & ~branch_found)
        begin
          dest_link   = cinstr_high_li inside {`RV64_CJALR};
          src_link    = (cinstr_high_li.t.crtype.rdrs1_addr inside {32'h1, 32'h5});
          dest_src_eq = (cinstr_high_li.t.crtype.rdrs1_addr == 5'h1);

          scan_cast_o.branch  = (cinstr_high_li inside {`RV64_CBEQZ, `RV64_CBNEZ});
          scan_cast_o.jal     = (cinstr_high_li inside {`RV64_CJ});
          scan_cast_o.jalr    = (cinstr_high_li inside {`RV64_CJR, `RV64_CJALR});
          scan_cast_o.call    = (cinstr_high_li inside {`RV64_CJALR});
          scan_cast_o._return = (cinstr_high_li inside {`RV64_CJR, `RV64_CJALR}) && src_link && !dest_src_eq;
          scan_cast_o.chigh   = 1'b1;

          unique casez (cinstr_high_li)
            `RV64_CJ:
              scan_cast_o.imm20 = dword_width_gp'($signed({cinstr_high_li[12], cinstr_high_li[8], cinstr_high_li[10:9], cinstr_high_li[6], cinstr_high_li[7], cinstr_high_li[2], cinstr_high_li[11], cinstr_high_li[5:3], 1'b0}));
            `RV64_CBEQZ, `RV64_CBNEZ:
              scan_cast_o.imm20 = dword_width_gp'($signed({cinstr_high_li[12], cinstr_high_li[6:5], cinstr_high_li[2], cinstr_high_li[11:10], cinstr_high_li[4:3], 1'b0}));
            default: begin end
          endcase
          // This is safe because the compressed immediate will never be >12b
          scan_cast_o.imm20 += 2'b10;
          branch_found = |{scan_cast_o.branch, scan_cast_o.jal, scan_cast_o.jalr};
        end
    end

endmodule

