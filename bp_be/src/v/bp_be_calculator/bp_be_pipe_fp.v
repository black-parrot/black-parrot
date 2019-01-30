/**
 *
 * Name:
 *   bp_be_pipe_fp.v
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
 *   exc_i            - Exception information for a dispatched instruction
 *
 * Outputs:
 *   result_o         - The calculated result of the instruction
 *   
 * Keywords:
 *   calculator, fp, float, rvfd
 *
 * Notes:
 *
 */
module bp_be_pipe_fp
  import bp_be_pkg::*;
  import bp_be_rv64_pkg::*;
 #(// Generated parameters
   localparam decode_width_lp    = `bp_be_decode_width
   , localparam exception_width_lp = `bp_be_exception_width
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input logic                            clk_i
   , input logic                          reset_i

   // Common pipeline interface
   , input logic [decode_width_lp-1:0]    decode_i
   , input logic [reg_data_width_lp-1:0]  rs1_i
   , input logic [reg_data_width_lp-1:0]  rs2_i
   , input logic [exception_width_lp-1:0] exc_i

   // Pipeline result
   , output logic [reg_data_width_lp-1:0] result_o
   );

// Cast input and output ports 
bp_be_decode_s    decode;
bp_be_exception_s exc;

assign decode = decode_i;
assign exc    = exc_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;

wire [decode_width_lp-1:0]    unused2 = decode_i;
wire [reg_data_width_lp-1:0]  unused3 = rs1_i;
wire [reg_data_width_lp-1:0]  unused4 = rs2_i;
wire [exception_width_lp-1:0] unused5 = exc_i;


// Submodule connections

// Module instantiations

always_comb 
  begin : pipeline
    result_o = '0;
  end 

// Runtime assertions
always_comb 
  begin : runtime_assertions
    assert(~decode.pipe_fp_v) 
      else $warning("RV64FD not currently supported");
  end

endmodule : bp_be_pipe_fp

