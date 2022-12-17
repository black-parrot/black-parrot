/**
 *  Name:
 *    bp_lce_cmd.sv
 *
 *  Description:
 *    LCE command handler
 *
 *    The LCE Command module processes inbound commands and issues responses to the CCE
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce_cmd
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // parameters specific to this LCE (these match the cache managed by the LCE)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   , parameter `BSG_INV_PARAM(ctag_width_p)

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i
    , input bp_lce_mode_e                            lce_mode_i

    , output logic                                   cache_init_done_o
    , output logic                                   sync_done_o

    // LCE-Cache Interface
    // valid->yumi
    // commands issued that read and return data have data returned the cycle after
    // the valid->yumi command handshake occurs
    , output logic                                   tag_mem_pkt_v_o
    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , input                                          tag_mem_pkt_yumi_i
    , input [cache_tag_info_width_lp-1:0]            tag_mem_i

    , output logic                                   data_mem_pkt_v_o
    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input                                          data_mem_pkt_yumi_i
    , input [block_width_p-1:0]                      data_mem_i

    , output logic                                   stat_mem_pkt_v_o
    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input                                          stat_mem_pkt_yumi_i
    , input [cache_stat_info_width_lp-1:0]           stat_mem_i

    // request complete signals
    // cached requests and uncached loads block in the caches, but uncached stores do not
    // cache_req_complete_o is routed to the cache to indicate a blocking request is complete
    , output logic                                   cache_req_critical_tag_o
    , output logic                                   cache_req_critical_data_o
    , output logic                                   cache_req_complete_o
    // uncached store request complete is used by the LCE to decrement the request credit counter
    // when an uncached store complete, but is not routed to the cache because the caches do not
    // block (miss) on uncached stores
    , output logic                                   uc_store_req_complete_o

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
    , input                                          lce_cmd_header_v_i
    , output logic                                   lce_cmd_header_ready_and_o
    , input                                          lce_cmd_has_data_i
    , input [fill_width_p-1:0]                       lce_cmd_data_i
    , input                                          lce_cmd_data_v_i
    , output logic                                   lce_cmd_data_ready_and_o
    , input                                          lce_cmd_last_i

    , output logic [lce_fill_header_width_lp-1:0]    lce_fill_header_o
    , output logic                                   lce_fill_header_v_o
    , input                                          lce_fill_header_ready_and_i
    , output logic                                   lce_fill_has_data_o
    , output logic [fill_width_p-1:0]                lce_fill_data_o
    , output logic                                   lce_fill_data_v_o
    , input                                          lce_fill_data_ready_and_i
    , output logic                                   lce_fill_last_o

    , output logic [lce_resp_header_width_lp-1:0]    lce_resp_header_o
    , output logic                                   lce_resp_header_v_o
    , input                                          lce_resp_header_ready_and_i
    , output logic                                   lce_resp_has_data_o
    , output logic [fill_width_p-1:0]                lce_resp_data_o
    , output logic                                   lce_resp_data_v_o
    , input                                          lce_resp_data_ready_and_i
    , output logic                                   lce_resp_last_o
  );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `bp_cast_i(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_o(bp_bedrock_lce_fill_header_s, lce_fill_header);
  `bp_cast_o(bp_bedrock_lce_resp_header_s, lce_resp_header);

  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);

  // number of fill per block
  localparam block_size_in_fill_lp = block_width_p / fill_width_p;
  // number of bits to select fill per block
  localparam fill_cnt_width_lp = `BSG_SAFE_CLOG2(block_size_in_fill_lp);
  localparam lg_assoc_lp = `BSG_SAFE_CLOG2(assoc_p);
  localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p);
  // bytes per cache block
  localparam block_size_in_bytes_lp = (block_width_p/8);
  // number of bits for byte select in block
  localparam block_byte_offset_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp);
  // number of bytes per fill
  localparam fill_bytes_lp = (fill_width_p/8);
  // byte offset bits per fill
  localparam fill_byte_offset_lp = `BSG_SAFE_CLOG2(fill_bytes_lp);
  // tag offset
  localparam tag_offset_lp = block_byte_offset_lp + (sets_p > 1 ? lg_sets_lp : 0);
  // coherence request size for cached requests
  localparam bp_bedrock_msg_size_e cmd_block_size_lp = bp_bedrock_msg_size_e'(`BSG_SAFE_CLOG2(block_width_p/8));

  // FSM states
  enum logic [3:0] {
    e_reset
    ,e_clear
    ,e_ready
    ,e_data_to_cache
    ,e_tr
    ,e_stat_clear
    ,e_wb
    ,e_wb_dirty_rd
    ,e_coh_ack
  } state_n, state_r;

  bp_bedrock_lce_cmd_header_s fsm_cmd_header_li;
  logic [paddr_width_p-1:0] fsm_cmd_addr_li;
  logic [fill_width_p-1:0] fsm_cmd_data_li;
  logic fsm_cmd_v_li, fsm_cmd_yumi_lo;
  logic [fill_cnt_width_lp-1:0] fsm_cmd_cnt_li;
  logic fsm_cmd_new_li, fsm_cmd_last_li;
  bp_me_burst_pump_in
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(fill_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.msg_stream_mask_p(lce_cmd_payload_mask_gp)
     ,.fsm_stream_mask_p(lce_cmd_payload_mask_gp)
     ,.header_els_p(2)
     ,.data_els_p(2)
     )
   cmd_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_cmd_header_cast_i)
     ,.msg_header_v_i(lce_cmd_header_v_i)
     ,.msg_header_ready_and_o(lce_cmd_header_ready_and_o)
     ,.msg_has_data_i(lce_cmd_has_data_i)
     ,.msg_data_i(lce_cmd_data_i)
     ,.msg_data_v_i(lce_cmd_data_v_i)
     ,.msg_data_ready_and_o(lce_cmd_data_ready_and_o)
     ,.msg_last_i(lce_cmd_last_i)

     ,.fsm_header_o(fsm_cmd_header_li)
     ,.fsm_addr_o(fsm_cmd_addr_li)
     ,.fsm_cnt_o(fsm_cmd_cnt_li)
     ,.fsm_data_o(fsm_cmd_data_li)
     ,.fsm_v_o(fsm_cmd_v_li)
     ,.fsm_yumi_i(fsm_cmd_yumi_lo)
     ,.fsm_new_o(fsm_cmd_new_li)
     ,.fsm_last_o(fsm_cmd_last_li)
     );

  // Save off the command header for usage in fill and resp networks
  bp_bedrock_lce_cmd_header_s fsm_cmd_header_r;
  bsg_dff_en
   #(.width_p($bits(bp_bedrock_lce_cmd_header_s)))
   fsm_cmd_header_reg
    (.clk_i(clk_i)
     ,.en_i(fsm_cmd_yumi_lo)
     ,.data_i(fsm_cmd_header_li)
     ,.data_o(fsm_cmd_header_r)
     );

  bp_bedrock_lce_fill_header_s fsm_fill_header_lo;
  logic [fill_width_p-1:0] fsm_fill_data_lo;
  logic fsm_fill_v_lo, fsm_fill_ready_and_li;
  logic [fill_cnt_width_lp-1:0] fsm_fill_cnt_lo;
  logic fsm_fill_new_lo, fsm_fill_last_lo;
  bp_me_burst_pump_out
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(fill_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(lce_fill_payload_width_lp)
     ,.msg_stream_mask_p(lce_fill_payload_mask_gp)
     ,.fsm_stream_mask_p(lce_fill_payload_mask_gp)
     )
   lce_fill_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_fill_header_cast_o)
     ,.msg_header_v_o(lce_fill_header_v_o)
     ,.msg_header_ready_and_i(lce_fill_header_ready_and_i)
     ,.msg_has_data_o(lce_fill_has_data_o)
     ,.msg_data_o(lce_fill_data_o)
     ,.msg_data_v_o(lce_fill_data_v_o)
     ,.msg_data_ready_and_i(lce_fill_data_ready_and_i)
     ,.msg_last_o(lce_fill_last_o)

     ,.fsm_header_i(fsm_fill_header_lo)
     ,.fsm_data_i(fsm_fill_data_lo)
     ,.fsm_v_i(fsm_fill_v_lo)
     ,.fsm_ready_and_o(fsm_fill_ready_and_li)
     ,.fsm_cnt_o(fsm_fill_cnt_lo)
     ,.fsm_new_o(fsm_fill_new_lo)
     ,.fsm_last_o(fsm_fill_last_lo)
     );

  bp_bedrock_lce_resp_header_s fsm_resp_header_lo;
  logic [fill_width_p-1:0] fsm_resp_data_lo;
  logic fsm_resp_v_lo, fsm_resp_ready_and_li;
  logic [fill_cnt_width_lp-1:0] fsm_resp_cnt_lo;
  logic fsm_resp_new_lo, fsm_resp_last_lo;
  bp_me_burst_pump_out
   #(.bp_params_p(bp_params_p)
     ,.stream_data_width_p(fill_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(lce_resp_payload_width_lp)
     ,.msg_stream_mask_p(lce_resp_payload_mask_gp)
     ,.fsm_stream_mask_p(lce_resp_payload_mask_gp)
     )
   lce_resp_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_resp_header_cast_o)
     ,.msg_header_v_o(lce_resp_header_v_o)
     ,.msg_header_ready_and_i(lce_resp_header_ready_and_i)
     ,.msg_has_data_o(lce_resp_has_data_o)
     ,.msg_data_o(lce_resp_data_o)
     ,.msg_data_v_o(lce_resp_data_v_o)
     ,.msg_data_ready_and_i(lce_resp_data_ready_and_i)
     ,.msg_last_o(lce_resp_last_o)

     ,.fsm_header_i(fsm_resp_header_lo)
     ,.fsm_data_i(fsm_resp_data_lo)
     ,.fsm_v_i(fsm_resp_v_lo)
     ,.fsm_ready_and_o(fsm_resp_ready_and_li)
     ,.fsm_cnt_o(fsm_resp_cnt_lo)
     ,.fsm_new_o(fsm_resp_new_lo)
     ,.fsm_last_o(fsm_resp_last_lo)
     );

  logic [block_width_p-1:0] dirty_data_r;
  wire dirty_data_read = data_mem_pkt_yumi_i & (data_mem_pkt_cast_o.opcode == e_cache_data_mem_read);
  bsg_dff_sync_read
   #(.width_p(block_width_p), .bypass_p(1))
   dirty_data_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(data_mem_i)
     ,.v_n_i(dirty_data_read)

     ,.data_o(dirty_data_r)
     );

  // data mux to pick fill word for sending in command/response data beat
  logic [fill_width_p-1:0] dirty_data_selected;
  logic [`BSG_SAFE_CLOG2(block_size_in_fill_lp)-1:0] dirty_data_select;
  bsg_mux
   #(.width_p(fill_width_p), .els_p(block_size_in_fill_lp))
   dirty_data_mux
    (.data_i(dirty_data_r)
     ,.sel_i(dirty_data_select)
     ,.data_o(dirty_data_selected)
     );

  bp_cache_tag_info_s dirty_tag_r;
  wire dirty_tag_read = tag_mem_pkt_yumi_i & (tag_mem_pkt_cast_o.opcode == e_cache_tag_mem_read);
  bsg_dff_sync_read
   #(.width_p($bits(bp_cache_tag_info_s)), .bypass_p(1))
   dirty_tag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(tag_mem_i)
     ,.v_n_i(dirty_tag_read)

     ,.data_o(dirty_tag_r)
     );

  bp_cache_stat_info_s dirty_stat_r;
  wire dirty_stat_read = stat_mem_pkt_yumi_i & (stat_mem_pkt_cast_o.opcode == e_cache_stat_mem_read);
  bsg_dff_sync_read
   #(.width_p($bits(bp_cache_stat_info_s)), .bypass_p(1))
   dirty_stat_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(stat_mem_i)
     ,.v_n_i(dirty_stat_read)

     ,.data_o(dirty_stat_r)
     );

  // LCE Command module is ready after it clears the cache's tag and stat memories
  assign cache_init_done_o = (state_r != e_reset) && (state_r != e_clear);

  // counter used by Command FSM to perform sync sequence
  // width for counter used during initiliazation and for sync messages
  localparam cnt_width_lp = `BSG_MAX(cce_id_width_p+1, `BSG_SAFE_CLOG2(sets_p)+1);
  localparam cnt_max_val_lp = ((2**cnt_width_lp)-1);

  logic cnt_inc, cnt_clear;
  logic [cnt_width_lp-1:0] cnt_r;
  bsg_counter_clear_up
    #(.max_val_p(cnt_max_val_lp)
      ,.init_val_p(0)
      ,.disable_overflow_warning_p(1)
      )
    counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_clear)
      ,.up_i(cnt_inc)
      ,.count_o(cnt_r)
      );

  wire sync_done = (cnt_r == cnt_width_lp'(num_cce_p-1));
  bsg_dff_reset_set_clear
   #(.width_p(1))
   sync_done_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(sync_done)
     ,.clear_i(1'b0)
     ,.data_o(sync_done_o)
     );

  localparam bank_width_lp = block_width_p / assoc_p;
  localparam byte_offset_width_lp  = `BSG_SAFE_CLOG2(bank_width_lp>>3);
  localparam bank_offset_width_lp  = `BSG_SAFE_CLOG2(assoc_p);
  localparam fill_size_in_bank_lp = fill_width_p / bank_width_lp;
  localparam bank_sub_offset_width_lp = $clog2(fill_size_in_bank_lp);
  wire [block_size_in_fill_lp-1:0] fill_index_shift = fsm_cmd_addr_li[byte_offset_width_lp+:bank_offset_width_lp] >> bank_sub_offset_width_lp;

  always_comb begin

    state_n = state_r;

    uc_store_req_complete_o = 1'b0;
    cache_req_critical_data_o = 1'b0;
    cache_req_critical_tag_o = 1'b0;
    // raised request is fully resolved
    cache_req_complete_o = 1'b0;

    // LCE-CCE Interface signals
    fsm_cmd_yumi_lo = 1'b0;

    fsm_fill_header_lo = '0;
    fsm_fill_data_lo = '0;
    fsm_fill_v_lo = 1'b0;

    fsm_resp_header_lo = '0;
    fsm_resp_data_lo = '0;
    fsm_resp_v_lo = 1'b0;

    // Counter
    cnt_inc = 1'b0;
    cnt_clear = reset_i;
    dirty_data_select = '0; 

    // LCE-Cache Interface signals
    data_mem_pkt_cast_o = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt_cast_o = '0;
    tag_mem_pkt_v_o = 1'b0;
    stat_mem_pkt_cast_o = '0;
    stat_mem_pkt_v_o = 1'b0;

    // Command FSM
    unique case (state_r)

      e_reset: begin
        state_n = e_clear;
      end

      // After reset is complete, the LCE Command module clears the tag and stat memories
      // of the cache it manages, initializing the cache for operation.
      e_clear: begin
        tag_mem_pkt_cast_o.index = cnt_r[0+:lg_sets_lp];
        tag_mem_pkt_cast_o.state = e_COH_I;
        tag_mem_pkt_cast_o.tag = '0;
        tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
        tag_mem_pkt_v_o = 1'b1;

        stat_mem_pkt_cast_o.index = cnt_r[0+:lg_sets_lp];
        stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
        stat_mem_pkt_v_o = 1'b1;

        state_n = ((cnt_r == cnt_width_lp'(sets_p-1)) & tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
                  ? e_ready
                  : e_clear;
        cnt_clear = (state_n == e_ready);
        cnt_inc = ~cnt_clear & (tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i);

      end

      // Ready for LCE Commands
      // A command is dequeued when the command module finishes processing the command.
      e_ready: begin
        unique case (fsm_cmd_header_li.msg_type.cmd)

          /*
           * Commands that don't read/write cache data memory
           */

          // Sync
          e_bedrock_cmd_sync: begin
            fsm_resp_header_lo.payload.dst_id = fsm_cmd_header_li.payload.src_id;
            fsm_resp_header_lo.payload.src_id = lce_id_i;
            fsm_resp_header_lo.msg_type.resp = e_bedrock_resp_sync_ack;
            // handshake
            // response (r&v) can send when header is valid
            fsm_resp_v_lo = fsm_cmd_v_li;
            // header (v->y) consumed when response sends
            fsm_cmd_yumi_lo = fsm_resp_ready_and_li & fsm_resp_v_lo;

            // reset the counter when last sync is received and ack is sent
            cnt_clear = ((cnt_r == cnt_width_lp'(num_cce_p-1))
                         & (fsm_resp_v_lo & fsm_resp_ready_and_li));
            // increment as long as not resetting counter
            cnt_inc = ~cnt_clear & (fsm_resp_v_lo & fsm_resp_ready_and_li);
          end

          // Set Clear - invalidate entire set specified by command
          // cache tag and stat writes are idempotent
          e_bedrock_cmd_set_clear: begin
            tag_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_v_o = fsm_cmd_v_li;

            stat_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_v_o = fsm_cmd_v_li;

            // consume header when tag and stat packets consumed together
            fsm_cmd_yumi_lo = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;

          end

          // Invalidate Tag - write tag mem and send Invalidate Ack
          // cache tag write is idempotent
          e_bedrock_cmd_inv: begin
            tag_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            tag_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            tag_mem_pkt_cast_o.state = e_COH_I;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = fsm_cmd_v_li;

            // response can send if tag mem packet consumed by cache
            fsm_resp_v_lo = tag_mem_pkt_yumi_i;
            fsm_resp_header_lo.addr = fsm_cmd_header_li.addr;
            fsm_resp_header_lo.msg_type.resp = e_bedrock_resp_inv_ack;
            fsm_resp_header_lo.payload.src_id = lce_id_i;
            fsm_resp_header_lo.payload.dst_id = fsm_cmd_header_li.payload.src_id;

            // consume command header when response sends
            fsm_cmd_yumi_lo = fsm_resp_v_lo & fsm_resp_ready_and_li;

          end

          // Set State
          // Write the state as commanded, no response sent
          // cache tag write is idempotent
          // Set State and Wakeup
          e_bedrock_cmd_st
          , e_bedrock_cmd_st_wakeup: begin
            tag_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            tag_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            tag_mem_pkt_cast_o.state = fsm_cmd_header_li.payload.state;
            tag_mem_pkt_cast_o.tag = '0;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = fsm_cmd_v_li;

            // consume header when tag write consumed by cache
            fsm_cmd_yumi_lo = tag_mem_pkt_yumi_i;

            state_n = (tag_mem_pkt_yumi_i && (fsm_cmd_header_li.msg_type inside {e_bedrock_cmd_st_wakeup}))
                      ? e_coh_ack
                      : state_r;
          end

          /*
           * Commands that read/write cache data memory
           */

          // Data and Tag - cache block data, tag, and state from coherence directory
          // completes a regular cache miss
          // sends tag in this state, and data in next state
          e_bedrock_cmd_data: begin
            tag_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            tag_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            tag_mem_pkt_cast_o.state = fsm_cmd_header_li.payload.state;
            tag_mem_pkt_cast_o.tag = fsm_cmd_header_li.addr[tag_offset_lp+:ctag_width_p];
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v_o = fsm_cmd_v_li;
            cache_req_critical_tag_o = tag_mem_pkt_yumi_i & fsm_cmd_new_li;

            // do not consume header since it is needed to compute fill index for cache data writes
            state_n = tag_mem_pkt_yumi_i
                      ? e_data_to_cache
                      : state_r;
          end

          // Uncached Data - uncached load returning from memory
          // sends data to cache and raises request complete signal for one cycle
          // requires valid header (buffered) and data
          // note: supports uncached accesses up to dword_width_gp size
          e_bedrock_cmd_uc_data: begin
            data_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            // This replication only works for up to 64b uncached requests
            data_mem_pkt_cast_o.data = {(fill_width_p/dword_width_gp){fsm_cmd_data_li[0+:dword_width_gp]}};
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_v_o = fsm_cmd_v_li;

            // consume single data beat and header when data packet is consumed by cache
            fsm_cmd_yumi_lo = data_mem_pkt_yumi_i & fsm_cmd_new_li;

            // raise request complete signal when data consumed
            cache_req_complete_o = data_mem_pkt_yumi_i & fsm_cmd_new_li;
            // Note: should create a tag_mem_pkt message for uncached
            cache_req_critical_tag_o = data_mem_pkt_yumi_i & fsm_cmd_new_li;
            cache_req_critical_data_o = data_mem_pkt_yumi_i & fsm_cmd_new_li;
          end

          // Uncached Store/Req Done
          e_bedrock_cmd_uc_st_done: begin
            fsm_cmd_yumi_lo = fsm_cmd_v_li;
            uc_store_req_complete_o = fsm_cmd_yumi_lo;
          end

          // Writeback
          // Set State and Writeback
          e_bedrock_cmd_wb
          , e_bedrock_cmd_st_wb: begin
            // read block from data mem
            // data will be available in the first cycle of e_wb state
            data_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            data_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_v_o = fsm_cmd_v_li;

            // update state - write is idempotent
            tag_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            tag_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            tag_mem_pkt_cast_o.state = fsm_cmd_header_li.payload.state;
            tag_mem_pkt_cast_o.tag = fsm_cmd_header_li.addr[tag_offset_lp+:ctag_width_p];
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = fsm_cmd_v_li
                              & (fsm_cmd_header_li.msg_type.cmd inside {e_bedrock_cmd_st_wb}); 

            // read stat mem to determine if line is dirty
            stat_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            stat_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_v_o = fsm_cmd_v_li;

            fsm_cmd_yumi_lo = data_mem_pkt_yumi_i & stat_mem_pkt_yumi_i & (~tag_mem_pkt_v_o | tag_mem_pkt_yumi_i);

            state_n = fsm_cmd_yumi_lo
                      ? e_wb
                      : state_r;

          end

          // Transfer
          // Set State and Transfer
          // Set State, Transfer, and Writeback
          e_bedrock_cmd_tr
          , e_bedrock_cmd_st_tr
          , e_bedrock_cmd_st_tr_wb: begin
            // read block from data mem
            // data will be available in the first cycle of e_tr state
            data_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            data_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_v_o = fsm_cmd_v_li;

            // update state
            tag_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            tag_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            tag_mem_pkt_cast_o.state = fsm_cmd_header_li.payload.state;
            tag_mem_pkt_cast_o.tag = fsm_cmd_header_li.addr[tag_offset_lp+:ctag_width_p];
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = fsm_cmd_v_li
                              & (fsm_cmd_header_li.msg_type.cmd inside {e_bedrock_cmd_st_tr, e_bedrock_cmd_st_tr_wb}); 

            // try to speculatively read stat memory for writeback 
            stat_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
            stat_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_v_o = fsm_cmd_v_li 
                           & (fsm_cmd_header_li.msg_type.cmd == e_bedrock_cmd_st_tr_wb);

            // for both of these commands, do the transfer next
            state_n = (data_mem_pkt_yumi_i & (~tag_mem_pkt_v_o | tag_mem_pkt_yumi_i) & (~stat_mem_pkt_v_o | stat_mem_pkt_yumi_i))
                      ? e_tr
                      : state_r;

          end

          // for other message types in this state, use default as defined at top.
          default: begin
            state_n = state_r;
          end

        endcase // cmd.msg_type case
      end // e_ready

      // write data from command to cache
      // raise critical data signal only on first write
      e_data_to_cache: begin
        data_mem_pkt_cast_o.index = fsm_cmd_header_li.addr[block_byte_offset_lp+:lg_sets_lp];
        data_mem_pkt_cast_o.way_id = fsm_cmd_header_li.payload.way_id[0+:lg_assoc_lp];
        data_mem_pkt_cast_o.data = fsm_cmd_data_li;
        data_mem_pkt_cast_o.fill_index = 1'b1 << fill_index_shift; 
        data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
        data_mem_pkt_v_o = fsm_cmd_v_li;
        // consume data beat when write to cache occurs
        fsm_cmd_yumi_lo = data_mem_pkt_yumi_i;
        // critical beat is first data beat
        cache_req_critical_data_o = fsm_cmd_yumi_lo & fsm_cmd_new_li;

        state_n = (fsm_cmd_yumi_lo & fsm_cmd_last_li)
                  ? e_coh_ack
                  : state_r;

      end // e_data_to_cache

      // Transfer
      // send e_bedrock_fill_data header to target LCE
      // three commands enter this state: tr, st_tr, and st_tr_wb
      e_tr: begin

        fsm_fill_header_lo.msg_type.fill = e_bedrock_fill_data;
        fsm_fill_header_lo.addr = fsm_cmd_header_li.addr;
        fsm_fill_header_lo.size = bp_bedrock_msg_size_e'(cmd_block_size_lp);
        fsm_fill_header_lo.payload.dst_id = fsm_cmd_header_li.payload.target;
        // set src to be the CCE that sent the transfer command so the destination LCE knows
        // which CCE it must send its coherence ack to when the data command arrives
        fsm_fill_header_lo.payload.src_id = fsm_cmd_header_li.payload.src_id;
        fsm_fill_header_lo.payload.way_id = fsm_cmd_header_li.payload.target_way_id;
        fsm_fill_header_lo.payload.state = fsm_cmd_header_li.payload.target_state;

        dirty_data_select = fsm_fill_cnt_lo; 
        fsm_fill_data_lo = dirty_data_selected;

        // handshake - r&v
        fsm_fill_v_lo = fsm_cmd_v_li;
        fsm_cmd_yumi_lo = fsm_fill_v_lo & fsm_fill_ready_and_li & fsm_fill_last_lo;

        // send transfer data in next state
        state_n = fsm_cmd_yumi_lo
                  ? (fsm_cmd_header_li.msg_type.cmd == e_bedrock_cmd_st_tr_wb)
                    ? e_wb
                    : ((fsm_cmd_header_li.msg_type.cmd == e_bedrock_cmd_st_tr) && fsm_cmd_header_li.payload.state == e_COH_I)
                      ? e_stat_clear
                      : e_ready
                  : state_r;

      end // e_tr

      // Transfer Data to target LCE
      e_stat_clear: begin

        // clear dirty bit if command is e_lce_st_tr (not doing writeback) and block
        // is changing to invalid, since transfer target will take ownership of dirty block.
        // Thus, this LCE needs to make block clean (without the writeback).
        stat_mem_pkt_cast_o.index = fsm_cmd_header_r.addr[block_byte_offset_lp+:lg_sets_lp];
        stat_mem_pkt_cast_o.way_id = fsm_cmd_header_r.payload.way_id[0+:lg_assoc_lp];
        stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
        stat_mem_pkt_v_o = 1'b1;

        // move to next state when last data beat sends
        // do a writeback if needed, otherwise go to ready
        state_n = stat_mem_pkt_yumi_i 
                  ? e_ready
                  : state_r;

      end // e_stat_clear

      // Writeback
      // send writeback or null writeback header response, based on dirty bit from stat mem read
      // three commands enter this state: wb, st_wb, and st_tr_wb
      e_wb: begin

        fsm_resp_header_lo.addr = fsm_cmd_header_r.addr;
        fsm_resp_header_lo.msg_type.resp = dirty_stat_r.dirty[fsm_cmd_header_r.payload.way_id[0+:lg_assoc_lp]] 
                                               ? e_bedrock_resp_wb
                                               : e_bedrock_resp_null_wb;
        fsm_resp_header_lo.payload.src_id = lce_id_i;
        fsm_resp_header_lo.payload.dst_id = fsm_cmd_header_r.payload.src_id;
        fsm_resp_header_lo.size = dirty_stat_r.dirty[fsm_cmd_header_r.payload.way_id[0+:lg_assoc_lp]]
                                      ? bp_bedrock_msg_size_e'(cmd_block_size_lp)
                                      : e_bedrock_msg_size_1;
        dirty_data_select = fsm_resp_cnt_lo; 
        fsm_resp_data_lo = dirty_data_selected;
        fsm_resp_v_lo = 1'b1;

        state_n = (fsm_resp_ready_and_li & fsm_resp_v_lo)
                  ? dirty_stat_r.dirty[fsm_cmd_header_r.payload.way_id[0+:lg_assoc_lp]]
                    ? e_stat_clear
                    : e_ready
                  : state_r;

      end // e_wb

      // Send Coherence Ack message and raise request complete for one cycle
      e_coh_ack: begin
        fsm_resp_header_lo.addr = fsm_cmd_header_r.addr;
        fsm_resp_header_lo.msg_type.resp = e_bedrock_resp_coh_ack;
        fsm_resp_header_lo.payload.src_id = lce_id_i;
        fsm_resp_header_lo.payload.dst_id = fsm_cmd_header_r.payload.src_id;
        fsm_resp_v_lo = 1'b1;

        // cache request is complete when coherence ack sends
        cache_req_complete_o = fsm_resp_v_lo & fsm_resp_ready_and_li;

        state_n = cache_req_complete_o 
                  ? e_ready
                  : state_r;

      end // e_coh_ack

      // we should never get in this state, but if we do, return to reset
      default: begin
        state_n = e_reset;
      end
    endcase // state
  end

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
    end
    else begin
      state_r <= state_n;
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_lce_cmd)
