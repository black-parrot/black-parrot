/*                                  
* bp_fe_top.v                                                                                                                                                                                          
* */

module bp_fe_top
 import bp_fe_pkg::*;
 import bp_common_pkg::*;  
 #(parameter  vaddr_width_p="inv" 
   , parameter paddr_width_p="inv" 


   /* TODO: These all need to go away */
   , parameter eaddr_width_p=64
   , parameter data_width_p=64
   , parameter inst_width_p=32
   , parameter tag_width_p=10 // TODO: Need to calculate this based on vaddr
   , parameter instr_width_p=32


   , parameter branch_predictor_p=1 

   // icache related parameters 
   , parameter num_cce_p="inv"
   , parameter num_lce_p="inv"
   , parameter lce_assoc_p="inv"
   , parameter lce_sets_p="inv"
   , parameter cce_block_size_in_bytes_p="inv"
   /* TODO: Fix.  This is in words, not bytes, but FE depends on it */
   , localparam block_size_in_bytes_fix_lp=cce_block_size_in_bytes_p/8 
   , localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
   , localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
   , localparam lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_fix_lp)
   , localparam data_mask_width_lp=(data_width_p>>3)
   , localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
   , localparam vaddr_width_lp=(lg_lce_sets_lp+lg_lce_assoc_lp+lg_data_mask_width_lp)
   , localparam addr_width_lp=(vaddr_width_lp+tag_width_p)
   , localparam lce_data_width_lp=(lce_assoc_p*data_width_p)
   , localparam bp_fe_itlb_icache_data_resp_width_lp=`bp_fe_itlb_icache_data_resp_width(tag_width_p)
   , localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p 
                                                              ,num_lce_p
                                                              ,addr_width_lp
                                                              ,lce_assoc_p
                                                             )
   , localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                                ,num_lce_p
                                                                ,addr_width_lp
                                                               )
   , localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                          ,num_lce_p
                                                                          ,addr_width_lp
                                                                          ,lce_data_width_lp
                                                                         )
   , localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                              ,num_lce_p
                                                              ,addr_width_lp
                                                              ,lce_assoc_p
                                                             )
   , localparam bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                        ,num_lce_p
                                                                        ,addr_width_lp
                                                                        ,lce_data_width_lp
                                                                        ,lce_assoc_p
                                                                       )
   , localparam bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                      ,addr_width_lp
                                                                      ,lce_data_width_lp
                                                                      ,lce_assoc_p
                                                                     )
  
   // pc gen related parameters
   , parameter btb_indx_width_p="inv"
   , parameter bht_indx_width_p="inv"
   , parameter ras_addr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter bp_first_pc_p="inv"
   , localparam instr_scan_width_lp=`bp_fe_instr_scan_width
   , localparam branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
   , localparam bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p)
   , localparam bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_p
                                                                ,branch_metadata_fwd_width_lp
                                                               )
   , localparam bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_p
                                                                  ,branch_metadata_fwd_width_lp
                                                                 )
  
  
   // itlb related parameters 
   , localparam ppn_start_bit_lp=lg_lce_sets_lp+lg_block_size_in_bytes_lp+lg_lce_assoc_lp
   , localparam bp_fe_itlb_cmd_width_lp=`bp_fe_itlb_cmd_width(vaddr_width_p
                                                              ,paddr_width_p
                                                              ,asid_width_p
                                                              ,branch_metadata_fwd_width_lp
                                                             )
   , localparam bp_fe_itlb_queue_width_lp=`bp_fe_itlb_queue_width(vaddr_width_p
                                                                  ,branch_metadata_fwd_width_lp
                                                                 )
    
   // be interfaces parameters
   , localparam bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p
                                                    ,paddr_width_p
                                                    ,asid_width_p
                                                    ,branch_metadata_fwd_width_lp
                                                   )
   , localparam bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p
                                                        ,branch_metadata_fwd_width_lp
                                                       )
   , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [lce_id_width_lp-1:0]                      icache_id_i

   , input [bp_fe_cmd_width_lp-1:0]                   bp_fe_cmd_i
   , input                                            bp_fe_cmd_v_i
   , output logic                                     bp_fe_cmd_ready_o

   , output logic [bp_fe_queue_width_lp-1:0]          bp_fe_queue_o
   , output logic                                     bp_fe_queue_v_o
   , input                                            bp_fe_queue_ready_i

   , output logic [bp_lce_cce_req_width_lp-1:0]       lce_cce_req_o
   , output logic                                     lce_cce_req_v_o
   , input                                            lce_cce_req_ready_i

   , output logic [bp_lce_cce_resp_width_lp-1:0]      lce_cce_resp_o
   , output logic                                     lce_cce_resp_v_o
   , input                                            lce_cce_resp_ready_i

   , output logic [bp_lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o     
   , output logic                                     lce_cce_data_resp_v_o 
   , input                                            lce_cce_data_resp_ready_i

   , input [bp_cce_lce_cmd_width_lp-1:0]              cce_lce_cmd_i
   , input                                            cce_lce_cmd_v_i
   , output logic                                     cce_lce_cmd_ready_o

   , input [bp_cce_lce_data_cmd_width_lp-1:0]         cce_lce_data_cmd_i
   , input                                            cce_lce_data_cmd_v_i
   , output logic                                     cce_lce_data_cmd_ready_o

   , input [bp_lce_lce_tr_resp_width_lp-1:0]          lce_lce_tr_resp_i
   , input                                            lce_lce_tr_resp_v_i
   , output logic                                     lce_lce_tr_resp_ready_o

   , output logic[bp_lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_o
   , output logic                                     lce_lce_tr_resp_v_o
   , input                                            lce_lce_tr_resp_ready_i
   );

// the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp);   
// fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(branch_metadata_fwd_width_lp);
// pc_gen to icache
`declare_bp_fe_pc_gen_icache_s(eaddr_width_p);
// pc_gen to itlb
`declare_bp_fe_pc_gen_itlb_s(eaddr_width_p);
// icache to pc_gen
`declare_bp_fe_icache_pc_gen_s(eaddr_width_p);
// itlb to cache
`declare_bp_fe_itlb_icache_data_resp_s(tag_width_p);

   
// fe to be
bp_fe_queue_s                 bp_fe_queue;
// pc_gen to fe
bp_fe_pc_gen_queue_s          pc_gen_queue;
// fe to pc_gen
bp_fe_pc_gen_cmd_s            fe_pc_gen;
// pc_gen to icache
bp_fe_pc_gen_icache_s         pc_gen_icache;
// pc_gen to itlb
bp_fe_pc_gen_itlb_s           pc_gen_itlb;
// icache to pc_gen
bp_fe_icache_pc_gen_s         icache_pc_gen;
// be to fe
bp_fe_cmd_s                   bp_fe_cmd;
// fe to itlb
bp_fe_itlb_cmd_s              fe_itlb_cmd;
// itlb to fe 
bp_fe_itlb_queue_s            itlb_fe_queue;
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
logic cache_miss;
logic poison;

// be interfaces
assign bp_fe_cmd     = bp_fe_cmd_i;
assign bp_fe_queue_o = bp_fe_queue;

// pc_gen to fe
assign bp_fe_queue.msg_type = pc_gen_queue.msg_type;
assign bp_fe_queue.msg      = pc_gen_queue.msg;
assign pc_gen_fe_ready      = bp_fe_queue_ready_i;
assign bp_fe_queue_v_o      = pc_gen_fe_v;


// fe to pc_gen 
always_comb
  begin
    fe_pc_gen.pc_redirect_valid   = (bp_fe_cmd.opcode == e_op_pc_redirection)
                                    && (bp_fe_cmd.operands.pc_redirect_operands.subopcode
                                    == e_subop_branch_mispredict);
       
    fe_pc_gen.attaboy_valid       = bp_fe_cmd.opcode == e_op_attaboy;
       
    fe_pc_gen.branch_metadata_fwd = (bp_fe_cmd.opcode  == e_op_attaboy) 
                                    ? bp_fe_cmd.operands.attaboy.branch_metadata_fwd
                                    : (bp_fe_cmd.opcode  == e_op_pc_redirection)
                                      ? bp_fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd
                                      : '{default:'0};
    
    fe_pc_gen.pc                  = fe_pc_gen.pc_redirect_valid 
                                    ? bp_fe_cmd.operands.pc_redirect_operands.pc
                                    : bp_fe_cmd.operands.attaboy.pc;

    fe_pc_gen_v                   = bp_fe_cmd_v_i;
    bp_fe_cmd_ready_o             = fe_pc_gen_ready;
  end
   
// fe to itlb
// itlb does not has the exception functionality yet, thus it does not use the valid/ready signal from backend
assign fe_itlb_cmd = bp_fe_cmd;
assign fe_itlb_v   = bp_fe_cmd_v_i;

// itlb to fe
assign itlb_fe_ready = bp_fe_queue_ready_i;

// icache to icache
assign poison = cache_miss && bp_fe_cmd.opcode == e_op_icache_fence;

   
bp_fe_pc_gen 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.eaddr_width_p(eaddr_width_p)
   ,.btb_indx_width_p(btb_indx_width_p)
   ,.bht_indx_width_p(bht_indx_width_p)
   ,.ras_addr_width_p(ras_addr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.bp_first_pc_p(bp_first_pc_p)
   ,.instr_width_p(instr_width_p)
   ,.branch_predictor_p(branch_predictor_p)
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
   ,.icache_miss_i(cache_miss)
               
   ,.pc_gen_itlb_o(pc_gen_itlb)
   ,.pc_gen_itlb_v_o(pc_gen_itlb_v)
   ,.pc_gen_itlb_ready_i(pc_gen_itlb_ready)
               
   ,.pc_gen_fe_o(pc_gen_queue)
   ,.pc_gen_fe_v_o(pc_gen_fe_v)
   ,.pc_gen_fe_ready_i(pc_gen_fe_ready)
               
   ,.fe_pc_gen_i(fe_pc_gen)
   ,.fe_pc_gen_v_i(fe_pc_gen_v)
   ,.fe_pc_gen_ready_o(fe_pc_gen_ready)
   );

   
icache 
 #(.eaddr_width_p(eaddr_width_p)
   ,.data_width_p(data_width_p)
   ,.inst_width_p(inst_width_p)
   ,.tag_width_p(tag_width_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.ways_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.block_size_in_bytes_p(block_size_in_bytes_fix_lp)
   ) 
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
         
   ,.lce_req_o(lce_cce_req_o)
   ,.lce_req_v_o(lce_cce_req_v_o)
   ,.lce_req_ready_i(lce_cce_req_ready_i)
         
   ,.lce_resp_o(lce_cce_resp_o)
   ,.lce_resp_v_o(lce_cce_resp_v_o)
   ,.lce_resp_ready_i(lce_cce_resp_ready_i)
         
   ,.lce_data_resp_o(lce_cce_data_resp_o)
   ,.lce_data_resp_v_o(lce_cce_data_resp_v_o)
   ,.lce_data_resp_ready_i(lce_cce_data_resp_ready_i)
         
   ,.lce_cmd_i(cce_lce_cmd_i)
   ,.lce_cmd_v_i(cce_lce_cmd_v_i)
   ,.lce_cmd_ready_o(cce_lce_cmd_ready_o)
         
   ,.lce_data_cmd_i(cce_lce_data_cmd_i)
   ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
   ,.lce_data_cmd_ready_o(cce_lce_data_cmd_ready_o)
         
   ,.lce_tr_resp_i(lce_lce_tr_resp_i)
   ,.lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
   ,.lce_tr_resp_ready_o(lce_lce_tr_resp_ready_o)               
         
   ,.lce_tr_resp_o(lce_lce_tr_resp_o)
   ,.lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
   ,.lce_tr_resp_ready_i(lce_lce_tr_resp_ready_i)
         
   ,.cache_miss_o(cache_miss)
   ,.poison_i(poison)
   );

   
itlb 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.eaddr_width_p(eaddr_width_p)
   ,.btb_indx_width_p(btb_indx_width_p)
   ,.bht_indx_width_p(bht_indx_width_p)
   ,.ras_addr_width_p(ras_addr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.ppn_start_bit_p(ppn_start_bit_lp)
   ,.tag_width_p(tag_width_p)
   ) 
 itlb_1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
       
   ,.fe_itlb_i(fe_itlb_cmd)
   ,.fe_itlb_v_i(fe_itlb_v)
   ,.fe_itlb_ready_o(fe_itlb_ready)                       
       
   ,.pc_gen_itlb_i(pc_gen_itlb)
   ,.pc_gen_itlb_v_i(pc_gen_itlb_v)
   ,.pc_gen_itlb_ready_o(pc_gen_itlb_ready)                       
       
   ,.itlb_icache_o(itlb_icache)
   ,.itlb_icache_data_resp_v_o(itlb_icache_data_resp_v)
   ,.itlb_icache_data_resp_ready_i(itlb_icache_data_resp_ready)                       
       
   ,.itlb_fe_o(itlb_fe_queue)
   ,.itlb_fe_v_o(itlb_fe_v)
   ,.itlb_fe_ready_i(itlb_fe_ready)
   );

endmodule
