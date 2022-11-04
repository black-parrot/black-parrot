/**
 * bp_me_nonsynth_cache.sv
 *
 * This module is a fake cache with the standard cache-LCE interface that should be connected
 * to the standard BP LCE and a trace replay interface to consume cache operations.
 * The trace replay format is defined in bp_me_nonsynth_pkg.svh.
 *
 * All operations except uncached stores are blocking.
 *
 * Cache request metadata is sent same cycle as cache request
 *
 * Stat, Data, and Tag memories operate on module's normal clock input
 *
 * Atomic operations are not supported
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cache
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_test_multicore_half_cfg
    `declare_bp_proc_params(bp_params_p)

    // cache organization params
    , parameter sets_p = 64
    , parameter assoc_p = 8
    , parameter block_width_p = 512
    , parameter fill_width_p = 64

    , localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam lg_assoc_lp=`BSG_SAFE_CLOG2(assoc_p)
    , localparam block_size_in_bytes_lp = (block_width_p/8)
    , localparam block_offset_width_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam fill_words_lp = (block_width_p/fill_width_p)
    , localparam tag_offset_lp = block_offset_width_lp + (sets_p > 1 ? lg_sets_lp : 0)

    , localparam tr_pkt_width_lp=`bp_me_nonsynth_tr_pkt_width(paddr_width_p, dword_width_gp)

    , localparam counter_max_p = 512
    , localparam counter_width_p=`BSG_WIDTH(counter_max_p+1)

    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
   )
   (
    input                                                   clk_i
    , input                                                 reset_i

    , input [lce_id_width_p-1:0]                            id_i

    // Trace Replay Interface
    , input [tr_pkt_width_lp-1:0]                           tr_pkt_i
    , input                                                 tr_pkt_v_i
    , output logic                                          tr_pkt_yumi_o

    // ready->valid
    , output logic [tr_pkt_width_lp-1:0]                    tr_pkt_o
    , output logic                                          tr_pkt_v_o
    , input                                                 tr_pkt_ready_then_i

     // Cache-LCE interface
    , output logic [cache_req_width_lp-1:0]                 cache_req_o
    , output logic                                          cache_req_v_o
    , input                                                 cache_req_ready_and_i
    , input                                                 cache_req_busy_i
    , output logic [cache_req_metadata_width_lp-1:0]        cache_req_metadata_o
    , output logic                                          cache_req_metadata_v_o
    , input                                                 cache_req_critical_tag_i
    , input                                                 cache_req_critical_data_i
    , input                                                 cache_req_complete_i
    , input                                                 cache_req_credits_full_i
    , input                                                 cache_req_credits_empty_i

    // LCE-Cache Interface
    , input                                                 data_mem_pkt_v_i
    , input [cache_data_mem_pkt_width_lp-1:0]               data_mem_pkt_i
    , output logic                                          data_mem_pkt_yumi_o
    , output logic [block_width_p-1:0]                      data_mem_o

    , input                                                 tag_mem_pkt_v_i
    , input [cache_tag_mem_pkt_width_lp-1:0]                tag_mem_pkt_i
    , output logic                                          tag_mem_pkt_yumi_o
    , output logic [cache_tag_info_width_lp-1:0]            tag_mem_o

    , input                                                 stat_mem_pkt_v_i
    , input [cache_stat_mem_pkt_width_lp-1:0]               stat_mem_pkt_i
    , output logic                                          stat_mem_pkt_yumi_o
    , output logic [cache_stat_info_width_lp-1:0]           stat_mem_o
   );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);

    localparam bp_cache_req_size_e block_req_size = bp_cache_req_size_e'(`BSG_SAFE_CLOG2(block_width_p/8));

  // Trace Replay Interface
  `declare_bp_me_nonsynth_tr_pkt_s(paddr_width_p, dword_width_gp);
  `bp_cast_i(bp_me_nonsynth_tr_pkt_s, tr_pkt);
  `bp_cast_o(bp_me_nonsynth_tr_pkt_s, tr_pkt);

  // Trace Replay Packet Register
  // Automatically consume new packet if register doesn't hold valid packet
  // Clear register when TR response sends
  // do not accept new TR packets if LCE busy signal asserted
  wire tr_pkt_v_li = tr_pkt_v_i & ~cache_req_busy_i;
  bp_me_nonsynth_tr_pkt_s tr_pkt_r;
  bsg_dff_reset_en
    #(.width_p($bits(bp_me_nonsynth_tr_pkt_s)+1))
    tr_pkt_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i | (tr_pkt_v_o & tr_pkt_ready_then_i))
      ,.en_i(tr_pkt_yumi_o)
      ,.data_i({tr_pkt_v_li, tr_pkt_cast_i})
      ,.data_o({tr_pkt_v, tr_pkt_r})
      );
  assign tr_pkt_yumi_o = ~tr_pkt_v & tr_pkt_v_li;

  wire store_op = tr_pkt_r.cmd[3];
  wire load_op = ~tr_pkt_r.cmd[3];
  wire signed_op = ~tr_pkt_r.cmd[2];
  wire double_op = (tr_pkt_r.cmd[1:0] == 2'b11);
  wire word_op = (tr_pkt_r.cmd[1:0] == 2'b10);
  wire half_op = (tr_pkt_r.cmd[1:0] == 2'b01);
  wire byte_op = (tr_pkt_r.cmd[1:0] == 2'b00);
  wire [2:0] byte_offset = tr_pkt_r.paddr[2:0];
  wire [2:0] dword_offset = tr_pkt_r.paddr[5:3];
  wire uc_op = tr_pkt_r.uncached;
  wire [ctag_width_p-1:0] tr_tag = tr_pkt_r.paddr[tag_offset_lp+:ctag_width_p];

  // cache locked signal to block LCE x_mem_pkt operations
  // need to lock once cache accepts TR pkt until send to LCE
  // or need to restart processing of TR pkt if LCE updates any of the memories
  logic lce_if_locked;

  // Cache-LCE Interface
  `bp_cast_o(bp_cache_req_s, cache_req);
  `bp_cast_o(bp_cache_req_metadata_s, cache_req_metadata);

  // LCE-Cache Interface
  `bp_cast_i(bp_cache_tag_mem_pkt_s, tag_mem_pkt);
  `bp_cast_i(bp_cache_data_mem_pkt_s, data_mem_pkt);
  `bp_cast_i(bp_cache_stat_mem_pkt_s, stat_mem_pkt);
  `bp_cast_o(bp_cache_tag_info_s, tag_mem);
  `bp_cast_o(bp_cache_stat_info_s, stat_mem);

  // data mem packet way register
  logic [lg_assoc_lp-1:0] data_mem_pkt_way;
  bsg_dff_reset_en
    #(.width_p(lg_assoc_lp))
    data_mem_pkt_way_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(data_mem_pkt_yumi_o)
      ,.data_i(data_mem_pkt_cast_i.way_id)
      ,.data_o(data_mem_pkt_way)
      );

  // tag mem packet way register
  logic [lg_assoc_lp-1:0] tag_mem_pkt_way;
  bsg_dff_reset_en
    #(.width_p(lg_assoc_lp))
    tag_mem_pkt_way_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(tag_mem_pkt_yumi_o)
      ,.data_i(tag_mem_pkt_cast_i.way_id)
      ,.data_o(tag_mem_pkt_way)
      );

  // Cache Data and Metadata

  // Tags and State per block
  bp_cache_tag_info_s [assoc_p-1:0] tag_mem_data_li, tag_mem_mask_li, tag_mem_data_lo;
  logic [lg_sets_lp-1:0] tag_mem_addr_li;
  logic tag_mem_v_li, tag_mem_w_li;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p($bits(bp_cache_tag_info_s)*assoc_p)
      ,.els_p(sets_p)
      ,.latch_last_read_p(1)
      )
    tag_array
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(tag_mem_data_li)
      ,.addr_i(tag_mem_addr_li)
      ,.v_i(tag_mem_v_li)
      ,.w_mask_i(tag_mem_mask_li)
      ,.w_i(tag_mem_w_li)
      ,.data_o(tag_mem_data_lo)
      );

  // combinational logic to process tag mem output
  logic tag_lookup_hit_lo;
  logic tag_lookup_dirty_lo;
  logic [lg_assoc_lp-1:0] tag_lookup_hit_way_lo;
  bp_coh_states_e tag_lookup_hit_state_lo;
  logic [assoc_p-1:0] tag_lookup_invalid_ways_lo;

  bp_me_nonsynth_cache_tag_lookup
    #(.assoc_p(assoc_p)
      ,.tag_width_p(ctag_width_p)
      )
    tag_lookup
    (.tag_set_i(tag_mem_data_lo)
     ,.tag_i(tr_tag)
     ,.w_i(store_op)
     ,.uc_i(uc_op)
     ,.hit_o(tag_lookup_hit_lo)
     ,.dirty_o(tag_lookup_dirty_lo)
     ,.way_o(tag_lookup_hit_way_lo)
     ,.state_o(tag_lookup_hit_state_lo)
     ,.invalid_ways_o(tag_lookup_invalid_ways_lo)
     );

  // Data Memory
  logic [assoc_p-1:0][block_width_p-1:0] data_mem_data_li, data_mem_mask_li, data_mem_data_lo;
  logic [lg_sets_lp-1:0] data_mem_addr_li;
  logic data_mem_v_li, data_mem_w_li;

  bsg_mem_1rw_sync_mask_write_bit_banked
    #(.width_p(block_width_p*assoc_p)
      ,.els_p(sets_p)
      ,.num_width_bank_p(assoc_p)
      ,.latch_last_read_p(1)
      )
    data_array
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(data_mem_data_li)
      ,.addr_i(data_mem_addr_li)
      ,.v_i(data_mem_v_li)
      ,.w_mask_i(data_mem_mask_li)
      ,.w_i(data_mem_w_li)
      ,.data_o(data_mem_data_lo)
      );

  // Stat memory
  // LRU and dirty bits per cache set
  logic stat_mem_v_li;
  logic stat_mem_w_li;
  logic [lg_sets_lp-1:0] stat_mem_addr_li;
  bp_cache_stat_info_s stat_mem_data_li;
  bp_cache_stat_info_s stat_mem_mask_li;
  bp_cache_stat_info_s stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
   #(.width_p(cache_stat_info_width_lp)
     ,.els_p(sets_p)
     ,.latch_last_read_p(1)
     )
   stat_mem
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.v_i(stat_mem_v_li)
    ,.w_i(stat_mem_w_li)
    ,.addr_i(stat_mem_addr_li)
    ,.data_i(stat_mem_data_li)
    ,.w_mask_i(stat_mem_mask_li)
    ,.data_o(stat_mem_data_lo)
    );

  // generate way id from lru bits
  logic [lg_assoc_lp-1:0] lru_way;
  bsg_lru_pseudo_tree_encode
   #(.ways_p(assoc_p))
   lru_encoder
    (.lru_i(stat_mem_data_lo.lru)
     ,.way_id_o(lru_way)
     );

  logic invalid_exist;
  logic [lg_assoc_lp-1:0] invalid_way;
  bsg_priority_encode
   #(.width_p(assoc_p), .lo_to_hi_p(1))
    pe_invalid
    (.i(tag_lookup_invalid_ways_lo)
     ,.v_o(invalid_exist)
     ,.addr_o(invalid_way)
     );

  wire [lg_assoc_lp-1:0] hit_or_repl_way = invalid_exist ? invalid_way : lru_way;

  // next LRU way logic - given current way being accessed, get a next way to use as LRU
  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_data_lo;
  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_mask_lo;
  logic [lg_assoc_lp-1:0] lru_decode_way_li;
  bsg_lru_pseudo_tree_decode
   #(.ways_p(assoc_p))
   lru_decode
    (.way_id_i(lru_decode_way_li)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
     );

  // Data word (64-bit) targeted by current trace replay command
  logic [dword_width_gp-1:0] load_dword;
  assign load_dword = data_mem_data_lo[tag_lookup_hit_way_lo][(dword_width_gp*dword_offset) +: dword_width_gp];
  logic word_sigext, half_sigext, byte_sigext;
  logic [31:0] load_word;
  logic [15:0] load_half;
  logic [7:0] load_byte;

  bsg_mux #(
    .width_p(32)
    ,.els_p(2)
  ) word_mux (
    .data_i(load_dword)
    ,.sel_i(byte_offset[2])
    ,.data_o(load_word)
  );

  bsg_mux #(
    .width_p(16)
    ,.els_p(4)
  ) half_mux (
    .data_i(load_dword)
    ,.sel_i(byte_offset[2:1])
    ,.data_o(load_half)
  );

  bsg_mux #(
    .width_p(8)
    ,.els_p(8)
  ) byte_mux (
    .data_i(load_dword)
    ,.sel_i(byte_offset[2:0])
    ,.data_o(load_byte)
  );

  assign word_sigext = signed_op & load_word[31];
  assign half_sigext = signed_op & load_half[15];
  assign byte_sigext = signed_op & load_byte[7];

  // Uncached data word
  logic [dword_width_gp-1:0] uc_load_dword;
  assign uc_load_dword = data_mem_pkt_cast_i.data[0+:dword_width_gp];
  logic [31:0] uc_load_word;
  logic [15:0] uc_load_half;
  logic [7:0] uc_load_byte;

  bsg_mux #(
    .width_p(32)
    ,.els_p(2)
  ) uc_word_mux (
    .data_i(uc_load_dword)
    ,.sel_i(byte_offset[2])
    ,.data_o(uc_load_word)
  );

  bsg_mux #(
    .width_p(16)
    ,.els_p(4)
  ) uc_half_mux (
    .data_i(uc_load_dword)
    ,.sel_i(byte_offset[2:1])
    ,.data_o(uc_load_half)
  );

  bsg_mux #(
    .width_p(8)
    ,.els_p(8)
  ) uc_byte_mux (
    .data_i(uc_load_dword)
    ,.sel_i(byte_offset[2:0])
    ,.data_o(uc_load_byte)
  );

  // fill index to shift value
  logic [`BSG_SAFE_CLOG2(fill_words_lp)-1:0] fill_shift;
  logic fill_shift_v;
  bsg_encode_one_hot
    #(.width_p(fill_words_lp)
      ,.lo_to_hi_p(1)
      )
    fill_encode
     (.i(data_mem_pkt_cast_i.fill_index)
      ,.addr_o(fill_shift)
      ,.v_o(fill_shift_v)
      );

  // FSM states
  typedef enum logic [3:0]
  {
    e_reset
    // wait for valid TR packet in register (or replay after miss)
    // read all memories if no incoming LCE packets
    ,e_ready
    // evaluate cache memory output
    ,e_check_hit
    // wait for cache miss resolution from LCE
    ,e_wait
    // invalidate cache block if targeted by uncached access
    ,e_uc_hit_inv
    // wait for uncached load data
    ,e_uc_load_wait
    // like the D$, an UC store completes as soon as the cache request pkt sends to LCE
    ,e_uc_store_resp
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
    end else begin
      state_r <= state_n;
    end
  end

  localparam data_mem_mask_pad_lp = (fill_width_p < block_width_p) ? (block_width_p-fill_width_p) : 1;

  always_comb begin
    state_n = state_r;
    // Trace Replay Interface
    tr_pkt_cast_o = tr_pkt_r;
    tr_pkt_cast_o.data = '0;
    tr_pkt_v_o = 1'b0;
    // signal to lock LCE-Cache interface (data, stat, mem pkt from LCE)
    lce_if_locked = 1'b0;
    // Cache-LCE Interface
    cache_req_cast_o = '0;
    cache_req_cast_o.hit = 1'b0; // unused by LCE
    cache_req_cast_o.data = tr_pkt_r.data;
    cache_req_cast_o.size = uc_op
                            ? double_op
                              ? e_size_8B
                              : word_op
                                ? e_size_4B
                                : half_op
                                  ? e_size_2B
                                  : e_size_1B
                            : block_req_size;
    cache_req_cast_o.addr = tr_pkt_r.paddr;
    // AMO, flush, clear, and wt_store not supported
    cache_req_cast_o.msg_type = uc_op ? store_op ? e_uc_store : e_uc_load
                                      : store_op ? e_miss_store : e_miss_load;
    cache_req_cast_o.subop = e_req_store; // only regular stores supported
    cache_req_v_o = 1'b0;
    cache_req_metadata_cast_o = '0;
    cache_req_metadata_cast_o.hit_or_repl_way = hit_or_repl_way;
    cache_req_metadata_cast_o.dirty = stat_mem_data_lo[hit_or_repl_way];
    cache_req_metadata_v_o = 1'b0;
    // LCE-Cache Interface
    data_mem_pkt_yumi_o = 1'b0;
    tag_mem_pkt_yumi_o = 1'b0;
    stat_mem_pkt_yumi_o = 1'b0;
    data_mem_o = data_mem_data_lo[data_mem_pkt_way];
    tag_mem_cast_o = tag_mem_data_lo[tag_mem_pkt_way];
    stat_mem_cast_o = stat_mem_data_lo;
    // tag mem
    tag_mem_data_li = '0;
    tag_mem_mask_li = '0;
    tag_mem_addr_li = tr_pkt_r.paddr[block_offset_width_lp +: lg_sets_lp];
    tag_mem_v_li = 1'b0;
    tag_mem_w_li = 1'b0;
    // stat mem
    stat_mem_v_li = 1'b0;
    stat_mem_w_li = 1'b0;
    stat_mem_addr_li = tr_pkt_r.paddr[block_offset_width_lp +: lg_sets_lp];
    stat_mem_data_li = '0;
    stat_mem_mask_li = '0;
    // data mem
    data_mem_data_li = '0;
    data_mem_mask_li = '0;
    data_mem_addr_li = tr_pkt_r.paddr[block_offset_width_lp +: lg_sets_lp];
    data_mem_v_li = 1'b0;
    data_mem_w_li = 1'b0;
    // lru way to pseudo lru bits
    lru_decode_way_li = tag_lookup_hit_way_lo;

    case (state_r)
      e_reset: begin
        state_n = e_ready;
      end // e_reset

      // wait for new TR packet
      // read tag mem, data mem, and dirty bits
      e_ready: begin
        lce_if_locked = tr_pkt_v;
        tag_mem_v_li = tr_pkt_v;
        data_mem_v_li = tr_pkt_v;
        stat_mem_v_li = tr_pkt_v;
        state_n = tr_pkt_v ? e_check_hit : state_r;
      end // e_ready

      // send TR response if hit or cache request to LCE if miss
      e_check_hit: begin
        // uncached ops send request to LCE
        if (uc_op) begin
          cache_req_v_o = 1'b1;
          // metadata not used by LCE for uncached ops, but send it anyway
          cache_req_metadata_v_o = 1'b1;
          state_n = (cache_req_ready_and_i & cache_req_v_o)
                    ? tag_lookup_hit_lo
                      ? e_uc_hit_inv
                      : load_op
                        ? e_uc_load_wait
                        : e_uc_store_resp
                    : state_r;
        end
        // cached hit
        else if (tag_lookup_hit_lo) begin
          lce_if_locked = 1'b1;
          if (store_op) begin
            // commit store, write dirty bit, send TR response, update LRU
            tag_mem_v_li = tr_pkt_ready_then_i;
            tag_mem_w_li = tr_pkt_ready_then_i;
            tag_mem_data_li[tag_lookup_hit_way_lo].state = e_COH_M;
            tag_mem_mask_li[tag_lookup_hit_way_lo].state = '1;

            data_mem_v_li = tr_pkt_ready_then_i;
            data_mem_w_li = tr_pkt_ready_then_i;
            data_mem_mask_li[tag_lookup_hit_way_lo] = double_op
              ? {{(block_width_p-64){1'b0}}, {64{1'b1}}} << (dword_offset*64)
              : word_op
                ? {{(block_width_p-32){1'b0}}, {32{1'b1}}} << (dword_offset*64 + 32*byte_offset[2])
                : half_op
                  ? {{(block_width_p-16){1'b0}}, {16{1'b1}}} << (dword_offset*64 + 16*byte_offset[2:1])
                  : {{(block_width_p-8){1'b0}}, {8{1'b1}}} << (dword_offset*64 + 8*byte_offset[2:0]);
            data_mem_data_li[tag_lookup_hit_way_lo] = double_op
              ? {{(block_width_p-64){1'b0}}, tr_pkt_r.data} << (dword_offset*64)
              : word_op
                ? {{(block_width_p-32){1'b0}}, tr_pkt_r.data[0+:32]} << (dword_offset*64 + 32*byte_offset[2])
                : half_op
                  ? {{(block_width_p-16){1'b0}}, tr_pkt_r.data[0+:16]} << (dword_offset*64 + 16*byte_offset[2:1])
                  : {{(block_width_p-8){1'b0}}, tr_pkt_r.data[0+:8]} << (dword_offset*64 + 8*byte_offset[2:0]);

            stat_mem_v_li = tr_pkt_ready_then_i;
            stat_mem_w_li = tr_pkt_ready_then_i;
            stat_mem_data_li.dirty[tag_lookup_hit_way_lo] = 1'b1;
            stat_mem_mask_li.dirty[tag_lookup_hit_way_lo] = 1'b1;
            stat_mem_data_li.lru = lru_decode_data_lo;
            stat_mem_mask_li.lru = lru_decode_mask_lo;

            // send response packet
            tr_pkt_v_o = tr_pkt_ready_then_i;

            state_n = tr_pkt_ready_then_i ? e_ready : state_r;

          end else begin
            if (load_op) begin
              tr_pkt_cast_o.data = double_op
                ? load_dword
                : word_op
                  ? {{32{word_sigext}}, load_word}
                  : half_op
                    ? {{48{half_sigext}}, load_half}
                    : {{56{byte_sigext}}, load_byte};
            end

            stat_mem_v_li = tr_pkt_ready_then_i;
            stat_mem_w_li = tr_pkt_ready_then_i;
            stat_mem_data_li.lru = lru_decode_data_lo;
            stat_mem_mask_li.lru = lru_decode_mask_lo;

            // return load data with TR response
            tr_pkt_v_o = tr_pkt_ready_then_i;

            state_n = tr_pkt_ready_then_i ? e_ready : state_r;
          end
        end
        // cached miss
        else begin
          cache_req_v_o = 1'b1;
          cache_req_metadata_v_o = 1'b1;
          state_n = (cache_req_ready_and_i & cache_req_v_o) ? e_wait : state_r;
        end
      end // e_check_hit

      // self-invalidate valid block targeted by uncached access
      // forces a following cacheable access to miss and send request to LCE
      // and serialize with the uncached access
      e_uc_hit_inv: begin
        lce_if_locked = 1'b1;
        tag_mem_v_li = 1'b1;
        tag_mem_w_li = 1'b1;
        tag_mem_data_li[tag_lookup_hit_way_lo].state = e_COH_I;
        tag_mem_mask_li[tag_lookup_hit_way_lo].state = '1;
        state_n = load_op ? e_uc_load_wait : e_uc_store_resp;
      end

      // wait for LCE to resolve cached request miss
      // then, return to ready and replay the current TR command
      // note: critical tag and data signals are ignored
      e_wait: begin
        state_n = cache_req_complete_i ? e_ready : state_r;
      end

      // wait for UC load data
      e_uc_load_wait: begin
        tr_pkt_v_o = data_mem_pkt_v_i & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached)
                     & tr_pkt_ready_then_i;
        tr_pkt_cast_o.data = double_op
          ? uc_load_dword
          : word_op
            ? {{32{1'b0}}, uc_load_word}
            : half_op
              ? {{48{1'b0}}, uc_load_half}
              : {{56{1'b0}}, uc_load_byte};

        data_mem_pkt_yumi_o = tr_pkt_v_o;
        state_n = tr_pkt_v_o ? e_ready : state_r;
      end

      // send TR response for UC store
      e_uc_store_resp: begin
        tr_pkt_v_o = tr_pkt_ready_then_i;
        state_n = tr_pkt_v_o ? e_ready : state_r;
      end

      default: begin
        state_n = e_reset;
      end
    endcase

    // process data, stat, tag packets from LCE if able
    // response are sent cycle after command is consumed
    if (!lce_if_locked) begin
      // data mem - only need to handle read or write (UC handled by FSM)
      if (data_mem_pkt_v_i) begin
        data_mem_pkt_yumi_o = 1'b1;
        data_mem_addr_li = data_mem_pkt_cast_i.index;
        data_mem_v_li = 1'b1;
        case (data_mem_pkt_cast_i.opcode)
          e_cache_data_mem_write: begin
            data_mem_w_li = 1'b1;
            data_mem_addr_li = data_mem_pkt_cast_i.index;
            data_mem_data_li[data_mem_pkt_cast_i.way_id] =
              {fill_words_lp{data_mem_pkt_cast_i.data}} << (fill_shift * fill_width_p);
            data_mem_mask_li[data_mem_pkt_cast_i.way_id] =
              {(data_mem_mask_pad_lp)'('0), {fill_width_p{1'b1}}} << (fill_shift * fill_width_p);
          end
          e_cache_data_mem_read: begin
            // nothing needed here; way_id is captured by dff, output muxed next cycle
          end
          default: begin
          end
        endcase
      end
      // tag mem
      if (tag_mem_pkt_v_i) begin
        tag_mem_pkt_yumi_o = 1'b1;
        tag_mem_addr_li = tag_mem_pkt_cast_i.index;
        tag_mem_v_li = 1'b1;
        case (tag_mem_pkt_cast_i.opcode)
          e_cache_tag_mem_set_clear: begin
            tag_mem_w_li = 1'b1;
            tag_mem_data_li = '0;
            tag_mem_mask_li = '1;
          end
          e_cache_tag_mem_set_tag: begin // set tag and state
            tag_mem_w_li = 1'b1;
            tag_mem_data_li[tag_mem_pkt_cast_i.way_id].tag = tag_mem_pkt_cast_i.tag;
            tag_mem_data_li[tag_mem_pkt_cast_i.way_id].state = tag_mem_pkt_cast_i.state;
            tag_mem_mask_li[tag_mem_pkt_cast_i.way_id] = '1;
          end
          e_cache_tag_mem_set_state: begin // set state only
            tag_mem_w_li = 1'b1;
            tag_mem_data_li[tag_mem_pkt_cast_i.way_id].state = tag_mem_pkt_cast_i.state;
            tag_mem_mask_li[tag_mem_pkt_cast_i.way_id].state = '1;
          end
          e_cache_tag_mem_read: begin
            // nothing needed here; way_id is captured by dff, output muxed next cycle
          end
          default: begin
          end
        endcase
      end
      // stat mem
      if (stat_mem_pkt_v_i) begin
        stat_mem_pkt_yumi_o = 1'b1;
        lru_decode_way_li = stat_mem_pkt_cast_i.way_id;
        stat_mem_addr_li = stat_mem_pkt_cast_i.index;
        case (stat_mem_pkt_cast_i.opcode)
          e_cache_stat_mem_set_clear: begin
            stat_mem_v_li = 1'b1;
            stat_mem_w_li = 1'b1;
            stat_mem_data_li = '0;
            stat_mem_mask_li = '1;
          end
          e_cache_stat_mem_read: begin
            stat_mem_v_li = 1'b1;
          end
          e_cache_stat_mem_clear_dirty: begin
            stat_mem_v_li = 1'b1;
            stat_mem_w_li = 1'b1;
            stat_mem_data_li.dirty[stat_mem_pkt_cast_i.way_id] = 1'b0;
            stat_mem_mask_li.dirty[stat_mem_pkt_cast_i.way_id] = 1'b1;
          end
          default: begin
          end
        endcase
      end
    end

  end // always_comb

endmodule


