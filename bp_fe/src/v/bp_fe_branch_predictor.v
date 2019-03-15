/*
 * bp_fe_branch_predictor.v
 * 
 * Branch prediction implemented by Branch Target Buffer (BTB) and Branch History Table (BHT).
 * BTB stores the addresses of branch targets and BHT stores the information of the branch history
 * e.g. branch taken or not taken.  
*/

module bp_fe_branch_predictor
 import bp_fe_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter eaddr_width_p="inv"
   , parameter btb_tag_width_p="inv"
   , parameter btb_indx_width_p="inv"
   , parameter bht_indx_width_p="inv"
   , parameter ras_addr_width_p="inv"
   , localparam branch_metadata_fwd_width_lp=`bp_fe_branch_metadata_fwd_width(btb_tag_width_p,btb_indx_width_p,bht_indx_width_p,ras_addr_width_p)
   )
  (input                                             clk_i
   , input                                           reset_i

   , input                                           attaboy_i
   , input                                           r_v_i
   , input                                           w_v_i
   , input [eaddr_width_p-1:0]                       pc_queue_i
   , input [eaddr_width_p-1:0]                       pc_cmd_i
   , input [eaddr_width_p-1:0]                       pc_fwd_i
   , input [branch_metadata_fwd_width_lp-1:0]        branch_metadata_fwd_i

   , output logic                                    predict_o
   , output logic [eaddr_width_p-1:0]                pc_o
   , output logic [branch_metadata_fwd_width_lp-1:0] branch_metadata_fwd_o
   );


//BHT prediction (taken, not taken)
logic predict;
//prediction valid signal
logic read_valid;

   
`declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_p,btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);
bp_fe_branch_metadata_fwd_s branch_metadata_i;
bp_fe_branch_metadata_fwd_s branch_metadata_o;

   
assign branch_metadata_i     = branch_metadata_fwd_i;
assign branch_metadata_fwd_o = branch_metadata_o;
assign predict_o             = predict && read_valid;
assign branch_metadata_o     = {pc_fwd_i[btb_indx_width_p-1:0]
                                ,pc_fwd_i[bht_indx_width_p-1:0]
                                ,ras_addr_width_p'(0)
                               };


/*
bp_fe_bht 
 #(.bht_indx_width_p(bht_indx_width_p)
   ) 
 bht_1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(1'b1)
        
   ,.idx_r_i(pc_queue_i[bht_indx_width_p-1:0])
   ,.idx_w_i(branch_metadata_i.bht_indx)
     
   ,.r_v_i(r_v_i)
   ,.w_v_i(w_v_i)
     
   ,.correct_i(attaboy_i)
   ,.predict_o(predict)
   );

    
bp_fe_btb
 #(.bp_fe_pc_gen_btb_idx_width_lp(btb_indx_width_p)
   ,.eaddr_width_p(eaddr_width_p)
   ) 
 btb_1 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
    
   ,.idx_r_i(pc_queue_i[btb_indx_width_p-1:0])
   ,.idx_w_i(branch_metadata_i.btb_indx)
    
   ,.r_v_i(r_v_i)
   ,.w_v_i(w_v_i)
    
   ,.branch_target_i(pc_cmd_i)
   ,.branch_target_o(pc_o)
    
   ,.read_valid_o(read_valid)
   );
*/

endmodule
