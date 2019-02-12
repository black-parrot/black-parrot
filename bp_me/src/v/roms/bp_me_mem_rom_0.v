// This ROM is empty and should be replaced by an actual test ROM via Makefile
module bp_me_boot_rom #(parameter width_p=-1, addr_width_p=-1)
(input [addr_width_p-1:0] addr_i
 ,output logic [width_p-1:0] data_o
 );
always_comb case(addr_i)
    default: data_o = width_p ' (64'b0000000000000000000000000000000000000000000000000000000000000000); // 0x0000000000000000
endcase
endmodule
