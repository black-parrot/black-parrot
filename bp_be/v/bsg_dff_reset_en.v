module bsg_dff_reset_en #(width_p=-1, reset_val_p=0, harden_p=0)
   (input   clk_i
    ,input  reset_i
    ,input  en_i
    ,input  [width_p-1:0] data_i
    ,output [width_p-1:0] data_o
    );

   reg [width_p-1:0] data_r;

   assign data_o = data_r;

   always @(posedge clk_i)
     begin
        if (reset_i)
          data_r <= width_p'(reset_val_p);
        else
          if (en_i)
            data_r <= data_i;
     end



endmodule
