/*
 * bp_fe_btb.v
 * 
 * Branch Target Buffer (BTB) stores the addresses of the branch targets and the
 * corresponding branch sites. Branch happens from the branch sites to the branch
 * targets. In order to save the logic sizes, the BTB is designed to have limited 
 * entries for storing the branch sites, branch target pairs. The implementation 
 * uses the bsg_mem_1rw_sync_synth RAM design.
*/

module bp_fe_btb
 import bp_fe_pkg::*; 
 #(parameter   bp_fe_pc_gen_btb_idx_width_lp=9
   , parameter eaddr_width_p="inv"
   , localparam els_lp=2**bp_fe_pc_gen_btb_idx_width_lp
   ) 
  (input                                       clk_i
   , input                                     reset_i 

   , input [bp_fe_pc_gen_btb_idx_width_lp-1:0] idx_w_i
   , input [bp_fe_pc_gen_btb_idx_width_lp-1:0] idx_r_i
   , input                                     r_v_i
   , input                                     w_v_i

   , input [eaddr_width_p-1:0]                 branch_target_i
   , output logic [eaddr_width_p-1:0]          branch_target_o

   , output logic                              read_valid_o
   );

   
logic [els_lp-1:0] valid;

always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
      begin
        valid <= '{default:'0};
      end 
    else if (w_v_i) 
      begin
        valid[idx_w_i] <= '1;
      end
  end

assign read_valid_o = valid[idx_r_i];

bsg_mem_1r1w 
 #(.width_p(eaddr_width_p)
   ,.els_p(2**bp_fe_pc_gen_btb_idx_width_lp)
   ,.addr_width_lp(bp_fe_pc_gen_btb_idx_width_lp)
   ) 
 bsg_mem_1rw_sync_synth_1 
  (.w_clk_i(clk_i)
   ,.w_reset_i(reset_i)

   ,.w_v_i(w_v_i)
   ,.w_addr_i(idx_w_i)
   ,.w_data_i(branch_target_i)
   
   ,.r_v_i(r_v_i)
   ,.r_addr_i(idx_r_i)
   ,.r_data_o(branch_target_o)
   );

endmodule
