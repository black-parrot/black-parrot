/**
 *  Name:
 *    bp_lce_fill.sv
 *
 *  Description:
 *    LCE Fill network handler
 *
 *    The LCE Fill module performs a few key functions:
 *    1. reset tag and stat mem state in the cache after reset
 *    2. processes all inbound fill messages and sends coherence transaction acknowledgements
 *    3. informs the Request module when a transaction completes, thus freeing up a credit for
 *       a new transaction
 *
 *    This module does not perform any reads of the cache's stat, tag, or data memories.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce_fill
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // parameters specific to this LCE (these match the cache managed by the LCE)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   // LCE may have 1 outstanding data fill or uc load, but multiple uc store requests
   , parameter fill_buffer_els_p = 2
   , localparam fill_data_buffer_els_lp = fill_buffer_els_p*(block_width_p/fill_width_p)

   // derived parameters
   , localparam lg_assoc_lp = `BSG_SAFE_CLOG2(assoc_p)
   , localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
   // bytes per cache block
   , localparam block_size_in_bytes_lp = (block_width_p/8)
   // number of bits for byte select in block
   , localparam block_byte_offset_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
   // number of bytes per fill
   , localparam fill_bytes_lp = (fill_width_p/8)
   // byte offset bits per fill
   , localparam fill_byte_offset_lp = `BSG_SAFE_CLOG2(fill_bytes_lp)
   // number of fill per block
   , localparam block_size_in_fill_lp = (block_width_p/fill_width_p)
   // number of bits to select fill per block
   , localparam fill_select_width_lp = `BSG_SAFE_CLOG2(block_size_in_fill_lp)

   // width for counter used during initiliazation and for sync messages
   , localparam cnt_width_lp = `BSG_MAX(cce_id_width_p+1, `BSG_SAFE_CLOG2(sets_p)+1)
   , localparam cnt_max_val_lp = ((2**cnt_width_lp)-1)

   // coherence request size for cached requests
   , localparam bp_bedrock_msg_size_e cmd_block_size_lp = bp_bedrock_msg_size_e'(`BSG_SAFE_CLOG2(block_width_p/8))

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i

    , output logic                                   ready_o
    , output logic                                   init_done_o

    // LCE-Cache Interface
    // valid->yumi
    // commands issued that read and return data have data returned the cycle after
    // the valid->yumi command handshake occurs
    , output logic                                   tag_mem_pkt_v_o
    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , input                                          tag_mem_pkt_yumi_i

    , output logic                                   data_mem_pkt_v_o
    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input                                          data_mem_pkt_yumi_i

    , output logic                                   stat_mem_pkt_v_o
    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input                                          stat_mem_pkt_yumi_i

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
    , input [lce_fill_header_width_lp-1:0]           lce_fill_header_i
    , input                                          lce_fill_header_v_i
    , output logic                                   lce_fill_header_ready_and_o
    , input                                          lce_fill_has_data_i
    , input [fill_width_p-1:0]                       lce_fill_data_i
    , input                                          lce_fill_data_v_i
    , output logic                                   lce_fill_data_ready_and_o
    , input                                          lce_fill_last_i

    , output logic [lce_resp_header_width_lp-1:0]    lce_resp_header_o
    , output logic                                   lce_resp_header_v_o
    , input                                          lce_resp_header_ready_and_i
    , output logic                                   lce_resp_has_data_o
  );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `bp_cast_i(bp_bedrock_lce_fill_header_s, lce_fill_header);
  `bp_cast_o(bp_bedrock_lce_resp_header_s, lce_resp_header);

  `bp_cast_o(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_o(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_o(bp_cache_stat_mem_pkt_s, stat_mem_pkt);

  // LCE fill header buffer
  // Required for handshake conversion for cache interface packets
  bp_bedrock_lce_fill_header_s lce_fill_header_cast_li;
  logic lce_fill_header_v_li, lce_fill_header_yumi_lo, lce_fill_has_data;
  bsg_fifo_1r1w_small
    #(.width_p(lce_fill_header_width_lp+1)
      ,.els_p(fill_buffer_els_p)
      )
    lce_fill_header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_fill_header_v_i)
      ,.ready_o(lce_fill_header_ready_and_o)
      ,.data_i({lce_fill_has_data_i, lce_fill_header_cast_i})
      ,.v_o(lce_fill_header_v_li)
      ,.yumi_i(lce_fill_header_yumi_lo)
      ,.data_o({lce_fill_has_data, lce_fill_header_cast_li})
      );

  // LCE fill data buffer
  // required to prevent deadlock in multicore networks
  logic [fill_width_p-1:0] lce_fill_data_li;
  logic lce_fill_data_v_li, lce_fill_last_li, lce_fill_data_ready_and_lo, lce_fill_data_yumi_lo;
  if (fill_data_buffer_els_lp == 0) begin : data_passthrough
    assign lce_fill_data_li = lce_fill_data_i;
    assign lce_fill_data_v_li = lce_fill_data_v_i;
    assign lce_fill_last_li = lce_fill_last_i;
    assign lce_fill_data_ready_and_o = lce_fill_data_ready_and_lo;
    assign lce_fill_data_yumi_lo = 1'b0;
  end
  else begin : data_buffer
  bsg_fifo_1r1w_small
    #(.width_p(fill_width_p+1)
      ,.els_p(fill_data_buffer_els_lp)
      )
    lce_fill_data_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_fill_data_v_i)
      ,.ready_o(lce_fill_data_ready_and_o)
      ,.data_i({lce_fill_last_i, lce_fill_data_i})
      ,.v_o(lce_fill_data_v_li)
      ,.yumi_i(lce_fill_data_yumi_lo)
      ,.data_o({lce_fill_last_li, lce_fill_data_li})
      );
  assign lce_fill_data_yumi_lo = lce_fill_data_v_li & lce_fill_data_ready_and_lo;
  end

  // tag sent tracking
  // clears when header consumed
  logic critical_tag_sent_r, critical_tag_sent;
  bsg_dff_reset_set_clear
    #(.width_p(1)
      ,.clear_over_set_p(1)
      )
    critical_tag_sent_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(critical_tag_sent)
      ,.clear_i(lce_fill_header_yumi_lo)
      ,.data_o(critical_tag_sent_r)
      );
  assign cache_req_critical_tag_o = ~critical_tag_sent_r & critical_tag_sent;

  // first data beat is critical beat
  // clears when last data beat sent to cache (consumed from input)
  logic critical_data_sent_r, critical_data_sent;
  bsg_dff_reset_set_clear
    #(.width_p(1)
      ,.clear_over_set_p(1)
      )
    critical_data_sent_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(critical_data_sent)
      ,.clear_i(lce_fill_data_v_li & lce_fill_data_ready_and_lo & lce_fill_last_li)
      ,.data_o(critical_data_sent_r)
      );
  assign cache_req_critical_data_o = ~critical_data_sent_r & critical_data_sent;

  // number of fills required for arriving fill command
  // equivalent to number of data beats that arrive
  wire [fill_select_width_lp-1:0] fill_size_in_fill =
    `BSG_MAX((1'b1 << lce_fill_header_cast_li.size)/fill_bytes_lp, 1'b1) - 'd1;
  // first fill index of arriving command
  wire [fill_select_width_lp-1:0] first_cnt =
    lce_fill_header_cast_li.addr[fill_byte_offset_lp+:fill_select_width_lp];

  logic wrap_cnt_set, wrap_cnt_up;
  logic [fill_select_width_lp-1:0] wrap_cnt_size, full_cnt, wrap_cnt;

  // fill width and bedrock data width have same width
  // initial count set by FSM
  // size and first_cnt held constant by not dequeueing command header until all data consumed
  // increment count as each data beat is forwarded to cache
  // wrap count provides fill select as long as set_i and en_i not raised same cycle
  bp_me_stream_wraparound
    #(.max_val_p(block_size_in_fill_lp-1))
    cmd_wraparound_cnt
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.size_i(wrap_cnt_size)
      ,.set_i(wrap_cnt_set)
      ,.val_i(first_cnt)
      ,.en_i(wrap_cnt_up)
      ,.full_o(full_cnt)
      ,.wrap_o(wrap_cnt)
      );
  wire [fill_select_width_lp-1:0] last_cnt = first_cnt + wrap_cnt_size;
  wire is_last_cnt = (full_cnt == last_cnt);

  // decode wrap around count into one-hot fill index for data mem packet
  logic [block_size_in_fill_lp-1:0] fill_index, fill_index_li;
  bsg_decode
    #(.num_out_p(block_size_in_fill_lp))
    fill_index_decode
     (.i(wrap_cnt)
      ,.o(fill_index_li)
      );
  assign fill_index = (assoc_p == 1) ? 'b1 : fill_index_li;

  // FSM states
  enum logic [2:0] {
    e_reset
    ,e_clear
    ,e_ready
    ,e_data_to_cache
    ,e_coh_ack
  } state_n, state_r;

  // internal cache reset routine done register - goes high when FSM finishes resetting cache
  logic init_done_en, init_done_li;
  logic init_done_lo;
  bsg_dff_reset_en
    #(.width_p(1))
    init_done_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(init_done_en)
      ,.data_i(init_done_li)
      ,.data_o(init_done_o)
      );

  // common fields from LCE Fill used by FSM
  logic [lg_sets_lp-1:0] lce_fill_addr_index;
  logic [ptag_width_p-1:0] lce_fill_addr_tag;
  logic [lg_assoc_lp-1:0] lce_fill_way_id;

  assign lce_fill_addr_index = (sets_p > 1)
                               ? lce_fill_header_cast_li.addr[block_byte_offset_lp+:lg_sets_lp]
                               : '0;
  assign lce_fill_addr_tag = lce_fill_header_cast_li.addr[(paddr_width_p-1) -: ptag_width_p];
  assign lce_fill_way_id = lce_fill_header_cast_li.payload.way_id[0+:lg_assoc_lp];

  // LCE Command module is ready after it clears the cache's tag and stat memories
  assign ready_o = (state_r != e_reset) && (state_r != e_clear);

  // counter used by Fill FSM to clear cache state
  logic cnt_inc, cnt_clear;
  logic [cnt_width_lp-1:0] cnt_r;
  bsg_counter_clear_up
    #(.max_val_p(cnt_max_val_lp)
      ,.init_val_p(0)
      )
    counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_clear)
      ,.up_i(cnt_inc)
      ,.count_o(cnt_r)
      );

  always_comb begin

    state_n = state_r;

    // uc store committed
    uc_store_req_complete_o = 1'b0;
    // raised request is fully resolved
    cache_req_complete_o = 1'b0;

    // wrap around count set / start transaction
    wrap_cnt_set = 1'b0;
    // wrap around count increment
    wrap_cnt_up = 1'b0;
    // default size input comes from inbound command
    wrap_cnt_size = fill_size_in_fill;

    critical_tag_sent = 1'b0;
    critical_data_sent = 1'b0;

    // LCE-CCE Interface signals
    lce_fill_header_yumi_lo = 1'b0;
    lce_fill_data_ready_and_lo = 1'b0;

    lce_resp_header_cast_o = '0;
    lce_resp_header_v_o = 1'b0;
    lce_resp_has_data_o = 1'b0;

    // LCE-Cache Interface signals
    data_mem_pkt_cast_o = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt_cast_o = '0;
    tag_mem_pkt_v_o = 1'b0;
    stat_mem_pkt_cast_o = '0;
    stat_mem_pkt_v_o = 1'b0;

    // Counter
    cnt_inc = 1'b0;
    cnt_clear = reset_i;

    // DFF register signals
    init_done_en = 1'b0;
    init_done_li = 1'b0;

    // Fill FSM
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

        state_n = ((cnt_r == cnt_width_lp'(lce_sets_p-1)) & tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
                  ? e_ready
                  : e_clear;

        cnt_clear = (state_n == e_ready);
        cnt_inc = ~cnt_clear & (tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i);

        // signal to command FSM that reset is complete
        init_done_en = cnt_clear;
        init_done_li = 1'b1;
      end

      // Ready for Fill messages (completes this LCE's cache request) has priority
      // for *_mem_pkt interfaces to cache over Command FSM
      e_ready: begin
        unique case (lce_fill_header_cast_li.msg_type.fill)
          // Set State and Wakeup
          // Write the state as commanded, send coherence ack, and complete request
          e_bedrock_fill_st_wakeup: begin
            tag_mem_pkt_cast_o.index = lce_fill_addr_index;
            tag_mem_pkt_cast_o.way_id = lce_fill_way_id;
            tag_mem_pkt_cast_o.state = lce_fill_header_cast_li.payload.state;
            tag_mem_pkt_cast_o.tag = lce_fill_addr_tag;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = lce_fill_header_v_li;

            critical_tag_sent = tag_mem_pkt_yumi_i & ~critical_tag_sent_r;

            state_n = tag_mem_pkt_yumi_i
                      ? e_coh_ack
                      : state_r;

          end

          // Data and Tag - cache block data, tag, and state from coherence directory
          // completes a regular cache miss
          // sends tag in this state, and data in next state
          e_bedrock_fill_data: begin
            tag_mem_pkt_cast_o.index = lce_fill_addr_index;
            tag_mem_pkt_cast_o.way_id = lce_fill_way_id;
            tag_mem_pkt_cast_o.state = lce_fill_header_cast_li.payload.state;
            tag_mem_pkt_cast_o.tag = lce_fill_addr_tag;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v_o = lce_fill_header_v_li;
            critical_tag_sent = tag_mem_pkt_yumi_i & ~critical_tag_sent_r;
            wrap_cnt_set = tag_mem_pkt_yumi_i;

            // do not consume header since it is needed to compute fill index for cache data writes
            state_n = (tag_mem_pkt_yumi_i)
                      ? e_data_to_cache
                      : state_r;
          end

          // Uncached Data - uncached load returning from memory
          // sends data to cache and raises request complete signal for one cycle
          // Requires valid header (buffered) and data
          // note: supports uncached accesses up to fill_width_p in size
          e_bedrock_fill_uc_data: begin
            data_mem_pkt_cast_o.index = lce_fill_addr_index;
            data_mem_pkt_cast_o.data = lce_fill_data_li;
            data_mem_pkt_cast_o.fill_index = block_size_in_fill_lp'(1'b1);
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_v_o = lce_fill_header_v_li & lce_fill_data_v_li;

            // consume single data beat and header when data packet is consumed by cache
            lce_fill_data_ready_and_lo = data_mem_pkt_yumi_i;
            lce_fill_header_yumi_lo = data_mem_pkt_yumi_i;

            // raise request complete signal when data consumed
            cache_req_complete_o = data_mem_pkt_yumi_i;
            critical_data_sent = data_mem_pkt_yumi_i & ~critical_data_sent_r;
            critical_tag_sent = data_mem_pkt_yumi_i & ~critical_tag_sent_r;
          end

          // Uncached Done - uncached request with no response data is complete
          // completes an uncached store operation
          e_bedrock_fill_uc_done: begin
            // dequeue message and assert request complete signal for a cycle
            lce_fill_header_yumi_lo = lce_fill_header_v_li;
            uc_store_req_complete_o = lce_fill_header_yumi_lo;
          end

          default: begin
            state_n = state_r;
          end
        endcase // Fill message
      end // e_ready

      // write data from command to cache
      // raise critical data signal only on first write
      e_data_to_cache: begin
        data_mem_pkt_cast_o.index = lce_fill_addr_index;
        data_mem_pkt_cast_o.way_id = lce_fill_way_id;
        data_mem_pkt_cast_o.data = lce_fill_data_li;
        data_mem_pkt_cast_o.fill_index = fill_index;
        data_mem_pkt_cast_o.opcode = e_cache_data_mem_write;
        data_mem_pkt_v_o = lce_fill_data_v_li;
        // consume data beat when write to cache occurs
        lce_fill_data_ready_and_lo = data_mem_pkt_yumi_i;
        // increment wrap around count as each data beat sends
        wrap_cnt_up = lce_fill_data_v_li & lce_fill_data_ready_and_lo;
        // critical beat is first data beat
        critical_data_sent = data_mem_pkt_yumi_i & ~critical_data_sent_r;

        // do not consume header yet, will be consumed by sending coherence ack

        state_n = (lce_fill_data_v_li & lce_fill_data_ready_and_lo & lce_fill_last_li)
                  ? e_coh_ack
                  : state_r;

      end // e_data_to_cache

      // Send Coherence Ack message and raise request complete for one cycle
      e_coh_ack: begin
        lce_resp_header_cast_o.addr = lce_fill_header_cast_li.addr;
        lce_resp_header_cast_o.msg_type.resp = e_bedrock_resp_coh_ack;
        lce_resp_header_cast_o.payload.src_id = lce_id_i;
        lce_resp_header_cast_o.payload.dst_id = lce_fill_header_cast_li.payload.src_id;
        lce_resp_header_v_o = lce_fill_header_v_li;

        // consume header when sending ack
        lce_fill_header_yumi_lo = lce_resp_header_v_o & lce_resp_header_ready_and_i;

        // cache request is complete when coherence ack sends
        cache_req_complete_o = lce_fill_header_yumi_lo;

        state_n = lce_fill_header_yumi_lo
                  ? e_ready
                  : state_r;

      end // e_coh_ack

      default: begin
        state_n = state_r;
      end
    endcase // Fill FSM
  end

  //synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
    end
    else begin
      state_r <= state_n;
    end
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_lce_fill)
