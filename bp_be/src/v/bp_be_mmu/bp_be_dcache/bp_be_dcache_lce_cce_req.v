/**
 *  bp_be_dcache_lce_cce_req.v
 *
 *  @author tommy
 */

`include "bp_common_me_if.vh"

module bp_be_dcache_lce_cce_req
  import bp_be_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter lce_addr_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter ways_p="inv"
  
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
  
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    ,parameter lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)

    ,parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_p, ways_p)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_p)

    ,localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
  )
  (
    input clk_i
    ,input reset_i

    ,input logic[lce_id_width_lp-1:0] id_i

    ,input load_miss_i
    ,input store_miss_i
    ,input [lce_addr_width_p-1:0] miss_addr_i
    ,input [lg_ways_lp-1:0] lru_way_i
    ,input [ways_p-1:0] dirty_i
    ,output logic cache_miss_o

    ,input tr_received_i
    ,input cce_data_received_i
    ,input tag_set_i
    ,input tag_set_wakeup_i

    ,output logic [lce_cce_req_width_lp-1:0] lce_cce_req_o
    ,output logic lce_cce_req_v_o
    ,input lce_cce_req_ready_i

    ,output logic [lce_cce_resp_width_lp-1:0] lce_cce_resp_o
    ,output logic lce_cce_resp_v_o
    ,input lce_cce_resp_yumi_i
  );

  // casting struct
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, lce_addr_width_p, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, lce_addr_width_p);
  bp_lce_cce_req_s lce_cce_req;
  bp_lce_cce_resp_s lce_cce_resp;
  assign lce_cce_req_o = lce_cce_req;
  assign lce_cce_resp_o = lce_cce_resp;

  // states
  //
  typedef enum logic [2:0] {
    e_lce_cce_req_ready
    ,e_lce_cce_req_send
    ,e_lce_cce_req_send_tr_ack
    ,e_lce_cce_req_send_coh_ack
    ,e_lce_cce_req_sleep
  } lce_cce_req_state_e; 

  lce_cce_req_state_e state_r, state_n;
  logic load_not_store_r, load_not_store_n;
  logic [lg_ways_lp-1:0] lru_way_r, lru_way_n;
  logic dirty_r, dirty_n;
  logic [lce_addr_width_p-1:0] miss_addr_r, miss_addr_n;
  logic dirty_lru_flopped_r, dirty_lru_flopped_n;
  logic missed;

  logic tr_received_r, tr_received_n, tr_received;
  logic cce_data_received_r, cce_data_received_n, cce_data_received;
  logic tag_set_r, tag_set_n, tag_set;

  // comb logic
  //

  if (num_cce_p == 1) begin
    /* TODO: VCS has problems with structs assigned in different comb blocks
    *        Remove when fixed more elegantly*/
    logic zero_r;
    always_ff @(posedge clk_i) begin
        zero_r <= 1'b0;
    end
    assign lce_cce_resp.dst_id = zero_r;
    assign lce_cce_req.dst_id = zero_r;
  end
  else begin
    assign lce_cce_resp.dst_id = miss_addr_r[lg_data_mask_width_lp+lg_ways_lp+:lg_num_cce_lp];
    assign lce_cce_req.dst_id = miss_addr_r[lg_data_mask_width_lp+lg_ways_lp+:lg_num_cce_lp];
  end

  always_comb begin

    missed = load_miss_i | store_miss_i;

    state_n = state_r;
    load_not_store_n = load_not_store_r;
    lru_way_n = lru_way_r;
    dirty_n = dirty_r;
    miss_addr_n = miss_addr_r;
    dirty_lru_flopped_n = dirty_lru_flopped_r;
    
    tr_received_n = tr_received_r;
    cce_data_received_n = cce_data_received_r;
    tag_set_n = tag_set_r;
    tr_received = tr_received_r | tr_received_i;
    cce_data_received = cce_data_received_r | cce_data_received_i;
    tag_set = tag_set_r | tag_set_i;

    lce_cce_req_v_o = 1'b0;
    lce_cce_req.src_id = (lg_num_lce_lp)'(id_i);
    lce_cce_req.non_exclusive = e_lce_req_excl;
    lce_cce_req.msg_type = load_not_store_r ? e_lce_req_type_rd : e_lce_req_type_wr;
    lce_cce_req.addr = miss_addr_r;
    lce_cce_req.lru_way_id = dirty_lru_flopped_r ? lru_way_r : lru_way_i;
    lce_cce_req.lru_dirty = dirty_lru_flopped_r
      ? bp_lce_cce_lru_dirty_e'(dirty_r)
      : bp_lce_cce_lru_dirty_e'(dirty_i[lru_way_i]);

    lce_cce_resp_v_o = 1'b0;
    lce_cce_resp.src_id = (lg_num_lce_lp)'(id_i);
    lce_cce_resp.addr = miss_addr_r;
    lce_cce_resp.msg_type = e_lce_cce_tr_ack;

    case (state_r)
      e_lce_cce_req_ready: begin
        cache_miss_o = missed;
        if (missed) begin
          miss_addr_n = miss_addr_i;
          dirty_lru_flopped_n = 1'b0;
          load_not_store_n = load_miss_i;
          tr_received_n = 1'b0;
          cce_data_received_n = 1'b0;
          tag_set_n = 1'b0;
          state_n = e_lce_cce_req_send;
        end
      end

      e_lce_cce_req_send: begin
        cache_miss_o = 1'b1;

        dirty_lru_flopped_n = 1'b1;
        lru_way_n = dirty_lru_flopped_r ? lru_way_r : lru_way_i;
        dirty_n = dirty_lru_flopped_r ? dirty_r : dirty_i[lru_way_i];

        lce_cce_req_v_o = 1'b1;

        state_n = lce_cce_req_ready_i ? e_lce_cce_req_sleep : e_lce_cce_req_send;
      end

      e_lce_cce_req_sleep: begin
        cache_miss_o = 1'b1;
        tr_received_n = tr_received_i ? 1'b1 : tr_received_r;
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;
        tag_set_n = tag_set_i ? 1'b1 : tag_set_r;

        state_n = tag_set_wakeup_i
          ? e_lce_cce_req_ready
          : (tag_set
            ? (tr_received
              ? e_lce_cce_req_send_tr_ack
              : (cce_data_received ? e_lce_cce_req_send_coh_ack : e_lce_cce_req_sleep))
            : e_lce_cce_req_sleep
          );
      end

      e_lce_cce_req_send_tr_ack: begin
        cache_miss_o = 1'b1;
        lce_cce_resp_v_o = 1'b1;
        state_n = lce_cce_resp_yumi_i
          ? e_lce_cce_req_ready
          : e_lce_cce_req_send_tr_ack;
      end

      e_lce_cce_req_send_coh_ack: begin
        cache_miss_o = 1'b1;
        lce_cce_resp_v_o = 1'b1;
        lce_cce_resp.msg_type = e_lce_cce_coh_ack;
        state_n = lce_cce_resp_yumi_i
          ? e_lce_cce_req_ready
          : e_lce_cce_req_send_coh_ack;
      end
    endcase
  end


  // sequential
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_lce_cce_req_ready;
      dirty_lru_flopped_r <= 1'b0;
      tr_received_r <= 1'b0;
      cce_data_received_r <= 1'b0;
      tag_set_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      load_not_store_r <= load_not_store_n;
      lru_way_r <= lru_way_n;
      dirty_r <= dirty_n;
      miss_addr_r <= miss_addr_n;
      dirty_lru_flopped_r <= dirty_lru_flopped_n;
      tr_received_r <= tr_received_n;
      cce_data_received_r <= cce_data_received_n;
      tag_set_r <= tag_set_n;
    end
  end

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (state_r == e_lce_cce_req_ready) begin
      assert(~tr_received_i) else $error("id: %0d, transfer received while no cache miss.", id_i);
      assert(~cce_data_received_i) else $error("id: %0d, data_cmd received while no cache miss.", id_i);
      assert(~tag_set_i) else $error("id: %0d, set_tag_cmd received while no cache miss.", id_i);
      assert(~tag_set_wakeup_i) else $error("id: %0d, set_tag_wakeup_cmd received while no cache miss.", id_i);
    end
  end
  // synopsys translate_on

endmodule
