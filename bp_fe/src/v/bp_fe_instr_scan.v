/*
 *bp_fe_instr_scan.v
 * 
 *Instr scan check if the intruction is aligned, compressed, or normal instruction.
 *The entire block is implemented in combinational logic, achieved within one cycle.
*/

module instr_scan
 import bp_common_pkg::*;
 import bp_fe_pkg::*; 
 #(parameter vaddr_width_p="inv"
   , parameter instr_width_p="inv"
   , localparam bp_fe_instr_scan_width_lp=`bp_fe_instr_scan_width 
  ) 
  (input [instr_width_p-1:0]                      instr_i
   , output logic [bp_fe_instr_scan_width_lp-1:0] scan_o
  );

   
//assign the struct to the port signals
bp_fe_instr_scan_s scan;
assign scan_o = scan;
   
//is_compressed signal indicates if the instruction from icache is compressed
assign scan.is_compressed = (instr_i[1:0] != 2'b11);

assign scan.instr_scan_class = bp_fe_instr_scan_class_e'(
  (instr_i[6:0]   == `opcode_rvi_branch) ? `bp_fe_instr_scan_class_width'(e_rvi_branch) :
  (instr_i[6:0]   == `opcode_rvi_jalr  ) ? `bp_fe_instr_scan_class_width'(e_rvi_jalr  ) :
  (instr_i[6:0]   == `opcode_rvi_jal   ) ? `bp_fe_instr_scan_class_width'(e_rvi_jal   ) :
                                           `bp_fe_instr_scan_class_width'(e_default   ) );

endmodule


