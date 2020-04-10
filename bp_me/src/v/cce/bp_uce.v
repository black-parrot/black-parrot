
module bp_uce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   ,parameter assoc_p = 8
   ,parameter sets_p = 64
   ,parameter block_width_p = 512
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

    , localparam stat_info_width_lp = `bp_cache_stat_info_width(assoc_p)

    , localparam bank_width_lp = block_width_p / assoc_p
    , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
    , localparam byte_offset_width_lp  = `BSG_SAFE_CLOG2(bank_width_lp>>3)
    // Words per line == associativity
    , localparam word_offset_width_lp  = `BSG_SAFE_CLOG2(assoc_p)
    , localparam block_offset_width_lp = (word_offset_width_lp + byte_offset_width_lp)
    , localparam index_width_lp = `BSG_SAFE_CLOG2(sets_p)
    , localparam way_width_lp = `BSG_SAFE_CLOG2(assoc_p)

    , localparam cache_req_width_lp = `bp_cache_req_width(dword_width_p, paddr_width_p) 
    , localparam cache_req_metadata_width_lp = `bp_cache_req_metadata_width(assoc_p)
    , localparam cache_tag_mem_pkt_width_lp = `bp_cache_tag_mem_pkt_width(sets_p, assoc_p, ptag_width_p)
    , localparam cache_data_mem_pkt_width_lp = `bp_cache_data_mem_pkt_width(sets_p, assoc_p, block_width_p)
    , localparam cache_stat_mem_pkt_width_lp = `bp_cache_stat_mem_pkt_width(sets_p, assoc_p)

    // Block size parameterisations - 
    , localparam is_blockwidth_512 = (block_width_p == 512)
    , localparam is_blockwidth_256 = (block_width_p == 256)
    , localparam is_blockwidth_128 = (block_width_p == 128)
    )
   (input                                            clk_i
    , input                                          reset_i

    , input [lce_id_width_p-1:0]                     lce_id_i

    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_v_i
    , output logic                                   cache_req_ready_o
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
    , input                                          cache_req_metadata_v_i
    , output logic                                   cache_req_complete_o

    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , output logic                                   tag_mem_pkt_v_o
    , input                                          tag_mem_pkt_ready_i
    , input [ptag_width_p-1:0]                       tag_mem_i

    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , output logic                                   data_mem_pkt_v_o
    , input                                          data_mem_pkt_ready_i
    , input [block_width_p-1:0]                      data_mem_i

    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , output logic                                   stat_mem_pkt_v_o
    , input                                          stat_mem_pkt_ready_i
    , input [stat_info_width_lp-1:0]                 stat_mem_i

    , output logic                                   credits_full_o
    , output logic                                   credits_empty_o

    , output [cce_mem_msg_width_lp-1:0]              mem_cmd_o
    , output logic                                   mem_cmd_v_o
    , input                                          mem_cmd_ready_i

    , input [cce_mem_msg_width_lp-1:0]               mem_resp_i
    , input                                          mem_resp_v_i
    , output logic                                   mem_resp_yumi_o
    );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, cache);
  `declare_bp_cache_stat_info_s(assoc_p, cache);

  `bp_cast_i(bp_cache_req_s, cache_req);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);

  `bp_cast_o(bp_cce_mem_msg_s, mem_cmd);
  `bp_cast_i(bp_cce_mem_msg_s, mem_resp);

  logic cache_req_v_r, dirty_data_v_r, dirty_tag_v_r, dirty_stat_v_r;
  always_ff @(posedge clk_i)
    begin
      cache_req_v_r <= cache_req_v_i;
      dirty_data_v_r <= data_mem_pkt_v_o & (data_mem_pkt_cast_o.opcode == e_cache_data_mem_read);
      dirty_tag_v_r <= tag_mem_pkt_v_o & (tag_mem_pkt_cast_o.opcode == e_cache_tag_mem_read);
      dirty_stat_v_r <= stat_mem_pkt_v_o & (stat_mem_pkt_cast_o.opcode == e_cache_stat_mem_read);
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

  logic cache_req_metadata_v_r;
  bsg_dff_en_bypass
   #(.width_p(1))
   metadata_v_reg
    (.clk_i(clk_i)

     ,.en_i(cache_req_v_i | cache_req_metadata_v_i)
     ,.data_i(cache_req_metadata_v_i)
     ,.data_o(cache_req_metadata_v_r)
     );

  logic [block_width_p-1:0] dirty_data_r;
  bsg_dff_en_bypass
   #(.width_p(block_width_p))
   dirty_data_reg
    (.clk_i(clk_i)

    ,.en_i(dirty_data_v_r)
    ,.data_i(data_mem_i)
    ,.data_o(dirty_data_r)
    );

  logic [ptag_width_p-1:0] dirty_tag_r;
  bsg_dff_en_bypass
   #(.width_p(ptag_width_p))
   dirty_tag_reg
    (.clk_i(clk_i)

    ,.en_i(dirty_tag_v_r)
    ,.data_i(tag_mem_i)
    ,.data_o(dirty_tag_r)
    );

  bp_cache_stat_info_s dirty_stat_r;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_cache_stat_info_s)))
   dirty_stat_reg
    (.clk_i(clk_i)

     ,.en_i(dirty_stat_v_r)
     ,.data_i(stat_mem_i)
     ,.data_o(dirty_stat_r)
     );

  // We can do a little better by sending the read_request before the writeback
  enum logic [3:0] {e_reset, e_clear, e_flush_read, e_flush_scan, e_flush_write, e_flush_fence, e_ready, e_send_req, e_writeback_read, e_writeback_req, e_write_wait, e_read_wait, e_uc_read_wait} state_n, state_r;
  wire is_reset         = (state_r == e_reset);
  wire is_clear         = (state_r == e_clear);
  wire is_flush_read    = (state_r == e_flush_read);
  wire is_flush_scan    = (state_r == e_flush_scan);
  wire is_flush_write   = (state_r == e_flush_write);
  wire is_flush_fence   = (state_r == e_flush_fence);
  wire is_ready         = (state_r == e_ready);
  wire is_send_req      = (state_r == e_send_req);
  wire is_writeback_read = (state_r == e_writeback_read);
  wire is_writeback_req = (state_r == e_writeback_req);
  wire is_write_request = (state_r == e_write_wait);
  wire is_read_request  = (state_r == e_read_wait);

  // We check for uncached stores ealier than other requests, because they get sent out in ready
  wire flush_v_li         = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_flush};
  wire clear_v_li         = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_clear};
  wire uc_store_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};

  wire store_resp_v_li    = mem_resp_v_i & mem_resp_cast_i.header.msg_type inside {e_cce_mem_wb, e_cce_mem_uc_wr};
  wire load_resp_v_li     = mem_resp_v_i & mem_resp_cast_i.header.msg_type inside {e_cce_mem_rd, e_cce_mem_wr, e_cce_mem_uc_rd};

  wire miss_load_v_li  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire wt_store_v_li   = cache_req_v_r & cache_req_r.msg_type inside {e_wt_store};

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

  logic [way_width_lp-1:0] way_cnt;
  logic way_up;
  bsg_counter_clear_up
   #(.max_val_p(assoc_p-1)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   way_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i('0)
     ,.up_i(way_up)

     ,.count_o(way_cnt)
     );
  wire way_done = (way_cnt == assoc_p-1);

  // Outstanding Requests Counter - counts all requests, cached and uncached
  //
  logic [`BSG_WIDTH(coh_noc_max_credits_p)-1:0] credit_count_lo;
  wire credit_v_li = mem_cmd_v_o;
  wire credit_ready_li = mem_cmd_ready_i;
  // credit is returned when request completes
  // UC store done for UC Store, UC Data for UC Load, Set Tag Wakeup for
  // a miss that is actually an upgrade, and data and tag for normal requests.
  wire credit_returned_li = mem_resp_yumi_o;
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

  // We ack mem_resps for uncached stores no matter what, so mem_resp_yumi_lo is for other responses 
  logic mem_resp_yumi_lo;
  assign mem_resp_yumi_o = mem_resp_yumi_lo | store_resp_v_li;
  always_comb
    begin
      cache_req_ready_o = '0;

      index_up = '0;
      way_up   = '0;

      tag_mem_pkt_cast_o  = '0;
      tag_mem_pkt_v_o     = '0;
      data_mem_pkt_cast_o = '0;
      data_mem_pkt_v_o    = '0;
      stat_mem_pkt_cast_o = '0;
      stat_mem_pkt_v_o    = '0;

      cache_req_complete_o = '0;

      mem_cmd_cast_o   = '0;
      mem_cmd_v_o      = '0;
      mem_resp_yumi_lo = '0;

      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            state_n = e_clear;
          end
        e_clear:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_cast_o.index  = index_cnt;
            tag_mem_pkt_v_o = tag_mem_pkt_ready_i & stat_mem_pkt_ready_i;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_cast_o.index  = index_cnt;
            stat_mem_pkt_v_o = stat_mem_pkt_ready_i & tag_mem_pkt_ready_i;

            index_up = tag_mem_pkt_v_o & stat_mem_pkt_v_o;

            cache_req_complete_o = (index_done & index_up);

            state_n = (index_done & index_up) ? e_ready : e_clear;
          end
        e_flush_read:
          begin
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_cast_o.index = index_cnt;
            stat_mem_pkt_v_o = stat_mem_pkt_ready_i;

            state_n = stat_mem_pkt_v_o ? e_flush_scan : e_flush_read;
          end
        e_flush_scan:
          begin
            // Could check if |dirty_stat_r to skip index entirely
            if (dirty_stat_r[way_cnt])
              begin
                data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
                data_mem_pkt_cast_o.index  = index_cnt;
                data_mem_pkt_cast_o.way_id = way_cnt;
                data_mem_pkt_v_o = stat_mem_pkt_ready_i & tag_mem_pkt_ready_i & data_mem_pkt_ready_i;

                tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_read;
                tag_mem_pkt_cast_o.index  = index_cnt;
                tag_mem_pkt_cast_o.way_id = way_cnt;
                tag_mem_pkt_v_o = stat_mem_pkt_ready_i & tag_mem_pkt_ready_i & data_mem_pkt_ready_i;

                stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
                stat_mem_pkt_cast_o.index  = index_cnt;
                stat_mem_pkt_cast_o.way_id = way_cnt;
                stat_mem_pkt_v_o = stat_mem_pkt_ready_i & tag_mem_pkt_ready_i & data_mem_pkt_ready_i;

                state_n = (data_mem_pkt_v_o & tag_mem_pkt_v_o & stat_mem_pkt_v_o) ? e_flush_write : e_flush_scan;
              end
            else
              begin
                way_up   = 1'b1;
                index_up = way_done;

                state_n = (index_done & way_done)
                          ? e_flush_fence
                          : way_done 
                            ? e_flush_read 
                            : e_flush_scan;
              end
          end
        e_flush_write:
          begin
            mem_cmd_cast_o.header.msg_type = e_cce_mem_wb;
            mem_cmd_cast_o.header.addr     = {dirty_tag_r, index_cnt, block_offset_width_lp'(0)};
            mem_cmd_cast_o.header.size     = is_blockwidth_512
                                              ? e_mem_size_64
                                              : is_blockwidth_256
                                                ? e_mem_size_32
                                                : is_blockwidth_128
                                                  ? e_mem_size_16
                                                  : e_mem_size_64;
            mem_cmd_cast_o.header.payload.lce_id = lce_id_i;
            mem_cmd_cast_o.data            = dirty_data_r;
            mem_cmd_v_o = mem_cmd_ready_i;

            way_up = mem_cmd_v_o;
            index_up = way_done & mem_cmd_v_o;

            state_n = (mem_cmd_v_o & index_done & way_done)
                      ? e_flush_fence
                      : index_up
                        ? e_flush_read
                          : mem_cmd_v_o
                            ? e_flush_scan
                            : e_flush_write;
          end
        e_flush_fence:
          begin
            cache_req_complete_o = credits_empty_o;

            state_n = cache_req_complete_o ? e_ready : e_flush_fence;
          end
        e_ready:
          begin
            cache_req_ready_o = mem_cmd_ready_i;
            if (uc_store_v_li)
              begin
                mem_cmd_cast_o.header.msg_type       = e_cce_mem_uc_wr;
                mem_cmd_cast_o.header.addr           = cache_req_cast_i.addr;
                mem_cmd_cast_o.header.size           = bp_cce_mem_req_size_e'(cache_req_cast_i.size);
                mem_cmd_cast_o.header.payload.lce_id = lce_id_i;
                mem_cmd_cast_o.data                  = cache_req_cast_i.data;
                mem_cmd_v_o = mem_cmd_ready_i;
              end
            else
              begin
                state_n = cache_req_v_i
                          ? flush_v_li
                            ? e_flush_read
                            : clear_v_li
                              ? e_clear
                              : e_send_req
                          : e_ready;
              end
          end
        e_send_req:
          if (miss_v_li)
            begin
              mem_cmd_cast_o.header.msg_type       = miss_load_v_li ? e_cce_mem_rd : e_cce_mem_wr;
              mem_cmd_cast_o.header.addr           = {cache_req_r.addr[paddr_width_p-1:block_offset_width_lp], block_offset_width_lp'(0)};
              mem_cmd_cast_o.header.size           = is_blockwidth_512
                                                      ? e_mem_size_64
                                                      : is_blockwidth_256
                                                        ? e_mem_size_32
                                                        : is_blockwidth_128
                                                          ? e_mem_size_16
                                                          : e_mem_size_64;
              mem_cmd_cast_o.header.payload.way_id = lce_assoc_p'(cache_req_metadata_r.repl_way);
              mem_cmd_cast_o.header.payload.lce_id = lce_id_i;
              mem_cmd_v_o = mem_cmd_ready_i;

              state_n = mem_cmd_v_o 
                        ? cache_req_metadata_r.dirty 
                          ? e_writeback_read
                          : e_read_wait 
                        : e_send_req;
            end
          else if (uc_load_v_li)
            begin
              mem_cmd_cast_o.header.msg_type       = e_cce_mem_uc_rd;
              mem_cmd_cast_o.header.addr           = cache_req_r.addr;
              mem_cmd_cast_o.header.size           = e_mem_size_8;
              mem_cmd_cast_o.header.payload.lce_id = lce_id_i;
              mem_cmd_v_o = mem_cmd_ready_i;

              state_n = mem_cmd_v_o ? e_uc_read_wait : e_send_req;
            end
        e_writeback_read:
          begin
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
            data_mem_pkt_v_o = data_mem_pkt_ready_i & tag_mem_pkt_ready_i & stat_mem_pkt_ready_i;

            tag_mem_pkt_cast_o.opcode  = e_cache_tag_mem_read;
            tag_mem_pkt_cast_o.index   = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            tag_mem_pkt_cast_o.way_id  = cache_req_metadata_r.repl_way;
            tag_mem_pkt_v_o = data_mem_pkt_ready_i & tag_mem_pkt_ready_i & stat_mem_pkt_ready_i;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
            stat_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
            stat_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
            stat_mem_pkt_v_o = data_mem_pkt_ready_i & tag_mem_pkt_ready_i & stat_mem_pkt_ready_i;

            state_n = (data_mem_pkt_v_o & tag_mem_pkt_v_o & stat_mem_pkt_v_o) ? e_writeback_req : e_writeback_read;
          end
        e_writeback_req:
          begin
            mem_cmd_cast_o.header.msg_type = e_cce_mem_wb;
            mem_cmd_cast_o.header.addr     = {dirty_tag_r, cache_req_r.addr[block_offset_width_lp+:index_width_lp], block_offset_width_lp'(0)};
            mem_cmd_cast_o.header.size     = is_blockwidth_512
                                              ? e_mem_size_64
                                              : is_blockwidth_256
                                                ? e_mem_size_32
                                                : is_blockwidth_128
                                                  ? e_mem_size_16
                                                  : e_mem_size_64;
            mem_cmd_cast_o.header.payload.lce_id = lce_id_i;
            mem_cmd_cast_o.data            = dirty_data_r;
            mem_cmd_v_o = mem_cmd_ready_i;

            state_n = mem_cmd_v_o ? e_read_wait : e_writeback_req;
          end
        e_read_wait:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_cast_o.index  = mem_resp_cast_i.header.addr[block_offset_width_lp+:index_width_lp];
            // We fill in M because we don't want to trigger additional coherence traffic
            tag_mem_pkt_cast_o.way_id = mem_resp_cast_i.header.payload.way_id[0+:`BSG_SAFE_CLOG2(assoc_p)];
            tag_mem_pkt_cast_o.state  = e_COH_M;
            tag_mem_pkt_cast_o.tag    = mem_resp_cast_i.header.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
            tag_mem_pkt_v_o = load_resp_v_li & tag_mem_pkt_ready_i & data_mem_pkt_ready_i;

            data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
            data_mem_pkt_cast_o.index  = mem_resp_cast_i.header.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = mem_resp_cast_i.header.payload.way_id[0+:`BSG_SAFE_CLOG2(assoc_p)];
            data_mem_pkt_cast_o.data   = mem_resp_cast_i.data;
            data_mem_pkt_v_o = load_resp_v_li & data_mem_pkt_ready_i & tag_mem_pkt_ready_i;

            cache_req_complete_o = tag_mem_pkt_v_o & data_mem_pkt_v_o;
            mem_resp_yumi_lo = cache_req_complete_o; 

            state_n = cache_req_complete_o ? e_ready : e_read_wait;
          end
        e_uc_read_wait:
          begin
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_cast_o.data = mem_resp_cast_i.data;
            data_mem_pkt_v_o = load_resp_v_li & data_mem_pkt_ready_i;

            cache_req_complete_o = data_mem_pkt_v_o;
            mem_resp_yumi_lo = cache_req_complete_o;

            state_n = cache_req_complete_o ? e_ready : e_uc_read_wait;
          end
        default: state_n = e_reset;
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

////synopsys translate_on
//always_ff @(negedge clk_i)
//  begin
//    assert (reset_i || ~wt_store_v_li)
//      $display("Unsupported op: wt store %p", cache_req_cast_i);
//  end
////synopsys translate_off

endmodule

