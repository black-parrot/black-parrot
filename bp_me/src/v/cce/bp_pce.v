// This module describes the Piton Cache Engine (PCE) which is the interface
// between the L1 D-Cache of BlackParrot and the L1.5 D-Cache of OpenPiton

//TODO: Import package for OpenPiton
module bp_pce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   
   // I-Cache parameters
   , localparam icache_bank_width_lp = icache_block_width_p / icache_assoc_p
   , localparam icache_num_dwords_per_bank_lp = icache_bank_width_lp / dword_width_p
   , localparam icache_byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam icache_word_offset_width_lp = `BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam icache_index_width_lp = `BSG_SAFE_CLOG2(icache_sets_p)
   , localparam icache_way_width_lp = `BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam icache_req_width_lp = `bp_cache_req_width(dword_width_p, paddr_width_p)
   , localparam icache_req_metadata_width_lp = `bp_cache_req_metadata_width(icache_assoc_p)
   , localparam icache_tag_mem_pkt_width_lp = `bp_cache_tag_mem_pkt_width(icache_sets_p, icache_assoc_p, ptag_width_p)
   , localparam icache_data_mem_pkt_width_lp = `bp_cache_data_mem_pkt_width(icache_sets_p, icache_assoc_p, icache_block_width_p)
   , localparam icache_stat_mem_pkt_width_lp = `bp_cache_stat_mem_pkt_width(icache_sets_p, icache_assoc_p)

   // D-Cache parameters
   , localparam dcache_bank_width_lp = dcache_block_width_p / dcache_assoc_p
   , localparam dcache_num_dwords_per_bank_lp = dcache_bank_width_lp / dword_width_p
   , localparam dcache_byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam dcache_word_offset_width_lp = `BSG_SAFE_CLOG2(dcache_assoc_p)
   , localparam dcache_index_width_lp = `BSG_SAFE_CLOG2(dcache_sets_p)
   , localparam dcache_way_width_lp = `BSG_SAFE_CLOG2(dcache_assoc_p)
   , localparam dcache_req_width_lp = `bp_cache_req_width(dword_width_p, paddr_width_p)
   , localparam dcache_req_metadata_width_lp = `bp_cache_req_metadata_width(dcache_assoc_p)
   , localparam dcache_tag_mem_pkt_width_lp = `bp_cache_tag_mem_pkt_width(dcache_sets_p, dcache_assoc_p, ptag_width_p)
   , localparam dcache_data_mem_pkt_width_lp = `bp_cache_data_mem_pkt_width(dcache_sets_p, dcache_assoc_p, dcache_block_width_p)
   , localparam dcache_stat_mem_pkt_width_lp = `bp_cache_stat_mem_pkt_width(dcache_sets_p, dcache_assoc_p)

   )
  (input                                        clk_i
  , input                                       reset_i

  // Cache -> PCE
  
  // I-Cache side
  , input [icache_req_width_lp-1:0]             icache_req_i
  , input                                       icache_req_v_i
  , output                                      icache_req_ready_o
  , input [icache_req_metadata_width_lp-1:0]    icache_req_metadata_i
  , input                                       icache_req_metadata_v_i
  , output                                      icache_req_complete_o

  // D-Cache side
  , input [dcache_req_width_lp-1:0]             dcache_req_i
  , input                                       dcache_req_v_i
  , output                                      dcache_req_ready_o
  , input [dcache_req_metadata_width_lp-1:0]    dcache_req_metadata_i
  , input                                       dcache_req_metadata_v_i
  , output                                      dcache_req_complete_o
  
  // PCE -> Cache

  // I-Cache side
  , output                                      isync_o
  , output [icache_data_mem_pkt_width_lp-1:0]   icache_data_mem_pkt_o
  , output                                      icache_data_mem_pkt_v_o
  , input                                       icache_data_mem_pkt_yumi_i

  , output [icache_tag_mem_pkt_width_lp-1:0]    icache_tag_mem_pkt_o
  , output                                      icache_tag_mem_pkt_v_o
  , input                                       icache_tag_mem_pkt_yumi_i

  , output [icache_stat_mem_pkt_width_lp-1:0]   icache_stat_mem_pkt_o
  , output                                      icache_stat_mem_pkt_v_o
  , input                                       icache_stat_mem_pkt_yumi_i

  // D-Cache side
  , output                                      dsync_o
  , output [dcache_data_mem_pkt_width_lp-1:0]   dcache_data_mem_pkt_o
  , output                                      dcache_data_mem_pkt_v_o
  , input                                       dcache_data_mem_pkt_yumi_i

  , output [dcache_tag_mem_pkt_width_lp-1:0]    dcache_tag_mem_pkt_o
  , output                                      dcache_tag_mem_pkt_v_o
  , input                                       dcache_tag_mem_pkt_yumi_i

  , output [dcache_stat_mem_pkt_width_lp-1:0]   dcache_stat_mem_pkt_o
  , output                                      dcache_stat_mem_pkt_v_o
  , input                                       dcache_stat_mem_pkt_yumi_i

  // PCE -> L1.5
  , output logic [4:0]                          transducer_l15_rqtype
  , output logic                                transducer_l15_nc
  , output logic [2:0]                          transducer_l15_size
  , output logic                                transducer_l15_val
  , output logic [39:0]                         transducer_l15_address
  , output logic [63:0]                         transducer_l15_data
  , output logic [1:0]                          transducer_l15_l1rplway
  , input                                       l15_transducer_ack

  // L1.5 -> PCE
  , input                                       l15_transducer_val
  , input [3:0]                                 l15_transducer_returntype
  , input [63:0]                                l15_transducer_data_0
  , input [63:0]                                l15_transducer_data_1
  , input [63:0]                                l15_transducer_data_2
  , input [63:0]                                l15_transducer_data_3
  , output logic                                transducer_l15_req_ack
  );

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);
  // The one below is just used for the request structures so we don't care
  // about the sets, assoc and block_width
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, cache);
  //`declare_bp_cache_stat_info_s(icache_assoc_p, icache);
  //`declare_bp_cache_stat_info_s(dcache_assoc_p, dcache);

  bp_cache_req_s cache_req_cast_i;
  bp_cache_req_metadata_s cache_req_metadata_cast_i;

  bp_icache_data_mem_pkt_s icache_data_mem_pkt_cast_o;
  bp_icache_tag_mem_pkt_s icache_tag_mem_pkt_cast_o;
  bp_icache_stat_mem_pkt_s icache_stat_mem_pkt_cast_o;

  bp_dcache_data_mem_pkt_s dcache_data_mem_pkt_cast_o;
  bp_dcache_tag_mem_pkt_s dcache_tag_mem_pkt_cast_o;
  bp_dcache_stat_mem_pkt_s dcache_stat_mem_pkt_cast_o;

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

  enum logic [2:0] {e_reset, e_i_clear, e_d_clear, e_ready, e_send_req, e_uc_read_wait, e_read_wait} state_n, state_r;

  wire uc_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire wt_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};

  //TODO: Check return types
  wire store_resp_v_li = l15_transducer_val & (l15_transducer_returntype == `ST_ACK);
  wire load_resp_v_li  = l15_transducer_val & l15_transducer_returntype inside {`LOAD_RET, `IFLL_RET};
  wire inval_v_li      = l15_transducer_val & l15_transducer_returntype inside {`EVICT_REQ};

  wire miss_load_v_li  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};

  logic [dcache_index_width_lp-1:0] index_cnt;
  logic index_up, index_clr;
  bsg_counter_clear_up
    #(.max_val_p(dcache_sets_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
    index_counter
     (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(index_clr)
     ,.up_i(index_up)

     ,.count_o(index_cnt)
     );
  
  wire index_done = (index_cnt == dcache_sets_p-1);

  logic transducer_l15_req_ack_lo;
  assign transducer_l15_req_ack = transducer_l15_req_ack_lo | store_resp_v_li;

  always_comb
    begin
      cache_req_ready_o = '0;

      index_up = '0;
      index_clr = '0;
      isync_o = '0;
      dsync_o = '0;

      icache_tag_mem_pkt_cast_o  = '0;
      icache_tag_mem_pkt_v_o     = '0;
      icache_data_mem_pkt_cast_o = '0;
      icache_data_mem_pkt_v_o    = '0;
      icache_stat_mem_pkt_cast_o = '0;
      icache_stat_mem_pkt_v_o    = '0;

      dcache_tag_mem_pkt_cast_o  = '0;
      dcache_tag_mem_pkt_v_o     = '0;
      dcache_data_mem_pkt_cast_o = '0;
      dcache_data_mem_pkt_v_o    = '0;
      dcache_stat_mem_pkt_cast_o = '0;
      dcache_stat_mem_pkt_v_o    = '0;

      icache_req_complete_o = '0;
      dcache_req_complete_o = '0;

      transducer_l15_rqtype = '0;
      transducer_l15_nc = '0;
      transducer_l15_size = '0;
      transducer_l15_address = '0;
      transducer_l15_data = '0;
      transducer_l15_l1rplway = '0;
      transducer_l15_val = '0;

      transducer_l15_req_ack_lo = '0;
      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            transducer_l15_req_ack_lo = (l15_transducer_val & (l15_transducer_returntype == `INT_RET));

            state_n = transducer_l15_req_ack_lo ? e_i_clear : e_reset;
          end

        e_i_clear:
          begin
            icache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            icache_tag_mem_pkt_cast_o.index  = index_cnt;
            icache_tag_mem_pkt_v_o = 1'b1;

            icache_stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            icache_stat_mem_pkt_cast_o.index  = index_cnt;
            icache_stat_mem_pkt_v_o = 1'b1;

            index_up = icache_tag_mem_pkt_yumi_i & icache_stat_mem_pkt_yumi_i;

            icache_req_complete_o = ((index_cnt == 8'd127) & index_up);
            index_clr = (index_cnt == 8'd127) & index_up;

            state_n = icache_req_complete_o ? e_d_clear : e_i_clear;
          end

        e_d_clear:
          begin
            dcache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            dcache_tag_mem_pkt_cast_o.index  = index_cnt;
            dcache_tag_mem_pkt_v_o = 1'b1;

            dcache_stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            dcache_stat_mem_pkt_cast_o.index  = index_cnt;
            dcache_stat_mem_pkt_v_o = 1'b1;

            index_up = dcache_tag_mem_pkt_yumi_i & dcache_stat_mem_pkt_yumi_i;

            dcache_req_complete_o = index_done & index_up;
            index_clr = index_done;

            state_n = dcache_req_complete_o ? e_ready : e_d_clear;
          end

        e_ready:
          begin
            // TODO: Need to accommodate the ready/yumi signal from the fifo
            if (uc_store_v_li) begin
              transducer_l15_rqtype = `STORE_RQ;
              transducer_l15_nc = 1'b1;
              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_size = (cache_req_cast_i.size == e_size_1B)
                                    ? `PCX_SZ_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? `PCX_SZ_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? `PCX_SZ_4B
                                        : `PCX_SZ_8B;
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
            //TODO: Check if we need l1rplway for writethrough stores
            if (wt_store_v_li) begin
              transducer_l15_rqtype = `STORE_RQ;
              transducer_l15_nc = 1'b0;
              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_size = (cache_req_cast_i.size == e_size_1B)
                                    ? `PCX_SZ_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? `PCX_SZ_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? `PCX_SZ_4B
                                        : `PCX_SZ_8B;
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
            //TODO: What about inval_all_ways
            if (l15_transducer_inval_icache_inval) begin
              icache_tag_mem_pkt_cast_o.index = l15_transducer_inval_address_15_4[10:4];
              icache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_invalidate;
              icache_tag_mem_pkt_cast_o.way_id = l15_transducer_inval_way;
              icache_tag_mem_pkt_v_o = 1'b1;

              transducer_l15_req_ack_lo = icache_tag_mem_pkt_yumi_i;

              state_n = e_ready;
            end

            if (l15_transducer_inval_dcache_inval) begin
              dcache_tag_mem_pkt_cast_o.index = {l15_transducer_inval_way[1], l15_transducer_inval_address_15_4[10:4]};
              dcache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_invalidate;
              dcache_tag_mem_pkt_cast_o.way_id = l15_transducer_inval_way[0];
              dcache_tag_mem_pkt_v_o = 1'b1;

              transducer_l15_req_ack_lo = dcache_tag_mem_pkt_yumi_i;

              state_n = e_ready;
            end
            //TODO: Can we use miss_v_li for this?
            if (cache_req_v_i & cache_req_cast_i.req_type inside {e_miss_load, e_miss_store}) begin
              state_n = e_send_req;
            end 
            else begin
              state_n = e_ready;
            end
          end
        
        e_send_req:
          begin
            //TODO: After adding the arbiter, use the one hot signal to distinguish
            //between I$ and D$
            if (uc_load_v_li) begin
              transducer_l15_rqtype = `LOAD_RQ;
              transducer_l15_nc = 1'b1;
              transducer_l15_size = (cache_req_cast_i.size == e_size_1B)
                                    ? `PCX_SZ_1B
                                    : (cache_req_cast_i.size == e_size_2B)
                                      ? `PCX_SZ_2B
                                      : (cache_req_cast_i.size == e_size_4B)
                                        ? `PCX_SZ_4B
                                        : `PCX_SZ_8B;
              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_l1rplway = {cache_req_cast_i.addr[11], cache_req_metadata_cast_i.repl_way};
              transducer_l15_val = 1'b1;

              state_n = l15_transducer_ack
                        ? e_uc_read_wait
                        : e_send_req;
            end

            if (miss_v_li) begin
              transducer_l15_rqtype = `LOAD_RQ;
              transducer_l15_nc = 1'b0;
              transducer_l15_size = `PCX_SZ_8B; // TODO: Fix this for I$ after adding arbiter
              transducer_l15_address = cache_req_cast_i.addr;
              transducer_l15_l1rplway = {cache_req_cast_i.addr[11], cache_req_metadata_cast_i.repl_way};
              transducer_l15_val = 1'b1;

              state_n = l15_transducer_ack
                        ? e_read_wait
                        : e_send_req;
            end
          end

        e_uc_read_wait:
          begin
            if (l15_transducer_returntype == `IFILL_RET) begin
              icache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              icache_data_mem_pkt_cast_o.data = //TODO
              icache_data_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = icache_data_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo ? e_ready : e_uc_read_wait;
            end

            if (l15_transducer_returntype == `LOAD_RET) begin
              dcache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
              dcache_data_mem_pkt_cast_o.data = //TODO
              dcache_data_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = dcache_data_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo ? e_ready : e_uc_read_wait;
            end
          end
        
        e_read_wait:
          begin
            //TODO: Check how to use cache_req_r if there are multiple
            // requests
            // TODO: IFILL_RET needs to be acknowledged the next cycle
            if (l15_transducer_returntype == `IFILL_RET) begin
              icache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              icache_data_mem_pkt_cast_o.index = cache_req_r.addr[icache_block_offset_width_lp+:icache_index_width_lp];
              icache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              icache_data_mem_pkt_cast_o.data = //TODO
              icache_data_mem_pkt_v_o = l15_transducer_val;

              icache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              icache_tag_mem_pkt_cast_o.index = cache_req_r.addr[icache_block_offset_width_lp+:icache_index_width_lp];
              icache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              icache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[icache_block_offset_width_lp+icache_index_width_lp+:ptag_width_p];
              icache_tag_mem_pkt_cast_o.state = e_COH_M;
              icache_tag_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = icache_data_mem_pkt_yumi_i & icache_tag_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo ? e_ready : e_read_wait;
            end

            if (l15_transducer_returntype == `LOAD_RET) begin
              dcache_data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
              dcache_data_mem_pkt_cast_o.index = cache_req_r.addr[dcache_block_offset_width_lp+:dcache_index_width_lp];
              dcache_data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              dcache_data_mem_pkt_cast_o.data = //TODO
              dcache_data_mem_pkt_v_o = l15_transducer_val;

              dcache_tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
              dcache_tag_mem_pkt_cast_o.index = cache_req_r.addr[dcache_block_offset_width_lp+:dcache_index_width_lp];
              dcache_tag_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              dcache_tag_mem_pkt_cast_o.tag = cache_req_r.addr[dcache_block_offset_width_lp+dcache_index_width_lp+:ptag_width_p];
              dcache_tag_mem_pkt_cast_o.state = e_COH_M;
              dcache_tag_mem_pkt_v_o = l15_transducer_val;

              transducer_l15_req_ack_lo = dcache_data_mem_pkt_yumi_i & dcache_tag_mem_pkt_yumi_i;
              state_n = transducer_l15_req_ack_lo ? e_ready : e_read_wait;
            end 
          end
        default: state_n = e_reset;
      endcase
    end

