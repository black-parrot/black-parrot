/**
 *
 * Name:
 *   bp_fe_lce_req.v
 *
 * Description:
 *   To	be updated
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
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache)
   
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(icache_assoc_p)
   , localparam block_size_in_words_lp=icache_assoc_p
   , localparam bank_width_lp = icache_block_width_p / icache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp=(bank_width_lp >> 3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp >> 3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(icache_sets_p)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
   
   , parameter timeout_max_limit_p=4
  )
   (input clk_i
    , input reset_i

    , input [lce_id_width_p-1:0] lce_id_i
 
    , input [icache_req_width_lp-1:0] cache_req_i
    , input cache_req_v_i
    , output logic cache_req_ready_o
    , input [icache_req_metadata_width_lp-1:0] cache_req_metadata_i
    , input cache_req_metadata_v_i

    , output logic [paddr_width_p-1:0] miss_addr_o
          
    , input cce_data_received_i
    , input uncached_data_received_i
    , input set_tag_received_i
    , input set_tag_wakeup_received_i

    , input coherence_blocked_i
    , input cmd_ready_i
          
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i
          
    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_yumi_i
   );

  // lce interface

  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache);

  bp_lce_cce_resp_s lce_resp;
  bp_lce_cce_req_s lce_req;
  bp_icache_req_s cache_req_cast_li;
  bp_icache_req_metadata_s cache_req_metadata_cast_li;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;

  assign cache_req_cast_li = cache_req_i;
  assign cache_req_metadata_cast_li = cache_req_metadata_i;

  logic cache_req_v_r;
  always_ff @(posedge clk_i)
    cache_req_v_r <= cache_req_v_i;

  bp_icache_req_metadata_s cache_req_metadata_r;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_icache_req_metadata_s)))
   metadata_reg
    (.clk_i(clk_i)

     ,.en_i(cache_req_v_r)
     ,.data_i(cache_req_metadata_i)
     ,.data_o(cache_req_metadata_r)
     );
  
  logic cache_req_metadata_v_r;
  bsg_dff_en_bypass
   #(.width_p(1))
   metadata_v_reg
    (.clk_i(clk_i)

     ,.en_i(cache_req_v_i | cache_req_metadata_v_i)
     ,.data_i(cache_req_metadata_v_i)
     ,.data_o(cache_req_metadata_v_r)
     );

  // states
  typedef enum logic [2:0] {
    e_lce_req_ready
  , e_lce_req_send_miss_req
  , e_lce_req_send_ack_tr
  , e_lce_req_send_coh_ack
  , e_lce_req_send_uncached_load_req
  , e_lce_req_sleep
  } bp_fe_lce_req_state_e;

  bp_fe_lce_req_state_e state_r, state_n;
  logic [paddr_width_p-1:0] miss_addr_r, miss_addr_n;
  logic cce_data_received_r, cce_data_received_n, cce_data_received;
  logic set_tag_received_r, set_tag_received_n, set_tag_received;
  logic cache_req_ready;

  assign miss_addr_o = miss_addr_r;
   
  logic [cce_id_width_p-1:0] req_cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   req_map
    (.paddr_i(lce_req.header.addr)

     ,.cce_id_o(req_cce_id_lo)
     );

  logic [cce_id_width_p-1:0] resp_cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   resp_map
    (.paddr_i(lce_resp.header.addr)

     ,.cce_id_o(resp_cce_id_lo)
     );

  // lce_req fsm
  always_comb begin

    state_n               = state_r;
    miss_addr_n           = miss_addr_r;
    cce_data_received_n   = cce_data_received_r;
    set_tag_received_n    = set_tag_received_r;

    cce_data_received     = cce_data_received_r | cce_data_received_i;
    set_tag_received      = set_tag_received_r | set_tag_received_i;

    lce_req_v_o           = 1'b0;

    lce_req = '0;
    lce_req.header.dst_id        = req_cce_id_lo;
    lce_req.header.src_id        = lce_id_i;
    lce_req.header.msg_type      = e_lce_req_type_rd;
    lce_req.header.addr          = miss_addr_r;
    lce_req.header.non_exclusive = e_lce_req_non_excl;
    lce_req.header.lru_dirty     = e_lce_req_lru_clean;
    lce_req.header.lru_way_id    = lce_assoc_p'(cache_req_metadata_r.repl_way);


    lce_resp_v_o          = 1'b0;

    lce_resp = '0;
    lce_resp.header.dst_id       = resp_cce_id_lo;
    lce_resp.header.src_id       = lce_id_i;
    lce_resp.header.msg_type     = bp_lce_cce_resp_type_e'('0);
    lce_resp.header.addr         = miss_addr_r;
    lce_resp.data         = '0;
  
    cache_req_ready = 1'b1;
    
    case (state_r)
      e_lce_req_ready: begin
       cache_req_ready = 1'b1;

       if(cache_req_v_i) begin
        if (cache_req_cast_li.msg_type == e_miss_load) begin
          miss_addr_n = cache_req_cast_li.addr;
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;
          state_n = e_lce_req_send_miss_req;
        end
        else if (cache_req_cast_li.msg_type == e_uc_load) begin
          miss_addr_n = cache_req_cast_li.addr;
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;
          state_n = e_lce_req_send_uncached_load_req;
        end
       end
      end

      e_lce_req_send_miss_req: begin
        lce_req_v_o        = lce_req_ready_i & cache_req_metadata_v_r;
        
        cache_req_ready    = 1'b0;
        
        state_n = lce_req_v_o
          ? e_lce_req_sleep 
          : e_lce_req_send_miss_req;
      end

      e_lce_req_send_uncached_load_req: begin
        lce_req_v_o = lce_req_ready_i & cache_req_metadata_v_r;
        cache_req_ready = 1'b0;

        lce_req.header.msg_type = e_lce_req_type_uc_rd;
        // TODO: this may need to change depending on what the LCE and CCE behavior spec is
        // In order for the uncached load to replay successfully and extract the correct
        // 32-bits, we fetch the aligned 64-bits containing the desired 32-bits.
        // Zero out the byte offset bits so the address is 64-bit aligned.
        lce_req.header.addr = {miss_addr_r[paddr_width_p-1:byte_offset_width_lp]
                               , {byte_offset_width_lp{1'b0}}};
        lce_req.header.uc_size = e_lce_uc_req_8;
        lce_req.data = '0;

        state_n = lce_req_v_o
          ? e_lce_req_sleep 
          : e_lce_req_send_uncached_load_req;
      end

      e_lce_req_sleep: begin
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;
        set_tag_received_n = set_tag_received_i ? 1'b1 : set_tag_received_r;

        cache_req_ready = 1'b0;

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
        cache_req_ready = 1'b0;

        lce_resp.header.msg_type = e_lce_cce_coh_ack;
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

  // LCE timeout logic
  // LCE can read/write to data_mem, tag_mem, and stat_mem, when they are free (e.g. tl stage in dcache is not accessing them).
  // In order to prevent LCE taking too much time to process incoming coherency requests,
  // there is a timer, which counts up whenever LCE needs to access mem, but have not been able to.
  // when the timer reaches max, it deasserts ready_o of dcache for one cycle, allowing it to access mem
  // by creating a free slot.
  logic [`BSG_SAFE_CLOG2(timeout_max_limit_p+1)-1:0] timeout_cnt_r;

  bsg_counter_clear_up
   #(.max_val_p(timeout_max_limit_p)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   timeout_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(~coherence_blocked_i)
     ,.up_i(coherence_blocked_i)
     ,.count_o(timeout_cnt_r)
     );
  
  wire timeout = (timeout_cnt_r == timeout_max_limit_p);

  assign cache_req_ready_o = cmd_ready_i & ~timeout & cache_req_ready;

  //synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r              <= e_lce_req_ready;
      miss_addr_r          <= '0;
      cce_data_received_r  <= 1'b0;
      set_tag_received_r   <= 1'b0;
    end else begin
      state_r              <= state_n;
      miss_addr_r          <= miss_addr_n;
      cce_data_received_r  <= cce_data_received_n;
      set_tag_received_r   <= set_tag_received_n;
    end
  end

endmodule
