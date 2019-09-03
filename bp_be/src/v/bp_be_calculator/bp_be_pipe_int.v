/**
 *
 * Name:
 *   bp_be_pipe_int.v
 * 
 * Description:
 *   Pipeline for RISC-V integer instructions. Handles integer computation.
 *
 * Parameters:
 *   num_core_p       - 
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
 * Outputs:
 *   data_o           - The calculated result of the instruction
 *   br_tgt_o         - The calculated branch target from branch instructions
 *   
 * Keywords:
 *   calculator, alu, int, integer, rv64i
 *
 * Notes:
 *   
 */
module bp_be_pipe_int 
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p = "inv"

   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   , localparam exception_width_lp   = `bp_be_exception_width
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input                          kill_ex1_i

   , input [decode_width_lp-1:0]    decode_i
   , input [vaddr_width_p-1:0]      pc_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i
   , input [reg_data_width_lp-1:0]  imm_i

   // Pipeline results
   , output [reg_data_width_lp-1:0] data_o

   , output [vaddr_width_p-1:0]     br_tgt_o
   );

// Cast input and output ports 
bp_be_decode_s      decode;

assign decode = decode_i;

// Suppress unused signal warning
wire unused0 = clk_i;
wire unused1 = reset_i;
wire unused2 = kill_ex1_i;

// Sign-extend PC for calculation
wire [reg_data_width_lp-1:0] pc_sext_li = reg_data_width_lp'($signed(pc_i));

// Submodule connections
logic [reg_data_width_lp-1:0] src1, src2, baddr, alu_result;
logic [reg_data_width_lp-1:0] pc_plus4;
logic [reg_data_width_lp-1:0] data_lo;

// Perform the actual ALU computation
bp_be_int_alu 
 alu
  (.src1_i(src1)
   ,.src2_i(src2)
   ,.op_i(decode.fu_op)
   ,.opw_v_i(decode.opw_v)

   ,.result_o(alu_result)
   );

always_comb 
  begin 
    src1     = decode.src1_sel  ? pc_sext_li : rs1_i;
    src2     = decode.src2_sel  ? imm_i      : rs2_i;
    baddr    = decode.baddr_sel ? src1       : pc_sext_li;
    pc_plus4 = pc_sext_li + reg_data_width_lp'(4);
  end

assign data_o   = decode.result_sel
                  ? pc_plus4
                  : alu_result;
assign br_tgt_o = baddr + imm_i;

endmodule : bp_be_pipe_int

