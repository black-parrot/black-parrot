/**
 *
 * wrapper.sv
 *
 */

module wrapper
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter uce_p = 1
   , parameter num_caches_p = 1
   , parameter wt_p = 1
   , parameter sets_p = dcache_sets_p
   , parameter assoc_p = dcache_assoc_p
   , parameter block_width_p = dcache_block_width_p
   , parameter fill_width_p = dcache_fill_width_p
   , parameter id_width_p = dcache_req_id_width_p
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   `declare_bp_cache_engine_generic_if_widths(paddr_width_p, dcache_tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p, dcache)

   , parameter debug_p=0
   , parameter lock_max_limit_p=8

   , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)

   , localparam dcache_pkt_width_lp = $bits(bp_be_dcache_pkt_s)

   , localparam lg_num_lce_lp = `BSG_SAFE_CLOG2(num_lce_p)
   )
   ( input                                             clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   , input [num_caches_p-1:0][dcache_pkt_width_lp-1:0] dcache_pkt_i
   , input [num_caches_p-1:0]                          v_i
   , output logic [num_caches_p-1:0]                   ready_o

   , input [num_caches_p-1:0][ptag_width_p-1:0]        ptag_i
   , input [num_caches_p-1:0]                          uncached_i
   , input [num_caches_p-1:0][dword_width_gp-1:0]      st_data_i

   , output logic [num_caches_p-1:0][dword_width_gp-1:0] data_o
   , output logic [num_caches_p-1:0]                     v_o

   , output logic [mem_fwd_header_width_lp-1:0]        mem_fwd_header_o
   , output logic [l2_data_width_p-1:0]                mem_fwd_data_o
   , output logic                                      mem_fwd_v_o
   , input                                             mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]               mem_rev_header_i
   , input [l2_data_width_p-1:0]                       mem_rev_data_i
   , input                                             mem_rev_v_i
   , output logic                                      mem_rev_ready_and_o
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // Cache to Rolly FIFO signals
  logic [num_caches_p-1:0] dcache_busy_lo;
  logic [num_caches_p-1:0] rollback_li;
  logic [num_caches_p-1:0] rolly_uncached_lo;
  logic [num_caches_p-1:0] rolly_v_lo, rolly_yumi_li;
  bp_be_dcache_pkt_s [num_caches_p-1:0] rolly_dcache_pkt_lo;
  logic [num_caches_p-1:0][ptag_width_p-1:0] rolly_ptag_lo;

  // D$ - LCE Interface signals
  // Miss, Management Interfaces
  logic [num_caches_p-1:0] cache_req_v_lo, cache_req_metadata_v_lo;
  logic [num_caches_p-1:0] cache_req_yumi_lo, cache_req_lock_lo;
  logic [num_caches_p-1:0][dcache_req_id_width_p-1:0] cache_req_id_lo;
  logic [num_caches_p-1:0] cache_req_last_lo, cache_req_critical_lo;
  logic [num_caches_p-1:0][dcache_req_width_lp-1:0] cache_req_lo;
  logic [num_caches_p-1:0][dcache_req_metadata_width_lp-1:0] cache_req_metadata_lo;

  // Fill Interface
  logic [num_caches_p-1:0] data_mem_pkt_v_lo, tag_mem_pkt_v_lo, stat_mem_pkt_v_lo;
  logic [num_caches_p-1:0] data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
  logic [num_caches_p-1:0][dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_lo;
  logic [num_caches_p-1:0][dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_lo;
  logic [num_caches_p-1:0][dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_lo;
  logic [num_caches_p-1:0][block_width_p-1:0] data_mem_lo;
  logic [num_caches_p-1:0][dcache_tag_info_width_lp-1:0] tag_mem_lo;
  logic [num_caches_p-1:0][dcache_stat_info_width_lp-1:0] stat_mem_lo;

  // Credits
  logic [num_caches_p-1:0] cache_req_credits_full_lo, cache_req_credits_empty_lo;

  logic [num_caches_p-1:0][ptag_width_p-1:0] rolly_ptag_r;
  logic [num_caches_p-1:0] rolly_uncached_r;
  logic [num_caches_p-1:0] is_store, is_store_rr, dcache_v_rr;

  // LCE-CCE connections - to/from LCE and xbars
  bp_bedrock_lce_req_header_s [num_caches_p-1:0] lce_req_header_lo;
  logic [num_caches_p-1:0][fill_width_p-1:0] lce_req_data_lo;
  logic [num_caches_p-1:0] lce_req_v_lo, lce_req_ready_and_li;
  wire [num_lce_p-1:0] lce_req_dst = '0;

  bp_bedrock_lce_resp_header_s [num_caches_p-1:0] lce_resp_header_lo;
  logic [num_caches_p-1:0][fill_width_p-1:0] lce_resp_data_lo;
  logic [num_caches_p-1:0] lce_resp_v_lo, lce_resp_ready_and_li;
  wire [num_lce_p-1:0] lce_resp_dst = '0;

  bp_bedrock_lce_cmd_header_s [num_caches_p-1:0] lce_cmd_header_li;
  logic [num_caches_p-1:0][fill_width_p-1:0] lce_cmd_data_li;
  logic [num_caches_p-1:0] lce_cmd_header_v_li, lce_cmd_header_ready_and_lo;
  logic [num_caches_p-1:0] lce_cmd_v_li, lce_cmd_ready_and_lo;

  bp_bedrock_lce_fill_header_s [num_caches_p-1:0] lce_fill_header_li;
  logic [num_caches_p-1:0][fill_width_p-1:0] lce_fill_data_li;
  logic [num_caches_p-1:0] lce_fill_v_li, lce_fill_ready_and_lo;

  bp_bedrock_lce_fill_header_s [num_caches_p-1:0] lce_fill_header_lo;
  logic [num_caches_p-1:0][fill_width_p-1:0] lce_fill_data_lo;
  logic [num_caches_p-1:0] lce_fill_v_lo, lce_fill_ready_and_li;
  logic [num_caches_p-1:0][lg_num_lce_lp-1:0] lce_fill_dst;

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  for (genvar i = 0; i < num_caches_p; i++)
    begin : cache
      bsg_fifo_1r1w_rolly
      #(.width_p(dcache_pkt_width_lp+ptag_width_p+1)
       ,.els_p(8))
       rolly
       (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.roll_v_i(rollback_li[i])
       ,.clr_v_i(1'b0)
       ,.deq_v_i(dcache_v_rr[i])

       ,.data_i({uncached_i[i], ptag_i[i], dcache_pkt_i[i]})
       ,.v_i(v_i[i])
       ,.ready_o(ready_o[i])

       ,.data_o({rolly_uncached_lo[i], rolly_ptag_lo[i], rolly_dcache_pkt_lo[i]})
       ,.v_o(rolly_v_lo[i])
       ,.yumi_i(rolly_yumi_li[i])
       );
      assign rolly_yumi_li[i] = rolly_v_lo[i] & ~dcache_busy_lo[i];

      bsg_dff_reset
       #(.width_p(1+ptag_width_p)
        ,.reset_val_p(0)
       )
       ptag_dff
       (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.data_i({rolly_uncached_lo[i], rolly_ptag_lo[i]})
       ,.data_o({rolly_uncached_r[i], rolly_ptag_r[i]})
       );

      assign is_store[i] = rolly_dcache_pkt_lo[i].opcode inside {e_dcache_op_sb, e_dcache_op_sh, e_dcache_op_sw, e_dcache_op_sd};

      bsg_dff_chain
       #(.width_p(2)
        ,.num_stages_p(2)
       )
       dcache_v_reg
       (.clk_i(clk_i)
       ,.data_i({is_store[i], rolly_yumi_li[i]})
       ,.data_o({is_store_rr[i], dcache_v_rr[i]})
       );

      assign rollback_li[i] = dcache_v_rr[i] & ~v_o[i];

      bp_be_dcache
      #(.bp_params_p(bp_params_p)
        ,.writeback_p(!wt_p)
        ,.sets_p(sets_p)
        ,.assoc_p(assoc_p)
        ,.block_width_p(block_width_p)
        ,.fill_width_p(fill_width_p)
        )
      dcache
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)
      ,.ordered_o()

      ,.dcache_pkt_i(rolly_dcache_pkt_lo[i])
      ,.v_i(rolly_yumi_li[i])
      ,.busy_o(dcache_busy_lo[i])

      ,.ptag_v_i(1'b1)
      ,.ptag_i(rolly_ptag_r[i])
      ,.ptag_uncached_i(rolly_uncached_r[i])
      ,.ptag_dram_i(1'b1)
      ,.st_data_i(st_data_i)

      ,.v_o(v_o[i])
      ,.data_o(data_o[i])
      ,.rd_addr_o()
      ,.int_o()
      ,.float_o()
      ,.ptw_o()
      ,.ret_o()
      ,.late_o()
      ,.tag_o()
      ,.unsigned_o()

      ,.flush_i('0)

      ,.cache_req_v_o(cache_req_v_lo[i])
      ,.cache_req_o(cache_req_lo[i])
      ,.cache_req_metadata_o(cache_req_metadata_lo[i])
      ,.cache_req_metadata_v_o(cache_req_metadata_v_lo[i])
      ,.cache_req_yumi_i(cache_req_yumi_lo[i])
      ,.cache_req_lock_i(cache_req_lock_lo[i])
      ,.cache_req_id_i(cache_req_id_lo[i])
      ,.cache_req_critical_i(cache_req_critical_lo[i])
      ,.cache_req_last_i(cache_req_last_lo[i])
      ,.cache_req_credits_full_i(cache_req_credits_full_lo[i])
      ,.cache_req_credits_empty_i(cache_req_credits_empty_lo[i])

      ,.data_mem_pkt_v_i(data_mem_pkt_v_lo[i])
      ,.data_mem_pkt_i(data_mem_pkt_lo[i])
      ,.data_mem_o(data_mem_lo[i])
      ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo[i])

      ,.tag_mem_pkt_v_i(tag_mem_pkt_v_lo[i])
      ,.tag_mem_pkt_i(tag_mem_pkt_lo[i])
      ,.tag_mem_o(tag_mem_lo[i])
      ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo[i])

      ,.stat_mem_pkt_v_i(stat_mem_pkt_v_lo[i])
      ,.stat_mem_pkt_i(stat_mem_pkt_lo[i])
      ,.stat_mem_o(stat_mem_lo[i])
      ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo[i])
      );

      if (uce_p == 0)
        begin : lce
          bp_lce
           #(.bp_params_p(bp_params_p)
             ,.assoc_p(assoc_p)
             ,.sets_p(sets_p)
             ,.block_width_p(block_width_p)
             ,.fill_width_p(fill_width_p)
             ,.timeout_max_limit_p(4)
             ,.credits_p(coh_noc_max_credits_p)
             ,.tag_width_p(dcache_tag_width_p)
             ,.id_width_p(id_width_p)
             )
           dcache_lce
            (.clk_i(clk_i)
             ,.reset_i(reset_i)

             ,.lce_id_i(lce_id_width_p'(i))
             ,.did_i('0)
             ,.lce_mode_i(cfg_bus_cast_i.dcache_mode)

             ,.cache_req_i(cache_req_lo[i])
             ,.cache_req_v_i(cache_req_v_lo[i])
             ,.cache_req_yumi_o(cache_req_yumi_lo[i])
             ,.cache_req_lock_o(cache_req_lock_lo[i])
             ,.cache_req_metadata_i(cache_req_metadata_lo[i])
             ,.cache_req_metadata_v_i(cache_req_metadata_v_lo[i])
             ,.cache_req_critical_o(cache_req_critical_lo[i])
             ,.cache_req_last_o(cache_req_last_lo[i])
             ,.cache_req_id_o(cache_req_id_lo[i])
             ,.cache_req_credits_full_o(cache_req_credits_full_lo[i])
             ,.cache_req_credits_empty_o(cache_req_credits_empty_lo[i])

             ,.data_mem_pkt_v_o(data_mem_pkt_v_lo[i])
             ,.data_mem_pkt_o(data_mem_pkt_lo[i])
             ,.data_mem_i(data_mem_lo[i])
             ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo[i])

             ,.tag_mem_pkt_v_o(tag_mem_pkt_v_lo[i])
             ,.tag_mem_pkt_o(tag_mem_pkt_lo[i])
             ,.tag_mem_i(tag_mem_lo[i])
             ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo[i])

             ,.stat_mem_pkt_v_o(stat_mem_pkt_v_lo[i])
             ,.stat_mem_pkt_o(stat_mem_pkt_lo[i])
             ,.stat_mem_i(stat_mem_lo[i])
             ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo[i])

             ,.lce_req_header_o(lce_req_header_lo[i])
             ,.lce_req_data_o(lce_req_data_lo[i])
             ,.lce_req_v_o(lce_req_v_lo[i])
             ,.lce_req_ready_and_i(lce_req_ready_and_li[i])

             ,.lce_cmd_header_i(lce_cmd_header_li[i])
             ,.lce_cmd_data_i(lce_cmd_data_li[i])
             ,.lce_cmd_v_i(lce_cmd_v_li[i])
             ,.lce_cmd_ready_and_o(lce_cmd_ready_and_lo[i])

             ,.lce_resp_header_o(lce_resp_header_lo[i])
             ,.lce_resp_data_o(lce_resp_data_lo[i])
             ,.lce_resp_v_o(lce_resp_v_lo[i])
             ,.lce_resp_ready_and_i(lce_resp_ready_and_li[i])

             ,.lce_fill_header_i(lce_fill_header_li[i])
             ,.lce_fill_data_i(lce_fill_data_li[i])
             ,.lce_fill_v_i(lce_fill_v_li[i])
             ,.lce_fill_ready_and_o(lce_fill_ready_and_lo[i])

             ,.lce_fill_header_o(lce_fill_header_lo[i])
             ,.lce_fill_data_o(lce_fill_data_lo[i])
             ,.lce_fill_v_o(lce_fill_v_lo[i])
             ,.lce_fill_ready_and_i(lce_fill_ready_and_li[i])
             );

          // LCE fill destination (LCE to LCE)
          assign lce_fill_dst[i] = lce_fill_header_lo[i].payload.dst_id[0+:lg_num_lce_lp];
        end
      else if (uce_p == 1)
        begin : uce
         bp_uce
          #(.bp_params_p(bp_params_p)
            ,.assoc_p(assoc_p)
            ,.sets_p(sets_p)
            ,.block_width_p(block_width_p)
            ,.fill_width_p(fill_width_p)
            ,.tag_width_p(dcache_tag_width_p)
            ,.id_width_p(id_width_p)
            ,.writeback_p(!wt_p)
            )
          dcache_uce
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.lce_id_i('0)

            ,.cache_req_i(cache_req_lo)
            ,.cache_req_v_i(cache_req_v_lo)
            ,.cache_req_yumi_o(cache_req_yumi_lo)
            ,.cache_req_lock_o(cache_req_lock_lo)
            ,.cache_req_metadata_i(cache_req_metadata_lo)
            ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
            ,.cache_req_critical_o(cache_req_critical_lo)
            ,.cache_req_last_o(cache_req_last_lo)
            ,.cache_req_credits_full_o(cache_req_credits_full_lo)
            ,.cache_req_credits_empty_o(cache_req_credits_empty_lo)

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

            ,.mem_fwd_header_o(mem_fwd_header_o)
            ,.mem_fwd_data_o(mem_fwd_data_o)
            ,.mem_fwd_v_o(mem_fwd_v_o)
            ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)

            ,.mem_rev_header_i(mem_rev_header_i)
            ,.mem_rev_data_i(mem_rev_data_i)
            ,.mem_rev_v_i(mem_rev_v_i)
            ,.mem_rev_ready_and_o(mem_rev_ready_and_o)
            );
       end
    end

  if (uce_p == 0)
    begin : cce

      // LCE-CCE request interface (from xbar to CCE)
      bp_bedrock_lce_req_header_s cce_lce_req_header_li;
      logic [fill_width_p-1:0] cce_lce_req_data_li;
      logic cce_lce_req_v_li, cce_lce_req_ready_and_lo;

      // LCE-CCE response interface (from xbar to CCE)
      bp_bedrock_lce_resp_header_s cce_lce_resp_header_li;
      logic [fill_width_p-1:0] cce_lce_resp_data_li;
      logic cce_lce_resp_v_li, cce_lce_resp_ready_and_lo;

      // LCE-CCE command interface (from CCE to xbar)
      bp_bedrock_lce_cmd_header_s cce_lce_cmd_header_lo;
      logic [fill_width_p-1:0] cce_lce_cmd_data_lo;
      logic cce_lce_cmd_v_lo, cce_lce_cmd_ready_and_li;
      wire [lg_num_lce_lp-1:0] cce_lce_cmd_dst = cce_lce_cmd_header_lo.payload.dst_id[0+:lg_num_lce_lp];

      // Req Crossbar
      bp_me_xbar_stream
       #(.bp_params_p(bp_params_p)
         ,.stream_mask_p(lce_req_stream_mask_gp)
         ,.payload_width_p(lce_req_payload_width_lp)
         ,.num_source_p(num_lce_p)
         ,.num_sink_p(num_cce_p)
         )
       req_xbar
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.msg_header_i(lce_req_header_lo)
         ,.msg_data_i(lce_req_data_lo)
         ,.msg_v_i(lce_req_v_lo)
         ,.msg_ready_and_o(lce_req_ready_and_li)
         ,.msg_dst_i(lce_req_dst)

         ,.msg_header_o(cce_lce_req_header_li)
         ,.msg_data_o(cce_lce_req_data_li)
         ,.msg_v_o(cce_lce_req_v_li)
         ,.msg_ready_and_i(cce_lce_req_ready_and_lo)
         );

      // Resp Crossbar
      bp_me_xbar_stream
       #(.bp_params_p(bp_params_p)
         ,.payload_width_p(lce_resp_payload_width_lp)
         ,.stream_mask_p(lce_resp_stream_mask_gp)
         ,.num_source_p(num_lce_p)
         ,.num_sink_p(num_cce_p)
         )
       rev_xbar
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.msg_header_i(lce_resp_header_lo)
         ,.msg_data_i(lce_resp_data_lo)
         ,.msg_v_i(lce_resp_v_lo)
         ,.msg_ready_and_o(lce_resp_ready_and_li)
         ,.msg_dst_i(lce_resp_dst)

         ,.msg_header_o(cce_lce_resp_header_li)
         ,.msg_data_o(cce_lce_resp_data_li)
         ,.msg_v_o(cce_lce_resp_v_li)
         ,.msg_ready_and_i(cce_lce_resp_ready_and_lo)
         );

      // Fill Crossbar
      // from CCE and LCE cmd out to LCE cmd in
      bp_me_xbar_stream
       #(.bp_params_p(bp_params_p)
         ,.payload_width_p(lce_fill_payload_width_lp)
         ,.stream_mask_p(lce_fill_stream_mask_gp)
         ,.num_source_p(num_lce_p)
         ,.num_sink_p(num_lce_p)
         )
       fill_xbar
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.msg_header_i(lce_fill_header_lo)
         ,.msg_data_i(lce_fill_data_lo)
         ,.msg_v_i(lce_fill_v_lo)
         ,.msg_ready_and_o(lce_fill_ready_and_li)
         ,.msg_dst_i(lce_fill_dst)

         ,.msg_header_o(lce_fill_header_li)
         ,.msg_data_o(lce_fill_data_li)
         ,.msg_v_o(lce_fill_v_li)
         ,.msg_ready_and_i(lce_fill_ready_and_lo)
         );

      // Cmd Crossbar
      // from CCE to LCE cmd in
      bp_me_xbar_stream
       #(.bp_params_p(bp_params_p)
         ,.payload_width_p(lce_cmd_payload_width_lp)
         ,.stream_mask_p(lce_cmd_stream_mask_gp)
         ,.num_source_p(num_cce_p)
         ,.num_sink_p(num_lce_p)
         )
       fwd_xbar
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.msg_header_i(cce_lce_cmd_header_lo)
         ,.msg_data_i(cce_lce_cmd_data_lo)
         ,.msg_v_i(cce_lce_cmd_v_lo)
         ,.msg_ready_and_o(cce_lce_cmd_ready_and_li)
         ,.msg_dst_i(cce_lce_cmd_dst)

         ,.msg_header_o(lce_cmd_header_li)
         ,.msg_data_o(lce_cmd_data_li)
         ,.msg_v_o(lce_cmd_v_li)
         ,.msg_ready_and_i(lce_cmd_ready_and_lo)
         );

       bp_cce_fsm
        #(.bp_params_p(bp_params_p))
        cce
         (.clk_i(clk_i)
          ,.reset_i(reset_i)

          ,.cfg_bus_i(cfg_bus_i)

          // LCE-CCE Interface
          // BedRock Burst protocol: ready&valid
          ,.lce_req_header_i(cce_lce_req_header_li)
          ,.lce_req_data_i(cce_lce_req_data_li)
          ,.lce_req_v_i(cce_lce_req_v_li)
          ,.lce_req_ready_and_o(cce_lce_req_ready_and_lo)

          ,.lce_resp_header_i(cce_lce_resp_header_li)
          ,.lce_resp_data_i(cce_lce_resp_data_li)
          ,.lce_resp_v_i(cce_lce_resp_v_li)
          ,.lce_resp_ready_and_o(cce_lce_resp_ready_and_lo)

          ,.lce_cmd_header_o(cce_lce_cmd_header_lo)
          ,.lce_cmd_data_o(cce_lce_cmd_data_lo)
          ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
          ,.lce_cmd_ready_and_i(cce_lce_cmd_ready_and_li)

          // CCE-MEM Interface
          // BedRock Stream protocol: ready&valid
          ,.mem_rev_header_i(mem_rev_header_i)
          ,.mem_rev_data_i(mem_rev_data_i)
          ,.mem_rev_v_i(mem_rev_v_i)
          ,.mem_rev_ready_and_o(mem_rev_ready_and_o)

          ,.mem_fwd_header_o(mem_fwd_header_o)
          ,.mem_fwd_data_o(mem_fwd_data_o)
          ,.mem_fwd_v_o(mem_fwd_v_o)
          ,.mem_fwd_ready_and_i(mem_fwd_ready_and_i)
          );
     end

endmodule

