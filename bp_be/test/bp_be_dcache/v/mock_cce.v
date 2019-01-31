/**
 *  mock_cce.v
 */

module mock_cce
  #(parameter data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"

    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter vaddr_width_lp=(lg_sets_lp+lg_ways_lp+lg_data_mask_width_lp)
    ,parameter addr_width_lp=(vaddr_width_lp+tag_width_p)
    ,parameter lce_data_width_lp=(ways_p*data_width_p)

    ,parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_lp, ways_p)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_lp)
    ,parameter lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp)
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_lp, ways_p, 4)
    ,parameter cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p)
  )
  (
    input clk_i
    ,input reset_i

    ,input [lce_cce_req_width_lp-1:0] lce_req_i
    ,input lce_req_v_i
    ,output logic lce_req_ready_o

    ,input [lce_cce_resp_width_lp-1:0] lce_resp_i
    ,input lce_resp_v_i
    ,output logic lce_resp_ready_o
   
    ,input [lce_cce_data_resp_width_lp-1:0] lce_data_resp_i
    ,input lce_data_resp_v_i
    ,output logic lce_data_resp_ready_o
    
    ,output logic [cce_lce_cmd_width_lp-1:0] lce_cmd_o
    ,output logic lce_cmd_v_o
    ,input lce_cmd_yumi_i

    ,output logic [cce_lce_data_cmd_width_lp-1:0] lce_data_cmd_o
    ,output logic lce_data_cmd_v_o
    ,input lce_data_cmd_yumi_i 

    ,output logic done_o
  );

  // casting structs
  //
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, addr_width_lp, ways_p, 4);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, addr_width_lp);

  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_cce_resp_s lce_resp;

  assign lce_cmd_o = lce_cmd;
  assign lce_resp = lce_resp_i;
  
  // states
  //
  typedef enum logic [2:0] {
    e_set_clear
    ,e_send_sync
    ,e_wait_sync
    ,e_send_set_tag
    ,e_done
  } mock_cce_state_e;

  mock_cce_state_e state_r, state_n;
  logic [lg_sets_lp-1:0] set_clear_count_r, set_clear_count_n;
  logic [lg_sets_lp+lg_ways_lp-1:0] set_tag_count_r, set_tag_count_n;


  always_comb begin
    lce_req_ready_o = 0;
    lce_resp_ready_o = 0;
    lce_cmd = '0;
    lce_cmd_v_o = 0;
    lce_data_cmd_o = '0;
    lce_data_cmd_v_o = 0;
    lce_data_resp_ready_o = 0;
    done_o = 1'b0;
    set_tag_count_n = set_tag_count_r;
    set_clear_count_n = set_clear_count_r;

    case (state_r)
      e_set_clear: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.msg_type = e_lce_cmd_set_clear;
        lce_cmd.addr = {{tag_width_p{1'b0}}, set_clear_count_r, {(lg_ways_lp+lg_data_mask_width_lp){1'b0}}};
        set_clear_count_n = lce_cmd_yumi_i 
          ? set_clear_count_r + 1
          : set_clear_count_r;
        state_n = lce_cmd_yumi_i & (set_clear_count_r == sets_p-1)
          ? e_send_sync
          : e_set_clear;
      end

      e_send_sync: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.msg_type = e_lce_cmd_sync;
        state_n = lce_cmd_yumi_i
          ? e_wait_sync
          : e_send_sync;
      end

      e_wait_sync: begin
        lce_resp_ready_o = lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_sync_ack);
        state_n = lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_sync_ack)
          ? e_send_set_tag
          : e_wait_sync;
      end

      e_send_set_tag: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.msg_type = e_lce_cmd_set_tag_wakeup;
        lce_cmd.addr = {{(tag_width_p-lg_ways_lp){1'b0}}, set_tag_count_r[lg_sets_lp+:lg_ways_lp],
          set_tag_count_r[lg_sets_lp-1:0], {(lg_ways_lp+lg_data_mask_width_lp){1'b0}}};
        lce_cmd.way_id = set_tag_count_r[lg_sets_lp+:lg_ways_lp];
        lce_cmd.state = e_MESI_E;
        set_tag_count_n = lce_cmd_yumi_i
          ? set_tag_count_r + 1
          : set_tag_count_r;
        state_n = lce_cmd_yumi_i & (set_tag_count_r == (sets_p*ways_p)-1)
          ? e_done
          : e_send_set_tag;
      end

      e_done: begin
        done_o = 1'b1;
        state_n = e_done;
      end

    endcase
  end



  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_set_clear;
      set_clear_count_r <= '0;
      set_tag_count_r <= '0;
    end
    else begin
      state_r <= state_n;
      set_clear_count_r <= set_clear_count_n;
      set_tag_count_r <= set_tag_count_n;
    end
  end

endmodule
