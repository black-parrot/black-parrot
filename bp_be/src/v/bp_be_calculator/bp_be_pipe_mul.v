/**
 *
 * Name:
 *   bp_be_pipe_mul.v
 * 
 * Description:
 *   Pipeline for RISC-V float instructions. Handles float and double computation.
 *
 * Parameters:
 *
 * Inputs:
 *   clk_i            -
 *   reset_i          -
 *
 *   decode_i         - All of the stage register information needed for a dispatched instruction
 *   rs1_i            - Source register data for the dispatched instruction
 *   rs2_i            - Source register data for the dispatched instruction
 *
 * Outputs:
 *   data_o           - The calculated result of the instruction
 *   
 * Keywords:
 *   calculator, mul, div, rv64m
 *
 * Notes:
 *
 */
module bp_be_pipe_mul
  import bp_be_pkg::*;
  import bp_common_rv64_pkg::*;
 #(// Generated parameters
   localparam decode_width_lp      = `bp_be_decode_width
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input                          kill_ex1_i
   , input                          kill_ex2_i

   , input [decode_width_lp-1:0]    decode_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i

   // Pipeline result
   , output logic [reg_data_width_lp-1:0] data_o
   );

// Cast input and output ports 
bp_be_decode_s    decode;

assign decode = decode_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;
wire unused2 = kill_ex1_i;
wire unused3 = kill_ex2_i;

wire [decode_width_lp-1:0]    unused4 = decode_i;
wire [reg_data_width_lp-1:0]  unused5 = rs1_i;
wire [reg_data_width_lp-1:0]  unused6 = rs2_i;

// Submodule connections

// Module instantiations
assign data_o = '0;

always_comb 
  begin : runtime_assertions
    // Fires immediately after reset
    //assert(reset_i | ~decode.pipe_mul_v) 
    //  else $warning("RV64M is not currently supported");
  end

endmodule : bp_be_pipe_mul
