
`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

`ifndef BP_COMMON_FE_BE_IF_VH
`define BP_COMMON_FE_BE_IF_VH
`include "bp_common_fe_be_if.vh"
`endif

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH
`include "bp_fe_pc_gen.vh"
`endif

`ifndef BP_FE_ITLB_VH
`define BP_FE_ITLB_VH
`include "bp_fe_itlb.vh"
`endif

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH
`include "bp_fe_icache.vh"
`endif

import pc_gen_pkg::*;

module bp_fe_top 
 #(parameter  vaddr_width_p="inv" 
   , parameter paddr_width_p="inv" 
   , parameter eaddr_width_p="inv" 
   , parameter data_width_p="inv"
   , parameter inst_width_p="inv"
  
   , parameter branch_predictor_p=1 // TODO: Make string to select branch predictor 

   // icache related parameters 
   , parameter tag_width_p="inv"
   , parameter num_cce_p="inv"
   , parameter num_lce_p="inv"
   , parameter lce_assoc_p="inv"
   , parameter lce_sets_p="inv"
   , parameter block_size_in_bytes_p="inv"
   , parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
   , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
   , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
   , parameter data_mask_width_lp=(data_width_p>>3)
   , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
   , parameter vaddr_width_lp=(lg_lce_sets_lp+lg_lce_assoc_lp+lg_data_mask_width_lp)
   , parameter addr_width_lp=(vaddr_width_lp+tag_width_p)
   , parameter lce_data_width_lp=(lce_assoc_p*data_width_p)
   , parameter bp_fe_itlb_icache_width_lp=44
   , parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p 
                                                             ,num_lce_p
                                                             ,addr_width_lp
                                                             ,lce_assoc_p
                                                           )
   , parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                               ,num_lce_p
                                                               ,addr_width_lp
                                                             )
   , parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                         ,num_lce_p
                                                                         ,addr_width_lp
                                                                         ,lce_data_width_lp
                                                                       )
   , parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                             ,num_lce_p
                                                             ,addr_width_lp
                                                             ,lce_assoc_p
                                                            )
   , parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                       ,num_lce_p
                                                                       ,addr_width_lp
                                                                       ,lce_data_width_lp
                                                                       ,lce_assoc_p
                                                                      )
   , parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
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
   , parameter instr_width_p="inv"
   , parameter instr_scan_width_lp=`bp_fe_instr_scan_width
   , parameter branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
   , parameter bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p)
   , parameter bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_p
                                                              ,paddr_width_p
                                                              ,asid_width_p
                                                              ,branch_metadata_fwd_width_lp
                                                             )
   , parameter bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_p
                                                                ,branch_metadata_fwd_width_lp
                                                               )
  
  
   // itlb related parameters 
   , parameter ppn_start_bit_p=lg_lce_sets_lp+lg_block_size_in_bytes_lp+lg_lce_assoc_lp
   , parameter bp_fe_itlb_cmd_width_lp=`bp_fe_itlb_cmd_width(vaddr_width_p
                                                            ,paddr_width_p
                                                            ,asid_width_p
                                                            ,branch_metadata_fwd_width_lp
                                                           )
   , parameter bp_fe_itlb_queue_width_lp=`bp_fe_itlb_queue_width(vaddr_width_p
                                                                ,branch_metadata_fwd_width_lp
                                                               )
    
   // be interfaces parameters
   , parameter bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p
                                                  ,paddr_width_p
                                                  ,asid_width_p
                                                  ,branch_metadata_fwd_width_lp
                                                 )
   , parameter bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p
                                                      ,branch_metadata_fwd_width_lp
                                                      )
   , localparam lce_id_width_lp=`bp_lce_id_width
  )
  (input logic                                       clk_i
   , input logic                                     reset_i

   , input [lce_id_width_lp-1:0]                     icache_id_i

   , input logic[bp_fe_cmd_width_lp-1:0]             bp_fe_cmd_i
   , input logic                                     bp_fe_cmd_v_i
   , output logic                                    bp_fe_cmd_ready_o

   , output logic[bp_fe_queue_width_lp-1:0]          bp_fe_queue_o
   , output logic                                    bp_fe_queue_v_o
   , input logic                                     bp_fe_queue_ready_i

   , output logic[bp_lce_cce_req_width_lp-1:0]       lce_cce_req_o
   , output logic                                    lce_cce_req_v_o
   , input  logic                                    lce_cce_req_ready_i

   , output logic[bp_lce_cce_resp_width_lp-1:0]      lce_cce_resp_o
   , output logic                                    lce_cce_resp_v_o
   , input  logic                                    lce_cce_resp_ready_i

   , output logic[bp_lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o     
   , output logic                                    lce_cce_data_resp_v_o 
   , input logic                                     lce_cce_data_resp_ready_i

   , input logic[bp_cce_lce_cmd_width_lp-1:0]        cce_lce_cmd_i
   , input logic                                     cce_lce_cmd_v_i
   , output logic                                    cce_lce_cmd_ready_o

   , input logic[bp_cce_lce_data_cmd_width_lp-1:0]   cce_lce_data_cmd_i
   , input logic                                     cce_lce_data_cmd_v_i
   , output logic                                    cce_lce_data_cmd_ready_o

   , input logic[bp_lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_i
   , input logic                                     lce_lce_tr_resp_v_i
   , output logic                                    lce_lce_tr_resp_ready_o

   , output logic[bp_lce_lce_tr_resp_width_lp-1:0]   lce_lce_tr_resp_o
   , output logic                                    lce_lce_tr_resp_v_o
   , input logic                                     lce_lce_tr_resp_ready_i
  );

// the first level of structs
// be_fe interface
localparam branch_metadata_fwd_width_p = branch_metadata_fwd_width_lp; 
`declare_bp_common_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p)
// pc_gen to fe
`declare_bp_fe_pc_gen_queue_s;
// fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s;
// pc_gen to icache
`declare_bp_fe_pc_gen_icache_s(eaddr_width_p);
// pc_gen to itlb
`declare_bp_fe_pc_gen_itlb_s(eaddr_width_p);
// icache to pc_gen
`declare_bp_fe_icache_pc_gen_s(eaddr_width_p);
// fe to itlb
`declare_bp_fe_itlb_cmd_s;
// itlb to cache
`declare_bp_fe_itlb_icache_data_resp_s(bp_fe_itlb_icache_width_lp);
// itlb to fe
`declare_bp_fe_itlb_queue_s;

   
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
logic cache_miss_o;
logic poison_i;

// be interfaces
assign bp_fe_cmd     = bp_fe_cmd_i;
assign bp_fe_queue_o = bp_fe_queue;

// pc_gen to fe
// pc_gen output msg_type and msg, does not forward the instr_scan results to the backend
assign bp_fe_queue.msg_type = pc_gen_queue.msg_type;
assign bp_fe_queue.msg      = pc_gen_queue.msg;
assign pc_gen_fe_ready      = bp_fe_queue_ready_i;
assign bp_fe_queue_v_o      = pc_gen_fe_v;


// fe to pc_gen 
//(top module only forward information if the bp_fe_cmd is in the following opcode)
assign fe_pc_gen         = bp_fe_cmd;
assign fe_pc_gen_v       = bp_fe_cmd_v_i;
assign bp_fe_cmd_ready_o = fe_pc_gen_ready;

   
// fe to itlb
// itlb does not has the exception functionality yet, thus it does not use the valid/ready signal from backend
assign fe_itlb_cmd = bp_fe_cmd;
assign fe_itlb_v   = bp_fe_cmd_v_i;

// itlb to fe
assign itlb_fe_ready = bp_fe_queue_ready_i;

// icache to icache
assign poison_i = cache_miss_o && bp_fe_cmd.opcode == e_op_icache_fence;


   
bp_fe_pc_gen #(.vaddr_width_p(vaddr_width_p)
               ,.paddr_width_p(paddr_width_p)
               ,.eaddr_width_p(eaddr_width_p)
               ,.btb_indx_width_p(btb_indx_width_p)
               ,.bht_indx_width_p(bht_indx_width_p)
               ,.ras_addr_width_p(ras_addr_width_p)
               ,.asid_width_p(asid_width_p)
               ,.bp_first_pc_p(bp_first_pc_p)
               ,.instr_width_p(instr_width_p)
               ,.branch_predictor_p(branch_predictor_p)
              ) bp_fe_pc_gen_1
              (.clk_i(clk_i)
               ,.reset_i(reset_i)
               
               ,.v_i(1'b1)
               
               ,.pc_gen_icache_o(pc_gen_icache)
               ,.pc_gen_icache_v_o(pc_gen_icache_v)
               ,.pc_gen_icache_ready_i(pc_gen_icache_ready)
               
               ,.icache_pc_gen_i(icache_pc_gen)
               ,.icache_pc_gen_v_i(icache_pc_gen_v)
               ,.icache_pc_gen_ready_o(icache_pc_gen_ready)
               ,.icache_miss_i(cache_miss_o)
               
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

   
icache #(.eaddr_width_p(eaddr_width_p)
         ,.data_width_p(data_width_p)
         ,.inst_width_p(inst_width_p)
         ,.tag_width_p(tag_width_p)
         ,.num_cce_p(num_cce_p)
         ,.num_lce_p(num_lce_p)
         ,.lce_assoc_p(lce_assoc_p)
         ,.lce_sets_p(lce_sets_p)
         ,.block_size_in_bytes_p(block_size_in_bytes_p)
        ) icache_1
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
         
         ,.lce_cce_req_o(lce_cce_req_o)
         ,.lce_cce_req_v_o(lce_cce_req_v_o)
         ,.lce_cce_req_ready_i(lce_cce_req_ready_i)
         
         ,.lce_cce_resp_o(lce_cce_resp_o)
         ,.lce_cce_resp_v_o(lce_cce_resp_v_o)
         ,.lce_cce_resp_ready_i(lce_cce_resp_ready_i)
         
         ,.lce_cce_data_resp_o(lce_cce_data_resp_o)
         ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v_o)
         ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_ready_i)
         
         ,.cce_lce_cmd_i(cce_lce_cmd_i)
         ,.cce_lce_cmd_v_i(cce_lce_cmd_v_i)
         ,.cce_lce_cmd_ready_o(cce_lce_cmd_ready_o)
         
         ,.cce_lce_data_cmd_i(cce_lce_data_cmd_i)
         ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
         ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_ready_o)
         
         ,.lce_lce_tr_resp_i(lce_lce_tr_resp_i)
         ,.lce_lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
         ,.lce_lce_tr_resp_ready_o(lce_lce_tr_resp_ready_o)               
         
         ,.lce_lce_tr_resp_o(lce_lce_tr_resp_o)
         ,.lce_lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
         ,.lce_lce_tr_resp_ready_i(lce_lce_tr_resp_ready_i)
         
         ,.cache_miss_o(cache_miss_o)
         ,.poison_i(poison_i)
        );

   
itlb #(.vaddr_width_p(vaddr_width_p)
       ,.paddr_width_p(paddr_width_p)
       ,.eaddr_width_p(eaddr_width_p)
       ,.btb_indx_width_p(btb_indx_width_p)
       ,.bht_indx_width_p(bht_indx_width_p)
       ,.ras_addr_width_p(ras_addr_width_p)
       ,.asid_width_p(asid_width_p)
       ,.ppn_start_bit_p(ppn_start_bit_p)
      ) itlb_1
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
