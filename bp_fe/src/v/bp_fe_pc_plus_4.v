/*
 * bp_fe_pc_plus_4.v
 * 
 * The simplest predictor ever :D 
*/

module branch_prediction_pc_plus_4
 import bp_fe_pkg::*;
 #(parameter   eaddr_width_p="inv"
   , parameter btb_indx_width_p="inv"
   , parameter bht_indx_width_p="inv"
   , parameter ras_addr_width_p="inv"
   , localparam branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
   )
  (input                                             clk_i
   , input                                           reset_i

   , input                                           attaboy
   , input                                           bp_r_i
   , input                                           bp_w_i
   , input  [eaddr_width_p-1:0]                      pc_queue_i
   , input  [eaddr_width_p-1:0]                      pc_cmd_i
   , input  [eaddr_width_p-1:0]                      pc_fwd_i
   , input  [branch_metadata_fwd_width_lp-1:0]       branch_metadata_fwd_i

   , output logic                                    predict_o
   , output logic [eaddr_width_p-1:0]                pc_o
   , output logic [branch_metadata_fwd_width_lp-1:0] branch_metadata_fwd_o
  );

//BHT prediction (taken, not taken)
logic predict;
//prediction valid signal
logic read_valid;

   
`declare_bp_fe_branch_metadata_fwd_s(btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);
bp_fe_branch_metadata_fwd_s branch_metadata_o;



assign branch_metadata_fwd_o = branch_metadata_o;
assign branch_metadata_o     = {pc_fwd_i[btb_indx_width_p-1:0]
                                ,pc_fwd_i[bht_indx_width_p-1:0]
                                ,ras_addr_width_p'(0)
                               };
assign predict_o             = 1'b0;
assign pc_o                  = pc_queue_i + 'd4;

   
endmodule
