
module bp_addr_map
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (// Destination nodes address
   input [mem_noc_cord_width_p-1:0]    clint_cord_i
   , input [mem_noc_cord_width_p-1:0]  dram_cord_i
   , input [mem_noc_cord_width_p-1:0]  host_cord_i

   // Command physical address
   , input [paddr_width_p-1:0]         paddr_i

   // Destination router coordinates
   , output [mem_noc_cord_width_p-1:0] dst_cord_o
   , output [mem_noc_cid_width_p-1:0]  dst_cid_o
   );

// TODO: Currently, tiles are not writable and host is the same as DRAM
wire unused = &{host_cord_i};

logic clint_not_dram;

always_comb
  casez (paddr_i)
    cfg_link_dev_base_addr_gp, clint_dev_base_addr_gp, plic_dev_base_addr_gp:
             clint_not_dram = 1'b1;
    default: clint_not_dram = 1'b0;
  endcase

assign dst_cord_o = clint_not_dram ? clint_cord_i : dram_cord_i;
assign dst_cid_o  = '0; // currently unused

endmodule

