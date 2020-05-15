/**
 *
 * Name:
 *   bp_be_pipe_sys.v
 * 
 * Description:
 *
 * Notes:
 *   
 */
module bp_be_pipe_sys
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam csr_cmd_width_lp       = `bp_be_csr_cmd_width
   , localparam mem_resp_width_lp      = `bp_be_mem_resp_width(vaddr_width_p)
   // Generated parameters
   , localparam decode_width_lp      = `bp_be_decode_width
   , localparam exception_width_lp   = `bp_be_exception_width
   )
  (input                                  clk_i
   , input                                reset_i

   , input [decode_width_lp-1:0]          decode_i
   , input [vaddr_width_p-1:0]            pc_i
   , input [instr_width_p-1:0]            instr_i
   , input [dword_width_p-1:0]            rs1_i
   , input [dword_width_p-1:0]            rs2_i
   , input [dword_width_p-1:0]            imm_i

   , input                                kill_ex1_i
   , input                                kill_ex2_i
   , input                                kill_ex3_i

   , output [csr_cmd_width_lp-1:0]        csr_cmd_o
   , output                               csr_cmd_v_o
   , input                                csr_cmd_ready_i

   , input  [mem_resp_width_lp-1:0]       mem_resp_i
   , input                                mem_resp_v_i
   , output                               mem_resp_ready_o

   , output logic                         exc_v_o
   , output logic                         miss_v_o
   , output logic [dword_width_p-1:0]     data_o
   );

`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p/8)

bp_be_decode_s    decode;
bp_be_csr_cmd_s csr_cmd_li, csr_cmd_lo;
bp_be_mem_resp_s mem_resp;
rv64_instr_s      instr;

assign decode = decode_i;
assign instr = instr_i;
assign mem_resp = mem_resp_i;

wire csr_imm_op = decode.fu_op inside {e_csrrwi, e_csrrsi, e_csrrci};

always_comb
  begin
    csr_cmd_li.csr_op   = decode.fu_op;
    csr_cmd_li.csr_addr = instr.fields.itype.imm12;
    csr_cmd_li.data     = csr_imm_op ? imm_i : rs1_i;
  end

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

assign csr_cmd_o = csr_cmd_lo;
assign csr_cmd_v_o = (csr_cmd_v_lo & ~kill_ex3_i);

assign data_o           = mem_resp.data;
assign exc_v_o          = mem_resp_v_i;
assign miss_v_o         = 1'b0;
assign mem_resp_ready_o = 1'b1;


endmodule

