/*
 * bp_fe_branch_predictor.v
 * 
 * Branch prediction implemented by Branch Target Buffer (BTB) and Branch History Table (BHT).
 * BTB stores the addresses of branch targets and BHT stores the information of the branch history
 * e.g. branch taken or not taken.  
*/

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

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif


module branch_prediction_bht_btb
 #(parameter   eaddr_width_p="inv"
   , parameter btb_indx_width_p="inv"
   , parameter bht_indx_width_p="inv"
   , parameter ras_addr_width_p="inv"
   , parameter branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
  )
  (input logic                                       clk_i
   , input logic                                     reset_i

   , input logic                                     attaboy
   , input logic                                     bp_r_i
   , input logic                                     bp_w_i
   , input logic [eaddr_width_p-1:0]                 pc_queue_i
   , input logic [eaddr_width_p-1:0]                 pc_cmd_i
   , input logic [eaddr_width_p-1:0]                 pc_fwd_i
   , input logic [branch_metadata_fwd_width_lp-1:0]  branch_metadata_fwd_i

   , output logic                                    predict_o
   , output logic [eaddr_width_p-1:0]                pc_o
   , output logic [branch_metadata_fwd_width_lp-1:0] branch_metadata_fwd_o
  );


//BHT prediction (taken, not taken)
logic predict;
//prediction valid signal
logic read_valid;

   
`declare_bp_fe_branch_metadata_fwd_s(btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);
bp_fe_branch_metadata_fwd_s branch_metadata_i;
bp_fe_branch_metadata_fwd_s branch_metadata_o;

   
assign branch_metadata_i     = branch_metadata_fwd_i;
assign branch_metadata_fwd_o = branch_metadata_o;
assign predict_o             = predict && read_valid;
assign branch_metadata_o     = {pc_fwd_i[btb_indx_width_p-1:0]
                                ,pc_fwd_i[bht_indx_width_p-1:0]
                                ,ras_addr_width_p'(0)
                               };


   
bht #(.saturation_size_lp(2)
      ,.bht_indx_width_p(bht_indx_width_p)
     ) bht_1
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(1'b1)
        
      ,.bht_idx_r_i(pc_queue_i[bht_indx_width_p-1:0])
      ,.bht_idx_w_i(branch_metadata_i.bht_indx)
     
      ,.bht_r_i(bp_r_i)
      ,.bht_w_i(bp_w_i)
     
      ,.correct_i(attaboy)
      ,.predict_o(predict)
     );

    
btb #(.bp_fe_pc_gen_btb_idx_width_lp(btb_indx_width_p)
      ,.eaddr_width_p(eaddr_width_p)
     ) btb_1 
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.btb_idx_r_i(pc_queue_i[btb_indx_width_p-1:0])
      ,.btb_idx_w_i(branch_metadata_i.btb_indx)
    
      ,.btb_r_i(bp_r_i)
      ,.btb_w_i(bp_w_i)
    
      ,.branch_target_i(pc_cmd_i)
      ,.branch_target_o(pc_o)
    
      ,.read_valid_o(read_valid)
     );

endmodule
