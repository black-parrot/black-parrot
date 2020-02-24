
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

    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_v_i
    , output logic                                   cache_req_ready_o

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

    , output logic                                   cache_req_complete_o

    , output logic                                   credits_full_o
    , output logic                                   credits_empty_o

    , output [cce_mem_msg_width_lp-1:0]              mem_cmd_o
    , output logic                                   mem_cmd_v_o
    , input                                          mem_cmd_yumi_i

    , input [cce_mem_msg_width_lp-1:0]               mem_resp_i
    , input                                          mem_resp_v_i
    , output logic                                   mem_resp_yumi_o
    );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, lce_sets_p, lce_assoc_p, dword_width_p, cce_block_width_p);
  // FIXME: Should use this directly
  //`bp_cast_i(bp_cache_req_s, cache_req);
  bp_cache_req_s cache_req_r, cache_req_cast_i;
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);

  `bp_cast_o(bp_cce_mem_msg_s, mem_cmd);
  `bp_cast_i(bp_cce_mem_msg_s, mem_resp);

  // FIXME: This is a hack to get around the stat info coming a cycle after other info during misses
  //
  bsg_dff_reset
   #(.width_p($bits(bp_cache_req_s)))
   cache_req_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_i)
     ,.data_o(cache_req_r)
     );

  enum logic [2:0] {e_reset, e_flush, e_ready, e_writeback, e_write_request, e_read_request} state_n, state_r;
  wire is_reset         = (state_r == e_reset);
  wire is_flush         = (state_r == e_flush);
  wire is_ready         = (state_r == e_ready);
  wire is_writeback     = (state_r == e_writeback);
  wire is_write_request = (state_r == e_write_request);
  wire is_read_request  = (state_r == e_read_request);

  wire miss_load_v_li  = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_load};
  wire miss_store_v_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_store};
  wire miss_v_li       = miss_load_v_li | miss_store_v_li;
  wire uc_load_v_li    = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_load};
  wire uc_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire wt_store_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};

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
  assign credits_full_o = '0;
  assign credits_empty_o = '0;

  always_comb
    begin
      cache_req_ready_o = ~reset_i && is_ready;

      tag_mem_pkt_cast_o  = '0;
      tag_mem_pkt_v_o     = '0;
      data_mem_pkt_cast_o = '0;
      data_mem_pkt_v_o    = '0;
      stat_mem_pkt_cast_o = '0;
      stat_mem_pkt_v_o    = '0;

      cache_req_complete_o = '0;

      mem_cmd_cast_o   = '0;
      mem_cmd_v_o      = '0;
      mem_resp_yumi_o  = '0;

      state_n = state_r;

      unique case (state_r)
        e_reset:
          begin
            state_n = e_flush;
          end
        e_flush:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_cast_o.index  = index_cnt;
            tag_mem_pkt_v_o = tag_mem_pkt_ready_i & stat_mem_pkt_ready_i;

            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_cast_o.index  = index_cnt;
            stat_mem_pkt_v_o = stat_mem_pkt_ready_i & tag_mem_pkt_ready_i;

            state_n = index_done ? e_ready : e_flush;
          end
        e_ready: 
          if (miss_v_li & ~cache_req_cast_i.dirty)
            begin
              mem_cmd_v_o = 1'b1;
              mem_cmd_cast_o.msg_type       = miss_load_v_li ? e_cce_mem_rd : e_cce_mem_wr;
              mem_cmd_cast_o.addr           = cache_req_cast_i.addr;
              mem_cmd_cast_o.size           = e_mem_size_64;
              mem_cmd_cast_o.payload.way_id = cache_req_cast_i.repl_way;

              state_n = mem_cmd_v_o ? e_read_request : e_ready;
            end
          else if (miss_v_li & cache_req_cast_i.dirty)
            begin
              // TODO: 
              //state_n = block_read_li ? e_write_request : e_writeback;
              state_n = state_r;
            end
        e_writeback:
          begin
            // TODO: Need to dequeue the writeback response while still preserving the original
            // request

            //state_n = block_read_li ? e_write_request : e_writeback;
            state_n = state_r;
          end
        e_write_request:
          begin
            state_n = state_r;
            //state_n = mem_resp_yumi_o ? e_read_request : e_ready;
          end
        e_read_request:
          begin
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_cast_o.index  = mem_resp_cast_i.addr[block_offset_width_lp+:index_width_lp];
            // We fill in M because we don't want to trigger additional coherence traffic
            tag_mem_pkt_cast_o.way_id = mem_resp_cast_i.payload.way_id;
            tag_mem_pkt_cast_o.state  = e_COH_M;
            tag_mem_pkt_cast_o.tag    = mem_resp_cast_i.addr[block_offset_width_lp+index_width_lp+:ptag_width_p];
            tag_mem_pkt_v_o = mem_resp_v_i & tag_mem_pkt_ready_i & data_mem_pkt_ready_i;

            data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
            data_mem_pkt_cast_o.index  = mem_resp_cast_i.addr[block_offset_width_lp+:index_width_lp];
            data_mem_pkt_cast_o.way_id = mem_resp_cast_i.payload.way_id;
            data_mem_pkt_cast_o.data   = mem_resp_cast_i.data;
            data_mem_pkt_v_o = mem_resp_v_i & data_mem_pkt_ready_i & tag_mem_pkt_ready_i;

            // TODO: Should we clear dirty bit?
            //
            cache_req_complete_o = tag_mem_pkt_v_o & data_mem_pkt_v_o;
            mem_resp_yumi_o = cache_req_complete_o; 

            state_n = cache_req_complete_o ? e_ready : e_read_request;
          end
        default: state_n = e_reset;
      endcase
    end

  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

//  //synopsys translate_on
//  always_ff @(negedge clk_i)
//    begin
//      if (cache_req_v_i)
//        begin
//          assert (~wt_store_v_li)
//            $display("Unsupported op: wt store %p", cache_req_cast_i);
//        end
//    end
//  //synopsys translate_off

endmodule

