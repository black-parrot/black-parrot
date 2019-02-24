// MBT 10-29-14
//
// implements a shift register of fixed latency
//
//
// If fixed_p is 0, then shift only occurs when v_i is high

module bsg_shift_reg #(parameter width_p = "inv"
                       , parameter stages_p = "inv"
                       )
   (input clk_i
    , input reset_i
    , input v_i
    , input               dir_i
    , input [width_p-1:0] data_i
    , output [width_p-1:0] data_o
    );

   logic [stages_p-1:0][width_p-1:0] shift_r;

   always_ff @(posedge clk_i)
     if (reset_i)
       shift_r <= '0;
     else
       begin
             if (v_i)
               begin
                 if (dir_i == 0)
                   begin
                     shift_r[0+:stages_p-1] <= shift_r[1+:stages_p-1];
                     shift_r[stages_p-1] <= data_i;
                   end
                 else
                   begin
                     shift_r[1+:stages_p-1] <= shift_r[0+:stages_p-1];
                     shift_r[0] <= data_i;
                   end
               end
             else
               begin
                 shift_r <= shift_r;
               end
       end
   assign data_o = shift_r[0];

endmodule
