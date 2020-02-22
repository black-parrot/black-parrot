
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
   (input                                      clk_i
    , input                                    reset_i

    , input [cache_req_width_lp-1:0]           cache_req_i
    , input                                    cache_req_v_i
    , output logic                             cache_req_ready_o

    , output [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , output                                   tag_mem_pkt_v_o
    , input                                    tag_mem_pkt_ready_i
    , input [ptag_width_p-1:0]                 tag_mem_i

    , output [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , output                                   data_mem_pkt_v_o
    , input                                    data_mem_pkt_ready_i
    , input [cce_block_width_p-1:0]            data_mem_i

    , output [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , output                                   stat_mem_pkt_v_o
    , input                                    stat_mem_pkt_ready_i
    , input [stat_info_width_lp-1:0]           stat_mem_i

    , output logic                             cache_req_complete_o

    , output logic                             credits_full_o
    , output logic                             credits_empty_o

    , output [cce_mem_msg_width_lp-1:0]        mem_cmd_o
    , output logic                             mem_cmd_v_o
    , input                                    mem_cmd_ready_i

    , input [cce_mem_msg_width_lp-1:0]         mem_resp_i
    , input                                    mem_resp_v_i
    , output logic                             mem_resp_yumi_o
    );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, lce_sets_p, lce_assoc_p, dword_width_p, cce_block_width_p);
  bp_cache_req_s cache_req_cast_i;
  bp_cache_stat_mem_pkt_s stat_mem_pkt_cast_o;
  bp_cache_tag_mem_pkt_s tag_mem_pkt_cast_o;
  bp_cache_data_mem_pkt_s data_mem_pkt_cast_o;
  bp_cce_mem_msg_s mem_cmd_cast_o, mem_resp_cast_i;

  assign cache_req_cast_i = cache_req_i;
  assign stat_mem_pkt_o = stat_mem_pkt_cast_o;
  assign tag_mem_pkt_o = tag_mem_pkt_cast_o;
  assign data_mem_pkt_o = data_mem_pkt_cast_o;
  assign mem_cmd_o = mem_cmd_cast_o;
  assign mem_resp_cast_i = mem_resp_i;

  enum logic [2:0] {e_reset, e_clear, e_ready, e_writeback, e_write_request, e_read_request} state_n, state_r;
  wire is_reset         = (state_r == e_reset);
  wire is_clear         = (state_r == e_clear);
  wire is_ready         = (state_r == e_ready);
  wire is_writeback     = (state_r == e_writeback);
  wire is_write_request = (state_r == e_write_request);
  wire is_read_request  = (state_r == e_read_request);


  /*
  wire miss_load_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_load};
  wire miss_store_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_store};
  wire miss_li = cache_req_v_i & (miss_load_li | miss_store_li);
  wire uc_store_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire wt_store_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_wt_store};
  wire uc_load_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_load};
  wire block_read_li = cache_req_v_i & cache_req_cast_i.msg_type inside {e_block_read};


  localparam index_width_lp = `BSG_SAFE_CLOG2(lce_sets_p);
  logic [index_width_lp-1:0] index_cnt;
  logic index_clr, index_inc;
  bsg_counter_clear_up
   #(.max_val_p((lce_sets_p-1))
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   index_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(index_clr)
     ,.up_i(index_cnt)

     ,.count_o(index_cnt)
     );
  wire index_done = '0;
  wire index_done = cache_fill_yumi_i & (index_cnt == lce_sets_p-1);

  always_comb
    begin
      index_inc = '0;
      index_clr = '0;

      stat_mem_pkt_cast_o = '0;
      tag_mem_pkt_cast_o = '0;
      data_mem_pkt_cast_o = '0;
      cache_fill_v_o = '0;

      mem_cmd_cast_o = '0;
      mem_cmd_v_o = '0;

      mem_resp_yumi_o = '0;

      state_n = state_r;

      cache_req_ready_o = '0;

      unique case (state_r)
        e_reset: begin end
          begin
            index_clr = 1'b1;

            state_n = e_clear;
          end
        e_clear:
          begin
            index_inc = cache_fill_yumi_i;

            // TODO: Clear each tag and stat index

            state_n = index_done ? e_ready : e_clear;
          end
        e_ready: 
          if (miss_li & ~cache_req_cast_i.dirty)
            begin
              mem_cmd_v_o = mem_cmd_ready_o;
              mem_cmd_cast_o.msg_type = miss_load_li ? e_cce_mem_rd : e_cce_mem_wr;
              mem_cmd_cast_o.addr = cache_req_cast_i.addr;
              mem_cmd_cast_o.size = e_mem_size_64;
              mem_cmd_cast_o.way_id = cache_req_cast_i.repl_way;

              state_n = mem_cmd_v_o ? e_read_request : e_ready;
            end
          else if (miss_li & cache_req_cast_i.dirty)
            begin
              // TODO: 
              state_n = block_read_li ? e_write_request : e_writeback;
            end
        e_writeback:
          begin
            // TODO: Need to dequeue the writeback response while still preserving the original
            // request

            state_n = block_read_li ? e_write_request : e_writeback;
          end
        e_write_request:
          begin
            state_n = mem_resp_yumi_o ? e_read_request : e_ready;
          end
        e_read_request:
          begin
            state_n = cache_req_yumi_lo ? e_ready : e_read_request;
          end
    end

  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  //synopsys translate_on
  always_ff @(negedge clk_i)
    begin
      if (cache_req_v_i)
        begin
          assert (~wt_store_li)
            $error("Unsupported op: wt store");
          assert (~block_read_li || is_writeback)
            $error("Block read response received outside of writeback");
        end
    end
  //synopsys translate_off

  */

endmodule

