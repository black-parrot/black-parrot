/**
 *
 * Name:
 *   bp_be_pipe_mem.v
 * 
 * Description:
 *   Pipeline for RISC-V memory instructions. This includes both int + float loads + stores.
 *
 * Notes:
 *   
 */

module bp_be_pipe_mem 
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   , localparam exception_width_lp     = `bp_be_exception_width
   , localparam mmu_cmd_width_lp       = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mem_resp_width_lp      = `bp_be_mem_resp_width(vaddr_width_p)

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                                  clk_i
   , input                                reset_i

   , input                                kill_ex1_i
   , input                                kill_ex2_i
   , input                                kill_ex3_i

   , input [decode_width_lp-1:0]          decode_i
   , input [vaddr_width_p-1:0]            pc_i
   , input [rv64_instr_width_gp-1:0]      instr_i
   , input [reg_data_width_lp-1:0]        rs1_i
   , input [reg_data_width_lp-1:0]        rs2_i
   , input [reg_data_width_lp-1:0]        imm_i

   , output [mmu_cmd_width_lp-1:0]        mmu_cmd_o
   , output                               mmu_cmd_v_o
   , input                                mmu_cmd_ready_i

   , input  [mem_resp_width_lp-1:0]       mem_resp_i
   , input                                mem_resp_v_i

   , output logic                              exc_v_o
   , output logic                              miss_v_o
   , output logic [reg_data_width_lp-1:0]      data_o
   );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p/8)

// Cast input and output ports 
bp_be_decode_s    decode;
bp_be_mmu_cmd_s   mem1_cmd, mem3_cmd_li, mem3_cmd_lo, mem3_cmd;
bp_be_mem_resp_s  mem_resp;
rv64_instr_s      instr;

assign decode = decode_i;
assign mem_resp = mem_resp_i;
assign instr = instr_i;

// Suppress unused signal warnings
wire unused0 = kill_ex2_i;

logic mem1_cmd_v;

// Suppress unused signal warnings
wire unused2 = mmu_cmd_ready_i;

assign data_o = mem_resp.data;

logic [reg_data_width_lp-1:0] offset;

assign offset = decode.offset_sel ? '0 : imm_i[0+:vaddr_width_p];

assign mem1_cmd_v = (decode.dcache_r_v | decode.dcache_w_v) & ~kill_ex1_i;

wire fe_exc_v = (decode.fu_op == e_op_instr_misaligned)
                | (decode.fu_op == e_op_instr_access_fault)
                | (decode.fu_op == e_op_instr_page_fault)
                | (decode.fu_op == e_itlb_fill);
always_comb 
  begin
    mem1_cmd.mem_op   = decode.fu_op;
    mem1_cmd.data     = rs2_i;
    mem1_cmd.vaddr    = fe_exc_v ? pc_i : (rs1_i + offset);
  end

// Output results of memory op
assign exc_v_o            = mem_resp_v_i & ((mem_resp.store_page_fault | mem_resp.load_page_fault)
                                            | (mem_resp.store_access_fault | mem_resp.store_misaligned)
                                            | (mem_resp.load_access_fault | mem_resp.load_misaligned)
                                            );

assign miss_v_o           = mem_resp_v_i & (mem_resp.tlb_miss_v | mem_resp.cache_miss_v);

// Set MMU cmd signal
assign mmu_cmd_v_o = mem1_cmd_v;
assign mmu_cmd_o = mem1_cmd;

endmodule : bp_be_pipe_mem

