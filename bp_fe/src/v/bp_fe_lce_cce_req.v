/**
 *
 * Name:
 *   bp_fe_lce_req.v
 *
 * Description:
 *   To	be updated
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


module bp_fe_lce_req
  import bp_common_pkg::*;
  import bp_fe_icache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter lce_addr_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter lce_sets_p="inv"
    , parameter ways_p="inv"
    , parameter block_size_in_bytes_p="inv"

    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)

    , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , parameter lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)

    , parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                           ,num_lce_p
                                                           ,lce_addr_width_p
                                                           ,ways_p
                                                          )
    , parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    )
   (input                                      clk_i
    , input                                    reset_i

    , input [lce_id_width_lp-1:0]              id_i
 
    , input                                    miss_i
    , input [lce_addr_width_p-1:0]             miss_addr_i
    , input [lg_ways_lp-1:0]                   lru_way_i
    , output logic                             cache_miss_o
          
    , input                                    tr_received_i
    , input                                    cce_data_received_i
    , input                                    tag_set_i
    , input                                    tag_set_wakeup_i
          
    , output logic [lce_cce_req_width_lp-1:0]  lce_req_o
    , output logic                             lce_req_v_o
    , input                                    lce_req_ready_i
          
    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic                             lce_resp_v_o
    , input                                    lce_resp_yumi_i
   );

  bp_fe_lce_req_state_e                   state_r, state_n;
  logic [lce_addr_width_p-1:0]                miss_addr_r, miss_addr_n;
  logic                                       tr_received_r, tr_received_n, tr_received;
  logic                                       cce_data_received_r, cce_data_received_n, cce_data_received;
  logic                                       tag_set_r, tag_set_n, tag_set;
  logic [lg_ways_lp-1:0]                      lru_way_r, lru_way_n;

  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  bp_lce_cce_resp_s lce_resp_lo;

  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p);
  bp_lce_cce_req_s lce_req_lo;

  assign lce_req_o  = lce_req_lo;
  assign lce_resp_o = lce_resp_lo;

  // This part of the code is written using zero_r register to overcome a bug in vcs 2017
  if (num_cce_p == 1) begin
    logic zero_r;
    always_ff @ (posedge clk_i) begin
      zero_r <= 1'b0; 
    end
    assign lce_resp_lo.dst_id = zero_r;
    assign lce_req_lo.dst_id  = zero_r;
  end
  else begin
    assign lce_resp_lo.dst_id = miss_addr_r[lg_data_mask_width_lp
                                                +lg_block_size_in_bytes_lp
                                                +:lg_num_cce_lp];
    assign lce_req_lo.dst_id  = miss_addr_r[lg_data_mask_width_lp
                                                +lg_block_size_in_bytes_lp
                                                +:lg_num_cce_lp];
  end
   
  // lce_req fsm
  always_comb begin : lce_req_fsm

    state_n               = state_r;
    miss_addr_n           = miss_addr_r;
    tr_received_n         = tr_received_r;
    cce_data_received_n   = cce_data_received_r;
    tag_set_n             = tag_set_r;
    lru_way_n             = lru_way_r;

    tr_received           = tr_received_r | tr_received_i;
    cce_data_received     = cce_data_received_r | cce_data_received_i;
    tag_set               = tag_set_r | tag_set_i;

    lce_req_lo.src_id        = (lg_num_lce_lp)'(id_i);
    lce_req_lo.non_exclusive = e_lce_req_excl;
    lce_req_lo.msg_type      = e_lce_req_type_rd;
    lce_req_lo.addr          = miss_addr_r;
    lce_req_lo.lru_way_id    = lru_way_r;
    lce_req_lo.lru_dirty     = e_lce_req_lru_clean;
    lce_req_v_o              = 1'b0;

    lce_resp_lo.src_id       = id_i;
    lce_resp_lo.msg_type     = e_lce_cce_tr_ack;
    lce_resp_lo.addr         = miss_addr_r;
    lce_resp_v_o             = 1'b0;
     
    case (state_r)
      e_lce_req_ready: begin
        cache_miss_o          = miss_i;
        if (miss_i) begin
          miss_addr_n         = miss_addr_i;
          lru_way_n           = lru_way_i;
          tr_received_n       = 1'b0;
          cce_data_received_n = 1'b0;
          tag_set_n           = 1'b0;
          state_n             = e_lce_req_send_miss_req ;
        end
      end

      e_lce_req_send_miss_req: begin
        cache_miss_o                 = 1'b1;
        lce_req_v_o              = 1'b1;
        state_n                      = lce_req_ready_i ? e_lce_req_sleep : e_lce_req_send_miss_req;
      end

      e_lce_req_sleep: begin
        cache_miss_o = 1'b1;
        tr_received_n = tr_received_i ? 1'b1 : tr_received_r;
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;
        tag_set_n = tag_set_i ? 1'b1 : tag_set_r;
        state_n = tag_set_wakeup_i
          ? e_lce_req_ready
          : (tag_set
            ? (tr_received
              ? e_lce_req_send_ack_tr
              : (cce_data_received ? e_lce_req_send_coh_ack : e_lce_req_sleep))
            : e_lce_req_sleep);
      end

      e_lce_req_send_ack_tr: begin
        cache_miss_o             = 1'b1;
        lce_resp_v_o         = 1'b1;
        state_n                  = lce_resp_yumi_i ? e_lce_req_ready : e_lce_req_send_ack_tr;
      end

      e_lce_req_send_coh_ack: begin
        cache_miss_o             = 1'b1;
        lce_resp_v_o         = 1'b1;
        lce_resp_lo.msg_type = e_lce_cce_coh_ack;
        state_n                  = lce_resp_yumi_i ? e_lce_req_ready : e_lce_req_send_coh_ack;
      end

      default: begin

      end
    endcase
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_lce_req_ready;
      miss_addr_r          <= '0;
      tr_received_r        <= 1'b0;
      cce_data_received_r  <= 1'b0;
      tag_set_r            <= 1'b0;
      lru_way_r            <= '0;
    end else begin
      state_r              <= state_n;
      miss_addr_r          <= miss_addr_n;
      tr_received_r        <= tr_received_n;
      cce_data_received_r  <= cce_data_received_n;
      tag_set_r            <= tag_set_n;
      lru_way_r            <= lru_way_n;
    end
  end
endmodule
