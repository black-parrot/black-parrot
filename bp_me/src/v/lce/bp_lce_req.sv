/**
 *  Name:
 *    bp_lce_req.sv
 *
 *  Description:
 *    LCE request handler.
 *
 *    Issues LCE requests when cache misses arrive. Supports cached, uncached, and uncached atomic
 *    requests.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce_req
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // parameters specific to this LCE (these match the cache managed by the LCE)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   , parameter `BSG_INV_PARAM(tag_width_p)
   , parameter `BSG_INV_PARAM(id_width_p)

   // LCE-cache interface timeout in cycles
   , parameter timeout_max_limit_p=4
   // maximum number of outstanding transactions
   , parameter credits_p = coh_noc_max_credits_p
   // issue non-exclusive read requests
   , parameter non_excl_reads_p = 0

   // byte offset bits required per bedrock data channel beat
   , localparam bedrock_byte_offset_lp = `BSG_SAFE_CLOG2(fill_width_p/8)
   , localparam bit [paddr_width_p-1:0] req_addr_mask = {paddr_width_p{1'b1}} << bedrock_byte_offset_lp

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   `declare_bp_cache_engine_generic_if_widths(paddr_width_p, tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p, cache)
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [did_width_p-1:0]                        did_i
    , input [lce_id_width_p-1:0]                     lce_id_i
    , input bp_lce_mode_e                            lce_mode_i
    , input                                          cache_init_done_i
    , input                                          sync_done_i

    // LCE Req is not able to accept requests
    , output logic                                   busy_o

    // Cache-LCE Interface
    // ready / valid handshake
    // metadata arrives in the same cycle as req, or any cycle after, but before the next request
    // can arrive, as indicated by the metadata_v_i signal
    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_v_i
    , output logic                                   cache_req_yumi_o
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
    , input                                          cache_req_metadata_v_i

    // LCE-Cache Interface
    , output logic                                   cache_req_credits_full_o
    , output logic                                   cache_req_credits_empty_o

    // LCE Cmd - LCE Req Interface
    // request complete signal from LCE Cmd module - Cached Load/Store and Uncached Load
    // this signal is raised exactly once, for a single cycle, per request completing, and it
    // can be raised at any time after the LCE request sends out
    , input                                          credit_return_i
    , input                                          cache_req_done_i

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
    , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
    , output logic                                   lce_req_v_o
    , input                                          lce_req_ready_and_i
  );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_cache_engine_generic_if(paddr_width_p, tag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, id_width_p, cache);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_cache_req_s, cache_req);
  `bp_cast_i(bp_cache_req_metadata_s, cache_req_metadata);

  enum logic [2:0] {e_reset, e_ready, e_request, e_send, e_backoff} state_n, state_r;
  wire is_reset   = (state_r == e_reset);
  wire is_ready   = (state_r == e_ready);
  wire is_request = (state_r == e_request);
  wire is_send    = (state_r == e_send);
  wire is_backoff = (state_r == e_backoff);

  logic cache_req_ready_lo;
  bp_cache_req_s cache_req_r;
  logic cache_req_v_r, cache_req_done;
  bsg_two_fifo
   #(.width_p($bits(bp_cache_req_s)), .ready_THEN_valid_p(1))
   cache_req_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_cast_i)
     ,.v_i(cache_req_yumi_o)
     ,.ready_param_o(cache_req_ready_lo)

     ,.data_o(cache_req_r)
     ,.v_o(cache_req_v_r)
     ,.yumi_i(cache_req_done)
     );

  bp_cache_req_metadata_s cache_req_metadata, cache_req_metadata_r;
  logic cache_req_metadata_v_r;
  bsg_two_fifo
   #(.width_p($bits(bp_cache_req_metadata_s)), .ready_THEN_valid_p(1))
   cache_req_metadata_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_metadata_cast_i)
     ,.v_i(cache_req_metadata_v_i & (cache_req_metadata_v_r | ~cache_req_done))
     ,.ready_param_o(/* Follows cache req fifo */)

     ,.data_o(cache_req_metadata_r)
     ,.v_o(cache_req_metadata_v_r)
     ,.yumi_i(cache_req_metadata_v_r & cache_req_done)
     );
  assign cache_req_metadata = cache_req_metadata_v_r ? cache_req_metadata_r : cache_req_metadata_cast_i;
  wire cache_req_metadata_v = cache_req_metadata_v_i | cache_req_metadata_v_r;

  wire miss_load_v_li   = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_load};
  wire miss_store_v_li  = cache_req_v_i & cache_req_cast_i.msg_type inside {e_miss_store};
  wire miss_v_li        = cache_req_v_i & miss_load_v_li | miss_store_v_li;
  wire bclean_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_bclean};
  wire clean_v_li       = cache_req_v_i & cache_req_cast_i.msg_type inside {e_cache_clean};
  wire uc_load_v_li     = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_load};
  wire uc_amo_v_li      = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_amo};
  wire uc_store_v_li    = cache_req_v_i & cache_req_cast_i.msg_type inside {e_uc_store};
  wire blocking_v_li    = miss_load_v_li | miss_store_v_li | uc_load_v_li | uc_amo_v_li;
  wire nonblocking_v_li = uc_store_v_li;

  bp_bedrock_lce_req_header_s fsm_req_header_lo;
  logic [paddr_width_p-1:0] fsm_req_addr_lo;
  logic [fill_width_p-1:0] fsm_req_data_lo;
  logic fsm_req_v_lo, fsm_req_ready_then_li;
  logic fsm_req_new_lo, fsm_req_critical_lo, fsm_req_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(fill_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.msg_stream_mask_p(lce_req_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_req_stream_mask_gp)
     )
   lce_req_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_req_header_cast_o)
     ,.msg_data_o(lce_req_data_o)
     ,.msg_v_o(lce_req_v_o)
     ,.msg_ready_and_i(lce_req_ready_and_i)

     ,.fsm_header_i(fsm_req_header_lo)
     ,.fsm_addr_o(fsm_req_addr_lo)
     ,.fsm_data_i(fsm_req_data_lo)
     ,.fsm_v_i(fsm_req_v_lo)
     ,.fsm_ready_then_o(fsm_req_ready_then_li)
     ,.fsm_new_o(fsm_req_new_lo)
     ,.fsm_critical_o(fsm_req_critical_lo)
     ,.fsm_last_o(fsm_req_last_lo)
     );

  wire miss_load_v_r   = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_r  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_r        = miss_load_v_r | miss_store_v_r;
  wire bflush_v_r      = cache_req_v_r & cache_req_r.msg_type inside {e_cache_bclean, e_cache_binval, e_cache_bflush};
  wire clean_v_r       = cache_req_v_r & cache_req_r.msg_type inside {e_cache_clean};
  wire uc_load_v_r     = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire uc_amo_v_r      = cache_req_v_r & cache_req_r.msg_type inside {e_uc_amo};
  wire uc_store_v_r    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_store};
  wire blocking_v_r    = miss_load_v_r | miss_store_v_r | uc_load_v_r | uc_amo_v_r;
  wire nonblocking_v_r = uc_store_v_r;

  // Outstanding request credit counter
  // one credit used per LCE request sent
  logic [`BSG_WIDTH(credits_p)-1:0] credit_count_lo;
  wire credit_v_li = fsm_req_v_lo & fsm_req_new_lo;
  wire credit_ready_then_li = fsm_req_ready_then_li;
  wire credit_returned_li = credit_return_i;
  bsg_flow_counter
    #(.els_p(credits_p), .ready_THEN_valid_p(1))
    req_counter
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(credit_v_li)
      ,.ready_param_i(credit_ready_then_li)
      ,.yumi_i(credit_returned_li)
      ,.count_o(credit_count_lo)
      );
  assign cache_req_credits_full_o  =  cache_req_v_r && (credit_count_lo == credits_p);
  assign cache_req_credits_empty_o = ~cache_req_v_r && (credit_count_lo == '0);

  // Request Address to CCE
  logic [cce_id_width_p-1:0] req_cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   req_map
    (.paddr_i(cache_req_r.addr)
     ,.cce_id_o(req_cce_id_lo)
     );

  // LCE should suppress messages if in reset or we are not synchronized with the CCE
  // busy being lowered does not guarantee that this module will accept a valid cache request
  // packet (refer to cache_req_yumi_o below).
  assign busy_o = ~sync_done_i && (lce_mode_i == e_lce_mode_normal);

  // atomic request subop determination
  bp_bedrock_wr_subop_e req_subop;
  always_comb
    unique case (cache_req_r.subop)
      e_req_amolr  : req_subop = e_bedrock_amolr;
      e_req_amosc  : req_subop = e_bedrock_amosc;
      e_req_amoswap: req_subop = e_bedrock_amoswap;
      e_req_amoadd : req_subop = e_bedrock_amoadd;
      e_req_amoxor : req_subop = e_bedrock_amoxor;
      e_req_amoand : req_subop = e_bedrock_amoand;
      e_req_amoor  : req_subop = e_bedrock_amoor;
      e_req_amomin : req_subop = e_bedrock_amomin;
      e_req_amomax : req_subop = e_bedrock_amomax;
      e_req_amominu: req_subop = e_bedrock_amominu;
      e_req_amomaxu: req_subop = e_bedrock_amomaxu;
      default : req_subop = e_bedrock_store;
    endcase

  always_comb
    begin
      // Request message defaults
      fsm_req_header_lo = '0;
      fsm_req_header_lo.addr = cache_req_r.addr;
      fsm_req_header_lo.size = bp_bedrock_msg_size_e'(cache_req_r.size);
      fsm_req_header_lo.payload.dst_id = req_cce_id_lo;
      fsm_req_header_lo.payload.src_id = lce_id_i;
      fsm_req_header_lo.payload.src_did = did_i;
      fsm_req_header_lo.payload.lru_way_id = lce_assoc_width_p'(cache_req_metadata.hit_or_repl_way);
      fsm_req_header_lo.payload.non_exclusive =
        (miss_load_v_r && (non_excl_reads_p == 1)) ? e_bedrock_req_non_excl : e_bedrock_req_excl;
      fsm_req_header_lo.subop = bflush_v_r ? e_bedrock_amoor : req_subop;
      fsm_req_data_lo = cache_req_r.data;

      // Send request header when able
      // requires valid cache request and possibly valid metadata (cached requests only)
      unique case (cache_req_r.msg_type)
        e_cache_bflush: fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_wr;
        e_uc_store    : fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_wr;
        e_uc_load     : fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_rd;
        e_uc_amo      : fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_amo;
        e_miss_load   : fsm_req_header_lo.msg_type.req = e_bedrock_req_rd_miss;
        e_miss_store  : fsm_req_header_lo.msg_type.req = e_bedrock_req_wr_miss;
        default: begin end
      endcase
    end

  always_comb
    begin
      cache_req_yumi_o = '0;
      fsm_req_v_lo = '0;
      cache_req_done = '0;

      case (state_r)
        e_ready:
          begin
            cache_req_yumi_o = cache_req_v_i & cache_req_ready_lo & (~cache_req_v_r | nonblocking_v_li);

            state_n = cache_req_yumi_o
                      ? blocking_v_li
                        ? e_send
                        : e_ready
                      : cache_req_v_i ? e_backoff : state_r;
          end
        e_send:
          begin
            fsm_req_v_lo = fsm_req_ready_then_li & ~cache_req_credits_full_o;

            state_n = (fsm_req_v_lo & fsm_req_last_lo) ? e_request : state_r;
          end
        e_request:
          begin
            cache_req_done = cache_req_done_i;

            state_n = cache_req_done ? e_ready : state_r;
          end
        e_backoff:
          begin
            state_n = fsm_req_ready_then_li ? e_ready : state_r;
          end
        // e_reset:
        default : state_n = cache_init_done_i ? e_ready : state_r;
      endcase

      // Fire off a non-blocking request opportunistically if we have one
      // Could eke out some performance by changing ~fsm_req_v_lo to blocking_req_v_lo
      //if (nonblocking_v_r & ~fsm_req_v_lo)
      if (is_ready & nonblocking_v_r)
        begin
          fsm_req_v_lo = fsm_req_ready_then_li & ~cache_req_credits_full_o;

          cache_req_done = fsm_req_v_lo & fsm_req_last_lo;
        end
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

endmodule

`BSG_ABSTRACT_MODULE(bp_lce_req)

