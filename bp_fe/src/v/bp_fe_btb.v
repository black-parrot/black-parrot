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
logic [bp_fe_pc_gen_btb_idx_width_lp-1:0] addr;
   
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

assign addr = (w_v_i) ? idx_w_i : idx_r_i;

always_ff @(posedge clk_i)
  begin
    read_valid_o = valid[idx_r_i];
  end
   
bsg_mem_1rw_sync 
 #(.width_p(eaddr_width_p)
   ,.els_p(2**bp_fe_pc_gen_btb_idx_width_lp)
   ,.addr_width_lp(bp_fe_pc_gen_btb_idx_width_lp)
   ) 
 btb_mem 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.data_i(branch_target_i)
   ,.addr_i(addr)
   ,.v_i(1'b1) 
   ,.w_i(w_v_i)
   ,.data_o(branch_target_o)
   );

endmodule
