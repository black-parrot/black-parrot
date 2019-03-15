/**
 *
 * Name:
 *   bp_be_pipe_int.v
 * 
 * Description:
 *   Pipeline for RISC-V integer instructions. Handles integer computation and mhartid requests.
 *
 * Parameters:
 *   core_els_p       - 
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
 *   
 */
module bp_be_pipe_int 
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter core_els_p = "inv"
   // Generated parameters
   , localparam decode_width_lp    = `bp_be_decode_width
   , localparam exception_width_lp = `bp_be_exception_width
   , localparam mhartid_width_lp   = `BSG_SAFE_CLOG2(core_els_p)
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Common pipeline interface
   , input [decode_width_lp-1:0]    decode_i
   , input [reg_data_width_lp-1:0]  pc_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i
   , input [reg_data_width_lp-1:0]  imm_i
   , input [exception_width_lp-1:0] exc_i

   // For mhartid CSR
   , input [mhartid_width_lp-1:0]   mhartid_i

   // Pipeline results
   , output logic [reg_data_width_lp-1:0] result_o
   , output logic [reg_data_width_lp-1:0] br_tgt_o
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
logic [reg_data_width_lp-1:0] src1, src2, baddr, alu_result;
logic [reg_data_width_lp-1:0] pc_plus4, mhartid;
logic [reg_data_width_lp-1:0] src1_r, src2_r, src1_gated, src2_gated;

 assign src1_gated = decode.pipe_int_v ? src1 : src1_r;
assign src2_gated = decode.pipe_int_v ? src2 : src2_r;

 bsg_dff_en #(.width_p(reg_data_width_lp)) src1_dff (
  .clk_i(clk_i&decode.pipe_int_v)
  ,.data_i(src1)
  ,.en_i(decode.pipe_int_v)
  ,.data_o(src1_r)
  );

 bsg_dff_en #(.width_p(reg_data_width_lp)) src2_dff (
  .clk_i(clk_i&decode.pipe_int_v)
  ,.data_i(src2)
  ,.en_i(decode.pipe_int_v)
  ,.data_o(src2_r)
  );

// Perform the actual ALU computation
bp_be_int_alu 
 alu
  (.src1_i(src1_gated)
   ,.src2_i(src2_gated)
   ,.op_i(decode.fu_op&{4{decode.pipe_int_v}})
   ,.opw_v_i(decode.opw_v)

   ,.result_o(alu_result)
   );

always_comb 
  begin 
    src1  = decode.src1_sel  ? pc_i  : rs1_i;
    src2  = decode.src2_sel  ? imm_i : rs2_i;
    baddr = decode.baddr_sel ? src1  : pc_i ;

    result_o = decode.mhartid_r_v 
               ? mhartid 
               : decode.result_sel
                 ? pc_plus4
                 : alu_result;
  end

always_comb 
  begin : aux_compute
    mhartid          = reg_data_width_lp'(mhartid_i);
    pc_plus4         = pc_i + reg_data_width_lp'(4);
    br_tgt_o         = baddr + imm_i;
  end

endmodule : bp_be_pipe_int

