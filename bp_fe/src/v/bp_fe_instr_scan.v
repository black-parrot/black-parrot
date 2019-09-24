/*
 * bp_fe_instr_scan.v
 * 
 * Instr scan check if the intruction is aligned, compressed, or normal instruction.
 * The entire block is implemented in combinational logic, achieved within one cycle.
*/

module bp_fe_instr_scan
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_fe_pkg::*; 
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   , localparam instr_scan_width_lp = `bp_fe_instr_scan_width(vaddr_width_p)
   )
  (input [instr_width_p-1:0]          instr_i

   , output [instr_scan_width_lp-1:0] scan_o
  );

`declare_bp_fe_instr_scan_s(vaddr_width_p);

rv64_instr_s       instr_cast_i;
bp_fe_instr_scan_s scan_cast_o;

assign instr_cast_i = instr_i;
assign scan_o = scan_cast_o;

// TODO: compressed instruction support
wire is_compressed = (instr_i[1:0] != 2'b11);

always_comb
  begin
    unique casez (instr_cast_i.opcode)
      `RV64_BRANCH_OP: scan_cast_o.scan_class = e_rvi_branch;
      `RV64_JAL_OP   : scan_cast_o.scan_class = e_rvi_jal;
      `RV64_JALR_OP  : scan_cast_o.scan_class = e_rvi_jalr;
      default        : scan_cast_o.scan_class = e_default;
    endcase

    unique casez (instr_cast_i.opcode)
      `RV64_BRANCH_OP: scan_cast_o.imm = `rv64_signext_b_imm(instr_i);
      `RV64_JAL_OP   : scan_cast_o.imm = `rv64_signext_j_imm(instr_i);
      default        : scan_cast_o.imm = '0;
    endcase
  end

endmodule

