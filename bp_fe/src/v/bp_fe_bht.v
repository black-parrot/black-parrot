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
 #(parameter bht_idx_width_p = "inv"

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

assign predict_o = r_v_i ? mem[idx_r_i][1] : 1'b0;

always_ff @(posedge clk_i) 
  if (reset_i) 
    mem <= '{default:2'b01};
  else if (w_v_i) 
    begin
      //2-bit saturating counter(high_bit:prediction direction,low_bit:strong/weak prediction)
      case ({correct_i, mem[idx_w_i][1], mem[idx_w_i][0]})
        //wrong prediction
        3'b000: mem[idx_w_i] <= {mem[idx_w_i][1]^mem[idx_w_i][0], 1'b1};//2'b01
        3'b001: mem[idx_w_i] <= {mem[idx_w_i][1]^mem[idx_w_i][0], 1'b1};//2'b11
        3'b010: mem[idx_w_i] <= {mem[idx_w_i][1]^mem[idx_w_i][0], 1'b1};//2'b11
        3'b011: mem[idx_w_i] <= {mem[idx_w_i][1]^mem[idx_w_i][0], 1'b1};//2'b01
        //correct prediction
        3'b100: mem[idx_w_i] <= mem[idx_w_i];//2'b00
        3'b101: mem[idx_w_i] <= {mem[idx_w_i][1], ~mem[idx_w_i][0]};//2'b00
        3'b110: mem[idx_w_i] <= mem[idx_w_i];//2'b10
        3'b111: mem[idx_w_i] <= {mem[idx_w_i][1], ~mem[idx_w_i][0]};//2'b10
      endcase
    end

endmodule
