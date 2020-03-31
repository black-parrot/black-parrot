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
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache)
   
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam block_size_in_words_lp=icache_assoc_p
   , localparam bank_width_lp = icache_block_width_p / icache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp=(bank_width_lp >> 3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp >> 3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(icache_sets_p)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
   
   , localparam stat_width_lp = `bp_cache_stat_info_width(icache_assoc_p)

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

   , output logic [icache_req_width_lp-1:0]           cache_req_o
   , output logic                                     cache_req_v_o
   , input                                            cache_req_ready_i
   , output logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o
   , output logic                                     cache_req_metadata_v_o
 
   , input                                            cache_req_complete_i

   , input [icache_data_mem_pkt_width_lp-1:0]         data_mem_pkt_i
   , input                                            data_mem_pkt_v_i
   , output logic                                     data_mem_pkt_ready_o
   , output logic [icache_block_width_p-1:0]          data_mem_o

   , input [icache_tag_mem_pkt_width_lp-1:0]          tag_mem_pkt_i
   , input                                            tag_mem_pkt_v_i
   , output logic                                     tag_mem_pkt_ready_o
   , output logic [ptag_width_lp-1:0]                 tag_mem_o

   , input [icache_stat_mem_pkt_width_lp-1:0]         stat_mem_pkt_i
   , input                                            stat_mem_pkt_v_i
   , output logic                                     stat_mem_pkt_ready_o
   , output logic [stat_width_lp-1:0]                 stat_mem_o
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_fe_mem_structs(vaddr_width_p, icache_sets_p, icache_block_width_p, vtag_width_p, ptag_width_p)
   
bp_fe_mem_cmd_s  mem_cmd_lo;
logic            mem_cmd_v_lo, mem_cmd_yumi_li;
logic [rv64_priv_width_gp-1:0]  mem_priv_lo;
logic            mem_poison_lo, mem_translation_en_lo;
bp_fe_mem_resp_s mem_resp_li;
logic            mem_resp_v_li;

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

   ,.cache_req_o(cache_req_o)
   ,.cache_req_v_o(cache_req_v_o)
   ,.cache_req_ready_i(cache_req_ready_i)
   ,.cache_req_metadata_o(cache_req_metadata_o)
   ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

   ,.cache_req_complete_i(cache_req_complete_i)

   ,.data_mem_pkt_i(data_mem_pkt_i)
   ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
   ,.data_mem_pkt_ready_o(data_mem_pkt_ready_o)
   ,.data_mem_o(data_mem_o)

   ,.tag_mem_pkt_i(tag_mem_pkt_i)
   ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
   ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_o)
   ,.tag_mem_o(tag_mem_o)

   ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
   ,.stat_mem_pkt_i(stat_mem_pkt_i)
   ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_o)
   ,.stat_mem_o(stat_mem_o)
   );

endmodule

