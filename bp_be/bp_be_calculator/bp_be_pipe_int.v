/**
 *
 * Name:
 *   bp_be_pipe_int.v
 * 
 * Description:
 *   Pipeline for RISC-V integer instructions. Handles integer computation and mhartid requests.
 *
 * Parameters:
 *
 * Inputs:
 *   clk_i            -
 *   reset_i          -
 *
 *   decode_i         - All of the pipeline control information needed for a dispatched instruction
 *   pc_i             - PC of the dispatched instruction
 *   rs1_i            - Source register data for the dispatched instruction
 *   rs2_i            - Source register data for the dispatched instruction
 *   imm_i            - Immediate data for the dispatched instruction
 *   exc_i            - Exception information for a dispatched instruction
 * 
 *   mhartid_i        - The hartid for this core
 *
 * Outputs:
 *   result_o         - The calculated result of the instruction
 *   br_tgt_o         - The calculated branch target from branch instructions
 *   
 * Keywords:
 *   calculator, alu, int, integer, rv64i
 *
 * Notes:
 *   We could also replace explicit muxes with case statements, not sure which is clearer.
 */
module bp_be_pipe_int 
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(// Generated parameters
   localparam decode_width_lp    = `bp_be_decode_width
   , localparam exception_width_lp = `bp_be_exception_width
   , localparam mhartid_width_lp   = `bp_mhartid_width
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input logic                           clk_i
   , input logic                         reset_i

   // Common pipeline interface
   , input logic[decode_width_lp-1:0]    decode_i
   , input logic[reg_data_width_lp-1:0]  pc_i
   , input logic[reg_data_width_lp-1:0]  rs1_i
   , input logic[reg_data_width_lp-1:0]  rs2_i
   , input logic[reg_data_width_lp-1:0]  imm_i
   , input logic[exception_width_lp-1:0] exc_i

   // For mhartid CSR
   , input logic[mhartid_width_lp-1:0]   mhartid_i

   // Pipeline results
   , output logic[reg_data_width_lp-1:0] result_o
   , output logic[reg_data_width_lp-1:0] br_tgt_o
   );

// Cast input and output ports 
bp_be_decode_s     decode;
bp_be_exception_s  exc;

assign decode = decode_i;
assign exc    = exc_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;

// Submodule connections
logic [reg_data_width_lp-1:0] src1      , src2            , baddr;
logic [reg_data_width_lp-1:0] alu_result, result;

logic [reg_data_width_lp-1:0] pc_plus4 , mhartid;

// Module instantiations
bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   )
 src1_mux
  (.data_i({pc_i, rs1_i})
   ,.sel_i(decode.src1_sel)
   ,.data_o(src1)
   );

bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   )
 src2_mux
  (.data_i({imm_i, rs2_i})
   ,.sel_i(decode.src2_sel)
   ,.data_o(src2)
   );

bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   )
 baddr_mux
  (.data_i({src1, pc_i})
   ,.sel_i(decode.baddr_sel)
   ,.data_o(baddr)
   );

bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   )
 result_mux
  (.data_i({pc_plus4, alu_result})
   ,.sel_i(decode.result_sel)
   ,.data_o(result)
   );

bsg_mux 
 #(.width_p(reg_data_width_lp)
   ,.els_p(2)
   )
 mhartid_mux
  (.data_i({mhartid, result})
   ,.sel_i(decode.mhartid_r_v)
   ,.data_o(result_o)
   );

// Perform the actual ALU computation
bp_be_int_alu 
alu
  (.src1_i(src1)
   ,.src2_i(src2)
   ,.op_i(decode.fu_op)
   ,.opw_v_i(decode.opw_v)

   ,.result_o(alu_result)
   );

// Auxillary computation
always_comb begin
  mhartid          = reg_data_width_lp'(mhartid_i);
  pc_plus4         = pc_i + reg_data_width_lp'(4);
  br_tgt_o         = baddr + imm_i;
end

endmodule : bp_be_pipe_int

