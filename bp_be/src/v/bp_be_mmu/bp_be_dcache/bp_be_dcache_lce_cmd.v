/**
 *  Name:
 *    bp_be_dcache_lce_cmd.v
 *
 *  Description:
 *    LCE command handler. On reset, LCE is in reset state, waiting to be
 *    initialized. LCE receives set_clear commands to invalidate all the sets
 *    in the cache. Once LCE has received sync command from all the CCEs, and
 *    has responded with ack, it asserts lce_sync_done_o signal to indicate
 *    that the cache may begin start accepting load/store instructions from
 *    the backend.
 *
 */

module bp_be_dcache_lce_cmd
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter paddr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter data_width_p="inv"

    , localparam block_size_in_words_lp=ways_p
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam tag_width_lp=(paddr_width_p-index_width_lp-block_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam cce_id_width_lp=`BSG_SAFE_CLOG2(num_cce_p)
    
    , localparam cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p)
    , localparam lce_lce_tr_resp_width_lp=
      `bp_lce_lce_tr_resp_width(num_lce_p, paddr_width_p, lce_data_width_p, ways_p)

    , localparam dcache_lce_data_mem_pkt_width_lp=
      `bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
    , localparam dcache_lce_tag_mem_pkt_width_lp=
      `bp_be_dcache_lce_tag_mem_pkt_width(sets_p, ways_p, tag_width_lp)
    , localparam dcache_lce_stat_mem_pkt_width_lp=
      `bp_be_dcache_lce_stat_mem_pkt_width(sets_p, ways_p)
  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_lp-1:0] lce_id_i

    , output logic lce_sync_done_o
    , output logic tag_set_o
    , output logic tag_set_wakeup_o

    // CCE_LCE_cmd
    , input [cce_lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_yumi_o

    // LCE_CCE_resp
    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_yumi_i

    // LCE_CCE_data_resp
    ,output logic [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
    ,output logic lce_data_resp_v_o
    ,input lce_data_resp_ready_i

    // LCE_LCE_tr_out
    , output logic [lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_o
    , output logic lce_tr_resp_v_o
    , input lce_tr_resp_ready_i 

    // data_mem
    , output logic data_mem_pkt_v_o
    , output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input [lce_data_width_p-1:0] data_mem_data_i
    , input data_mem_pkt_yumi_i
  
    // tag_mem
    , output logic tag_mem_pkt_v_o
    , output logic [dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    , input tag_mem_pkt_yumi_i
    
    // stat_mem
    , output logic stat_mem_pkt_v_o
    , output logic [dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input [ways_p-1:0] dirty_i
    , input stat_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, lce_data_width_p, ways_p);
  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_lp);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(sets_p, ways_p);

  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_data_resp_s lce_data_resp;
  bp_lce_lce_tr_resp_s lce_tr_resp_out;

  assign lce_cmd = lce_cmd_i;
  assign lce_resp_o = lce_resp;
  assign lce_data_resp_o = lce_data_resp;
  assign lce_tr_resp_o = lce_tr_resp_out;

  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;

  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;

  logic [index_width_lp-1:0] lce_cmd_addr_index;
  logic [tag_width_lp-1:0] lce_cmd_addr_tag;

  assign lce_cmd_addr_index = lce_cmd.addr[block_offset_width_lp+:index_width_lp];
  assign lce_cmd_addr_tag = lce_cmd.addr[block_offset_width_lp+index_width_lp+:tag_width_lp];


  // states
  //
  typedef enum logic [2:0] {
    e_lce_cmd_state_sync
    ,e_lce_cmd_state_ready
    ,e_lce_cmd_state_tr
    ,e_lce_cmd_state_wb
    ,e_lce_cmd_state_wb_dirty
    ,e_lce_cmd_state_wb_not_dirty
  } lce_cmd_state_e;

  lce_cmd_state_e state_r, state_n;
  logic [cce_id_width_lp-1:0] sync_ack_count_r, sync_ack_count_n;

  // for invalidate_tag_cmd
  logic invalidated_tag_r, invalidated_tag_n;

  // for transfer_cmd
  logic tr_data_buffered_r, tr_data_buffered_n;
  logic tr_dirty_cleared_r, tr_dirty_cleared_n;

  // for writeback_cmd
  logic wb_data_buffered_r, wb_data_buffered_n;
  logic wb_data_read_r, wb_data_read_n;
  logic wb_dirty_cleared_r, wb_dirty_cleared_n;

  // data buffer
  logic [lce_data_width_p-1:0] data_buf_r, data_buf_n;

  // transaction signals
  //
  logic lce_data_resp_done;
  logic lce_tr_resp_done;
  
  assign lce_tr_resp_done = lce_tr_resp_v_o & lce_tr_resp_ready_i;
  assign lce_data_resp_done = lce_data_resp_ready_i & lce_data_resp_v_o;

  // next state logic
  //
  always_comb begin
    
    lce_sync_done_o = (state_r != e_lce_cmd_state_sync);
    tag_set_o = 1'b0;
    tag_set_wakeup_o = 1'b0;

    state_n = state_r;
    sync_ack_count_n = sync_ack_count_r;
    tr_data_buffered_n = tr_data_buffered_r;
    tr_dirty_cleared_n = tr_dirty_cleared_r;

    wb_data_buffered_n = wb_data_buffered_r;
    wb_data_read_n = wb_data_read_r;
    wb_dirty_cleared_n = wb_dirty_cleared_r;

    invalidated_tag_n = invalidated_tag_r;

    data_buf_n = data_buf_r;

    lce_cmd_yumi_o = 1'b0;

    lce_resp ='0;
    lce_resp.src_id = (lce_id_width_lp)'(lce_id_i);
    lce_resp_v_o = 1'b0;

    lce_data_resp = '0;
    lce_data_resp.src_id = (lce_id_width_lp)'(lce_id_i);
    lce_data_resp_v_o = 1'b0;

    lce_tr_resp_out = '0;
    lce_tr_resp_out.src_id = (lce_id_width_lp)'(lce_id_i);
    lce_tr_resp_v_o = 1'b0;

    data_mem_pkt = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt = '0;
    tag_mem_pkt_v_o = 1'b0;
    stat_mem_pkt = '0;
    stat_mem_pkt_v_o = 1'b0;
    
    case (state_r)

      // < RESET >
      // LCE is expected to receive SET-CLEAR messages from CCE to invalidate every cache lines.
      // set-clear messages clears the valid bits in tag_mem and the dirty bits in stat_mem.
      // When LCE receives SYNC message, it responds with SYNC-ACK. When LCE received SYNC messages from
      // every CCE in the system, it moves onto READY state.
      e_lce_cmd_state_sync: begin

        case (lce_cmd.msg_type)

          e_lce_cmd_sync: begin
            lce_resp.dst_id = lce_cmd.src_id;
            lce_resp.msg_type = e_lce_cce_sync_ack;
            lce_resp_v_o = lce_cmd_v_i;
            lce_cmd_yumi_o = lce_resp_yumi_i;
            sync_ack_count_n = lce_resp_yumi_i
              ? sync_ack_count_r + 1
              : sync_ack_count_r;
            state_n = ((sync_ack_count_r == cce_id_width_lp'(num_cce_p-1)) & lce_resp_yumi_i)
              ? e_lce_cmd_state_ready
              : e_lce_cmd_state_sync;
          end

          e_lce_cmd_set_clear: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_set_clear;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            stat_mem_pkt.index = lce_cmd_addr_index;
            stat_mem_pkt.opcode = e_dcache_lce_stat_mem_set_clear;
            stat_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;
          end

          default: begin

          end
        endcase 
      end

      // < READY >
      // LCE is ready to process cce_lce_cmd packets. In general, the packets are dequeued, when LCE
      // has finished with the job related to the packet.
      e_lce_cmd_state_ready: begin

        case (lce_cmd.msg_type)

          // <transfer packet>
          // LCE first reads the data mem, and moves onto TRANSFER state.
          e_lce_cmd_transfer: begin
            data_mem_pkt.index = lce_cmd_addr_index;
            data_mem_pkt.way_id = lce_cmd.way_id;
            data_mem_pkt.write_not_read = 1'b0;
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
            stat_mem_pkt.way_id = lce_cmd.way_id;
            stat_mem_pkt.opcode = e_dcache_lce_stat_mem_read;
            stat_mem_pkt_v_o = lce_cmd_v_i;

            state_n = stat_mem_pkt_yumi_i
              ? e_lce_cmd_state_wb
              : e_lce_cmd_state_ready;
          end

          //  <set tag>
          //  set the tag and coherency state of given index/way.
          e_lce_cmd_set_tag: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd.way_id;
            tag_mem_pkt.state = lce_cmd.state;
            tag_mem_pkt.tag = lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_set_tag;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i;

            tag_set_o = tag_mem_pkt_yumi_i;
          end

          //  <set tag wakeup>
          //  set the tag and send wake-up signal to lce_cce_req module.
          e_lce_cmd_set_tag_wakeup: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd.way_id;
            tag_mem_pkt.state = lce_cmd.state;
            tag_mem_pkt.tag = lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_set_tag;
            tag_mem_pkt_v_o = lce_cmd_v_i;

            lce_cmd_yumi_o = tag_mem_pkt_yumi_i;

            tag_set_wakeup_o = tag_mem_pkt_yumi_i;
          end

          //  <invalidate tag>
          //  invalidate tag. It does not update the LRU. It sends out
          //  invalidate_ack response.
          e_lce_cmd_invalidate_tag: begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd.way_id;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_invalidate;
            tag_mem_pkt_v_o = invalidated_tag_r
              ? 1'b0
              : lce_cmd_v_i;
            invalidated_tag_n = lce_resp_yumi_i
              ? 1'b0
              : (invalidated_tag_r
                ? 1'b1
                : tag_mem_pkt_yumi_i);

            lce_resp.dst_id = lce_cmd.src_id;
            lce_resp.msg_type = e_lce_cce_inv_ack;
            lce_resp.addr = lce_cmd.addr;
            lce_resp_v_o = invalidated_tag_r | tag_mem_pkt_yumi_i;
            lce_cmd_yumi_o = lce_resp_yumi_i;
          end

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
        tr_data_buffered_n = ~lce_tr_resp_done;

        lce_tr_resp_out.dst_id = lce_cmd.target;
        lce_tr_resp_out.way_id = lce_cmd.target_way_id;
        lce_tr_resp_out.addr = lce_cmd.addr;
        lce_tr_resp_out.data = tr_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        lce_tr_resp_v_o = 1'b1;

        lce_cmd_yumi_o = lce_tr_resp_done;
        state_n = lce_tr_resp_done
          ? e_lce_cmd_state_ready
          : e_lce_cmd_state_tr;
      end

      // <WRITEBACK state>
      // Determine if the block is dirty or not.
      e_lce_cmd_state_wb: begin
        state_n = dirty_i[lce_cmd.way_id] 
          ? e_lce_cmd_state_wb_dirty
          : e_lce_cmd_state_wb_not_dirty;
      end

      // <WRITEBACK dirty state>
      // If the block is dirty, read the block, buffers the data, clear the dirty bit on the block.
      // At last, send out the block data to CCE.
      e_lce_cmd_state_wb_dirty: begin
        data_mem_pkt.index = lce_cmd_addr_index;
        data_mem_pkt.way_id = lce_cmd.way_id;
        data_mem_pkt.write_not_read = 1'b0;
        data_mem_pkt_v_o = ~wb_data_read_r;
        data_buf_n = wb_data_buffered_r
          ? data_buf_r
          : (wb_data_read_r
            ? data_mem_data_i
            : data_buf_r);
        wb_data_buffered_n = lce_data_resp_done
          ? 1'b0
          : (wb_data_buffered_r
            ? 1'b1
            : wb_data_read_r);
        wb_data_read_n = lce_data_resp_done
          ? 1'b0
          : (wb_data_read_r
            ? 1'b1
            : data_mem_pkt_yumi_i);

        stat_mem_pkt.index = lce_cmd_addr_index;
        stat_mem_pkt.way_id = lce_cmd.way_id;
        stat_mem_pkt.opcode = e_dcache_lce_stat_mem_clear_dirty;
        stat_mem_pkt_v_o = wb_dirty_cleared_r
          ? 1'b0
          : (wb_data_read_r | data_mem_pkt_yumi_i);
        wb_dirty_cleared_n = lce_data_resp_done
          ? 1'b0
          : (wb_dirty_cleared_r
            ? 1'b1
            : stat_mem_pkt_yumi_i);
        
        lce_data_resp.dst_id = lce_cmd.src_id;
        lce_data_resp.msg_type = e_lce_resp_wb;
        lce_data_resp.addr = lce_cmd.addr;
        lce_data_resp.data = wb_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        lce_data_resp_v_o = wb_data_read_r & (wb_dirty_cleared_r | stat_mem_pkt_yumi_i);

        lce_cmd_yumi_o = lce_data_resp_done;

        state_n = lce_data_resp_done
          ? e_lce_cmd_state_ready
          : e_lce_cmd_state_wb_dirty;
      end

      //  <WRITEBACK not-dirty state>
      //  If not dirty, just respond with null writeback data.
      e_lce_cmd_state_wb_not_dirty: begin
        lce_data_resp.dst_id = lce_cmd.src_id;
        lce_data_resp.msg_type = e_lce_resp_null_wb;
        lce_data_resp.addr = lce_cmd.addr;
        lce_data_resp_v_o = 1'b1;

        lce_cmd_yumi_o = lce_data_resp_done;

        state_n = lce_data_resp_done
          ? e_lce_cmd_state_ready
          : e_lce_cmd_state_wb_not_dirty;
      end

      default: begin

      end
    endcase
  end


  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_lce_cmd_state_sync;
      sync_ack_count_r <= '0;
      tr_data_buffered_r <= 1'b0;
      tr_dirty_cleared_r <= 1'b0;
      wb_data_buffered_r <= 1'b0;
      wb_data_read_r <= 1'b0;
      wb_dirty_cleared_r <= 1'b0;
      invalidated_tag_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      sync_ack_count_r <= sync_ack_count_n;
      tr_data_buffered_r <= tr_data_buffered_n;
      tr_dirty_cleared_r <= tr_dirty_cleared_n;
      wb_data_buffered_r <= wb_data_buffered_n;
      wb_data_read_r <= wb_data_read_n;
      wb_dirty_cleared_r <= wb_dirty_cleared_n;
      data_buf_r <= data_buf_n;
      invalidated_tag_r <= invalidated_tag_n;
    end
  end

endmodule
