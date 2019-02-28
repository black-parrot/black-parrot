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
  #(parameter data_width_p="inv"
    , parameter lce_data_width_p="inv"
    , parameter lce_addr_width_p="inv"
    , parameter lce_sets_p="inv"
    , parameter ways_p="inv"
    , parameter tag_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter block_size_in_bytes_p="inv"
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    , parameter timeout_max_limit_p=4

    , parameter bp_fe_icache_lce_data_mem_pkt_width_lp=`bp_fe_icache_lce_data_mem_pkt_width(lce_sets_p 
                                                                                            ,ways_p
                                                                                            ,lce_data_width_p
                                                                                           )
    , parameter bp_fe_icache_lce_tag_mem_pkt_width_lp=`bp_fe_icache_lce_tag_mem_pkt_width(lce_sets_p
                                                                                          ,ways_p
                                                                                          ,tag_width_p
                                                                                         )
    , parameter bp_fe_icache_lce_metadata_mem_pkt_width_lp=`bp_fe_icache_lce_metadata_mem_pkt_width(lce_sets_p
                                                                                                      ,ways_p
                                                                                                     )

    , parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                                ,num_lce_p
                                                                ,lce_addr_width_p
                                                               )
    , parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                          ,num_lce_p
                                                                          ,lce_addr_width_p
                                                                          ,lce_data_width_p
                                                                         )
    , parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                              ,num_lce_p
                                                              ,lce_addr_width_p
                                                              ,ways_p
                                                             )
    , parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                        ,num_lce_p
                                                                        ,lce_addr_width_p
                                                                        ,lce_data_width_p
                                                                        ,ways_p
                                                                       )
    , parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                      ,lce_addr_width_p
                                                                      ,lce_data_width_p
                                                                      ,ways_p
                                                                     )    
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
   )
   (input                                                        clk_i
    , input                                                      reset_i
    , input [lce_id_width_lp-1:0]                                id_i

    , output logic                                               lce_ready_o
    , output logic                                               tag_set_o
    , output logic                                               tag_set_wakeup_o

    , input [lce_data_width_p-1:0]                               data_mem_data_i
    , output logic [bp_fe_icache_lce_data_mem_pkt_width_lp-1:0]  data_mem_pkt_o
    , output logic                                               data_mem_pkt_v_o
    , input                                                      data_mem_pkt_yumi_i

    , output logic [bp_fe_icache_lce_tag_mem_pkt_width_lp-1:0]   tag_mem_pkt_o
    , output logic                                               tag_mem_pkt_v_o
    , input                                                      tag_mem_pkt_yumi_i

    , output logic                                               metadata_mem_pkt_v_o
    , output logic [bp_fe_icache_lce_metadata_mem_pkt_width_lp-1:0] metadata_mem_pkt_o
    , input                                                      metadata_mem_pkt_yumi_i

    , output logic [bp_lce_cce_resp_width_lp-1:0]                lce_resp_o
    , output logic                                               lce_resp_v_o
    , input                                                      lce_resp_yumi_i

    , output logic [bp_lce_cce_data_resp_width_lp-1:0]           lce_data_resp_o     
    , output logic                                               lce_data_resp_v_o 
    , input                                                      lce_data_resp_ready_i

    , input [bp_cce_lce_cmd_width_lp-1:0]                        lce_cmd_i
    , input                                                      lce_cmd_v_i
    , output logic                                               lce_cmd_yumi_o

    , output logic [bp_lce_lce_tr_resp_width_lp-1:0]             lce_tr_resp_o
    , output logic                                               lce_tr_resp_v_o
    , input                                                      lce_tr_resp_ready_i
   );

  logic [lg_lce_sets_lp-1:0]                                   syn_ack_cnt_r, syn_ack_cnt_n;
  logic [lce_data_width_p-1:0]                                 data_r, data_n;
  logic                                                        flag_data_buffered_r, flag_data_buffered_n;
  logic                                                        flag_invalidate_r, flag_invalidate_n;
  logic                                                        flag_updated_lru_r, flag_updated_lru_n;
   

  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p);
  bp_cce_lce_cmd_s lce_cmd_li;
  assign lce_cmd_li = lce_cmd_i;

  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  bp_lce_cce_resp_s lce_resp_lo;

  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  bp_lce_cce_data_resp_s lce_data_resp_lo;
   
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);
  bp_lce_lce_tr_resp_s lce_tr_resp_lo;

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, ways_p, data_width_p);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt_lo;

  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, ways_p, tag_width_p);
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt_lo;

  `declare_bp_fe_icache_lce_metadata_mem_pkt_s(lce_sets_p, ways_p);
  bp_fe_icache_lce_metadata_mem_pkt_s metadata_mem_pkt_lo;

  bp_fe_lce_cmd_state_e state_r, state_n;

  assign lce_resp_o         = lce_resp_lo;
  assign lce_data_resp_o    = lce_data_resp_lo;
  assign lce_tr_resp_o      = lce_tr_resp_lo;
  assign data_mem_pkt_o     = data_mem_pkt_lo;
  assign tag_mem_pkt_o      = tag_mem_pkt_lo;
  assign metadata_mem_pkt_o = metadata_mem_pkt_lo;
 
  // lce_cmd fsm
  always_comb begin : lce_cmd_fsm
    lce_resp_v_o        = 1'b0;
    lce_cmd_yumi_o      = 1'b0;
    lce_data_resp_v_o   = 1'b0;
    lce_tr_resp_v_o     = 1'b0;

    data_mem_pkt_v_o       = 1'b0;
    tag_mem_pkt_v_o        = 1'b0;
    metadata_mem_pkt_v_o   = 1'b0;

    lce_resp_lo         = '0;
    lce_data_resp_lo    = '0;
    lce_tr_resp_lo      = '0;

    data_mem_pkt_lo        = '0;
    tag_mem_pkt_lo         = '0;
    metadata_mem_pkt_v_o   = '0;

    lce_ready_o             = (state_r != e_lce_cmd_reset);
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
      e_lce_cmd_ready: begin
        // Casting because these enums are different types, although they should be synchronized
        if (lce_cmd_li.msg_type == bp_cce_lce_cmd_type_e'(e_lce_cmd_transfer_tmp)) begin
          data_mem_pkt_lo.index  = lce_cmd_li.addr[lg_data_mask_width_lp
                                                       +lg_block_size_in_bytes_lp
                                                       +:lg_lce_sets_lp];
          data_mem_pkt_lo.way_id = lce_cmd_li.way_id;
          data_mem_pkt_lo.we     = 1'b0;
          data_mem_pkt_v_o       = lce_cmd_v_i;
          state_n                = data_mem_pkt_yumi_i ? e_lce_cmd_transfer_tmp : e_lce_cmd_ready;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_writeback) begin
          lce_data_resp_lo.src_id   = id_i;
          lce_data_resp_lo.dst_id   = lce_cmd_li.src_id;
          lce_data_resp_lo.msg_type = e_lce_resp_null_wb;
          lce_data_resp_lo.addr     = lce_cmd_li.addr;
          lce_data_resp_v_o         = lce_cmd_v_i;
          lce_cmd_yumi_o            = lce_data_resp_ready_i & lce_data_resp_v_o;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_tag) begin
          tag_mem_pkt_lo.index  = lce_cmd_li.addr[lg_data_mask_width_lp
                                                      +lg_block_size_in_bytes_lp
                                                      +:lg_lce_sets_lp];
          tag_mem_pkt_lo.way_id = lce_cmd_li.way_id;
          tag_mem_pkt_lo.state  = lce_cmd_li.state;
          tag_mem_pkt_lo.tag    = lce_cmd_li.addr[(lg_data_mask_width_lp
                                                       +lg_block_size_in_bytes_lp
                                                       +lg_lce_sets_lp)
                                                      +:tag_width_p];
          tag_mem_pkt_lo.opcode = e_tag_mem_set_tag;
          tag_mem_pkt_v_o       = lce_cmd_v_i;
          lce_cmd_yumi_o        = tag_mem_pkt_yumi_i;
          tag_set_o             = tag_mem_pkt_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_set_tag_wakeup) begin
          tag_mem_pkt_lo.index  = lce_cmd_li.addr[lg_data_mask_width_lp
                                                      +lg_block_size_in_bytes_lp
                                                      +:lg_lce_sets_lp];
          tag_mem_pkt_lo.way_id = lce_cmd_li.way_id;
          tag_mem_pkt_lo.state  = lce_cmd_li.state;
          tag_mem_pkt_lo.tag    = lce_cmd_li.addr[(lg_data_mask_width_lp
                                                       +lg_block_size_in_bytes_lp
                                                       +lg_lce_sets_lp)
                                                      +:tag_width_p];
          tag_mem_pkt_lo.opcode = e_tag_mem_set_tag;
          tag_mem_pkt_v_o       = lce_cmd_v_i;
          lce_cmd_yumi_o        = tag_mem_pkt_yumi_i;
          tag_set_wakeup_o      = tag_mem_pkt_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_invalidate_tag) begin
          tag_mem_pkt_lo.index        = lce_cmd_li.addr[lg_data_mask_width_lp
                                                            +lg_block_size_in_bytes_lp
                                                            +:lg_lce_sets_lp];
          tag_mem_pkt_lo.way_id       = lce_cmd_li.way_id;
          tag_mem_pkt_lo.state        = e_VI_I;
          tag_mem_pkt_lo.opcode       = e_tag_mem_ivalidate;
          tag_mem_pkt_v_o             = flag_invalidate_r ? 1'b0 : lce_cmd_v_i;
          flag_invalidate_n           = lce_resp_yumi_i ? 1'b0 : (flag_invalidate_r ? 1'b1 : tag_mem_pkt_yumi_i);

          metadata_mem_pkt_lo.index  = lce_cmd_li.addr[lg_data_mask_width_lp
                                                            +lg_block_size_in_bytes_lp
                                                            +:lg_lce_sets_lp];
          metadata_mem_pkt_lo.way    = lce_cmd_li.way_id;
          metadata_mem_pkt_lo.opcode = e_metadata_mem_set_lru;
          metadata_mem_pkt_v_o       = flag_updated_lru_r
            ? 1'b0
            : flag_invalidate_r | tag_mem_pkt_yumi_i;
          flag_updated_lru_n          = lce_resp_yumi_i
            ? 1'b0
            : flag_updated_lru_r
              ? 1'b1
              : metadata_mem_pkt_yumi_i;

          lce_resp_lo.dst_id   = lce_cmd_li.src_id;
          lce_resp_lo.src_id   = id_i;
          lce_resp_lo.msg_type = e_lce_cce_inv_ack;
          lce_resp_lo.addr     = lce_cmd_li.addr;
          lce_resp_v_o         = (flag_invalidate_r | tag_mem_pkt_yumi_i)
                                      &(flag_updated_lru_r | metadata_mem_pkt_yumi_i);
          lce_cmd_yumi_o       = lce_resp_yumi_i;
         end
      end

      e_lce_cmd_transfer_tmp: begin //Todo: double check
        flag_data_buffered_n       = ~lce_tr_resp_ready_i;
        data_n                     = flag_data_buffered_r ? data_r : data_mem_data_i;
        lce_tr_resp_lo.dst_id  = lce_cmd_li.target;
        lce_tr_resp_lo.src_id  = id_i;
        lce_tr_resp_lo.way_id  = lce_cmd_li.target_way_id;
        lce_tr_resp_lo.addr    = lce_cmd_li.addr;
        lce_tr_resp_lo.data    = flag_data_buffered_r ? data_r : data_mem_data_i;
        lce_cmd_yumi_o         = lce_tr_resp_ready_i;
        lce_tr_resp_v_o        = 1'b1;
        state_n                    = lce_tr_resp_ready_i ? e_lce_cmd_ready : e_lce_cmd_transfer_tmp;
      end

      e_lce_cmd_reset: begin
        if (lce_cmd_li.msg_type == e_lce_cmd_set_clear) begin
          tag_mem_pkt_lo.index        = lce_cmd_li.addr[lg_data_mask_width_lp
                                                            +lg_block_size_in_bytes_lp
                                                            +:lg_lce_sets_lp];
          tag_mem_pkt_lo.state        = e_VI_I;
          tag_mem_pkt_lo.tag          = '0;
          tag_mem_pkt_lo.opcode       = e_tag_mem_set_clear;
          tag_mem_pkt_v_o             = lce_cmd_v_i;
          metadata_mem_pkt_lo.index  = lce_cmd_li.addr[lg_data_mask_width_lp
                                                            +lg_block_size_in_bytes_lp
                                                            +:lg_lce_sets_lp];
          metadata_mem_pkt_lo.opcode = e_metadata_mem_set_clear;
          metadata_mem_pkt_v_o       = lce_cmd_v_i;
          lce_cmd_yumi_o             = tag_mem_pkt_yumi_i;

        end else if (lce_cmd_li.msg_type == e_lce_cmd_sync) begin
          lce_resp_lo.dst_id   = lce_cmd_li.src_id;
          lce_resp_lo.src_id   = id_i;
          lce_resp_lo.msg_type = e_lce_cce_sync_ack;
          // lce_resp_lo.addr is left unfilled for sync_ack
          lce_resp_v_o         = lce_cmd_v_i;
          lce_cmd_yumi_o       = lce_resp_yumi_i;
          syn_ack_cnt_n            = (lce_cmd_v_i & lce_resp_yumi_i) ? (syn_ack_cnt_r + 1) : syn_ack_cnt_r;
          if ((syn_ack_cnt_r == (num_cce_p - 1)) & lce_cmd_v_i & lce_resp_yumi_i) begin
            state_n                = e_lce_cmd_ready;
          end
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
