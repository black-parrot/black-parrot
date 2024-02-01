/**
 *
 * Name:
 *   bp_uce.sv
 *
 * Description:
 *   This is the top level module for the UCE
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_uce
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
    , parameter `BSG_INV_PARAM(writeback_p)
    , parameter `BSG_INV_PARAM(assoc_p)
    , parameter `BSG_INV_PARAM(sets_p)
    , parameter `BSG_INV_PARAM(block_width_p)
    , parameter `BSG_INV_PARAM(fill_width_p)
    , parameter `BSG_INV_PARAM(tag_width_p)
    , parameter `BSG_INV_PARAM(id_width_p)

    `declare_bp_cache_engine_generic_if_widths(paddr_width_p, tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p, cache)
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [did_width_p-1:0]                        did_i
    , input [lce_id_width_p-1:0]                     lce_id_i

    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_v_i
    , output logic                                   cache_req_yumi_o
    , output logic                                   cache_req_lock_o
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
    , input                                          cache_req_metadata_v_i
    , output logic [id_width_p-1:0]                  cache_req_id_o
    , output logic                                   cache_req_critical_o
    , output logic                                   cache_req_last_o
    , output logic                                   cache_req_credits_full_o
    , output logic                                   cache_req_credits_empty_o

    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , output logic                                   tag_mem_pkt_v_o
    , input                                          tag_mem_pkt_yumi_i
    , input [cache_tag_info_width_lp-1:0]            tag_mem_i

    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , output logic                                   data_mem_pkt_v_o
    , input                                          data_mem_pkt_yumi_i
    , input [block_width_p-1:0]                      data_mem_i

    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , output logic                                   stat_mem_pkt_v_o
    , input                                          stat_mem_pkt_yumi_i
    , input [cache_stat_info_width_lp-1:0]           stat_mem_i

    , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
    , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
    , output logic                                   mem_fwd_v_o
    , input                                          mem_fwd_ready_and_i

    , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
    , input [bedrock_fill_width_p-1:0]               mem_rev_data_i
    , input                                          mem_rev_v_i
    , output logic                                   mem_rev_ready_and_o
    );

  localparam bank_width_lp = block_width_p / assoc_p;
  localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_gp;
  localparam byte_offset_width_lp  = `BSG_SAFE_CLOG2(bank_width_lp>>3);
  // Words per line == associativity
  localparam bank_offset_width_lp  = `BSG_SAFE_CLOG2(assoc_p);
  localparam block_offset_width_lp = (assoc_p > 1) ? (bank_offset_width_lp + byte_offset_width_lp) : byte_offset_width_lp;
  localparam index_width_lp = `BSG_SAFE_CLOG2(sets_p);
  localparam way_width_lp = `BSG_SAFE_CLOG2(assoc_p);
  localparam block_size_in_fill_lp = block_width_p / fill_width_p;
  localparam fill_size_in_bank_lp = fill_width_p / bank_width_lp;
  localparam fill_cnt_width_lp = `BSG_SAFE_CLOG2(block_size_in_fill_lp);
  localparam fill_offset_width_lp = `BSG_SAFE_CLOG2(fill_width_p>>3);
  localparam bank_sub_offset_width_lp = $clog2(fill_size_in_bank_lp);

  localparam bp_bedrock_msg_size_e block_msg_size_lp = (block_width_p == 512)
                                                       ? e_bedrock_msg_size_64
                                                       : (block_width_p == 256)
                                                         ? e_bedrock_msg_size_32
                                                         : (block_width_p == 128)
                                                           ? e_bedrock_msg_size_16
                                                           : (block_width_p == 64)
                                                             ? e_bedrock_msg_size_8
                                                             : e_bedrock_msg_size_64;

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_cache_engine_generic_if(paddr_width_p, tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p, cache);

  `bp_cast_i(bp_cache_req_s, cache_req);
  `bp_cast_i(bp_cache_req_metadata_s, cache_req_metadata);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);

  enum logic [4:0] {
    e_reset
    ,e_init
    ,e_backoff
    ,e_inval
    ,e_clean_read
    ,e_clean_scan
    ,e_clean_write
    ,e_clean_fence
    ,e_bclean_evict
    ,e_bclean_writeback_req
    ,e_ready
    ,e_uc_writeback_evict
    ,e_uc_writeback_write_req
    ,e_send_critical
    ,e_writeback_evict
    ,e_writeback_read_wait
    ,e_writeback_write_req
    ,e_write_wait
    ,e_read_wait
    ,e_uc_read_wait
  } state_n, state_r;

  wire is_reset           = (state_r == e_reset);
  wire is_backoff         = (state_r == e_backoff);
  wire is_inval           = (state_r == e_inval);
  wire is_init            = (state_r == e_init);
  wire is_clean_read      = (state_r == e_clean_read);
  wire is_clean_scan      = (state_r == e_clean_scan);
  wire is_clean_write     = (state_r == e_clean_write);
  wire is_clean_fence     = (state_r == e_clean_fence);
  wire is_ready           = (state_r == e_ready);
  wire is_send_critical   = (state_r == e_send_critical);
  wire is_writeback_evict = (state_r == e_writeback_evict); // read dirty data from cache to UCE
  wire is_writeback_read  = (state_r == e_writeback_read_wait); // read data from L2 to cache
  wire is_writeback_wb    = (state_r == e_writeback_write_req); // send dirty data from UCE to L2
  wire is_write_request   = (state_r == e_write_wait);
  wire is_read_request    = (state_r == e_read_wait);
  wire is_uc_read_wait    = (state_r == e_uc_read_wait);

  logic cache_req_ready_lo;
  bp_cache_req_s cache_req_r;
  logic cache_req_v_r, cache_req_done;
  bsg_two_fifo
   #(.width_p($bits(bp_cache_req_s)), .ready_THEN_valid_p(1))
   cache_req_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_cast_i)
     ,.v_i(cache_req_yumi_o)
     ,.ready_param_o(cache_req_ready_lo)

     ,.data_o(cache_req_r)
     ,.v_o(cache_req_v_r)
     ,.yumi_i(cache_req_v_r & cache_req_done)
     );

  bp_cache_req_metadata_s cache_req_metadata, cache_req_metadata_r;
  logic cache_req_metadata_v_r;
  bsg_two_fifo
   #(.width_p($bits(bp_cache_req_metadata_s)), .ready_THEN_valid_p(1))
   cache_req_metadata_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_metadata_cast_i)
     ,.v_i(cache_req_metadata_v_i & (cache_req_metadata_v_r | ~cache_req_done))
     ,.ready_param_o(/* Follows cache req fifo */)

     ,.data_o(cache_req_metadata_r)
     ,.v_o(cache_req_metadata_v_r)
     ,.yumi_i(cache_req_metadata_v_r & cache_req_done)
     );
  assign cache_req_metadata = cache_req_metadata_v_r ? cache_req_metadata_r : cache_req_metadata_cast_i;
  wire cache_req_metadata_v = cache_req_metadata_v_i | cache_req_metadata_v_r;

  logic [block_width_p-1:0] dirty_data_r;
  wire dirty_data_read = data_mem_pkt_v_o & (data_mem_pkt_cast_o.opcode == e_cache_data_mem_read);
  bsg_dff_sync_read
   #(.width_p(block_width_p), .bypass_p(1))
   dirty_data_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(data_mem_i)
     ,.v_n_i(dirty_data_read)

     ,.data_o(dirty_data_r)
     );

  bp_cache_tag_info_s dirty_tag_r;
  wire dirty_tag_read = tag_mem_pkt_v_o & (tag_mem_pkt_cast_o.opcode == e_cache_tag_mem_read);
  bsg_dff_sync_read
   #(.width_p($bits(bp_cache_tag_info_s)), .bypass_p(1))
   dirty_tag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(tag_mem_i)
     ,.v_n_i(dirty_tag_read)

     ,.data_o(dirty_tag_r)
     );

  bp_cache_stat_info_s dirty_stat_r;
  wire dirty_stat_read = stat_mem_pkt_v_o & (stat_mem_pkt_cast_o.opcode == e_cache_stat_mem_read);
  bsg_dff_sync_read
   #(.width_p($bits(bp_cache_stat_info_s)), .bypass_p(1))
   dirty_stat_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(stat_mem_i)
     ,.v_n_i(dirty_stat_read)

     ,.data_o(dirty_stat_r)
     );

  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [fill_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_ready_then_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_lo;
  logic fsm_fwd_new_lo, fsm_fwd_critical_lo, fsm_fwd_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(fill_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   uce_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_fwd_header_o)
     ,.msg_data_o(mem_fwd_data_o)
     ,.msg_v_o(mem_fwd_v_o)
     ,.msg_ready_and_i(mem_fwd_ready_and_i)

     ,.fsm_header_i(fsm_fwd_header_lo)
     ,.fsm_data_i(fsm_fwd_data_lo)
     ,.fsm_v_i(fsm_fwd_v_lo)
     ,.fsm_ready_then_o(fsm_fwd_ready_then_li)
     ,.fsm_addr_o(fsm_fwd_addr_lo)
     ,.fsm_new_o(fsm_fwd_new_lo)
     ,.fsm_critical_o(fsm_fwd_critical_lo)
     ,.fsm_last_o(fsm_fwd_last_lo)
     );

  bp_bedrock_mem_rev_header_s fsm_rev_header_li;
  logic [fill_width_p-1:0] fsm_rev_data_li;
  logic fsm_rev_v_li, fsm_rev_yumi_lo;
  logic [paddr_width_p-1:0] fsm_rev_addr_li;
  logic fsm_rev_new_li, fsm_rev_critical_li, fsm_rev_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(fill_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_rev_stream_mask_gp)
     )
   uce_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_rev_header_i)
     ,.msg_data_i(mem_rev_data_i)
     ,.msg_v_i(mem_rev_v_i)
     ,.msg_ready_and_o(mem_rev_ready_and_o)

     ,.fsm_header_o(fsm_rev_header_li)
     ,.fsm_data_o(fsm_rev_data_li)
     ,.fsm_v_o(fsm_rev_v_li)
     ,.fsm_yumi_i(fsm_rev_yumi_lo)
     ,.fsm_addr_o(fsm_rev_addr_li)
     ,.fsm_new_o(fsm_rev_new_li)
     ,.fsm_critical_o(fsm_rev_critical_li)
     ,.fsm_last_o(fsm_rev_last_li)
     );

  // We check for uncached stores ealier than other requests, because they get sent out in ready
  wire miss_load_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_load};
  wire miss_store_v_li  = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_store};
  wire miss_v_li        = cache_req_v_i & miss_load_v_li | miss_store_v_li;
  wire wt_store_v_li    = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};
  wire uc_load_v_li     = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_load};
  wire uc_store_v_li    = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire uc_amo_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_amo};
  wire uc_evict_v_li    = (uc_load_v_li | uc_store_v_li | uc_amo_v_li) & writeback_p & cache_req_cast_i.hit;
  wire inval_v_li       = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_inval};
  wire clean_v_li       = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_clean};
  wire flush_v_li       = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_flush};
  wire binval_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_binval};
  wire bclean_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_bclean};
  wire nonblocking_v_li = cache_req_v_i & (uc_store_v_li | wt_store_v_li) & ~uc_evict_v_li;

  wire store_resp_v_li  = fsm_rev_v_li & fsm_rev_header_li.msg_type inside {e_bedrock_mem_wr};
  wire load_resp_v_li   = fsm_rev_v_li & fsm_rev_header_li.msg_type inside {e_bedrock_mem_rd, e_bedrock_mem_amo};

  wire miss_load_v_r   = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_r  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_r        = cache_req_v_r & miss_load_v_r | miss_store_v_r;
  wire wt_store_v_r    = cache_req_v_r & cache_req_r.msg_type inside {e_wt_store};
  wire uc_load_v_r     = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire uc_store_v_r    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_store};
  wire uc_amo_v_r      = cache_req_v_r & cache_req_r.msg_type inside {e_uc_amo};
  wire uc_evict_v_r    = (uc_load_v_r | uc_store_v_r | uc_amo_v_r) & writeback_p & cache_req_r.hit;
  wire inval_v_r       = cache_req_v_r & cache_req_r.msg_type inside {e_cache_inval};
  wire clean_v_r       = cache_req_v_r & cache_req_r.msg_type inside {e_cache_clean};
  wire flush_v_r       = cache_req_v_r & cache_req_r.msg_type inside {e_cache_flush};
  wire binval_v_r      = cache_req_v_r & cache_req_r.msg_type inside {e_cache_binval};
  wire bclean_v_r      = cache_req_v_r & cache_req_r.msg_type inside {e_cache_bclean};
  wire nonblocking_v_r = cache_req_v_r & (uc_store_v_r | wt_store_v_r) & ~uc_evict_v_r;

  wire [block_size_in_fill_lp-1:0] fill_index_shift = (assoc_p > 1) ? (fsm_rev_addr_li[byte_offset_width_lp+:bank_offset_width_lp] >> bank_sub_offset_width_lp) : '0;

  logic [index_width_lp-1:0] index_cnt;
  logic index_clear, index_up;
  bsg_counter_clear_up
   #(.max_val_p(sets_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   index_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(index_clear)
     ,.up_i(index_up)

     ,.count_o(index_cnt)
     );
  wire index_done = index_up && ((sets_p == 1) || (index_cnt == sets_p-1));

  logic [`BSG_SAFE_CLOG2(assoc_p)-1:0] way_cnt;
  logic way_clear, way_up;
  bsg_counter_clear_up
   #(.max_val_p(assoc_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   way_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(way_clear)
     ,.up_i(way_up)

     ,.count_o(way_cnt)
     );
  wire way_done = way_up && ((assoc_p == 1) || (way_cnt == assoc_p-1));

  // Outstanding Requests Counter - counts all requests, cached and uncached
  //
  logic [`BSG_WIDTH(coh_noc_max_credits_p)-1:0] credit_count_lo;
  bsg_flow_counter
   #(.els_p(coh_noc_max_credits_p), .ready_THEN_valid_p(1))
   credit_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // credit consumed when memory command sends
     ,.v_i(fsm_fwd_v_lo & fsm_fwd_last_lo)
     ,.ready_param_i(fsm_fwd_ready_then_li)

     // credit returned when memory response fully consumed
     ,.yumi_i(fsm_rev_yumi_lo & fsm_rev_last_li)
     ,.count_o(credit_count_lo)
     );
  assign cache_req_credits_full_o  = cache_req_v_r && (credit_count_lo == coh_noc_max_credits_p);
  assign cache_req_credits_empty_o = ~cache_req_v_r && (credit_count_lo == 0);

  logic [fill_width_p-1:0] writeback_data;
  wire [fill_cnt_width_lp-1:0] dirty_data_select = fsm_fwd_addr_lo[fill_offset_width_lp+:fill_cnt_width_lp];
  bsg_mux
   #(.width_p(fill_width_p), .els_p(block_size_in_fill_lp))
   writeback_mux
    (.data_i(dirty_data_r)
     ,.sel_i(dirty_data_select)
     ,.data_o(writeback_data)
     );

  bp_cache_req_wr_subop_e cache_wr_subop;
  bp_bedrock_wr_subop_e mem_wr_subop;
  always_comb
    begin
      cache_wr_subop = cache_req_r.subop;
      unique case (cache_wr_subop)
        e_req_amolr  : mem_wr_subop = e_bedrock_amolr;
        e_req_amosc  : mem_wr_subop = e_bedrock_amosc;
        e_req_amoswap: mem_wr_subop = e_bedrock_amoswap;
        e_req_amoadd : mem_wr_subop = e_bedrock_amoadd;
        e_req_amoxor : mem_wr_subop = e_bedrock_amoxor;
        e_req_amoand : mem_wr_subop = e_bedrock_amoand;
        e_req_amoor  : mem_wr_subop = e_bedrock_amoor;
        e_req_amomin : mem_wr_subop = e_bedrock_amomin;
        e_req_amomax : mem_wr_subop = e_bedrock_amomax;
        e_req_amominu: mem_wr_subop = e_bedrock_amominu;
        e_req_amomaxu: mem_wr_subop = e_bedrock_amomaxu;
        default : mem_wr_subop = e_bedrock_store;
      endcase
    end

  // We ack mem_revs for stores no matter what, so load_resp_yumi_lo is for other responses
  logic load_resp_yumi_lo;
  assign fsm_rev_yumi_lo = load_resp_yumi_lo | store_resp_v_li;
  assign cache_req_lock_o = is_reset | is_init | inval_v_r | clean_v_r | flush_v_r;
  logic blocking_req_v_lo;
  always_comb
    begin
      cache_req_yumi_o = '0;

      index_up    = '0;
      index_clear = '0;
      way_up      = '0;
      way_clear   = '0;

      tag_mem_pkt_cast_o  = '0;
      tag_mem_pkt_v_o     = '0;
      data_mem_pkt_cast_o = '0;
      data_mem_pkt_v_o    = '0;
      stat_mem_pkt_cast_o = '0;
      stat_mem_pkt_v_o    = '0;

      cache_req_critical_o = '0;
      cache_req_last_o = '0;
      cache_req_done = '0;

      fsm_fwd_header_lo = '0;
      fsm_fwd_data_lo = '0;
      fsm_fwd_v_lo = '0;

      load_resp_yumi_lo = '0;

      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            state_n = e_init;
          end

        e_init, e_inval:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_cast_o.index  = index_cnt;
            tag_mem_pkt_v_o = 1'b1;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_cast_o.index  = index_cnt;
            stat_mem_pkt_v_o = 1'b1;

            index_up = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;

            cache_req_critical_o = is_inval & index_done;
            cache_req_last_o = cache_req_critical_o;
            cache_req_done = cache_req_last_o;

            state_n = (index_done & index_up) ? e_ready : state_r;
          end

        e_backoff:
          begin
            state_n = fsm_fwd_ready_then_li ? e_ready : state_r;
          end

        e_clean_read:
          begin
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_cast_o.index  = index_cnt;
            stat_mem_pkt_v_o = 1'b1;

            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_inval;
            tag_mem_pkt_cast_o.index = index_cnt;
            tag_mem_pkt_v_o = flush_v_r;

            state_n = (stat_mem_pkt_yumi_i & (~tag_mem_pkt_v_o | tag_mem_pkt_yumi_i))
                      ? e_clean_scan
                      : state_r;
          end

        e_clean_scan:
          if (~|dirty_stat_r)
            begin
              way_clear = 1'b1;
              index_up  = way_clear;

              state_n = index_done
                        ? e_clean_fence
                        : e_clean_read;
            end
          else if (dirty_stat_r[way_cnt])
            begin
              data_mem_pkt_cast_o.opcode     = e_cache_data_mem_read;
              data_mem_pkt_cast_o.index      = index_cnt;
              data_mem_pkt_cast_o.way_id     = way_cnt;
              data_mem_pkt_cast_o.fill_index = {block_size_in_fill_lp{1'b1}};
              data_mem_pkt_v_o = 1'b1;

              tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_read;
              tag_mem_pkt_cast_o.index  = index_cnt;
              tag_mem_pkt_cast_o.way_id = way_cnt;
              tag_mem_pkt_v_o = 1'b1;

              stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
              stat_mem_pkt_cast_o.index  = index_cnt;
              stat_mem_pkt_cast_o.way_id = way_cnt;
              stat_mem_pkt_v_o = 1'b1;

              state_n = (data_mem_pkt_yumi_i & tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
                        ? e_clean_write
                        : state_r;
            end
          else
            begin
              way_up   = 1'b1;
              index_up = way_done;

              state_n = (index_done & way_done)
                        ? e_clean_fence
                        : way_done
                          ? e_clean_read
                          : e_clean_scan;
            end

        e_clean_write:
          begin
            fsm_fwd_header_lo.msg_type       = e_bedrock_mem_wr;
            fsm_fwd_header_lo.addr           = {dirty_tag_r.tag, index_cnt, block_offset_width_lp'(0)};
            fsm_fwd_header_lo.size           = block_msg_size_lp;
            fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
            fsm_fwd_header_lo.payload.lce_id = lce_id_i;
            fsm_fwd_header_lo.payload.src_did = did_i;
            fsm_fwd_data_lo                  = writeback_data;
            fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

            way_up = fsm_fwd_v_lo & fsm_fwd_last_lo;
            index_up = way_done;

            state_n = (index_done & way_done)
                      ? e_clean_fence
                      : index_up
                        ? e_clean_read
                        : way_up
                          ? e_clean_scan
                          : e_clean_write;
          end

        e_clean_fence:
          begin
            cache_req_critical_o = (credit_count_lo == '0);
            cache_req_last_o = cache_req_critical_o;
            cache_req_done = cache_req_last_o;

            state_n = cache_req_last_o ? e_ready : state_r;
          end

        e_bclean_evict:
          begin
            data_mem_pkt_cast_o.opcode     = e_cache_data_mem_read;
            data_mem_pkt_cast_o.index      = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id     = cache_req_metadata.hit_or_repl_way;
            data_mem_pkt_cast_o.fill_index = {block_size_in_fill_lp{1'b1}};
            data_mem_pkt_v_o = 1'b1;

            state_n = data_mem_pkt_yumi_i ? e_bclean_writeback_req : state_r;
          end

        e_bclean_writeback_req:
          begin
            fsm_fwd_header_lo.msg_type       = e_bedrock_mem_wr;
            fsm_fwd_header_lo.addr           = {cache_req_r.addr[paddr_width_p-1:block_offset_width_lp], block_offset_width_lp'(0)};
            fsm_fwd_header_lo.size           = block_msg_size_lp;
            fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
            fsm_fwd_header_lo.payload.lce_id = lce_id_i;
            fsm_fwd_data_lo                  = writeback_data;
            fsm_fwd_v_lo = fsm_fwd_ready_then_li & cache_req_metadata.dirty;

            cache_req_done = ~cache_req_metadata.dirty || (fsm_fwd_v_lo & fsm_fwd_last_lo);

            state_n = cache_req_done ? e_ready : state_r;
          end

        e_ready:
          begin
            cache_req_yumi_o = cache_req_v_i & cache_req_ready_lo & (~cache_req_v_r |  nonblocking_v_li);

            state_n = cache_req_yumi_o
                      ? (flush_v_li | clean_v_li)
                        ? e_clean_read
                        : inval_v_li
                          ? e_inval
                          : bclean_v_li
                            ? e_bclean_evict
                            : uc_evict_v_li
                              ? e_uc_writeback_evict
                              : nonblocking_v_li
                                ? e_ready
                                : e_send_critical
                      : cache_req_v_i ? e_backoff : state_r;
          end

        e_uc_writeback_evict:
          begin
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = cache_req_metadata.hit_or_repl_way;
            data_mem_pkt_cast_o.fill_index = {block_size_in_fill_lp{1'b1}};
            data_mem_pkt_v_o = cache_req_metadata.dirty;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
            stat_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            stat_mem_pkt_cast_o.way_id = cache_req_metadata.hit_or_repl_way;
            stat_mem_pkt_v_o = cache_req_metadata.dirty;

            state_n = cache_req_metadata.dirty
                      ? (data_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
                        ? e_uc_writeback_write_req
                        : state_r
                      : e_send_critical;
          end

        e_uc_writeback_write_req:
          begin
            fsm_fwd_header_lo.msg_type       = e_bedrock_mem_wr;
            fsm_fwd_header_lo.addr           = {cache_req_r.addr[paddr_width_p-1:block_offset_width_lp], block_offset_width_lp'(0)};
            fsm_fwd_header_lo.size           = block_msg_size_lp;
            fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
            fsm_fwd_header_lo.payload.lce_id = lce_id_i;
            fsm_fwd_header_lo.payload.src_did = did_i;
            fsm_fwd_data_lo                   = writeback_data;
            fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

            state_n = (fsm_fwd_v_lo & fsm_fwd_last_lo)
                      ? e_send_critical
                      : state_r;
          end

        e_send_critical:
          if (miss_v_r)
            begin
              fsm_fwd_header_lo.msg_type = e_bedrock_mem_rd;
              fsm_fwd_header_lo.addr     = cache_req_r.addr;
              fsm_fwd_header_lo.size     = bp_bedrock_msg_size_e'(cache_req_r.size);
              fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
              fsm_fwd_header_lo.payload.lce_id = lce_id_i;
              fsm_fwd_header_lo.payload.src_did = did_i;
              fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

              state_n = (fsm_fwd_v_lo & fsm_fwd_last_lo)
                        ? cache_req_metadata.dirty
                          ? e_writeback_evict
                          : e_read_wait
                        : state_r;
            end
          else if (uc_load_v_r | uc_amo_v_r)
            begin
              fsm_fwd_header_lo.msg_type = uc_load_v_r ? e_bedrock_mem_rd : e_bedrock_mem_amo;
              fsm_fwd_header_lo.addr     = cache_req_r.addr;
              fsm_fwd_header_lo.size     = bp_bedrock_msg_size_e'(cache_req_r.size);
              fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
              fsm_fwd_header_lo.payload.lce_id = lce_id_i;
              fsm_fwd_header_lo.payload.src_did = did_i;
              fsm_fwd_header_lo.subop    = mem_wr_subop;
              fsm_fwd_data_lo            = {fill_width_p/dword_width_gp{cache_req_r.data}};
              fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

              state_n = (fsm_fwd_v_lo & fsm_fwd_last_lo) ? e_uc_read_wait : state_r;
            end
          else if (uc_store_v_r)
            begin
              fsm_fwd_header_lo.msg_type = e_bedrock_mem_wr;
              fsm_fwd_header_lo.addr     = cache_req_r.addr;
              fsm_fwd_header_lo.size     = bp_bedrock_msg_size_e'(cache_req_r.size);
              fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
              fsm_fwd_header_lo.payload.lce_id = lce_id_i;
              fsm_fwd_header_lo.payload.src_did = did_i;
              fsm_fwd_header_lo.subop    = mem_wr_subop;
              fsm_fwd_data_lo            = {fill_width_p/dword_width_gp{cache_req_r.data}};
              fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

              cache_req_done = fsm_fwd_v_lo & fsm_fwd_last_lo;

              state_n = cache_req_done ? e_ready : state_r;
            end

        e_writeback_evict:
          begin
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = cache_req_metadata.hit_or_repl_way;
            data_mem_pkt_cast_o.fill_index = {block_size_in_fill_lp{1'b1}};
            data_mem_pkt_v_o = 1'b1;

            tag_mem_pkt_cast_o.opcode  = e_cache_tag_mem_read;
            tag_mem_pkt_cast_o.index   = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            tag_mem_pkt_cast_o.way_id  = cache_req_metadata.hit_or_repl_way;
            tag_mem_pkt_v_o = 1'b1;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
            stat_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            stat_mem_pkt_cast_o.way_id = cache_req_metadata.hit_or_repl_way;
            stat_mem_pkt_v_o = 1'b1;

            state_n = (data_mem_pkt_yumi_i & tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i) ? e_writeback_read_wait : e_writeback_evict;
          end

        e_writeback_read_wait:
          begin
            // send the sub-block from L2 to cache
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_cast_o.index  = fsm_rev_addr_li[block_offset_width_lp+:index_width_lp];
            // We fill in M because we don't want to trigger additional coherence traffic
            tag_mem_pkt_cast_o.way_id = fsm_rev_header_li.payload.way_id[0+:`BSG_SAFE_CLOG2(assoc_p)];
            tag_mem_pkt_cast_o.state  = e_COH_M;
            tag_mem_pkt_cast_o.tag    = fsm_rev_addr_li[block_offset_width_lp+index_width_lp+:tag_width_p];
            tag_mem_pkt_v_o = load_resp_v_li & fsm_rev_new_li;

            data_mem_pkt_cast_o.opcode     = e_cache_data_mem_write;
            data_mem_pkt_cast_o.index      = fsm_rev_addr_li[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id     = fsm_rev_header_li.payload.way_id[0+:`BSG_SAFE_CLOG2(assoc_p)];
            data_mem_pkt_cast_o.data       = fsm_rev_data_li;
            data_mem_pkt_cast_o.fill_index = 1'b1 << fill_index_shift;
            data_mem_pkt_v_o = load_resp_v_li;

            load_resp_yumi_lo = (~fsm_rev_new_li | tag_mem_pkt_yumi_i) && data_mem_pkt_yumi_i;

            cache_req_critical_o = load_resp_v_li & fsm_rev_critical_li;
            cache_req_last_o = load_resp_v_li & fsm_rev_last_li;

            state_n = (load_resp_yumi_lo & cache_req_last_o) ? e_writeback_write_req : e_writeback_read_wait;
          end

        e_writeback_write_req:
          begin
            fsm_fwd_header_lo.msg_type       = e_bedrock_mem_wr;
            fsm_fwd_header_lo.addr           = {dirty_tag_r.tag, cache_req_r.addr[block_offset_width_lp+:index_width_lp], block_offset_width_lp'(0)};
            fsm_fwd_header_lo.size           = block_msg_size_lp;
            fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
            fsm_fwd_header_lo.payload.lce_id = lce_id_i;
            fsm_fwd_header_lo.payload.src_did = did_i;
            fsm_fwd_data_lo                  = writeback_data;
            fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

            cache_req_done = fsm_fwd_v_lo & fsm_fwd_last_lo;

            state_n = cache_req_done ? e_ready : e_writeback_write_req;
          end

        e_read_wait:
          begin
            // send the sub-block from L2 to cache
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_cast_o.index  = fsm_rev_addr_li[block_offset_width_lp+:index_width_lp];
            // We fill in M because we don't want to trigger additional coherence traffic
            tag_mem_pkt_cast_o.way_id = fsm_rev_header_li.payload.way_id[0+:`BSG_SAFE_CLOG2(assoc_p)];
            tag_mem_pkt_cast_o.state  = e_COH_M;
            tag_mem_pkt_cast_o.tag    = fsm_rev_addr_li[block_offset_width_lp+index_width_lp+:tag_width_p];
            tag_mem_pkt_v_o = load_resp_v_li & fsm_rev_new_li;

            data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
            data_mem_pkt_cast_o.index  = fsm_rev_addr_li[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = fsm_rev_header_li.payload.way_id[0+:`BSG_SAFE_CLOG2(assoc_p)];
            data_mem_pkt_cast_o.data   = fsm_rev_data_li;
            data_mem_pkt_cast_o.fill_index = 1'b1 << fill_index_shift;
            data_mem_pkt_v_o = load_resp_v_li;

            load_resp_yumi_lo = (~fsm_rev_new_li | tag_mem_pkt_yumi_i) && data_mem_pkt_yumi_i;

            cache_req_critical_o = load_resp_v_li & fsm_rev_critical_li;
            cache_req_last_o = load_resp_v_li & fsm_rev_last_li;
            cache_req_done = cache_req_last_o & load_resp_yumi_lo;

            state_n = cache_req_done ? e_ready : e_read_wait;
          end

        e_uc_read_wait:
          begin
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_cast_o.data = {(fill_width_p/dword_width_gp){fsm_rev_data_li[0+:dword_width_gp]}};
            data_mem_pkt_v_o = load_resp_v_li;

            load_resp_yumi_lo = data_mem_pkt_yumi_i;

            cache_req_critical_o = load_resp_v_li & fsm_rev_critical_li;
            cache_req_last_o = load_resp_v_li & fsm_rev_last_li;
            cache_req_done = cache_req_last_o & load_resp_yumi_lo;

            state_n = cache_req_done ? e_ready : e_uc_read_wait;
          end
        default: state_n = e_reset;
      endcase

      // Fire off a non-blocking request opportunistically if we have one
      // Could eke out some performance by changing ~fsm_fwd_v_lo to blocking_req_v_lo
      //if (nonblocking_v_r & ~fsm_fwd_v_lo)
      if (is_ready & nonblocking_v_r)
        begin
          fsm_fwd_header_lo.msg_type       = e_bedrock_mem_wr;
          fsm_fwd_header_lo.addr           = cache_req_r.addr;
          fsm_fwd_header_lo.size           = bp_bedrock_msg_size_e'(cache_req_r.size);
          fsm_fwd_header_lo.payload.way_id = lce_assoc_p'(cache_req_metadata.hit_or_repl_way);
          fsm_fwd_header_lo.payload.lce_id = lce_id_i;
          fsm_fwd_header_lo.payload.src_did = did_i;
          fsm_fwd_header_lo.subop          = wt_store_v_r ? e_bedrock_store : mem_wr_subop;
          fsm_fwd_data_lo                  = {fill_width_p/dword_width_gp{cache_req_r.data}};
          fsm_fwd_v_lo = fsm_fwd_ready_then_li & ~cache_req_credits_full_o;

          cache_req_done = fsm_fwd_v_lo & fsm_fwd_last_lo;
        end
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  // synopsys translate_off
  always_ff @(negedge clk_i)
    assert(reset_i !== '0 || (writeback_p == 1) || !(state_r inside {e_uc_writeback_evict, e_writeback_evict, e_uc_writeback_write_req, e_writeback_read_wait, e_writeback_write_req}))
      else $error("writethrough cache should not be in writeback states");
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bp_uce)

