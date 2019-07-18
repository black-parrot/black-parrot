
module bp_addr_map
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   )
  (// Destination nodes address
   input [noc_cord_width_p-1:0]    clint_cord_i
   , input [noc_cord_width_p-1:0]  dram_cord_i
   , input [noc_cord_width_p-1:0]  openpiton_cord_i

   // Command physical address
   , input [paddr_width_p-1:0]     paddr_i

   // Destination router coordinates
   , output [noc_cord_width_p-1:0] dest_cord_o
   );

logic clint_not_dram;

always_comb
  casez (paddr_i)
    cfg_link_dev_base_addr_gp, clint_dev_base_addr_gp, plic_dev_base_addr_gp:
             clint_not_dram = 1'b1;
    default: clint_not_dram = 1'b0;
  endcase

assign dest_cord_o = clint_not_dram ? clint_cord_i : dram_cord_i;

endmodule : bp_addr_map

