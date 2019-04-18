/*                                  
 * bp_fe_top.v 
 */

module bp_fe_top
 import bp_fe_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;  
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

   `declare_bp_fe_pc_gen_if_widths(vaddr_width_p, branch_metadata_fwd_width_p)

   , localparam data_width_p      = rv64_reg_data_width_gp
   , localparam instr_width_lp    = rv64_instr_width_gp   

   , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_p)
   , localparam block_size_in_words_lp=lce_assoc_p
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam data_mask_width_lp=(data_width_p>>3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   //do we need this? come back to this
   , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)
  
   , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
   
   , localparam vtag_width_lp = (vaddr_width_p-bp_page_offset_width_gp)
   , localparam ptag_width_lp = (paddr_width_p-bp_page_offset_width_gp)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [lce_id_width_lp-1:0]                      icache_id_i
   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output logic                                     fe_cmd_ready_o

   , output [fe_queue_width_lp-1:0]                   fe_queue_o
   , output                                           fe_queue_v_o
   , input                                            fe_queue_ready_i

   , output logic [lce_cce_req_width_lp-1:0]          lce_req_o
   , output logic                                     lce_req_v_o
   , input                                            lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]               lce_resp_o
   , output                                           lce_resp_v_o
   , input                                            lce_resp_ready_i

   , output [lce_cce_data_resp_width_lp-1:0]          lce_data_resp_o     
   , output                                           lce_data_resp_v_o 
   , input                                            lce_data_resp_ready_i

   , input [cce_lce_cmd_width_lp-1:0]                 lce_cmd_i
   , input                                            lce_cmd_v_i
   , output                                           lce_cmd_ready_o

   , input [lce_data_cmd_width_lp-1:0]                lce_data_cmd_i
   , input                                            lce_data_cmd_v_i
   , output                                           lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]               lce_data_cmd_o
   , output                                           lce_data_cmd_v_o
   , input                                            lce_data_cmd_ready_i

   );

// the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p);   
// fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(vaddr_width_p,branch_metadata_fwd_width_p);
// pc_gen to icache
`declare_bp_fe_pc_gen_icache_s(vaddr_width_p);
// pc_gen to itlb
`declare_bp_fe_pc_gen_itlb_s(vaddr_width_p);
`declare_bp_fe_itlb_vaddr_s(vaddr_width_p,lce_sets_p,cce_block_width_p) 
`declare_bp_be_tlb_entry_s(ptag_width_lp);  
// icache to pc_gen
`declare_bp_fe_icache_pc_gen_s(vaddr_width_p);
// itlb to cache
`declare_bp_fe_itlb_icache_data_resp_s(tag_width_lp);
   
// fe to be
bp_fe_queue_s                 fe_queue;
// pc_gen to fe
bp_fe_pc_gen_queue_s          pc_gen_queue;
// fe to pc_gen
bp_fe_pc_gen_cmd_s            fe_pc_gen;
// pc_gen to icache
bp_fe_pc_gen_icache_s         pc_gen_icache;
// pc_gen to itlb
bp_fe_pc_gen_itlb_s           pc_gen_itlb;
bp_fe_itlb_vaddr_s            itlb_vaddr;   
// icache to pc_gen
bp_fe_icache_pc_gen_s         icache_pc_gen;
// be to fe
bp_fe_cmd_s                   fe_cmd;   
// itlb to icache
bp_fe_itlb_icache_data_resp_s itlb_icache;

   
// valid, ready signals
logic pc_gen_itlb_v;
logic pc_gen_itlb_ready;
logic pc_gen_fe_v;
logic pc_gen_fe_ready;
logic pc_gen_icache_v;
logic pc_gen_icache_ready;
logic fe_pc_gen_v;
logic fe_pc_gen_ready;
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
logic poison_tl;

//itlb
logic [vtag_width_lp-1:0]       itlb_miss_vtag;
logic 		                itlb_miss;
   
// be interfaces
assign fe_cmd          = fe_cmd_i;
assign fe_queue_o      = fe_queue;

assign fe_queue.msg_type = pc_gen_queue.msg_type;
assign fe_queue.msg      = pc_gen_queue.msg;
assign pc_gen_fe_ready   = fe_queue_ready_i;
assign fe_queue_v_o      = pc_gen_fe_v;
// processor parameters
//`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)

// fe to pc_gen 
always_comb
  begin
    fe_pc_gen.reset_valid         = fe_cmd.opcode == e_op_state_reset;
    fe_pc_gen.pc_redirect_valid   = (fe_cmd.opcode == e_op_pc_redirection)
                                    && (fe_cmd.operands.pc_redirect_operands.subopcode
                                    == e_subop_branch_mispredict);
       
    fe_pc_gen.attaboy_valid       = fe_cmd.opcode == e_op_attaboy;
       
    fe_pc_gen.branch_metadata_fwd = (fe_cmd.opcode  == e_op_attaboy) 
                                    ? fe_cmd.operands.attaboy.branch_metadata_fwd
                                    : (fe_cmd.opcode  == e_op_pc_redirection)
                                    ? fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd
                                    : '{default:'0};
    
    fe_pc_gen.pc                  = (fe_pc_gen.reset_valid) 
                                    ? fe_cmd.operands.reset_operands.pc
                                    : (fe_pc_gen.pc_redirect_valid) 
                                    ? fe_cmd.operands.pc_redirect_operands.pc
                                    : fe_cmd.operands.attaboy.pc ;

    fe_pc_gen_v                   = fe_cmd_v_i;
    fe_cmd_ready_o                = fe_pc_gen_ready;
  end
     

// icache to icache
assign poison_tl = icache_miss | fe_pc_gen.pc_redirect_valid & fe_pc_gen_v;

//fe to itlb
bp_be_tlb_entry_s  itlb_entry_r;
assign itlb_vaddr        = pc_gen_itlb.virt_addr;
assign itlb_icache.ppn   = itlb_entry_r.ptag;
   
bp_fe_pc_gen 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.btb_tag_width_p(btb_tag_width_p)
   ,.btb_idx_width_p(btb_idx_width_p)
   ,.bht_idx_width_p(bht_idx_width_p)
   ,.ras_idx_width_p(ras_idx_width_p)
   ,.asid_width_p(asid_width_p)
   ,.instr_width_p(instr_width_lp)
   ) 
 bp_fe_pc_gen_1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
               
   ,.v_i(1'b1)
               
   ,.pc_gen_icache_o(pc_gen_icache)
   ,.pc_gen_icache_v_o(pc_gen_icache_v)
   ,.pc_gen_icache_ready_i(pc_gen_icache_ready)
               
   ,.icache_pc_gen_i(icache_pc_gen)
   ,.icache_pc_gen_v_i(icache_pc_gen_v)
   ,.icache_pc_gen_ready_o(icache_pc_gen_ready)
   ,.icache_miss_i(icache_miss)
               
   ,.pc_gen_itlb_o(pc_gen_itlb)
   ,.pc_gen_itlb_v_o(pc_gen_itlb_v)
   ,.pc_gen_itlb_ready_i(pc_gen_itlb_ready)
               
   ,.pc_gen_fe_o(pc_gen_queue)
   ,.pc_gen_fe_v_o(pc_gen_fe_v)
   ,.pc_gen_fe_ready_i(pc_gen_fe_ready)
               
   ,.fe_pc_gen_i(fe_pc_gen)
   ,.fe_pc_gen_v_i(fe_pc_gen_v)
   ,.fe_pc_gen_ready_o(fe_pc_gen_ready)

   ,.itlb_miss_i(itlb_miss)
   );

   
bp_fe_icache 
 #(.cfg_p(cfg_p)) 
 icache_1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.id_i(icache_id_i)         

   ,.pc_gen_icache_vaddr_i(pc_gen_icache)
   ,.pc_gen_icache_vaddr_v_i(pc_gen_icache_v)
   ,.pc_gen_icache_vaddr_ready_o(pc_gen_icache_ready)
         
   ,.icache_pc_gen_data_o(icache_pc_gen)
   ,.icache_pc_gen_data_v_o(icache_pc_gen_v)
   ,.icache_pc_gen_data_ready_i(icache_pc_gen_ready)
         
   ,.itlb_icache_data_resp_i(itlb_icache)
   ,.itlb_icache_data_resp_v_i(itlb_icache_data_resp_v)
   ,.itlb_icache_data_resp_ready_o(itlb_icache_data_resp_ready)
   ,.itlb_icache_miss_i(itlb_miss) 
  
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

         
   ,.cache_miss_o(icache_miss)
   ,.poison_tl_i(poison_tl)
   );

   
bp_be_dtlb
 #(.vtag_width_p(vtag_width_lp)
   ,.ptag_width_p(ptag_width_lp)
   ,.els_p(16)
   )
 itlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)
	       
   ,.r_v_i(pc_gen_itlb_v)
   ,.r_vtag_i(itlb_vaddr.tag)
	   
   ,.r_v_o(itlb_icache_data_resp_v)
   ,.r_entry_o(itlb_entry_r)

   ,.w_v_i(itlb_miss & fe_cmd_v_i & fe_cmd.opcode == e_op_itlb_fill_response)
   ,.w_vtag_i(fe_cmd.operands.itlb_fill_response.vaddr[vaddr_width_p-1:bp_page_offset_width_gp])
	 ,.w_entry_i(fe_cmd.operands.itlb_fill_response.pte_entry_leaf)

   ,.miss_clear_i(1'b0)
	 ,.miss_v_o(itlb_miss)
	 ,.miss_vtag_o(itlb_miss_vtag)
	 );

endmodule
