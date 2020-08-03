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
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  ,parameter uce_p = 1
  ,parameter wt_p = 1
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache)

   , parameter debug_p=0
   , parameter lock_max_limit_p=8

   , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam block_size_in_words_lp=dcache_assoc_p
   , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(dcache_assoc_p)

   , localparam wg_per_cce_lp = (lce_sets_p / num_cce_p)

   , localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(page_offset_width_p,dpath_width_p)
   , localparam tag_info_width_lp=`bp_be_dcache_tag_info_width(ptag_width_lp)
   )
   ( input                                             clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   , input [dcache_pkt_width_lp-1:0]                   dcache_pkt_i
   , input                                             v_i
   , output logic                                      ready_o

   , input [ptag_width_lp-1:0]                         ptag_i
   , input                                             uncached_i

   , output logic [dword_width_p-1:0]                  data_o
   , output logic                                      v_o

   , input                                             mem_resp_v_i
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , output logic                                      mem_resp_yumi_o

   , output logic                                      mem_cmd_v_o
   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , input                                             mem_cmd_ready_i
   );

   `declare_bp_be_dcache_pkt_s(page_offset_width_p, dpath_width_p);

   // Cache to Rolly FIFO signals
   logic dcache_ready_lo;
   logic rollback_li;
   logic [ptag_width_lp-1:0] rolly_ptag_lo;
   logic rolly_uncached_lo;
   bp_be_dcache_pkt_s rolly_dcache_pkt_lo;
   logic rolly_v_lo, rolly_yumi_li;

   // D$ - LCE Interface signals
   // Miss, Management Interfaces
   logic cache_req_v_lo, cache_req_metadata_v_lo;
   logic cache_req_ready_lo;
   logic cache_req_complete_lo, cache_req_critical_lo;
   logic [dcache_req_width_lp-1:0] cache_req_lo;
   logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_lo;

   // Fill Interface
   logic data_mem_pkt_v_lo, tag_mem_pkt_v_lo, stat_mem_pkt_v_lo;
   logic data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
   logic [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_lo;
   logic [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_lo;
   logic [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_lo;
   logic [dcache_block_width_p-1:0] data_mem_lo;
   logic [ptag_width_lp-1:0] tag_mem_lo;
   logic [dcache_stat_info_width_lp-1:0] stat_mem_lo;

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
   assign rolly_yumi_li = rolly_v_lo & dcache_ready_lo;

   logic [ptag_width_lp-1:0] rolly_ptag_r;
   logic rolly_uncached_r;
   bsg_dff_reset
    #(.width_p(1+ptag_width_lp)
     ,.reset_val_p(0)
    )
    ptag_dff
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i({rolly_uncached_lo, rolly_ptag_lo})
    ,.data_o({rolly_uncached_r, rolly_ptag_r})
    );

   wire is_store = rolly_dcache_pkt_lo.opcode inside {e_dcache_op_sb, e_dcache_op_sh, e_dcache_op_sw, e_dcache_op_sd};

   logic is_store_rr, dcache_v_rr, poison_li;
   bsg_dff_chain
    #(.width_p(2)
     ,.num_stages_p(2)
    )
    dcache_v_reg
    (.clk_i(clk_i)
    ,.data_i({is_store, rolly_yumi_li})
    ,.data_o({is_store_rr, dcache_v_rr})
    );

   assign poison_li = dcache_v_rr & ~v_o;
   assign rollback_li = poison_li;

   logic [dpath_width_p-1:0] early_data_lo;
   logic early_v_lo;
   logic [dpath_width_p-1:0] final_data_lo;
   logic final_v_lo;

   bp_be_dcache
   #(.bp_params_p(bp_params_p)
     ,.writethrough_p(wt_p)
     )
   dcache
   (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)

   ,.dcache_pkt_i(rolly_dcache_pkt_lo)
   ,.v_i(rolly_yumi_li)
   ,.ready_o(dcache_ready_lo)

   ,.early_data_o(early_data_lo)
   ,.early_v_o(early_v_lo)
   ,.final_data_o(final_data_lo)
   ,.final_v_o(final_v_lo)

   ,.ptag_v_i(1'b1)
   ,.ptag_i(rolly_ptag_r)
   ,.uncached_i(rolly_uncached_r)

   ,.flush_i(poison_li)

   ,.cache_req_v_o(cache_req_v_lo)
   ,.cache_req_o(cache_req_lo)
   ,.cache_req_metadata_o(cache_req_metadata_lo)
   ,.cache_req_metadata_v_o(cache_req_metadata_v_lo)
   ,.cache_req_ready_i(cache_req_ready_lo)
   ,.cache_req_complete_i(cache_req_complete_lo)
   ,.cache_req_critical_i(cache_req_critical_lo)

   ,.data_mem_pkt_v_i(data_mem_pkt_v_lo)
   ,.data_mem_pkt_i(data_mem_pkt_lo)
   ,.data_mem_o(data_mem_lo)
   ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo)

   ,.tag_mem_pkt_v_i(tag_mem_pkt_v_lo)
   ,.tag_mem_pkt_i(tag_mem_pkt_lo)
   ,.tag_mem_o(tag_mem_lo)
   ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo)

   ,.stat_mem_pkt_v_i(stat_mem_pkt_v_lo)
   ,.stat_mem_pkt_i(stat_mem_pkt_lo)
   ,.stat_mem_o(stat_mem_lo)
   ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo)
   );

   // Stores "return" 0 to the trace replay module
   assign data_o = is_store_rr ? '0 : final_data_lo;
   assign v_o = final_v_lo;

   if(uce_p == 0) begin : cce
     logic lce_req_v_lo, lce_resp_v_lo;
     logic lce_req_ready_lo, lce_resp_ready_lo;
     logic fifo_lce_cmd_v_lo, fifo_lce_cmd_yumi_li, lce_cmd_v_lo, lce_cmd_ready_li;
     logic [lce_cce_req_width_lp-1:0] lce_req_lo;
     logic [lce_cmd_width_lp-1:0] lce_cmd_lo, fifo_lce_cmd_lo;
     logic [lce_cce_resp_width_lp-1:0] lce_resp_lo;

     logic mem_resp_ready_lo;

     `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
     bp_cfg_bus_s cfg_bus_cast_i;
     assign cfg_bus_cast_i = cfg_bus_i;

     bp_lce
     #(.bp_params_p(bp_params_p)
        ,.assoc_p(dcache_assoc_p)
        ,.sets_p(dcache_sets_p)
        ,.block_width_p(dcache_block_width_p)
        ,.timeout_max_limit_p(4)
        ,.credits_p(coh_noc_max_credits_p)
        ,.data_mem_invert_clk_p(1)
        ,.tag_mem_invert_clk_p(1)
       )
     dcache_lce
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(cfg_bus_cast_i.dcache_id)
     ,.lce_mode_i(cfg_bus_cast_i.dcache_mode)

     ,.cache_req_i(cache_req_lo)
     ,.cache_req_v_i(cache_req_v_lo)
     ,.cache_req_ready_o(cache_req_ready_lo)
     ,.cache_req_metadata_i(cache_req_metadata_lo)
     ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)

     ,.cache_req_complete_o(cache_req_complete_lo)
     ,.cache_req_critical_o(cache_req_critical_lo)

     ,.data_mem_pkt_v_o(data_mem_pkt_v_lo)
     ,.data_mem_pkt_o(data_mem_pkt_lo)
     ,.data_mem_i(data_mem_lo)
     ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)

     ,.tag_mem_pkt_v_o(tag_mem_pkt_v_lo)
     ,.tag_mem_pkt_o(tag_mem_pkt_lo)
     ,.tag_mem_i(tag_mem_lo)
     ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)

     ,.stat_mem_pkt_v_o(stat_mem_pkt_v_lo)
     ,.stat_mem_pkt_o(stat_mem_pkt_lo)
     ,.stat_mem_i(stat_mem_lo)
     ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)

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
     ,.lce_cmd_ready_i(1'b1)

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
     cce
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

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
     ,.mem_resp_ready_o(mem_resp_ready_lo)

     ,.mem_cmd_o(mem_cmd_o)
     ,.mem_cmd_v_o(mem_cmd_v_o)
     ,.mem_cmd_yumi_i(mem_cmd_ready_i & mem_cmd_v_o)
     );

     assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
  end
  else begin : uce
    logic fifo_mem_resp_v_lo, fifo_mem_cmd_v_lo;
    logic fifo_mem_resp_yumi_li;
    logic [cce_mem_msg_width_lp-1:0] fifo_mem_resp_lo, fifo_mem_cmd_lo;
    logic mem_resp_ready_lo, fifo_mem_cmd_ready_li;

    bp_uce
    #(.bp_params_p(bp_params_p)
     ,.assoc_p(dcache_assoc_p)
     ,.sets_p(dcache_sets_p)
     ,.block_width_p(dcache_block_width_p)
     ,.data_mem_invert_clk_p(1)
     ,.tag_mem_invert_clk_p(1)
     )
     dcache_uce
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i('0)

     ,.cache_req_i(cache_req_lo)
     ,.cache_req_v_i(cache_req_v_lo)
     ,.cache_req_ready_o(cache_req_ready_lo)
     ,.cache_req_metadata_i(cache_req_metadata_lo)
     ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)

     ,.cache_req_complete_o(cache_req_complete_lo)
     ,.cache_req_critical_o(cache_req_critical_lo)

     ,.tag_mem_pkt_o(tag_mem_pkt_lo)
     ,.tag_mem_pkt_v_o(tag_mem_pkt_v_lo)
     ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)
     ,.tag_mem_i(tag_mem_lo)

     ,.data_mem_pkt_o(data_mem_pkt_lo)
     ,.data_mem_pkt_v_o(data_mem_pkt_v_lo)
     ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)
     ,.data_mem_i(data_mem_lo)

     ,.stat_mem_pkt_o(stat_mem_pkt_lo)
     ,.stat_mem_pkt_v_o(stat_mem_pkt_v_lo)
     ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(stat_mem_lo)

     ,.credits_full_o(credits_full_lo)
     ,.credits_empty_o(credits_empty_lo)

     ,.mem_cmd_o(fifo_mem_cmd_lo)
     ,.mem_cmd_v_o(fifo_mem_cmd_v_lo)
     ,.mem_cmd_ready_i(fifo_mem_cmd_ready_li)

     ,.mem_resp_i(mem_resp_i)
     ,.mem_resp_v_i(mem_resp_v_i)
     ,.mem_resp_yumi_o(mem_resp_yumi_o)
     );

    // We need a mem cmd fifo because we need to buffer the wt stores to
    // memory since we don't raise a miss for these stores.
    // Update: This is useful even on writebacks to successively allow the
    // read request and hold the following writeback request
    bsg_two_fifo
      #(.width_p(cce_mem_msg_width_lp))
      mem_cmd_fifo
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.v_i(fifo_mem_cmd_v_lo)
      ,.data_i(fifo_mem_cmd_lo)
      ,.ready_o(fifo_mem_cmd_ready_li)

      ,.v_o(mem_cmd_v_o)
      ,.data_o(mem_cmd_o)
      ,.yumi_i(mem_cmd_v_o & mem_cmd_ready_i)
      );

   end

endmodule
