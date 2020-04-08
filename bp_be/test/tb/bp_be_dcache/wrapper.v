/**
 *
 * wrapper.v
 *
 */
 
module wrapper
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_me_pkg::*;
 import bp_cce_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)

   , parameter writethrough_p=0
   , parameter debug_p=0
   , parameter lock_max_limit_p=8

   , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam block_size_in_words_lp=dcache_assoc_p
   , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp=(bank_width_lp>>3)
   , localparam bypass_data_width_lp = (dword_width_p >> 3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(dcache_sets_p)
   , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(dcache_assoc_p)

   , localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(page_offset_width_p,dword_width_p)
   , localparam tag_info_width_lp=`bp_be_dcache_tag_info_width(ptag_width_lp)
   , localparam stat_info_width_lp=`bp_cache_stat_info_width(dcache_assoc_p)
   )
   ( input                                             clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   , input [dcache_pkt_width_lp-1:0]                   dcache_pkt_i
   , input                                             v_i
   , output logic                                      ready_o

   , output logic [dword_width_p-1:0]                  data_o
   , output logic                                      v_o

   , input [ptag_width_lp-1:0]                         ptag_i

   , input                                             uncached_i

   , input                                             mem_resp_v_i
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , output logic                                      mem_resp_ready_o

   , output logic                                      mem_cmd_v_o
   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , input                                             mem_cmd_yumi_i
   );

   `declare_bp_be_dcache_pkt_s(page_offset_width_p, dword_width_p);

   // Cache to Rolly FIFO signals
   logic dcache_miss_lo, dcache_ready_lo;
   logic rollback_li;
   logic [ptag_width_lp-1:0] rolly_ptag_lo;
   logic rolly_uncached_lo;
   bp_be_dcache_pkt_s rolly_dcache_pkt_lo;
   logic rolly_v_lo, rolly_yumi_li;

   // D$ - LCE Interface signals
   // Miss, Management Interfaces
   logic cache_req_v_lo, cache_req_metadata_v_lo;
   logic cache_req_ready_lo;
   logic cache_req_complete_lo;
   logic [dcache_req_width_lp-1:0] cache_req_lo;
   logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_lo;

   // Fill Interface
   logic data_mem_pkt_v_lo, tag_mem_pkt_v_lo, stat_mem_pkt_v_lo;
   logic data_mem_pkt_ready_lo, tag_mem_pkt_ready_lo, stat_mem_pkt_ready_lo;
   logic [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_lo;
   logic [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_lo;
   logic [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_lo;
   logic [cce_block_width_p-1:0] data_mem_lo;
   logic [ptag_width_lp-1:0] tag_mem_lo;
   logic [stat_info_width_lp-1:0] stat_mem_lo;

   // LCE - CCE Interface
   logic lce_req_v_lo, lce_resp_v_lo;
   logic lce_req_ready_lo, lce_resp_ready_lo;
   logic fifo_lce_cmd_v_lo, fifo_lce_cmd_yumi_li, lce_cmd_v_lo, lce_cmd_ready_li;  
   logic [lce_cce_req_width_lp-1:0] lce_req_lo;
   logic [lce_cmd_width_lp-1:0] lce_cmd_lo, fifo_lce_cmd_lo;
   logic [lce_cce_resp_width_lp-1:0] lce_resp_lo;

   // Credits
   logic credits_full_lo, credits_empty_lo;
  
   bsg_fifo_1r1w_rolly
   #(.width_p(dcache_pkt_width_lp+ptag_width_lp+1)
    ,.els_p(8))
    rolly 
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.roll_v_i(rollback_li)
    ,.clr_v_i(1'b0)
    ,.deq_v_i(v_o)
    
    ,.data_i({uncached_i, ptag_i, dcache_pkt_i})
    ,.v_i(v_i)
    ,.ready_o(ready_o)
    
    ,.data_o({rolly_uncached_lo, rolly_ptag_lo, rolly_dcache_pkt_lo})
    ,.v_o(rolly_v_lo)
    ,.yumi_i(rolly_yumi_li)
    );
  
   assign rollback_li = dcache_miss_lo;
   assign rolly_yumi_li = rolly_v_lo & dcache_ready_lo;
  
   logic [ptag_width_lp-1:0] rolly_ptag_r;
   bsg_dff_reset
    #(.width_p(ptag_width_lp)
     ,.reset_val_p(0)
    )
    ptag_dff
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(rolly_ptag_lo)
    ,.data_o(rolly_ptag_r)
    );

   logic dcache_v_rr, poison_li;
   bsg_dff_chain
    #(.width_p(1)
     ,.num_stages_p(2)
    )
    dcache_v_reg
    (.clk_i(clk_i)
    ,.data_i(rolly_yumi_li)
    ,.data_o(dcache_v_rr)
    );

   assign poison_li = dcache_v_rr & ~v_o;
   
   logic uncached_r;
   bsg_dff_reset
   #(.width_p(1)
    ,.reset_val_p(0)
   )
   uncached_reg
   (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(rolly_uncached_lo)
   ,.data_o(uncached_r)
   );
  
   bp_be_dcache
   #(.bp_params_p(bp_params_p))
   dcache
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.cfg_bus_i(cfg_bus_i)
   
   ,.dcache_pkt_i(rolly_dcache_pkt_lo)
   ,.v_i(rolly_v_lo)
   ,.ready_o(dcache_ready_lo)

   ,.data_o(data_o)
   ,.v_o(v_o)
   ,.fencei_v_o()

   ,.tlb_miss_i(1'b0)
   ,.ptag_i(rolly_ptag_r)
   ,.uncached_i(uncached_r)

   ,.poison_i(poison_li)

   ,.load_op_tl_o()
   ,.store_op_tl_o()

   ,.dcache_miss_o(dcache_miss_lo)
    
   ,.cache_req_v_o(cache_req_v_lo)
   ,.cache_req_o(cache_req_lo)
   ,.cache_req_metadata_o(cache_req_metadata_lo)
   ,.cache_req_metadata_v_o(cache_req_metadata_v_lo)
   ,.cache_req_ready_i(cache_req_ready_lo)
   ,.cache_req_complete_i(cache_req_complete_lo)

   ,.data_mem_pkt_v_i(data_mem_pkt_v_lo)
   ,.data_mem_pkt_i(data_mem_pkt_lo)
   ,.data_mem_o(data_mem_lo)
   ,.data_mem_pkt_ready_o(data_mem_pkt_ready_lo)

   ,.tag_mem_pkt_v_i(tag_mem_pkt_v_lo)
   ,.tag_mem_pkt_i(tag_mem_pkt_lo)
   ,.tag_mem_o(tag_mem_lo)
   ,.tag_mem_pkt_ready_o(tag_mem_pkt_ready_lo)

   ,.stat_mem_pkt_v_i(stat_mem_pkt_v_lo)
   ,.stat_mem_pkt_i(stat_mem_pkt_lo)
   ,.stat_mem_o(stat_mem_lo)
   ,.stat_mem_pkt_ready_o(stat_mem_pkt_ready_lo)
   );

   bp_be_dcache_lce
   #(.bp_params_p(bp_params_p))
   dcache_lce
   (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.lce_id_i('0)

   ,.cache_req_i(cache_req_lo)
   ,.cache_req_v_i(cache_req_v_lo)
   ,.cache_req_ready_o(cache_req_ready_lo)
   ,.cache_req_metadata_i(cache_req_metadata_lo)
   ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)

   ,.cache_req_complete_o(cache_req_complete_lo)

   ,.data_mem_pkt_v_o(data_mem_pkt_v_lo)
   ,.data_mem_pkt_o(data_mem_pkt_lo)
   ,.data_mem_i(data_mem_lo)
   ,.data_mem_pkt_ready_i(data_mem_pkt_ready_lo)

   ,.tag_mem_pkt_v_o(tag_mem_pkt_v_lo)
   ,.tag_mem_pkt_o(tag_mem_pkt_lo)
   ,.tag_mem_i(tag_mem_lo)
   ,.tag_mem_pkt_ready_i(tag_mem_pkt_ready_lo)

   ,.stat_mem_pkt_v_o(stat_mem_pkt_v_lo)
   ,.stat_mem_pkt_o(stat_mem_pkt_lo)
   ,.stat_mem_i(stat_mem_lo)
   ,.stat_mem_pkt_ready_i(stat_mem_pkt_ready_lo)
    
   ,.lce_req_o(lce_req_lo)
   ,.lce_req_v_o(lce_req_v_lo)
   ,.lce_req_ready_i(lce_req_ready_lo)

   ,.lce_resp_o(lce_resp_lo)
   ,.lce_resp_v_o(lce_resp_v_lo)
   ,.lce_resp_ready_i(lce_resp_ready_lo)
   
   ,.lce_cmd_i(fifo_lce_cmd_lo)
   ,.lce_cmd_v_i(fifo_lce_cmd_v_lo)
   ,.lce_cmd_yumi_o(fifo_lce_cmd_yumi_li)

   ,.lce_cmd_o()
   ,.lce_cmd_v_o()
   ,.lce_cmd_ready_i()

   ,.credits_full_o(credits_full_lo)
   ,.credits_empty_o(credits_empty_lo)
   );

   // lce_cmd demanding -> demanding handshake conversion
   bsg_two_fifo 
     #(.width_p(lce_cmd_width_lp))
     cmd_fifo 
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // from CCE
     ,.v_i(lce_cmd_v_lo)
     ,.ready_o(lce_cmd_ready_li)
     ,.data_i(lce_cmd_lo)

     // to LCE
     ,.v_o(fifo_lce_cmd_v_lo)
     ,.yumi_i(fifo_lce_cmd_yumi_li)
     ,.data_o(fifo_lce_cmd_lo)
   );

   bp_cce_fsm_top
   #(.bp_params_p(bp_params_p))
   cce_top
   (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)
   ,.cfg_cce_ucode_data_o()

   ,.lce_req_i(lce_req_lo)
   ,.lce_req_v_i(lce_req_v_lo)
   ,.lce_req_ready_o(lce_req_ready_lo)

   ,.lce_resp_i(lce_resp_lo)
   ,.lce_resp_v_i(lce_resp_v_lo)
   ,.lce_resp_ready_o(lce_resp_ready_lo)

   ,.lce_cmd_o(lce_cmd_lo)
   ,.lce_cmd_v_o(lce_cmd_v_lo)
   ,.lce_cmd_ready_i(lce_cmd_ready_li)

   ,.mem_resp_i(mem_resp_i)
   ,.mem_resp_v_i(mem_resp_v_i)
   ,.mem_resp_ready_o(mem_resp_ready_o)

   ,.mem_cmd_o(mem_cmd_o)
   ,.mem_cmd_v_o(mem_cmd_v_o)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_i)
   );

endmodule
