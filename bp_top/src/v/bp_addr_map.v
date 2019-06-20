
module bp_addr_map
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   ,parameter x_cord_width_p = "inv"
   ,parameter y_cord_width_p = "inv"
   
   `declare_bp_proc_params(cfg_p)
   )
  (// Command physical address
     input [paddr_width_p-1:0]    paddr_i
   
   // Destination nodes address
   , input [x_cord_width_p-1:0]  clint_x_cord_i
   , input [y_cord_width_p-1:0]  clint_y_cord_i
   , input [x_cord_width_p-1:0]  dram_x_cord_i
   , input [y_cord_width_p-1:0]  dram_y_cord_i

   // Destination router coordinates
   , output [x_cord_width_p-1:0]  dest_x_o
   , output [y_cord_width_p-1:0]  dest_y_o
   );

logic clint_not_dram;

always_comb
  casez (paddr_i)
    cfg_link_dev_base_addr_gp, clint_dev_base_addr_gp, plic_dev_base_addr_gp:
             clint_not_dram = 1'b1;
    default: clint_not_dram = 1'b0;
  endcase

assign dest_x_o = clint_not_dram ? clint_x_cord_i : dram_x_cord_i;
assign dest_y_o = clint_not_dram ? clint_y_cord_i : dram_y_cord_i;

endmodule : bp_addr_map

