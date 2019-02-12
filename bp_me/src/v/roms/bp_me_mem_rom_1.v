// This ROM is empty and should be replaced by an actual test ROM via Makefile
module bp_me_boot_rom #(parameter width_p=-1, addr_width_p=-1)
(input [addr_width_p-1:0] addr_i
 ,output logic [width_p-1:0] data_o
 );
always_comb case(addr_i)
  0: data_o = width_p ' (512'b0);
  1: data_o = width_p ' (512'b1);
  2: data_o = width_p ' (512'b10);
  3: data_o = width_p ' (512'b11);
  4: data_o = width_p ' (512'b100);
  5: data_o = width_p ' (512'b101);
  6: data_o = width_p ' (512'b110);
  7: data_o = width_p ' (512'b111);
  default: data_o = 'X;
endcase
endmodule
