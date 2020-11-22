/**
 *  mock_cce.v
 *  @Tommy's code with modifications
 */

module mock_cce
  import bp_common_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter eaddr_width_p="inv" 

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
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_lp, ways_p)
    ,parameter cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p)
   
    ,parameter rom_addr_width_lp=eaddr_width_p
    ,parameter rom_data_width_lp=ways_p*data_width_p
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

    ,output logic [rom_addr_width_lp-1:0] rom_addr_o
    ,input logic [rom_data_width_lp-1:0] rom_data_i
  );

  // casting structs
  //
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, addr_width_lp, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, addr_width_lp);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p);
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, addr_width_lp, ways_p);

  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_cce_resp_s lce_resp;
  bp_cce_lce_data_cmd_s lce_data_cmd;
  bp_lce_cce_req_s lce_req;
   
  assign lce_cmd_o = lce_cmd;
  assign lce_resp = lce_resp_i;
  assign lce_data_cmd_o = lce_data_cmd;
  assign lce_req = lce_req_i;

  assign rom_addr_o   = lce_req.addr >>> 6;
  
  // states
  //
  typedef enum logic [3:0] {
    e_set_clear
    ,e_send_sync
    ,e_wait_sync
    ,e_sleep
    ,e_set_tag_wakeup
    ,e_send_invalidate
    ,e_send_tr_req
    ,e_set_tag
    ,e_wait_tr_ack
    ,e_done
  } mock_cce_state_e;

  mock_cce_state_e state_r, state_n;
  logic [lg_sets_lp-1:0]    set_clear_count_r, set_clear_count_n;
  logic [lg_sets_lp-1:0]    send_sync_count_r, send_sync_count_n;
  logic [addr_width_lp-1:0] addr_r, addr_n;
  logic [lg_ways_lp-1:0]    way_r, way_n;
  logic [lg_sets_lp-1:0]    miss_resp_count_r, miss_resp_count_n;
  logic [addr_width_lp-1:0] addr_prev_r, addr_prev_n;
  logic [addr_width_lp-1:0] way_prev_r, way_prev_n;
  logic                     wait_inv_ack_r, wait_inv_ack_n;

  always_comb begin
    lce_req_ready_o = 0;
    lce_resp_ready_o = 0;
    lce_cmd = '0;
    lce_data_cmd = '0;
    lce_cmd_v_o = 0;
    lce_data_cmd = '0;
    lce_data_cmd_v_o = 0;
    lce_data_resp_ready_o = 0;
    done_o = 1'b0;
    send_sync_count_n = send_sync_count_r;
    set_clear_count_n = set_clear_count_r;
    miss_resp_count_n = miss_resp_count_r;
    addr_prev_n       = addr_prev_r;
    way_prev_n        = way_prev_r;
    wait_inv_ack_n    = wait_inv_ack_r;

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
        send_sync_count_n = lce_cmd_yumi_i
          ? send_sync_count_r + 1
          : send_sync_count_r;
        state_n = lce_cmd_yumi_i
          ? e_wait_sync
          : e_send_sync;
      end

      e_wait_sync: begin
        lce_resp_ready_o = lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_sync_ack);
        state_n = lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_sync_ack)
          ? (send_sync_count_r == num_cce_p)
            ? e_sleep
            : e_send_sync
          : e_wait_sync;
      end
      
      e_sleep: begin
        lce_req_ready_o = 1'b1;
        lce_data_cmd.dst_id = lce_req.src_id;
        lce_data_cmd.msg_type = e_lce_req_type_rd;
        lce_data_cmd.way_id = lce_req.lru_way_id;
        lce_data_cmd.addr = lce_req.addr;
        //lce_data_cmd.data = {ways_p{42'b0,lce_req.addr}};
        lce_data_cmd.data = rom_data_i;
        lce_data_cmd_v_o = lce_req_v_i;
        addr_n = lce_req.addr;
        way_n = lce_req.lru_way_id;
        state_n = lce_req_v_i
          //? (miss_resp_count_r ==  ways_p - 1)
          //  ? e_send_invalidate
          ? e_set_tag_wakeup
          : e_sleep;
      end

      e_set_tag_wakeup: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.msg_type = e_lce_cmd_set_tag_wakeup;
        lce_cmd.addr = addr_r;
        lce_cmd.way_id = way_r;
        lce_cmd.state = e_VI_V;
        miss_resp_count_n = miss_resp_count_r + 1;
        addr_prev_n = addr_r;
        way_prev_n = way_r;
        state_n = lce_cmd_yumi_i
          ? e_sleep
          : e_set_tag_wakeup;
      end

      e_send_invalidate: begin
        wait_inv_ack_n = 1'b1;
        lce_cmd_v_o = ~wait_inv_ack_r;
        lce_cmd.msg_type = e_lce_cmd_invalidate_tag;
        lce_cmd.addr = addr_prev_r;
        lce_cmd.way_id = way_prev_r;
        lce_cmd.state = e_VI_I;
        lce_resp_ready_o = lce_cmd_yumi_i & lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_inv_ack);
        miss_resp_count_n = '0;
        state_n = lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_inv_ack)
          ? e_send_tr_req
          : e_send_invalidate;
      end

      e_send_tr_req: begin
        lce_cmd_v_o = 1'b1;
        lce_cmd.msg_type = e_lce_cmd_transfer;
        lce_cmd.addr = addr_prev_r;
        lce_cmd.way_id = way_prev_r;
        lce_cmd.target = addr_r;
        lce_cmd.target_way_id = way_r;
        state_n = lce_cmd_yumi_i
          ? e_set_tag
          : e_send_tr_req;   
      end

     e_set_tag: begin
       lce_cmd_v_o = 1'b1;
        lce_cmd.msg_type = e_lce_cmd_set_tag;
        lce_cmd.addr = addr_r;
        lce_cmd.way_id = way_r;
        lce_cmd.state = e_VI_V;
        state_n = lce_cmd_yumi_i
          ? e_wait_tr_ack
          : e_set_tag;
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
      send_sync_count_r <= '0;
      addr_r            <= '0;
      way_r             <= '0;
      miss_resp_count_r <= '0;
      addr_prev_r       <= '0;
      way_prev_r       <= '0;
      wait_inv_ack_r   <= 1'b0;
    end
    else begin
      state_r <= state_n;
      set_clear_count_r <= set_clear_count_n;
      send_sync_count_r <= send_sync_count_n;
      addr_r            <= addr_n;
      way_r             <= way_n;
      miss_resp_count_r <= miss_resp_count_n;
      addr_prev_r       <= addr_prev_n;
      way_prev_r        <= way_prev_n;
      wait_inv_ack_r    <= wait_inv_ack_n;
    end
  end

endmodule
