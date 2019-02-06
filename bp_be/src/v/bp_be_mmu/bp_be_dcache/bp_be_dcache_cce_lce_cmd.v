/**
 *  bp_be_dcache_cce_lce_cmd.v
 *
 *  @author tommy
 */

module bp_be_dcache_cce_lce_cmd
  import bp_be_pkg::*;
  import bp_be_dcache_lce_pkg::*;
  #(parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter lce_data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter data_width_p="inv"
    ,parameter tag_width_p="inv"

    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,parameter lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    ,parameter lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, ways_p, 4)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)
    ,parameter lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p)
    ,parameter lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p)

    ,parameter dcache_lce_data_mem_pkt_width_lp=`bp_be_dcache_lce_data_mem_pkt_width(sets_p, ways_p, lce_data_width_p)
    ,parameter dcache_lce_tag_mem_pkt_width_lp=`bp_be_dcache_lce_tag_mem_pkt_width(sets_p, ways_p, tag_width_p)
    ,parameter dcache_lce_stat_mem_pkt_width_lp=`bp_be_dcache_lce_stat_mem_pkt_width(sets_p, ways_p)

    ,localparam lce_id_width_lp=`bp_lce_id_width
  )
  (
    input clk_i
    ,input reset_i

    ,input logic [lce_id_width_lp-1:0] id_i

    ,output logic lce_sync_done_o
    ,output logic tag_set_o
    ,output logic tag_set_wakeup_o

    // CCE_LCE_cmd
    ,input [cce_lce_cmd_width_lp-1:0] cce_lce_cmd_i
    ,input cce_lce_cmd_v_i
    ,output logic cce_lce_cmd_yumi_o

    // LCE_CCE_resp
    ,output logic [lce_cce_resp_width_lp-1:0] lce_cce_resp_o
    ,output logic lce_cce_resp_v_o
    ,input lce_cce_resp_yumi_i

    // LCE_CCE_data_resp
    ,output logic [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o
    ,output logic lce_cce_data_resp_v_o
    ,input lce_cce_data_resp_ready_i

    // LCE_LCE_tr_out
    ,output logic [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_o
    ,output logic lce_lce_tr_resp_v_o
    ,input lce_lce_tr_resp_ready_i 

    // data_mem
    ,output logic data_mem_pkt_v_o
    ,output logic [dcache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    ,input [lce_data_width_p-1:0] data_mem_data_i
    ,input data_mem_pkt_yumi_i
  
    // tag_mem
    ,output logic tag_mem_pkt_v_o
    ,output logic [dcache_lce_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_o
    ,input tag_mem_pkt_yumi_i
    
    // stat_mem
    ,output logic stat_mem_pkt_v_o
    ,output logic [dcache_lce_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    ,input [ways_p-1:0] dirty_i
    ,input stat_mem_pkt_yumi_i
  );

  // casting structs
  //
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p, 4);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_p);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(sets_p, ways_p);

  bp_cce_lce_cmd_s cce_lce_cmd;
  bp_lce_cce_resp_s lce_cce_resp;
  bp_lce_cce_data_resp_s lce_cce_data_resp;
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_out;
  bp_be_dcache_lce_data_mem_pkt_s data_mem_pkt;
  bp_be_dcache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_be_dcache_lce_stat_mem_pkt_s stat_mem_pkt;

  assign cce_lce_cmd = cce_lce_cmd_i;
  assign lce_cce_resp_o = lce_cce_resp;
  assign lce_cce_data_resp_o = lce_cce_data_resp;
  assign lce_lce_tr_resp_o = lce_lce_tr_resp_out;
  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;

  logic [lg_sets_lp-1:0] cce_lce_cmd_addr_index;
  logic [tag_width_p-1:0] cce_lce_cmd_addr_tag;
  assign cce_lce_cmd_addr_index = cce_lce_cmd.addr[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp];
  assign cce_lce_cmd_addr_tag = cce_lce_cmd.addr[lg_data_mask_width_lp+lg_ways_lp+lg_sets_lp+:tag_width_p];


  // states
  //
  typedef enum logic [3:0] {
    e_cce_lce_cmd_reset
    ,e_cce_lce_cmd_ready
    ,e_cce_lce_cmd_tr
    ,e_cce_lce_cmd_wb
    ,e_cce_lce_cmd_wb_dirty
    ,e_cce_lce_cmd_wb_not_dirty
  } cce_lce_cmd_state_e;

  cce_lce_cmd_state_e state_r, state_n;
  logic [lg_num_cce_lp-1:0] sync_ack_count_r, sync_ack_count_n;

  // for invalidate_tag_cmd
  logic invalidated_tag_r, invalidated_tag_n;
  logic updated_lru_r, updated_lru_n;

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
  logic lce_cce_data_resp_done;
  logic lce_lce_tr_resp_done;
  
  assign lce_lce_tr_resp_done = lce_lce_tr_resp_v_o & lce_lce_tr_resp_ready_i;
  assign lce_cce_data_resp_done = lce_cce_data_resp_ready_i & lce_cce_data_resp_v_o;

  // next state logic
  //
  always_comb begin
    
    lce_sync_done_o = (state_r != e_cce_lce_cmd_reset);
    tag_set_o = 1'b0;
    tag_set_wakeup_o = 1'b0;

    state_n = state_r;
    sync_ack_count_n = sync_ack_count_r;
    invalidated_tag_n = invalidated_tag_r;
    updated_lru_n = updated_lru_r;
    tr_data_buffered_n = tr_data_buffered_r;
    tr_dirty_cleared_n = tr_dirty_cleared_r;

    wb_data_buffered_n = wb_data_buffered_r;
    wb_data_read_n = wb_data_read_r;
    wb_dirty_cleared_n = wb_dirty_cleared_r;

    data_buf_n = data_buf_r;

    cce_lce_cmd_yumi_o = 1'b0;

    lce_cce_resp ='0;
    lce_cce_resp.src_id = (lg_num_lce_lp)'(id_i);
    lce_cce_resp_v_o = 1'b0;

    lce_cce_data_resp = '0;
    lce_cce_data_resp.src_id = (lg_num_lce_lp)'(id_i);
    lce_cce_data_resp_v_o = 1'b0;

    lce_lce_tr_resp_out = '0;
    lce_lce_tr_resp_out.src_id = (lg_num_lce_lp)'(id_i);
    lce_lce_tr_resp_v_o = 1'b0;

    data_mem_pkt = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt = '0;
    tag_mem_pkt_v_o = 1'b0;
    stat_mem_pkt = '0;
    stat_mem_pkt_v_o = 1'b0;
    
    case (state_r)

      // RESET
      e_cce_lce_cmd_reset: begin
        case (cce_lce_cmd.msg_type)
          e_lce_cmd_sync: begin
            lce_cce_resp.dst_id = cce_lce_cmd.src_id;
            lce_cce_resp.msg_type = e_lce_cce_sync_ack;
            lce_cce_resp_v_o = cce_lce_cmd_v_i;
            cce_lce_cmd_yumi_o = lce_cce_resp_yumi_i;
            sync_ack_count_n = lce_cce_resp_yumi_i
              ? sync_ack_count_r + 1
              : sync_ack_count_r;
            state_n = ((sync_ack_count_r == num_cce_p-1) & lce_cce_resp_yumi_i)
              ? e_cce_lce_cmd_ready
              : e_cce_lce_cmd_reset;
          end
          e_lce_cmd_set_clear: begin
            tag_mem_pkt.index = cce_lce_cmd_addr_index;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_set_clear;
            tag_mem_pkt_v_o = cce_lce_cmd_v_i;
            stat_mem_pkt.index = cce_lce_cmd_addr_index;
            stat_mem_pkt.opcode = e_dcache_lce_stat_mem_set_clear;
            stat_mem_pkt_v_o = cce_lce_cmd_v_i;
            cce_lce_cmd_yumi_o = tag_mem_pkt_yumi_i & stat_mem_pkt_yumi_i;
          end

        endcase 
      end

      // READY
      e_cce_lce_cmd_ready: begin
        case (cce_lce_cmd.msg_type)
          e_lce_cmd_transfer: begin
            data_mem_pkt.index = cce_lce_cmd_addr_index;
            data_mem_pkt.way = cce_lce_cmd.way_id;
            data_mem_pkt.write_not_read = 1'b0;
            data_mem_pkt_v_o = cce_lce_cmd_v_i;
            state_n = data_mem_pkt_yumi_i
              ? e_cce_lce_cmd_tr
              : e_cce_lce_cmd_ready;
          end

          e_lce_cmd_writeback: begin
            stat_mem_pkt.index = cce_lce_cmd_addr_index;
            stat_mem_pkt.way = cce_lce_cmd.way_id;
            stat_mem_pkt.opcode = e_dcache_lce_stat_mem_read;
            stat_mem_pkt_v_o = cce_lce_cmd_v_i;
            state_n = stat_mem_pkt_yumi_i
              ? e_cce_lce_cmd_wb
              : e_cce_lce_cmd_ready;
          end

          e_lce_cmd_set_tag: begin
            tag_mem_pkt.index = cce_lce_cmd_addr_index;
            tag_mem_pkt.way = cce_lce_cmd.way_id;
            tag_mem_pkt.state = cce_lce_cmd.state;
            tag_mem_pkt.tag = cce_lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_set_tag;
            tag_mem_pkt_v_o = cce_lce_cmd_v_i;
            cce_lce_cmd_yumi_o = tag_mem_pkt_yumi_i;
            tag_set_o = tag_mem_pkt_yumi_i;
          end

          e_lce_cmd_set_tag_wakeup: begin
            tag_mem_pkt.index = cce_lce_cmd_addr_index;
            tag_mem_pkt.way = cce_lce_cmd.way_id;
            tag_mem_pkt.state = cce_lce_cmd.state;
            tag_mem_pkt.tag = cce_lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_set_tag;
            tag_mem_pkt_v_o = cce_lce_cmd_v_i;
            cce_lce_cmd_yumi_o = tag_mem_pkt_yumi_i;
            tag_set_wakeup_o = tag_mem_pkt_yumi_i;
          end

          e_lce_cmd_invalidate_tag: begin
            tag_mem_pkt.index = cce_lce_cmd_addr_index;
            tag_mem_pkt.way = cce_lce_cmd.way_id;
            tag_mem_pkt.opcode = e_dcache_lce_tag_mem_invalidate;
            tag_mem_pkt_v_o = invalidated_tag_r
              ? 1'b0
              : cce_lce_cmd_v_i;
            invalidated_tag_n = lce_cce_resp_yumi_i
              ? 1'b0
              : (invalidated_tag_r
                ? 1'b1
                : tag_mem_pkt_yumi_i);

            
            stat_mem_pkt.index = cce_lce_cmd_addr_index;
            stat_mem_pkt.way = cce_lce_cmd.way_id;
            stat_mem_pkt.opcode = e_dcache_lce_stat_mem_set_lru;
            stat_mem_pkt_v_o = updated_lru_r
              ? 1'b0
              : invalidated_tag_r | tag_mem_pkt_yumi_i;
            updated_lru_n = lce_cce_resp_yumi_i
              ? 1'b0
              : (updated_lru_r
                ? 1'b1
                : stat_mem_pkt_yumi_i);

            lce_cce_resp.dst_id = cce_lce_cmd.src_id;
            lce_cce_resp.msg_type = e_lce_cce_inv_ack;
            lce_cce_resp.addr = cce_lce_cmd.addr;
            lce_cce_resp_v_o = (invalidated_tag_r | tag_mem_pkt_yumi_i) & (updated_lru_r | stat_mem_pkt_yumi_i);
            cce_lce_cmd_yumi_o = lce_cce_resp_yumi_i;
          end
        endcase
      end
    
      e_cce_lce_cmd_tr: begin
        data_buf_n = tr_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        tr_data_buffered_n = ~lce_lce_tr_resp_done;

        lce_lce_tr_resp_out.dst_id = cce_lce_cmd.target;
        lce_lce_tr_resp_out.way_id = cce_lce_cmd.target_way_id;
        lce_lce_tr_resp_out.addr = cce_lce_cmd.addr;
        lce_lce_tr_resp_out.data = tr_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        lce_lce_tr_resp_v_o = 1'b1;

        cce_lce_cmd_yumi_o = lce_lce_tr_resp_done;
        state_n = lce_lce_tr_resp_done
          ? e_cce_lce_cmd_ready
          : e_cce_lce_cmd_tr;
      end

      e_cce_lce_cmd_wb: begin
        state_n = dirty_i[cce_lce_cmd.way_id] 
          ? e_cce_lce_cmd_wb_dirty
          : e_cce_lce_cmd_wb_not_dirty;
      end

      e_cce_lce_cmd_wb_dirty: begin
        data_mem_pkt.index = cce_lce_cmd_addr_index;
        data_mem_pkt.way = cce_lce_cmd.way_id;
        data_mem_pkt.write_not_read = 1'b0;
        data_mem_pkt_v_o = ~wb_data_read_r;
        data_buf_n = wb_data_buffered_r
          ? data_buf_r
          : (wb_data_read_r
            ? data_mem_data_i
            : data_buf_r);
        wb_data_buffered_n = lce_cce_data_resp_done
          ? 1'b0
          : (wb_data_buffered_r
            ? 1'b1
            : wb_data_read_r);
        wb_data_read_n = lce_cce_data_resp_done
          ? 1'b0
          : (wb_data_read_r
            ? 1'b1
            : data_mem_pkt_yumi_i);

        stat_mem_pkt.index = cce_lce_cmd_addr_index;
        stat_mem_pkt.way = cce_lce_cmd.way_id;
        stat_mem_pkt.opcode = e_dcache_lce_stat_mem_clear_dirty;
        stat_mem_pkt_v_o = wb_dirty_cleared_r
          ? 1'b0
          : (wb_data_read_r | data_mem_pkt_yumi_i);
        wb_dirty_cleared_n = lce_cce_data_resp_done
          ? 1'b0
          : (wb_dirty_cleared_r
            ? 1'b1
            : stat_mem_pkt_yumi_i);
        
        lce_cce_data_resp.dst_id = cce_lce_cmd.src_id;
        lce_cce_data_resp.msg_type = e_lce_resp_wb;
        lce_cce_data_resp.addr = cce_lce_cmd.addr;
        lce_cce_data_resp.data = wb_data_buffered_r
          ? data_buf_r
          : data_mem_data_i;
        lce_cce_data_resp_v_o = wb_data_read_r & (wb_dirty_cleared_r | stat_mem_pkt_yumi_i);
        cce_lce_cmd_yumi_o = lce_cce_data_resp_done;
        state_n = lce_cce_data_resp_done
          ? e_cce_lce_cmd_ready
          : e_cce_lce_cmd_wb_dirty;
      end

      e_cce_lce_cmd_wb_not_dirty: begin
        lce_cce_data_resp.dst_id = cce_lce_cmd.src_id;
        lce_cce_data_resp.msg_type = e_lce_resp_null_wb;
        lce_cce_data_resp.addr = cce_lce_cmd.addr;
        lce_cce_data_resp_v_o = 1'b1;
        cce_lce_cmd_yumi_o = lce_cce_data_resp_done;
        state_n = lce_cce_data_resp_done
          ? e_cce_lce_cmd_ready
          : e_cce_lce_cmd_wb_not_dirty;
      end
    endcase
  end


  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_cce_lce_cmd_reset;
      sync_ack_count_r <= '0;
      invalidated_tag_r <= 1'b0;
      updated_lru_r <= 1'b0;
      tr_data_buffered_r <= 1'b0;
      tr_dirty_cleared_r <= 1'b0;
      wb_data_buffered_r <= 1'b0;
      wb_data_read_r <= 1'b0;
      wb_dirty_cleared_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      sync_ack_count_r <= sync_ack_count_n;
      invalidated_tag_r <= invalidated_tag_n;
      updated_lru_r <= updated_lru_n;
      tr_data_buffered_r <= tr_data_buffered_n;
      tr_dirty_cleared_r <= tr_dirty_cleared_n;
      wb_data_buffered_r <= wb_data_buffered_n;
      wb_data_read_r <= wb_data_read_n;
      wb_dirty_cleared_r <= wb_dirty_cleared_n;
      data_buf_r <= data_buf_n;
    end
  end

endmodule
