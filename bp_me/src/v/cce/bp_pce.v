// This module describes the P-Mesh Cache Engine (PCE) which is the interface
// between the L1 Caches of BlackParrot and the L1.5 Cache of OpenPiton

module bp_pce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_pce_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   ,parameter block_width_p = 128
   ,parameter fill_width_p = 128
   ,parameter assoc_p = 2
   ,parameter sets_p = 256
   ,parameter pce_id_p = 1 // 0 = I$, 1 = D$
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, fill_width_p, cache)
   `declare_bp_pce_l15_if_widths(paddr_width_p, dword_width_p)

   // Cache parameters
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(assoc_p)
   , localparam block_offset_width_lp = word_offset_width_lp + byte_offset_width_lp
   , localparam index_width_lp = `BSG_SAFE_CLOG2(sets_p)
   , localparam way_width_lp = `BSG_SAFE_CLOG2(assoc_p)

   )
  ( input                                       clk_i
  , input                                       reset_i

  // Cache side
  , input [cache_req_width_lp-1:0]                 cache_req_i
  , input                                          cache_req_v_i
  , output logic                                   cache_req_ready_o
  , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
  , input                                          cache_req_metadata_v_i
  , output logic                                   cache_req_complete_o

  // Cache side
  , output logic [cache_data_mem_pkt_width_lp-1:0] cache_data_mem_pkt_o
  , output logic                                   cache_data_mem_pkt_v_o
  , input                                          cache_data_mem_pkt_yumi_i

  , output logic [cache_tag_mem_pkt_width_lp-1:0]  cache_tag_mem_pkt_o
  , output logic                                   cache_tag_mem_pkt_v_o
  , input                                          cache_tag_mem_pkt_yumi_i

  , output logic [cache_stat_mem_pkt_width_lp-1:0] cache_stat_mem_pkt_o
  , output logic                                   cache_stat_mem_pkt_v_o
  , input                                          cache_stat_mem_pkt_yumi_i

  // PCE -> L1.5
  , output logic                                   pce_l15_req_v_o
  , output logic [bp_pce_l15_req_width_lp-1:0]     pce_l15_req_o
  , input                                          pce_l15_req_ready_i

  // L1.5 -> PCE
  , input                                          l15_pce_ret_v_i
  , input        [bp_l15_pce_ret_width_lp-1:0]     l15_pce_ret_i
  , output logic                                   l15_pce_ret_yumi_o

  , output logic                                   credits_full_o
  , output logic                                   credits_empty_o
  );

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, fill_width_p, cache);
  `declare_bp_pce_l15_if(paddr_width_p, dword_width_p);

  bp_cache_req_s cache_req_cast_i;
  bp_cache_req_metadata_s cache_req_metadata_cast_i;
  assign cache_req_cast_i = cache_req_i;
  assign cache_req_metadata_cast_i = cache_req_metadata_i;

  bp_cache_data_mem_pkt_s cache_data_mem_pkt_cast_o;
  bp_cache_tag_mem_pkt_s cache_tag_mem_pkt_cast_o, inval_cache_tag_mem_pkt_cast_o;
  bp_cache_stat_mem_pkt_s cache_stat_mem_pkt_cast_o, inval_cache_stat_mem_pkt_cast_o;

  bp_pce_l15_req_s pce_l15_req_cast_o;
  bp_l15_pce_ret_s l15_pce_ret_cast_i;
  assign pce_l15_req_o = pce_l15_req_cast_o;
  assign l15_pce_ret_cast_i = l15_pce_ret_i;

  logic cache_req_v_r;
  always_ff @(posedge clk_i) begin
    cache_req_v_r <= cache_req_v_i;
  end

  bp_cache_req_s cache_req_r;
  bsg_dff_reset_en
    #(.width_p($bits(bp_cache_req_s)))
    cache_req_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.en_i(cache_req_v_i)
      ,.data_i(cache_req_cast_i)
      ,.data_o(cache_req_r)
      );
 
  bp_cache_req_metadata_s cache_req_metadata_r;
  bsg_dff_en_bypass
    #(.width_p($bits(bp_cache_req_metadata_s)))
    metadata_reg
     (.clk_i(clk_i)

      ,.en_i(cache_req_metadata_v_i)
      ,.data_i(cache_req_metadata_i)
      ,.data_o(cache_req_metadata_r)
      );

  enum logic [3:0] {e_reset, e_clear, e_ready, e_send_req, e_uc_read_wait, e_amo_lr_wait, e_amo_sc_wait, e_amo_op_wait, e_read_wait} state_n, state_r;

  wire uc_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire wt_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};

  wire store_resp_v_li = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_st_ack);
  wire load_resp_v_li  = l15_pce_ret_v_i & l15_pce_ret_cast_i.rtntype inside {e_load_ret, e_ifill_ret};
  wire inval_v_li      = l15_pce_ret_v_i & l15_pce_ret_cast_i.rtntype inside {e_evict_req, e_st_ack};
  wire is_ifill_ret_nc = (l15_pce_ret_cast_i.rtntype == e_ifill_ret) & l15_pce_ret_cast_i.noncacheable;
  wire is_load_ret_nc  = (l15_pce_ret_cast_i.rtntype == e_load_ret) & l15_pce_ret_cast_i.noncacheable;
  wire is_ifill_ret    = (l15_pce_ret_cast_i.rtntype == e_ifill_ret) & ~l15_pce_ret_cast_i.noncacheable;
  wire is_load_ret     = (l15_pce_ret_cast_i.rtntype == e_load_ret) & ~l15_pce_ret_cast_i.noncacheable;
  wire is_amo_lrsc_ret = (l15_pce_ret_cast_i.rtntype == e_atomic_ret) & l15_pce_ret_cast_i.atomic;
  // Fetch + Op atomics also set the noncacheable bit as 1
  wire is_amo_op_ret   = (l15_pce_ret_cast_i.rtntype == e_atomic_ret) & l15_pce_ret_cast_i.atomic & l15_pce_ret_cast_i.noncacheable;

  wire miss_load_v_li  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire amo_lr_v_li     = cache_req_v_r & cache_req_r.msg_type inside {e_amo_lr};
  wire amo_sc_v_li     = cache_req_v_r & cache_req_r.msg_type inside {e_amo_sc};
  wire amo_op_v_li     = cache_req_v_r & cache_req_r.msg_type inside {e_amo_swap, e_amo_add, e_amo_xor, e_amo_and, e_amo_or
                                                                     ,e_amo_min, e_amo_max, e_amo_minu, e_amo_maxu};

  logic [index_width_lp-1:0] index_cnt;
  logic index_up;
  bsg_counter_clear_up
    #(.max_val_p(sets_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
    index_counter
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i('0)
     ,.up_i(index_up)

     ,.count_o(index_cnt)
     );
  
  wire index_done = (index_cnt == sets_p-1);

  // Outstanding requests counter
  // Need to return credits only on load and store (cached/uncached) requests
  logic [`BSG_WIDTH(coh_noc_max_credits_p)-1:0] credit_count_lo;
  wire credit_v_li = pce_l15_req_v_o;
  wire credit_ready_li = pce_l15_req_ready_i;
  wire credit_not_returned = l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype inside {e_int_ret, e_evict_req});
  wire credit_returned_li = l15_pce_ret_yumi_o & ~credit_not_returned;
  bsg_flow_counter
    #(.els_p(coh_noc_max_credits_p))
    credit_counter
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(credit_v_li)
    ,.ready_i(credit_ready_li)

    ,.yumi_i(credit_returned_li)
    ,.count_o(credit_count_lo)
    );

  assign credits_full_o = (credit_count_lo == coh_noc_max_credits_p);
  assign credits_empty_o = (credit_count_lo == 0);

  logic l15_pce_ret_yumi_lo;
  assign l15_pce_ret_yumi_o = l15_pce_ret_yumi_lo | store_resp_v_li;

  // Assigning PCE->$ packets
  assign cache_data_mem_pkt_o = cache_data_mem_pkt_cast_o;
  assign cache_tag_mem_pkt_o = inval_v_li ? inval_cache_tag_mem_pkt_cast_o : cache_tag_mem_pkt_cast_o;
  assign cache_stat_mem_pkt_o = inval_v_li ? inval_cache_stat_mem_pkt_cast_o : cache_stat_mem_pkt_cast_o;
  
  always_comb
    begin
      cache_req_ready_o = '0;

      index_up = '0;

      cache_tag_mem_pkt_cast_o  = '0;
      inval_cache_tag_mem_pkt_cast_o = '0;
      cache_tag_mem_pkt_v_o     = '0;
      cache_data_mem_pkt_cast_o = '0;
      cache_data_mem_pkt_v_o    = '0;
      cache_stat_mem_pkt_cast_o = '0;
      inval_cache_stat_mem_pkt_cast_o = '0;
      cache_stat_mem_pkt_v_o    = '0;

      cache_req_complete_o = '0;
      
      pce_l15_req_cast_o = '0;
      pce_l15_req_v_o = '0;

      l15_pce_ret_yumi_lo = '0;
      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            l15_pce_ret_yumi_lo = (l15_pce_ret_v_i & (l15_pce_ret_cast_i.rtntype == e_int_ret));

            state_n = l15_pce_ret_yumi_lo
                          ? e_clear 
                          : e_reset;
          end
        e_clear:
          begin
            cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            cache_tag_mem_pkt_cast_o.index  = index_cnt;
            cache_tag_mem_pkt_v_o = 1'b1;

            cache_stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            cache_stat_mem_pkt_cast_o.index  = index_cnt;
            cache_stat_mem_pkt_v_o = 1'b1;

            index_up = cache_tag_mem_pkt_yumi_i & cache_stat_mem_pkt_yumi_i;

            cache_req_complete_o = (index_done & index_up);

            state_n = cache_req_complete_o 
                          ? e_ready 
                          : e_clear;
          end

        e_ready:
          begin
            cache_req_ready_o = pce_l15_req_ready_i;
            if (uc_store_v_li) begin
              pce_l15_req_cast_o.rqtype = e_store_req;
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.address = cache_req_cast_i.addr;
              pce_l15_req_cast_o.size = (cache_req_cast_i.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              // OpenPiton is big endian whereas BlackParrot is little endian
              pce_l15_req_cast_o.data = (cache_req_cast_i.size == e_size_1B)
                                    ? {8{cache_req_cast_i.data[0+:8]}}
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? {4{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8]}}}
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? {2{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                              cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8]}}}
                                        : {{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                            cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8],
                                            cache_req_cast_i.data[32+:8], cache_req_cast_i.data[40+:8],
                                            cache_req_cast_i.data[48+:8], cache_req_cast_i.data[56+:8]}};
              pce_l15_req_v_o = pce_l15_req_ready_i;
              state_n = e_ready;
            end
            else if (wt_store_v_li) begin
              pce_l15_req_cast_o.rqtype = e_store_req;
              pce_l15_req_cast_o.nc = 1'b0;
              pce_l15_req_cast_o.address = cache_req_cast_i.addr;
              pce_l15_req_cast_o.size = (cache_req_cast_i.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.data = (cache_req_cast_i.size == e_size_1B)
                                    ? {8{cache_req_cast_i.data[0+:8]}}
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? {4{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8]}}}
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? {2{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                              cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8]}}}
                                        : {{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                            cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8],
                                            cache_req_cast_i.data[32+:8], cache_req_cast_i.data[40+:8],
                                            cache_req_cast_i.data[48+:8], cache_req_cast_i.data[56+:8]}};
              pce_l15_req_v_o = pce_l15_req_ready_i;
              state_n = e_ready;
            end
            else begin
              state_n = cache_req_v_i 
                        ? e_send_req 
                        : e_ready;
            end 
          end
        
        e_send_req:
          begin
            if (miss_v_li) begin
              pce_l15_req_cast_o.rqtype = (pce_id_p == 1)
                                          ? e_load_req
                                          : e_imiss_req;

              pce_l15_req_cast_o.nc = 1'b0;
              pce_l15_req_cast_o.size = (pce_id_p == 1)
                                        ? e_l15_size_16B
                                        : e_l15_size_16B;
              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1)
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.repl_way}
                                            : cache_req_metadata_r.repl_way;
              pce_l15_req_v_o = pce_l15_req_ready_i;

              state_n = pce_l15_req_v_o
                        ? e_read_wait
                        : e_send_req;
            end
            else if (uc_load_v_li) begin
              pce_l15_req_cast_o.rqtype = (pce_id_p == 1)
                                            ? e_load_req
                                            : e_imiss_req; 
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1) 
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.repl_way}
                                            : cache_req_metadata_r.repl_way;

              pce_l15_req_v_o = pce_l15_req_ready_i;

              state_n = pce_l15_req_v_o
                        ? e_uc_read_wait
                        : e_send_req;
            end
            else if (amo_lr_v_li & (pce_id_p == 1)) begin
              pce_l15_req_cast_o.rqtype = e_amo_req; 
              pce_l15_req_cast_o.amo_op = e_amo_op_lr;
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1) 
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.repl_way}
                                            : cache_req_metadata_r.repl_way;

              pce_l15_req_v_o = pce_l15_req_ready_i;

              state_n = pce_l15_req_v_o
                        ? e_amo_lr_wait
                        : e_send_req;
            end
            else if (amo_sc_v_li & (pce_id_p == 1)) begin
              pce_l15_req_cast_o.rqtype = e_amo_req; 
              pce_l15_req_cast_o.amo_op = e_amo_op_sc;
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.data = (cache_req_r.size == e_size_1B)
                                    ? {8{cache_req_r.data[0+:8]}}
                                    : (cache_req_r.size == e_size_2B)
                                      ? {4{{cache_req_r.data[0+:8], cache_req_r.data[8+:8]}}}
                                      : (cache_req_r.size == e_size_4B)
                                        ? {2{{cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                              cache_req_r.data[16+:8], cache_req_r.data[24+:8]}}}
                                        : {{cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                            cache_req_r.data[16+:8], cache_req_r.data[24+:8],
                                            cache_req_r.data[32+:8], cache_req_r.data[40+:8],
                                            cache_req_r.data[48+:8], cache_req_r.data[56+:8]}};

              pce_l15_req_v_o = pce_l15_req_ready_i;

              state_n = pce_l15_req_v_o
                        ? e_amo_sc_wait
                        : e_send_req;
            end
            else if (amo_op_v_li & (pce_id_p == 1)) begin
              pce_l15_req_cast_o.rqtype = e_amo_req;
              // TODO: Can this be done in a more concise manner?
              pce_l15_req_cast_o.amo_op = bp_pce_l15_amo_type_e'((cache_req_r.msg_type == e_amo_swap)
                                                                  ? e_amo_op_swap
                                                                  : (cache_req_r.msg_type == e_amo_add)
                                                                  ? e_amo_op_add
                                                                  : (cache_req_r.msg_type == e_amo_and)
                                                                  ? e_amo_op_and
                                                                  : (cache_req_r.msg_type == e_amo_or)
                                                                  ? e_amo_op_or
                                                                  : (cache_req_r.msg_type == e_amo_xor)
                                                                  ? e_amo_op_xor
                                                                  : (cache_req_r.msg_type == e_amo_max)
                                                                  ? e_amo_op_max
                                                                  : (cache_req_r.msg_type == e_amo_min)
                                                                  ? e_amo_op_min
                                                                  : (cache_req_r.msg_type == e_amo_maxu)
                                                                  ? e_amo_op_maxu
                                                                  : (cache_req_r.msg_type == e_amo_minu)
                                                                  ? e_amo_op_minu
                                                                  : e_amo_op_none);

              // Fetch + Op atomics need to have the nc bit set
              pce_l15_req_cast_o.nc = 1'b1;
              pce_l15_req_cast_o.size = (cache_req_r.size == e_size_1B)
                                    ? e_l15_size_1B
                                    : (cache_req_r.size == e_size_2B)
                                      ? e_l15_size_2B
                                      : (cache_req_r.size == e_size_4B)
                                        ? e_l15_size_4B
                                        : e_l15_size_8B;

              pce_l15_req_cast_o.address = cache_req_r.addr;
              pce_l15_req_cast_o.data = (cache_req_r.size == e_size_1B)
                                    ? {8{cache_req_r.data[0+:8]}}
                                    : (cache_req_r.size == e_size_2B)
                                      ? {4{{cache_req_r.data[0+:8], cache_req_r.data[8+:8]}}}
                                      : (cache_req_r.size == e_size_4B)
                                        ? {2{{cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                              cache_req_r.data[16+:8], cache_req_r.data[24+:8]}}}
                                        : {{cache_req_r.data[0+:8], cache_req_r.data[8+:8], 
                                            cache_req_r.data[16+:8], cache_req_r.data[24+:8],
                                            cache_req_r.data[32+:8], cache_req_r.data[40+:8],
                                            cache_req_r.data[48+:8], cache_req_r.data[56+:8]}};

              pce_l15_req_cast_o.l1rplway = (pce_id_p == 1) 
                                            ? {cache_req_r.addr[11], cache_req_metadata_r.repl_way}
                                            : cache_req_metadata_r.repl_way;

              pce_l15_req_v_o = pce_l15_req_ready_i;
              state_n = pce_l15_req_v_o
                        ? e_amo_op_wait
                        : e_send_req;
            end
          end

        e_uc_read_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_ifill_ret_nc && (pce_id_p == 0)) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              // TODO: This might need some work (especially for SD cards)
              // based on how OP does this. 
              cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                               ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                  l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                  l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]}   
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;
              
              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o 
                            ? e_ready 
                            : e_uc_read_wait;
            end
            else if (is_load_ret_nc && pce_id_p == 1) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              // TODO: This might need some work (especially for SD cards)
              // based on how OP does this. 
              cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                               ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                  l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                  l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]} 
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_uc_read_wait;
            end
            else begin
              state_n = e_uc_read_wait;
            end
          end
        
        e_amo_lr_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_amo_lrsc_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_amo;
              // TODO: This might need some work based on how OP does this. 
              cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                               ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                  l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                  l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]}   
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_amo_lr_wait;
            end
            else begin
              state_n = e_amo_lr_wait;
            end
          end
        
        e_amo_sc_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_amo_lrsc_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_amo;
              // Size for an atomic operation is either 32 bits or 64 bits. SC
              // returns either a 0 or 1
              cache_data_mem_pkt_cast_o.data = (cache_req_r.size == e_size_4B) 
                                               ? {32'b0, l15_pce_ret_cast_i.data_0[0+:8], l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8]}
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]};
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_amo_sc_wait;
            end
            else begin
              state_n = e_amo_sc_wait;
            end
          end

        e_amo_op_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (is_amo_op_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_amo;
              // TODO: This might need some work based on how OP does this. 
              cache_data_mem_pkt_cast_o.data = (cache_req_r.addr[3] == 1'b1)
                                               ? {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                  l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                  l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                  l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8]}   
                                               : {l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                  l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                  l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                  l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i;

              state_n = cache_req_complete_o
                            ? e_ready 
                            : e_amo_op_wait;
            end
            else begin
              state_n = e_amo_op_wait;
            end
          end

        e_read_wait:
          begin
            // Checking for return types here since we could also have
            // invalidations coming in at anytime
            if (is_ifill_ret && (pce_id_p == 0)) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              cache_data_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_data_mem_pkt_cast_o.data = {l15_pce_ret_cast_i.data_3[0+:8],  l15_pce_ret_cast_i.data_3[8+:8],
                                                l15_pce_ret_cast_i.data_3[16+:8], l15_pce_ret_cast_i.data_3[24+:8],
                                                l15_pce_ret_cast_i.data_3[32+:8], l15_pce_ret_cast_i.data_3[40+:8],
                                                l15_pce_ret_cast_i.data_3[48+:8], l15_pce_ret_cast_i.data_3[56+:8],
                                                l15_pce_ret_cast_i.data_2[0+:8],  l15_pce_ret_cast_i.data_2[8+:8],       
                                                l15_pce_ret_cast_i.data_2[16+:8], l15_pce_ret_cast_i.data_2[24+:8],
                                                l15_pce_ret_cast_i.data_2[32+:8], l15_pce_ret_cast_i.data_2[40+:8],
                                                l15_pce_ret_cast_i.data_2[48+:8], l15_pce_ret_cast_i.data_2[56+:8],
                                                l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8],       
                                                l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};   
              cache_data_mem_pkt_cast_o.fill_index = 1'b1;
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              cache_tag_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
              cache_tag_mem_pkt_cast_o.state = e_COH_M;
              cache_tag_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;

              state_n = cache_req_complete_o 
                              ? e_ready 
                              : e_read_wait;
            end
            if (is_load_ret && (pce_id_p == 1)) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              cache_data_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_data_mem_pkt_cast_o.data = {l15_pce_ret_cast_i.data_1[0+:8],  l15_pce_ret_cast_i.data_1[8+:8],    
                                                l15_pce_ret_cast_i.data_1[16+:8], l15_pce_ret_cast_i.data_1[24+:8],
                                                l15_pce_ret_cast_i.data_1[32+:8], l15_pce_ret_cast_i.data_1[40+:8],
                                                l15_pce_ret_cast_i.data_1[48+:8], l15_pce_ret_cast_i.data_1[56+:8],       
                                                l15_pce_ret_cast_i.data_0[0+:8],  l15_pce_ret_cast_i.data_0[8+:8],    
                                                l15_pce_ret_cast_i.data_0[16+:8], l15_pce_ret_cast_i.data_0[24+:8],
                                                l15_pce_ret_cast_i.data_0[32+:8], l15_pce_ret_cast_i.data_0[40+:8],
                                                l15_pce_ret_cast_i.data_0[48+:8], l15_pce_ret_cast_i.data_0[56+:8]};
              cache_data_mem_pkt_cast_o.fill_index = 1'b1;
              cache_data_mem_pkt_v_o = l15_pce_ret_v_i;

              cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              cache_tag_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
              cache_tag_mem_pkt_cast_o.state = e_COH_M;
              cache_tag_mem_pkt_v_o = l15_pce_ret_v_i;

              l15_pce_ret_yumi_lo = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;
              cache_req_complete_o = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;

              state_n = cache_req_complete_o 
                              ? e_ready 
                              : e_read_wait;
            end 
          end
        default: state_n = e_reset;
      endcase

      // Need to support invalidations no matter what
      // Supporting inval all way and single way for both caches. OpenPiton
      // doesn't support inval all way for dcache and inval specific way for
      // icache
      if (inval_v_li) begin
        if (((pce_id_p == 0) && l15_pce_ret_cast_i.inval_icache_inval) || ((pce_id_p == 1) && l15_pce_ret_cast_i.inval_dcache_inval)) begin
          inval_cache_tag_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_pce_ret_cast_i.inval_way[1], l15_pce_ret_cast_i.inval_address_15_4[6:0]} 
                                                  : l15_pce_ret_cast_i.inval_address_15_4[7:1];
          inval_cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_invalidate;
          inval_cache_tag_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_pce_ret_cast_i.inval_way[0] 
                                                  : l15_pce_ret_cast_i.inval_way;
          cache_tag_mem_pkt_v_o = l15_pce_ret_v_i;

          l15_pce_ret_yumi_lo = cache_tag_mem_pkt_yumi_i;
        end
        else if (((pce_id_p == 0) && l15_pce_ret_cast_i.inval_icache_all_way) || ((pce_id_p == 1) && l15_pce_ret_cast_i.inval_dcache_all_way)) begin
          inval_cache_tag_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_pce_ret_cast_i.inval_way[1], l15_pce_ret_cast_i.inval_address_15_4[6:0]} 
                                                  : l15_pce_ret_cast_i.inval_address_15_4[7:1];
          inval_cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
          inval_cache_tag_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_pce_ret_cast_i.inval_way[0] 
                                                  : l15_pce_ret_cast_i.inval_way;
          cache_tag_mem_pkt_v_o = l15_pce_ret_v_i;
          
          inval_cache_stat_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_pce_ret_cast_i.inval_way[1], l15_pce_ret_cast_i.inval_address_15_4[6:0]} 
                                                  : l15_pce_ret_cast_i.inval_address_15_4[7:1];
          inval_cache_stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
          inval_cache_stat_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_pce_ret_cast_i.inval_way[0] 
                                                  : l15_pce_ret_cast_i.inval_way;

          cache_stat_mem_pkt_v_o = l15_pce_ret_v_i;

          l15_pce_ret_yumi_lo = cache_tag_mem_pkt_yumi_i & cache_stat_mem_pkt_yumi_i;
        end
      end
      
    end
    
  always_ff @(posedge clk_i)
    begin
      if(reset_i) begin
        state_r <= e_reset;
      end
      else begin
        state_r <= state_n;
      end
    end

endmodule
