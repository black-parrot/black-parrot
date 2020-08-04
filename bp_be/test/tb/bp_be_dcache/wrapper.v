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
  ,parameter num_caches_p = 1
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
   `declare_bp_lce_cce_if_header_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p)
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

   , localparam lce_cce_req_packet_width_lp = `bsg_wormhole_concentrator_packet_width(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp)
   , localparam lce_cce_req_packet_hdr_width_lp = (lce_cce_req_packet_width_lp-cce_block_width_p)
   )
   ( input                                             clk_i
   , input                                             reset_i

   , input [cfg_bus_width_lp-1:0]                      cfg_bus_i

   , input [num_caches_p-1:0][dcache_pkt_width_lp-1:0] dcache_pkt_i
   , input [num_caches_p-1:0]                          v_i
   , output logic [num_caches_p-1:0]                   ready_o

   , input [num_caches_p-1:0][ptag_width_lp-1:0]       ptag_i
   , input [num_caches_p-1:0]                          uncached_i

   , output logic [num_caches_p-1:0][dword_width_p-1:0]data_o
   , output logic [num_caches_p-1:0]                   v_o

   , input                                             mem_resp_v_i
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , output logic                                      mem_resp_yumi_o

   , output logic                                      mem_cmd_v_o
   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , input                                             mem_cmd_ready_i
   );

   `declare_bp_be_dcache_pkt_s(page_offset_width_p, dpath_width_p);

   // Cache to Rolly FIFO signals
   logic [num_caches_p-1:0] dcache_ready_lo;
   logic [num_caches_p-1:0] rollback_li;
   logic [num_caches_p-1:0] rolly_uncached_lo;
   logic [num_caches_p-1:0] rolly_v_lo, rolly_yumi_li;
   bp_be_dcache_pkt_s [num_caches_p-1:0] rolly_dcache_pkt_lo;
   logic [num_caches_p-1:0][ptag_width_lp-1:0] rolly_ptag_lo;

   // D$ - LCE Interface signals
   // Miss, Management Interfaces
   logic [num_caches_p-1:0] cache_req_v_lo, cache_req_metadata_v_lo;
   logic [num_caches_p-1:0] cache_req_ready_lo;
   logic [num_caches_p-1:0] cache_req_complete_lo, cache_req_critical_lo;
   logic [num_caches_p-1:0][dcache_req_width_lp-1:0] cache_req_lo;
   logic [num_caches_p-1:0][dcache_req_metadata_width_lp-1:0] cache_req_metadata_lo;

   // Fill Interface
   logic [num_caches_p-1:0] data_mem_pkt_v_lo, tag_mem_pkt_v_lo, stat_mem_pkt_v_lo;
   logic [num_caches_p-1:0] data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
   logic [num_caches_p-1:0][dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_lo;
   logic [num_caches_p-1:0][dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_lo;
   logic [num_caches_p-1:0][dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_lo;
   logic [num_caches_p-1:0][dcache_block_width_p-1:0] data_mem_lo;
   logic [num_caches_p-1:0][ptag_width_lp-1:0] tag_mem_lo;
   logic [num_caches_p-1:0][dcache_stat_info_width_lp-1:0] stat_mem_lo;

   // Credits
   logic [num_caches_p-1:0] credits_full_lo, credits_empty_lo;

   logic [num_caches_p-1:0][ptag_width_lp-1:0] rolly_ptag_r;
   logic [num_caches_p-1:0] rolly_uncached_r;
   logic [num_caches_p-1:0] is_store, is_store_rr, dcache_v_rr, poison_li;

   logic [num_caches_p-1:0][dpath_width_p-1:0] early_data_lo;
   logic [num_caches_p-1:0] early_v_lo;
   logic [num_caches_p-1:0][dpath_width_p-1:0] final_data_lo;
   logic [num_caches_p-1:0] final_v_lo;

   logic [num_caches_p-1:0] lce_req_v_lo, lce_resp_v_lo;
   logic cce_lce_req_v_li, cce_lce_req_yumi_lo;
   logic [num_caches_p-1:0] lce_req_ready_li, lce_resp_ready_li;
   logic cce_lce_resp_v_li, cce_lce_resp_yumi_lo;
   logic [num_caches_p-1:0] fifo_lce_cmd_v_lo, fifo_lce_cmd_yumi_li, lce_cmd_v_li, lce_cmd_yumi_lo, lce_cmd_v_lo, lce_cmd_ready_li;
   logic cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;
   
   `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, dcache_assoc_p, dcache_block_width_p);
   
   bp_lce_cce_req_s [num_caches_p-1:0] lce_req_lo;
   bp_lce_cce_req_s cce_lce_req_li;
   bp_lce_cmd_s [num_caches_p-1:0] lce_cmd_li, lce_cmd_lo, fifo_lce_cmd_lo;
   bp_lce_cmd_s cce_lce_cmd_lo;
   bp_lce_cce_resp_s [num_caches_p-1:0] lce_resp_lo;
   bp_lce_cce_resp_s cce_lce_resp_li;
   
   `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
   bp_cfg_bus_s cfg_bus_cast_i;
   assign cfg_bus_cast_i = cfg_bus_i;

   `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_req_packet_s);
   `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_width_lp, lce_cmd_packet_s);
   `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_resp_width_lp, lce_resp_packet_s);
   `declare_bsg_ready_and_link_sif_s($bits(lce_req_packet_s), coh_req_ready_and_link_s);
   `declare_bsg_ready_and_link_sif_s($bits(lce_cmd_packet_s), coh_cmd_ready_and_link_s);
   `declare_bsg_ready_and_link_sif_s($bits(lce_resp_packet_s), coh_resp_ready_and_link_s);

   coh_req_ready_and_link_s [num_caches_p-1:0]  lce_req_link_li, lce_req_link_lo;
   coh_cmd_ready_and_link_s [num_caches_p-1:0]  lce_cmd_link_li, lce_cmd_link_lo;
   coh_resp_ready_and_link_s [num_caches_p-1:0] lce_resp_link_li, lce_resp_link_lo;

   coh_req_ready_and_link_s cce_lce_req_link_li, cce_lce_req_link_lo;
   coh_cmd_ready_and_link_s cce_lce_cmd_link_li, cce_lce_cmd_link_lo;
   coh_resp_ready_and_link_s cce_lce_resp_link_li, cce_lce_resp_link_lo;
   
   logic [num_caches_p-1:0][coh_noc_cord_width_p-1:0] req_cce_cord_li;
   logic [num_caches_p-1:0][coh_noc_cid_width_p-1:0] req_cce_cid_li;
   lce_req_packet_s [num_caches_p-1:0] lce_req_packet_lo;
   
   logic [num_caches_p-1:0][coh_noc_cord_width_p-1:0] lce_cord_li;
   logic [num_caches_p-1:0][coh_noc_cid_width_p-1:0] lce_cid_li;
   lce_cmd_packet_s [num_caches_p-1:0] lce_cmd_packet_lo, lce_cmd_packet_li;

   logic [num_caches_p-1:0][coh_noc_cord_width_p-1:0] resp_cce_cord_li;
   logic [num_caches_p-1:0][coh_noc_cid_width_p-1:0] resp_cce_cid_li;
   lce_resp_packet_s [num_caches_p-1:0] lce_resp_packet_lo;

   for (genvar i = 0; i < num_caches_p; i++)
     begin : cache
       bsg_fifo_1r1w_rolly
       #(.width_p(dcache_pkt_width_lp+ptag_width_lp+1)
        ,.els_p(8))
        rolly
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.roll_v_i(rollback_li[i])
        ,.clr_v_i(1'b0)
        ,.deq_v_i(v_o[i])

        ,.data_i({uncached_i[i], ptag_i[i], dcache_pkt_i[i]})
        ,.v_i(v_i[i])
        ,.ready_o(ready_o[i])

        ,.data_o({rolly_uncached_lo[i], rolly_ptag_lo[i], rolly_dcache_pkt_lo[i]})
        ,.v_o(rolly_v_lo[i])
        ,.yumi_i(rolly_yumi_li[i])
        );
       assign rolly_yumi_li[i] = rolly_v_lo[i] & dcache_ready_lo[i];

       bsg_dff_reset
        #(.width_p(1+ptag_width_lp)
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

       assign poison_li[i] = dcache_v_rr[i] & ~v_o[i];
       assign rollback_li[i] = poison_li[i];

       bp_be_dcache
       #(.bp_params_p(bp_params_p)
         ,.writethrough_p(wt_p)
         )
       dcache
       (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.cfg_bus_i(cfg_bus_i)

       ,.dcache_pkt_i(rolly_dcache_pkt_lo[i])
       ,.v_i(rolly_yumi_li[i])
       ,.ready_o(dcache_ready_lo[i])

       ,.early_data_o(early_data_lo[i])
       ,.early_v_o(early_v_lo[i])
       ,.final_data_o(final_data_lo[i])
       ,.final_v_o(final_v_lo[i])

       ,.ptag_v_i(1'b1)
       ,.ptag_i(rolly_ptag_r[i])
       ,.uncached_i(rolly_uncached_r[i])

       ,.flush_i(poison_li[i])

       ,.cache_req_v_o(cache_req_v_lo[i])
       ,.cache_req_o(cache_req_lo[i])
       ,.cache_req_metadata_o(cache_req_metadata_lo[i])
       ,.cache_req_metadata_v_o(cache_req_metadata_v_lo[i])
       ,.cache_req_ready_i(cache_req_ready_lo[i])
       ,.cache_req_complete_i(cache_req_complete_lo[i])
       ,.cache_req_critical_i(cache_req_critical_lo[i])

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

       // Stores "return" 0 to the trace replay module
       assign data_o[i] = is_store_rr[i] ? '0 : final_data_lo[i];
       assign v_o[i] = final_v_lo[i];

       if (uce_p == 0)
         begin : lce
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

           ,.lce_id_i(/*cfg_bus_cast_i.dcache_id*/lce_id_width_p'(i))
           ,.lce_mode_i(cfg_bus_cast_i.dcache_mode)

           ,.cache_req_i(cache_req_lo[i])
           ,.cache_req_v_i(cache_req_v_lo[i])
           ,.cache_req_ready_o(cache_req_ready_lo[i])
           ,.cache_req_metadata_i(cache_req_metadata_lo[i])
           ,.cache_req_metadata_v_i(cache_req_metadata_v_lo[i])

           ,.cache_req_complete_o(cache_req_complete_lo[i])
           ,.cache_req_critical_o(cache_req_critical_lo[i])

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

           ,.lce_req_o(lce_req_lo[i])
           ,.lce_req_v_o(lce_req_v_lo[i])
           ,.lce_req_ready_i(lce_req_ready_li[i])

           ,.lce_resp_o(lce_resp_lo[i])
           ,.lce_resp_v_o(lce_resp_v_lo[i])
           ,.lce_resp_ready_i(lce_resp_ready_li[i])

           ,.lce_cmd_i(lce_cmd_li[i])
           ,.lce_cmd_v_i(lce_cmd_v_li[i])
           ,.lce_cmd_yumi_o(lce_cmd_yumi_lo[i])

           ,.lce_cmd_o(lce_cmd_lo[i])
           ,.lce_cmd_v_o(lce_cmd_v_lo[i])
           ,.lce_cmd_ready_i(lce_cmd_ready_li[i])

           ,.credits_full_o(credits_full_lo[i])
           ,.credits_empty_o(credits_empty_lo[i])
           );

           if (num_caches_p > 1) 
             begin : multiple
               bp_me_cce_id_to_cord
                #(.bp_params_p(bp_params_p))
                 req_router_cord
                  (.cce_id_i(lce_req_lo[i].header.dst_id)
                   ,.cce_cord_o(req_cce_cord_li[i])
                   ,.cce_cid_o(req_cce_cid_li[i])
                   );
               
               assign lce_req_packet_lo[i].payload = lce_req_lo[i];
               assign lce_req_packet_lo[i].cid = req_cce_cid_li[i];
               assign lce_req_packet_lo[i].cord = req_cce_cord_li[i];
               assign lce_req_packet_lo[i].len = coh_noc_len_width_p'(0);

               bsg_wormhole_router_adapter_in
                #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
                  ,.len_width_p(coh_noc_len_width_p)
                  ,.cord_width_p(coh_noc_cord_width_p)
                  ,.flit_width_p($bits(lce_req_packet_s))
                  )
                  lce_req_adapter_in
                   (.clk_i(clk_i)
                    ,.reset_i(reset_i)

                    ,.packet_i(lce_req_packet_lo[i])
                    ,.v_i(lce_req_v_lo[i])
                    ,.ready_o(lce_req_ready_li[i])

                    ,.link_i(lce_req_link_li[i])
                    ,.link_o(lce_req_link_lo[i])
                    );

               
               bp_me_lce_id_to_cord
                #(.bp_params_p(bp_params_p))
                cmd_router_cord
                 (.lce_id_i(lce_cmd_lo[i].header.dst_id)
                  ,.lce_cord_o(lce_cord_li[i])
                  ,.lce_cid_o(lce_cid_li[i])
                  );

               assign lce_cmd_packet_lo[i].payload = lce_cmd_lo[i];
               assign lce_cmd_packet_lo[i].cid = lce_cmd_lo[i].header.dst_id;
               assign lce_cmd_packet_lo[i].cord = lce_cord_li[i];
               assign lce_cmd_packet_lo[i].len = coh_noc_len_width_p'(0);

               bsg_wormhole_router_adapter
                #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
                  ,.len_width_p(coh_noc_len_width_p)
                  ,.cord_width_p(coh_noc_cord_width_p)
                  ,.flit_width_p($bits(lce_cmd_packet_s))
                  )
                  cmd_adapter
                   (.clk_i(clk_i)
                    ,.reset_i(reset_i)

                    ,.packet_i(lce_cmd_packet_lo[i])
                    ,.v_i(lce_cmd_v_lo[i])
                    ,.ready_o(lce_cmd_ready_li[i])

                    ,.link_i(lce_cmd_link_li[i])
                    ,.link_o(lce_cmd_link_lo[i])

                    ,.packet_o(lce_cmd_packet_li[i])
                    ,.v_o(lce_cmd_v_li[i])
                    ,.yumi_i(lce_cmd_yumi_lo[i])
                    );
               assign lce_cmd_li[i] = lce_cmd_packet_li[i].payload;

               bp_me_cce_id_to_cord
                #(.bp_params_p(bp_params_p))
                 resp_router_cord
                  (.cce_id_i(lce_resp_lo[i].header.dst_id)
                   ,.cce_cord_o(resp_cce_cord_li[i])
                   ,.cce_cid_o(resp_cce_cid_li[i])
                   );

               assign lce_resp_packet_lo[i].payload = lce_resp_lo[i];
               assign lce_resp_packet_lo[i].cid = resp_cce_cid_li[i];
               assign lce_resp_packet_lo[i].cord = resp_cce_cord_li[i];
               assign lce_resp_packet_lo[i].len = coh_noc_len_width_p'(0);
               
               bsg_wormhole_router_adapter_in
                #(.max_payload_width_p($bits(lce_resp_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
                  ,.len_width_p(coh_noc_len_width_p)
                  ,.cord_width_p(coh_noc_cord_width_p)
                  ,.flit_width_p($bits(lce_resp_packet_s))
                  )
                  lce_resp_adapter_in
                   (.clk_i(clk_i)
                    ,.reset_i(reset_i)

                    ,.packet_i(lce_resp_packet_lo[i])
                    ,.v_i(lce_resp_v_lo[i])
                    ,.ready_o(lce_resp_ready_li[i])

                    ,.link_i(lce_resp_link_li[i])
                    ,.link_o(lce_resp_link_lo[i])
                    );
             end
           else 
             begin : single
               // lce_req demanding -> demanding handshake conversion
               bsg_two_fifo
                #(.width_p(lce_cce_req_width_lp))
                lce_cce_req_fifo
                 (.clk_i(clk_i)
                  ,.reset_i(reset_i)

                  ,.v_i(lce_req_v_lo)
                  ,.data_i(lce_req_lo)
                  ,.ready_o(lce_req_ready_li)

                  ,.v_o(cce_lce_req_v_li)
                  ,.data_o(cce_lce_req_li)
                  ,.yumi_i(cce_lce_req_yumi_lo)
                  );
               
               // lce_resp demanding -> demanding handshake conversion
               bsg_fifo_1r1w_small
                #(.width_p(lce_cce_resp_width_lp)
                  ,.els_p(wg_per_cce_lp)
                  )
                  lce_cce_resp_fifo
                   (.clk_i(clk_i)
                    ,.reset_i(reset_i)

                    ,.v_i(lce_resp_v_lo)
                    ,.data_i(lce_resp_lo)
                    ,.ready_o(lce_resp_ready_li)

                    ,.v_o(cce_lce_resp_v_li)
                    ,.data_o(cce_lce_resp_li)
                    ,.yumi_i(cce_lce_resp_yumi_lo)
                    );

               // lce_cmd demanding -> demanding handshake conversion
               bsg_two_fifo
                #(.width_p(lce_cmd_width_lp))
                cmd_fifo
                 (.clk_i(clk_i)
                  ,.reset_i(reset_i)

                  // from CCE
                  ,.v_i(cce_lce_cmd_v_lo)
                  ,.ready_o(cce_lce_cmd_ready_li)
                  ,.data_i(cce_lce_cmd_lo)

                  // to LCE
                  ,.v_o(lce_cmd_v_li)
                  ,.yumi_i(lce_cmd_yumi_lo)
                  ,.data_o(lce_cmd_li)
                  );
             end
         end
       else if (uce_p == 1)
         begin : uce
           logic fifo_mem_resp_v_lo, fifo_mem_cmd_v_lo;
           logic fifo_mem_resp_yumi_li;
           logic [cce_mem_msg_width_lp-1:0] fifo_mem_resp_lo, fifo_mem_cmd_lo;
           logic mem_resp_ready_lo, fifo_mem_cmd_ready_li;

           bp_uce
           #(.bp_params_p(bp_params_p)
            ,.uce_mem_data_width_p(dcache_fill_width_p)
            ,.assoc_p(dcache_assoc_p)
            ,.sets_p(dcache_sets_p)
            ,.block_width_p(dcache_block_width_p)
            ,.fill_width_p(dcache_fill_width_p)
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
     end

   if ((uce_p == 0) & (num_caches_p > 1))
     begin : concentrator
       coh_req_ready_and_link_s req_concentrated_link_li, req_concentrated_link_lo, req_concentrated_link_r;
       coh_cmd_ready_and_link_s cmd_concentrated_link_li, cmd_concentrated_link_lo, cmd_concentrated_link_r;
       coh_resp_ready_and_link_s resp_concentrated_link_li, resp_concentrated_link_lo, resp_concentrated_link_r;
       
       lce_req_packet_s cce_lce_req_packet_li;
       bsg_wormhole_router_adapter_out
        #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
          ,.len_width_p(coh_noc_len_width_p)
          ,.cord_width_p(coh_noc_cord_width_p)
          ,.flit_width_p($bits(lce_req_packet_s))
          )
          cce_req_adapter_out
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.link_i(req_concentrated_link_li)
            ,.link_o(cce_lce_req_link_lo)

            ,.packet_o(cce_lce_req_packet_li)
            ,.v_o(cce_lce_req_v_li)
            ,.yumi_i(cce_lce_req_yumi_lo)
            );

       assign cce_lce_req_li = cce_lce_req_packet_li.payload;

       logic [coh_noc_cord_width_p-1:0] cce_lce_cord_li;
       logic [coh_noc_cid_width_p-1:0] cce_lce_cid_li;
       lce_cmd_packet_s cce_lce_cmd_packet_lo;

       bp_me_lce_id_to_cord
        #(.bp_params_p(bp_params_p))
        cce_cmd_router_cord
         (.lce_id_i(cce_lce_cmd_lo.header.dst_id)
          ,.lce_cord_o(cce_lce_cord_li)
          ,.lce_cid_o(cce_lce_cid_li)
          );

       assign cce_lce_cmd_packet_lo.payload = cce_lce_cmd_lo;
       assign cce_lce_cmd_packet_lo.cid = cce_lce_cmd_lo.header.dst_id;
       assign cce_lce_cmd_packet_lo.cord = cce_lce_cord_li;
       assign cce_lce_cmd_packet_lo.len = coh_noc_len_width_p'(0); 

       bsg_wormhole_router_adapter_in
        #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
          ,.len_width_p(coh_noc_len_width_p)
          ,.cord_width_p(coh_noc_cord_width_p)
          ,.flit_width_p($bits(lce_cmd_packet_s))
          )
          cmd_adapter_in
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.packet_i(cce_lce_cmd_packet_lo)
            ,.v_i(cce_lce_cmd_v_lo)
            ,.ready_o(cce_lce_cmd_ready_li)

            ,.link_i(cce_lce_cmd_link_li)
            ,.link_o(cce_lce_cmd_link_lo)
            );

       lce_resp_packet_s cce_lce_resp_packet_li;
       bsg_wormhole_router_adapter_out
        #(.max_payload_width_p($bits(lce_resp_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
          ,.len_width_p(coh_noc_len_width_p)
          ,.cord_width_p(coh_noc_cord_width_p)
          ,.flit_width_p($bits(lce_resp_packet_s))
          )
          cce_resp_adapter_out
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.link_i(resp_concentrated_link_li)
            ,.link_o(cce_lce_resp_link_lo)

            ,.packet_o(cce_lce_resp_packet_li)
            ,.v_o(cce_lce_resp_v_li)
            ,.yumi_i(cce_lce_resp_yumi_lo)
            );
       assign cce_lce_resp_li = cce_lce_resp_packet_li.payload;


       assign req_concentrated_link_li = '{data          : req_concentrated_link_lo.data
                                           ,v            : req_concentrated_link_lo.v
                                           ,ready_and_rev: cce_lce_req_link_lo.ready_and_rev
                                           };

       bsg_wormhole_concentrator_in
        #(.flit_width_p($bits(lce_req_packet_s))
          ,.len_width_p(coh_noc_len_width_p)
          ,.cid_width_p(coh_noc_cid_width_p)
          ,.num_in_p(num_caches_p)
          ,.cord_width_p(coh_noc_cord_width_p)
          )
          req_concentrator
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.links_i(lce_req_link_lo)
            ,.links_o(lce_req_link_li)

            ,.concentrated_link_i(req_concentrated_link_li)
            ,.concentrated_link_o(req_concentrated_link_lo)
            );

       assign cmd_concentrated_link_li = cmd_concentrated_link_lo;
       bsg_wormhole_concentrator
        #(.flit_width_p($bits(lce_cmd_packet_s))
          ,.len_width_p(coh_noc_len_width_p)
          ,.cid_width_p(coh_noc_cid_width_p)
          ,.num_in_p(num_caches_p+1)
          ,.cord_width_p(coh_noc_cord_width_p)
          )
          cmd_concentrator
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.links_i({cce_lce_cmd_link_lo, lce_cmd_link_lo})
            ,.links_o({cce_lce_cmd_link_li, lce_cmd_link_li})

            ,.concentrated_link_i(cmd_concentrated_link_li)
            ,.concentrated_link_o(cmd_concentrated_link_lo)
            );

       assign resp_concentrated_link_li = '{data          : resp_concentrated_link_lo.data
                                            ,v            : resp_concentrated_link_lo.v
                                            ,ready_and_rev: cce_lce_resp_link_lo.ready_and_rev
                                            };
       bsg_wormhole_concentrator_in
        #(.flit_width_p($bits(lce_resp_packet_s))
          ,.len_width_p(coh_noc_len_width_p)
          ,.cid_width_p(coh_noc_cid_width_p)
          ,.num_in_p(num_caches_p)
          ,.cord_width_p(coh_noc_cord_width_p)
          )
          resp_concentrator
           (.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.links_i(lce_resp_link_lo)
            ,.links_o(lce_resp_link_li)

            ,.concentrated_link_i(resp_concentrated_link_li)
            ,.concentrated_link_o(resp_concentrated_link_lo)
            );
     end   

   if (uce_p == 0)
     begin : cce
       logic mem_resp_v_to_cce, mem_resp_yumi_from_cce, mem_resp_ready_lo;
       logic mem_cmd_v_from_cce, mem_cmd_ready_to_cce, mem_cmd_v_lo, mem_cmd_yumi_li;
       logic [cce_mem_msg_width_lp-1:0] mem_resp_to_cce;
       logic [cce_mem_msg_width_lp-1:0] mem_cmd_from_cce;
       bp_cce_fsm
       #(.bp_params_p(bp_params_p))
       cce
       (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.cfg_bus_i(cfg_bus_i)

       ,.lce_req_i(cce_lce_req_li)
       ,.lce_req_v_i(cce_lce_req_v_li)
       ,.lce_req_yumi_o(cce_lce_req_yumi_lo)

       ,.lce_resp_i(cce_lce_resp_li)
       ,.lce_resp_v_i(cce_lce_resp_v_li)
       ,.lce_resp_yumi_o(cce_lce_resp_yumi_lo)

       ,.lce_cmd_o(cce_lce_cmd_lo)
       ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
       ,.lce_cmd_ready_i(cce_lce_cmd_ready_li)

       ,.mem_resp_i(mem_resp_to_cce)
       ,.mem_resp_v_i(mem_resp_v_to_cce)
       ,.mem_resp_yumi_o(mem_resp_yumi_from_cce)

       ,.mem_cmd_o(mem_cmd_from_cce)
       ,.mem_cmd_v_o(mem_cmd_v_from_cce)
       ,.mem_cmd_ready_i(mem_cmd_ready_to_cce)
       );

       // Inbound Mem to CCE
       bsg_fifo_1r1w_small
        #(.width_p(cce_mem_msg_width_lp)
          ,.els_p(wg_per_cce_lp)
          )
        mem_cce_resp_fifo
         (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.v_i(mem_resp_v_i)
          ,.data_i(mem_resp_i)
          ,.ready_o(mem_resp_ready_lo)
          ,.v_o(mem_resp_v_to_cce)
          ,.data_o(mem_resp_to_cce)
          ,.yumi_i(mem_resp_yumi_from_cce)
          );

       // Outbound CCE to Mem
       bsg_two_fifo
        #(.width_p(cce_mem_msg_width_lp))
        cce_mem_cmd_fifo
         (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.v_i(mem_cmd_v_from_cce)
          ,.data_i(mem_cmd_from_cce)
          ,.ready_o(mem_cmd_ready_to_cce)
          ,.v_o(mem_cmd_v_lo)
          ,.data_o(mem_cmd_o)
          ,.yumi_i(mem_cmd_yumi_li)
          );

       assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
       assign mem_cmd_yumi_li = mem_cmd_ready_i & mem_cmd_v_lo;
       assign mem_cmd_v_o = mem_cmd_yumi_li;

     end
endmodule
