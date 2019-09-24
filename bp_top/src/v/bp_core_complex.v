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
 import bp_common_rv64_pkg::*;
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
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   )
  (input                                                           core_clk_i
   , input                                                         core_reset_i

   , input                                                         coh_clk_i
   , input                                                         coh_reset_i

   , input                                                         mem_clk_i
   , input                                                         mem_reset_i

   // Memory side connection
   , input [num_core_p-1:0][mem_noc_cord_width_p-1:0]              tile_cord_i
   , input [mem_noc_cord_width_p-1:0]                              dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                              mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]                              host_cord_i

   // Config channel
   , input [num_core_p-1:0]                                        cfg_w_v_i
   , input [num_core_p-1:0][cfg_addr_width_p-1:0]                  cfg_addr_i
   , input [num_core_p-1:0][cfg_data_width_p-1:0]                  cfg_data_i

   // Interrupts
   , input [num_core_p-1:0]                                        timer_irq_i
   , input [num_core_p-1:0]                                        soft_irq_i
   , input [num_core_p-1:0]                                        external_irq_i

   , input [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]    mem_cmd_link_i
   , output [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]   mem_cmd_link_o

   , input [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]    mem_resp_link_i
   , output [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]   mem_resp_link_o
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, coh_noc_ral_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, mem_noc_ral_link_s);

logic [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0]                       cfg_w_v_lo;
logic [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0][cfg_addr_width_p-1:0] cfg_addr_lo;
logic [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0][cfg_data_width_p-1:0] cfg_data_lo;

logic [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0] timer_irq_lo, soft_irq_lo, external_irq_lo;

coh_noc_ral_link_s [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0][S:W] lce_req_link_lo, lce_req_link_li;
coh_noc_ral_link_s [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0][S:W] lce_cmd_link_lo, lce_cmd_link_li;
coh_noc_ral_link_s [coh_noc_y_dim_p-1:0][coh_noc_x_dim_p-1:0][S:W] lce_resp_link_lo, lce_resp_link_li;

mem_noc_ral_link_s [mem_noc_y_dim_p-1:0][mem_noc_x_dim_p-1:0][S:W] mem_cmd_link_lo, mem_cmd_link_li;
mem_noc_ral_link_s [mem_noc_y_dim_p-1:0][mem_noc_x_dim_p-1:0][S:W] mem_resp_link_lo, mem_resp_link_li;

coh_noc_ral_link_s [E:W][mem_noc_y_dim_p-1:0] lce_req_hor_link_li, lce_req_hor_link_lo;
coh_noc_ral_link_s [S:N][mem_noc_x_dim_p-1:0] lce_req_ver_link_li, lce_req_ver_link_lo;
coh_noc_ral_link_s [E:W][mem_noc_y_dim_p-1:0] lce_cmd_hor_link_li, lce_cmd_hor_link_lo;
coh_noc_ral_link_s [S:N][mem_noc_x_dim_p-1:0] lce_cmd_ver_link_li, lce_cmd_ver_link_lo;
coh_noc_ral_link_s [E:W][mem_noc_y_dim_p-1:0] lce_resp_hor_link_li, lce_resp_hor_link_lo;
coh_noc_ral_link_s [S:N][mem_noc_x_dim_p-1:0] lce_resp_ver_link_li, lce_resp_ver_link_lo;

mem_noc_ral_link_s [E:W][mem_noc_y_dim_p-1:0] mem_cmd_hor_link_li, mem_cmd_hor_link_lo;
mem_noc_ral_link_s [S:N][mem_noc_x_dim_p-1:0] mem_cmd_ver_link_li, mem_cmd_ver_link_lo;
mem_noc_ral_link_s [E:W][mem_noc_y_dim_p-1:0] mem_resp_hor_link_li, mem_resp_hor_link_lo;
mem_noc_ral_link_s [S:N][mem_noc_x_dim_p-1:0] mem_resp_ver_link_li, mem_resp_ver_link_lo;

for (genvar j = 0; j < mem_noc_y_dim_p; j++)
  begin : y
    for (genvar i = 0; i < mem_noc_x_dim_p; i++) 
      begin : x
        localparam tile_idx = j*mem_noc_x_dim_p + i;

        bp_proc_cfg_s proc_cfg;
        assign proc_cfg.core_id   = tile_idx;
        assign proc_cfg.cce_id    = tile_idx;
        assign proc_cfg.icache_id = (tile_idx*2 + 0);
        assign proc_cfg.dcache_id = (tile_idx*2 + 1);

        // TODO: Num stages arbitrarily set, should be based on PD
        logic cfg_w_v_li, timer_irq_li, soft_irq_li, external_irq_li;
        logic [cfg_addr_width_p-1:0] cfg_addr_li;
        logic [cfg_data_width_p-1:0] cfg_data_li;
        bsg_dff_chain
         #(.width_p(3+1+cfg_addr_width_p+cfg_data_width_p), .num_stages_p(10))
         slow_pipe
          (.clk_i(core_clk_i)
           ,.data_i({cfg_w_v_i[tile_idx]
                     ,cfg_addr_i[tile_idx]
                     ,cfg_data_i[tile_idx]
                     ,timer_irq_i[tile_idx]
                     ,soft_irq_i[tile_idx]
                     ,external_irq_i[tile_idx]
                     })
           ,.data_o({cfg_w_v_li
                     ,cfg_addr_li
                     ,cfg_data_li
                     ,timer_irq_li
                     ,soft_irq_li
                     ,external_irq_li})
           );
    
        bp_tile_node
         #(.cfg_p(cfg_p))
         tile_node
          (.core_clk_i(core_clk_i)
           ,.core_reset_i(core_reset_i)

           ,.coh_clk_i(coh_clk_i)
           ,.coh_reset_i(coh_reset_i)

           ,.mem_clk_i(mem_clk_i)
           ,.mem_reset_i(mem_reset_i)
    
           ,.proc_cfg_i(proc_cfg)
    
           ,.my_cord_i(tile_cord_i[tile_idx])
           ,.my_cid_i(mem_noc_cid_width_p'(0))
           ,.dram_cord_i(dram_cord_i)
           ,.mmio_cord_i(mmio_cord_i)
           ,.host_cord_i(host_cord_i)
    
           ,.cfg_w_v_i(cfg_w_v_li)
           ,.cfg_addr_i(cfg_addr_li)
           ,.cfg_data_i(cfg_data_li)
    
           ,.timer_int_i(timer_irq_li)
           ,.software_int_i(soft_irq_li)
           ,.external_int_i(external_irq_li)

           ,.coh_lce_req_link_i(lce_req_link_li[j][i])
           ,.coh_lce_resp_link_i(lce_resp_link_li[j][i])
           ,.coh_lce_cmd_link_i(lce_cmd_link_li[j][i])
    
           ,.coh_lce_req_link_o(lce_req_link_lo[j][i])
           ,.coh_lce_resp_link_o(lce_resp_link_lo[j][i])
           ,.coh_lce_cmd_link_o(lce_cmd_link_lo[j][i])
    
           ,.mem_cmd_link_i(mem_cmd_link_li[j][i])
           ,.mem_resp_link_i(mem_resp_link_li[j][i])
    
           ,.mem_cmd_link_o(mem_cmd_link_lo[j][i])
           ,.mem_resp_link_o(mem_resp_link_lo[j][i])
           );
      end
  end

  assign lce_req_hor_link_li = '0;
  assign lce_req_ver_link_li = '0;
  bsg_mesh_stitch
   #(.width_p($bits(coh_noc_ral_link_s))
     ,.x_max_p(coh_noc_x_dim_p)
     ,.y_max_p(coh_noc_y_dim_p)
     )
   coh_req_mesh
    (.outs_i(lce_req_link_lo)
     ,.ins_o(lce_req_link_li)

     ,.hor_i(lce_req_hor_link_li)
     ,.hor_o(lce_req_hor_link_lo)

     ,.ver_i(lce_req_ver_link_li)
     ,.ver_o(lce_req_ver_link_lo)
     );
  
  assign lce_cmd_hor_link_li = '0;
  assign lce_cmd_ver_link_li = '0;
  bsg_mesh_stitch
   #(.width_p($bits(coh_noc_ral_link_s))
     ,.x_max_p(coh_noc_x_dim_p)
     ,.y_max_p(coh_noc_y_dim_p)
     )
   coh_cmd_mesh
    (.outs_i(lce_cmd_link_lo)
     ,.ins_o(lce_cmd_link_li)

     ,.hor_i(lce_cmd_hor_link_li)
     ,.hor_o(lce_cmd_hor_link_lo)

     ,.ver_i(lce_cmd_ver_link_li)
     ,.ver_o(lce_cmd_ver_link_lo)
     );
  
  assign lce_resp_hor_link_li = '0;
  assign lce_resp_ver_link_li = '0;
  bsg_mesh_stitch
   #(.width_p($bits(coh_noc_ral_link_s))
     ,.x_max_p(coh_noc_x_dim_p)
     ,.y_max_p(coh_noc_y_dim_p)
     )
   coh_resp_mesh
    (.outs_i(lce_resp_link_lo)
     ,.ins_o(lce_resp_link_li)

     ,.hor_i(lce_resp_hor_link_li)
     ,.hor_o(lce_resp_hor_link_lo)

     ,.ver_i(lce_resp_ver_link_li)
     ,.ver_o(lce_resp_ver_link_lo)
     );
  
  assign mem_cmd_hor_link_li    = '0;
  assign mem_cmd_ver_link_li[N] = mem_cmd_link_i;
  assign mem_cmd_ver_link_li[S] = '0;
  bsg_mesh_stitch
   #(.width_p($bits(mem_noc_ral_link_s))
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(mem_noc_y_dim_p)
     )
   mem_cmd_mesh
    (.outs_i(mem_cmd_link_lo)
     ,.ins_o(mem_cmd_link_li)

     ,.hor_i(mem_cmd_hor_link_li)
     ,.hor_o(mem_cmd_hor_link_lo)

     ,.ver_i(mem_cmd_ver_link_li)
     ,.ver_o(mem_cmd_ver_link_lo)
     );
  assign mem_cmd_link_o = mem_cmd_ver_link_lo[N];

  assign mem_resp_hor_link_li    = '0;
  assign mem_resp_ver_link_li[N] = mem_resp_link_i;
  assign mem_resp_ver_link_li[S] = '0;
  bsg_mesh_stitch
   #(.width_p($bits(mem_noc_ral_link_s))
     ,.x_max_p(mem_noc_x_dim_p)
     ,.y_max_p(mem_noc_y_dim_p)
     )
   mem_resp_mesh
    (.outs_i(mem_resp_link_lo)
     ,.ins_o(mem_resp_link_li)

     ,.hor_i(mem_resp_hor_link_li)
     ,.hor_o(mem_resp_hor_link_lo)

     ,.ver_i(mem_resp_ver_link_li)
     ,.ver_o(mem_resp_ver_link_lo)
     );
  assign mem_resp_link_o = mem_resp_ver_link_lo[N];

endmodule

