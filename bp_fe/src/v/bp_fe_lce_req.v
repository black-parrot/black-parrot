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
  import bp_common_aviary_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_fe_tag_widths(lce_assoc_p, lce_sets_p, lce_id_width_p, cce_id_width_p, dword_width_p, paddr_width_p)
   `declare_bp_fe_lce_widths(lce_assoc_p, lce_sets_p, tag_width_lp, cce_block_width_p)
   `declare_bp_cache_miss_widths(cce_block_width_p, lce_assoc_p, paddr_width_p)
  )
   (input clk_i
    , input reset_i

    , input [lce_id_width_p-1:0] lce_id_i
 
    , input [bp_cache_miss_width_lp-1:0] cache_miss_i
    , input cache_miss_v_i
    , output logic cache_miss_ready_o

    , output logic cache_miss_o
    , output logic [paddr_width_p-1:0] miss_addr_o
          
    , input cce_data_received_i
    , input uncached_data_received_i
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

  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);
  `declare_bp_cache_miss_s(cce_block_width_p, lce_assoc_p, paddr_width_p);  

  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_req_s lce_req;
  bp_cache_miss_s cache_miss_cast_li;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;

  assign cache_miss_cast_li = cache_miss_i;
  
  // states 
  bp_fe_lce_req_state_e state_r, state_n;
  logic [paddr_width_p-1:0] miss_addr_r, miss_addr_n;
  logic cce_data_received_r, cce_data_received_n, cce_data_received;
  logic set_tag_received_r, set_tag_received_n, set_tag_received;
  logic [way_id_width_lp-1:0] lru_way_r, lru_way_n;
  logic lru_flopped_r, lru_flopped_n;

  assign miss_addr_o = miss_addr_r;
   
  logic [cce_id_width_p-1:0] req_cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   req_map
    (.paddr_i(lce_req.addr)

     ,.cce_id_o(req_cce_id_lo)
     );

  logic [cce_id_width_p-1:0] resp_cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   resp_map
    (.paddr_i(lce_resp.addr)

     ,.cce_id_o(resp_cce_id_lo)
     );

  // lce_req fsm
  always_comb begin

    state_n               = state_r;
    miss_addr_n           = miss_addr_r;
    cce_data_received_n   = cce_data_received_r;
    set_tag_received_n             = set_tag_received_r;
    lru_way_n             = lru_way_r;
    lru_flopped_n         = lru_flopped_r;

    cce_data_received     = cce_data_received_r | cce_data_received_i;
    set_tag_received      = set_tag_received_r | set_tag_received_i;

    lce_req_v_o           = 1'b0;

    lce_req.dst_id        = req_cce_id_lo;
    lce_req.src_id        = lce_id_i;
    lce_req.msg_type      = e_lce_req_type_rd;
    lce_req.addr          = miss_addr_r;

    lce_req.msg.req.non_exclusive = e_lce_req_non_excl;
    lce_req.msg.req.lru_dirty     = e_lce_req_lru_clean;
    lce_req.msg.req.lru_way_id    = lru_flopped_r
                                    ? lru_way_r
                                    : cache_miss_cast_li.repl_way;
    lce_req.msg.req.pad    = '0;


    lce_resp_v_o          = 1'b0;

    lce_resp.dst_id       = resp_cce_id_lo;
    lce_resp.src_id       = lce_id_i;
    lce_resp.msg_type     = bp_lce_cce_resp_type_e'('0);
    lce_resp.addr         = miss_addr_r;
    lce_resp.data         = '0;
  
    cache_miss_o = 1'b0;
    cache_miss_ready_o = 1'b1;
    
    case (state_r)
      e_lce_req_ready: begin
       cache_miss_ready_o = 1'b1;
       if(cache_miss_v_i) begin
        if (cache_miss_cast_li.msg_type == e_miss_load) begin
          miss_addr_n = cache_miss_cast_li.addr;
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;
          lru_flopped_n = 1'b0;
          state_n = e_lce_req_send_miss_req;
          cache_miss_o = 1'b1;
        end
        else if (cache_miss_cast_li.msg_type == e_uc_load) begin
          miss_addr_n = cache_miss_cast_li.addr;
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;
          lru_flopped_n = 1'b0;
          cache_miss_o = 1'b1;
          state_n = e_lce_req_send_uncached_load_req;
        end
       end
      end

      e_lce_req_send_miss_req: begin
        lru_flopped_n = 1'b1;
        lru_way_n = lru_flopped_r ? lru_way_r : cache_miss_cast_li.repl_way;

        lce_req_v_o           = 1'b1;
        cache_miss_o          = 1'b1;
        cache_miss_ready_o    = 1'b0;
        state_n = lce_req_ready_i
          ? e_lce_req_sleep 
          : e_lce_req_send_miss_req;
      end

      e_lce_req_send_uncached_load_req: begin
        lce_req_v_o = 1'b1;
        cache_miss_o = 1'b1;
        cache_miss_ready_o = 1'b0;

        lce_req.msg_type = e_lce_req_type_uc_rd;
        // TODO: this may need to change depending on what the LCE and CCE behavior spec is
        // In order for the uncached load to replay successfully and extract the correct
        // 32-bits, we fetch the aligned 64-bits containing the desired 32-bits.
        // Zero out the byte offset bits so the address is 64-bit aligned.
        lce_req.addr = {miss_addr_r[paddr_width_p-1:byte_offset_width_lp]
                        , {byte_offset_width_lp{1'b0}}};
        lce_req.msg.uc_req.uc_size = e_lce_uc_req_8;
        lce_req.msg.uc_req.data = '0;

        state_n = lce_req_ready_i
          ? e_lce_req_sleep 
          : e_lce_req_send_uncached_load_req;
      end

      e_lce_req_sleep: begin
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;
        set_tag_received_n = set_tag_received_i ? 1'b1 : set_tag_received_r;

        cache_miss_o = 1'b1;
        cache_miss_ready_o = 1'b0;

        if (set_tag_wakeup_received_i) begin
          state_n = e_lce_req_send_coh_ack;
        end
        else if (uncached_data_received_i) begin
          state_n = e_lce_req_ready;
        end
        else if (set_tag_received) begin
          if (cce_data_received) begin
            state_n = e_lce_req_send_coh_ack;
          end
          else begin
            state_n = e_lce_req_sleep;
          end
        end
        else begin
          state_n = e_lce_req_sleep;
        end
      end

      e_lce_req_send_coh_ack: begin
        lce_resp_v_o = 1'b1;
        lce_resp.msg_type = e_lce_cce_coh_ack;
        cache_miss_o = 1'b1;
        cache_miss_ready_o = 1'b0;
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

  //synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_lce_req_ready;
      lru_flopped_r        <= 1'b0;
      cce_data_received_r  <= 1'b0;
      set_tag_received_r   <= 1'b0;
    end else begin
      state_r              <= state_n;
      miss_addr_r          <= miss_addr_n;
      cce_data_received_r  <= cce_data_received_n;
      set_tag_received_r   <= set_tag_received_n;
      lru_way_r            <= lru_way_n;
      lru_flopped_r        <= lru_flopped_n;
    end
  end

endmodule
