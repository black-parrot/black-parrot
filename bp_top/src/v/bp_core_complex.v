/**
 *
 * bp_core_complex.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_core_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                    clk_i
   , input                                                  reset_i

   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0]       tile_cord_i
   , input [mem_noc_cord_width_p-1:0]                       dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                       mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]                       host_cord_i

   , input [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0]  cmd_link_i
   , output [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0] cmd_link_o

   , input [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0]  resp_link_i
   , output [num_core_p-1:0][mem_noc_ral_link_width_lp-1:0] resp_link_o
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

logic [num_core_p-1:0]                       cfg_w_v_lo;
logic [num_core_p-1:0][cfg_addr_width_p-1:0] cfg_addr_lo;
logic [num_core_p-1:0][cfg_data_width_p-1:0] cfg_data_lo;
logic [num_core_p-1:0] timer_irq_lo, soft_irq_lo, external_irq_lo;

logic [mem_noc_y_dim_p-1:0][mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0] 
  tile_cmd_link_li, tile_cmd_link_lo, tile_resp_link_li, tile_resp_link_lo;

logic [mem_noc_ral_link_width_lp-1:0] 
  mmio_cmd_link_li, mmio_cmd_link_lo, mmio_resp_link_li, mmio_resp_link_lo;

logic [mem_noc_y_dim_p-1:0][mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0] 
  cmd_link_li, cmd_link_lo, resp_link_li, resp_link_lo;

bp_tile_mesh
 #(.cfg_p(cfg_p))
 tile_mesh
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_w_v_i(cfg_w_v_lo)
   ,.cfg_addr_i(cfg_addr_lo)
   ,.cfg_data_i(cfg_data_lo)

   ,.timer_irq_i(timer_irq_lo)
   ,.soft_irq_i(soft_irq_lo)
   ,.external_irq_i(external_irq_lo)

   ,.tile_cord_i(tile_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.mmio_cord_i(mmio_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.cmd_link_i(tile_cmd_link_li)
   ,.cmd_link_o(tile_cmd_link_lo)
   ,.resp_link_i(tile_resp_link_li)
   ,.resp_link_o(tile_resp_link_lo)
   );

bp_mmio_enclave
 #(.cfg_p(cfg_p))
 mmio
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.cfg_w_v_o(cfg_w_v_lo)
   ,.cfg_addr_o(cfg_addr_lo)
   ,.cfg_data_o(cfg_data_lo)

   ,.soft_irq_o(soft_irq_lo)
   ,.timer_irq_o(timer_irq_lo)
   ,.external_irq_o(external_irq_lo)

   ,.my_cord_i(mmio_cord_i)
   // TODO: Configurable?
   ,.my_cid_i(mem_noc_cid_width_p'(1))
   ,.dram_cord_i(dram_cord_i)
   ,.mmio_cord_i(mmio_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.cmd_link_i(mmio_cmd_link_li)
   ,.cmd_link_o(mmio_cmd_link_lo)
   ,.resp_link_i(mmio_resp_link_li)
   ,.resp_link_o(mmio_resp_link_lo)
   );

for (genvar j = 0; j < mem_noc_y_dim_p; j++)
  begin : y
    for (genvar i = 0; i < mem_noc_x_dim_p; i++)
      begin : x
        if ((i == mmio_x_pos_p) && (j == mmio_y_pos_p))
          begin : conc
            bsg_wormhole_concentrator
             #(.flit_width_p(mem_noc_flit_width_p)
               ,.len_width_p(mem_noc_len_width_p)
               ,.cid_width_p(mem_noc_cid_width_p)
               ,.num_in_p(2)
               ,.cord_width_p(mem_noc_cord_width_p)
               )
             cmd_concentrator
              (.clk_i(clk_i)
               ,.reset_i(reset_i)

               ,.links_i({mmio_cmd_link_lo, tile_cmd_link_lo[j][i]})
               ,.links_o({mmio_cmd_link_li, tile_cmd_link_li[j][i]})

               ,.concentrated_link_i(cmd_link_li[j][i])
               ,.concentrated_link_o(cmd_link_lo[j][i])
               );

            bsg_wormhole_concentrator
             #(.flit_width_p(mem_noc_flit_width_p)
               ,.len_width_p(mem_noc_len_width_p)
               ,.cid_width_p(mem_noc_cid_width_p)
               ,.num_in_p(2)
               ,.cord_width_p(mem_noc_cord_width_p)
               )
             resp_concentrator
              (.clk_i(clk_i)
               ,.reset_i(reset_i)

               ,.links_i({mmio_resp_link_lo, tile_resp_link_lo[j][i]})
               ,.links_o({mmio_resp_link_li, tile_resp_link_li[j][i]})

               ,.concentrated_link_i(resp_link_li[j][i])
               ,.concentrated_link_o(resp_link_lo[j][i])
               );
          end
        else
          begin : no_conc
            assign resp_link_lo[j][i]      = tile_resp_link_lo[j][i];
            assign tile_resp_link_li[j][i] = resp_link_li[j][i];
            assign cmd_link_lo[j][i]       = tile_cmd_link_lo[j][i];
            assign tile_cmd_link_li[j][i]  = cmd_link_li[j][i];
          end
      end
  end

  assign cmd_link_o   = cmd_link_lo;
  assign cmd_link_li  = cmd_link_i;
  assign resp_link_o  = resp_link_lo;
  assign resp_link_li = resp_link_i;

endmodule

