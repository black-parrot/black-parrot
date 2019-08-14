/*                                  
 * bp_fe_top.v 
 */

module bp_fe_top
 import bp_fe_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   `declare_bp_fe_be_if_widths(vaddr_width_p
                               ,paddr_width_p
                               ,asid_width_p
                               ,branch_metadata_fwd_width_p
                               )

   , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
   )
  (input                                              clk_i
   , input                                            reset_i
   , input                                            freeze_i

   , input [lce_id_width_lp-1:0]                      icache_id_i

   // Config channel
   , input                                            cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                     cfg_addr_i
   , input [cfg_data_width_p-1:0]                     cfg_data_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output                                           fe_cmd_yumi_o
   , output                                           fe_cmd_processed_o

   , output [fe_queue_width_lp-1:0]                   fe_queue_o
   , output                                           fe_queue_v_o
   , input                                            fe_queue_ready_i

   , output logic [lce_cce_req_width_lp-1:0]          lce_req_o
   , output logic                                     lce_req_v_o
   , input                                            lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]               lce_resp_o
   , output                                           lce_resp_v_o
   , input                                            lce_resp_ready_i

   , input [lce_cmd_width_lp-1:0]                     lce_cmd_i
   , input                                            lce_cmd_v_i
   , output                                           lce_cmd_ready_o

   , output [lce_cmd_width_lp-1:0]                    lce_cmd_o
   , output                                           lce_cmd_v_o
   , input                                            lce_cmd_ready_i
   );

// the first level of structs
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_fe_itlb_vaddr_s(vaddr_width_p,lce_sets_p,cce_block_width_p) 
`declare_bp_be_tlb_entry_s(ptag_width_p);
   
// fe to be
bp_fe_queue_s                 fe_queue;
   
// valid, ready signals
logic pc_gen_itlb_v;
logic pc_gen_itlb_ready;
logic pc_gen_icache_v;
logic pc_gen_icache_ready;
logic itlb_fe_v;
logic itlb_fe_ready;
logic itlb_icache_data_resp_v;
logic itlb_icache_data_resp_ready;
logic fe_itlb_v;
logic fe_itlb_ready;
logic icache_pc_gen_v;
logic icache_pc_gen_ready;
logic icache_itlb_v;
logic icache_itlb_ready;
// reserved icache
logic icache_miss;
logic instr_access_fault;
logic poison_tl;

logic [vaddr_width_p-1:0] fetch_pc_lo;
logic fetch_pc_v_lo, fetch_pc_ready_li;

//itlb
logic [vtag_width_p-1:0]  itlb_miss_vtag;
logic 		                itlb_miss;
   
bp_be_tlb_entry_s itlb_r_entry;

//fe to itlb
logic itlb_fence_v;

wire icache_uncached = itlb_r_entry.uc;

logic itlb_w_v;
logic [vaddr_width_p-page_offset_width_p-1:0] itlb_w_vtag;
bp_be_tlb_entry_s itlb_w_entry;

logic [instr_width_p-1:0] fetch_instr_li;
logic fetch_instr_v_li, fetch_instr_ready_lo;

logic icache_ready_lo, itlb_ready_lo;
logic fetch_v_lo;
wire fetch_ready_li = icache_ready_lo & itlb_ready_lo;
bp_fe_pc_gen 
 #(.cfg_p(cfg_p)) 
 bp_fe_pc_gen_1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
               
   ,.fetch_pc_o(fetch_pc_lo)
   ,.fetch_v_o(fetch_v_lo)
   ,.fetch_ready_i(fetch_ready_li)
    
   ,.fetch_instr_i(fetch_instr_li)
   ,.fetch_instr_v_i(fetch_instr_v_li)
   ,.fetch_instr_ready_o(fetch_instr_ready_lo)

   ,.instr_access_fault_i(instr_access_fault)
   ,.icache_poison_o(poison_tl)

   ,.itlb_miss_i(itlb_miss)

   ,.itlb_fence_v_o(itlb_fence_v)
   ,.itlb_w_v_o(itlb_w_v)
   ,.itlb_w_vtag_o(itlb_w_vtag)
	 ,.itlb_w_entry_o(itlb_w_entry)
 
   ,.fe_cmd_i(fe_cmd_i)
   ,.fe_cmd_v_i(fe_cmd_v_i)
   ,.fe_cmd_yumi_o(fe_cmd_yumi_o)
   ,.fe_cmd_processed_o(fe_cmd_processed_o)

   ,.fe_queue_o(fe_queue_o)
   ,.fe_queue_v_o(fe_queue_v_o)
   ,.fe_queue_ready_i(fe_queue_ready_i)
   );

logic [ptag_width_p-1:0] fetch_ptag_lo;
logic itlb_r_v_lo, itlb_r_ready_li;

bp_fe_icache 
 #(.cfg_p(cfg_p)) 
 icache
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.freeze_i(freeze_i)

   ,.lce_id_i(icache_id_i)         
   ,.cfg_w_v_i(cfg_w_v_i)
   ,.cfg_addr_i(cfg_addr_i)
   ,.cfg_data_i(cfg_data_i)

   ,.vaddr_i(fetch_pc_lo)
   ,.vaddr_v_i(fetch_v_lo)
   ,.vaddr_ready_o(icache_ready_lo)

   ,.data_o(fetch_instr_li)
   ,.data_v_o(fetch_instr_v_li)
   ,.data_ready_i(fetch_instr_ready_lo)

   ,.ptag_i(itlb_r_entry.ptag)
   ,.ptag_v_i(itlb_r_v_lo)
   ,.ptag_ready_o(itlb_r_ready_li)

   ,.itlb_icache_miss_i(itlb_miss) 
   ,.uncached_i(icache_uncached)
  
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

   ,.instr_access_fault_o(instr_access_fault)
   ,.cache_miss_o(icache_miss)
   ,.poison_tl_i(poison_tl | icache_miss)
   );

bp_be_dtlb
 #(.cfg_p(cfg_p))
 itlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(itlb_fence_v)
	       
   ,.r_vtag_i(fetch_pc_lo[vaddr_width_p-1:page_offset_width_p])
   ,.r_v_i(fetch_v_lo)
   ,.r_ready_o(itlb_ready_lo)
	   
   ,.r_v_o(itlb_r_v_lo)
   ,.r_entry_o(itlb_r_entry)

   ,.w_v_i(itlb_w_v)
   ,.w_vtag_i(itlb_w_vtag)
	 ,.w_entry_i(itlb_w_entry)

	 ,.miss_v_o(itlb_miss)
	 ,.miss_vtag_o(itlb_miss_vtag)
	 );

endmodule
