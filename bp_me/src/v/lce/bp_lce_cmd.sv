/**
 *  Name:
 *    bp_lce_cmd.v
 *
 *  Description:
 *    LCE command handler
 *
 *    The LCE Command module performs a few key functions:
 *    1. reset tag and stat mem state in the cache after reset
 *    2. processes all inbound commands, issues outbound commands (transfers), and sens coherence
 *       response messages to maintain coherence
 *    3. informs the Request module when a transaction completes, thus freeing up a credit for
 *       a new transaction
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce_cmd
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

    // parameters specific to this LCE
    , parameter assoc_p = "inv"
    , parameter sets_p = "inv"
    , parameter block_width_p = "inv"
    , parameter fill_width_p = block_width_p
    , parameter data_mem_invert_clk_p = 0
    , parameter tag_mem_invert_clk_p = 0
    , parameter stat_mem_invert_clk_p = 0

    , parameter timeout_max_limit_p=4

    , localparam block_size_in_bytes_lp = (block_width_p/8)
    , localparam lg_assoc_lp = `BSG_SAFE_CLOG2(assoc_p)
    , localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)

    // width for counter used during initiliazation and for sync messages
    , localparam cnt_width_lp = `BSG_MAX(cce_id_width_p+1, `BSG_SAFE_CLOG2(sets_p)+1)
    , localparam cnt_max_val_lp = ((2**cnt_width_lp)-1)

    // coherence request size for cached requests
    // block size smaller than 8-bytes not supported
    , localparam bp_bedrock_msg_size_e cmd_block_size_lp =
      (block_size_in_bytes_lp == 128)
      ? e_bedrock_msg_size_128
      : (block_size_in_bytes_lp == 64)
        ? e_bedrock_msg_size_64
        : (block_size_in_bytes_lp == 32)
          ? e_bedrock_msg_size_32
          : (block_size_in_bytes_lp == 16)
            ? e_bedrock_msg_size_16
            : e_bedrock_msg_size_8

    , localparam block_size_in_fill_lp = block_width_p/fill_width_p
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i
    , input bp_lce_mode_e                            lce_mode_i

    , output logic                                   ready_o
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
    , output logic                                   cache_req_complete_o
    , output logic                                   cache_req_critical_o
    // uncached store request complete is used by the LCE to decrement the request credit counter
    // when an uncached store complete, but is not routed to the cache because the caches do not
    // block (miss) on uncached stores
    , output logic                                   uc_store_req_complete_o

    // LCE-CCE interface
    // Resp: ready->valid
    , output logic [lce_resp_msg_width_lp-1:0]       lce_resp_o
    , output logic                                   lce_resp_v_o
    , input                                          lce_resp_ready_i

    // CCE-LCE interface
    // Cmd_i: valid->yumi
    , input [lce_cmd_msg_width_lp-1:0]               lce_cmd_i
    , input                                          lce_cmd_v_i
    , output logic                                   lce_cmd_yumi_o

    // LCE-LCE interface
    // Cmd_o: ready->valid
    , output logic [lce_cmd_msg_width_lp-1:0]        lce_cmd_o
    , output logic                                   lce_cmd_v_o
    , input                                          lce_cmd_ready_i
  );

  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);

  // FSM states
  typedef enum logic [3:0] {
    e_reset
    ,e_clear
    ,e_ready
    ,e_tr
    ,e_wb
    ,e_wb_stat_rd
    ,e_wb_dirty_rd
    ,e_wb_dirty_send
    ,e_coh_ack
  } lce_cmd_state_e;
  lce_cmd_state_e state_r, state_n;

  bp_bedrock_lce_cmd_msg_s lce_cmd, lce_cmd_out;
  bp_bedrock_lce_resp_msg_s lce_resp;
  bp_bedrock_lce_cmd_payload_s lce_cmd_payload, lce_cmd_out_payload;
  bp_bedrock_lce_resp_payload_s lce_resp_payload;

  assign lce_cmd = lce_cmd_i;
  assign lce_cmd_payload = lce_cmd.header.payload;
  assign lce_resp_o = lce_resp;
  assign lce_cmd_o = lce_cmd_out;

  bp_cache_data_mem_pkt_s data_mem_pkt;
  bp_cache_tag_mem_pkt_s tag_mem_pkt;
  bp_cache_stat_mem_pkt_s stat_mem_pkt;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;

  // sync done register - goes high when all sync command/acks complete
  logic sync_done_en, sync_done_li;
  bsg_dff_en
    #(.width_p(1))
    sync_done_reg
     (.clk_i(clk_i)
      ,.en_i(sync_done_en)
      ,.data_i(sync_done_li)
      ,.data_o(sync_done_o)
      );

  // data buffer and enable register
  // the enable register is set when the data_mem_pkt is accepted and the command is a mem read,
  // which will capture the data into the data buffer on the next cycle (when it is guaranteed to
  // be valid on the data_mem_i port). The data will remain in the buffer until the next read
  // command is accepted and new data is latched.
  logic data_buf_read_en;
  wire data_buf_read = data_mem_pkt_yumi_i & (data_mem_pkt.opcode == e_cache_data_mem_read);
  wire data_mem_clk = (data_mem_invert_clk_p ? ~clk_i : clk_i);
  bsg_dff
   #(.width_p(1))
   data_buf_read_en_reg
    (.clk_i(data_mem_clk)

     ,.data_i(data_buf_read)
     ,.data_o(data_buf_read_en)
     );

  logic data_buf_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   data_buf_v_reg
    (.clk_i(data_mem_clk)
     ,.reset_i(reset_i)

     ,.set_i(data_buf_read_en)
     ,.clear_i(data_buf_read)
     ,.data_o(data_buf_v_r)
     );

  logic [cce_block_width_p-1:0] data_buf_r;
  bsg_dff_en
    #(.width_p(cce_block_width_p))
    data_buf_reg
     (.clk_i(data_mem_clk)
      ,.en_i(data_buf_read_en)
      ,.data_i(data_mem_i)
      ,.data_o(data_buf_r)
      );

  logic stat_buf_read_en;
  wire stat_buf_read = stat_mem_pkt_yumi_i & (stat_mem_pkt.opcode == e_cache_stat_mem_read);
  wire stat_mem_clk = (stat_mem_invert_clk_p ? ~clk_i : clk_i);
  bsg_dff
   #(.width_p(1))
   stat_buf_read_en_reg
    (.clk_i(stat_mem_clk)

     ,.data_i(stat_buf_read)
     ,.data_o(stat_buf_read_en)
     );

  logic stat_buf_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   stat_buf_v_reg
    (.clk_i(stat_mem_clk)
     ,.reset_i(reset_i)

     ,.set_i(stat_buf_read_en)
     ,.clear_i(stat_buf_read)
     ,.data_o(stat_buf_v_r)
     );

  bp_cache_stat_info_s stat_buf_r;
  bsg_dff_en
    #(.width_p($bits(bp_cache_stat_info_s)))
    stat_buf_reg
     (.clk_i(stat_mem_clk)
      ,.en_i(stat_buf_read_en)
      ,.data_i(stat_mem_i)
      ,.data_o(stat_buf_r)
      );

  // common fields from LCE Command used in many states for responses or pkt fields
  logic [lg_sets_lp-1:0] lce_cmd_addr_index;
  logic [ptag_width_p-1:0] lce_cmd_addr_tag;
  logic [lg_assoc_lp-1:0] lce_cmd_way_id;

  assign lce_cmd_addr_index = lce_cmd.header.addr[lg_block_size_in_bytes_lp+:lg_sets_lp];
  assign lce_cmd_addr_tag = lce_cmd.header.addr[(paddr_width_p-1) -: ptag_width_p];
  assign lce_cmd_way_id = lce_cmd_payload.way_id[0+:lg_assoc_lp];

  // LCE Command module is ready after it clears the cache's tag and stat memories
  assign ready_o = (state_r != e_reset) && (state_r != e_clear);

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

    uc_store_req_complete_o = 1'b0;

    cache_req_complete_o = 1'b0;
    //TODO: support partial fill, currently not supported
    cache_req_critical_o = 1'b0;

    // LCE-CCE Interface signals
    lce_cmd_yumi_o = 1'b0;

    lce_resp = '0;
    lce_resp_payload = '0;
    lce_resp_v_o = 1'b0;

    lce_cmd_out = '0;
    lce_cmd_out_payload = '0;
    lce_cmd_v_o = 1'b0;

    // LCE-Cache Interface signals
    data_mem_pkt = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt = '0;
    tag_mem_pkt_v_o = 1'b0;
    stat_mem_pkt = '0;
    stat_mem_pkt_v_o = 1'b0;

    // Counter
    cnt_inc = 1'b0;
    cnt_clear = reset_i;

    // DFF register signals
    sync_done_en = 1'b0;
    sync_done_li = 1'b0;

    unique case (state_r)

      e_reset: begin
        state_n = e_clear;
        // clear registers
        sync_done_en = 1'b1;
      end

      // After reset is complete, the LCE Command module clears the tag and stat memories
      // of the cache it manages, initializing the cache for operation.
      e_clear: begin
        tag_mem_pkt.index = cnt_r[0+:lg_sets_lp];
        tag_mem_pkt.state = e_COH_I;
        tag_mem_pkt.tag = '0;
        tag_mem_pkt.opcode = e_cache_tag_mem_set_clear;
        tag_mem_pkt_v_o = 1'b1;

        stat_mem_pkt.index = cnt_r[0+:lg_sets_lp];
        stat_mem_pkt.opcode = e_cache_stat_mem_set_clear;
        stat_mem_pkt_v_o = 1'b1;

        state_n = ((cnt_r == cnt_width_lp'(lce_sets_p-1)) & tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
          ? e_ready
          : e_clear;
        cnt_clear = (state_n == e_ready);
        cnt_inc = ~cnt_clear & (tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i);

      end

      // Ready for LCE Commands
      // A command is dequeued when the command module finishes processing the command.
      e_ready: begin
        if (lce_cmd_v_i) begin
          unique case (lce_cmd.header.msg_type.cmd)

            // Sync
            e_bedrock_cmd_sync: begin
              lce_resp_payload.dst_id = lce_cmd_payload.src_id;
              lce_resp_payload.src_id = lce_id_i;
              lce_resp.header.payload = lce_resp_payload;
              lce_resp.header.msg_type.resp = e_bedrock_resp_sync_ack;
              lce_resp_v_o = lce_resp_ready_i;
              lce_cmd_yumi_o = lce_resp_v_o;

              // reset the counter when last sync is received and ack is sent
              cnt_clear = ((cnt_r == cnt_width_lp'(num_cce_p-1)) & lce_resp_v_o);
              // increment as long as not resetting counter
              cnt_inc = ~cnt_clear & lce_resp_v_o;
              // sync is done when last sync is received and ack is sent
              sync_done_en = cnt_clear;
              sync_done_li = 1'b1;

            end

            // Set Clear - invalidate entire set specified by command
            e_bedrock_cmd_set_clear: begin
              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_clear;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              stat_mem_pkt.index = lce_cmd_addr_index;
              stat_mem_pkt.opcode = e_cache_stat_mem_set_clear;
              stat_mem_pkt_v_o = lce_cmd_v_i;

              lce_cmd_yumi_o = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;

            end

            // Invalidate Tag - write tag mem and send Invalidate Ack
            e_bedrock_cmd_inv: begin
              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.way_id = lce_cmd_way_id;
              tag_mem_pkt.state = e_COH_I;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_state;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              lce_resp_v_o = tag_mem_pkt_yumi_i & lce_resp_ready_i;
              lce_resp.header.addr = lce_cmd.header.addr;
              lce_resp.header.msg_type.resp = e_bedrock_resp_inv_ack;
              lce_resp_payload.src_id = lce_id_i;
              lce_resp_payload.dst_id = lce_cmd_payload.src_id;
              lce_resp.header.payload = lce_resp_payload;

              lce_cmd_yumi_o = lce_resp_v_o;

            end

            // Set State
            // Write the state as commanded, no response sent
            e_bedrock_cmd_st: begin
              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.way_id = lce_cmd_way_id;
              tag_mem_pkt.state = lce_cmd_payload.state;
              tag_mem_pkt.tag = '0;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_state;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              lce_cmd_yumi_o = tag_mem_pkt_yumi_i;

            end

            // Data and Tag - completes cache miss
            // Set Tag and State, write Data
            e_bedrock_cmd_data: begin
              data_mem_pkt.index = lce_cmd_addr_index;
              data_mem_pkt.way_id = lce_cmd_way_id;
              data_mem_pkt.data = lce_cmd.data;
              data_mem_pkt.fill_index = {block_size_in_fill_lp{1'b1}};
              data_mem_pkt.opcode = e_cache_data_mem_write;
              data_mem_pkt_v_o = lce_cmd_v_i;

              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.way_id = lce_cmd_way_id;
              tag_mem_pkt.state = lce_cmd_payload.state;
              tag_mem_pkt.tag = lce_cmd_addr_tag;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              // TODO: This is sufficient for the critical signal when only
              //   line width fills
              cache_req_critical_o = tag_mem_pkt_yumi_i & data_mem_pkt_yumi_i;

              // send coherence ack after updating tag and data memories
              state_n = (tag_mem_pkt_yumi_i & data_mem_pkt_yumi_i)
                        ? e_coh_ack
                        : e_ready;

            end

            // Set State and Wakeup
            // Write the state as commanded, send coherence ack, and complete request
            e_bedrock_cmd_st_wakeup: begin
              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.way_id = lce_cmd_way_id;
              tag_mem_pkt.state = lce_cmd_payload.state;
              tag_mem_pkt.tag = lce_cmd_addr_tag;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_state;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              state_n = tag_mem_pkt_yumi_i
                        ? e_coh_ack
                        : e_ready;

            end

            // Writeback
            e_bedrock_cmd_wb: begin

              // read stat mem to determine if line is dirty
              stat_mem_pkt.index = lce_cmd_addr_index;
              stat_mem_pkt.way_id = lce_cmd_way_id;
              stat_mem_pkt.opcode = e_cache_stat_mem_read;
              stat_mem_pkt_v_o = lce_cmd_v_i;

              state_n = stat_mem_pkt_yumi_i
                ? e_wb
                : e_ready;

            end

            // Set State and Writeback
            e_bedrock_cmd_st_wb: begin
              // update state
              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.way_id = lce_cmd_way_id;
              tag_mem_pkt.state = lce_cmd_payload.state;
              tag_mem_pkt.tag = lce_cmd_addr_tag;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_state;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              // read stat mem to determine if line is dirty
              stat_mem_pkt.index = lce_cmd_addr_index;
              stat_mem_pkt.way_id = lce_cmd_way_id;
              stat_mem_pkt.opcode = e_cache_stat_mem_read;
              stat_mem_pkt_v_o = lce_cmd_v_i;

              state_n = stat_mem_pkt_yumi_i & tag_mem_pkt_yumi_i
                ? e_wb
                : e_ready;

            end

            // Transfer
            e_bedrock_cmd_tr: begin

              // read block from data mem
              // data will be available in the first cycle of e_tr state
              data_mem_pkt.index = lce_cmd_addr_index;
              data_mem_pkt.way_id = lce_cmd_way_id;
              data_mem_pkt.opcode = e_cache_data_mem_read;
              data_mem_pkt_v_o = lce_cmd_v_i;

              state_n = data_mem_pkt_yumi_i
                ? e_tr
                : e_ready;

            end

            // Set State and Transfer
            // Set State, Transfer, and Writeback
            e_bedrock_cmd_st_tr
            , e_bedrock_cmd_st_tr_wb: begin
              // update state
              tag_mem_pkt.index = lce_cmd_addr_index;
              tag_mem_pkt.way_id = lce_cmd_way_id;
              tag_mem_pkt.state = lce_cmd_payload.state;
              tag_mem_pkt.tag = lce_cmd_addr_tag;
              tag_mem_pkt.opcode = e_cache_tag_mem_set_state;
              tag_mem_pkt_v_o = lce_cmd_v_i;

              // read block from data mem
              // data will be available in the first cycle of e_tr state
              data_mem_pkt.index = lce_cmd_addr_index;
              data_mem_pkt.way_id = lce_cmd_way_id;
              data_mem_pkt.opcode = e_cache_data_mem_read;
              data_mem_pkt_v_o = lce_cmd_v_i;

              // clear dirty bit if command is e_lce_st_tr (not doing writeback) and block
              // is changing to invalid, since transfer target will take ownership of dirty block.
              // Thus, this LCE needs to make block clean (without the writeback).
              stat_mem_pkt.index = lce_cmd_addr_index;
              stat_mem_pkt.way_id = lce_cmd_way_id;
              stat_mem_pkt.opcode = e_cache_stat_mem_clear_dirty;
              stat_mem_pkt_v_o = lce_cmd_v_i & (lce_cmd.header.msg_type.cmd == e_bedrock_cmd_st_tr)
                                & (lce_cmd_payload.state == e_COH_I);

              // for both of these commands, do the transfer next
              state_n = data_mem_pkt_yumi_i & tag_mem_pkt_yumi_i
                ? e_tr
                : e_ready;

            end

            //  Uncached Store Done - store has committed to memory
            e_bedrock_cmd_uc_st_done: begin
              // dequeue message and assert request complete signal for a cycle
              lce_cmd_yumi_o = lce_cmd_v_i;
              uc_store_req_complete_o = lce_cmd_yumi_o;

            end

            // Uncached Data - send data to cache and raise request complete signal for one cycle
            // when data sends and command is dequeued
            e_bedrock_cmd_uc_data: begin
              data_mem_pkt.index = lce_cmd_addr_index;
              data_mem_pkt.data = {(block_width_p/dword_width_gp){lce_cmd.data[0+:dword_width_gp]}};
              data_mem_pkt.fill_index = {block_size_in_fill_lp{1'b1}};
              data_mem_pkt.opcode = e_cache_data_mem_uncached;
              data_mem_pkt_v_o = lce_cmd_v_i;

              lce_cmd_yumi_o = data_mem_pkt_yumi_i;

              cache_req_critical_o = lce_cmd_yumi_o;
              cache_req_complete_o = lce_cmd_yumi_o;
            end

            // for other message types in this state, use default as defined at top.
            default: begin
              state_n = e_ready;
            end

          endcase // cmd.msg_type case
        end // lce_cmd_v
      end // e_ready

      // Send Coherence Ack message and raise request complete for one cycle
      e_coh_ack: begin
        lce_resp.header.addr = lce_cmd.header.addr;
        lce_resp.header.msg_type.resp = e_bedrock_resp_coh_ack;
        lce_resp_payload.src_id = lce_id_i;
        lce_resp_payload.dst_id = lce_cmd_payload.src_id;
        lce_resp.header.payload = lce_resp_payload;
        lce_resp_v_o = lce_cmd_v_i & lce_resp_ready_i;

        lce_cmd_yumi_o = lce_resp_v_o;

        cache_req_complete_o = lce_cmd_yumi_o;

        state_n = lce_cmd_yumi_o
          ? e_ready
          : e_coh_ack;

      end

      // Transfer
      // send e_bedrock_cmd_data message to target LCE
      // data_buf_r holds valid data when data_buf_v_r is high
      e_tr: begin

        lce_cmd_out.header.msg_type = e_bedrock_cmd_data;
        lce_cmd_out.header.addr = lce_cmd.header.addr;
        lce_cmd_out.header.size = cmd_block_size_lp;
        // form the outbound message
        lce_cmd_out_payload.dst_id = lce_cmd_payload.target;
        // set src to be the CCE that sent the transfer command so the destination LCE knows
        // which CCE it must send its coherence ack to when the data command arrives
        lce_cmd_out_payload.src_id = lce_cmd_payload.src_id;
        lce_cmd_out_payload.way_id = lce_cmd_payload.target_way_id;
        lce_cmd_out_payload.state = lce_cmd_payload.target_state;
        lce_cmd_out.header.payload = lce_cmd_out_payload;
        lce_cmd_out.data = data_buf_r;

        // handshakes
        // outbound command is ready->valid
        // inbound is valid->yumi, but only dequeue when outbound sends
        lce_cmd_v_o = lce_cmd_ready_i & lce_cmd_v_i & data_buf_v_r;

        // dequeue the command if transfer is last action
        lce_cmd_yumi_o = lce_cmd_v_o & (lce_cmd.header.msg_type.cmd != e_bedrock_cmd_st_tr_wb);

        // do a writeback if needed, otherwise go to ready after the transfer sends
        // move to next state when LCE command sends
        state_n = lce_cmd_v_o
          ? (lce_cmd.header.msg_type.cmd == e_bedrock_cmd_st_tr_wb)
            ? e_wb_stat_rd
            : e_ready
          : e_tr;

      end

      // Writeback stat mem read, when processing e_bedrock_cmd_st_tr_wb
      // i.e., after the set state and transfer happen
      e_wb_stat_rd: begin
        // read stat mem to determine if line is dirty
        stat_mem_pkt.index = lce_cmd_addr_index;
        stat_mem_pkt.way_id = lce_cmd_way_id;
        stat_mem_pkt.opcode = e_cache_stat_mem_read;
        stat_mem_pkt_v_o = lce_cmd_v_i;

        state_n = stat_mem_pkt_yumi_i
          ? e_wb
          : e_wb_stat_rd;
      end

      // Writeback
      // If block is dirty, read it from data mem and send back to CCE
      // If block is clean, respond with null writeback
      // Determine if the block is dirty or not.
      e_wb: begin

        // Send a null writeback if not dirty, else move to writeback
        lce_resp.data = '0;
        lce_resp.header.addr = lce_cmd.header.addr;
        lce_resp.header.msg_type = e_bedrock_resp_null_wb;
        lce_resp_payload.src_id = lce_id_i;
        lce_resp_payload.dst_id = lce_cmd_payload.src_id;
        lce_resp.header.payload = lce_resp_payload;
        lce_resp_v_o = lce_resp_ready_i & stat_buf_v_r & ~stat_buf_r.dirty[lce_cmd_way_id];
        // dequeue command only if sending null writeback
        lce_cmd_yumi_o = lce_resp_v_o;

        state_n = stat_buf_v_r & stat_buf_r.dirty[lce_cmd_way_id]
                  ? e_wb_dirty_rd
                  : stat_buf_v_r & lce_cmd_yumi_o
                    ? e_ready
                    : e_wb;

      end

      // Writeback dirty block - read from data memory, write to stat memory to clear dirty bit
      e_wb_dirty_rd: begin

        // read from data memory
        data_mem_pkt.index = lce_cmd_addr_index;
        data_mem_pkt.way_id = lce_cmd_way_id;
        data_mem_pkt.opcode = e_cache_data_mem_read;
        data_mem_pkt_v_o = 1'b1;

        // write to stat memory
        stat_mem_pkt.index = lce_cmd_addr_index;
        stat_mem_pkt.way_id = lce_cmd_way_id;
        stat_mem_pkt.opcode = e_cache_stat_mem_clear_dirty;
        stat_mem_pkt_v_o = 1'b1;

        // move to next state once both data and stat mem commands have sent
        state_n = (data_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
          ? e_wb_dirty_send
          : e_wb_dirty_rd;

      end

      // Dirty Writeback Response
      // data_buf_r holds valid data when data_buf_v_r is high
      e_wb_dirty_send: begin

        lce_resp.data = data_buf_r;
        lce_resp.header.addr = lce_cmd.header.addr;
        lce_resp.header.msg_type = e_bedrock_resp_wb;
        lce_resp_payload.src_id = lce_id_i;
        lce_resp_payload.dst_id = lce_cmd_payload.src_id;
        lce_resp.header.payload = lce_resp_payload;
        lce_resp.header.size = cmd_block_size_lp;
        lce_resp_v_o = lce_resp_ready_i & data_buf_v_r;

        lce_cmd_yumi_o = lce_resp_v_o;

        state_n = lce_cmd_yumi_o
          ? e_ready
          : e_wb_dirty_send;

      end

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
