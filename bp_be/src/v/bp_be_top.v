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
 import bp_common_cfg_link_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)

   // Default parameters 
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   
   // VM parameters
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   , localparam stat_info_width_lp = `bp_cache_stat_info_width(dcache_assoc_p)
  )
  (input                                     clk_i
   , input                                   reset_i

   // Processor configuration
   , input [cfg_bus_width_lp-1:0]            cfg_bus_i
   , output [dword_width_p-1:0]              cfg_irf_data_o
   , output [vaddr_width_p-1:0]              cfg_npc_data_o
   , output [dword_width_p-1:0]              cfg_csr_data_o
   , output [1:0]                            cfg_priv_data_o

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_yumi_o
   , output                                  fe_queue_clr_o
   , output                                  fe_queue_deq_o
   , output                                  fe_queue_roll_o

   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_ready_i
   , input                                   fe_cmd_fence_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]      cache_req_o
   , output logic                                cache_req_v_o
   , input                                       cache_req_ready_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                cache_req_metadata_v_o

   , input cache_req_complete_i
   
   // data_mem
   , input data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
   , output logic [dcache_block_width_p-1:0] data_mem_o
   , output logic data_mem_pkt_ready_o

   // tag_mem
   , input tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_i
   , output logic [ptag_width_p-1:0] tag_mem_o
   , output logic tag_mem_pkt_ready_o

   // stat_mem
   , input stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
   , output logic [stat_info_width_lp-1:0] stat_mem_o
   , output logic  stat_mem_pkt_ready_o

   , input                                   credits_full_i
   , input                                   credits_empty_i

   , input                                   timer_irq_i
   , input                                   software_irq_i
   , input                                   external_irq_i
   );

// Declare parameterized structures
// TODO: Shouldn't the block size be in bytes and not in bits?
`declare_bp_be_mmu_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dcache_block_width_p)
`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

// Casting
bp_cfg_bus_s cfg_bus;

assign cfg_bus = cfg_bus_i;

// Top-level interface connections
bp_be_dispatch_pkt_s dispatch_pkt;
logic dispatch_pkt_v;

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_csr_cmd_s csr_cmd;
logic csr_cmd_v, csr_cmd_rdy;

bp_be_mem_resp_s mem_resp;
logic mem_resp_v, mem_resp_rdy;

logic [tlb_entry_width_lp-1:0]  itlb_fill_entry;
logic [vaddr_width_p-1:0]       itlb_fill_vaddr;
logic                           itlb_fill_v;

bp_be_calc_status_s    calc_status;

logic chk_dispatch_v;

logic [vaddr_width_p-1:0] chk_tvec_li;
logic [vaddr_width_p-1:0] chk_epc_li;

logic chk_trap_v_li, chk_ret_v_li, chk_tlb_fence_li, chk_fencei_li;

logic debug_mode_lo;
logic single_step_lo;
logic accept_irq_lo;

logic                     instret_mem3;
logic                     pc_v_mem3;
logic [vaddr_width_p-1:0] pc_mem3;
logic [instr_width_p-1:0] instr_mem3;

bp_be_commit_pkt_s commit_pkt;
bp_be_trap_pkt_s trap_pkt;
bp_be_wb_pkt_s wb_pkt;
logic wb_pkt_v;

logic flush;
// Module instantiations
bp_be_checker_top 
 #(.bp_params_p(bp_params_p))
 be_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)
   ,.cfg_npc_data_o(cfg_npc_data_o)
   ,.cfg_irf_data_o(cfg_irf_data_o)

   ,.chk_dispatch_v_o(chk_dispatch_v)
   ,.flush_o(flush)

   ,.calc_status_i(calc_status)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)
   ,.credits_full_i(credits_full_i)
   ,.credits_empty_i(credits_empty_i)
   ,.debug_mode_i(debug_mode_lo)
   ,.single_step_i(single_step_lo)
   ,.accept_irq_i(accept_irq_lo)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)
   ,.fe_cmd_fence_i(fe_cmd_fence_i)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_yumi_o(fe_queue_yumi_o)
   ,.fe_queue_clr_o(fe_queue_clr_o)
   ,.fe_queue_roll_o(fe_queue_roll_o)
   ,.fe_queue_deq_o(fe_queue_deq_o)

   ,.dispatch_pkt_o(dispatch_pkt)

   ,.itlb_fill_v_i(itlb_fill_v)
   ,.itlb_fill_vaddr_i(itlb_fill_vaddr)
   ,.itlb_fill_entry_i(itlb_fill_entry)

   ,.commit_pkt_i(commit_pkt)
   ,.trap_pkt_i(trap_pkt)
   ,.wb_pkt_i(wb_pkt)
   );

bp_be_calculator_top 
 #(.bp_params_p(bp_params_p))
 be_calculator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.dispatch_pkt_i(dispatch_pkt)

   ,.flush_i(flush)

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

   ,.commit_pkt_o(commit_pkt)
   ,.wb_pkt_o(wb_pkt)
   );

bp_be_mem_top
 #(.bp_params_p(bp_params_p))
 be_mem
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i(cfg_bus_i)
    ,.cfg_csr_data_o(cfg_csr_data_o)
    ,.cfg_priv_data_o(cfg_priv_data_o)

    ,.chk_poison_ex_i(flush)

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

    ,.cache_req_complete_i(cache_req_complete_i)   
 
    ,.cache_req_o(cache_req_o)
    ,.cache_req_metadata_o(cache_req_metadata_o)
    ,.cache_req_v_o(cache_req_v_o)
    ,.cache_req_ready_i(cache_req_ready_i)
    ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
    
    ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
    ,.data_mem_pkt_i(data_mem_pkt_i)
    ,.data_mem_o(data_mem_o)
    ,.data_mem_pkt_ready_o(data_mem_pkt_ready_o)
    ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
    ,.tag_mem_pkt_i(tag_mem_pkt_i)
    ,.tag_mem_o(tag_mem_o)
    ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_o)
    ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
    ,.stat_mem_pkt_i(stat_mem_pkt_i)
    ,.stat_mem_o(stat_mem_o)
    ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_o)

    ,.commit_pkt_i(commit_pkt)

    ,.debug_mode_o(debug_mode_lo)
    ,.single_step_o(single_step_lo)

    ,.timer_irq_i(timer_irq_i)
    ,.software_irq_i(software_irq_i)
    ,.external_irq_i(external_irq_i)
    ,.accept_irq_o(accept_irq_lo)

    ,.trap_pkt_o(trap_pkt)
    );

endmodule

