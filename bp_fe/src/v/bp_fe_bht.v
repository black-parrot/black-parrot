/*
 * bp_fe_bht.v
 * 
 * Branch History Table (BHT) records the information of the branch history, i.e.
 * branch taken or not taken. 
 * Each entry consists of 2 bit saturation counter. If the counter value is in
 * the positive regime, the BHT predicts "taken"; if the counter value is in the
 * negative regime, the BHT predicts "not taken". The implementation of BHT is
 * native to this design.
*/
module bp_fe_bht
 import bp_fe_pkg::*; 
 #(parameter vaddr_width_p = "inv"
   , parameter bht_idx_width_p = "inv"

   , parameter debug_p             = 0

   , localparam els_lp             = 2**bht_idx_width_p
   , localparam saturation_size_lp = 2
   )
  (input                         clk_i
   , input                       reset_i
    
   , input                       w_v_i
   , input [bht_idx_width_p-1:0] idx_w_i
   , input                       correct_i
 
   , input                       r_v_i   
   , input [bht_idx_width_p-1:0] idx_r_i

   , output                      predict_o
   );

logic [els_lp-1:0][saturation_size_lp-1:0] mem;

logic [bht_idx_width_p-1:0] idx_r_r;
logic r_v_r;
bsg_dff
 #(.width_p(1+bht_idx_width_p))
 read_reg
  (.clk_i(clk_i)

   ,.data_i({r_v_i, idx_r_i})
   ,.data_o({r_v_r, idx_r_r})
   );
assign predict_o = r_v_r ? mem[idx_r_r][1] : `BSG_UNDEFINED_IN_SIM(1'b0);

//2-bit saturating counter(high_bit:prediction direction,low_bit:strong/weak prediction)
always_ff @(posedge clk_i) 
  if (reset_i) 
    mem <= '{default:2'b01};
  else if (w_v_i & correct_i)
    mem[idx_w_i] <= {mem[idx_w_i][1], 1'b0};
  else if (w_v_i & ~correct_i)
    mem[idx_w_i] <= {mem[idx_w_i][1]^mem[idx_w_i][0], 1'b1};


//synopsys translate_off
logic [bht_idx_width_p-1:0] idx_w_r;
logic correct_r, w_v_r;
bsg_dff
 #(.width_p(2+bht_idx_width_p))
 write_reg
  (.clk_i(clk_i)

   ,.data_i({correct_i, w_v_i, idx_w_i})
   ,.data_o({correct_r, w_v_r, idx_w_r})
   );

if (debug_p)
  begin
     always_ff @(negedge clk_i)
       begin
         if (w_v_r | r_v_r)
	       $write("v=%b c=%b W[%h] (=%b); v=%b R[%h] (=%b) p=%b ",w_v_r,correct_r,idx_w_r,mem[idx_w_r],r_v_r,idx_r_r,mem[idx_r_r],predict_o);

	  if (w_v_r & ~correct_r)
	    $write("X\n");
	  else if (w_v_r | r_v_r)
	    $write("\n");
       end
end // if (debug_p)
//synopsys translate_on 

endmodule
