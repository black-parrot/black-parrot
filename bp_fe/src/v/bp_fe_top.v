/*                                  
 * bp_fe_top.v 
 */

module bp_fe_top
 import bp_fe_pkg::*;
 import bp_fe_icache_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_fe_tag_widths(lce_assoc_p, lce_sets_p, lce_id_width_p, cce_id_width_p, dword_width_p, paddr_width_p)
   //`declare_bp_fe_lce_widths(lce_assoc_p, lce_sets_p, ptag_width_p, cce_block_width_p)
   `declare_bp_cache_if_widths(lce_assoc_p, lce_sets_p, ptag_width_p, cce_block_width_p)
   `declare_bp_cache_miss_widths(cce_block_width_p, lce_assoc_p, paddr_width_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   , input [fe_cmd_width_lp-1:0]                      fe_cmd_i
   , input                                            fe_cmd_v_i
   , output                                           fe_cmd_yumi_o

   , output [fe_queue_width_lp-1:0]                   fe_queue_o
   , output                                           fe_queue_v_o
   , input                                            fe_queue_ready_i

   // Interface to LCE

   , input                                            lce_ready_i

   , output [bp_cache_miss_width_lp-1:0]              cache_miss_o
   , output                                           cache_miss_v_o
   , input                                            cache_miss_ready_i

   , output logic [cce_block_width_p-1:0]             data_mem_data_o
   , input [bp_cache_data_mem_pkt_width_lp-1:0]       data_mem_pkt_i
   , input                                            data_mem_pkt_v_i
   , output logic                                     data_mem_pkt_yumi_o

   , input [bp_cache_tag_mem_pkt_width_lp-1:0]        tag_mem_pkt_i
   , input                                            tag_mem_pkt_v_i
   , output logic                                     tag_mem_pkt_yumi_o

   , input                                            stat_mem_pkt_v_i
   , input [bp_cache_stat_mem_pkt_width_lp-1:0]       stat_mem_pkt_i
   , output logic                                     stat_mem_pkt_yumi_o
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_fe_mem_structs(vaddr_width_p, lce_sets_p, cce_block_width_p, vtag_width_p, ptag_width_p)
   
bp_fe_mem_cmd_s  mem_cmd_lo;
logic            mem_cmd_v_lo, mem_cmd_yumi_li;
logic [rv64_priv_width_gp-1:0]  mem_priv_lo;
logic            mem_poison_lo, mem_translation_en_lo;
bp_fe_mem_resp_s mem_resp_li;
logic            mem_resp_v_li, mem_resp_ready_lo;

bp_fe_pc_gen 
 #(.bp_params_p(bp_params_p)) 
 pc_gen
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
               
   ,.mem_cmd_o(mem_cmd_lo)
   ,.mem_cmd_v_o(mem_cmd_v_lo)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_li)

   ,.mem_priv_o(mem_priv_lo)
   ,.mem_translation_en_o(mem_translation_en_lo)
   ,.mem_poison_o(mem_poison_lo)

   ,.mem_resp_i(mem_resp_li)
   ,.mem_resp_v_i(mem_resp_v_li)
   ,.mem_resp_ready_o(mem_resp_ready_lo)

   ,.fe_cmd_i(fe_cmd_i)
   ,.fe_cmd_v_i(fe_cmd_v_i)
   ,.fe_cmd_yumi_o(fe_cmd_yumi_o)

   ,.fe_queue_o(fe_queue_o)
   ,.fe_queue_v_o(fe_queue_v_o)
   ,.fe_queue_ready_i(fe_queue_ready_i)
   );

bp_fe_mem
 #(.bp_params_p(bp_params_p))
 mem
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.cfg_bus_i(cfg_bus_i)
   
   ,.mem_cmd_i(mem_cmd_lo)
   ,.mem_cmd_v_i(mem_cmd_v_lo)
   ,.mem_cmd_yumi_o(mem_cmd_yumi_li)

   ,.mem_priv_i(mem_priv_lo)
   ,.mem_translation_en_i(mem_translation_en_lo)
   ,.mem_poison_i(mem_poison_lo)

   ,.mem_resp_o(mem_resp_li)
   ,.mem_resp_v_o(mem_resp_v_li)
   ,.mem_resp_ready_i(mem_resp_ready_lo)

   ,.lce_ready_i(lce_ready_i)
   ,.cache_miss_o(cache_miss_o)
   ,.cache_miss_v_o(cache_miss_v_o)
   ,.cache_miss_ready_i(cache_miss_ready_i)

   ,.data_mem_data_o(data_mem_data_o)
   ,.data_mem_pkt_i(data_mem_pkt_i)
   ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
   ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)

   ,.tag_mem_pkt_i(tag_mem_pkt_i)
   ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
   ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)

   ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
   ,.stat_mem_pkt_i(stat_mem_pkt_i)
   ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
   );

endmodule

