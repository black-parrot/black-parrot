
module bp_uce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, lce_sets_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

    , localparam stat_info_width_lp = `bp_be_dcache_stat_info_width(lce_assoc_p)
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
    , input [cce_block_width_p-1:0]                  data_mem_i

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
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, lce_sets_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  `bp_cast_i(bp_cache_req_s, cache_req);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);

  `bp_cast_o(bp_cce_mem_msg_s, mem_cmd);
  `bp_cast_i(bp_cce_mem_msg_s, mem_resp);

  logic cache_req_v_r, dirty_data_v_r, dirty_tag_v_r;
  always_ff @(posedge clk_i)
    begin
      cache_req_v_r <= cache_req_v_i;
      dirty_data_v_r <= data_mem_pkt_v_o & (data_mem_pkt_cast_o.opcode == e_cache_data_mem_read);
      dirty_tag_v_r <= tag_mem_pkt_v_o & (tag_mem_pkt_cast_o.opcode == e_cache_tag_mem_read);
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

  logic [cce_block_width_p-1:0] dirty_data_r;
  bsg_dff_en_bypass
   #(.width_p(cce_block_width_p))
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

  // We can do a little better by sending the read_request before the writeback
  enum logic [2:0] {e_reset, e_do_flush, e_ready, e_send_req, e_writeback, e_write_wait, e_read_wait, e_uc_read_wait} state_n, state_r;
  wire is_reset         = (state_r == e_reset);
  wire is_flush         = (state_r == e_do_flush);
  wire is_ready         = (state_r == e_ready);
  wire is_send_req      = (state_r == e_send_req);
  wire is_writeback     = (state_r == e_writeback);
  wire is_write_request = (state_r == e_write_wait);
  wire is_read_request  = (state_r == e_read_wait);

  // We check for uncached stores ealier than other requests, because they get sent out in ready
  wire uc_store_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire uc_store_resp_v_li = mem_resp_v_i & mem_resp_cast_i.header.msg_type inside {e_cce_mem_uc_wr};

  wire miss_load_v_li  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire wt_store_v_li   = cache_req_v_r & cache_req_r.msg_type inside {e_wt_store};

  localparam byte_offset_width_lp  = `BSG_SAFE_CLOG2(dword_width_p>>3);
  // Words per line == associativity
  localparam word_offset_width_lp  = `BSG_SAFE_CLOG2(lce_assoc_p);
  localparam block_offset_width_lp = (word_offset_width_lp + byte_offset_width_lp);
  localparam index_width_lp        = `BSG_SAFE_CLOG2(lce_sets_p);
  logic [index_width_lp-1:0] index_val, index_cnt;
  logic index_set, index_down, index_done;
  assign index_set  = is_reset;
  assign index_val  = lce_sets_p-1;
  assign index_down = (index_cnt != '0) & is_flush & tag_mem_pkt_v_o & stat_mem_pkt_v_o;
  bsg_counter_set_down
   #(.width_p(index_width_lp))
   index_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(index_set)
     ,.val_i(index_val)
     ,.down_i(index_down)

     ,.count_r_o(index_cnt)
     );
  assign index_done = (index_cnt == '0) & is_flush & tag_mem_pkt_v_o & stat_mem_pkt_v_o;

  // TODO: Count credits
  assign credits_full_o = 1'b0;
  assign credits_empty_o = 1'b1;

  // We ack mem_resps for uncached stores no matter what, so mem_resp_yumi_lo is for other responses 
  logic mem_resp_yumi_lo;
  assign mem_resp_yumi_o = mem_resp_yumi_lo | uc_store_resp_v_li;
  always_comb
    begin
      cache_req_ready_o = '0;

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
            state_n = e_do_flush;
          end
        e_do_flush:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_cast_o.index  = index_cnt;
            tag_mem_pkt_v_o = tag_mem_pkt_ready_i & stat_mem_pkt_ready_i;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_cast_o.index  = index_cnt;
            stat_mem_pkt_v_o = stat_mem_pkt_ready_i & tag_mem_pkt_ready_i;

            state_n = index_done ? e_ready : e_do_flush;
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
                state_n = cache_req_v_i ? e_send_req : e_ready;
              end
          end
        e_send_req:
          if (miss_v_li & ~cache_req_metadata_r.dirty)
            begin
              mem_cmd_cast_o.header.msg_type       = miss_load_v_li ? e_cce_mem_rd : e_cce_mem_wr;
              mem_cmd_cast_o.header.addr           = cache_req_r.addr;
              mem_cmd_cast_o.header.size           = e_mem_size_64;
              mem_cmd_cast_o.header.payload.way_id = cache_req_metadata_r.repl_way;
              mem_cmd_cast_o.header.payload.lce_id = lce_id_i;
              mem_cmd_v_o = mem_cmd_ready_i;

              state_n = mem_cmd_v_o ? e_read_wait : e_send_req;
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
          else if (miss_v_li & cache_req_metadata_r.dirty)
            begin
              data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
              data_mem_pkt_cast_o.index  = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              data_mem_pkt_cast_o.way_id = cache_req_metadata_r.repl_way;
              data_mem_pkt_v_o = data_mem_pkt_ready_i;

              tag_mem_pkt_cast_o.opcode  = e_cache_tag_mem_read;
              tag_mem_pkt_cast_o.index   = cache_req_r.addr[block_offset_width_lp+:index_width_lp];
              tag_mem_pkt_cast_o.way_id  = cache_req_metadata_r.repl_way;
              tag_mem_pkt_v_o = tag_mem_pkt_ready_i;

              state_n = data_mem_pkt_v_o ? e_write_wait : e_send_req;
            end
        e_writeback:
          begin
            mem_cmd_cast_o.header.msg_type = e_cce_mem_wb;
            mem_cmd_cast_o.header.addr     = {dirty_tag_r, cache_req_r.addr[block_offset_width_lp+:index_width_lp]};
            mem_cmd_cast_o.header.size     = e_mem_size_64;
            mem_cmd_v_o = mem_cmd_ready_i;

            state_n = mem_cmd_v_o ? e_write_wait : e_writeback;
          end
        e_write_wait:
          begin
            // Wait for writeback
            mem_resp_yumi_lo = mem_resp_v_i & ~uc_store_resp_v_li;

            state_n = mem_resp_yumi_lo ? e_read_wait : e_ready;
          end
        e_read_wait:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_cast_o.index  = mem_resp_cast_i.header.addr[block_offset_width_lp+:index_width_lp];
            // We fill in M because we don't want to trigger additional coherence traffic
            tag_mem_pkt_cast_o.way_id = mem_resp_cast_i.header.payload.way_id;
            tag_mem_pkt_cast_o.state  = e_COH_M;
            tag_mem_pkt_cast_o.tag    = mem_resp_cast_i.header.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
            tag_mem_pkt_v_o = mem_resp_v_i & tag_mem_pkt_ready_i & data_mem_pkt_ready_i;

            data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
            data_mem_pkt_cast_o.index  = mem_resp_cast_i.header.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = mem_resp_cast_i.header.payload.way_id;
            data_mem_pkt_cast_o.data   = mem_resp_cast_i.data;
            data_mem_pkt_v_o = mem_resp_v_i & data_mem_pkt_ready_i & tag_mem_pkt_ready_i;

            cache_req_complete_o = tag_mem_pkt_v_o & data_mem_pkt_v_o;
            mem_resp_yumi_lo = cache_req_complete_o; 

            state_n = cache_req_complete_o ? e_ready : e_read_wait;
          end
        e_uc_read_wait:
          begin
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_cast_o.data = mem_resp_cast_i.data;
            data_mem_pkt_v_o = mem_resp_v_i & data_mem_pkt_ready_i;

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

