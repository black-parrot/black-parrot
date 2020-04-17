/**
 *  Name:
 *    bp_be_dcache_lce_req.v
 *
 *  Description:
 *    LCE request handler.
 *
 *    When the miss occurs in dcache, either load_miss_i or store_miss_i is
 *    raised. Also, the address that caused miss (miss_addr_i), and lru_way
 *    and dirty bits are provided.
 *
 *    cache_miss_o is raised immediately, when the miss arrives. It is
 *    asserted until the miss is resolved.
 *
 *    There are multiple ways that a miss can be resolved.
 *    - set_tag_wakeup
 *    - set_tag and data_cmd
 *    - set_tag and transfer
 *
 *    This modules sends out ack to lce_resp channel, depending on how the miss is
 *    resolved.
 */

module bp_be_dcache_lce_req
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)
     
    , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    , localparam block_size_in_words_lp = dcache_assoc_p
    , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
    , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
    , localparam bypass_data_mask_width_lp = (dword_width_p >> 3)
    , localparam data_mem_mask_width_lp = (bank_width_lp >> 3)
    , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
    , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp = (word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp = `BSG_SAFE_CLOG2(dcache_sets_p)
    , localparam ptag_width_lp = (paddr_width_p-bp_page_offset_width_gp)
    , localparam way_id_width_lp = `BSG_SAFE_CLOG2(dcache_assoc_p)

    , parameter timeout_max_limit_p=4

  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_p-1:0] lce_id_i

    , input [dcache_req_width_lp-1:0] cache_req_i
    , input cache_req_v_i
    , output logic cache_req_ready_o
    , input [dcache_req_metadata_width_lp-1:0] cache_req_metadata_i
    , input cache_req_metadata_v_i

    , output logic [paddr_width_p-1:0] miss_addr_o

    , input coherence_blocked_i
    , input cmd_ready_i
    , input credits_ready_i

    , input cce_data_received_i
    , input uncached_data_received_i
    , input set_tag_wakeup_received_i

    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_yumi_i
  );

  // casting struct
  //
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;

  assign lce_req_o = lce_req;
  assign lce_resp_o = lce_resp;

  bp_dcache_req_s cache_req_cast_li;
  bp_dcache_req_metadata_s cache_req_metadata_cast_li;

  assign cache_req_cast_li = cache_req_i;
  assign cache_req_metadata_cast_li = cache_req_metadata_i;

  bp_dcache_req_metadata_s cache_req_metadata_r;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_dcache_req_metadata_s)))
   metadata_reg
    (.clk_i(clk_i)

     ,.en_i(cache_req_metadata_v_i)
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

  // For uncached store buffering
  //

  // states
  //
  enum logic [2:0] {
    e_READY
    ,e_SEND_CACHED_REQ
    ,e_SEND_UNCACHED_LOAD_REQ
    ,e_SEND_COH_ACK
    ,e_SLEEP
  } state_n, state_r;

  wire is_ready = (state_r == e_READY);

  logic load_not_store_r, load_not_store_n;
  logic [paddr_width_p-1:0] miss_addr_r, miss_addr_n;
  logic [1:0] size_op_r, size_op_n;

  logic cce_data_received_r, cce_data_received_n, cce_data_received;

  // comb logic
  //
  assign cce_data_received = cce_data_received_r | cce_data_received_i;
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

  always_comb begin
    state_n = state_r;
    load_not_store_n = load_not_store_r;
    miss_addr_n = miss_addr_r;
    size_op_n = size_op_r;
    
    cce_data_received_n = cce_data_received_r;

    lce_req_v_o = 1'b0;

    lce_req = '0;
    lce_req.header.dst_id = req_cce_id_lo;
    lce_req.header.src_id = lce_id_i;
    lce_req.header.msg_type = e_lce_req_type_rd;
    lce_req.header.addr = miss_addr_r;

    lce_resp_v_o = 1'b0;

    lce_resp = '0;
    lce_resp.header.dst_id = resp_cce_id_lo;
    lce_resp.header.src_id = lce_id_i;
    lce_resp.header.msg_type = bp_lce_cce_resp_type_e'('0);
    lce_resp.header.addr = miss_addr_r;
    lce_resp.data = '0;

    unique case (state_r)

      // READY
      // wait for the cache miss.
      e_READY: begin
        // LR needs priority over regular load miss, otherwise it might get sent out as a regular
        // load miss if the cache block is not in the cache at all.
        // LR misses are sent out as store misses.
      if (cache_req_v_i) begin 
        if (cache_req_cast_li.msg_type == e_miss_store) begin
          miss_addr_n = cache_req_cast_li.addr;
          load_not_store_n = 1'b0; // We force a store miss to upgrade the block to exclusive
          cce_data_received_n = 1'b0;

          state_n = e_SEND_CACHED_REQ;
        end
        else if (cache_req_cast_li.msg_type == e_miss_load | cache_req_cast_li.msg_type == e_miss_store) begin
          miss_addr_n = cache_req_cast_li.addr;
          load_not_store_n = (cache_req_cast_li.msg_type == e_miss_load);
          cce_data_received_n = 1'b0;
 
          state_n = e_SEND_CACHED_REQ;
        end
        else if (cache_req_cast_li.msg_type == e_uc_load) begin
          miss_addr_n = cache_req_cast_li.addr;
          size_op_n = bp_lce_cce_uc_req_size_e'(cache_req_cast_li.size);
          cce_data_received_n = 1'b0;
 
          state_n = e_SEND_UNCACHED_LOAD_REQ;
        end
        else if (cache_req_cast_li.msg_type == e_uc_store) begin
          lce_req_v_o = lce_req_ready_i;

          lce_req.data = cache_req_cast_li.data[dword_width_p-1:0];;
          lce_req.header.uc_size = bp_lce_cce_uc_req_size_e'(cache_req_cast_li.size);
          lce_req.header.addr = cache_req_cast_li.addr;
          lce_req.header.msg_type = e_lce_req_type_uc_wr;
          lce_req.header.src_id = lce_id_i;
          lce_req.header.dst_id = req_cce_id_lo;

          state_n = e_READY;
        end
        else begin
          state_n = e_READY;
        end
       end
      end

      // SEND_CACHED_REQ
      // send out cache miss request to CCE.
      e_SEND_CACHED_REQ: begin
        lce_req_v_o = lce_req_ready_i & cache_req_metadata_v_r;

        lce_req.header.lru_dirty = bp_lce_cce_lru_dirty_e'(cache_req_metadata_r.dirty);
        lce_req.header.lru_way_id = lce_assoc_p'(cache_req_metadata_r.repl_way);
        lce_req.header.non_exclusive = e_lce_req_excl;

        lce_req.header.addr = miss_addr_r;
        lce_req.header.msg_type = load_not_store_r 
          ? e_lce_req_type_rd
          : e_lce_req_type_wr;
        lce_req.header.src_id = lce_id_i;
        lce_req.header.dst_id = req_cce_id_lo;

        state_n = lce_req_v_o
          ? e_SLEEP
          : e_SEND_CACHED_REQ;
      end

      // SEND UNCACHED_LOAD_REQ
      e_SEND_UNCACHED_LOAD_REQ: begin
        lce_req_v_o = lce_req_ready_i & cache_req_metadata_v_r;

        lce_req.data = '0;
        lce_req.header.uc_size = bp_lce_cce_uc_req_size_e'(size_op_r);
        lce_req.header.addr = miss_addr_r;
        lce_req.header.msg_type = e_lce_req_type_uc_rd;
        lce_req.header.src_id = lce_id_i;
        lce_req.header.dst_id = req_cce_id_lo;


        state_n = lce_req_v_o
          ? e_SLEEP
          : e_SEND_UNCACHED_LOAD_REQ;
      end

      // SLEEP 
      // wait for signals from other modules to wake up.
      e_SLEEP: begin
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;

        if (set_tag_wakeup_received_i) begin
          state_n = e_SEND_COH_ACK;
        end
        else if (uncached_data_received_i) begin
          state_n = e_READY;
        end
        else if (cce_data_received) begin
          state_n = e_SEND_COH_ACK;
        end
        else begin
          state_n = e_SLEEP;
        end
      end

      // COH ACK
      // send out coh ack to CCE.
      e_SEND_COH_ACK: begin
        lce_resp_v_o = 1'b1;
        lce_resp.header.msg_type = e_lce_cce_coh_ack;

        state_n = lce_resp_yumi_i
          ? e_READY
          : e_SEND_COH_ACK;
      end
      
      // we should never get in this state, but if we do, return to ready.
      default: begin
        state_n = e_READY;
      end
    endcase
  end

  // sequential
  //
  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_READY;
      cce_data_received_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      load_not_store_r <= load_not_store_n;
      miss_addr_r <= miss_addr_n;
      cce_data_received_r <= cce_data_received_n;
      size_op_r <= size_op_n;
    end
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

  assign cache_req_ready_o = credits_ready_i & cmd_ready_i & is_ready & ~timeout & lce_req_ready_i;

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (state_r == e_READY) begin
      assert(~cce_data_received_i)
        else $error("id: %0d, data_cmd received while no cache miss.", lce_id_i);
      assert(~set_tag_wakeup_received_i)
        else $error("id: %0d, set_tag_wakeup_cmd received while no cache miss.", lce_id_i);
    end
  end
  // synopsys translate_on

endmodule
