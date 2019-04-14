/**
 *
 *  Name:
 *    bp_be_top.v
 * 
 */


module bp_be_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   // Default parameters 
   , parameter load_to_use_forwarding_p    = 1
   , parameter trace_p                     = 0
   , parameter calc_debug_p                = 0
   , parameter calc_debug_file_p           = "calc_debug.log"

   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(num_core_p, num_lce_p)
   , localparam ecode_dec_width_lp         = `bp_be_ecode_dec_width
   
   // VM parameters
   , localparam vtag_width_lp     = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp     = (paddr_width_p-bp_page_offset_width_gp)
   , localparam tlb_entry_width_lp = `bp_be_tlb_entry_width(ptag_width_lp)

   // CSRs
   , localparam mepc_width_lp  = `bp_mepc_width
   , localparam mtvec_width_lp = `bp_mtvec_width
   )
  (input                                     clk_i
   , input                                   reset_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_ready_o

   , output                                  fe_queue_clr_o
   , output                                  fe_queue_dequeue_o
   , output                                  fe_queue_rollback_o
 
   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_ready_i

   // LCE-CCE interface
   , output [lce_cce_req_width_lp-1:0]       lce_req_o
   , output                                  lce_req_v_o
   , input                                   lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]      lce_resp_o
   , output                                  lce_resp_v_o
   , input                                   lce_resp_ready_i                                 

   , output [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output                                  lce_data_resp_v_o
   , input                                   lce_data_resp_ready_i

   , input [cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   , input                                   lce_cmd_v_i
   , output                                  lce_cmd_ready_o

   , input [lce_data_cmd_width_lp-1:0]       lce_data_cmd_i
   , input                                   lce_data_cmd_v_i
   , output                                  lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]      lce_data_cmd_o
   , output                                  lce_data_cmd_v_o
   , input                                   lce_data_cmd_ready_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   , input                                   timer_int_i
   , input                                   software_int_i
   , input                                   external_int_i

   // Commit tracer for trace replay
   , output                                  cmt_rd_w_v_o
   , output [rv64_reg_addr_width_gp-1:0]     cmt_rd_addr_o
   , output                                  cmt_mem_w_v_o
   , output [dword_width_p-1:0]              cmt_mem_addr_o
   , output [`bp_be_fu_op_width-1:0]         cmt_mem_op_o
   , output [dword_width_p-1:0]              cmt_data_o
   );

// Declare parameterized structures
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_width_p)
`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );
`declare_bp_be_tlb_entry_s(ptag_width_lp);

// Casting
bp_proc_cfg_s proc_cfg;

assign proc_cfg = proc_cfg_i;

// Top-level interface connections
bp_be_issue_pkt_s issue_pkt;
logic issue_pkt_v, issue_pkt_rdy;

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_csr_cmd_s csr_cmd;
logic csr_cmd_v, csr_cmd_rdy;

bp_be_mem_resp_s mem_resp;
logic mem_resp_v, mem_resp_rdy;

bp_be_tlb_entry_s         itlb_fill_entry;
logic [vtag_width_lp-1:0] itlb_fill_vtag;
logic                     itlb_fill_v;

bp_be_calc_status_s    calc_status;

logic chk_dispatch_v, chk_poison_isd;
logic chk_poison_ex1, chk_poison_ex2, chk_poison_ex3, chk_roll, chk_instr_dequeue_v;

logic [mtvec_width_lp-1:0] chk_mtvec_li;
logic [mepc_width_lp-1:0]  chk_mepc_li;
logic [vaddr_width_p-1:0]  chk_pc_lo;

logic                      instret;
logic [vaddr_width_p-1:0]  exception_pc;
logic [instr_width_p-1:0]  exception_instr;
logic [ecode_dec_width_lp-1:0] exception_ecode_dec;
logic                      exception_v;
logic                      mret_v;
logic                      sret_v;
logic                      uret_v;

// Module instantiations
bp_be_checker_top 
 #(.cfg_p(cfg_p)

   ,.load_to_use_forwarding_p(load_to_use_forwarding_p)
   )
 be_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.chk_dispatch_v_o(chk_dispatch_v)
   ,.chk_roll_o(chk_roll)
   ,.chk_poison_isd_o(chk_poison_isd)
   ,.chk_poison_ex1_o(chk_poison_ex1)
   ,.chk_poison_ex2_o(chk_poison_ex2)
   ,.chk_poison_ex3_o(chk_poison_ex3)

   ,.calc_status_i(calc_status)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)

   ,.chk_roll_fe_o(fe_queue_rollback_o)
   ,.chk_flush_fe_o(fe_queue_clr_o)
   ,.chk_dequeue_fe_o(fe_queue_dequeue_o)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_ready_o(fe_queue_ready_o)

   ,.issue_pkt_o(issue_pkt)
   ,.issue_pkt_v_o(issue_pkt_v)
   ,.issue_pkt_ready_i(issue_pkt_rdy)

   ,.pc_o(chk_pc_lo)
   ,.mepc_i(chk_mepc_li)
   ,.mtvec_i(chk_mtvec_li)
   
   ,.itlb_fill_v_i(itlb_fill_v)
   ,.itlb_fill_vtag_i(itlb_fill_vtag)
   ,.itlb_fill_entry_i(itlb_fill_entry)
   );

bp_be_calculator_top 
 #(.cfg_p(cfg_p)

   ,.load_to_use_forwarding_p(load_to_use_forwarding_p)
   ,.trace_p(trace_p)
   ,.debug_p(calc_debug_p)
   ,.debug_file_p(calc_debug_file_p)
   )
 be_calculator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.issue_pkt_i(issue_pkt)
   ,.issue_pkt_v_i(issue_pkt_v)
   ,.issue_pkt_ready_o(issue_pkt_rdy)
   
   ,.chk_dispatch_v_i(chk_dispatch_v)

   ,.chk_roll_i(chk_roll)
   ,.chk_poison_isd_i(chk_poison_isd)
   ,.chk_poison_ex1_i(chk_poison_ex1)
   ,.chk_poison_ex2_i(chk_poison_ex2)
   ,.chk_poison_ex3_i(chk_poison_ex3)

   ,.calc_status_o(calc_status)

   ,.mmu_cmd_o(mmu_cmd)
   ,.mmu_cmd_v_o(mmu_cmd_v)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.csr_cmd_o(csr_cmd)
   ,.csr_cmd_v_o(csr_cmd_v)
   ,.csr_cmd_ready_i(csr_cmd_rdy)

   ,.mem_resp_i(mem_resp) 
   ,.mem_resp_v_i(mem_resp_v)
   ,.mem_resp_ready_o(mem_resp_rdy)   

   ,.proc_cfg_i(proc_cfg_i)

   ,.instret_o(instret)
   ,.exception_pc_o(exception_pc)
   ,.exception_instr_o(exception_instr)
   ,.exception_v_o(exception_v)
   ,.exception_ecode_dec_o(exception_ecode_dec)

   ,.mret_v_o(mret_v)
   ,.sret_v_o(sret_v)
   ,.uret_v_o(uret_v)

   ,.cmt_rd_w_v_o(cmt_rd_w_v_o)
   ,.cmt_rd_addr_o(cmt_rd_addr_o)
   ,.cmt_mem_w_v_o(cmt_mem_w_v_o)
   ,.cmt_mem_addr_o(cmt_mem_addr_o)
   ,.cmt_mem_op_o(cmt_mem_op_o)
   ,.cmt_data_o(cmt_data_o)
   );

bp_be_mem_top
 #(.cfg_p(cfg_p))
 be_mem
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.chk_poison_ex_i(chk_poison_ex2)

    ,.mmu_cmd_i(mmu_cmd)
    ,.mmu_cmd_v_i(mmu_cmd_v)
    ,.mmu_cmd_ready_o(mmu_cmd_rdy)

    ,.csr_cmd_i(csr_cmd)
    ,.csr_cmd_v_i(csr_cmd_v)
    ,.csr_cmd_ready_o(csr_cmd_rdy)

    ,.mem_resp_o(mem_resp)
    ,.mem_resp_v_o(mem_resp_v)
    ,.mem_resp_ready_i(mem_resp_rdy)
    
    ,.itlb_fill_v_o(itlb_fill_v)
    ,.itlb_fill_vtag_o(itlb_fill_vtag)
    ,.itlb_fill_entry_o(itlb_fill_entry)

    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)        

    ,.lce_data_resp_o(lce_data_resp_o)
    ,.lce_data_resp_v_o(lce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_data_cmd_i(lce_data_cmd_i)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

    ,.lce_data_cmd_o(lce_data_cmd_o)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

    ,.proc_cfg_i(proc_cfg_i)
    ,.instret_i(instret)

    ,.exception_pc_i(exception_pc)
    ,.exception_instr_i(exception_instr)
    ,.exception_v_i(exception_v)
    ,.exception_ecode_dec_i(exception_ecode_dec)

    ,.mret_v_i(mret_v)
    ,.sret_v_i(sret_v)
    ,.uret_v_i(uret_v)

    ,.timer_int_i(timer_int_i)
    ,.software_int_i(software_int_i)
    ,.external_int_i(external_int_i)
    ,.interrupt_pc_i(chk_pc_lo)

    ,.mepc_o(chk_mepc_li)
    ,.mtvec_o(chk_mtvec_li)
    );

endmodule : bp_be_top

