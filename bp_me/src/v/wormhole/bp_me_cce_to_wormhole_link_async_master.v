
/**
 * bp_me_cce_to_wormhole_link_async_master.v
 */

`include "bsg_noc_links.vh"

module bp_me_cce_to_wormhole_link_async_master

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
  
  `declare_bp_proc_params(cfg_p)
  , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)
  
  // wormhole parameters
  ,parameter  x_cord_width_p = "inv"
  ,parameter  y_cord_width_p = "inv"
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
  )
  
  (input clk_i
  ,input reset_i

  // CCE-MEM Interface
  // CCE to Mem, Mem is demanding and uses vaild->ready (valid-yumi)
  ,input  logic [cce_mem_cmd_width_lp-1:0]       mem_cmd_i
  ,input  logic                                  mem_cmd_v_i
  ,output logic                                  mem_cmd_yumi_o
                                                 
  ,input  logic [cce_mem_data_cmd_width_lp-1:0]  mem_data_cmd_i
  ,input  logic                                  mem_data_cmd_v_i
  ,output logic                                  mem_data_cmd_yumi_o
                                                 
  // Mem to CCE, Mem is demanding and uses ready->valid
  ,output logic [mem_cce_resp_width_lp-1:0]      mem_resp_o
  ,output logic                                  mem_resp_v_o
  ,input  logic                                  mem_resp_ready_i
                                                 
  ,output logic [mem_cce_data_resp_width_lp-1:0] mem_data_resp_o
  ,output logic                                  mem_data_resp_v_o
  ,input  logic                                  mem_data_resp_ready_i
  
  // Configuration
  ,input [x_cord_width_p-1:0] my_x_i
  ,input [y_cord_width_p-1:0] my_y_i
  
  ,input [x_cord_width_p-1:0] clint_x_cord_i
  ,input [y_cord_width_p-1:0] clint_y_cord_i
  
  ,input [x_cord_width_p-1:0] dram_x_cord_i
  ,input [y_cord_width_p-1:0] dram_y_cord_i
  
  // Wormhole interface
  ,input wormhole_clk_i
  ,input wormhole_reset_i
  
  ,input  [bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] link_o
  );
  
  localparam lg_fifo_depth_lp = 3;
  
  /************************ Interfacing noc links ***********************/
  
  `declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s link_i_cast, link_o_cast;
    
  assign link_i_cast = link_i;
  assign link_o = link_o_cast;
  
  /************************ Clock Domain Crossing ***********************/

  // CCE side
  bsg_ready_and_link_sif_s cce_link_li, cce_link_lo;
  
  logic cce_async_fifo_full_lo, cce_async_fifo_deq_li, cce_async_fifo_enq_li;
  
  assign cce_link_li.ready_and_rev = ~cce_async_fifo_full_lo;
  assign cce_async_fifo_deq_li = cce_link_li.v & cce_link_lo.ready_and_rev;
  assign cce_async_fifo_enq_li = cce_link_lo.v & cce_link_li.ready_and_rev;
  
  // Wormhole side
  logic wh_async_fifo_full_lo, wh_async_fifo_enq_li, wh_async_fifo_deq_li;
  
  assign link_o_cast.ready_and_rev = ~wh_async_fifo_full_lo;
  assign wh_async_fifo_enq_li = link_i_cast.v & link_o_cast.ready_and_rev;
  assign wh_async_fifo_deq_li = link_o_cast.v & link_i_cast.ready_and_rev;
  
  // Cross from wormhole clock to CCE clock
  bsg_async_fifo
 #(.lg_size_p(lg_fifo_depth_lp)
  ,.width_p  (noc_width_p)
  ) wh_to_mc
  (.w_clk_i  (wormhole_clk_i)
  ,.w_reset_i(wormhole_reset_i)
  ,.w_enq_i  (wh_async_fifo_enq_li)
  ,.w_data_i (link_i_cast.data)
  ,.w_full_o (wh_async_fifo_full_lo)

  ,.r_clk_i  (clk_i)
  ,.r_reset_i(reset_i)
  ,.r_deq_i  (cce_async_fifo_deq_li)
  ,.r_data_o (cce_link_li.data)
  ,.r_valid_o(cce_link_li.v)
  );
  
  // Cross from CCE clock to Wormhole clock
  bsg_async_fifo
 #(.lg_size_p(lg_fifo_depth_lp)
  ,.width_p  (noc_width_p)
  ) mc_to_wh
  (.w_clk_i  (clk_i)
  ,.w_reset_i(reset_i)
  ,.w_enq_i  (cce_async_fifo_enq_li)
  ,.w_data_i (cce_link_lo.data)
  ,.w_full_o (cce_async_fifo_full_lo)

  ,.r_clk_i  (wormhole_clk_i)
  ,.r_reset_i(wormhole_reset_i)
  ,.r_deq_i  (wh_async_fifo_deq_li)
  ,.r_data_o (link_o_cast.data)
  ,.r_valid_o(link_o_cast.v)
  );
  
  /************************ Address Map ***********************/
  
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp);
  
  bp_cce_mem_cmd_s      mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;
  
  assign mem_cmd      = mem_cmd_i;
  assign mem_data_cmd = mem_data_cmd_i;
  
  logic [x_cord_width_p-1:0] mem_cmd_dest_x, mem_data_cmd_dest_x;
  logic [y_cord_width_p-1:0] mem_cmd_dest_y, mem_data_cmd_dest_y;
  
  bp_addr_map
 #(.cfg_p         (cfg_p)
  ,.x_cord_width_p(x_cord_width_p)
  ,.y_cord_width_p(y_cord_width_p)
  )
  cmd_map
  (.paddr_i (mem_cmd.addr)
  ,.clint_x_cord_i
  ,.clint_y_cord_i
  ,.dram_x_cord_i
  ,.dram_y_cord_i
  ,.dest_x_o(mem_cmd_dest_x)
  ,.dest_y_o(mem_cmd_dest_y)
  );
    
  bp_addr_map
 #(.cfg_p         (cfg_p)
  ,.x_cord_width_p(x_cord_width_p)
  ,.y_cord_width_p(y_cord_width_p)
  )
  data_cmd_map
  (.paddr_i (mem_data_cmd.addr)
  ,.clint_x_cord_i
  ,.clint_y_cord_i
  ,.dram_x_cord_i
  ,.dram_y_cord_i
  ,.dest_x_o(mem_data_cmd_dest_x)
  ,.dest_y_o(mem_data_cmd_dest_y)
  );
  
  /************************ Master Link ***********************/
  
  bp_me_cce_to_wormhole_link_master
 #(.cfg_p(cfg_p)
  ,.x_cord_width_p(x_cord_width_p)
  ,.y_cord_width_p(y_cord_width_p)
  )
  mlink
  (.clk_i
  ,.reset_i

  ,.mem_cmd_i
  ,.mem_cmd_v_i
  ,.mem_cmd_yumi_o

  ,.mem_data_cmd_i
  ,.mem_data_cmd_v_i
  ,.mem_data_cmd_yumi_o

  ,.mem_resp_o
  ,.mem_resp_v_o
  ,.mem_resp_ready_i

  ,.mem_data_resp_o
  ,.mem_data_resp_v_o
  ,.mem_data_resp_ready_i
  
  ,.my_x_i
  ,.my_y_i
  
  ,.mem_cmd_dest_x_i     (mem_cmd_dest_x)
  ,.mem_cmd_dest_y_i     (mem_cmd_dest_y)
  
  ,.mem_data_cmd_dest_x_i(mem_data_cmd_dest_x)
  ,.mem_data_cmd_dest_y_i(mem_data_cmd_dest_y)
  
  ,.link_i               (cce_link_li)
  ,.link_o               (cce_link_lo)
  );
  

endmodule
