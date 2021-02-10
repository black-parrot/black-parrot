/**
 *  Name:
 *    bp_be_dcache.v
 *
 *  Description:
 *    L1 Data Cache. Features:
 *    - Virtually-indexed, physically-tagged
 *    - 2-8 way set-associative
 *    - 128-512 bit block size (minimum 64-bit data mem bank size)
 *
 *    There are three large 1rw memory blocks: data_mem, tag_mem, stat_mem:
 *    - data_mem is divided into 1 bank per way, and cache blocks are
 *      interleaved among the banks. The governing relationship is "bank_id =
 *      word_offset + way_id" (with modular arithmetic).
 *
 *    - tag_mem contains tag and coherence state bits.
 *
 *    - stat_mem contains information about dirty bits for each cache block and
 *      LRU info about each way group (pseudo-LRU replacement policy).
 *
 *    There are three pipeline stages: tag lookup (TL), tag verity (TV), and
 *      data mux (DM) stages. Signals and registers are suffixed by stage name.
 *
 *    - Before TL, a dcache_pkt containing opcode, address and store data arrives
 *        at the cache. It is decoded and latched on the NEGATIVE edge of the clock.
 *        This gives half a cycle for address calculation.
 *
 *    - In TL, data mem and tag mem are synchronously accessed. Addtionally, the
 *        physical tag and PMA attributes arrive and are latched. Hit detection is
 *        also performed in this stage. This information is latched on the NEGATIVE
 *        edge of the clock as well. This gives a full cycle for the large data memory
 *        access.
 *
 *    - In TV, the data read is muxed down to the correct word based on the bank hash
 *        of the hit vector and the word offset. This is expected to be latched by the
 *        external pipeline on a positive edge. This gives half a cycle for data muxing.
 *        This data is returned as "early_data".
 *
 *    - In DM, the data word selected in TV selected down to byte for sub-word ops, or
 *        recoded for floating point loads. This data is returned as "final_data"
 *
 *    There is a write buffer which allows holding write data from tv stage, delaying the
 *      physical write until data_mem becomes from from incoming loads. To prevent data
 *      hazards, it also supports bypassing from TL to TV if there is an address match in
 *      the write buffer
 *
 *    An address is broken down as follows:
 *      physical address = [physical tag | virtual index | block offset]
 *
 *    Load reserved and store conditional are implemented at a cache line granularity.
 *      A load reserved acts as a normal load with the following addtional properties:
 *      1) If the block is not in an exclusive ownership state (M or E in MESI), then the cache
 *      will send an upgrade request (store miss).
 *      2) If the LR is successful, a reservation is placed on the cache line. This reservation is
 *      valid for the current hart only.
 *      A store conditional will succeed (return 0) if there is a valid reservation on the address of
 *      the SC. Else, it will fail (return nonzero and will not commit the store). A failing store
 *      conditional will not produce a cache miss.
 *
 *    The reservation can be cleared by:
 *      1) Any SC to any address by this hart.
 *      2) A second LR (this will not clear the reservation, but it will change the reservation
 *      address).
 *      3) An invalidate received from the LCE. This command covers all cases of losing exclusive
 *      access to the block in this hart, including eviction and a cache miss.

 *    RISC-V guarantees forward progress for LR/SC sequences that match a set of conditions.
 *      BlackParrot guarantees progress by blocking remote invalidations until a following SC
 *      (subject to a timeout). Tradeoffs between local and remote QoS can be made by adjusting
 *      the lock time.
 *
 *    LR/SC aq/rl semantics are irrelevant for BlackParrot. Since we are in-order single issue and
 *      do not use a store buffer that allows stores before cache lines have been fetched, all
 *       memory requests are inherently ordered within a hart.
 *
 *    The dcache supports multi-cycle fill/eviction with the following constraints:
 *      - bank_width = block_width / assoc >= dword_width
 *      - fill_width = N*bank_width <= block_width
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_dcache
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Default to dcache parameters, but can override if needed
   , parameter coherent_p     = l1_coherent_p
   , parameter writethrough_p = l1_writethrough_p
   , parameter sets_p         = dcache_sets_p
   , parameter assoc_p        = dcache_assoc_p
   , parameter block_width_p  = dcache_block_width_p
   , parameter fill_width_p   = dcache_fill_width_p
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, dcache)

   , localparam cfg_bus_width_lp    = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dcache_pkt_width_lp = $bits(bp_be_dcache_pkt_s)
   )
  (input                              clk_i
   , input                            reset_i

   , input [cfg_bus_width_lp-1:0]     cfg_bus_i

   , input [dcache_pkt_width_lp-1:0]  dcache_pkt_i
   , input                            v_i
   , output logic                     ready_o

   // TLB interface
   , input [ptag_width_p-1:0]         ptag_i
   , input                            ptag_v_i
   , input                            uncached_i

   , output logic [dpath_width_gp-1:0] early_data_o
   , output logic                      early_v_o
   , output logic [dpath_width_gp-1:0] final_data_o
   , output logic                      final_v_o

   // ctrl
   , input                             flush_i

   // D$ Engine Interface
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_busy_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input                                           cache_req_critical_i
   , input                                           cache_req_complete_i
   // Unused
   , input                                           cache_req_credits_full_i
   , input                                           cache_req_credits_empty_i

   , input                                           data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
   , output logic                                    data_mem_pkt_yumi_o
   , output logic [block_width_p-1:0]         data_mem_o

   , input                                           tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0]         tag_mem_pkt_i
   , output logic                                    tag_mem_pkt_yumi_o
   , output logic [dcache_tag_info_width_lp-1:0]     tag_mem_o

   , input                                           stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0]        stat_mem_pkt_i
   , output logic                                    stat_mem_pkt_yumi_o
   , output logic [dcache_stat_info_width_lp-1:0]    stat_mem_o
   );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, dcache);

  localparam lg_dcache_assoc_lp       = `BSG_SAFE_CLOG2(assoc_p);
  localparam bank_width_lp            = block_width_p / assoc_p;
  localparam num_dwords_per_bank_lp   = bank_width_lp / dword_width_gp;
  localparam wbuf_data_mask_width_lp  = (dword_width_gp >> 3);
  localparam data_mem_mask_width_lp   = (bank_width_lp >> 3);
  localparam byte_offset_width_lp     = `BSG_SAFE_CLOG2(bank_width_lp>>3);
  localparam bindex_width_lp          = `BSG_SAFE_CLOG2(assoc_p);
  localparam sindex_width_lp          = `BSG_SAFE_CLOG2(sets_p);
  localparam block_size_in_fill_lp    = block_width_p / fill_width_p;
  localparam fill_size_in_bank_lp     = fill_width_p / bank_width_lp;
  localparam block_offset_width_lp    = (assoc_p > 1)
    ? (bindex_width_lp+byte_offset_width_lp)
    : byte_offset_width_lp;

  // State machine declaration
  enum logic [1:0] {e_ready, e_miss, e_fence} state_n, state_r;
  wire is_ready = (state_r == e_ready);
  wire is_miss  = (state_r == e_miss);
  wire is_fence = (state_r == e_fence);

  // Global signals
  logic tl_we, tv_we, dm_we;
  logic v_tl_r, v_tv_r, v_dm_r;
  logic gdirty_r, cache_lock;
  logic uncached_load_data_v_r;
  logic [dword_width_gp-1:0] uncached_load_data_r;

  /////////////////////////////////////////////////////////////////////////////
  // Decode Stage
  /////////////////////////////////////////////////////////////////////////////
  `bp_cast_i(bp_be_dcache_pkt_s, dcache_pkt);

  bp_be_dcache_decode_s decode_lo;
  bp_be_dcache_decoder
   #(.bp_params_p(bp_params_p))
     pkt_decoder
    (.pkt_i(dcache_pkt_i)
     ,.decode_o(decode_lo)
     );

  wire [page_offset_width_gp-1:0]  page_offset = dcache_pkt_cast_i.page_offset;
  wire [sindex_width_lp-1:0]       vaddr_index = page_offset[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0]       vaddr_bank  = page_offset[byte_offset_width_lp+:bindex_width_lp];

  ///////////////////////////
  // Tag Mem Storage
  ///////////////////////////
  `bp_cast_i(bp_dcache_tag_mem_pkt_s, tag_mem_pkt);
  logic                              tag_mem_v_li;
  logic                              tag_mem_w_li;
  logic [sindex_width_lp-1:0]        tag_mem_addr_li;
  bp_dcache_tag_info_s [assoc_p-1:0] tag_mem_data_li;
  bp_dcache_tag_info_s [assoc_p-1:0] tag_mem_mask_li;
  bp_dcache_tag_info_s [assoc_p-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(dcache_tag_info_width_lp*assoc_p)
      ,.els_p(sets_p)
      ,.latch_last_read_p(1)
      )
    tag_mem
     (.clk_i(~clk_i)
      ,.reset_i(reset_i)
      ,.v_i(tag_mem_v_li)
      ,.w_i(tag_mem_w_li)
      ,.addr_i(tag_mem_addr_li)
      ,.data_i(tag_mem_data_li)
      ,.w_mask_i(tag_mem_mask_li)
      ,.data_o(tag_mem_data_lo)
      );

  ///////////////////////////
  // Data Mem Storage
  ///////////////////////////
  localparam data_mem_addr_width_lp = (assoc_p > 1) ? (sindex_width_lp+bindex_width_lp) : sindex_width_lp;
  `bp_cast_i(bp_dcache_data_mem_pkt_s, data_mem_pkt);
  logic [assoc_p-1:0]                               data_mem_v_li;
  logic [assoc_p-1:0]                               data_mem_w_li;
  logic [assoc_p-1:0][data_mem_addr_width_lp-1:0]   data_mem_addr_li;
  logic [assoc_p-1:0][bank_width_lp-1:0]            data_mem_data_li;
  logic [assoc_p-1:0][data_mem_mask_width_lp-1:0]   data_mem_mask_li;
  logic [assoc_p-1:0][bank_width_lp-1:0]            data_mem_data_lo;

  for (genvar i = 0; i < assoc_p; i++)
    begin : d
      bsg_mem_1rw_sync_mask_write_byte
       #(.data_width_p(bank_width_lp)
         ,.els_p(sets_p*assoc_p)
         ,.latch_last_read_p(1)
         )
       data_mem
        (.clk_i(~clk_i)
         ,.reset_i(reset_i)
         ,.v_i(data_mem_v_li[i])
         ,.w_i(data_mem_w_li[i])
         ,.addr_i(data_mem_addr_li[i])
         ,.data_i(data_mem_data_li[i])
         ,.write_mask_i(data_mem_mask_li[i])
         ,.data_o(data_mem_data_lo[i])
         );
    end

  /////////////////////////////////////////////////////////////////////////////
  // TL Stage
  /////////////////////////////////////////////////////////////////////////////
  bp_be_dcache_decode_s decode_tl_r;
  logic [page_offset_width_gp-1:0] page_offset_tl_r;
  logic [dpath_width_gp-1:0] data_tl_r;

  assign tl_we = ready_o & v_i & ~flush_i;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_tl_reg
    (.clk_i(~clk_i)
     ,.reset_i(reset_i)

     ,.set_i(tl_we)
     // We always advance in this non-stalling D$
     ,.clear_i(1'b1)
     ,.data_o(v_tl_r)
     );

  // Save stage information
  bsg_dff_reset_en
   #(.width_p(dpath_width_gp+page_offset_width_gp+$bits(bp_be_dcache_decode_s)))
   tl_stage_reg
    (.clk_i(~clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tl_we)
     ,.data_i({dcache_pkt_cast_i.data, page_offset, decode_lo})
     ,.data_o({data_tl_r, page_offset_tl_r, decode_tl_r})
     );

  wire [paddr_width_p-1:0]         paddr_tl = {ptag_i, page_offset_tl_r};
  wire [sindex_width_lp-1:0] vaddr_index_tl = page_offset_tl_r[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0]  vaddr_bank_tl = page_offset_tl_r[byte_offset_width_lp+:bindex_width_lp];

  logic [assoc_p-1:0] load_hit_tl, store_hit_tl, way_v_tl;
  for (genvar i = 0; i < assoc_p; i++) begin: tag_comp_tl
    wire tag_match_tl      = (ptag_i == tag_mem_data_lo[i].tag);
    assign way_v_tl[i]     = (tag_mem_data_lo[i].state != e_COH_I);
    assign load_hit_tl[i]  = tag_match_tl & (tag_mem_data_lo[i].state != e_COH_I);
    assign store_hit_tl[i] = tag_match_tl & (tag_mem_data_lo[i].state inside {e_COH_M, e_COH_E});
  end

  logic [assoc_p-1:0] bank_sel_one_hot_tl;
  bsg_decode
   #(.num_out_p(assoc_p))
   offset_decode
    (.i(vaddr_bank_tl)
     ,.o(bank_sel_one_hot_tl)
     );

  bp_be_fp_reg_s fp_reg;
  assign fp_reg = data_tl_r;
  logic [dword_width_gp-1:0] fp_raw_data;
  bp_be_rec_to_fp
   #(.bp_params_p(bp_params_p))
   rec_to_fp
    (.rec_i(fp_reg.rec)

     ,.raw_sp_not_dp_i(fp_reg.sp_not_dp)
     ,.raw_o(fp_raw_data)
     );

  wire [dword_width_gp-1:0] st_data_tl = decode_tl_r.float_op ? fp_raw_data : data_tl_r;

  wire cached_op_tl   = ~uncached_i & ~decode_tl_r.fencei_op & ~decode_tl_r.l2_op;
  wire uncached_op_tl =  uncached_i | decode_tl_r.l2_op;

  /////////////////////////////////////////////////////////////////////////////
  // TV Stage
  /////////////////////////////////////////////////////////////////////////////
  logic uncached_op_tv_r, cached_op_tv_r;
  logic [paddr_width_p-1:0] paddr_tv_r;
  logic [dword_width_gp-1:0] st_data_tv_r;
  logic [assoc_p-1:0][bank_width_lp-1:0] ld_data_tv_r;
  logic [assoc_p-1:0] load_hit_tv_r, store_hit_tv_r, way_v_tv_r, bank_sel_one_hot_tv_r;
  bp_be_dcache_decode_s decode_tv_r;
  logic load_reservation_match_tv;

  // fencei does not require a ptag
  assign tv_we = v_tl_r & (ptag_v_i | decode_tl_r.fencei_op) & ~flush_i;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_tv_reg
    (.clk_i(~clk_i)
     ,.reset_i(reset_i)
     ,.set_i(tv_we)
     // We always advance in the non-stalling D$
     ,.clear_i(1'b1)
     ,.data_o(v_tv_r)
     );

  // TODO: We can combine the load data and store data
  logic [block_width_p-1:0] ld_data_tv_n;
  assign ld_data_tv_n = data_mem_data_lo;
  bsg_dff_en
   #(.width_p(block_width_p))
   ld_data_tv_reg
    (.clk_i(~clk_i)
     ,.en_i(tv_we & decode_tl_r.load_op)
     ,.data_i(ld_data_tv_n)
     ,.data_o(ld_data_tv_r)
     );

  bsg_dff_en
   #(.width_p(dword_width_gp))
   st_data_tv_reg
    (.clk_i(~clk_i)
     ,.en_i(tv_we & decode_tl_r.store_op)
     ,.data_i(st_data_tl)
     ,.data_o(st_data_tv_r)
     );

  bsg_dff_en
   #(.width_p(paddr_width_p+4*assoc_p+2+$bits(bp_be_dcache_decode_s)))
   tv_stage_reg
    (.clk_i(~clk_i)
     ,.en_i(tv_we)
     ,.data_i({paddr_tl
               ,bank_sel_one_hot_tl, way_v_tl, load_hit_tl, store_hit_tl
               ,uncached_op_tl, cached_op_tl
               ,decode_tl_r
               })
     ,.data_o({paddr_tv_r
               ,bank_sel_one_hot_tv_r, way_v_tv_r, load_hit_tv_r, store_hit_tv_r
               ,uncached_op_tv_r, cached_op_tv_r
               ,decode_tv_r
               })
     );

  logic [lg_dcache_assoc_lp-1:0] lru_encode;
  bsg_lru_pseudo_tree_encode
   #(.ways_p(assoc_p))
   lru_encoder
    (.lru_i(stat_mem_data_lo.lru)
     ,.way_id_o(lru_encode)
     );

  logic invalid_exist;
  logic [lg_dcache_assoc_lp-1:0] invalid_way;
  bsg_priority_encode
   #(.width_p(assoc_p), .lo_to_hi_p(1))
    pe_invalid
    (.i(~way_v_tv_r)
     ,.v_o(invalid_exist)
     ,.addr_o(invalid_way)
     );

  // If there is invalid way, then it take prioirty over LRU way.
  wire [lg_dcache_assoc_lp-1:0] lru_way_li = invalid_exist ? invalid_way : lru_encode;

  wire [3:0] byte_offset_tv = paddr_tv_r[0+:4];

  logic [lg_dcache_assoc_lp-1:0] store_hit_way_tv;
  logic store_hit_tv;
  bsg_encode_one_hot
   #(.width_p(assoc_p) ,.lo_to_hi_p(1))
   store_hit_index_encoder
    (.i(store_hit_tv_r)
     ,.addr_o(store_hit_way_tv)
     ,.v_o(store_hit_tv)
     );

  logic [lg_dcache_assoc_lp-1:0] load_hit_way_tv;
  logic load_hit_tv;
  bsg_encode_one_hot
   #(.width_p(assoc_p) ,.lo_to_hi_p(1))
   load_hit_index_encoder
    (.i(load_hit_tv_r)
     ,.addr_o(load_hit_way_tv)
     ,.v_o(load_hit_tv)
     );

  logic [assoc_p-1:0] ld_data_way_select;
  bsg_adder_one_hot
   #(.width_p(assoc_p))
   select_adder
    (.a_i(load_hit_tv_r)
     ,.b_i(bank_sel_one_hot_tv_r)
     ,.o(ld_data_way_select)
     );

  logic [bank_width_lp-1:0] ld_data_way_picked;
  bsg_mux_one_hot
   #(.width_p(bank_width_lp), .els_p(assoc_p))
   ld_data_set_select_mux
    (.data_i(ld_data_tv_r)
     ,.sel_one_hot_i(ld_data_way_select)
     ,.data_o(ld_data_way_picked)
     );

  logic [dword_width_gp-1:0] ld_data_dword_raw;
  bsg_mux
   #(.width_p(dword_width_gp), .els_p(num_dwords_per_bank_lp))
   dword_mux
    (.data_i(ld_data_way_picked)
     ,.sel_i(paddr_tv_r[3+:`BSG_SAFE_CLOG2(num_dwords_per_bank_lp)])
     ,.data_o(ld_data_dword_raw)
     );

  logic [dword_width_gp-1:0] ld_data_dword_merged;
  logic [dword_width_gp-1:0] result_data;
  bsg_mux
   #(.width_p(dword_width_gp), .els_p(2))
   final_data_mux
    (.data_i({uncached_load_data_r, ld_data_dword_merged})
     ,.sel_i(uncached_op_tv_r)
     ,.data_o(result_data)
     );

  logic [3:2][dword_width_gp-1:0] sigext_word;
  for (genvar i = 2; i < 4; i++)
    begin : word_alignment
      localparam slice_width_lp = 8*(2**i);

      logic [slice_width_lp-1:0] slice_data;
      bsg_mux
       #(.width_p(slice_width_lp), .els_p(dword_width_gp/slice_width_lp))
       align_mux
        (.data_i(result_data)
         ,.sel_i(paddr_tv_r[i+:`BSG_MAX(1, 3-i)])
         ,.data_o(slice_data)
         );

      wire sigext = decode_tv_r.signed_op & slice_data[slice_width_lp-1];
      assign sigext_word[i] = {{(dword_width_gp-slice_width_lp){sigext}}, slice_data};
    end

  logic [dword_width_gp-1:0] early_data;
  bsg_mux_one_hot
   #(.width_p(dword_width_gp), .els_p(2))
   word_mux
    (.data_i(sigext_word)
     ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op})
     ,.data_o(early_data)
     );

  // Load reserved misses if not in exclusive or modified (whether load hit or not)
  wire lr_hit_tv = v_tv_r & decode_tv_r.lr_op & store_hit_tv & (lr_sc_p == e_l1);
  // Succeed if the address matches and we have a store hit
  wire sc_success  = v_tv_r & decode_tv_r.sc_op & store_hit_tv & load_reservation_match_tv & (lr_sc_p == e_l1);
  // Fail if we have a store conditional without success
  wire sc_fail = v_tv_r & decode_tv_r.sc_op & ~sc_success;

  wire load_miss_tv   = v_tv_r & decode_tv_r.load_op & ~load_hit_tv & ~uncached_op_tv_r;
  wire store_miss_tv  = v_tv_r & decode_tv_r.store_op & ~decode_tv_r.sc_op & ~store_hit_tv & ~uncached_op_tv_r & (writethrough_p == 0);
  wire lr_miss_tv     = v_tv_r & decode_tv_r.lr_op & ~store_hit_tv & ~decode_tv_r.l2_op;
  wire engine_miss_tv = v_tv_r & (cache_req_v_o & ~cache_req_yumi_i);

  wire any_miss_tv = load_miss_tv | store_miss_tv | lr_miss_tv | engine_miss_tv;

  assign early_data_o = (decode_tv_r.sc_op & ~decode_tv_r.l2_op)
    ? (sc_success != 1'b1)
    : early_data;

  assign early_v_o = v_tv_r & ( (uncached_op_tv_r & (decode_tv_r.load_op & uncached_load_data_v_r))
                              | (uncached_op_tv_r & (decode_tv_r.store_op & cache_req_yumi_i))
                              | (decode_tv_r.fencei_op & (~gdirty_r | (coherent_p == 1)))
                              | (cached_op_tv_r & ~any_miss_tv)
                              );

  ///////////////////////////
  // Stat Mem Storage
  ///////////////////////////
  `bp_cast_i(bp_dcache_stat_mem_pkt_s, stat_mem_pkt);
  logic stat_mem_v_li;
  logic stat_mem_w_li;
  logic [sindex_width_lp-1:0] stat_mem_addr_li;
  bp_dcache_stat_info_s stat_mem_data_li;
  bp_dcache_stat_info_s stat_mem_mask_li;
  bp_dcache_stat_info_s stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
   #(.width_p(dcache_stat_info_width_lp)
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

  /////////////////////////////////////////////////////////////////////////////
  // DM Stage
  /////////////////////////////////////////////////////////////////////////////
  logic [dword_width_gp-1:0] data_dm_r;
  logic [3:0] byte_offset_dm_r;
  logic double_op_dm_r, word_op_dm_r, half_op_dm_r, byte_op_dm_r;
  logic signed_op_dm_r, float_op_dm_r;

  assign dm_we = v_tv_r & early_v_o & ~flush_i;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_dm_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(dm_we)
     // We always advance in the non-stalling D$
     ,.clear_i(1'b1)
     ,.data_o(v_dm_r)
     );

  bsg_dff_en
   #(.width_p(dword_width_gp+4+6))
   dm_stage_reg
    (.clk_i(clk_i)
     ,.en_i(dm_we)
     ,.data_i({result_data, byte_offset_tv
               ,decode_tv_r.double_op, decode_tv_r.word_op
               ,decode_tv_r.half_op, decode_tv_r.byte_op
               ,decode_tv_r.signed_op, decode_tv_r.float_op
               })
     ,.data_o({data_dm_r, byte_offset_dm_r
               ,double_op_dm_r, word_op_dm_r
               ,half_op_dm_r, byte_op_dm_r
               ,signed_op_dm_r, float_op_dm_r
               })
     );

  logic [3:0][dword_width_gp-1:0] sigext_byte;
  for (genvar i = 0; i < 4; i++)
    begin : byte_alignment
      localparam slice_width_lp = 8*(2**i);

      logic [slice_width_lp-1:0] slice_data;
      bsg_mux
       #(.width_p(slice_width_lp), .els_p(dword_width_gp/slice_width_lp))
       align_mux
        (.data_i(data_dm_r)
         ,.sel_i(byte_offset_dm_r[i+:`BSG_MAX(1, 3-i)])
         ,.data_o(slice_data)
         );

      wire sigext = signed_op_dm_r & slice_data[slice_width_lp-1];
      assign sigext_byte[i] = {{(dword_width_gp-slice_width_lp){sigext}}, slice_data};
    end

  logic [dword_width_gp-1:0] final_int_data;
  bsg_mux_one_hot
   #(.width_p(dword_width_gp), .els_p(4))
   byte_mux
    (.data_i(sigext_byte)
     ,.sel_one_hot_i({double_op_dm_r, word_op_dm_r, half_op_dm_r, byte_op_dm_r})
     ,.data_o(final_int_data)
     );

  bp_be_fp_reg_s final_float_data;
  bp_be_fp_to_rec
   #(.bp_params_p(bp_params_p))
   fp_to_rec
    (.raw_i(final_int_data)
     ,.raw_sp_not_dp_i(word_op_dm_r)

     ,.rec_sp_not_dp_o(final_float_data.sp_not_dp)
     ,.rec_o(final_float_data.rec)
     );

  assign final_data_o = float_op_dm_r ? final_float_data : final_int_data;
  assign final_v_o = v_dm_r;

  ///////////////////////////
  // Write buffer
  ///////////////////////////
  `declare_bp_be_dcache_wbuf_entry_s(paddr_width_p, assoc_p);
  bp_be_dcache_wbuf_entry_s wbuf_entry_in, wbuf_entry_out;
  logic wbuf_v_li, wbuf_v_lo, wbuf_yumi_li;

  assign wbuf_v_li = v_tv_r & decode_tv_r.store_op & store_hit_tv & ~sc_fail & ~uncached_op_tv_r & ~flush_i & ((writethrough_p == 0) || cache_req_yumi_i);

  logic [3:0][dword_width_gp-1:0] wbuf_data_in;
  logic [3:0][wbuf_data_mask_width_lp-1:0] wbuf_data_mem_mask_in;
  for (genvar i = 0; i < 4; i++)
    begin : wbuf_in
      localparam slice_width_lp = 8*(2**i);
      logic [slice_width_lp-1:0] slice_data;

      logic [(dword_width_gp/slice_width_lp)-1:0] addr_dec;
      bsg_decode
       #(.num_out_p(dword_width_gp/slice_width_lp))
       decode
        (.i(paddr_tv_r[i+:`BSG_MAX(3-i,1)])
         ,.o(addr_dec)
         );

      bsg_expand_bitmask
       #(.in_width_p(dword_width_gp/slice_width_lp), .expand_p(2**i))
       expand
        (.i(addr_dec)
         ,.o(wbuf_data_mem_mask_in[i])
         );

      assign slice_data = st_data_tv_r[0+:slice_width_lp];
      assign wbuf_data_in[i] = {(dword_width_gp/slice_width_lp){slice_data}};
    end

  bsg_mux_one_hot
   #(.width_p(dword_width_gp), .els_p(4))
   wbuf_data_in_mux
    (.data_i(wbuf_data_in)
     ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op, decode_tv_r.half_op, decode_tv_r.byte_op})
     ,.data_o(wbuf_entry_in.data)
     );

  bsg_mux_one_hot
   #(.width_p(wbuf_data_mask_width_lp), .els_p(4))
   wbuf_data_mem_mask_in_mux
    (.data_i(wbuf_data_mem_mask_in)
     ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op, decode_tv_r.half_op, decode_tv_r.byte_op})
     ,.data_o(wbuf_entry_in.mask)
     );
  assign wbuf_entry_in.paddr = paddr_tv_r;
  assign wbuf_entry_in.way_id = store_hit_way_tv;

  wire [paddr_width_p-1:0] ld_addr_tl = {ptag_i, page_offset_tl_r};
  bp_be_dcache_wbuf
   #(.bp_params_p(bp_params_p))
   wbuf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(wbuf_v_li)
     ,.wbuf_entry_i(wbuf_entry_in)

     ,.v_o(wbuf_v_lo)
     ,.yumi_i(wbuf_yumi_li)
     ,.wbuf_entry_o(wbuf_entry_out)

     ,.load_addr_i(ld_addr_tl)
     ,.load_data_i(ld_data_dword_raw)
     ,.data_merged_o(ld_data_dword_merged)
     );
  wire [bindex_width_lp-1:0] wbuf_entry_out_bank_offset = wbuf_entry_out.paddr[byte_offset_width_lp+:bindex_width_lp];
  wire [sindex_width_lp-1:0] wbuf_entry_out_index = wbuf_entry_out.paddr[block_offset_width_lp+:sindex_width_lp];

  /////////////////////////////////////////////////////////////////////////////
  // Slow Path
  /////////////////////////////////////////////////////////////////////////////
  localparam bp_cache_req_size_e block_req_size = bp_cache_req_size_e'(`BSG_SAFE_CLOG2(block_width_p/8));
  `bp_cast_o(bp_dcache_req_s, cache_req);
  `bp_cast_o(bp_dcache_req_metadata_s, cache_req_metadata);

  wire cached_req         = v_tv_r & (store_miss_tv | load_miss_tv | lr_miss_tv);
  wire fencei_req         = v_tv_r & decode_tv_r.fencei_op & gdirty_r & (coherent_p == 0);
  wire uncached_load_req  = v_tv_r & decode_tv_r.load_op & uncached_op_tv_r & ~uncached_load_data_v_r;
  wire uncached_store_req = v_tv_r & decode_tv_r.store_op & uncached_op_tv_r;
  wire wt_req             = v_tv_r & decode_tv_r.store_op & ~sc_fail & ~uncached_op_tv_r & (writethrough_p == 1);
  wire l2_amo_req         = v_tv_r & decode_tv_r.l2_op & ~uncached_load_data_v_r;

  assign cache_req_v_o = ~flush_i & |{cached_req, uncached_load_req, uncached_store_req, fencei_req, l2_amo_req, wt_req};

  always_comb
    begin
      cache_req_cast_o = '0;
      cache_req_cast_o.addr = paddr_tv_r;
      cache_req_cast_o.data = wbuf_entry_in.data;

      // Assigning sizes to cache miss packet
      if (uncached_load_req | uncached_store_req | wt_req | l2_amo_req)
        begin
          unique if (decode_tv_r.double_op)
            cache_req_cast_o.size = e_size_8B;
          else if (decode_tv_r.word_op)
            cache_req_cast_o.size = e_size_4B;
          else if (decode_tv_r.half_op)
            cache_req_cast_o.size = e_size_2B;
          else if (decode_tv_r.byte_op)
            cache_req_cast_o.size = e_size_1B;
        end
      else
        begin
            cache_req_cast_o.size = block_req_size;
        end

      if (load_miss_tv)
        cache_req_cast_o.msg_type = e_miss_load;
      else if (lr_miss_tv)
        cache_req_cast_o.msg_type = e_miss_store;
      else if (store_miss_tv)
        cache_req_cast_o.msg_type = e_miss_store;
      else if (wt_req)
        cache_req_cast_o.msg_type = e_wt_store;
      else if (uncached_load_req)
        cache_req_cast_o.msg_type = e_uc_load;
      else if (uncached_store_req)
        cache_req_cast_o.msg_type = e_uc_store;
      else if (fencei_req)
        cache_req_cast_o.msg_type = e_cache_flush;
      else
        begin
          unique casez (decode_tv_r.amo_subop)
            e_dcache_subop_lr     : cache_req_cast_o.msg_type = e_amo_lr;
            e_dcache_subop_sc     : cache_req_cast_o.msg_type = e_amo_sc;
            e_dcache_subop_amoswap: cache_req_cast_o.msg_type = e_amo_swap;
            e_dcache_subop_amoadd : cache_req_cast_o.msg_type = e_amo_add;
            e_dcache_subop_amoxor : cache_req_cast_o.msg_type = e_amo_xor;
            e_dcache_subop_amoand : cache_req_cast_o.msg_type = e_amo_and;
            e_dcache_subop_amoor  : cache_req_cast_o.msg_type = e_amo_or;
            e_dcache_subop_amomin : cache_req_cast_o.msg_type = e_amo_min;
            e_dcache_subop_amomax : cache_req_cast_o.msg_type = e_amo_max;
            e_dcache_subop_amominu: cache_req_cast_o.msg_type = e_amo_minu;
            //e_dcache_subop_amomaxu
            default               : cache_req_cast_o.msg_type = e_amo_maxu;
          endcase
        end
    end

  // Cache metadata is valid after the request goes out,
  //   but no metadata for uncached stores, writethroughs, or flushes
  wire cache_req_metadata_v = (cache_req_yumi_i & ~uncached_store_req & ~wt_req & ~fencei_req);
  bsg_dff_reset
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_metadata_v)
     ,.data_o(cache_req_metadata_v_o)
     );

  assign cache_req_metadata_cast_o.repl_way = lru_way_li;
  assign cache_req_metadata_cast_o.dirty = stat_mem_data_lo.dirty[lru_way_li];

  /////////////////////////////////////////////////////////////////////////////
  // State machine
  //   e_ready  : Cache is ready to accept requests
  //   e_miss   : Cache is waiting for a miss to be serviced
  //   e_fence  : Cache is waiting for a fence to be resolved
  /////////////////////////////////////////////////////////////////////////////
  always_comb
    case (state_r)
      e_ready: state_n = (cache_req_yumi_i & decode_tv_r.fencei_op)
                         ? e_fence
                           // Uncached stores and writethrough requests are non-blocking
                         : (cache_req_yumi_i & ~uncached_store_req & ~wt_req)
                           ? e_miss
                           : e_ready;
      e_miss : state_n = cache_req_complete_i ? e_ready : e_miss;
      e_fence: state_n = cache_req_complete_i ? e_ready : e_fence;
      default: state_n = e_ready;
    endcase

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  assign ready_o = ~cache_req_busy_i & is_ready;

  /////////////////////////////////////////////////////////////////////////////
  // SRAM Control
  /////////////////////////////////////////////////////////////////////////////

  ///////////////////////////
  // Tag Mem Control
  ///////////////////////////
  wire tag_mem_fast_read = (tl_we & ~decode_lo.fencei_op & ~decode_lo.l2_op);
  wire tag_mem_slow_read = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_read);
  wire tag_mem_slow_write = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode != e_cache_tag_mem_read);
  assign tag_mem_v_li = tag_mem_fast_read | tag_mem_slow_read | tag_mem_slow_write;
  assign tag_mem_w_li = tag_mem_slow_write;
  assign tag_mem_addr_li = tag_mem_fast_read
    ? vaddr_index
    : tag_mem_pkt_cast_i.index;
  assign tag_mem_pkt_yumi_o = ~cache_lock & tag_mem_pkt_v_i & ~tag_mem_fast_read;

  logic [assoc_p-1:0] tag_mem_way_one_hot;
  bsg_decode
    #(.num_out_p(assoc_p))
    tag_mem_way_decode
      (.i(tag_mem_pkt_cast_i.way_id)
      ,.o(tag_mem_way_one_hot)
      );

  always_comb
    for (integer i = 0; i < assoc_p; i++)
      case (tag_mem_pkt_cast_i.opcode)
        e_cache_tag_mem_set_tag:
          begin
            tag_mem_data_li[i] = '{state: tag_mem_pkt_cast_i.state, tag: tag_mem_pkt_cast_i.tag};
            tag_mem_mask_li[i] = '{state: {$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}
                                   ,tag : {ctag_width_p{tag_mem_way_one_hot[i]}}
                                   };
          end
        e_cache_tag_mem_set_state:
          begin
            tag_mem_data_li[i] = '{state: tag_mem_pkt_cast_i.state, tag: '0};
            tag_mem_mask_li[i] = '{state: {$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}, tag: '0};
          end
        default: // e_cache_tag_mem_set_clear
          begin
            tag_mem_data_li[i] = '{state: bp_coh_states_e'('0), tag: '0};
            tag_mem_mask_li[i] = '{state: bp_coh_states_e'('1), tag: '1};
          end
      endcase

  logic [lg_dcache_assoc_lp-1:0] tag_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_dcache_assoc_lp))
   tag_mem_pkt_way_reg
    (.clk_i(~clk_i)
     ,.data_i(tag_mem_pkt_cast_i.way_id)
     ,.data_o(tag_mem_pkt_way_r)
     );

  assign tag_mem_o = tag_mem_data_lo[tag_mem_pkt_way_r];

  ///////////////////////////
  // Data Mem Control
  ///////////////////////////
  logic [block_size_in_fill_lp-1:0][fill_size_in_bank_lp-1:0] data_mem_pkt_fill_mask_expanded;
  for (genvar i = 0; i < block_size_in_fill_lp; i++)
    begin : fill_mask
      assign data_mem_pkt_fill_mask_expanded[i] = {fill_size_in_bank_lp{data_mem_pkt_cast_i.fill_index[i]}};
    end

  logic [assoc_p-1:0] data_mem_write_bank_mask;
  wire [`BSG_SAFE_CLOG2(assoc_p)-1:0] write_mask_rot_li = data_mem_pkt_cast_i.way_id;
  bsg_rotate_left
   #(.width_p(assoc_p))
   write_mask_rotate
    (.data_i(data_mem_pkt_fill_mask_expanded)
     ,.rot_i(write_mask_rot_li)
     ,.o(data_mem_write_bank_mask)
     );

  logic [assoc_p-1:0][bank_width_lp-1:0] data_mem_pkt_data_li;
  wire [`BSG_SAFE_CLOG2(block_width_p)-1:0] write_data_rot_li = data_mem_pkt_cast_i.way_id*bank_width_lp;
  wire [block_width_p-1:0] data_mem_pkt_data_expanded = {block_size_in_fill_lp{data_mem_pkt_cast_i.data}};
  bsg_rotate_left
   #(.width_p(block_width_p))
   write_data_rotate
    (.data_i(data_mem_pkt_data_expanded)
     ,.rot_i(write_data_rot_li)
     ,.o(data_mem_pkt_data_li)
     );

  logic [assoc_p-1:0] wbuf_bank_sel_one_hot;
  wire [bindex_width_lp-1:0] wbuf_data_mem_offset =
    (bindex_width_lp'(wbuf_entry_out.way_id) + wbuf_entry_out_bank_offset);
  bsg_decode
   #(.num_out_p(assoc_p))
   wbuf_bank_sel_one_hot_decode
    (.i(wbuf_data_mem_offset)
     ,.o(wbuf_bank_sel_one_hot)
     );

  localparam dword_mask_width_lp = `BSG_SAFE_CLOG2(num_dwords_per_bank_lp);
  wire [dword_mask_width_lp-1:0] wbuf_dword_sel = wbuf_entry_out.paddr[3+:dword_mask_width_lp];
  wire [byte_offset_width_lp-1:0] mask_shift = (num_dwords_per_bank_lp > 1)
    ? (wbuf_dword_sel << 3)
    : '0;
  wire [data_mem_mask_width_lp-1:0] wbuf_data_mem_mask = wbuf_entry_out.mask << mask_shift;

  logic [assoc_p-1:0] data_mem_fast_read, data_mem_fast_write, data_mem_slow_read, data_mem_slow_write;
  for (genvar i = 0; i < assoc_p; i++)
    begin : data_mem_lines
      assign data_mem_slow_write[i] = data_mem_pkt_yumi_o
        & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_write) & data_mem_write_bank_mask[i];
      assign data_mem_slow_read[i] = data_mem_pkt_yumi_o
        & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_read);
      assign data_mem_fast_read[i] = tl_we & decode_lo.load_op;
      assign data_mem_fast_write[i] = wbuf_yumi_li & wbuf_bank_sel_one_hot[i];

      assign data_mem_v_li[i] = data_mem_fast_read[i]
        | data_mem_fast_write[i]
        | data_mem_slow_read[i]
        | data_mem_slow_write[i];
      assign data_mem_w_li[i] = (wbuf_yumi_li & wbuf_bank_sel_one_hot[i])
        | data_mem_slow_write[i];

      assign data_mem_mask_li[i] = (wbuf_yumi_li & wbuf_bank_sel_one_hot[i])
        ? wbuf_data_mem_mask
        : {data_mem_mask_width_lp{data_mem_write_bank_mask[i]}};

      wire [bindex_width_lp-1:0] data_mem_pkt_offset = (bindex_width_lp'(i) - data_mem_pkt_cast_i.way_id);
      assign data_mem_addr_li[i] = data_mem_fast_read[i]
        ? {vaddr_index, {(assoc_p > 1){vaddr_bank}}}
        : (wbuf_yumi_li & wbuf_bank_sel_one_hot[i])
          ? {wbuf_entry_out_index, {(assoc_p > 1){wbuf_entry_out_bank_offset}}}
          : {data_mem_pkt_cast_i.index, {(assoc_p > 1){data_mem_pkt_offset}}};

      assign data_mem_data_li[i] = (wbuf_yumi_li & wbuf_bank_sel_one_hot[i])
        ? {num_dwords_per_bank_lp{wbuf_entry_out.data}}
        : data_mem_pkt_data_li[i];
    end
  assign wbuf_yumi_li = wbuf_v_lo & ~|data_mem_fast_read;

  // As an optimization, we could snoop the data_mem_pkt to see if there are any matching entries
  //   in the write buffer, so that the write buffer will only drain if it is full, or if there is
  //   a snoop match. However, this is a critical path, so we drain the write buffer on invalidations.
  // A similar scheme could be adopted for a non-blocking version, where we snoop the bank
  assign data_mem_pkt_yumi_o = (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached)
                               ? ~cache_lock & data_mem_pkt_v_i
                               : ~cache_lock & data_mem_pkt_v_i & ~(decode_lo.load_op & tl_we) & ~wbuf_v_lo & ~wbuf_v_li;


  logic [lg_dcache_assoc_lp-1:0] data_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_dcache_assoc_lp))
   data_mem_pkt_way_reg
    (.clk_i(~clk_i)
     ,.data_i(data_mem_pkt_cast_i.way_id)
     ,.data_o(data_mem_pkt_way_r)
     );

  wire [`BSG_SAFE_CLOG2(block_width_p)-1:0] read_data_rot_li = data_mem_pkt_way_r*bank_width_lp;
  bsg_rotate_right
   #(.width_p(block_width_p))
   read_data_rotate
    (.data_i(data_mem_data_lo)
     ,.rot_i(read_data_rot_li)
     ,.o(data_mem_o)
     );

  ///////////////////////////
  // Stat Mem Control
  ///////////////////////////
  wire stat_mem_fast_read = ~flush_i & (v_tv_r & ~early_v_o & ~uncached_op_tv_r);
  wire stat_mem_fast_write = ~flush_i & (v_tv_r & early_v_o & ~uncached_op_tv_r);
  wire stat_mem_slow_write = stat_mem_pkt_yumi_o & (stat_mem_pkt_cast_i.opcode != e_cache_stat_mem_read);
  wire stat_mem_slow_read  = stat_mem_pkt_yumi_o & (stat_mem_pkt_cast_i.opcode == e_cache_stat_mem_read);
  assign stat_mem_v_li = stat_mem_fast_read | stat_mem_fast_write
      | (stat_mem_slow_write | stat_mem_slow_read);
  assign stat_mem_w_li = stat_mem_fast_write | stat_mem_slow_write;
  assign stat_mem_addr_li = (stat_mem_fast_write | stat_mem_fast_read)
    ? paddr_tv_r[block_offset_width_lp+:sindex_width_lp]
    : stat_mem_pkt_cast_i.index;
  assign stat_mem_pkt_yumi_o = ~(v_tv_r & ~uncached_op_tv_r) & ~cache_lock & stat_mem_pkt_v_i;

  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_data_lo;
  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_mask_lo;
  wire [lg_dcache_assoc_lp-1:0] lru_decode_way_li =
    v_tv_r ? decode_tv_r.store_op ? store_hit_way_tv : load_hit_way_tv : stat_mem_pkt_cast_i.way_id;
  bsg_lru_pseudo_tree_decode
   #(.ways_p(assoc_p))
   lru_decode
    (.way_id_i(lru_decode_way_li)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
     );

  logic [assoc_p-1:0] dirty_mask_lo;
  if (writethrough_p == 0)
    begin : td
      wire dirty_mask_v_li = stat_mem_slow_write || (v_tv_r & decode_tv_r.store_op);
      wire [lg_dcache_assoc_lp-1:0] dirty_mask_way_li = v_tv_r ? store_hit_way_tv : stat_mem_pkt_cast_i.way_id;
      bsg_decode_with_v
       #(.num_out_p(assoc_p))
       dirty_mask_decode
        (.i(dirty_mask_way_li)
         ,.v_i(dirty_mask_v_li)
         ,.o(dirty_mask_lo)
         );

      // Maintain a global dirty bit for the cache. When data is written to the write buffer, we set
      //   it. When we send a flush request to the CE, we clear it.
      // The way this works with fence.i is:
      //   1) If dirty bit is set, we force a miss and send off a flush request to the CE
      //   2) If dirty bit is not set, we do not send a request and simply return valid flush.
      //        The CSR unit is now responsible for sending the clear request to the I$.
      wire set_dirty = wbuf_v_li;
      wire clear_dirty = (is_fence & cache_req_complete_i);
      bsg_dff_reset_set_clear
       #(.width_p(1))
       gdirty_reg
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.set_i(set_dirty)
        ,.clear_i(clear_dirty)

        ,.data_o(gdirty_r)
        );
    end
  else
    begin : ntd
      // We don't track dirty
      // Note: This will synthesize out of stat_mem...unless hardened
      assign dirty_mask_lo = '0;
      assign gdirty_r     = '0;
    end

  always_comb 
    case ({v_tv_r, stat_mem_pkt_cast_i.opcode})
      {1'b0, e_cache_stat_mem_set_clear}:
        begin
          stat_mem_data_li = '0;
          stat_mem_mask_li = '{lru: '1, dirty: '1};
        end
      {1'b0, e_cache_stat_mem_clear_dirty}:
        begin
          stat_mem_data_li = '0;
          stat_mem_mask_li = '{lru: '0, dirty: dirty_mask_lo};
        end
      default : // v_tv_r
        begin
          stat_mem_data_li = '{lru: lru_decode_data_lo, dirty: '1};
          stat_mem_mask_li = '{lru: lru_decode_mask_lo, dirty: dirty_mask_lo};
        end
    endcase

  logic [lg_dcache_assoc_lp-1:0] stat_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_dcache_assoc_lp))
   stat_mem_pkt_way_reg
    (.clk_i(clk_i)
     ,.data_i(stat_mem_pkt_cast_i.way_id)
     ,.data_o(stat_mem_pkt_way_r)
     );

  assign stat_mem_o = stat_mem_data_lo;

  /////////////////////////////////////////////////////////////////////////////
  // Load Reservation
  /////////////////////////////////////////////////////////////////////////////
  if (lr_sc_p == e_l1)
    begin : l1_lrsc
      logic [sindex_width_lp-1:0] load_reserved_index_r;
      logic [ctag_width_p-1:0] load_reserved_tag_r;
      logic load_reserved_v_r;

      // Set reservation on successful LR, without a cache miss or upgrade request
      wire set_reservation = decode_tv_r.lr_op & early_v_o;
      // All SCs clear the reservation (regardless of success)
      // Invalidates from other harts which match the reservation address clear the reservation
      // Also invalidate on trap
      wire clear_reservation = decode_tv_r.sc_op
        || flush_i
        || (tag_mem_pkt_yumi_o
            & (tag_mem_pkt_cast_i.index == load_reserved_index_r)
            & (tag_mem_pkt_cast_i.tag == load_reserved_tag_r));
      bsg_dff_reset_set_clear
       #(.width_p(1), .clear_over_set_p(1))
       load_reserved_v_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(set_reservation)
         ,.clear_i(clear_reservation)
         ,.data_o(load_reserved_v_r)
         );

      wire [sindex_width_lp-1:0] paddr_index_tv = paddr_tv_r[block_offset_width_lp+:sindex_width_lp];
      wire [ctag_width_p-1:0]    paddr_tag_tv   = paddr_tv_r[block_offset_width_lp+sindex_width_lp+:ctag_width_p];
      bsg_dff_en
       #(.width_p(ctag_width_p+sindex_width_lp))
       load_reserved_addr
        (.clk_i(clk_i)
         ,.en_i(set_reservation)
         ,.data_i({paddr_tag_tv, paddr_index_tv})
         ,.data_o({load_reserved_tag_r, load_reserved_index_r})
         );

        assign load_reservation_match_tv = load_reserved_v_r
          & (load_reserved_index_r == paddr_index_tv)
          & (load_reserved_tag_r == paddr_tag_tv);

        // Linear backoff
        localparam lock_max_limit_lp = 8;
        logic [`BSG_SAFE_CLOG2(lock_max_limit_lp+1)-1:0] lock_cnt_r;
        wire lock_clr = early_v_o || (lock_cnt_r == lock_max_limit_lp);
        wire lock_inc = ~lock_clr & (lr_hit_tv || (lock_cnt_r > 0));
        bsg_counter_clear_up
         #(.max_val_p(lock_max_limit_lp), .init_val_p(0))
         lock_counter
          (.clk_i(clk_i)
           ,.reset_i(reset_i)

           ,.clear_i(lock_clr)
           ,.up_i(lock_inc)
           ,.count_o(lock_cnt_r)
           );
        assign cache_lock = (lock_cnt_r != '0);
    end
  else
    begin : no_l1_lrsc
        assign load_reservation_match_tv = '0;
        assign cache_lock                = '0;
    end

  ///////////////////////////
  // Uncached Load Storage
  // Note: Goes away with idempotency-handling D$
  ///////////////////////////
  wire uncached_load_set = data_mem_pkt_yumi_o & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached);
  // Invalidate uncached data if the cache is flushed or we successfully complete the request
  // NOTE: This method is not valid for non-idempotent loads, will cause replay
  wire uncached_load_clear = flush_i | early_v_o;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   uncached_load_data_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(uncached_load_set)
     ,.clear_i(uncached_load_clear)
     ,.data_o(uncached_load_data_v_r)
     );

  bsg_dff_en
   #(.width_p(dword_width_gp))
   uncached_load_data_reg
    (.clk_i(clk_i)
     ,.en_i(uncached_load_set)

     ,.data_i(data_mem_pkt_cast_i.data[0+:dword_width_gp])
     ,.data_o(uncached_load_data_r)
     );

  // synopsys translate_off
  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  always_ff @(negedge clk_i)
    begin
      assert(~v_tv_r || $countones(load_hit_tl) <= 1)
        else $error("multiple load hit: %b. id = %0d. addr = %H", load_hit_tl, cfg_bus_cast_i.dcache_id, ptag_i);
      assert(~v_tv_r || $countones(store_hit_tl) <= 1)
        else $error("multiple store hit: %b. id = %0d. addr = %H", store_hit_tl, cfg_bus_cast_i.dcache_id, ptag_i);
    end

  if (!(assoc_p == 8 | assoc_p == 4 | assoc_p == 2 | assoc_p == 1))
    begin
      $error("assoc_p has to be 8, 4, 2 or 1");
    end
  // synopsys translate_on

endmodule

