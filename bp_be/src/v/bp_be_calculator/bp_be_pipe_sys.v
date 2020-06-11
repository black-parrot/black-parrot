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
   , localparam exception_width_lp   = $bits(rv64_exception_dec_s)
   , localparam ptw_miss_pkt_width_lp = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp = `bp_be_ptw_fill_pkt_width(vaddr_width_p)
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

   , output logic [csr_cmd_width_lp-1:0]  csr_cmd_o
   , output logic                         csr_cmd_v_o
   , input logic [dword_width_p-1:0]      csr_data_i
   , input logic                          csr_exc_i

   , input [exception_width_lp-1:0]       exception_i
   , input                                itlb_miss_i
   , input                                dtlb_miss_i
   , input [vaddr_width_p-1:0]            exception_pc_i
   , input [vaddr_width_p-1:0]            exception_vaddr_i

   , output [ptw_miss_pkt_width_lp-1:0]   ptw_miss_pkt_o
   , input [ptw_fill_pkt_width_lp-1:0]    ptw_fill_pkt_i

   , output logic                         exc_v_o
   , output logic                         miss_v_o
   , output logic [dword_width_p-1:0]     data_o
   );

`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_mmu_structs(vaddr_width_p, ppn_width_p, lce_sets_p, cce_block_width_p/8)

bp_be_decode_s decode;
bp_be_csr_cmd_s csr_cmd_li, csr_cmd_r, csr_cmd_lo;
rv64_instr_s instr;
bp_be_ptw_miss_pkt_s ptw_miss_pkt;
bp_be_ptw_fill_pkt_s ptw_fill_pkt;

assign decode = decode_i;
assign instr = instr_i;
assign ptw_miss_pkt_o = ptw_miss_pkt;
assign ptw_fill_pkt = ptw_fill_pkt_i;

wire csr_imm_op = decode.fu_op inside {e_csrrwi, e_csrrsi, e_csrrci};

always_comb
  begin
    csr_cmd_li.csr_op   = decode.fu_op;
    csr_cmd_li.csr_addr = instr.fields.itype.imm12;
    csr_cmd_li.data     = csr_imm_op ? imm_i : rs1_i;
    csr_cmd_li.exc      = '0;
  end

logic csr_cmd_v_lo;
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
   ,.data_o(csr_cmd_r)
   );

// Track if an incoming tlb miss is store or load
logic is_store_r;
bsg_dff_chain
 #(.width_p(1)
   ,.num_stages_p(2)
   )
 store_reg
  (.clk_i(clk_i)

   ,.data_i(decode.dcache_w_v)
   ,.data_o(is_store_r)
   );

always_comb
  begin
    ptw_miss_pkt.instr_miss_v = ~kill_ex3_i & itlb_miss_i;
    ptw_miss_pkt.load_miss_v = ~kill_ex3_i & dtlb_miss_i & ~is_store_r;
    ptw_miss_pkt.store_miss_v = ~kill_ex3_i & dtlb_miss_i & is_store_r;
    ptw_miss_pkt.pc = exception_pc_i;
    ptw_miss_pkt.vaddr = itlb_miss_i ? exception_pc_i : exception_vaddr_i;
  end

always_comb
  begin
    csr_cmd_lo = csr_cmd_r;

    if (ptw_fill_pkt.instr_page_fault_v)
      begin
        csr_cmd_lo.exc.instr_page_fault = 1'b1;
      end
    else if (ptw_fill_pkt.store_page_fault_v)
      begin
        csr_cmd_lo.exc.store_page_fault = 1'b1;
      end
    else if (ptw_fill_pkt.load_page_fault_v)
      begin
        csr_cmd_lo.exc.load_page_fault = 1'b1;
      end
    else
      begin
        // Override data width vaddr for dtlb fill
        // Kill exception on ex3
        csr_cmd_lo.exc = kill_ex3_i ? '0 : exception_i;
        csr_cmd_lo.data = csr_cmd_lo.data;
      end
  end
assign csr_cmd_o = csr_cmd_lo;
assign csr_cmd_v_o = (csr_cmd_v_lo & ~kill_ex3_i);

assign data_o           = csr_data_i;
assign exc_v_o          = csr_exc_i;
assign miss_v_o         = 1'b0;

endmodule

