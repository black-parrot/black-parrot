
module bsg_rom_param
 #(parameter data_width_p = "inv"
   //, parameter logic [data_width_p-1:0] data_p = "inv"
   , parameter data_p = "inv"
   , parameter width_p = "inv"
   , parameter els_p = "inv"

   , localparam lg_els_lp = `BSG_SAFE_CLOG2(els_p)
   )
  (input [lg_els_lp-1:0] addr_i
   , output logic [width_p-1:0] data_o
   );

  assign data_o = data_p[addr_i*width_p+:width_p];

endmodule

