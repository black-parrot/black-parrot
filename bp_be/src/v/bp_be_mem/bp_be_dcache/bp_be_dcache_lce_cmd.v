/**
 *  Name:
 *    bp_be_dcache_lce_cmd.v
 *
 *  Description:
 *    LCE command handler. On reset, LCE is in reset state, waiting to be
 *    initialized. LCE receives set_clear commands to invalidate all the sets
 *    in the cache. Once LCE has received sync command from all the CCEs, and
 *    has responded with ack, it asserts lce_ready_o signal to indicate
 *    that the cache may begin start accepting load/store instructions from
 *    the backend.
 *
 */

module bp_be_dcache_lce_cmd
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

    , localparam block_size_in_words_lp=lce_assoc_p
    , localparam data_mask_width_lp=(dword_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp=(paddr_width_p-index_width_lp-block_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p) 

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_cache_data_mem_pkt_width(lce_sets_p, lce_assoc_p, cce_block_width_p)
    , localparam dcache_lce_tag_mem_pkt_width_lp=
      `bp_cache_tag_mem_pkt_width(lce_sets_p, lce_assoc_p, tag_width_lp)
    , localparam dcache_lce_stat_mem_pkt_width_lp=
      `bp_cache_stat_mem_pkt_width(lce_sets_p, lce_assoc_p)

    // width for counter used during initiliazation and for sync messages
    , localparam cnt_width_lp = `BSG_MAX(cce_id_width_p+1, `BSG_SAFE_CLOG2(lce_sets_p)+1)
    , localparam cnt_max_val_lp = ((2**cnt_width_lp)-1)

  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_p-1:0] lce_id_i

    , input [paddr_width_p-1:0] miss_addr_i

    , output logic lce_ready_o
    , output logic set_tag_received_o
    , output logic set_tag_wakeup_received_o
    , output logic uncached_store_done_received_o
    , output logic cce_data_received_o
    , output logic uncached_data_received_o

    // CCE_LCE_cmd
    , input [lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_yumi_o

    // LCE_CCE_resp
    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_yumi_i

    // LCE_data_cmd_out
    , output logic [lce_cmd_width_lp-1:0] lce_cmd_o
    , output logic lce_cmd_v_o
    , input lce_cmd_ready_i 

    // data_mem
    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input [cce_block_width_p-1:0] data_mem_data_i
    , input data_mem_pkt_yumi_i
  
    // tag_mem
    , output logic tag_mem_pkt_v_o
    , output logic [dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    , input tag_mem_pkt_yumi_i
    
    // stat_mem
    , output logic stat_mem_pkt_v_o
    , output logic [dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input [lce_assoc_p-1:0] dirty_i
    , input stat_mem_pkt_yumi_i
  );

  // casting structs
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bp_cache_data_mem_pkt_s(lce_sets_p, lce_assoc_p, cce_block_width_p);
  `declare_bp_cache_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, tag_width_lp);
  `declare_bp_cache_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);

  bp_lce_cmd_s lce_cmd_li;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd_out;

  assign lce_cmd_li = lce_cmd_i;
  assign lce_resp_o = lce_resp;
  assign lce_cmd_o = lce_cmd_out;

  bp_cache_data_mem_pkt_s data_mem_pkt;
  bp_cache_tag_mem_pkt_s tag_mem_pkt;
  bp_cache_stat_mem_pkt_s stat_mem_pkt;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;

  logic [index_width_lp-1:0] lce_cmd_addr_index;
  logic [tag_width_lp-1:0] lce_cmd_addr_tag;

  assign lce_cmd_addr_index = lce_cmd_li.msg.cmd.addr[block_offset_width_lp+:index_width_lp];
  assign lce_cmd_addr_tag = lce_cmd_li.msg.cmd.addr[block_offset_width_lp+index_width_lp+:tag_width_lp];


  // states
  //
  typedef enum logic [2:0] {
    e_lce_cmd_state_reset
    ,e_lce_cmd_state_uncached_only
    ,e_lce_cmd_state_ready
    ,e_lce_cmd_state_tr
    ,e_lce_cmd_state_wb
    ,e_lce_cmd_state_wb_dirty
    ,e_lce_cmd_state_wb_not_dirty
  } lce_cmd_state_e;

  lce_cmd_state_e state_r, state_n;

  // for invalidate_tag_cmd
  logic invalidated_tag_r, invalidated_tag_n;

  // for transfer_cmd
  logic tr_data_buffered_r, tr_data_buffered_n;

  // for writeback_cmd
  logic wb_data_buffered_r, wb_data_buffered_n;
  logic wb_data_read_r, wb_data_read_n;
  logic wb_dirty_cleared_r, wb_dirty_cleared_n;

  // data buffer
  logic [cce_block_width_p-1:0] data_buf_r, data_buf_n;

  // transaction signals
  //
  logic lce_resp_done;
  logic lce_tr_done;
  
  assign lce_tr_done = lce_cmd_v_o & lce_cmd_ready_i;
  assign lce_resp_done = lce_resp_yumi_i;

  // this gets asserted when LCE finishes resetting its state
  assign lce_ready_o = (state_r != e_lce_cmd_state_reset);

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

  // next state logic
  //
  always_comb begin

    cnt_inc = 1'b0;
    cnt_clear = reset_i;

    state_n = state_r;
    tr_data_buffered_n = tr_data_buffered_r;

    wb_data_buffered_n = wb_data_buffered_r;
    wb_data_read_n = wb_data_read_r;
    wb_dirty_cleared_n = wb_dirty_cleared_r;

    invalidated_tag_n = invalidated_tag_r;

    data_buf_n = data_buf_r;

    set_tag_received_o = 1'b0;
    set_tag_wakeup_received_o = 1'b0;
    uncached_store_done_received_o = 1'b0;
    uncached_data_received_o = 1'b0;
    cce_data_received_o = 1'b0;

    lce_cmd_yumi_o = 1'b0;

    lce_resp = '0;
    lce_resp_v_o = 1'b0;

    lce_cmd_out = '0;
    lce_cmd_v_o = 1'b0;

    data_mem_pkt = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt = '0;
    tag_mem_pkt_v_o = 1'b0;
    stat_mem_pkt = '0;
    stat_mem_pkt_v_o = 1'b0;
    
    unique case (state_r)

      // < RESET >
      // After reset_i goes low, this module clears all stat and tag mem entries,
      // resetting the state of the cache and LCE
      e_lce_cmd_state_reset: begin
        tag_mem_pkt.index = cnt_r[0+:index_width_lp];
        tag_mem_pkt.state = e_COH_I;
        tag_mem_pkt.tag = '0;
        tag_mem_pkt.opcode = e_cache_tag_mem_set_clear;
        tag_mem_pkt_v_o = 1'b1;

        stat_mem_pkt.index = cnt_r[0+:index_width_lp];
        stat_mem_pkt.opcode = e_cache_stat_mem_set_clear;
        stat_mem_pkt_v_o = 1'b1;

        state_n = ((cnt_r == cnt_width_lp'(lce_sets_p-1)) & tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i)
          ? e_lce_cmd_state_uncached_only
          : e_lce_cmd_state_reset;
        cnt_clear = (state_n == e_lce_cmd_state_uncached_only);
        cnt_inc = ~cnt_clear & (tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i);

      end

      // < UNCACHED ONLY >
      // LCE starts in a mode that can process uncached accesses.

      // LCE may receive SET-CLEAR messages from CCE to invalidate cache lines.
      // set-clear messages clears the valid bits in tag_mem and the dirty bits in stat_mem.
      // When LCE receives SYNC message, it responds with SYNC-ACK. When LCE received SYNC messages from
      // every CCE in the system, it moves onto READY state.

      e_lce_cmd_state_uncached_only: begin

        unique case (lce_cmd_li.msg_type)

          e_lce_cmd_sync: begin
            lce_resp.dst_id = lce_cmd_li.msg.cmd.src_id;
            lce_resp.src_id = lce_id_i;
            lce_resp.msg_type = e_lce_cce_sync_ack;
            lce_resp_v_o = lce_cmd_v_i;
            lce_cmd_yumi_o = lce_resp_yumi_i;
            state_n = ((cnt_r == cnt_width_lp'(num_cce_p-1)) & lce_resp_yumi_i)
              ? e_lce_cmd_state_ready
              : e_lce_cmd_state_uncached_only;
            // clear counter when moving to ready state
            cnt_clear = (state_n == e_lce_cmd_state_ready);
            // only increment counter when staying in uncached_only state and waiting for more
            // sync messages, and when the lce_resp is sent
            cnt_inc = ~cnt_clear & lce_resp_yumi_i;

          end

          e_lce_cmd_set_clear: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            stat_mem_pkt.index = lce_cmd_addr_index;
            stat_mem_pkt.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;
          end

          e_lce_cmd_uc_st_done: begin
            lce_cmd_yumi_o = lce_cmd_v_i;
            uncached_store_done_received_o = lce_cmd_v_i;
          end

          e_lce_cmd_uc_data: begin
            data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.data = lce_cmd_li.msg.dt_cmd.data;
            data_mem_pkt.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_v_o = lce_cmd_v_i;
            lce_cmd_yumi_o = data_mem_pkt_yumi_i;

            uncached_data_received_o = data_mem_pkt_yumi_i;

          end

          // for other message types in this state, use default as defined at top.
          default: begin
	     
          end
        endcase 

      end

      // < READY >
      // LCE is ready to process cce_lce_cmd packets. In general, the packets are dequeued, when LCE
      // has finished with the job related to the packet.
      e_lce_cmd_state_ready: begin
        unique case (lce_cmd_li.msg_type)
          // <transfer packet>
          // LCE first reads the data mem, and moves onto TRANSFER state.
          e_lce_cmd_transfer: begin
            data_mem_pkt.index = lce_cmd_addr_index;
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.opcode = e_cache_data_mem_read;
            data_mem_pkt_v_o = lce_cmd_v_i;

            state_n = data_mem_pkt_yumi_i
              ? e_lce_cmd_state_tr
              : e_lce_cmd_state_ready;
          end

          //  <writeback packet>
          //  LCE is asked to writeback a cache line.
          //  It first reads stat_mem to check if the line is dirty.
          e_lce_cmd_writeback: begin
            stat_mem_pkt.index = lce_cmd_addr_index;
            stat_mem_pkt.way_id = lce_cmd_li.way_id;
            stat_mem_pkt.opcode = e_cache_stat_mem_read;
            stat_mem_pkt_v_o = lce_cmd_v_i;

            state_n = stat_mem_pkt_yumi_i
              ? e_lce_cmd_state_wb
              : e_lce_cmd_state_ready;
          end

          //  <set tag>
          //  set the tag and coherency state of given index/way.
          e_lce_cmd_set_tag: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state = lce_cmd_li.msg.cmd.state;
            tag_mem_pkt.tag = lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i;

            set_tag_received_o = tag_mem_pkt_yumi_i;
          end

          //  <set tag wakeup>
          //  set the tag and send wake-up signal to lce_cce_req module.
          e_lce_cmd_set_tag_wakeup: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state = lce_cmd_li.msg.cmd.state;
            tag_mem_pkt.tag = lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i;

            set_tag_wakeup_received_o = tag_mem_pkt_yumi_i;
          end

          //  <invalidate tag>
          //  invalidate tag. It does not update the LRU. It sends out
          //  invalidate_ack response.
          e_lce_cmd_invalidate_tag: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.opcode = e_cache_tag_mem_invalidate;
            tag_mem_pkt_v_o = invalidated_tag_r
              ? 1'b0
              : lce_cmd_v_i;
            invalidated_tag_n = lce_resp_yumi_i
              ? 1'b0
              : (invalidated_tag_r
                ? 1'b1
                : tag_mem_pkt_yumi_i);

            lce_resp.dst_id = lce_cmd_li.msg.cmd.src_id;
            lce_resp.msg_type = e_lce_cce_inv_ack;
            lce_resp.src_id = lce_id_i;
            lce_resp.addr = lce_cmd_li.msg.cmd.addr;
            lce_resp_v_o = invalidated_tag_r | tag_mem_pkt_yumi_i;
            lce_cmd_yumi_o = lce_resp_yumi_i;
          end

          //  <uncached store done>
          //  Uncached store done from CCE - decrement flow counter
          e_lce_cmd_uc_st_done: begin
            lce_cmd_yumi_o = lce_cmd_v_i;
            uncached_store_done_received_o = lce_cmd_v_i;
          end

          e_lce_cmd_data: begin
            data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.data = lce_cmd_li.msg.dt_cmd.data;
            data_mem_pkt.opcode = e_cache_data_mem_write;
            data_mem_pkt_v_o = lce_cmd_v_i;

            tag_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state = lce_cmd_li.msg.dt_cmd.state;
            tag_mem_pkt.tag = lce_cmd_li.msg.dt_cmd.addr[block_offset_width_lp+index_width_lp+:tag_width_lp];
            tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o      = tag_mem_pkt_yumi_i & data_mem_pkt_yumi_i;

            cce_data_received_o = tag_mem_pkt_yumi_i & data_mem_pkt_yumi_i;
            set_tag_received_o  = tag_mem_pkt_yumi_i & data_mem_pkt_yumi_i;

          end

          e_lce_cmd_uc_data: begin
            data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.data = lce_cmd_li.msg.dt_cmd.data;
            data_mem_pkt.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_v_o = lce_cmd_v_i;
            lce_cmd_yumi_o = data_mem_pkt_yumi_i;

            uncached_data_received_o = data_mem_pkt_yumi_i;
          end

          e_lce_cmd_set_clear: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.opcode = e_cache_tag_mem_set_clear;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            stat_mem_pkt.index = lce_cmd_addr_index;
            stat_mem_pkt.opcode = e_cache_stat_mem_set_clear;
            stat_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;
          end

          // for other message types in this state, use default as defined at top.
          default: begin

          end
        endcase
      end

      // <TRANSFER state>    
      // First, buffer the data read from data_mem, and try to send transfer to another LCE.
      e_lce_cmd_state_tr: begin
        data_buf_n = tr_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        tr_data_buffered_n = ~lce_tr_done;

        lce_cmd_out.dst_id = lce_cmd_li.msg.cmd.target;
        lce_cmd_out.msg_type = e_lce_cmd_data;
        lce_cmd_out.way_id = lce_cmd_li.msg.cmd.target_way_id;
        lce_cmd_out.msg.dt_cmd.addr = lce_cmd_li.msg.cmd.addr;
        lce_cmd_out.msg.dt_cmd.state = lce_cmd_li.msg.cmd.state;
        lce_cmd_out.msg.dt_cmd.data = tr_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        lce_cmd_v_o = lce_cmd_ready_i;

        lce_cmd_yumi_o = lce_tr_done;
        state_n = lce_tr_done
          ? e_lce_cmd_state_ready
          : e_lce_cmd_state_tr;
      end

      // <WRITEBACK state>
      // Determine if the block is dirty or not.
      e_lce_cmd_state_wb: begin
        state_n = dirty_i[lce_cmd_li.way_id] 
          ? e_lce_cmd_state_wb_dirty
          : e_lce_cmd_state_wb_not_dirty;
      end

      // <WRITEBACK dirty state>
      // If the block is dirty, read the block, buffers the data, clear the dirty bit on the block.
      // At last, send out the block data to CCE.
      e_lce_cmd_state_wb_dirty: begin
        data_mem_pkt.index = lce_cmd_addr_index;
        data_mem_pkt.way_id = lce_cmd_li.way_id;
        data_mem_pkt.opcode = e_cache_data_mem_read;
        data_mem_pkt_v_o = ~wb_data_read_r;
        data_buf_n = wb_data_buffered_r
          ? data_buf_r
          : (wb_data_read_r
            ? data_mem_data_i
            : data_buf_r);
        wb_data_buffered_n = lce_resp_done
          ? 1'b0
          : (wb_data_buffered_r
            ? 1'b1
            : wb_data_read_r);
        wb_data_read_n = lce_resp_done
          ? 1'b0
          : (wb_data_read_r
            ? 1'b1
            : data_mem_pkt_yumi_i);

        stat_mem_pkt.index = lce_cmd_addr_index;
        stat_mem_pkt.way_id = lce_cmd_li.way_id;
        stat_mem_pkt.opcode = e_cache_stat_mem_clear_dirty;
        stat_mem_pkt_v_o = wb_dirty_cleared_r
          ? 1'b0
          : (wb_data_read_r | data_mem_pkt_yumi_i);
        wb_dirty_cleared_n = lce_resp_done
          ? 1'b0
          : (wb_dirty_cleared_r
            ? 1'b1
            : stat_mem_pkt_yumi_i);
        
        lce_resp.data = wb_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        lce_resp.addr = lce_cmd_li.msg.cmd.addr;
        lce_resp.msg_type = e_lce_cce_resp_wb;
        lce_resp.src_id = lce_id_i;
        lce_resp.dst_id = lce_cmd_li.msg.cmd.src_id;
        lce_resp_v_o = wb_data_read_r & (wb_dirty_cleared_r | stat_mem_pkt_yumi_i);

        lce_cmd_yumi_o = lce_resp_done;

        state_n = lce_resp_done
          ? e_lce_cmd_state_ready
          : e_lce_cmd_state_wb_dirty;
      end

      //  <WRITEBACK not-dirty state>
      //  If not dirty, just respond with null writeback data.
      e_lce_cmd_state_wb_not_dirty: begin
        lce_resp.data = '0;
        lce_resp.addr = lce_cmd_li.msg.cmd.addr;
        lce_resp.msg_type = e_lce_cce_resp_null_wb;
        lce_resp.src_id = lce_id_i;
        lce_resp.dst_id = lce_cmd_li.msg.cmd.src_id;
        lce_resp_v_o = 1'b1;

        lce_cmd_yumi_o = lce_resp_done;

        state_n = lce_resp_done
          ? e_lce_cmd_state_ready
          : e_lce_cmd_state_wb_not_dirty;
      end      

      // we should never get in this state, but if we do, return to the sync state.
      default: begin 
        state_n = e_lce_cmd_state_reset;
      end
    endcase
  end


  // sequential logic
  //
  //synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_lce_cmd_state_reset;
      tr_data_buffered_r <= 1'b0;
      wb_data_buffered_r <= 1'b0;
      wb_data_read_r <= 1'b0;
      wb_dirty_cleared_r <= 1'b0;
      invalidated_tag_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      tr_data_buffered_r <= tr_data_buffered_n;
      wb_data_buffered_r <= wb_data_buffered_n;
      wb_data_read_r <= wb_data_read_n;
      wb_dirty_cleared_r <= wb_dirty_cleared_n;
      data_buf_r <= data_buf_n;
      invalidated_tag_r <= invalidated_tag_n;
    end
  end

endmodule
