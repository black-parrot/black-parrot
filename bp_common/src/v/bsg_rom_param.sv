
`include "bsg_defines.sv"

module bsg_rom_param
 #(parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(data_p)
   , parameter `BSG_INV_PARAM(width_p)
   , parameter `BSG_INV_PARAM(els_p)

   , localparam lg_els_lp = `BSG_SAFE_CLOG2(els_p)
   )
  (input [lg_els_lp-1:0] addr_i
   , output logic [width_p-1:0] data_o
   );

  assign data_o = data_p[addr_i*width_p+:width_p];

endmodule

`BSG_ABSTRACT_MODULE(bsg_rom_param)

