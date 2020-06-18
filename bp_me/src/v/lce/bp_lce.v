/**
 *  Name:
 *    bp_lce.v
 *
 *
 *  Description:
 *    Generic Local Cache/Coherence Engine (LCE).
 *
 */

module bp_lce
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

    // parameters specific to this LCE
    , parameter assoc_p = "inv"
    , parameter sets_p = "inv"
    , parameter block_width_p = "inv"
    , parameter fill_width_p = block_width_p

    , parameter timeout_max_limit_p=4

    // maximum number of outstanding transactions
    , parameter credits_p = coh_noc_max_credits_p

    // issue non-exclusive read requests
    , parameter non_excl_reads_p = 0

    , localparam block_size_in_bytes_lp = (block_width_p/8)
    , localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam ptag_width_lp = (paddr_width_p-lg_sets_lp-lg_block_size_in_bytes_lp)

   `declare_bp_lce_cce_if_header_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_lp, sets_p, assoc_p, dword_width_p, block_width_p, fill_width_p, cache)

    , localparam stat_info_width_lp = `bp_cache_stat_info_width(assoc_p)
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i
    , input bp_lce_mode_e                            lce_mode_i

    // Cache-LCE Interface
    // ready_o->valid_i handshake
    // metadata arrives in the same cycle as req, or any cycle after, but before the next request
    // can arrive, as indicated by the metadata_v_i signal
    , input                                          cache_req_v_i
    , output logic                                   cache_req_ready_o
    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_metadata_v_i
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i

    // LCE-Cache Interface
    // valid->yumi
    // commands issued that read and return data have data returned the cycle after
    // the valid->yumi command handshake occurs
    , output logic                                   data_mem_pkt_v_o
    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input                                          data_mem_pkt_yumi_i
    , input [block_width_p-1:0]                      data_mem_i

    , output logic                                   tag_mem_pkt_v_o
    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , input                                          tag_mem_pkt_yumi_i
    , input [ptag_width_lp-1:0]                      tag_mem_i

    , output logic                                   stat_mem_pkt_v_o
    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input                                          stat_mem_pkt_yumi_i
    , input [stat_info_width_lp-1:0]                 stat_mem_i

    , output logic                                   credits_full_o
    , output logic                                   credits_empty_o

    , output logic                                   cache_req_complete_o
    , output logic                                   cache_req_critical_o

    // LCE-CCE interface
    // Req: ready->valid
    , output logic [lce_cce_req_width_lp-1:0]        lce_req_o
    , output logic                                   lce_req_v_o
    , input                                          lce_req_ready_i

    // Resp: ready->valid
    , output logic [lce_cce_resp_width_lp-1:0]       lce_resp_o
    , output logic                                   lce_resp_v_o
    , input                                          lce_resp_ready_i

    // CCE-LCE interface
    // Cmd_i: valid->yumi
    , input [lce_cmd_width_lp-1:0]                   lce_cmd_i
    , input                                          lce_cmd_v_i
    , output logic                                   lce_cmd_yumi_o

    // LCE-LCE interface
    // Cmd_o: ready->valid
    , output logic [lce_cmd_width_lp-1:0]            lce_cmd_o
    , output logic                                   lce_cmd_v_o
    , input                                          lce_cmd_ready_i
  );

  //synopsys translate_off
  initial begin
    assert((sets_p > 1) && `BSG_IS_POW2(sets_p)) else
      $error("LCE sets must be greater than 1 and power of two");
    assert((block_width_p % 8 == 0) && `BSG_IS_POW2(block_width_p)) else
      $error("LCE block width must be a whole number of bytes and power of two");
    assert(block_width_p <= 1024) else
      $error("LCE block width must be no greater than 128 bytes");
    assert(fill_width_p == block_width_p) else
      $error("LCE block width must be equal to fill width. Partial fill is not supported");
    assert(`BSG_IS_POW2(assoc_p)) else
      $error("LCE assoc must be power of two");
  end
  //synopsys translate_on

  // LCE Request Module
  logic lce_req_cache_req_ready_lo;
  logic uc_store_req_complete_lo;

  bp_lce_req
    #(.bp_params_p(bp_params_p)
      ,.assoc_p(assoc_p)
      ,.sets_p(sets_p)
      ,.block_width_p(block_width_p)
      ,.fill_width_p(fill_width_p)
      ,.credits_p(credits_p)
      ,.non_excl_reads_p(non_excl_reads_p)
      )
    request
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)
      ,.lce_mode_i(lce_mode_i)

      ,.cache_req_i(cache_req_i)
      ,.cache_req_v_i(cache_req_v_i)
      ,.cache_req_ready_o(lce_req_cache_req_ready_lo)
      ,.cache_req_metadata_i(cache_req_metadata_i)
      ,.cache_req_metadata_v_i(cache_req_metadata_v_i)

      ,.cache_req_complete_i(cache_req_complete_o)
      ,.uc_store_req_complete_i(uc_store_req_complete_lo)

      ,.credits_full_o(credits_full_o)
      ,.credits_empty_o(credits_empty_o)

      ,.lce_req_o(lce_req_o)
      ,.lce_req_v_o(lce_req_v_o)
      ,.lce_req_ready_i(lce_req_ready_i)
      );

  // LCE Command Module
  logic cmd_ready_lo;
  logic cmd_sync_done_lo;
  bp_lce_cmd
    #(.bp_params_p(bp_params_p)
      ,.assoc_p(assoc_p)
      ,.sets_p(sets_p)
      ,.block_width_p(block_width_p)
      ,.fill_width_p(fill_width_p)
      )
    command
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i(lce_id_i)
      ,.lce_mode_i(lce_mode_i)

      ,.ready_o(cmd_ready_lo)
      ,.sync_done_o(cmd_sync_done_lo)
      ,.cache_req_complete_o(cache_req_complete_o)
      ,.cache_req_critical_o(cache_req_critical_o)
      ,.uc_store_req_complete_o(uc_store_req_complete_lo)

      ,.data_mem_pkt_o(data_mem_pkt_o)
      ,.data_mem_pkt_v_o(data_mem_pkt_v_o)
      ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_i)
      ,.data_mem_i(data_mem_i)

      ,.tag_mem_pkt_o(tag_mem_pkt_o)
      ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
      ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)
      ,.tag_mem_i(tag_mem_i)

      ,.stat_mem_pkt_o(stat_mem_pkt_o)
      ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
      ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_i)
      ,.stat_mem_i(stat_mem_i)

      ,.lce_cmd_i(lce_cmd_i)
      ,.lce_cmd_v_i(lce_cmd_v_i)
      ,.lce_cmd_yumi_o(lce_cmd_yumi_o)

      ,.lce_resp_o(lce_resp_o)
      ,.lce_resp_v_o(lce_resp_v_o)
      ,.lce_resp_ready_i(lce_resp_ready_i)

      ,.lce_cmd_o(lce_cmd_o)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      );


  // LCE timeout logic
  //
  // LCE can read/write to data_mem, tag_mem, and stat_mem during cycles the cache itself is
  // not using them. To prevent the LCE from stalling for too long while waiting for one of
  // these ports, or when processing an inbound LCE command, there is a timer that deasserts the
  // LCE's cache_req_ready_o signal to prevent the cache from issuing a new request, thereby
  // freeing up a cycle for the LCE to use these resources.

  logic [`BSG_SAFE_CLOG2(timeout_max_limit_p+1)-1:0] timeout_cnt_r;
  wire coherence_blocked =
    (data_mem_pkt_v_o & ~data_mem_pkt_yumi_i)
    | (tag_mem_pkt_v_o & ~tag_mem_pkt_yumi_i)
    | (stat_mem_pkt_v_o & ~stat_mem_pkt_yumi_i);

  bsg_counter_clear_up
   #(.max_val_p(timeout_max_limit_p)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   timeout_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(~coherence_blocked)
     ,.up_i(coherence_blocked)
     ,.count_o(timeout_cnt_r)
     );
  wire timeout = (timeout_cnt_r == timeout_max_limit_p);

  // LCE is ready to accept new cache requests if:
  // - LCE Request module is ready (raised when in ready state and free credits exist)
  // - timout signal is low, indicating LCE isn't blocked on using data/tag/stat mem
  // - LCE Command module is ready to process commands (raised after initialization complete)
  assign cache_req_ready_o = lce_req_cache_req_ready_lo & ~timeout & cmd_ready_lo;

endmodule
