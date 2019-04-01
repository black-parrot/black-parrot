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
    , parameter paddr_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"

    , localparam block_size_in_words_lp=ways_p
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)

    , localparam cce_id_width_lp=`BSG_SAFE_CLOG2(num_cce_p)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p,num_lce_p,paddr_width_p,ways_p,data_width_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p,num_lce_p,paddr_width_p)

    )
   (input clk_i
    , input reset_i

    , input [lce_id_width_lp-1:0] id_i
 
    , input miss_i
    , input [paddr_width_p-1:0] miss_addr_i
    , input [way_id_width_lp-1:0] lru_way_i
    , output logic cache_miss_o
    , output logic [paddr_width_p-1:0] miss_addr_o
          
    , input tr_data_received_i
    , input cce_data_received_i
    , input set_tag_received_i
    , input set_tag_wakeup_received_i
          
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i
          
    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_yumi_i
   );

  // lce interface
  //
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, ways_p, data_width_p);
  
  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_req_s lce_req;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;
  
  // states 
  bp_fe_lce_req_state_e state_r, state_n;
  logic [paddr_width_p-1:0] miss_addr_r, miss_addr_n;
  logic tr_data_received_r, tr_data_received_n, tr_data_received;
  logic cce_data_received_r, cce_data_received_n, cce_data_received;
  logic set_tag_received_r, set_tag_received_n, set_tag_received;
  logic [way_id_width_lp-1:0] lru_way_r, lru_way_n;
  logic lru_flopped_r, lru_flopped_n;


  if (num_cce_p == 1) begin
    // This part of the code is written using zero_r register to overcome a bug in vcs 2017
    logic zero_r;
    always_ff @ (posedge clk_i) begin
      zero_r <= 1'b0; 
    end
    assign lce_resp.dst_id = zero_r;
    assign lce_req.dst_id = zero_r;
  end
  else begin
    assign lce_resp.dst_id = miss_addr_r[block_offset_width_lp+:cce_id_width_lp];
    assign lce_req.dst_id = miss_addr_r[block_offset_width_lp+:cce_id_width_lp];
  end

  assign miss_addr_o = miss_addr_r;
   
  // lce_req fsm
  always_comb begin

    state_n               = state_r;
    miss_addr_n           = miss_addr_r;
    tr_data_received_n    = tr_data_received_r;
    cce_data_received_n   = cce_data_received_r;
    set_tag_received_n             = set_tag_received_r;
    lru_way_n             = lru_way_r;
    lru_flopped_n         = lru_flopped_r;

    tr_data_received      = tr_data_received_r | tr_data_received_i;
    cce_data_received     = cce_data_received_r | cce_data_received_i;
    set_tag_received      = set_tag_received_r | set_tag_received_i;

    lce_req.src_id        = id_i;
    lce_req.non_exclusive = e_lce_req_not_excl; 
    lce_req.non_cacheable = e_lce_req_cacheable; 
    lce_req.nc_size       = e_lce_nc_req_1; 
    lce_req.msg_type      = e_lce_req_type_rd;
    lce_req.addr          = miss_addr_r;
    lce_req.lru_dirty     = e_lce_req_lru_clean;
    lce_req.lru_way_id = lru_flopped_r
      ? lru_way_r
      : lru_way_i;
    lce_req.data          = '0;
    lce_req_v_o           = 1'b0;

    lce_resp.src_id       = id_i;
    lce_resp.msg_type     = e_lce_cce_tr_ack;
    lce_resp.addr         = miss_addr_r;
    lce_resp_v_o          = 1'b0;
  
    cache_miss_o = 1'b0;
     
    case (state_r)
      e_lce_req_ready: begin
        cache_miss_o = miss_i;
        if (miss_i) begin
          miss_addr_n = miss_addr_i;
          tr_data_received_n = 1'b0;
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;
          lru_flopped_n = 1'b0;
          state_n = e_lce_req_send_miss_req;
        end
      end

      e_lce_req_send_miss_req: begin
        lru_flopped_n = 1'b1;
        lru_way_n = lru_flopped_r ? lru_way_r : lru_way_i;

        lce_req_v_o           = 1'b1;
        cache_miss_o          = 1'b1;
        state_n = lce_req_ready_i
          ? e_lce_req_sleep 
          : e_lce_req_send_miss_req;
      end

      e_lce_req_sleep: begin
        tr_data_received_n = tr_data_received_i ? 1'b1 : tr_data_received_r;
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;
        set_tag_received_n = set_tag_received_i ? 1'b1 : set_tag_received_r;

        cache_miss_o = 1'b1;
        state_n = set_tag_wakeup_received_i
          ? e_lce_req_ready
          : (set_tag_received
            ? (tr_data_received
              ? e_lce_req_send_ack_tr
              : (cce_data_received ? e_lce_req_send_coh_ack : e_lce_req_sleep))
            : e_lce_req_sleep);
      end

      e_lce_req_send_ack_tr: begin
        lce_resp_v_o = 1'b1;
        lce_resp.msg_type = e_lce_cce_coh_ack;

        cache_miss_o = 1'b1;
        state_n = lce_resp_yumi_i
          ? e_lce_req_ready
          : e_lce_req_send_ack_tr;
      end

      e_lce_req_send_coh_ack: begin
        lce_resp_v_o = 1'b1;
        lce_resp.msg_type = e_lce_cce_coh_ack;
        cache_miss_o = 1'b1;
        state_n = lce_resp_yumi_i
          ? e_lce_req_ready
          : e_lce_req_send_coh_ack;
      end
  
      // should never get in this state.
      default: begin
        state_n = e_lce_req_ready;
      end
    endcase
  end

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_lce_req_ready;
      lru_flopped_r        <= 1'b0;
      tr_data_received_r   <= 1'b0;
      cce_data_received_r  <= 1'b0;
      set_tag_received_r            <= 1'b0;
    end else begin
      state_r              <= state_n;
      miss_addr_r          <= miss_addr_n;
      tr_data_received_r   <= tr_data_received_n;
      cce_data_received_r  <= cce_data_received_n;
      set_tag_received_r   <= set_tag_received_n;
      lru_way_r            <= lru_way_n;
      lru_flopped_r        <= lru_flopped_r;
    end
  end

endmodule
