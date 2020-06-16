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
   , localparam mmu_cmd_width_lp       = `bp_be_mmu_cmd_width
   , localparam csr_cmd_width_lp       = `bp_be_csr_cmd_width
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

   , output [csr_cmd_width_lp-1:0]        csr_cmd_o
   , output                               csr_cmd_v_o
   , input                                csr_cmd_ready_i

   , input  [mem_resp_width_lp-1:0]       mem_resp_i
   , input                                mem_resp_v_i
   , output                               mem_resp_ready_o

   , output logic                              exc_v_o
   , output logic                              miss_v_o
   , output logic [reg_data_width_lp-1:0]      data_o
   );

// Declare parameterizable structs
`declare_bp_be_mmu_structs

// Cast input and output ports 
bp_be_decode_s    decode;
bp_be_mmu_cmd_s   mem1_cmd, mem3_cmd_li, mem3_cmd_lo, mem3_cmd;
bp_be_csr_cmd_s   csr_cmd_li, csr_cmd_lo;
bp_be_mem_resp_s  mem_resp;
rv64_instr_s      instr;

assign decode = decode_i;
assign mem_resp = mem_resp_i;
assign csr_cmd_o = csr_cmd_lo;
assign instr = instr_i;

// Suppress unused signal warnings
wire unused0 = kill_ex2_i;

logic csr_cmd_v_lo, mem1_cmd_v;

// Suppress unused signal warnings
wire unused2 = mmu_cmd_ready_i;
wire unused3 = csr_cmd_ready_i;

assign data_o = mem_resp.data;

bsg_shift_reg
 #(.width_p(csr_cmd_width_lp)
   ,.stages_p(2)
   )
 csr_shift_reg
  (.clk(clk_i)
   ,.reset_i(reset_i)

   ,.valid_i(decode.csr_v)
   ,.data_i(csr_cmd_li)

   ,.valid_o(csr_cmd_v_lo)
   ,.data_o(csr_cmd_lo)
   );

logic [reg_data_width_lp-1:0] offset;

assign offset = decode.offset_sel ? '0 : imm_i;

assign mem1_cmd_v = (decode.dcache_r_v | decode.dcache_w_v) & ~kill_ex1_i;

wire fe_exc_v = (decode.fu_op == e_op_instr_misaligned)
                | (decode.fu_op == e_op_instr_access_fault)
                | (decode.fu_op == e_op_instr_page_fault)
                | (decode.fu_op == e_itlb_fill);

wire pc_sigext = pc_i[38];
always_comb 
  begin
    mem1_cmd.mem_op   = decode.fu_op;
    mem1_cmd.data     = rs2_i;
    mem1_cmd.eaddr    = fe_exc_v ? {{25{pc_sigext}}, pc_i} : (rs1_i + offset);
  end

assign csr_cmd_v_o = csr_cmd_v_lo & ~kill_ex3_i;
wire csr_imm_op = (decode.fu_op == e_csrrwi) 
                  | (decode.fu_op == e_csrrsi) 
                  | (decode.fu_op == e_csrrci);
always_comb
  begin
    csr_cmd_li.csr_op   = decode.fu_op;
    csr_cmd_li.csr_addr = instr.fields.itype.imm12;
    csr_cmd_li.data     = csr_imm_op ? imm_i : rs1_i;
  end

// Output results of memory op
assign exc_v_o            = mem_resp_v_i & mem_resp.exc_v;
assign miss_v_o           = mem_resp_v_i & mem_resp.miss_v;
assign mem_resp_ready_o   = 1'b1;

// Set MMU cmd signal
assign mmu_cmd_v_o = mem1_cmd_v;
assign mmu_cmd_o = mem1_cmd;

endmodule : bp_be_pipe_mem

