module boot_rom
  #(parameter data_width_p="inv"
    ,parameter addr_width_p="inv"
  )
  (
    input [addr_width_p-1:0] addr_i
    ,output logic [data_width_p-1:0] data_o
  );

  wire [addr_width_p-1:0] unused = addr_i;
  assign data_o = '0;

endmodule

