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
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam instr_scan_width_lp = `bp_fe_instr_scan_width(vaddr_width_p)
   )
  (input [instr_width_p-1:0]          instr_i

   , output [instr_scan_width_lp-1:0] scan_o
  );

`declare_bp_fe_instr_scan_s(vaddr_width_p);

rv64_instr_rtype_s instr_cast_i;
bp_fe_instr_scan_s scan_cast_o;

assign instr_cast_i = instr_i;
assign scan_o = scan_cast_o;

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
    scan_cast_o.ret    = (instr_cast_i.opcode == `RV64_JALR_OP) && src_link && !dest_src_eq;

    unique casez (instr_cast_i.opcode)
      `RV64_BRANCH_OP: scan_cast_o.imm = `rv64_signext_b_imm(instr_i);
      `RV64_JAL_OP   : scan_cast_o.imm = `rv64_signext_j_imm(instr_i);
      default        : scan_cast_o.imm = '0;
    endcase
  end

endmodule

