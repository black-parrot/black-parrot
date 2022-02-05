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
   // number of LCE command buffer elements
   , parameter cmd_buffer_els_p = 2
   // command network messages, as currently defined, do not have data
   , localparam cmd_data_buffer_els_lp = 0 //cmd_buffer_els_p*(block_width_p/fill_width_p)

   // clocking options
   , parameter data_mem_invert_clk_p = 0
   , parameter tag_mem_invert_clk_p = 0
   , parameter stat_mem_invert_clk_p = 0

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
    , input bp_lce_mode_e                            lce_mode_i

    , output logic                                   ready_o
    , output logic                                   sync_done_o
    , input                                          init_done_i

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

  // LCE command header buffer
  // Required for handshake conversion for cache interface packets
  bp_bedrock_lce_cmd_header_s lce_cmd_header_cast_li;
  logic lce_cmd_header_v_li, lce_cmd_header_yumi_lo, lce_cmd_has_data;
  bsg_fifo_1r1w_small
    #(.width_p(lce_cmd_header_width_lp+1)
      ,.els_p(cmd_buffer_els_p)
      )
    lce_cmd_header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_cmd_header_v_i)
      ,.ready_o(lce_cmd_header_ready_and_o)
      ,.data_i({lce_cmd_has_data_i, lce_cmd_header_cast_i})
      ,.v_o(lce_cmd_header_v_li)
      ,.yumi_i(lce_cmd_header_yumi_lo)
      ,.data_o({lce_cmd_has_data, lce_cmd_header_cast_li})
      );

  // LCE command data buffer
  // required to prevent deadlock in multicore networks
  logic [fill_width_p-1:0] lce_cmd_data_li;
  logic lce_cmd_data_v_li, lce_cmd_last_li, lce_cmd_data_ready_and_lo, lce_cmd_data_yumi_lo;
  if (cmd_data_buffer_els_lp == 0) begin : data_passthrough
    assign lce_cmd_data_li = lce_cmd_data_i;
    assign lce_cmd_data_v_li = lce_cmd_data_v_i;
    assign lce_cmd_last_li = lce_cmd_last_i;
    assign lce_cmd_data_ready_and_o = lce_cmd_data_ready_and_lo;
    assign lce_cmd_data_yumi_lo = 1'b0;
  end
  else begin : data_buffer
  bsg_fifo_1r1w_small
    #(.width_p(fill_width_p+1)
      ,.els_p(cmd_data_buffer_els_lp)
      )
    lce_cmd_data_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_cmd_data_v_i)
      ,.ready_o(lce_cmd_data_ready_and_o)
      ,.data_i({lce_cmd_last_i, lce_cmd_data_i})
      ,.v_o(lce_cmd_data_v_li)
      ,.yumi_i(lce_cmd_data_yumi_lo)
      ,.data_o({lce_cmd_last_li, lce_cmd_data_li})
      );
  assign lce_cmd_data_yumi_lo = lce_cmd_data_v_li & lce_cmd_data_ready_and_lo;
  end

  // first fill index of arriving command
  wire [fill_select_width_lp-1:0] first_cnt =
    lce_cmd_header_cast_li.addr[fill_byte_offset_lp+:fill_select_width_lp];

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
    ,e_ready
    ,e_tr
    ,e_tr_data
    ,e_wb
    ,e_wb_stat_rd
    ,e_wb_dirty_rd
    ,e_wb_dirty_send_data
  } state_n, state_r;

  // sync done register - goes high when all sync command/acks complete
  logic sync_done_en, sync_done_li;
  bsg_dff_reset_en
    #(.width_p(1))
    sync_done_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(sync_done_en)
      ,.data_i(sync_done_li)
      ,.data_o(sync_done_o)
      );

  logic [block_width_p-1:0] dirty_data_r;
  logic dirty_data_v_r;
  wire dirty_data_read = data_mem_pkt_yumi_i & (data_mem_pkt_cast_o.opcode == e_cache_data_mem_read);
  wire data_mem_clk = (data_mem_invert_clk_p ? ~clk_i : clk_i);
  bsg_dff_sync_read
   #(.width_p(block_width_p))
   dirty_data_reg
    (.clk_i(data_mem_clk)
     ,.reset_i(reset_i)

     ,.data_i(data_mem_i)
     ,.v_n_i(dirty_data_read)

     ,.data_o(dirty_data_r)
     ,.v_o(dirty_data_v_r)
     ,.yumi_i(dirty_data_read)
     );

  // data mux to pick fill word for sending in command/response data beat
  logic [fill_width_p-1:0] dirty_data_selected;
  bsg_mux
    #(.width_p(fill_width_p)
      ,.els_p(block_size_in_fill_lp))
    dirty_data_mux
     (.data_i(dirty_data_r)
      ,.sel_i(wrap_cnt)
      ,.data_o(dirty_data_selected)
      );

  bp_cache_tag_info_s dirty_tag_r;
  logic dirty_tag_v_r;
  wire dirty_tag_read = tag_mem_pkt_yumi_i & (tag_mem_pkt_cast_o.opcode == e_cache_tag_mem_read);
  wire tag_mem_clk = (tag_mem_invert_clk_p ? ~clk_i : clk_i);
  bsg_dff_sync_read
   #(.width_p($bits(bp_cache_tag_info_s)))
   dirty_tag_reg
    (.clk_i(tag_mem_clk)
     ,.reset_i(reset_i)

     ,.data_i(tag_mem_i)
     ,.v_n_i(dirty_tag_read)

     ,.data_o(dirty_tag_r)
     ,.v_o(dirty_tag_v_r)
     ,.yumi_i(dirty_tag_read)
     );

  bp_cache_stat_info_s dirty_stat_r;
  logic dirty_stat_v_r;
  wire dirty_stat_read = stat_mem_pkt_yumi_i & (stat_mem_pkt_cast_o.opcode == e_cache_stat_mem_read);
  wire stat_mem_clk = (stat_mem_invert_clk_p ? ~clk_i : clk_i);
  bsg_dff_sync_read
   #(.width_p($bits(bp_cache_stat_info_s)))
   dirty_stat_reg
    (.clk_i(stat_mem_clk)
     ,.reset_i(reset_i)

     ,.data_i(stat_mem_i)
     ,.v_n_i(dirty_stat_read)

     ,.data_o(dirty_stat_r)
     ,.v_o(dirty_stat_v_r)
     ,.yumi_i(dirty_stat_read)
     );

  // common fields from LCE Command used in many states for responses or pkt fields
  logic [lg_sets_lp-1:0] lce_cmd_addr_index;
  logic [ptag_width_p-1:0] lce_cmd_addr_tag;
  logic [lg_assoc_lp-1:0] lce_cmd_way_id;

  assign lce_cmd_addr_index = (sets_p > 1)
                              ? lce_cmd_header_cast_li.addr[block_byte_offset_lp+:lg_sets_lp]
                              : '0;
  assign lce_cmd_addr_tag = lce_cmd_header_cast_li.addr[(paddr_width_p-1) -: ptag_width_p];
  assign lce_cmd_way_id = lce_cmd_header_cast_li.payload.way_id[0+:lg_assoc_lp];

  // LCE Command module is ready after it clears the cache's tag and stat memories
  assign ready_o = (state_r != e_reset);

  // counter used by Command FSM to perform sync sequence
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

    // wrap around count set / start transaction
    wrap_cnt_set = 1'b0;
    // wrap around count increment
    wrap_cnt_up = 1'b0;
    // default size input comes from inbound command
    wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);

    // LCE-CCE Interface signals
    lce_cmd_header_yumi_lo = 1'b0;
    lce_cmd_data_ready_and_lo = 1'b0;

    lce_fill_header_cast_o = '0;
    lce_fill_header_v_o = 1'b0;
    lce_fill_has_data_o = 1'b0;
    lce_fill_data_o = '0;
    lce_fill_data_v_o = 1'b0;
    lce_fill_last_o = 1'b0;

    lce_resp_header_cast_o = '0;
    lce_resp_header_v_o = 1'b0;
    lce_resp_has_data_o = 1'b0;
    lce_resp_data_o = '0;
    lce_resp_data_v_o = 1'b0;
    lce_resp_last_o = 1'b0;

    // Counter
    cnt_inc = 1'b0;
    cnt_clear = reset_i;

    // DFF register signals
    sync_done_en = 1'b0;
    sync_done_li = 1'b0;

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
        state_n = init_done_i ? e_ready : state_r;
      end

      // Ready for LCE Commands
      e_ready: begin
        unique case (lce_cmd_header_cast_li.msg_type.cmd)

          /*
           * Commands that don't read/write cache data memory
           */

          // Sync
          e_bedrock_cmd_sync: begin
            lce_resp_header_cast_o.payload.dst_id = lce_cmd_header_cast_li.payload.src_id;
            lce_resp_header_cast_o.payload.src_id = lce_id_i;
            lce_resp_header_cast_o.msg_type.resp = e_bedrock_resp_sync_ack;
            // handshake
            // response (r&v) can send when header is valid
            lce_resp_header_v_o = lce_cmd_header_v_li;
            // header (v->y) consumed when response sends
            lce_cmd_header_yumi_lo = lce_resp_header_v_o & lce_resp_header_ready_and_i;

            // reset the counter when last sync is received and ack is sent
            cnt_clear = ((cnt_r == cnt_width_lp'(num_cce_p-1))
                         & (lce_resp_header_v_o & lce_resp_header_ready_and_i));
            // increment as long as not resetting counter
            cnt_inc = ~cnt_clear & (lce_resp_header_v_o & lce_resp_header_ready_and_i);
            // sync is done when last sync is received and ack is sent
            sync_done_en = cnt_clear;
            sync_done_li = 1'b1;

          end

          // Set Clear - invalidate entire set specified by command
          // cache tag and stat writes are idempotent
          e_bedrock_cmd_set_clear: begin
            tag_mem_pkt_cast_o.index = lce_cmd_addr_index;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_v_o = lce_cmd_header_v_li;

            stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_v_o = lce_cmd_header_v_li;

            // consume header when tag and stat packets consumed together
            lce_cmd_header_yumi_lo = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;

          end

          // Invalidate Tag - write tag mem and send Invalidate Ack
          // cache tag write is idempotent
          e_bedrock_cmd_inv: begin
            tag_mem_pkt_cast_o.index = lce_cmd_addr_index;
            tag_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            tag_mem_pkt_cast_o.state = e_COH_I;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = lce_cmd_header_v_li;

            // response can send if tag mem packet consumed by cache
            lce_resp_header_v_o = tag_mem_pkt_yumi_i;
            lce_resp_header_cast_o.addr = lce_cmd_header_cast_li.addr;
            lce_resp_header_cast_o.msg_type.resp = e_bedrock_resp_inv_ack;
            lce_resp_header_cast_o.payload.src_id = lce_id_i;
            lce_resp_header_cast_o.payload.dst_id = lce_cmd_header_cast_li.payload.src_id;

            // consume command header when response sends
            lce_cmd_header_yumi_lo = lce_resp_header_v_o & lce_resp_header_ready_and_i;

          end

          // Set State
          // Write the state as commanded, no response sent
          // cache tag write is idempotent
          e_bedrock_cmd_st: begin
            tag_mem_pkt_cast_o.index = lce_cmd_addr_index;
            tag_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            tag_mem_pkt_cast_o.state = lce_cmd_header_cast_li.payload.state;
            tag_mem_pkt_cast_o.tag = '0;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = lce_cmd_header_v_li;

            // consume header when tag write consumed by cache
            lce_cmd_header_yumi_lo = tag_mem_pkt_yumi_i;

          end

          /*
           * Commands that read/write cache data memory
           */

          // Writeback
          e_bedrock_cmd_wb: begin

            // read stat mem to determine if line is dirty
            stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
            stat_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_v_o = lce_cmd_header_v_li;

            state_n = stat_mem_pkt_yumi_i
              ? e_wb
              : state_r;

          end

          // Set State and Writeback
          e_bedrock_cmd_st_wb: begin
            // update state - write is idempotent
            tag_mem_pkt_cast_o.index = lce_cmd_addr_index;
            tag_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            tag_mem_pkt_cast_o.state = lce_cmd_header_cast_li.payload.state;
            tag_mem_pkt_cast_o.tag = lce_cmd_addr_tag;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = lce_cmd_header_v_li;

            // read stat mem to determine if line is dirty
            stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
            stat_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_v_o = lce_cmd_header_v_li;

            state_n = (stat_mem_pkt_yumi_i & tag_mem_pkt_yumi_i)
              ? e_wb
              : state_r;

          end

          // Transfer
          e_bedrock_cmd_tr: begin

            // read block from data mem
            // data will be available in the first cycle of e_tr state
            data_mem_pkt_cast_o.index = lce_cmd_addr_index;
            data_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_v_o = lce_cmd_header_v_li;

            // setup wraparound counter
            wrap_cnt_set = data_mem_pkt_yumi_i;
            wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);

            state_n = data_mem_pkt_yumi_i
              ? e_tr
              : state_r;

          end

          // Set State and Transfer
          // Set State, Transfer, and Writeback
          e_bedrock_cmd_st_tr
          , e_bedrock_cmd_st_tr_wb: begin
            // update state
            tag_mem_pkt_cast_o.index = lce_cmd_addr_index;
            tag_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            tag_mem_pkt_cast_o.state = lce_cmd_header_cast_li.payload.state;
            tag_mem_pkt_cast_o.tag = lce_cmd_addr_tag;
            tag_mem_pkt_cast_o.opcode = e_cache_tag_mem_set_state;
            tag_mem_pkt_v_o = lce_cmd_header_v_li;

            // read block from data mem
            // data will be available in the first cycle of e_tr state
            data_mem_pkt_cast_o.index = lce_cmd_addr_index;
            data_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
            data_mem_pkt_v_o = lce_cmd_header_v_li;

            // clear dirty bit if command is e_lce_st_tr (not doing writeback) and block
            // is changing to invalid, since transfer target will take ownership of dirty block.
            // Thus, this LCE needs to make block clean (without the writeback).
            stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
            stat_mem_pkt_cast_o.way_id = lce_cmd_way_id;
            stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
            stat_mem_pkt_v_o = lce_cmd_header_v_li
                               & (lce_cmd_header_cast_li.msg_type.cmd == e_bedrock_cmd_st_tr)
                               & (lce_cmd_header_cast_li.payload.state == e_COH_I);

            // setup wraparound counter
            wrap_cnt_set = data_mem_pkt_yumi_i & tag_mem_pkt_yumi_i
                           & (~stat_mem_pkt_v_o | stat_mem_pkt_yumi_i);
            wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);

            // for both of these commands, do the transfer next
            state_n = (data_mem_pkt_yumi_i & tag_mem_pkt_yumi_i & (~stat_mem_pkt_v_o | stat_mem_pkt_yumi_i))
                      ? e_tr
                      : state_r;

          end

          // for other message types in this state, use default as defined at top.
          default: begin
            state_n = state_r;
          end

        endcase // cmd.msg_type case
      end // e_ready

      // Transfer
      // send e_bedrock_fill_data header to target LCE
      // three commands enter this state: tr, st_tr, and st_tr_wb
      e_tr: begin

        lce_fill_header_cast_o.msg_type.fill = e_bedrock_fill_data;
        lce_fill_header_cast_o.addr = lce_cmd_header_cast_li.addr;
        lce_fill_header_cast_o.size = cmd_block_size_lp;
        lce_fill_header_cast_o.payload.dst_id = lce_cmd_header_cast_li.payload.target;
        // set src to be the CCE that sent the transfer command so the destination LCE knows
        // which CCE it must send its coherence ack to when the data command arrives
        lce_fill_header_cast_o.payload.src_id = lce_cmd_header_cast_li.payload.src_id;
        lce_fill_header_cast_o.payload.way_id = lce_cmd_header_cast_li.payload.target_way_id;
        lce_fill_header_cast_o.payload.state = lce_cmd_header_cast_li.payload.target_state;

        // handshake - r&v
        lce_fill_header_v_o = lce_cmd_header_v_li;
        lce_fill_has_data_o = 1'b1;

        // hold wraparound counter size input constant
        wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);

        // send transfer data in next state
        state_n = (lce_fill_header_v_o & lce_fill_header_ready_and_i)
                  ? e_tr_data
                  : state_r;

      end // e_tr

      // Transfer Data to target LCE
      // dirty_data_r holds valid data when dirty_data_v_r is high
      // three commands enter this state: tr, st_tr, and st_tr_wb
      e_tr_data: begin

        lce_fill_data_o = dirty_data_selected;
        lce_fill_last_o = is_last_cnt;
        lce_fill_data_v_o = dirty_data_v_r;

        // hold wraparound counter size input constant
        wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);
        // increment counter on each data beat
        wrap_cnt_up = lce_fill_data_v_o & lce_fill_data_ready_and_i;

        // dequeue the command if transfer is last action
        lce_cmd_header_yumi_lo = lce_fill_data_v_o & lce_fill_data_ready_and_i & lce_fill_last_o
                                 & (lce_cmd_header_cast_li.msg_type.cmd != e_bedrock_cmd_st_tr_wb);

        // try to opportunistically read stat memory if writeback is required
        stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
        stat_mem_pkt_cast_o.way_id = lce_cmd_way_id;
        stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
        stat_mem_pkt_v_o = lce_fill_data_v_o & lce_fill_data_ready_and_i & lce_fill_last_o
                           & (lce_cmd_header_cast_li.msg_type.cmd == e_bedrock_cmd_st_tr_wb);

        // move to next state when last data beat sends
        // do a writeback if needed, otherwise go to ready
        // skip e_wb_stat_rd if stat read was accepted this cycle
        state_n = (lce_fill_data_v_o & lce_fill_data_ready_and_i & lce_fill_last_o)
                  ? (lce_cmd_header_cast_li.msg_type.cmd == e_bedrock_cmd_st_tr_wb)
                    ? (stat_mem_pkt_yumi_i)
                      ? e_wb
                      : e_wb_stat_rd
                    : e_ready
                  : state_r;

      end // e_tr_data

      // Writeback stat mem read, when processing e_bedrock_cmd_st_tr_wb
      // i.e., after the set state and transfer happen
      e_wb_stat_rd: begin
        // read stat mem to determine if line is dirty
        stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
        stat_mem_pkt_cast_o.way_id = lce_cmd_way_id;
        stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_read;
        stat_mem_pkt_v_o = lce_cmd_header_v_li;

        state_n = stat_mem_pkt_yumi_i
                  ? e_wb
                  : state_r;

      end // e_wb_stat_rd

      // Writeback
      // send writeback or null writeback header response, based on dirty bit from stat mem read
      // three commands enter this state: wb, st_wb, and st_tr_wb
      e_wb: begin

        lce_resp_has_data_o = dirty_stat_r.dirty[lce_cmd_way_id];
        lce_resp_header_cast_o.addr = lce_cmd_header_cast_li.addr;
        lce_resp_header_cast_o.msg_type.resp = (lce_resp_has_data_o)
                                               ? e_bedrock_resp_wb
                                               : e_bedrock_resp_null_wb;
        lce_resp_header_cast_o.payload.src_id = lce_id_i;
        lce_resp_header_cast_o.payload.dst_id = lce_cmd_header_cast_li.payload.src_id;
        lce_resp_header_cast_o.size = (lce_resp_has_data_o)
                                      ? cmd_block_size_lp
                                      : e_bedrock_msg_size_1;
        // send if stat read is valid
        lce_resp_header_v_o = dirty_stat_v_r;

        // dequeue command only if sending null writeback
        lce_cmd_header_yumi_lo = lce_resp_header_v_o & lce_resp_header_ready_and_i
                                 & ~lce_resp_has_data_o;

        state_n = (lce_resp_header_v_o & lce_resp_header_ready_and_i)
                  ? (lce_resp_has_data_o)
                    ? e_wb_dirty_rd
                    : e_ready
                  : state_r;

      end // e_wb

      // Writeback dirty block - read from data memory, write to stat memory to clear dirty bit
      // three commands enter this state: wb, st_wb, and st_tr_wb
      e_wb_dirty_rd: begin

        // read from data memory
        data_mem_pkt_cast_o.index = lce_cmd_addr_index;
        data_mem_pkt_cast_o.way_id = lce_cmd_way_id;
        data_mem_pkt_cast_o.opcode = e_cache_data_mem_read;
        data_mem_pkt_v_o = 1'b1;

        // write to stat memory
        stat_mem_pkt_cast_o.index = lce_cmd_addr_index;
        stat_mem_pkt_cast_o.way_id = lce_cmd_way_id;
        stat_mem_pkt_cast_o.opcode = e_cache_stat_mem_clear_dirty;
        stat_mem_pkt_v_o = 1'b1;

        // setup wraparound counter
        wrap_cnt_set = stat_mem_pkt_yumi_i & data_mem_pkt_yumi_i;
        wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);

        // move to next state once both data and stat mem commands have sent
        state_n = (data_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
                  ? e_wb_dirty_send_data
                  : state_r;

      end // e_wb_dirty_rd

      e_wb_dirty_send_data: begin

        lce_resp_data_o = dirty_data_selected;
        lce_resp_last_o = is_last_cnt;
        lce_resp_data_v_o = dirty_data_v_r;

        // hold wraparound counter size input constant
        wrap_cnt_size = fill_select_width_lp'(block_size_in_fill_lp-1);
        // increment counter on each data beat
        wrap_cnt_up = lce_resp_data_v_o & lce_resp_data_ready_and_i;

        // dequeue the command on last data beat
        lce_cmd_header_yumi_lo = lce_resp_data_v_o & lce_resp_data_ready_and_i & lce_resp_last_o;

        // go back to ready when last beat sends
        state_n = (lce_resp_data_v_o & lce_resp_data_ready_and_i & lce_resp_last_o)
                  ? e_ready
                  : state_r;

      end // e_wb_dirty_send_data

      // we should never get in this state, but if we do, return to reset
      default: begin
        state_n = e_reset;
      end
    endcase // state
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

`BSG_ABSTRACT_MODULE(bp_lce_cmd)
