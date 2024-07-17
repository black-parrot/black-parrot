/*
 * bp_fe_scan.v
 *
 * Instr scan check if the intruction is aligned, compressed, or normal instruction.
 * The entire block is implemented in combinational logic, achieved within one cycle.
*/

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_scan
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam scan_width_lp = $bits(bp_fe_scan_s)
   )
  (input [instr_width_gp-1:0]               instr_i
   , output logic [scan_width_lp-1:0] scan_o
   );

  `bp_cast_i(rv64_instr_rtype_s, instr);
  `bp_cast_o(bp_fe_scan_s, scan);

  rv64_cinstr_s cinstr_low_li, cinstr_high_li;
  assign cinstr_low_li = instr_i[0+:cinstr_width_gp];
  assign cinstr_high_li = instr_i[cinstr_width_gp+:cinstr_width_gp];

  logic scan_full, scan_clow, scan_chigh;
  logic dest_link, src_link, dest_src_eq;
  rv64_instr_s selected_instr;
  always_comb
    begin
      dest_link   = (instr_cast_i.rd_addr inside {32'h1, 32'h5});
      src_link    = (instr_cast_i.rs1_addr inside {32'h1, 32'h5});
      dest_src_eq = (instr_cast_i.rd_addr == instr_cast_i.rs1_addr);

      scan_full = &instr_i[0+:2];
      scan_clow = cinstr_low_li inside {`RV64_CBEQZ, `RV64_CBNEZ, `RV64_CJ, `RV64_CJR, `RV64_CJALR};
      scan_chigh = cinstr_high_li inside {`RV64_CBEQZ, `RV64_CBNEZ, `RV64_CJ, `RV64_CJR, `RV64_CJALR};

      dest_link   = (instr_cast_i.rd_addr inside {32'h1, 32'h5});
      src_link    = (instr_cast_i.rs1_addr inside {32'h1, 32'h5});
      dest_src_eq = dest_link & src_link & (instr_cast_i.rd_addr == instr_cast_i.rs1_addr);
      selected_instr = instr_i;

      if (compressed_support_p & ~scan_full & scan_clow)
        begin
          dest_link   = cinstr_low_li inside {`RV64_CJALR};
          src_link    = (cinstr_low_li.t.crtype.rdrs1_addr inside {32'h1, 32'h5});
          dest_src_eq = dest_link & src_link & (cinstr_low_li.t.crtype.rdrs1_addr == 5'h1);
          selected_instr = cinstr_low_li;
        end

      if (compressed_support_p & ~scan_full & ~scan_clow & scan_chigh)
        begin
          dest_link   = cinstr_high_li inside {`RV64_CJALR};
          src_link    = (cinstr_high_li.t.crtype.rdrs1_addr inside {32'h1, 32'h5});
          dest_src_eq = dest_link & src_link & (cinstr_high_li.t.crtype.rdrs1_addr == 5'h1);
          selected_instr = cinstr_high_li;
        end

      scan_cast_o.branch  = (selected_instr inside {`RV64_BRANCH, `RV64_CBEQZ, `RV64_CBNEZ});
      scan_cast_o.jal     = (selected_instr inside {`RV64_JAL, `RV64_CJ});
      scan_cast_o.jalr    = (selected_instr inside {`RV64_JALR, `RV64_CJR, `RV64_CJALR});
      scan_cast_o.call    = (selected_instr inside {`RV64_JAL, `RV64_JALR, `RV64_CJALR}) && dest_link;
      scan_cast_o._return = (selected_instr inside {`RV64_JALR, `RV64_CJR, `RV64_CJALR}) && src_link && !dest_src_eq;
      scan_cast_o.full    =  scan_full;
      scan_cast_o.clow    = ~scan_full &  scan_clow;
      scan_cast_o.chigh   = ~scan_full & ~scan_clow & scan_chigh;
    end

endmodule

