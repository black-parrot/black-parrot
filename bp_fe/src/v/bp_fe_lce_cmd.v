/**
 *
 * Name:
 *   bp_fe_lce_cmd_li.v
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
  #(parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"

    , localparam block_size_in_words_lp=ways_p
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam cce_id_width_lp=`BSG_SAFE_CLOG2(num_cce_p)

    , localparam data_mem_pkt_width_lp=
      `bp_fe_icache_lce_data_mem_pkt_width(sets_p,ways_p,lce_data_width_p)
    , localparam tag_mem_pkt_width_lp=
      `bp_fe_icache_lce_tag_mem_pkt_width(sets_p,ways_p,tag_width_lp)
    , localparam metadata_mem_pkt_width_lp=
      `bp_fe_icache_lce_metadata_mem_pkt_width(sets_p,ways_p)

    , localparam cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p)
    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, lce_data_width_p, ways_p)
  )
  (
    input                                                        clk_i
    , input                                                      reset_i
    , input [lce_id_width_lp-1:0]                                id_i

    , output logic                                               lce_ready_o
    , output logic                                               set_tag_received_o
    , output logic                                               set_tag_wakeup_received_o

    , input [lce_data_width_p-1:0]                               data_mem_data_i
    , output logic [data_mem_pkt_width_lp-1:0]                   data_mem_pkt_o
    , output logic                                               data_mem_pkt_v_o
    , input                                                      data_mem_pkt_yumi_i

    , output logic [tag_mem_pkt_width_lp-1:0]                    tag_mem_pkt_o
    , output logic                                               tag_mem_pkt_v_o
    , input                                                      tag_mem_pkt_yumi_i

    , output logic                                               metadata_mem_pkt_v_o
    , output logic [metadata_mem_pkt_width_lp-1:0]               metadata_mem_pkt_o
    , input                                                      metadata_mem_pkt_yumi_i

    , output logic [lce_cce_resp_width_lp-1:0]                   lce_resp_o
    , output logic                                               lce_resp_v_o
    , input                                                      lce_resp_yumi_i

    , output logic [lce_cce_data_resp_width_lp-1:0]              lce_data_resp_o     
    , output logic                                               lce_data_resp_v_o 
    , input                                                      lce_data_resp_ready_i

    , input [cce_lce_cmd_width_lp-1:0]                           lce_cmd_i
    , input                                                      lce_cmd_v_i
    , output logic                                               lce_cmd_ready_o
    
    , output logic [lce_data_cmd_width_lp-1:0]                   lce_data_cmd_o
    , output logic                                               lce_data_cmd_v_o
    , input                                                      lce_data_cmd_ready_i 
  );

  // lce interface
  //
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_data_cmd_s(num_lce_p, lce_data_width_p, ways_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_p);

  bp_cce_lce_cmd_s lce_cmd_li;
  logic lce_cmd_v_li, lce_cmd_yumi_lo;
  bp_lce_cce_resp_s lce_resp;
  bp_lce_data_cmd_s lce_data_cmd_out;
  bp_lce_cce_data_resp_s lce_data_resp;

  assign lce_resp_o         = lce_resp;
  assign lce_data_resp_o    = lce_data_resp;
  assign lce_data_cmd_o     = lce_data_cmd_out;
 
  logic [index_width_lp-1:0] lce_cmd_addr_index;
  logic [tag_width_lp-1:0] lce_cmd_addr_tag;
  assign lce_cmd_addr_index = lce_cmd_li.addr[block_offset_width_lp+:index_width_lp];
  assign lce_cmd_addr_tag = lce_cmd_li.addr[block_offset_width_lp+index_width_lp+:tag_width_lp];
 
  // lce pkt
  //
  `declare_bp_fe_icache_lce_data_mem_pkt_s(sets_p, ways_p, lce_data_width_p);
  `declare_bp_fe_icache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_lp);
  `declare_bp_fe_icache_lce_metadata_mem_pkt_s(sets_p, ways_p);

  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt;
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_fe_icache_lce_metadata_mem_pkt_s metadata_mem_pkt;

  assign data_mem_pkt_o     = data_mem_pkt;
  assign tag_mem_pkt_o      = tag_mem_pkt;
  assign metadata_mem_pkt_o = metadata_mem_pkt;

  // states
  //
  logic [cce_id_width_lp-1:0] syn_ack_cnt_r, syn_ack_cnt_n;
  logic [lce_data_width_p-1:0] data_r, data_n;
  logic flag_data_buffered_r, flag_data_buffered_n;
  logic flag_invalidate_r, flag_invalidate_n;

  bp_fe_lce_cmd_state_e state_r, state_n;

 
  // lce_cmd fsm
  always_comb begin

    lce_cmd_yumi_lo = 1'b0;

    lce_resp = '0;
    lce_resp.src_id = id_i;
    lce_resp_v_o = 1'b0;

    lce_data_resp = '0;
    lce_data_resp.src_id = id_i;
    lce_data_resp_v_o = 1'b0;

    lce_data_cmd_out = '0;
    lce_data_cmd_v_o = 1'b0;

    data_mem_pkt = '0;
    data_mem_pkt_v_o = 1'b0;
    tag_mem_pkt = '0;
    tag_mem_pkt_v_o = 1'b0;
    metadata_mem_pkt = '0;
    metadata_mem_pkt_v_o = 1'b0;

    lce_ready_o             = (state_r != e_lce_cmd_reset);
    set_tag_received_o               = 1'b0;
    set_tag_wakeup_received_o        = 1'b0;

    state_n = state_r;
    data_n = data_r;
    syn_ack_cnt_n = syn_ack_cnt_r;
    flag_data_buffered_n = flag_data_buffered_r;
    flag_invalidate_n = flag_invalidate_r;
           
    case (state_r)
      e_lce_cmd_ready: begin
        if (lce_cmd_li.msg_type == e_lce_cmd_transfer) begin
          data_mem_pkt.index  = lce_cmd_addr_index;
          data_mem_pkt.way_id = lce_cmd_li.way_id;
          data_mem_pkt.we     = 1'b0;
          data_mem_pkt_v_o    = lce_cmd_v_li;
          state_n             = data_mem_pkt_yumi_i ? e_lce_cmd_transfer_tmp : e_lce_cmd_ready;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_writeback) begin
          lce_data_resp.dst_id   = lce_cmd_li.src_id;
          lce_data_resp.msg_type = e_lce_resp_null_wb;
          lce_data_resp.addr     = lce_cmd_li.addr;
          lce_data_resp_v_o      = lce_cmd_v_li;
          lce_cmd_yumi_lo         = lce_data_resp_ready_i & lce_data_resp_v_o;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_tag) begin
          tag_mem_pkt.index  = lce_cmd_addr_index;
          tag_mem_pkt.way_id = lce_cmd_li.way_id;
          tag_mem_pkt.state  = lce_cmd_li.state;
          tag_mem_pkt.tag    = lce_cmd_addr_tag;
          tag_mem_pkt.opcode = e_tag_mem_set_tag;
          tag_mem_pkt_v_o    = lce_cmd_v_li;

          lce_cmd_yumi_lo     = tag_mem_pkt_yumi_i;
          set_tag_received_o          = tag_mem_pkt_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_tag_wakeup) begin
          tag_mem_pkt.index  = lce_cmd_addr_index;
          tag_mem_pkt.way_id = lce_cmd_li.way_id;
          tag_mem_pkt.state  = lce_cmd_li.state;
          tag_mem_pkt.tag    = lce_cmd_addr_tag;
          tag_mem_pkt.opcode = e_tag_mem_set_tag;
          tag_mem_pkt_v_o    = lce_cmd_v_li;

          lce_cmd_yumi_lo     = tag_mem_pkt_yumi_i;
          set_tag_wakeup_received_o   = tag_mem_pkt_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_invalidate_tag) begin
          tag_mem_pkt.index = lce_cmd_addr_index;
          tag_mem_pkt.way_id = lce_cmd_li.way_id;
          tag_mem_pkt.state = e_MESI_I;
          tag_mem_pkt.opcode = e_tag_mem_invalidate;
          tag_mem_pkt_v_o = flag_invalidate_r
            ? 1'b0
            : lce_cmd_v_li;
          flag_invalidate_n = lce_resp_yumi_i
            ? 1'b0
            : (flag_invalidate_r
                ? 1'b1  
                : tag_mem_pkt_yumi_i);

          lce_resp.dst_id = lce_cmd_li.src_id;
          lce_resp.msg_type = e_lce_cce_inv_ack;
          lce_resp.addr = lce_cmd_li.addr;
          lce_resp_v_o = (flag_invalidate_r | tag_mem_pkt_yumi_i);
          lce_cmd_yumi_lo = lce_resp_yumi_i;
        end
      end

      e_lce_cmd_transfer_tmp: begin
        flag_data_buffered_n     = ~lce_data_cmd_ready_i;
        data_n                   = flag_data_buffered_r ? data_r : data_mem_data_i;
        lce_data_cmd_out.dst_id  = lce_cmd_li.target;
        lce_data_cmd_out.way_id  = lce_cmd_li.target_way_id;
        lce_data_cmd_out.msg_type = e_lce_data_cmd_transfer;
        lce_data_cmd_out.data    = flag_data_buffered_r ? data_r : data_mem_data_i;
        lce_cmd_yumi_lo           = lce_data_cmd_ready_i;
        lce_data_cmd_v_o         = 1'b1;
        state_n                  = lce_data_cmd_ready_i ? e_lce_cmd_ready : e_lce_cmd_transfer_tmp;
      end

      e_lce_cmd_reset: begin
        if (lce_cmd_li.msg_type == e_lce_cmd_set_clear) begin
          tag_mem_pkt.index        = lce_cmd_addr_index;
          tag_mem_pkt.state        = e_MESI_I;
          tag_mem_pkt.tag          = '0;
          tag_mem_pkt.opcode       = e_tag_mem_set_clear;
          tag_mem_pkt_v_o          = lce_cmd_v_li;
          metadata_mem_pkt.index   = lce_cmd_addr_index;
          metadata_mem_pkt.opcode  = e_metadata_mem_set_clear;
          metadata_mem_pkt_v_o     = lce_cmd_v_li;
          lce_cmd_yumi_lo           = tag_mem_pkt_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_sync) begin
          lce_resp.dst_id = lce_cmd_li.src_id;
          lce_resp.msg_type = e_lce_cce_sync_ack;
          lce_resp_v_o = lce_cmd_v_li;
          lce_cmd_yumi_lo = lce_resp_yumi_i;
          syn_ack_cnt_n = lce_resp_yumi_i
            ? syn_ack_cnt_r + 1
            : syn_ack_cnt_r;
          state_n = (syn_ack_cnt_r == cce_id_width_lp'(num_cce_p-1)) & lce_resp_yumi_i
            ? e_lce_cmd_ready
            : e_lce_cmd_reset;
        end
      end

      default: begin

      end
    endcase
  end 
  
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_lce_cmd_reset;
      syn_ack_cnt_r        <= '0;
      flag_data_buffered_r <= 1'b0;
      flag_invalidate_r    <= 1'b0;
    end else begin
      state_r              <= state_n;
      syn_ack_cnt_r        <= syn_ack_cnt_n;
      data_r               <= data_n;
      flag_data_buffered_r <= flag_data_buffered_n;
      flag_invalidate_r    <= flag_invalidate_n;
    end
  end

  // We need this converter because the LCE expects this interface to be valid-yumi, while
  // the network links are ready-and-valid. It's possible that we could modify the LCE to
  // be helpful and avoid this
  bsg_two_fifo
   #(.width_p(cce_lce_cmd_width_lp))
   rv_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(lce_cmd_i)
     ,.v_i(lce_cmd_v_i)
     ,.ready_o(lce_cmd_ready_o)

     ,.data_o(lce_cmd_li)
     ,.v_o(lce_cmd_v_li)
     ,.yumi_i(lce_cmd_yumi_lo)
     );

endmodule
