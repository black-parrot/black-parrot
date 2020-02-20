/**
 *
 * Name:
 *   bp_fe_lce_cmd.v
 * 
 * Description:
 *   To be updated
 *
 * Parameters:
 *
 * Inputs:
 *
 * Outputs:
 *   
 * Keywords:
 * 
 * Notes:
 * 
 */


module bp_fe_lce_cmd
  import bp_common_pkg::*;
  import bp_fe_icache_pkg::*;
  import bp_fe_pkg::*; 
  import bp_common_aviary_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
   , localparam block_size_in_words_lp=lce_assoc_p
   , localparam data_mask_width_lp=(dword_width_p>>3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_p)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)
   
   `declare_bp_cache_if_widths(lce_assoc_p, lce_sets_p, tag_width_lp, cce_block_width_p)

   , localparam bp_fe_icache_stat_width_lp = `bp_fe_icache_stat_width(lce_assoc_p)

    // width for counter used during initiliazation and for sync messages
    , localparam cnt_width_lp = `BSG_MAX(cce_id_width_p+1, `BSG_SAFE_CLOG2(lce_sets_p)+1)
    , localparam cnt_max_val_lp = ((2**cnt_width_lp)-1)
  )
  (
    input                                                        clk_i
    , input                                                      reset_i
    , input [lce_id_width_p-1:0]                                 lce_id_i

    , input [paddr_width_p-1:0]                                  miss_addr_i

    , output logic                                               lce_ready_o
    , output logic                                               set_tag_received_o
    , output logic                                               set_tag_wakeup_received_o
    , output logic                                               cce_data_received_o
    , output logic                                               uncached_data_received_o
   
    , output logic [bp_cache_data_mem_pkt_width_lp-1:0]          data_mem_pkt_o
    , output logic                                               data_mem_pkt_v_o
    , input                                                      data_mem_pkt_ready_i
    , input  logic [cce_block_width_p-1:0]                       data_mem_i

    , output logic [bp_cache_tag_mem_pkt_width_lp-1:0]           tag_mem_pkt_o
    , output logic                                               tag_mem_pkt_v_o
    , input                                                      tag_mem_pkt_ready_i
    , input  logic [tag_width_lp-1:0]                            tag_mem_i

    , output logic                                               stat_mem_pkt_v_o
    , output logic [bp_cache_stat_mem_pkt_width_lp-1:0]          stat_mem_pkt_o
    , input                                                      stat_mem_pkt_ready_i
    , input  [bp_fe_icache_stat_width_lp-1:0]                    stat_mem_i

    , output logic [lce_cce_resp_width_lp-1:0]                   lce_resp_o
    , output logic                                               lce_resp_v_o
    , input                                                      lce_resp_yumi_i

    , input [lce_cmd_width_lp-1:0]                               lce_cmd_i
    , input                                                      lce_cmd_v_i
    , output logic                                               lce_cmd_yumi_o
    
    , output logic [lce_cmd_width_lp-1:0]                        lce_cmd_o
    , output logic                                               lce_cmd_v_o
    , input                                                      lce_cmd_ready_i 
  );

  // lce interface
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cmd_s lce_cmd_li;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cmd_s lce_cmd_out;

  assign lce_cmd_li    = lce_cmd_i;
  assign lce_resp_o    = lce_resp;
  assign lce_cmd_o     = lce_cmd_out;
 
  logic [index_width_lp-1:0] lce_cmd_addr_index;
  logic [tag_width_lp-1:0] lce_cmd_addr_tag;
  assign lce_cmd_addr_index = lce_cmd_li.msg.cmd.addr[block_offset_width_lp+:index_width_lp];
  assign lce_cmd_addr_tag = lce_cmd_li.msg.cmd.addr[block_offset_width_lp+index_width_lp+:tag_width_lp];
 
  // lce pkt
  //
  `declare_bp_cache_data_mem_pkt_s(lce_sets_p, lce_assoc_p, cce_block_width_p);
  `declare_bp_cache_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, tag_width_lp);
  `declare_bp_cache_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);
  
  `declare_bp_fe_icache_stat_s(lce_assoc_p);

  bp_cache_data_mem_pkt_s data_mem_pkt;
  bp_cache_tag_mem_pkt_s tag_mem_pkt;
  bp_cache_stat_mem_pkt_s stat_mem_pkt;
  
  bp_fe_icache_stat_s stat_mem_cast_i;
  
  assign data_mem_pkt_o = data_mem_pkt;
  assign tag_mem_pkt_o  = tag_mem_pkt;
  assign stat_mem_pkt_o = stat_mem_pkt;
  
  assign stat_mem_cast_i = stat_mem_i;

  logic [cce_block_width_p-1:0] data_r, data_n;
  logic flag_data_buffered_r, flag_data_buffered_n;
  logic flag_invalidate_r, flag_invalidate_n;
  
  logic data_mem_pkt_v, tag_mem_pkt_v, stat_mem_pkt_v;
  assign data_mem_pkt_v_o = data_mem_pkt_v;
  assign tag_mem_pkt_v_o = tag_mem_pkt_v;
  assign stat_mem_pkt_v_o = stat_mem_pkt_v;

  // states
  typedef enum logic [1:0] {
    e_lce_cmd_reset
  , e_lce_cmd_uncached_only
  , e_lce_cmd_ready
  , e_lce_cmd_send_transfer
  } bp_fe_lce_cmd_state_e;

  bp_fe_lce_cmd_state_e state_r, state_n;

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
 
  // lce_cmd fsm
  always_comb begin
    cnt_inc = 1'b0;
    cnt_clear = reset_i;

    lce_cmd_yumi_o = 1'b0;

    lce_resp = '0;
    lce_resp.src_id = lce_id_i;
    lce_resp_v_o = 1'b0;

    lce_cmd_out = '0;
    lce_cmd_v_o = 1'b0;

    data_mem_pkt = '0;
    data_mem_pkt_v = 1'b0;
    tag_mem_pkt = '0;
    tag_mem_pkt_v = 1'b0;
    stat_mem_pkt = '0;
    stat_mem_pkt_v = 1'b0;

    lce_ready_o             = (state_r != e_lce_cmd_reset);
    set_tag_received_o               = 1'b0;
    set_tag_wakeup_received_o        = 1'b0;
    cce_data_received_o              = 1'b0;
    uncached_data_received_o         = 1'b0;

    state_n = state_r;
    data_n = data_r;
    flag_data_buffered_n = flag_data_buffered_r;
    flag_invalidate_n = flag_invalidate_r;

    case (state_r)

      // After reset_i goes low, this module clears all stat and tag mem entries,
      // resetting the state of the cache and LCE
      e_lce_cmd_reset: begin
        if(tag_mem_pkt_ready_i) begin
          tag_mem_pkt.index        = cnt_r[0+:index_width_lp];
          tag_mem_pkt.state        = e_COH_I;
          tag_mem_pkt.tag          = '0;
          tag_mem_pkt.opcode       = e_cache_tag_mem_set_clear;
          tag_mem_pkt_v          = 1'b1;
        end

        if(stat_mem_pkt_ready_i) begin
          stat_mem_pkt.index       = cnt_r[0+:index_width_lp];
          stat_mem_pkt.opcode      = e_cache_stat_mem_set_clear;
          stat_mem_pkt_v         = 1'b1;
        end

        state_n = ((cnt_r == cnt_width_lp'(lce_sets_p-1)) & tag_mem_pkt_v & stat_mem_pkt_v)
          ? e_lce_cmd_uncached_only
          : e_lce_cmd_reset;
        cnt_clear = (state_n == e_lce_cmd_uncached_only);
        cnt_inc = ~cnt_clear & (tag_mem_pkt_v & stat_mem_pkt_v);
      end

      e_lce_cmd_uncached_only: begin
        if (lce_cmd_li.msg_type == e_lce_cmd_set_clear) begin
          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index        = lce_cmd_addr_index;
            tag_mem_pkt.state        = e_COH_I;
            tag_mem_pkt.tag          = '0;
            tag_mem_pkt.opcode       = e_cache_tag_mem_set_clear;
            tag_mem_pkt_v          = lce_cmd_v_i;
          end

          if(stat_mem_pkt_ready_i) begin
            stat_mem_pkt.index       = lce_cmd_addr_index;
            stat_mem_pkt.opcode      = e_cache_stat_mem_set_clear;
            stat_mem_pkt_v         = lce_cmd_v_i;
          end

          lce_cmd_yumi_o           = tag_mem_pkt_v & stat_mem_pkt_v;

        end
        else if (lce_cmd_li.msg_type == e_lce_cmd_sync) begin
          lce_resp.dst_id = lce_cmd_li.msg.cmd.src_id;
          lce_resp.msg_type = e_lce_cce_sync_ack;
          lce_resp_v_o = lce_cmd_v_i;
          lce_cmd_yumi_o = lce_resp_yumi_i;
          state_n = ((cnt_r == cnt_width_lp'(num_cce_p-1)) & lce_resp_yumi_i)
            ? e_lce_cmd_ready
            : e_lce_cmd_uncached_only;
          
          // clear counter when moving to ready state
          cnt_clear = (state_n == e_lce_cmd_ready);
          // only increment counter when staying in uncached_only state and waiting for more
          // sync messages, and when the lce_resp is sent
          cnt_inc = ~cnt_clear & lce_resp_yumi_i;
         
        end 
        else if (lce_cmd_li.msg_type == e_lce_cmd_uc_data) begin
          if(data_mem_pkt_ready_i) begin
            data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.data = lce_cmd_li.msg.dt_cmd.data;
            data_mem_pkt.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_v = lce_cmd_v_i;
          end

          lce_cmd_yumi_o = data_mem_pkt_v;

          uncached_data_received_o = data_mem_pkt_v;

        end
      end

      e_lce_cmd_ready: begin
        if (lce_cmd_li.msg_type == e_lce_cmd_transfer) begin
          if(data_mem_pkt_ready_i) begin
            data_mem_pkt.index  = lce_cmd_addr_index;
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.opcode = e_cache_data_mem_read;
            data_mem_pkt_v    = lce_cmd_v_i;
          end

          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.opcode = e_cache_tag_mem_read;
            tag_mem_pkt_v = lce_cmd_v_i;
          end

          state_n             = (data_mem_pkt_v & tag_mem_pkt_v) ? e_lce_cmd_send_transfer : e_lce_cmd_ready;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_writeback) begin
          lce_resp.dst_id   = lce_cmd_li.msg.cmd.src_id;
          lce_resp.msg_type = e_lce_cce_resp_null_wb;
          lce_resp.addr     = lce_cmd_li.msg.cmd.addr;
          lce_resp_v_o      = lce_cmd_v_i;
          lce_cmd_yumi_o    = lce_resp_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_tag) begin
          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index  = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state  = lce_cmd_li.msg.cmd.state;
            tag_mem_pkt.tag    = lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v    = lce_cmd_v_i;
          end

          lce_cmd_yumi_o     = tag_mem_pkt_v;
          set_tag_received_o = tag_mem_pkt_v;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_tag_wakeup) begin
          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index  = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state  = lce_cmd_li.msg.cmd.state;
            tag_mem_pkt.tag    = lce_cmd_addr_tag;
            tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v    = lce_cmd_v_i;
          end

          lce_cmd_yumi_o     = tag_mem_pkt_v;
          set_tag_wakeup_received_o = tag_mem_pkt_v;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_invalidate_tag) begin
          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index = lce_cmd_addr_index;
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state = e_COH_I;
            tag_mem_pkt.opcode = e_cache_tag_mem_invalidate;
            tag_mem_pkt_v = flag_invalidate_r
              ? 1'b0
              : lce_cmd_v_i;
          end

          flag_invalidate_n = lce_resp_yumi_i
            ? 1'b0
            : (flag_invalidate_r
                ? 1'b1  
                : tag_mem_pkt_v);

          lce_resp.dst_id = lce_cmd_li.msg.cmd.src_id;
          lce_resp.msg_type = e_lce_cce_inv_ack;
          lce_resp.addr = lce_cmd_li.msg.cmd.addr;
          lce_resp_v_o = (flag_invalidate_r | tag_mem_pkt_v);
          lce_cmd_yumi_o = lce_resp_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_data) begin
          if(data_mem_pkt_ready_i) begin
            data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.data = lce_cmd_li.msg.dt_cmd.data;
            data_mem_pkt.opcode = e_cache_data_mem_write;
            data_mem_pkt_v = lce_cmd_v_i;
          end
          
          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index  = miss_addr_i[block_offset_width_lp+:index_width_lp];
            tag_mem_pkt.way_id = lce_cmd_li.way_id;
            tag_mem_pkt.state  = lce_cmd_li.msg.dt_cmd.state;
            tag_mem_pkt.tag    = lce_cmd_li.msg.dt_cmd.addr[block_offset_width_lp+index_width_lp+:tag_width_lp];
            tag_mem_pkt.opcode = e_cache_tag_mem_set_tag;
            tag_mem_pkt_v    = lce_cmd_v_i;
          end

          lce_cmd_yumi_o     = tag_mem_pkt_v & data_mem_pkt_v;

          cce_data_received_o = tag_mem_pkt_v & data_mem_pkt_v;
          set_tag_received_o  = tag_mem_pkt_v & data_mem_pkt_v;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_uc_data) begin
          if(data_mem_pkt_ready_i) begin
            data_mem_pkt.index = miss_addr_i[block_offset_width_lp+:index_width_lp];
            data_mem_pkt.way_id = lce_cmd_li.way_id;
            data_mem_pkt.data = lce_cmd_li.msg.dt_cmd.data;
            data_mem_pkt.opcode = e_cache_data_mem_uncached;
            data_mem_pkt_v = lce_cmd_v_i;
          end

          lce_cmd_yumi_o = data_mem_pkt_v;

          uncached_data_received_o = data_mem_pkt_v;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_clear) begin
          if(tag_mem_pkt_ready_i) begin
            tag_mem_pkt.index        = lce_cmd_addr_index;
            tag_mem_pkt.state        = e_COH_I;
            tag_mem_pkt.tag          = '0;
            tag_mem_pkt.opcode       = e_cache_tag_mem_set_clear;
            tag_mem_pkt_v          = lce_cmd_v_i;
          end

          if(stat_mem_pkt_ready_i) begin
            stat_mem_pkt.index       = lce_cmd_addr_index;
            stat_mem_pkt.opcode      = e_cache_stat_mem_set_clear;
            stat_mem_pkt_v         = lce_cmd_v_i;
          end
          
          lce_cmd_yumi_o           = tag_mem_pkt_v & stat_mem_pkt_v;

        end

      end

      e_lce_cmd_send_transfer: begin
        
        flag_data_buffered_n = ~lce_cmd_ready_i;
        data_n               = flag_data_buffered_r ? data_r : data_mem_i;
        
        lce_cmd_out.msg.dt_cmd.data = flag_data_buffered_r ? data_r : data_mem_i;
        lce_cmd_out.msg.dt_cmd.addr = lce_cmd_li.msg.cmd.addr;
        lce_cmd_out.msg.dt_cmd.state = lce_cmd_li.msg.cmd.state;
        lce_cmd_out.way_id   = lce_cmd_li.msg.cmd.target_way_id;
        lce_cmd_out.msg_type = e_lce_cmd_data;
        lce_cmd_out.dst_id   = lce_cmd_li.msg.cmd.target;
        lce_cmd_v_o          = lce_cmd_ready_i;
        lce_cmd_yumi_o       = lce_cmd_v_o;
        state_n              = lce_cmd_v_o ? e_lce_cmd_ready : e_lce_cmd_send_transfer;
        
      end

      default: begin

      end
    endcase
  end 
  
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_lce_cmd_reset;
      flag_data_buffered_r <= 1'b0;
      flag_invalidate_r    <= 1'b0;
    end else begin
      state_r              <= state_n;
      data_r               <= data_n;
      flag_data_buffered_r <= flag_data_buffered_n;
      flag_invalidate_r    <= flag_invalidate_n;
    end
  end

endmodule
