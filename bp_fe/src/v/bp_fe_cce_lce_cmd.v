/**
 *
 * bp_fe_cce_lce_cmd.v
*/

`ifndef BP_CCE_MSG_VH
`define BP_CCE_MSG_VH
`include "bp_common_me_if.vh"
`endif

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

module bp_fe_cce_lce_cmd
  #(parameter data_width_p="inv"
    ,parameter lce_data_width_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter lce_sets_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter coh_states_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    ,parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    ,parameter lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    ,parameter lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
    ,parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    ,parameter timeout_max_limit_p=4

    ,parameter bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p, lce_assoc_p, lce_data_width_p)
    ,parameter bp_fe_icache_lce_tag_mem_pkt_width_lp=`bp_fe_icache_lce_tag_mem_pkt_width(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p)
    ,parameter bp_fe_icache_lce_meta_data_mem_pkt_width_lp=`bp_fe_icache_lce_meta_data_mem_pkt_width(lce_sets_p, lce_assoc_p)

    ,parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p)
    ,parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)
    ,parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p)
    ,parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p, coh_states_p)
    ,parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p)
    ,parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p)    

    ,localparam lce_id_width_lp=`bp_lce_id_width
   )
   (
    input logic                                                clk_i
    ,input logic                                               reset_i

    ,input logic [lce_id_width_lp-1:0]                         id_i

    ,output logic                                              lce_ready_o
    ,output logic                                              tag_set_o
    ,output logic                                              tag_set_wakeup_o

    ,input logic [lce_data_width_p-1:0]                        data_mem_data_i
    ,output logic [bp_fe_icache_lce_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    ,output logic                                              data_mem_pkt_v_o
    ,input logic                                               data_mem_pkt_yumi_i

    ,output logic [bp_fe_icache_lce_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    ,output logic                                              tag_mem_pkt_v_o
    ,input logic                                               tag_mem_pkt_yumi_i

    ,output logic                                              meta_data_mem_pkt_v_o
    ,output logic [bp_fe_icache_lce_meta_data_mem_pkt_width_lp-1:0] meta_data_mem_pkt_o
    ,input logic                                               meta_data_mem_pkt_yumi_i

    ,output logic [bp_lce_cce_resp_width_lp-1:0]               lce_cce_resp_o
    ,output logic                                              lce_cce_resp_v_o
    ,input  logic                                              lce_cce_resp_yumi_i

    ,output logic [bp_lce_cce_data_resp_width_lp-1:0]          lce_cce_data_resp_o     
    ,output logic                                              lce_cce_data_resp_v_o 
    ,input logic                                               lce_cce_data_resp_ready_i

    ,input logic [bp_cce_lce_cmd_width_lp-1:0]                 cce_lce_cmd_i
    ,input logic                                               cce_lce_cmd_v_i
    ,output logic                                              cce_lce_cmd_yumi_o

    ,output logic [bp_lce_lce_tr_resp_width_lp-1:0]            lce_lce_tr_resp_o
    ,output logic                                              lce_lce_tr_resp_v_o
    ,input logic                                               lce_lce_tr_resp_ready_i
   );

  logic [lg_lce_sets_lp-1:0]                                  syn_ack_cnt_r, syn_ack_cnt_n;
  logic [lce_data_width_p-1:0]                                data_r, data_n;
  logic                                                       flag_data_buffered_r, flag_data_buffered_n;
  logic                                                       flag_invalidate_r, flag_invalidate_n;
  logic                                                       flag_updated_lru_r, flag_updated_lru_n;
   

  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_assoc_p, coh_states_p);
  bp_cce_lce_cmd_s cce_lce_cmd_li;
  assign cce_lce_cmd_li = cce_lce_cmd_i;

  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  bp_lce_cce_resp_s lce_cce_resp_lo;

  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  bp_lce_cce_data_resp_s lce_cce_data_resp_lo;
   
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, lce_assoc_p);
  bp_lce_lce_tr_resp_s lce_lce_tr_resp_lo;

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, data_width_p);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;

  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p);
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt_lo;

  `declare_bp_fe_icache_lce_meta_data_mem_pkt_s(lce_sets_p, lce_assoc_p);
  bp_fe_icache_lce_meta_data_mem_pkt_s meta_data_mem_pkt_lo;

  bp_fe_cce_lce_cmd_state_e state_r, state_n;

  assign lce_cce_resp_o      = lce_cce_resp_lo;
  assign lce_cce_data_resp_o = lce_cce_data_resp_lo;
  assign lce_lce_tr_resp_o   = lce_lce_tr_resp_lo;
  assign data_mem_pkt_o      = data_mem_pkt_lo;
  assign tag_mem_pkt_o       = tag_mem_pkt_lo;
  assign meta_data_mem_pkt_o = meta_data_mem_pkt_lo;
 
  // cce_lce_cmd fsm
  always_comb begin : cce_lce_cmd_fsm
    lce_cce_resp_v_o        = 1'b0;
    cce_lce_cmd_yumi_o      = 1'b0;
    lce_cce_data_resp_v_o   = 1'b0;
    lce_lce_tr_resp_v_o     = 1'b0;

    data_mem_pkt_v_o        = 1'b0;
    tag_mem_pkt_v_o         = 1'b0;
    meta_data_mem_pkt_v_o   = 1'b0;

    lce_cce_resp_lo         = '0;
    lce_cce_data_resp_lo    = '0;
    lce_lce_tr_resp_lo      = '0;

    data_mem_pkt_lo         = '0;
    tag_mem_pkt_lo          = '0;
    meta_data_mem_pkt_v_o   = '0;

    lce_ready_o             = (state_r != e_cce_lce_cmd_reset);
    tag_set_o               = 1'b0;
    tag_set_wakeup_o        = 1'b0;

    state_n                 = state_r;
    data_n                  = data_r;
    syn_ack_cnt_n           = syn_ack_cnt_r;
    data_n                  = data_n;
    flag_data_buffered_n    = flag_data_buffered_r;
    flag_invalidate_n       = flag_invalidate_r;
    flag_updated_lru_n      = flag_updated_lru_r;
           
    case (state_r)
      e_cce_lce_cmd_ready: begin
        if (cce_lce_cmd_li.msg_type == e_lce_cmd_transfer) begin
          data_mem_pkt_lo.index  = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          data_mem_pkt_lo.assoc  = cce_lce_cmd_li.way_id;
          data_mem_pkt_lo.we     = 1'b0;
          data_mem_pkt_v_o       = cce_lce_cmd_v_i;
          state_n                = data_mem_pkt_yumi_i ? e_cce_lce_cmd_transfer : e_cce_lce_cmd_ready;

        end else if (cce_lce_cmd_li.msg_type == e_lce_cmd_writeback) begin
          lce_cce_data_resp_lo.src_id   = id_i;
          lce_cce_data_resp_lo.dst_id   = cce_lce_cmd_li.src_id;
          lce_cce_data_resp_lo.msg_type = e_lce_resp_null_wb;
          lce_cce_data_resp_lo.addr     = cce_lce_cmd_li.addr;
          lce_cce_data_resp_v_o         = cce_lce_cmd_v_i;
          cce_lce_cmd_yumi_o            = lce_cce_data_resp_ready_i & lce_cce_data_resp_v_o;

        end else if (cce_lce_cmd_li.msg_type == e_lce_cmd_set_tag) begin
          tag_mem_pkt_lo.index  = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          tag_mem_pkt_lo.assoc  = cce_lce_cmd_li.way_id;
          tag_mem_pkt_lo.state  = cce_lce_cmd_li.state;
          tag_mem_pkt_lo.tag    = cce_lce_cmd_li.addr[(lg_data_mask_width_lp+lg_block_size_in_bytes_lp+lg_lce_sets_lp)+:tag_width_p];
          tag_mem_pkt_lo.opcode = e_tag_mem_set_tag;
          tag_mem_pkt_v_o       = cce_lce_cmd_v_i;
          cce_lce_cmd_yumi_o    = tag_mem_pkt_yumi_i;
          tag_set_o             = tag_mem_pkt_yumi_i;

        end else if (cce_lce_cmd_li.msg_type == e_lce_cmd_set_tag_wakeup) begin
          tag_mem_pkt_lo.index  = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          tag_mem_pkt_lo.assoc  = cce_lce_cmd_li.way_id;
          tag_mem_pkt_lo.state  = cce_lce_cmd_li.state;
          tag_mem_pkt_lo.tag    = cce_lce_cmd_li.addr[(lg_data_mask_width_lp+lg_block_size_in_bytes_lp+lg_lce_sets_lp)+:tag_width_p];
          tag_mem_pkt_lo.opcode = e_tag_mem_set_tag;
          tag_mem_pkt_v_o       = cce_lce_cmd_v_i;
          cce_lce_cmd_yumi_o    = tag_mem_pkt_yumi_i;
          tag_set_wakeup_o      = tag_mem_pkt_yumi_i;

        end else if (cce_lce_cmd_li.msg_type == e_lce_cmd_invalidate_tag) begin
          tag_mem_pkt_lo.index        = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          tag_mem_pkt_lo.assoc        = cce_lce_cmd_li.way_id;
          tag_mem_pkt_lo.state        = e_VI_I;
          tag_mem_pkt_lo.opcode       = e_tag_mem_ivalidate;
          tag_mem_pkt_v_o             = flag_invalidate_r ? 1'b0 : cce_lce_cmd_v_i;
          flag_invalidate_n           = lce_cce_resp_yumi_i ? 1'b0 : (flag_invalidate_r ? 1'b1 : tag_mem_pkt_yumi_i);

          meta_data_mem_pkt_lo.index  = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          meta_data_mem_pkt_lo.way    = cce_lce_cmd_li.way_id;
          meta_data_mem_pkt_lo.opcode = e_meta_data_mem_set_lru;
          meta_data_mem_pkt_v_o       = flag_updated_lru_r
            ? 1'b0
            : flag_invalidate_r | tag_mem_pkt_yumi_i;
          flag_updated_lru_n          = lce_cce_resp_yumi_i
            ? 1'b0
            : flag_updated_lru_r
              ? 1'b1
              : meta_data_mem_pkt_yumi_i;

          lce_cce_resp_lo.dst_id   = cce_lce_cmd_li.src_id;
          lce_cce_resp_lo.src_id   = id_i;
          lce_cce_resp_lo.msg_type = e_lce_cce_inv_ack;
          lce_cce_resp_lo.addr     = cce_lce_cmd_li.addr;
          lce_cce_resp_v_o         = (flag_invalidate_r | tag_mem_pkt_yumi_i) & (flag_updated_lru_r | meta_data_mem_pkt_yumi_i);
          cce_lce_cmd_yumi_o       = lce_cce_resp_yumi_i;
         end
      end

      e_cce_lce_cmd_transfer: begin //Todo: double check
        flag_data_buffered_n       = ~lce_lce_tr_resp_ready_i;
        data_n                     = flag_data_buffered_r ? data_r : data_mem_data_i;
        lce_lce_tr_resp_lo.dst_id  = cce_lce_cmd_li.target;
        lce_lce_tr_resp_lo.src_id  = id_i;
        lce_lce_tr_resp_lo.way_id  = cce_lce_cmd_li.target_way_id;
        lce_lce_tr_resp_lo.addr    = cce_lce_cmd_li.addr;
        lce_lce_tr_resp_lo.data    = flag_data_buffered_r ? data_r : data_mem_data_i;
        cce_lce_cmd_yumi_o         = lce_lce_tr_resp_ready_i;
        lce_lce_tr_resp_v_o        = 1'b1;
        state_n                    = lce_lce_tr_resp_ready_i ? e_cce_lce_cmd_ready : e_cce_lce_cmd_transfer;
      end

      e_cce_lce_cmd_reset: begin
        if (cce_lce_cmd_li.msg_type == e_lce_cmd_set_clear) begin
          tag_mem_pkt_lo.index        = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          tag_mem_pkt_lo.state        = e_VI_I;
          tag_mem_pkt_lo.tag          = '0;
          tag_mem_pkt_lo.opcode       = e_tag_mem_set_clear;
          tag_mem_pkt_v_o             = cce_lce_cmd_v_i;
          meta_data_mem_pkt_lo.index  = cce_lce_cmd_li.addr[lg_data_mask_width_lp+lg_block_size_in_bytes_lp+:lg_lce_sets_lp];
          meta_data_mem_pkt_lo.opcode = e_meta_data_mem_set_clear;
          meta_data_mem_pkt_v_o       = cce_lce_cmd_v_i;
          cce_lce_cmd_yumi_o          = tag_mem_pkt_yumi_i;

        end else if (cce_lce_cmd_li.msg_type == e_lce_cmd_sync) begin
          lce_cce_resp_lo.dst_id   = cce_lce_cmd_li.src_id;
          lce_cce_resp_lo.src_id   = id_i;
          lce_cce_resp_lo.msg_type = e_lce_cce_sync_ack;
          // lce_cce_resp_lo.addr is left unfilled for sync_ack
          lce_cce_resp_v_o         = cce_lce_cmd_v_i;
          cce_lce_cmd_yumi_o       = lce_cce_resp_yumi_i;
          syn_ack_cnt_n            = (cce_lce_cmd_v_i & lce_cce_resp_yumi_i) ? (syn_ack_cnt_r + 1) : syn_ack_cnt_r;
          if ((syn_ack_cnt_r == (num_cce_p - 1)) & cce_lce_cmd_v_i & lce_cce_resp_yumi_i) begin
            state_n                = e_cce_lce_cmd_ready;
          end
        end
      end
    endcase
  end 
  
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_cce_lce_cmd_reset;
      syn_ack_cnt_r        <= '0;
      data_r               <= '0;
      flag_data_buffered_r <= 1'b0;
      flag_invalidate_r    <= 1'b0;
      flag_updated_lru_r   <= 1'b0;
    end else begin
      state_r              <= state_n;
      syn_ack_cnt_r        <= syn_ack_cnt_n;
      data_r               <= data_n;
      flag_data_buffered_r <= flag_data_buffered_n;
      flag_invalidate_r    <= flag_invalidate_n;
      flag_updated_lru_r   <= flag_updated_lru_n;
    end
  end
endmodule
