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
  (input [instr_width_gp-1:0]               instr_i

   , output logic [instr_scan_width_lp-1:0] scan_o
   , output logic [vaddr_width_p-1:0]       imm_o
   );

  `bp_cast_i(rv64_instr_rtype_s, instr);
  `bp_cast_o(bp_fe_instr_scan_s, scan);
  
  wire dest_link   = (instr_cast_i.rd_addr inside {32'h1, 32'h5});
  wire src_link    = (instr_cast_i.rs1_addr inside {32'h1, 32'h5});
  wire dest_src_eq = (instr_cast_i.rd_addr == instr_cast_i.rs1_addr);
  
  always_comb
    begin
      scan_cast_o = '0;
  
      scan_cast_o.branch = (instr_cast_i.opcode == `RV64_BRANCH_OP);
      scan_cast_o.jal    = (instr_cast_i.opcode == `RV64_JAL_OP);
      scan_cast_o.jalr   = (instr_cast_i.opcode == `RV64_JALR_OP);
      scan_cast_o.call   = (instr_cast_i.opcode inside {`RV64_JAL_OP, `RV64_JALR_OP}) && dest_link;
      scan_cast_o._return = (instr_cast_i.opcode == `RV64_JALR_OP) && src_link && !dest_src_eq;
  
      unique casez (instr_cast_i.opcode)
        `RV64_BRANCH_OP: imm_o = `rv64_signext_b_imm(instr_i);
        `RV64_JAL_OP   : imm_o = `rv64_signext_j_imm(instr_i);
        default        : imm_o = '0;
      endcase
    end

endmodule

