module wrapper
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
  , parameter uce_p = 1
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p)
  `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache_fill_width_p, icache)
  `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)

  , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
  , localparam wg_per_cce_lp = (lce_sets_p / num_cce_p)
  , localparam lg_icache_assoc_lp = `BSG_SAFE_CLOG2(icache_assoc_p)
  , localparam way_id_width_lp=`BSG_SAFE_CLOG2(icache_assoc_p)
  , localparam block_size_in_words_lp=icache_assoc_p
  , localparam bank_width_lp = icache_block_width_p / icache_assoc_p
  , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
  , localparam data_mem_mask_width_lp=(bank_width_lp>>3)
  , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp>>3)
  , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
  , localparam index_width_lp=`BSG_SAFE_CLOG2(icache_sets_p)
  , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
  , localparam stat_width_lp = `bp_cache_stat_info_width(icache_assoc_p)

  )
  ( input                             clk_i
  , input                             reset_i

  , input [cfg_bus_width_lp-1:0]      cfg_bus_i

  , input [vaddr_width_p-1:0]         vaddr_i
  , input                             vaddr_v_i
  , input                             fill_i
  , output                            vaddr_ready_o

  , input [ptag_width_p-1:0]          ptag_i
  , input                             ptag_v_i

  , input                             uncached_i

  , output [vaddr_width_p-1:0]        vaddr_o
  , output [instr_width_p-1:0]        data_o
  , output                            data_v_o
  , output                            miss_not_data_o
  , input                             data_yumi_i

  , input [cce_mem_msg_width_lp-1:0]  mem_resp_i
  , input                             mem_resp_v_i
  , output                            mem_resp_yumi_o

  , output [cce_mem_msg_width_lp-1:0] mem_cmd_o
  , output                            mem_cmd_v_o
  , input                             mem_cmd_ready_i
  );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  // I$-LCE Interface signals
  // Miss, Management Interfaces
  logic cache_req_ready_li;
  logic [icache_req_width_lp-1:0] cache_req_lo;
  logic cache_req_v_lo;
  logic [icache_req_metadata_width_lp-1:0] cache_req_metadata_lo;
  logic cache_req_metadata_v_lo;

  logic cache_req_complete_li, cache_req_critical_li;

  // Fill Interfaces
  logic data_mem_pkt_v_li, tag_mem_pkt_v_li, stat_mem_pkt_v_li;
  logic data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
  logic [icache_data_mem_pkt_width_lp-1:0] data_mem_pkt_li;
  logic [icache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_li;
  logic [icache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_li;
  logic [icache_block_width_p-1:0] data_mem_lo;
  logic [ptag_width_p-1:0] tag_mem_lo;
  logic [stat_width_lp-1:0] stat_mem_lo;

  // Rolly fifo signals
  logic [ptag_width_p-1:0] fifo_ptag_lo;
  logic [vaddr_width_p-1:0] fifo_vaddr_lo;
  logic fifo_uncached_lo;
  logic fifo_v_lo;
  logic fifo_yumi_li;

  bsg_fifo_1r1w_small
   #(.width_p(vaddr_width_p+ptag_width_p+1)
    ,.els_p(8)
    )
    fifo_icache (
     .clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({uncached_i, vaddr_i, ptag_i})
     ,.v_i(vaddr_v_i)
     ,.ready_o(vaddr_ready_o)

     ,.data_o({fifo_uncached_lo, fifo_vaddr_lo, fifo_ptag_lo})
     ,.v_o(fifo_v_lo)
     ,.yumi_i(fifo_yumi_li)
    );

  logic [ptag_width_p-1:0] fifo_ptag_r;
  logic ptag_v_r, uncached_r;
  bsg_dff_reset
    #(.width_p(ptag_width_p+2)
     ,.reset_val_p(0)
    )
    ptag_dff
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i({fifo_uncached_lo, fifo_v_lo, fifo_ptag_lo})
    ,.data_o({uncached_r, ptag_v_r, fifo_ptag_r})
    );

  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt;
  assign icache_pkt = '{vaddr: fifo_vaddr_lo, op: e_icache_fill, default: '0};

  // I-Cache
  bp_fe_icache
    #(.bp_params_p(bp_params_p))
    icache
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i(cfg_bus_i)

    ,.icache_pkt_i(icache_pkt)
    ,.v_i(fifo_v_lo)
    ,.yumi_o(fifo_yumi_li)

    ,.ptag_i(fifo_ptag_r)
    ,.ptag_v_i(ptag_v_r)
    ,.uncached_i(uncached_r)
    ,.tl_we_o()
    ,.tv_we_o()

    ,.vaddr_o(vaddr_o)
    ,.data_o(data_o)
    ,.data_v_o(data_v_o)
    ,.miss_not_data_o(miss_not_data_o)
    ,.data_yumi_i(data_yumi_i)

    ,.cache_req_ready_i(cache_req_ready_li)
    ,.cache_req_o(cache_req_lo)
    ,.cache_req_v_o(cache_req_v_lo)
    ,.cache_req_metadata_o(cache_req_metadata_lo)
    ,.cache_req_metadata_v_o(cache_req_metadata_v_lo)

    ,.cache_req_complete_i(cache_req_complete_li)
    ,.cache_req_critical_i(cache_req_critical_li)

    ,.data_mem_pkt_v_i(data_mem_pkt_v_li)
    ,.data_mem_pkt_i(data_mem_pkt_li)
    ,.data_mem_o(data_mem_lo)
    ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_lo)

    ,.tag_mem_pkt_v_i(tag_mem_pkt_v_li)
    ,.tag_mem_pkt_i(tag_mem_pkt_li)
    ,.tag_mem_o(tag_mem_lo)
    ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_lo)

    ,.stat_mem_pkt_v_i(stat_mem_pkt_v_li)
    ,.stat_mem_pkt_i(stat_mem_pkt_li)
    ,.stat_mem_o(stat_mem_lo)
    ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_lo)
    );

  if (uce_p == 0) begin : CCE
    logic lce_req_v_lo, lce_resp_v_lo, lce_cmd_v_lo, fifo_lce_cmd_v_lo;
    logic lce_req_ready_li, lce_resp_ready_li, lce_cmd_ready_li, fifo_lce_cmd_yumi_li;
    logic [lce_cce_req_width_lp-1:0] lce_req_lo;
    logic [lce_cce_resp_width_lp-1:0] lce_resp_lo;
    logic [lce_cmd_width_lp-1:0] lce_cmd_lo, fifo_lce_cmd_lo;
    logic mem_resp_ready_lo;

    // I-Cache LCE
    bp_lce
      #(.bp_params_p(bp_params_p)
        ,.assoc_p(icache_assoc_p)
        ,.sets_p(icache_sets_p)
        ,.block_width_p(icache_block_width_p)
        ,.timeout_max_limit_p(4)
        ,.credits_p(coh_noc_max_credits_p)
        ,.non_excl_reads_p(1)
        )
      icache_lce
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(cfg_bus_cast_i.icache_id)
      ,.lce_mode_i(cfg_bus_cast_i.icache_mode)

      ,.cache_req_v_i(cache_req_v_lo)
      ,.cache_req_i(cache_req_lo)
      ,.cache_req_ready_o(cache_req_ready_li)
      ,.cache_req_metadata_i(cache_req_metadata_lo)
      ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)

      ,.cache_req_complete_o(cache_req_complete_li)
      ,.cache_req_critical_o(cache_req_critical_li)

      ,.data_mem_i(data_mem_lo)
      ,.data_mem_pkt_o(data_mem_pkt_li)
      ,.data_mem_pkt_v_o(data_mem_pkt_v_li)
      ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)

      ,.tag_mem_i(tag_mem_lo)
      ,.tag_mem_pkt_o(tag_mem_pkt_li)
      ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li)
      ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)

      ,.stat_mem_i(stat_mem_lo)
      ,.stat_mem_pkt_o(stat_mem_pkt_li)
      ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li)
      ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)

      ,.lce_req_o(lce_req_lo)
      ,.lce_req_v_o(lce_req_v_lo)
      ,.lce_req_ready_i(lce_req_ready_li)

      ,.lce_resp_o(lce_resp_lo)
      ,.lce_resp_v_o(lce_resp_v_lo)
      ,.lce_resp_ready_i(lce_resp_ready_li)

      ,.lce_cmd_i(fifo_lce_cmd_lo)
      ,.lce_cmd_v_i(fifo_lce_cmd_v_lo)
      ,.lce_cmd_yumi_o(fifo_lce_cmd_yumi_li)

      ,.lce_cmd_o()
      ,.lce_cmd_v_o()
      ,.lce_cmd_ready_i(1'b1)

      ,.credits_full_o()
      ,.credits_empty_o()
      );


    // lce cmd demanding -> demanding handshake conversion
    bsg_two_fifo
      #(.width_p(lce_cmd_width_lp))
      cmd_fifo
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      // from CCE
      ,.v_i(lce_cmd_v_lo)
      ,.ready_o(lce_cmd_ready_li)
      ,.data_i(lce_cmd_lo)

      // to LCE
      ,.v_o(fifo_lce_cmd_v_lo)
      ,.yumi_i(fifo_lce_cmd_yumi_li)
      ,.data_o(fifo_lce_cmd_lo)
      );

    // FSM CCE
    bp_cce_fsm_top
      #(.bp_params_p(bp_params_p))
      cce_fsm
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)

      ,.lce_req_i(lce_req_lo)
      ,.lce_req_v_i(lce_req_v_lo)
      ,.lce_req_ready_o(lce_req_ready_li)

      ,.lce_resp_i(lce_resp_lo)
      ,.lce_resp_v_i(lce_resp_v_lo)
      ,.lce_resp_ready_o(lce_resp_ready_li)

      ,.lce_cmd_o(lce_cmd_lo)
      ,.lce_cmd_v_o(lce_cmd_v_lo)
      ,.lce_cmd_ready_i(lce_cmd_ready_li)

      ,.mem_resp_i(mem_resp_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_ready_o(mem_resp_ready_lo)

      ,.mem_cmd_o(mem_cmd_o)
      ,.mem_cmd_v_o(mem_cmd_v_o)
      ,.mem_cmd_yumi_i(mem_cmd_ready_i & mem_cmd_v_o)
      );

      assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
  end
  else begin: UCE
    logic mem_resp_ready_lo;
    logic fifo_mem_resp_v_lo, fifo_mem_resp_yumi_li;
    logic [cce_mem_msg_width_lp-1:0] fifo_mem_resp_lo;

    bp_uce
      #(.bp_params_p(bp_params_p)
       ,.uce_mem_data_width_p(icache_fill_width_p)
       ,.assoc_p(icache_assoc_p)
       ,.sets_p(icache_sets_p)
       ,.block_width_p(icache_block_width_p)
       ,.fill_width_p(icache_fill_width_p)
       )
      icache_uce
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i('0)

      ,.cache_req_i(cache_req_lo)
      ,.cache_req_v_i(cache_req_v_lo)
      ,.cache_req_ready_o(cache_req_ready_li)
      ,.cache_req_metadata_i(cache_req_metadata_lo)
      ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
      ,.cache_req_complete_o(cache_req_complete_li)
      ,.cache_req_critical_o(cache_req_critical_li)

      ,.tag_mem_pkt_o(tag_mem_pkt_li)
      ,.tag_mem_pkt_v_o(tag_mem_pkt_v_li)
      ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_lo)
      ,.tag_mem_i(tag_mem_lo)

      ,.data_mem_pkt_o(data_mem_pkt_li)
      ,.data_mem_pkt_v_o(data_mem_pkt_v_li)
      ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_lo)
      ,.data_mem_i(data_mem_lo)

      ,.stat_mem_pkt_o(stat_mem_pkt_li)
      ,.stat_mem_pkt_v_o(stat_mem_pkt_v_li)
      ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_lo)
      ,.stat_mem_i(stat_mem_lo)

      ,.credits_full_o()
      ,.credits_empty_o()

      ,.mem_cmd_o(mem_cmd_o)
      ,.mem_cmd_v_o(mem_cmd_v_o)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)

      ,.mem_resp_i(mem_resp_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_o(mem_resp_yumi_o)
      );
  end
endmodule

