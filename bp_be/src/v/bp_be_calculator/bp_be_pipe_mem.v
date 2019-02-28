/**
 *
 * Name:
 *   bp_be_pipe_mem.v
 * 
 * Description:
 *   Pipeline for RISC-V memory instructions. This includes both int + float loads + stores.
 *
 * Parameters:
 *   vaddr_width_p    -
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
 *   mmu_resp_i       - Load / store response from the MMU.
 *   mmu_resp_v_i     - 'ready-then-valid' interface
 *   mmu_resp_ready_o   - 

 *
 * Outputs:
 *   mmu_cmd_o        -  Load / store command to the MMU
 *   mmu_cmd_v_o      -  'ready-then-valid' interface
 *   mmu_cmd_ready_i    - 
 * 
 *   result_o         - The calculated result of a load
 *   cache_miss_o     - Goes high when the result of the load is a cache miss 
 *   
 * Keywords:
 *   calculator, mem, mmu, load, store, rv64i, rv64f
 *
 * Notes:
 *   
 */

module bp_be_pipe_mem 
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p               = "inv"
   , parameter lce_sets_p                = "inv"
   , parameter cce_block_size_in_bytes_p = "inv"
   // Generated parameters
   , localparam decode_width_lp    = `bp_be_decode_width
   , localparam exception_width_lp = `bp_be_exception_width
   , localparam mmu_cmd_width_lp   = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mmu_resp_width_lp  = `bp_be_mmu_resp_width

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   , input [decode_width_lp-1:0]    decode_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i
   , input [reg_data_width_lp-1:0]  imm_i
   , input [exception_width_lp-1:0] exc_i

   , output [mmu_cmd_width_lp-1:0]  mmu_cmd_o
   , output                         mmu_cmd_v_o
   , input                          mmu_cmd_ready_i

   , input  [mmu_resp_width_lp-1:0] mmu_resp_i
   , input                          mmu_resp_v_i
   , output                         mmu_resp_ready_o

   , output [reg_data_width_lp-1:0] result_o
   , output                         cache_miss_o
   );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)

// Cast input and output ports 
bp_be_decode_s    decode;
bp_be_exception_s exc;
bp_be_mmu_cmd_s   mmu_cmd;
bp_be_mmu_resp_s  mmu_resp;

assign decode    = decode_i;
assign exc       = exc_i;
assign mmu_cmd_o = mmu_cmd;
assign mmu_resp  = mmu_resp_i;

// Suppress unused signal warnings
wire unused0 = clk_i;
wire unused1 = reset_i;
wire unused2 = mmu_cmd_ready_i;
wire unused3 = mmu_resp_v_i;



// Module instantiations
assign mmu_cmd_v_o    = (decode.dcache_r_v | decode.dcache_w_v) & ~|exc;
always_comb 
  begin
    mmu_cmd.mem_op = decode.fu_op;
    mmu_cmd.data   = rs2_i;
    mmu_cmd.vaddr  = (rs1_i + imm_i[0+:vaddr_width_p]);
  end 

// Output results of memory op
assign mmu_resp_ready_o = 1'b1;
assign result_o         = mmu_resp.data;
assign cache_miss_o     = mmu_resp.exception.cache_miss_v;

endmodule : bp_be_pipe_mem

