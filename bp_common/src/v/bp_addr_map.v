
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

parameter vcache_sets_p = 64;

localparam lg_num_mem_lp = `BSG_SAFE_CLOG2(num_mem_p);
localparam lg_vcache_sets_lp = `BSG_SAFE_CLOG2(vcache_sets_p);
localparam cache_line_offset_lp = `BSG_SAFE_CLOG2(cce_block_width_p) - `BSG_SAFE_CLOG2(8);
localparam vcache_offset_lp = cache_line_offset_lp + lg_vcache_sets_lp;

logic clint_not_dram, host_not_dram;
logic [mem_noc_cord_width_p-1:0] cache_cord;

if (num_mem_p == 1)
    assign cache_cord = dram_cord_i;
else
    assign cache_cord = dram_cord_i + paddr_i[vcache_offset_lp+:lg_num_mem_lp];

always_comb
  casez (paddr_i)
    cfg_link_dev_base_addr_gp, clint_dev_base_addr_gp, plic_dev_base_addr_gp:
             clint_not_dram = 1'b1;
    default: clint_not_dram = 1'b0;
  endcase
  
assign host_not_dram = (paddr_i < dram_base_addr_gp);

assign dst_cord_o = clint_not_dram ? clint_cord_i : host_not_dram ? host_cord_i : cache_cord;
assign dst_cid_o  = '0; // currently unused

endmodule

