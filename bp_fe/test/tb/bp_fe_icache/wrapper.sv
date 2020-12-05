module wrapper
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   , parameter uce_p = 1
   `declare_bp_proc_params(bp_params_p)
   // These alternate parameters are untested
   , parameter sets_p = icache_sets_p
   , parameter assoc_p = icache_assoc_p
   , parameter block_width_p = icache_block_width_p
   , parameter fill_width_p = icache_fill_width_p
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, icache_sets_p, icache_assoc_p, dword_width_gp, icache_block_width_p, icache_fill_width_p, icache)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam wg_per_cce_lp = (lce_sets_p / num_cce_p)
   , localparam lg_icache_assoc_lp = `BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam block_size_in_words_lp=icache_assoc_p
   , localparam bank_width_lp = icache_block_width_p / icache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_gp
   , localparam data_mem_mask_width_lp=(bank_width_lp>>3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(icache_sets_p)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cfg_bus_width_lp-1:0]            cfg_bus_i

   , input [vaddr_width_p-1:0]               vaddr_i
   , input                                   vaddr_v_i
   , output                                  vaddr_ready_o

   , input [ptag_width_p-1:0]                ptag_i
   , input                                   ptag_v_i

   , input                                   uncached_i
   , input                                   nonidem_i

   , output [instr_width_gp-1:0]             data_o
   , output                                  data_v_o

   , input [cce_mem_msg_width_lp-1:0]        mem_resp_i
   , input                                   mem_resp_v_i
   , output logic                            mem_resp_yumi_o

   , output logic [cce_mem_msg_width_lp-1:0] mem_cmd_o
   , output logic                            mem_cmd_v_o
   , input                                   mem_cmd_ready_i
   );

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

  // I$-LCE Interface signals
  // Miss, Management Interfaces
  logic cache_req_yumi_li, cache_req_busy_li;
  logic [icache_req_width_lp-1:0] cache_req_lo;
  logic cache_req_v_lo;
  logic [icache_req_metadata_width_lp-1:0] cache_req_metadata_lo;
  logic cache_req_metadata_v_lo;
  logic cache_req_critical_li, cache_req_complete_li;
  logic cache_req_credits_full_li, cache_req_credits_empty_li;

  // Fill Interfaces
  logic data_mem_pkt_v_li, tag_mem_pkt_v_li, stat_mem_pkt_v_li;
  logic data_mem_pkt_yumi_lo, tag_mem_pkt_yumi_lo, stat_mem_pkt_yumi_lo;
  logic [icache_data_mem_pkt_width_lp-1:0] data_mem_pkt_li;
  logic [icache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_li;
  logic [icache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_li;
  logic [icache_block_width_p-1:0] data_mem_lo;
  logic [icache_tag_info_width_lp-1:0] tag_mem_lo;
  logic [icache_stat_info_width_lp-1:0] stat_mem_lo;

  // Rolly fifo signals
  logic [ptag_width_p-1:0] rolly_ptag_lo;
  logic [vaddr_width_p-1:0] rolly_vaddr_lo;
  logic rolly_nonidem_lo;
  logic rolly_uncached_lo;
  logic rolly_v_lo;
  logic rolly_yumi_li;
  logic icache_ready_lo;
  assign rolly_yumi_li = rolly_v_lo & icache_ready_lo;

  logic rollback_li, rolly_yumi_rr;

  bsg_fifo_1r1w_rolly
   #(.width_p(vaddr_width_p+ptag_width_p+2), .els_p(8))
   rolly_icache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clr_v_i(1'b0)
     ,.deq_v_i(data_v_o)
     ,.roll_v_i(rollback_li)

     ,.data_i({1'b0, uncached_i, vaddr_i, ptag_i})
     ,.v_i(vaddr_v_i)
     ,.ready_o(vaddr_ready_o)

     ,.data_o({rolly_nonidem_lo, rolly_uncached_lo, rolly_vaddr_lo, rolly_ptag_lo})
     ,.v_o(rolly_v_lo)
     ,.yumi_i(rolly_yumi_li)
     );

  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   rolly_yumi_reg
    (.clk_i(clk_i)
     ,.data_i(rolly_yumi_li)
     ,.data_o(rolly_yumi_rr)
     );

  assign rollback_li = rolly_yumi_rr & ~data_v_o;

  logic [ptag_width_p-1:0] rolly_ptag_r;
  bsg_dff_reset
   #(.width_p(ptag_width_p))
   ptag_dff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(rolly_ptag_lo)
     ,.data_o(rolly_ptag_r)
     );

  logic ptag_v_r, uncached_r, nonidem_r;
  bsg_dff_reset
   #(.width_p(3))
   ptag_v_dff
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({rolly_nonidem_lo, rolly_uncached_lo, rolly_v_lo})
     ,.data_o({rolly_nonidem_r, uncached_r, ptag_v_r})
     );

   logic icache_v_rr, poison_li;
   bsg_dff_chain
    #(.width_p(1), .num_stages_p(2))
    icache_v_reg
     (.clk_i(clk_i)
      ,.data_i(rolly_yumi_li)
      ,.data_o(icache_v_rr)
      );

   assign poison_li = icache_v_rr & ~data_v_o;

  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt;
  assign icache_pkt = '{vaddr: rolly_vaddr_lo, op: e_icache_fill};

  // I-Cache
  bp_fe_icache
   #(.bp_params_p(bp_params_p)
     ,.sets_p(sets_p)
     ,.assoc_p(assoc_p)
     ,.block_width_p(block_width_p)
     ,.fill_width_p(fill_width_p)
     )
   icache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_i)

     ,.icache_pkt_i(icache_pkt)
     ,.v_i(rolly_yumi_li)
     ,.ready_o(icache_ready_lo)

     ,.ptag_i(rolly_ptag_r)
     ,.ptag_v_i(ptag_v_r)
     ,.uncached_i(uncached_r)
     ,.nonidem_i(nonidem_r)
     ,.poison_tl_i(1'b0)

     ,.data_o(data_o)
     ,.data_v_o(data_v_o)
     ,.miss_v_o()
     ,.poison_tv_i(1'b0)

     ,.cache_req_o(cache_req_lo)
     ,.cache_req_v_o(cache_req_v_lo)
     ,.cache_req_yumi_i(cache_req_yumi_li)
     ,.cache_req_busy_i(cache_req_busy_li)
     ,.cache_req_metadata_o(cache_req_metadata_lo)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_lo)
     ,.cache_req_critical_i(cache_req_critical_li)
     ,.cache_req_complete_i(cache_req_complete_li)
     ,.cache_req_credits_full_i(cache_req_credits_full_li)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_li)

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
    bp_bedrock_lce_req_msg_s lce_req_lo;
    bp_bedrock_lce_resp_msg_s lce_resp_lo;
    bp_bedrock_lce_cmd_msg_s lce_cmd_lo, fifo_lce_cmd_lo;
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
       ,.cache_req_yumi_o(cache_req_yumi_li)
       ,.cache_req_busy_o(cache_req_busy_li)
       ,.cache_req_metadata_i(cache_req_metadata_lo)
       ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
       ,.cache_req_critical_o(cache_req_critical_li)
       ,.cache_req_complete_o(cache_req_complete_li)
       ,.cache_req_credits_full_o(cache_req_credits_full_li)
       ,.cache_req_credits_empty_o(cache_req_credits_empty_li)

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
       );


    // lce cmd demanding -> demanding handshake conversion
    bsg_two_fifo
     #(.width_p(lce_cmd_msg_width_lp))
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
    bp_bedrock_cce_mem_msg_s fifo_mem_resp_lo;
    logic mem_resp_ready_lo, mem_resp_ready_li;
    logic fifo_mem_resp_v_lo, fifo_mem_resp_yumi_li;

    bp_bedrock_cce_mem_msg_header_s mem_cmd_header_lo, mem_resp_header_li;
    logic [icache_fill_width_p-1:0] mem_cmd_data_lo, mem_resp_data_li;
    logic mem_cmd_v_lo, mem_cmd_ready_and_li, mem_cmd_last_lo;
    logic mem_resp_v_li, mem_resp_ready_and_lo, mem_resp_last_li;

    bp_uce
     #(.bp_params_p(bp_params_p)
       ,.uce_mem_data_width_p(cce_block_width_p)
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
       ,.cache_req_yumi_o(cache_req_yumi_li)
       ,.cache_req_busy_o(cache_req_busy_li)
       ,.cache_req_metadata_i(cache_req_metadata_lo)
       ,.cache_req_metadata_v_i(cache_req_metadata_v_lo)
       ,.cache_req_critical_o(cache_req_critical_li)
       ,.cache_req_complete_o(cache_req_complete_li)
       ,.cache_req_credits_full_o(cache_req_credits_full_li)
       ,.cache_req_credits_empty_o(cache_req_credits_empty_li)

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

       ,.mem_cmd_header_o(mem_cmd_header_lo)
       ,.mem_cmd_data_o(mem_cmd_data_lo)
       ,.mem_cmd_last_o(mem_cmd_last_lo)
       ,.mem_cmd_v_o(mem_cmd_v_lo)
       ,.mem_cmd_ready_and_i(mem_cmd_ready_and_li)

       ,.mem_resp_header_i(mem_resp_header_li)
       ,.mem_resp_data_i(mem_resp_data_li)
       ,.mem_resp_last_i(mem_resp_last_li)
       ,.mem_resp_v_i(mem_resp_v_li)
       ,.mem_resp_ready_and_o(mem_resp_ready_and_lo)
       );

    if (icache_fill_width_p < cce_block_width_p) begin
      bp_stream_to_lite
       #(.bp_params_p(bp_params_p)
       ,.in_data_width_p(icache_fill_width_p)
       ,.out_data_width_p(cce_block_width_p)
       ,.payload_width_p(cce_mem_payload_width_lp)
       ,.payload_mask_p(mem_cmd_payload_mask_gp))
       stream2lite
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.in_msg_header_i(mem_cmd_header_lo)
        ,.in_msg_data_i(mem_cmd_data_lo)
        ,.in_msg_v_i(mem_cmd_v_lo)
        ,.in_msg_ready_and_o(mem_cmd_ready_and_li)
        ,.in_msg_last_i(mem_cmd_last_lo)

        ,.out_msg_o(mem_cmd_o)
        ,.out_msg_v_o(mem_cmd_v_o)
        ,.out_msg_ready_and_i(mem_cmd_ready_i)
        );

      bp_lite_to_stream
       #(.bp_params_p(bp_params_p)
       ,.in_data_width_p(cce_block_width_p)
       ,.out_data_width_p(icache_fill_width_p)
       ,.payload_width_p(cce_mem_payload_width_lp)
       ,.payload_mask_p(mem_resp_payload_mask_gp))
       lite2stream
        (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.in_msg_i(fifo_mem_resp_lo)
        ,.in_msg_v_i(fifo_mem_resp_v_lo)
        ,.in_msg_ready_and_o(mem_resp_ready_li)

        ,.out_msg_header_o(mem_resp_header_li)
        ,.out_msg_data_o(mem_resp_data_li)
        ,.out_msg_v_o(mem_resp_v_li)
        ,.out_msg_ready_and_i(mem_resp_ready_and_lo)
        ,.out_msg_last_o(mem_resp_last_li)
        );
    end
    else begin
      bp_bedrock_cce_mem_msg_s mem_cmd_lo;
      always_comb begin
        mem_cmd_lo = '{header: mem_cmd_header_lo
                      ,data: mem_cmd_data_lo};
        mem_cmd_o            = mem_cmd_lo;
        mem_cmd_v_o          = mem_cmd_v_lo;
        mem_cmd_ready_and_li = mem_cmd_ready_i;

        mem_resp_header_li    = fifo_mem_resp_lo.header;
        mem_resp_data_li      = fifo_mem_resp_lo.data;
        mem_resp_v_li         = fifo_mem_resp_v_lo;
        mem_resp_last_li      = fifo_mem_resp_v_lo;
        mem_resp_ready_li     = mem_resp_ready_and_lo;
      end

    end
    
    bsg_fifo_1r1w_small
     #(.width_p(cce_mem_msg_width_lp)
       ,.els_p(1)
       )
     mem_resp_fifo
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.v_i(mem_resp_v_i)
       ,.data_i(mem_resp_i)
       ,.ready_o(mem_resp_ready_lo)

       ,.v_o(fifo_mem_resp_v_lo)
       ,.data_o(fifo_mem_resp_lo)
       ,.yumi_i(fifo_mem_resp_yumi_li)
       );
    assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
    assign fifo_mem_resp_yumi_li = fifo_mem_resp_v_lo & mem_resp_ready_li;
  end
endmodule

