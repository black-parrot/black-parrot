// This module describes the P-Mesh Cache Engine (PCE) which is the interface
// between the L1 Caches of BlackParrot and the L1.5 Cache of OpenPiton

module bp_pce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_pce_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    parameter block_width_p = dcache_block_width_p
    parameter assoc_p = dcache_assoc_p
    parameter sets_p = dcache_sets_p
    parameter pce_id_p = 1 
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, cache);
   
   // Cache parameters
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(assoc_p)
   , localparam index_width_lp = `BSG_SAFE_CLOG2(sets_p)
   , localparam way_width_lp = `BSG_SAFE_CLOG2(assoc_p)

   )
  ( input                                       clk_i
  , input                                       reset_i

  // Cache side
  , input [cache_req_width_lp-1:0]              cache_req_i
  , input                                       cache_req_v_i
  , output                                      cache_req_ready_o
  , input [cache_req_metadata_width_lp-1:0]     cache_req_metadata_i
  , input                                       cache_req_metadata_v_i
  , output                                      cache_req_complete_o

  // I-Cache side
  , output                                      sync_o
  , output [cache_data_mem_pkt_width_lp-1:0]    cache_data_mem_pkt_o
  , output                                      cache_data_mem_pkt_v_o
  , input                                       cache_data_mem_pkt_yumi_i

  , output [cache_tag_mem_pkt_width_lp-1:0]     cache_tag_mem_pkt_o
  , output                                      cache_tag_mem_pkt_v_o
  , input                                       cache_tag_mem_pkt_yumi_i

  , output [cache_stat_mem_pkt_width_lp-1:0]    cache_stat_mem_pkt_o
  , output                                      cache_stat_mem_pkt_v_o
  , input                                       cache_stat_mem_pkt_yumi_i

  // PCE -> L1.5
  , output logic [4:0]                          transducer_l15_rqtype
  , output logic                                transducer_l15_nc
  , output logic [2:0]                          transducer_l15_size
  , output logic                                transducer_l15_val
  , output logic [39:0]                         transducer_l15_address
  , output logic [63:0]                         transducer_l15_data
  , output logic [1:0]                          transducer_l15_l1rplway
  , output logic [2:0]                          transducer_l15_threadid
  , input                                       l15_transducer_ack

  // L1.5 -> PCE
  , input                                       l15_transducer_val
  , input [3:0]                                 l15_transducer_returntype
  , input                                       l15_transducer_noncacheable
  , input [63:0]                                l15_transducer_data_0
  , input [63:0]                                l15_transducer_data_1
  , input [63:0]                                l15_transducer_data_2
  , input [63:0]                                l15_transducer_data_3
  , input [2:0]                                 l15_transducer_threadid
  // TODO: OpenPiton defines this as [15:4]. Will this redefinition break things?
  , input [11:0]                                l15_transducer_inval_address_15_4
  , input                                       l15_transducer_inval_icache_inval
  , input                                       l15_transducer_inval_icache_all_way
  , input                                       l15_transducer_inval_dcache_inval
  , input                                       l15_transducer_inval_dcache_all_way
  , input [1:0]                                 l15_transducer_inval_way
  , output logic                                transducer_l15_req_ack
  );

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, cache);

  bp_cache_req_s cache_req_cast_i;
  bp_cache_req_metadata_s cache_req_metadata_cast_i;

  bp_cache_data_mem_pkt_s cache_data_mem_pkt_cast_o;
  bp_cache_tag_mem_pkt_s cache_tag_mem_pkt_cast_o;
  bp_cache_stat_mem_pkt_s cache_stat_mem_pkt_cast_o;

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

  enum logic [2:0] {e_reset, e_clear, e_ready, e_send_req, e_uc_read_wait, e_read_wait} state_n, state_r;

  wire uc_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire wt_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};

  // TODO: Check return types
  // TODO: Update once we create structures
  wire store_resp_v_li = l15_transducer_val & (l15_transducer_returntype == e_st_ack);
  wire load_resp_v_li  = l15_transducer_val & l15_transducer_returntype inside {e_load_ret, e_ifill_ret};
  wire inval_v_li      = l15_transducer_val & l15_transducer_returntype inside {e_evict_req};

  wire miss_load_v_li  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};

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

  logic transducer_l15_req_ack_lo;
  assign transducer_l15_req_ack = transducer_l15_req_ack_lo | store_resp_v_li;

  always_comb
    begin
      cache_req_ready_o = '0;

      index_up = '0;
      index_clr = '0;
      sync_o = '0;

      cache_tag_mem_pkt_cast_o  = '0;
      cache_tag_mem_pkt_v_o     = '0;
      cache_data_mem_pkt_cast_o = '0;
      cache_data_mem_pkt_v_o    = '0;
      cache_stat_mem_pkt_cast_o = '0;
      cache_stat_mem_pkt_v_o    = '0;

      cache_req_complete_o = '0;
      
      transducer_l15_threadid = '0;
      transducer_l15_rqtype = '0;
      transducer_l15_nc = '0;
      transducer_l15_size = '0;
      transducer_l15_address = '0;
      transducer_l15_data = '0;
      transducer_l15_l1rplway = '0;
      transducer_l15_val = '0;

      transducer_l15_req_ack_lo = '0;
      state_n = state_r;

      // Need to support invalidations no matter what
      // Supporting inval all way and single way for both caches. OpenPiton
      // doesn't support inval all way for dcache and inval specific way for
      // icache
      if (inval_v_li) begin
        if (l15_transducer_inval_icache_inval || l15_transducer_inval_dcache_inval) begin
          cache_tag_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_transducer_inval_way[1], l15_transducer_inval_address_15_4[6:0]} 
                                                  : l15_transducer_inval_address_15_4[6:0];
          cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_invalidate;
          cache_tag_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_transducer_inval_way[0] 
                                                  : l15_transducer_inval_way;
          cache_tag_mem_pkt_v_o = 1'b1;

          transducer_l15_req_ack_lo = cache_tag_mem_pkt_yumi_i;
        end

        if (l15_transducer_inval_icache_all_way || l15_transducer_inval_dcache_all_way) begin
          cache_tag_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_transducer_inval_way[1], l15_transducer_inval_address_15_4[6:0]} 
                                                  : l15_transducer_inval_address_15_4[6:0];
          cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
          cache_tag_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_transducer_inval_way[0] 
                                                  : l15_transducer_inval_way;
          cache_tag_mem_pkt_v_o = 1'b1;
          
          // Do we need to clear stat mem also?
          cache_stat_mem_pkt_cast_o.index = (pce_id_p == 1) 
                                                  ? {l15_transducer_inval_way[1], l15_transducer_inval_address_15_4[6:0]} 
                                                  : l15_transducer_inval_address_15_4[6:0];
          cache_stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
          cache_stat_mem_pkt_cast_o.way_id = (pce_id_p == 1) 
                                                  ? l15_transducer_inval_way[0] 
                                                  : l15_transducer_inval_way;

          cache_stat_mem_pkt_v_o = 1'b1;

          transducer_l15_req_ack_lo = cache_tag_mem_pkt_yumi_i & cache_stat_mem_pkt_yumi_i;
        end
      end

      unique case (state_r)
        e_reset:
          begin
            transducer_l15_req_ack_lo = (l15_transducer_val & (l15_transducer_returntype == e_int_ret));

            state_n = transducer_l15_req_ack_lo 
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
            // TODO: Need to accommodate the ready/yumi signal from the fifo
            if (uc_store_v_li) begin
              transducer_l15_rqtype = e_store_req;
              transducer_l15_nc = 1'b1;
              transducer_l15_address = cache_req_cast_i.addr;
              // TODO: Check if the size mapping used here will work.
              // Something tells me it won't.
              transducer_l15_size = (cache_req_cast_i.size == e_size_1B)
                                    ? e_size_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? e_size_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? e_size_4B
                                        : e_size_8B;

              // OpenPiton is big endian whereas BlackParrot is little endian
              transducer_l15_data = (cache_req_cast_i.size == e_size_1B)
                                    ? {8{cache_req_cast_i.data[0+:8]}}
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? {4{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8]}}}
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? {2{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                              cache_req_cast_i.data[16+:8], cache_req_cast_i[24+:8]}}}
                                        : {{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                            cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8],
                                            cache_req_cast_i.data[32+:8], cache_req_cast_i.data[40+:8],
                                            cache_req_cast_i.data[48+:8], cache_req_cast_i.data[56+:8]}};
              transducer_l15_val = 1'b1;
              state_n = e_ready;
            end
            // TODO: Check if we need l1rplway for writethrough stores.
            // Actually, do we need to worry about l1rplway for stores?
            else if (wt_store_v_li) begin
              transducer_l15_rqtype = e_store_req;
              transducer_l15_nc = 1'b0;
              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_size = (cache_req_cast_i.size == e_size_1B)
                                    ? e_size_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? e_size_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? e_size_4B
                                        : e_size_8B;

              transducer_l15_data = (cache_req_cast_i.size == e_size_1B)
                                    ? {8{cache_req_cast_i.data[0+:8]}}
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? {4{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8]}}}
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? {2{{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                              cache_req_cast_i.data[16+:8], cache_req_cast_i[24+:8]}}}
                                        : {{cache_req_cast_i.data[0+:8], cache_req_cast_i.data[8+:8], 
                                            cache_req_cast_i.data[16+:8], cache_req_cast_i.data[24+:8],
                                            cache_req_cast_i.data[32+:8], cache_req_cast_i.data[40+:8],
                                            cache_req_cast_i.data[48+:8], cache_req_cast_i.data[56+:8]}};
              transducer_l15_val = 1'b1;
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
              transducer_l15_rqtype = (pce_id_p == 1)
                                          ? e_load_req
                                          : e_imiss_req;

              transducer_l15_nc = 1'b0;
              transducer_l15_size = (pce_id_p == 1)
                                        ? e_size_8B
                                        : e_size_16B;
              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_l1rplway = (pce_id_p == 1)
                                            ? {cache_req_cast_i.addr[11], cache_req_metadata_cast_i.repl_way}
                                            : cache_req_metadata_cast_i.reply_way;
              transducer_l15_val = 1'b1;

              state_n = l15_transducer_ack
                        ? e_read_wait
                        : e_send_req;
            end
            else if (uc_load_v_li) begin
              transducer_l15_rqtype = (pce_id_p == 1)
                                            ? e_load_req
                                            : e_imiss_req; 
              transducer_l15_nc = 1'b1;
              transducer_l15_size = (cache_req_cast_i.size == e_size_1B)
                                    ? e_size_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? e_size_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? e_size_4B
                                        : e_size_8B;

              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_l1rplway = (pce_id_p == 1) 
                                            ? {cache_req_cast_i.addr[11], cache_req_metadata_cast_i.repl_way}
                                            : cache_req_metadata_cast_i.reply_way;

              transducer_l15_val = 1'b1;

              state_n = l15_transducer_ack
                        ? e_uc_read_wait
                        : e_send_req;
            end
        e_uc_read_wait:
          begin
            // Checking for the return type here since we could be in this
            // state when we receive an invalidation
            if (l15_transducer_returntype == e_ifill_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              cache_data_mem_pkt_cast_o.data = // TODO: We need to send back 64 bits. Which set of 64 bits do we use?
              cache_data_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = icache_data_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo 
                            ? e_ready 
                            : e_uc_read_wait;
            end
            else if (l15_transducer_returntype == e_load_ret) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              cache_data_mem_pkt_cast_o.data = //TODO: We need to send back 64 bits. Which set of 64 bits do we use?
              cache_data_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = cache_data_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo ? e_ready : e_uc_read_wait;
            end
          end
        
        e_read_wait:
          begin
            // TODO: Remember IFILL_RET needs to be acknowledged the next cycle
            // Checking for return types here since we could also have
            // invalidations coming in at anytime
            if (l15_transducer_returntype == e_ifill_ret && (pce_id_p == 0)) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              cache_data_mem_pkt_cast_o.index = cache_req_r.addr[icache_block_offset_width_lp+:icache_index_width_lp];
              cache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_data_mem_pkt_cast_o.data = {l15_transducer_data_3[0+:8], l15_transducer_data_3[8+:8],
                                                l15_transducer_data_3[16+:8], l15_transducer_data_3[24+:8],
                                                l15_transducer_data_3[32+:8], l15_transducer_data_3[40+:8],
                                                l15_transducer_data_3[48+:8], l15_transducer_data_3[56+:8],
                                                l15_transducer_data_2[0+:8], l15_transducer_data_2[8+:8],       
                                                l15_transducer_data_2[16+:8], l15_transducer_data_2[24+:8],
                                                l15_transducer_data_2[32+:8], l15_transducer_data_2[40+:8],
                                                l15_transducer_data_2[48+:8], l15_transducer_data_2[56+:8],
                                                l15_transducer_data_1[0+:8], l15_transducer_data_1[8+:8],    
                                                l15_transducer_data_1[16+:8], l15_transducer_data_1[24+:8],
                                                l15_transducer_data_1[32+:8], l15_transducer_data_1[40+:8],
                                                l15_transducer_data_1[48+:8], l15_transducer_data_1[56+:8],       
                                                l15_transducer_data_0[0+:8], l15_transducer_data_0[8+:8],    
                                                l15_transducer_data_0[16+:8], l15_transducer_data_0[24+:8],
                                                l15_transducer_data_0[32+:8], l15_transducer_data_0[40+:8],
                                                l15_transducer_data_0[48+:8], l15_transducer_data_0[56+:8]};   
              cache_data_mem_pkt_v_o = l15_transducer_val;

              cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              cache_tag_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
              cache_tag_mem_pkt_cast_o.state = e_COH_M;
              cache_tag_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo 
                              ? e_ready 
                              : e_read_wait;
            end
            if (l15_transducer_returntype == e_load_ret && (pce_id_p == 1)) begin
              cache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              cache_data_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_data_mem_pkt_cast_o.data = {l15_transducer_data_1[0+:8], l15_transducer_data_1[8+:8],    
                                                l15_transducer_data_1[16+:8], l15_transducer_data_1[24+:8],
                                                l15_transducer_data_1[32+:8], l15_transducer_data_1[40+:8],
                                                l15_transducer_data_1[48+:8], l15_transducer_data_1[56+:8],       
                                                l15_transducer_data_0[0+:8], l15_transducer_data_0[8+:8],    
                                                l15_transducer_data_0[16+:8], l15_transducer_data_0[24+:8],
                                                l15_transducer_data_0[32+:8], l15_transducer_data_0[40+:8],
                                                l15_transducer_data_0[48+:8], l15_transducer_data_0[56+:8]};
              cache_data_mem_pkt_v_o = l15_transducer_val;

              cache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              cache_tag_mem_pkt_cast_o.index = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              cache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              cache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
              cache_tag_mem_pkt_cast_o.state = e_COH_M;
              cache_tag_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = cache_data_mem_pkt_yumi_i & cache_tag_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo 
                              ? e_ready 
                              : e_read_wait;
            end 
          end
        default: state_n = e_reset;
      endcase
    end
    
  always_ff @(posedge clk_i)
    begin
      if(reset_i) begin
        state_n <= e_reset;
      end
      else begin
        state_n <= state_r;
      end
    end

endmodule
