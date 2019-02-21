module bp_boot_rom #(parameter width_p=-1, addr_width_p=-1)
(input  [addr_width_p-1:0] addr_i
,output logic [width_p-1:0]      data_o
);
always_comb case(addr_i)
   default: data_o = { width_p { 1'b0 } };
endcase
endmodule
