/**
 *
 *  Name:
 *    bp_be_top.v
 * 
 */


module bp_be_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cfg_link_pkg::*;
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
   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   , localparam ecode_dec_width_lp         = `bp_be_ecode_dec_width
   
   // VM parameters
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i
   , input                                   freeze_i

   // Config channel
   , input                                   cfg_w_v_i
   , input [cfg_addr_width_p-1:0]            cfg_addr_i
   , input [cfg_data_width_p-1:0]            cfg_data_i

   // FE queue interface
   , output                                  fe_queue_deq_o
   , output                                  fe_queue_roll_o
 
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_yumi_o

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

   , input [lce_cmd_width_lp-1:0]            lce_cmd_i
   , input                                   lce_cmd_v_i
   , output                                  lce_cmd_ready_o

   , output [lce_cmd_width_lp-1:0]           lce_cmd_o
   , output                                  lce_cmd_v_o
   , input                                   lce_cmd_ready_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   , input                                   timer_int_i
   , input                                   software_int_i
   , input                                   external_int_i
   );

// Declare parameterized structures
`declare_bp_be_mmu_structs(vaddr_width_p, ptag_width_p, lce_sets_p, cce_block_width_p)
`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

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

logic [tlb_entry_width_lp-1:0]  itlb_fill_entry;
logic [vaddr_width_p-1:0]       itlb_fill_vaddr;
logic                           itlb_fill_v;

bp_be_isd_status_s     isd_status;
bp_be_calc_status_s    calc_status;

logic chk_dispatch_v, chk_poison_iss, chk_poison_isd;
logic chk_poison_ex1, chk_poison_ex2, chk_roll, chk_instr_dequeue_v;

logic [vaddr_width_p-1:0] chk_tvec_li;
logic [vaddr_width_p-1:0] chk_epc_li;
logic [vaddr_width_p-1:0] chk_pc_lo;

logic chk_trap_v_li, chk_ret_v_li, chk_tlb_fence_li, chk_ifence_li;

logic credits_full_lo, credits_empty_lo;

logic                     instret_mem3;
logic                     pc_v_mem3;
logic [vaddr_width_p-1:0] pc_mem3;
logic [instr_width_p-1:0] instr_mem3;

// Module instantiations
bp_be_checker_top 
 #(.cfg_p(cfg_p))
 be_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i(freeze_i)

   ,.cfg_w_v_i(cfg_w_v_i)
   ,.cfg_addr_i(cfg_addr_i)
   ,.cfg_data_i(cfg_data_i)

   ,.chk_dispatch_v_o(chk_dispatch_v)
   ,.chk_roll_o(chk_roll)
   ,.chk_poison_iss_o(chk_poison_iss)
   ,.chk_poison_isd_o(chk_poison_isd)
   ,.chk_poison_ex1_o(chk_poison_ex1)
   ,.chk_poison_ex2_o(chk_poison_ex2)

   ,.isd_status_i(isd_status)
   ,.calc_status_i(calc_status)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)
   ,.credits_full_i(credits_full_lo)
   ,.credits_empty_i(credits_empty_lo)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)

   ,.fe_queue_roll_o(fe_queue_roll_o)
   ,.fe_queue_deq_o(fe_queue_deq_o)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_yumi_o(fe_queue_yumi_o)

   ,.issue_pkt_o(issue_pkt)
   ,.issue_pkt_v_o(issue_pkt_v)
   ,.issue_pkt_ready_i(issue_pkt_rdy)

   ,.trap_v_i(chk_trap_v_li)
   ,.ret_v_i(chk_ret_v_li)
   ,.pc_o(chk_pc_lo)
   ,.epc_i(chk_epc_li)
   ,.tvec_i(chk_tvec_li)
   ,.tlb_fence_i(chk_tlb_fence_li)
   
   ,.itlb_fill_v_i(itlb_fill_v)
   ,.itlb_fill_vaddr_i(itlb_fill_vaddr)
   ,.itlb_fill_entry_i(itlb_fill_entry)
   );

bp_be_calculator_top 
 #(.cfg_p(cfg_p))
 be_calculator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.proc_cfg_i(proc_cfg_i)

   ,.issue_pkt_i(issue_pkt)
   ,.issue_pkt_v_i(issue_pkt_v)
   ,.issue_pkt_ready_o(issue_pkt_rdy)
   
   ,.chk_dispatch_v_i(chk_dispatch_v)

   ,.chk_roll_i(chk_roll)
   ,.chk_poison_iss_i(chk_poison_iss)
   ,.chk_poison_isd_i(chk_poison_isd)
   ,.chk_poison_ex1_i(chk_poison_ex1)
   ,.chk_poison_ex2_i(chk_poison_ex2)

   ,.isd_status_o(isd_status)
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

   ,.instret_mem3_o(instret_mem3)
   ,.pc_v_mem3_o(pc_v_mem3)
   ,.pc_mem3_o(pc_mem3)
   ,.instr_mem3_o(instr_mem3)
   );

bp_be_mem_top
 #(.cfg_p(cfg_p))
 be_mem
   (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.freeze_i(freeze_i)

    ,.cfg_w_v_i(cfg_w_v_i)
    ,.cfg_addr_i(cfg_addr_i)
    ,.cfg_data_i(cfg_data_i)

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
    ,.itlb_fill_vaddr_o(itlb_fill_vaddr)
    ,.itlb_fill_entry_o(itlb_fill_entry)

    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)        

    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_cmd_o(lce_cmd_o)
    ,.lce_cmd_v_o(lce_cmd_v_o)
    ,.lce_cmd_ready_i(lce_cmd_ready_i)

    ,.proc_cfg_i(proc_cfg_i)
    ,.instret_i(instret_mem3)

    ,.pc_v_mem3_i(pc_v_mem3)
    ,.pc_mem3_i(pc_mem3)
    ,.instr_mem3_i(instr_mem3)

    ,.credits_full_o(credits_full_lo)
    ,.credits_empty_o(credits_empty_lo)

    ,.timer_int_i(timer_int_i)
    ,.software_int_i(software_int_i)
    ,.external_int_i(external_int_i)
    ,.interrupt_pc_i(chk_pc_lo)

    // Should connect priv mode to checker for shadow privilege mode
    ,.priv_mode_o()
    ,.trap_v_o(chk_trap_v_li)
    ,.ret_v_o(chk_ret_v_li)
    ,.epc_o(chk_epc_li)
    ,.tvec_o(chk_tvec_li)
    ,.tlb_fence_o(chk_tlb_fence_li)
    );

endmodule : bp_be_top

