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
   , parameter core_els_p                = "inv"
   // Generated parameters
   , localparam decode_width_lp    = `bp_be_decode_width
   , localparam exception_width_lp = `bp_be_exception_width
   , localparam mmu_cmd_width_lp   = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mmu_resp_width_lp  = `bp_be_mmu_resp_width
   , localparam mhartid_width_lp   = `BSG_SAFE_CLOG2(core_els_p)

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   , input                          kill_v_i
   , input [decode_width_lp-1:0]    decode_i
   , input [reg_data_width_lp-1:0]  rs1_i
   , input [reg_data_width_lp-1:0]  rs2_i
   , input [reg_data_width_lp-1:0]  imm_i

   , output [mmu_cmd_width_lp-1:0]  mmu_cmd_o
   , output                         mmu_cmd_v_o
   , input                          mmu_cmd_ready_i

   , input  [mmu_resp_width_lp-1:0] mmu_resp_i
   , input                          mmu_resp_v_i
   , output                         mmu_resp_ready_o

   , output [reg_data_width_lp-1:0] result_o
   , output                         cache_miss_o

   // CSR interface
   , input [mhartid_width_lp-1:0]   mhartid_i
   , input [reg_data_width_lp-1:0]  mcycle_i
   , input [reg_data_width_lp-1:0]  mtime_i
   , input [reg_data_width_lp-1:0]  minstret_i

   , output [reg_data_width_lp-1:0] mtvec_o
   , output                         mtvec_w_v_o
   , input  [reg_data_width_lp-1:0] mtvec_i

   , output [reg_data_width_lp-1:0] mtval_o
   , output                         mtval_w_v_o
   , input [reg_data_width_lp-1:0]  mtval_i

   , output [reg_data_width_lp-1:0] mepc_o
   , output                         mepc_w_v_o
   , input [reg_data_width_lp-1:0]  mepc_i

   , output [reg_data_width_lp-1:0] mscratch_o
   , output                         mscratch_w_v_o
   , input  [reg_data_width_lp-1:0] mscratch_i
   );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)

// Cast input and output ports 
bp_be_decode_s    decode;
bp_be_exception_s exc;
bp_be_mmu_cmd_s   mmu_cmd;
bp_be_mmu_resp_s  mmu_resp;

logic [reg_data_width_lp-1:0] result;

assign decode    = decode_i;
assign mmu_cmd_o = mmu_cmd;
assign mmu_resp  = mmu_resp_i;
assign result_o  = result;

bp_be_decode_s                decode_r;
logic [reg_data_width_lp-1:0] rs1_r, imm_r;

// Suppress unused signal warnings
wire unused2 = mmu_cmd_ready_i;

bsg_shift_reg
 #(.width_p(decode_width_lp+reg_data_width_lp*2)
   ,.stages_p(2)
   )
 csr_shift_reg
  (.clk(clk_i)
   ,.reset_i(reset_i)
   ,.valid_i(decode.csr_instr_v)
   ,.data_i({decode, rs1_i, imm_i})
   ,.valid_o(/* We look at decode for valid_o */)
   ,.data_o({decode_r, rs1_r, imm_r})
   );


// Module instantiations
assign mmu_cmd_v_o    = (decode.dcache_r_v | decode.dcache_w_v) & ~kill_v_i;
always_comb 
  begin
    mmu_cmd.mem_op = decode.fu_op;
    mmu_cmd.data   = rs2_i;
    mmu_cmd.vaddr  = (rs1_i + imm_i[0+:vaddr_width_p]);
  end 

// Output results of memory op
assign mmu_resp_ready_o = 1'b1;
assign cache_miss_o     = mmu_resp.exception.cache_miss_v;
assign mtvec_o          = rs1_r;
assign mtvec_w_v_o      = decode_r.mtvec_rw_v;
assign mtval_o          = rs1_r;
assign mtval_w_v_o      = decode_r.mtval_rw_v;
assign mepc_o           = rs1_r;
assign mepc_w_v_o       = decode_r.mepc_rw_v;
assign mscratch_o       = rs1_r;
assign mscratch_w_v_o   = decode_r.mscratch_rw_v;

always_comb
  begin
    unique if (decode_r.mhartid_r_v)   result = reg_data_width_lp'(mhartid_i);
    else   if (decode_r.mcycle_r_v)    result = mcycle_i;
    else   if (decode_r.mtime_r_v)     result = mtime_i;
    else   if (decode_r.minstret_r_v)  result = minstret_i;
    else   if (decode_r.mtvec_rw_v)    result = mtvec_i;
    else   if (decode_r.mtval_rw_v)    result = mtval_i;
    else   if (decode_r.mepc_rw_v)     result = mepc_i;
    else   if (decode_r.mscratch_rw_v) result = mscratch_i;
    else   if (mmu_resp_v_i)           result = mmu_resp.data;
    else                               result = '0;
  end

endmodule : bp_be_pipe_mem

