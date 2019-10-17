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
  #(parameter dword_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter ways_p="inv"
    , parameter cce_block_width_p="inv"
  
    , localparam block_size_in_words_lp=ways_p
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(dword_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam cce_id_width_lp=`BSG_SAFE_CLOG2(num_cce_p)
  
    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, dword_width_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p, cce_block_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [lce_id_width_lp-1:0] lce_id_i

    , input load_miss_i
    , input store_miss_i
    , input lr_miss_i
    , input [paddr_width_p-1:0] miss_addr_i
    , input [way_id_width_lp-1:0] lru_way_i
    , input [ways_p-1:0] dirty_i

    , input uncached_load_req_i
    , input uncached_store_req_i
    , input [dword_width_p-1:0] store_data_i
    , input [1:0] size_op_i

    , output logic cache_miss_o
    , output logic [paddr_width_p-1:0] miss_addr_o

    , input cce_data_received_i
    , input uncached_data_received_i
    , input set_tag_received_i
    , input set_tag_wakeup_received_i

    , output logic lce_req_uncached_store_o
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_yumi_i

    , input credits_full_i
  );

  // casting struct
  //
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, ways_p, dword_width_p, cce_block_width_p)

  bp_lce_cce_req_s lce_req;
  bp_lce_cce_resp_s lce_resp;

  assign lce_resp_o = lce_resp;

  // For uncached store buffering
  //
  logic lce_req_v_lo, lce_req_ready_li;

  // states
  //
  typedef enum logic [2:0] {
    e_READY
    ,e_SEND_CACHED_REQ
    ,e_SEND_UNCACHED_LOAD_REQ
    ,e_SEND_COH_ACK
    ,e_SLEEP
  } lce_req_state_e; 

  lce_req_state_e state_r, state_n;
  logic load_not_store_r, load_not_store_n;
  logic [way_id_width_lp-1:0] lru_way_r, lru_way_n;
  logic dirty_r, dirty_n;
  logic [paddr_width_p-1:0] miss_addr_r, miss_addr_n;
  logic dirty_lru_flopped_r, dirty_lru_flopped_n;
  logic [1:0] size_op_r, size_op_n;

  logic cce_data_received_r, cce_data_received_n, cce_data_received;
  logic set_tag_received_r, set_tag_received_n, set_tag_received;

  // comb logic
  //
  assign cce_data_received = cce_data_received_r | cce_data_received_i;
  assign set_tag_received = set_tag_received_r | set_tag_received_i;
  assign miss_addr_o = miss_addr_r;

  always_comb begin
    cache_miss_o = 1'b0;

    state_n = state_r;
    load_not_store_n = load_not_store_r;
    lru_way_n = lru_way_r;
    dirty_n = dirty_r;
    miss_addr_n = miss_addr_r;
    dirty_lru_flopped_n = dirty_lru_flopped_r;
    size_op_n = size_op_r;
    
    cce_data_received_n = cce_data_received_r;
    set_tag_received_n = set_tag_received_r;

    lce_req_v_lo = 1'b0;

    lce_req.dst_id = (num_cce_p > 1) ? miss_addr_r[block_offset_width_lp+:cce_id_width_lp] : 1'b0;
    lce_req.src_id = lce_id_i;
    lce_req.msg_type = e_lce_req_type_rd;
    lce_req.addr = miss_addr_r;
    lce_req.msg = '0;

    lce_resp_v_o = 1'b0;

    lce_resp.dst_id = (num_cce_p > 1) ? miss_addr_r[block_offset_width_lp+:cce_id_width_lp] : 1'b0;
    lce_resp.src_id = lce_id_i;
    lce_resp.msg_type = bp_lce_cce_resp_type_e'('0);
    lce_resp.addr = miss_addr_r;
    lce_resp.data = '0;

    unique case (state_r)

      // READY
      // wait for the cache miss.
      e_READY: begin
        if (load_miss_i | store_miss_i) begin
          miss_addr_n = miss_addr_i;
          dirty_lru_flopped_n = 1'b0;
          load_not_store_n = load_miss_i;
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;

          cache_miss_o = 1'b1;
          state_n = e_SEND_CACHED_REQ;
        end
        else if (lr_miss_i) begin
          miss_addr_n = miss_addr_i;
          dirty_lru_flopped_n = 1'b0;
          load_not_store_n = 1'b0; // We force a store miss to upgrade the block to exclusive
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;

          cache_miss_o = 1'b1;
          state_n = e_SEND_CACHED_REQ;
        end
        else if (uncached_load_req_i) begin
          miss_addr_n = miss_addr_i;
          size_op_n = bp_lce_cce_uc_req_size_e'(size_op_i);
          cce_data_received_n = 1'b0;
          set_tag_received_n = 1'b0;

          cache_miss_o = 1'b1;
          state_n = e_SEND_UNCACHED_LOAD_REQ;
        end
        else if (uncached_store_req_i) begin
          lce_req_v_lo = ~credits_full_i & lce_req_ready_li;

          lce_req.msg.uc_req.data = store_data_i;
          lce_req.msg.uc_req.uc_size = bp_lce_cce_uc_req_size_e'(size_op_i);
          lce_req.addr = miss_addr_i;
          lce_req.msg_type = e_lce_req_type_uc_wr;
          lce_req.src_id = lce_id_i;
          lce_req.dst_id = (num_cce_p > 1) ? miss_addr_i[block_offset_width_lp+:cce_id_width_lp] : 1'b0;

          cache_miss_o = ~lce_req_ready_li | credits_full_i;
          state_n = e_READY;
        end
        else begin
          cache_miss_o = 1'b0;
          state_n = e_READY;
        end
      end

      // SEND_CACHED_REQ
      // send out cache miss request to CCE.
      e_SEND_CACHED_REQ: begin
        dirty_lru_flopped_n = 1'b1;
        lru_way_n = dirty_lru_flopped_r ? lru_way_r : lru_way_i;
        dirty_n = dirty_lru_flopped_r ? dirty_r : dirty_i[lru_way_i];

        lce_req_v_lo = 1'b1;

        lce_req.msg.req.pad = '0;
        lce_req.msg.req.lru_dirty = dirty_lru_flopped_r
          ? bp_lce_cce_lru_dirty_e'(dirty_r)
          : bp_lce_cce_lru_dirty_e'(dirty_i[lru_way_i]);
        lce_req.msg.req.lru_way_id = dirty_lru_flopped_r
          ? lru_way_r
          : lru_way_i;
        lce_req.msg.req.non_exclusive = e_lce_req_excl;

        lce_req.addr = miss_addr_r;
        lce_req.msg_type = load_not_store_r 
          ? e_lce_req_type_rd
          : e_lce_req_type_wr;
        lce_req.src_id = lce_id_i;
        lce_req.dst_id = (num_cce_p > 1) ? miss_addr_r[block_offset_width_lp+:cce_id_width_lp] : 1'b0;

        cache_miss_o = 1'b1;
        state_n = lce_req_ready_li
          ? e_SLEEP
          : e_SEND_CACHED_REQ;
      end

      // SEND UNCACHED_LOAD_REQ
      e_SEND_UNCACHED_LOAD_REQ: begin
        lce_req_v_lo = 1'b1;

        lce_req.msg.uc_req.data = '0;
        lce_req.msg.uc_req.uc_size = bp_lce_cce_uc_req_size_e'(size_op_r);
        lce_req.addr = miss_addr_r;
        lce_req.msg_type = e_lce_req_type_uc_rd;
        lce_req.src_id = lce_id_i;
        lce_req.dst_id = (num_cce_p > 1) ? miss_addr_r[block_offset_width_lp+:cce_id_width_lp] : 1'b0;

        cache_miss_o = 1'b1;
        state_n = lce_req_ready_li
          ? e_SLEEP
          : e_SEND_UNCACHED_LOAD_REQ;
      end

      // SLEEP 
      // wait for signals from other modules to wake up.
      e_SLEEP: begin
        cache_miss_o = 1'b1;
        cce_data_received_n = cce_data_received_i ? 1'b1 : cce_data_received_r;
        set_tag_received_n = set_tag_received_i ? 1'b1 : set_tag_received_r;

        if (set_tag_wakeup_received_i) begin
          state_n = e_SEND_COH_ACK;
        end
        else if (uncached_data_received_i) begin
          state_n = e_READY;
        end
        else if (set_tag_received) begin
          if (cce_data_received) begin
            state_n = e_SEND_COH_ACK;
          end
          else begin
            state_n = e_SLEEP;
          end
        end
        else begin
          state_n = e_SLEEP;
        end
      end

      // COH ACK
      // send out coh ack to CCE.
      e_SEND_COH_ACK: begin
        lce_resp_v_o = 1'b1;
        lce_resp.msg_type = e_lce_cce_coh_ack;

        cache_miss_o = 1'b1;
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

  // We need this converter because the LCE expects the store data to go out when valid
  bsg_one_fifo
   #(.width_p(lce_cce_req_width_lp+1))
   rv_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({uncached_store_req_i, lce_req})
     ,.v_i(lce_req_v_lo)
     ,.ready_o(lce_req_ready_li)

     ,.data_o({lce_req_uncached_store_o, lce_req_o})
     ,.v_o(lce_req_v_o)
     ,.yumi_i(lce_req_ready_i & lce_req_v_o)
     );

  // sequential
  //
  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_READY;
      dirty_lru_flopped_r <= 1'b0;
      cce_data_received_r <= 1'b0;
      set_tag_received_r <= 1'b0;
    end
    else begin
      state_r <= state_n;
      load_not_store_r <= load_not_store_n;
      lru_way_r <= lru_way_n;
      dirty_r <= dirty_n;
      miss_addr_r <= miss_addr_n;
      dirty_lru_flopped_r <= dirty_lru_flopped_n;
      cce_data_received_r <= cce_data_received_n;
      set_tag_received_r <= set_tag_received_n;
      size_op_r <= size_op_n;
    end
  end

  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (state_r == e_READY) begin
      assert(~cce_data_received_i)
        else $error("id: %0d, data_cmd received while no cache miss.", lce_id_i);
      assert(~set_tag_received_i)
        else $error("id: %0d, set_tag_cmd received while no cache miss.", lce_id_i);
      assert(~set_tag_wakeup_received_i)
        else $error("id: %0d, set_tag_wakeup_cmd received while no cache miss.", lce_id_i);
    end
  end
  // synopsys translate_on

endmodule
