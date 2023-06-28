/**
 *  Name:
 *    bp_be_dcache.v
 *
 *  Description:
 *    L1 Data Cache. Features:
 *    - Virtually-indexed, physically-tagged
 *    - 1-8 way set-associative
 *    - 64-512 bit block size (minimum 64-bit data mem bank size)
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
 *    There are two pipeline stages: tag lookup (TL), tag verify (TV) stages.
 *      Signals and registers are suffixed by stage name.
 *
 *    - Before TL, a dcache_pkt containing opcode, address and store data arrives
 *        at the cache. It is decoded and latched.
 *
 *    - In TL, data mem and tag mem are synchronously accessed. Addtionally, the
 *        physical tag and PMA attributes arrive and are latched. Hit detection is
 *        also performed in this stage.
 *
 *    - In TV, the data read is muxed down to the correct word based on the bank hash
 *        of the hit vector and the word offset.
 *
 *    There is a write buffer which allows holding write data from tv stage, delaying the
 *      physical write until data_mem becomes from from incoming loads. To prevent data
 *      hazards, it also supports bypassing from TV to TL if there is an address match in
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
   , parameter coherent_p            = dcache_features_p[e_cfg_coherent]
   , parameter writeback_p           = dcache_features_p[e_cfg_writeback]
   , parameter [31:0] amo_support_p  = (((dcache_features_p[e_cfg_lr_sc]) << e_dcache_subop_lr)
                                        | ((dcache_features_p[e_cfg_lr_sc]) << e_dcache_subop_sc)
                                        | ((dcache_features_p[e_cfg_amo_swap]) << e_dcache_subop_amoswap)
                                        | ((dcache_features_p[e_cfg_amo_fetch_arithmetic]) << e_dcache_subop_amoadd)
                                        | ((dcache_features_p[e_cfg_amo_fetch_logic]) << e_dcache_subop_amoxor)
                                        | ((dcache_features_p[e_cfg_amo_fetch_logic]) << e_dcache_subop_amoand)
                                        | ((dcache_features_p[e_cfg_amo_fetch_logic]) << e_dcache_subop_amoor)
                                        | ((dcache_features_p[e_cfg_amo_fetch_arithmetic]) << e_dcache_subop_amomin)
                                        | ((dcache_features_p[e_cfg_amo_fetch_arithmetic]) << e_dcache_subop_amomax)
                                        | ((dcache_features_p[e_cfg_amo_fetch_arithmetic]) << e_dcache_subop_amominu)
                                        | ((dcache_features_p[e_cfg_amo_fetch_arithmetic]) << e_dcache_subop_amomaxu)
                                        )
   , parameter sets_p         = dcache_sets_p
   , parameter assoc_p        = dcache_assoc_p
   , parameter block_width_p  = dcache_block_width_p
   , parameter fill_width_p   = dcache_fill_width_p
   , parameter ctag_width_p   = dcache_ctag_width_p

   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, dcache)

   , localparam cfg_bus_width_lp    = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dcache_pkt_width_lp = `bp_be_dcache_pkt_width(vaddr_width_p)
   )
  (input                                             clk_i
   , input                                           reset_i

   // Unused except for tracers
   , input [cfg_bus_width_lp-1:0]                    cfg_bus_i

   // Cycle 0: "Request"
   // New D$ packet comes in
   , input [dcache_pkt_width_lp-1:0]                 dcache_pkt_i
   , input                                           v_i
   , output logic                                    ready_and_o
   , output logic                                    ordered_o

   // Cycle 1: "Tag Lookup"
   // TLB and PMA information comes in this cycle
   , input [ptag_width_p-1:0]                        ptag_i
   , input                                           ptag_v_i
   , input                                           ptag_uncached_i
   , input                                           ptag_dram_i
   , input [dword_width_gp-1:0]                      st_data_i
   , input                                           flush_i

   // Cycle 2: "Tag Verify"
   // Data (or miss result) comes out of the cache
   , output logic                                    v_o
   , output logic [dword_width_gp-1:0]               data_o
   , output logic [reg_addr_width_gp-1:0]            rd_addr_o
   , output logic                                    fencei_o
   , output logic                                    float_o
   , output logic                                    ret_o
   , output logic                                    late_o
   , output logic                                    store_o
   , output logic                                    req_o

   // Cache Engine Interface
   // This is considered the "slow path", handling uncached requests
   //   and fill DMAs. It also handles coherence transactions for
   //   configurations which support that behavior
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_busy_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input [paddr_width_p-1:0]                       cache_req_addr_i
   , input                                           cache_req_critical_i
   , input                                           cache_req_last_i
   // Unused
   , input                                           cache_req_credits_full_i
   , input                                           cache_req_credits_empty_i

   , input                                           data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
   , output logic                                    data_mem_pkt_yumi_o
   , output logic [block_width_p-1:0]                data_mem_o

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

  localparam lg_assoc_lp              = `BSG_SAFE_CLOG2(assoc_p);
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
  enum logic {e_ready, e_miss} state_n, state_r;
  wire is_ready  = (state_r == e_ready);
  wire is_miss   = (state_r == e_miss);

  // Global signals
  logic tl_we, tv_we;
  logic safe_tl_we, safe_tv_we;
  logic v_tl_r, v_tv_r;
  logic gdirty_r;
  logic tag_mem_write_hazard, data_mem_write_hazard, blocking_hazard, engine_hazard;
  logic blocking_sent, nonblocking_sent;

  wire flush_self = flush_i | tag_mem_write_hazard | data_mem_write_hazard | blocking_hazard | engine_hazard;
  wire critical_recv = cache_req_critical_i
    & (~stat_mem_pkt_v_i | stat_mem_pkt_yumi_o)
    & (~tag_mem_pkt_v_i | tag_mem_pkt_yumi_o)
    & (~data_mem_pkt_v_i | data_mem_pkt_yumi_o);
  wire complete_recv = cache_req_last_i
    & (~stat_mem_pkt_v_i | stat_mem_pkt_yumi_o)
    & (~tag_mem_pkt_v_i | tag_mem_pkt_yumi_o)
    & (~data_mem_pkt_v_i | data_mem_pkt_yumi_o);

  // Snoop signals
  logic snoop_uncached_op_r;
  logic [dword_width_gp-1:0] snoop_st_data_r;
  bp_be_dcache_decode_s snoop_decode_r;
  logic [block_width_p-1:0] snoop_data;
  logic [paddr_width_p-1:0] snoop_addr;
  logic [2:0][assoc_p-1:0] snoop_hit;
  logic [assoc_p-1:0] snoop_bank_sel_one_hot;

  /////////////////////////////////////////////////////////////////////////////
  // Decode Stage
  /////////////////////////////////////////////////////////////////////////////
  `declare_bp_be_dcache_pkt_s(vaddr_width_p);
  `bp_cast_i(bp_be_dcache_pkt_s, dcache_pkt);

  bp_be_dcache_decode_s decode_lo;
  bp_be_dcache_decoder
   #(.bp_params_p(bp_params_p), .amo_support_p(amo_support_p))
   pkt_decoder
    (.pkt_i(dcache_pkt_i)
     ,.decode_o(decode_lo)
     );

  wire [vaddr_width_p-1:0]         vaddr       = dcache_pkt_cast_i.vaddr;
  wire [sindex_width_lp-1:0]       vaddr_index = vaddr[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0]       vaddr_bank  = vaddr[byte_offset_width_lp+:bindex_width_lp];
  wire [vtag_width_p-1:0]          vaddr_tag   = vaddr[vaddr_width_p-1-:vtag_width_p];

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
     (.clk_i(clk_i)
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
        (.clk_i(clk_i)
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
  logic [vaddr_width_p-1:0] vaddr_tl_r;

  assign safe_tl_we = ready_and_o & v_i;
  assign tl_we = safe_tl_we & ~flush_self;
  bsg_dff_reset
   #(.width_p(1))
   v_tl_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(tl_we)
     ,.data_o(v_tl_r)
     );

  // Save stage information
  bsg_dff
   #(.width_p(vaddr_width_p+$bits(bp_be_dcache_decode_s)))
   tl_stage_reg
    (.clk_i(clk_i)
     ,.data_i({vaddr, decode_lo})
     ,.data_o({vaddr_tl_r, decode_tl_r})
     );

  wire [paddr_width_p-1:0]         paddr_tl = {ptag_i, vaddr_tl_r[0+:page_offset_width_gp]};
  wire [sindex_width_lp-1:0] vaddr_index_tl = vaddr_tl_r[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0]  vaddr_bank_tl = vaddr_tl_r[byte_offset_width_lp+:bindex_width_lp];

  // Concatenate unused bits from vaddr if any cache way size is not 4kb
  localparam ctag_vbits_lp = page_offset_width_gp - (block_offset_width_lp + sindex_width_lp);
  wire [ctag_vbits_lp-1:0] ctag_vbits = vaddr_tl_r[block_offset_width_lp+sindex_width_lp+:`BSG_MAX(ctag_vbits_lp,1)];
  // Causes segfault in Synopsys DC O-2018.06-SP4
  // wire [ctag_width_p-1:0] ctag_li = {ptag_i, {ctag_vbits_lp!=0{ctag_vbits}}};
  wire [ctag_width_p-1:0] ctag_li = ctag_vbits_lp ? {ptag_i, ctag_vbits} : ptag_i;

  logic [assoc_p-1:0] way_v_tl, load_hit_tl, store_hit_tl;
  for (genvar i = 0; i < assoc_p; i++) begin: tag_comp_tl
    wire tag_match_tl      = (ctag_li == tag_mem_data_lo[i].tag);
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

  wire uncached_op_tl =  ptag_uncached_i | decode_tl_r.uncached_op;
  wire dram_op_tl =  ptag_dram_i;
  wire [dword_width_gp-1:0] st_data_tl = st_data_i;

  /////////////////////////////////////////////////////////////////////////////
  // TV Stage
  /////////////////////////////////////////////////////////////////////////////
  logic uncached_op_tv_r, snoop_tv_r;
  logic [paddr_width_p-1:0] paddr_tv_r;
  logic [dword_width_gp-1:0] st_data_tv_r;
  logic [assoc_p-1:0][bank_width_lp-1:0] ld_data_tv_r;
  logic [assoc_p-1:0] load_hit_v_tv_r, store_hit_v_tv_r, way_v_tv_r, bank_sel_one_hot_tv_r;
  bp_be_dcache_decode_s decode_tv_r;
  logic load_reservation_match_tv;
  wire [bindex_width_lp-1:0] paddr_bank_tv  = paddr_tv_r[byte_offset_width_lp+:bindex_width_lp];
  wire [sindex_width_lp-1:0] paddr_index_tv = paddr_tv_r[block_offset_width_lp+:sindex_width_lp];
  wire [ctag_width_p-1:0]    paddr_tag_tv   = paddr_tv_r[block_offset_width_lp+sindex_width_lp+:ctag_width_p];

  // fencei does not require a ptag
  assign safe_tv_we = v_tl_r & (ptag_v_i | decode_tl_r.fencei_op);
  assign tv_we = safe_tv_we & ~flush_self;
  bsg_dff_reset
   #(.width_p(1))
   v_tv_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(tv_we | critical_recv)
     ,.data_o(v_tv_r)
     );

  logic [assoc_p-1:0] way_v_tv_n, store_hit_tv_n, load_hit_tv_n;
  logic [block_width_p-1:0] ld_data_tv_n;
  logic [paddr_width_p-1:0] paddr_tv_n;
  logic [dword_width_gp-1:0] st_data_tv_n;
  logic [assoc_p-1:0] bank_sel_one_hot_tv_n;
  logic uncached_op_tv_n;
  bp_be_dcache_decode_s decode_tv_n;
  bsg_mux
   #(.width_p(3*assoc_p+block_width_p+paddr_width_p+dword_width_gp+assoc_p+1+$bits(bp_be_dcache_decode_s)), .els_p(2))
   tv_snoop_mux
    (.data_i({{snoop_hit, snoop_data, snoop_addr
               ,snoop_st_data_r, snoop_bank_sel_one_hot, snoop_uncached_op_r, snoop_decode_r}
              ,{way_v_tl, store_hit_tl, load_hit_tl, data_mem_data_lo, paddr_tl
                ,st_data_tl, bank_sel_one_hot_tl, uncached_op_tl, decode_tl_r}
              })
     ,.sel_i(critical_recv)
     ,.data_o({way_v_tv_n, store_hit_tv_n, load_hit_tv_n, ld_data_tv_n, paddr_tv_n
               ,st_data_tv_n, bank_sel_one_hot_tv_n, uncached_op_tv_n, decode_tv_n})
     );

  wire snoop_tv_n = critical_recv;
  bsg_dff
   #(.width_p(1+3*assoc_p+paddr_width_p+block_width_p+dword_width_gp+assoc_p+1+$bits(bp_be_dcache_decode_s)))
   tv_stage_reg
    (.clk_i(clk_i)
     ,.data_i({snoop_tv_n, way_v_tv_n, store_hit_tv_n, load_hit_tv_n, paddr_tv_n, ld_data_tv_n
               ,st_data_tv_n, bank_sel_one_hot_tv_n, uncached_op_tv_n, decode_tv_n})
     ,.data_o({snoop_tv_r, way_v_tv_r, store_hit_v_tv_r, load_hit_v_tv_r, paddr_tv_r, ld_data_tv_r
               ,st_data_tv_r, bank_sel_one_hot_tv_r, uncached_op_tv_r, decode_tv_r})
     );

  logic invalid_exist_tv;
  logic [lg_assoc_lp-1:0] invalid_way_tv;
  bsg_priority_encode
   #(.width_p(assoc_p), .lo_to_hi_p(1))
    pe_invalid
    (.i(~way_v_tv_r)
     ,.v_o(invalid_exist_tv)
     ,.addr_o(invalid_way_tv)
     );

  // If there is invalid way, then it take priority over LRU way.
  logic [lg_assoc_lp-1:0] lru_encode;
  wire [lg_assoc_lp-1:0] lru_way_li = invalid_exist_tv ? invalid_way_tv : lru_encode;

  logic [lg_assoc_lp-1:0] store_hit_way_tv;
  logic store_hit_tv;
  bsg_encode_one_hot
   #(.width_p(assoc_p) ,.lo_to_hi_p(1))
   store_hit_index_encoder
    (.i(store_hit_v_tv_r)
     ,.addr_o(store_hit_way_tv)
     ,.v_o(store_hit_tv)
     );

  logic [lg_assoc_lp-1:0] load_hit_way_tv;
  logic load_hit_tv;
  bsg_encode_one_hot
   #(.width_p(assoc_p) ,.lo_to_hi_p(1))
   load_hit_index_encoder
    (.i(load_hit_v_tv_r)
     ,.addr_o(load_hit_way_tv)
     ,.v_o(load_hit_tv)
     );

  logic [assoc_p-1:0] ld_data_way_select;
  bsg_adder_one_hot
   #(.width_p(assoc_p))
   select_adder
    (.a_i(load_hit_v_tv_r)
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
  wire [`BSG_SAFE_CLOG2(num_dwords_per_bank_lp)-1:0] ld_data_dword_sel =
    paddr_tv_r[3+:`BSG_SAFE_CLOG2(num_dwords_per_bank_lp)];
  bsg_mux
   #(.width_p(dword_width_gp), .els_p(num_dwords_per_bank_lp))
   dword_mux
    (.data_i(ld_data_way_picked)
     ,.sel_i(ld_data_dword_sel)
     ,.data_o(ld_data_dword_raw)
     );

  logic [dword_width_gp-1:0] ld_data_dword_merged;

  logic [3:0][dword_width_gp-1:0] sigext_word;
  for (genvar i = 0; i < 4; i++)
    begin : word_alignment
      localparam slice_width_lp = 8*(2**i);

      logic [slice_width_lp-1:0] slice_data;
      bsg_mux
       #(.width_p(slice_width_lp), .els_p(dword_width_gp/slice_width_lp))
       align_mux
        (.data_i(ld_data_dword_merged)
         ,.sel_i(paddr_tv_r[i+:`BSG_MAX(1, 3-i)])
         ,.data_o(slice_data)
         );

      wire sigext = // Integer sigext
                    (decode_tv_r.signed_op & slice_data[slice_width_lp-1])
                    // FP nanbox
                    || ((i==2) & decode_tv_r.float_op & decode_tv_r.word_op);
      assign sigext_word[i] = {{(dword_width_gp-slice_width_lp){sigext}}, slice_data};
    end

  logic [dword_width_gp-1:0] final_data;
  bsg_mux_one_hot
   #(.width_p(dword_width_gp), .els_p(4))
   word_mux
    (.data_i(sigext_word)
     ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op, decode_tv_r.half_op, decode_tv_r.byte_op})
     ,.data_o(final_data)
     );

  // Load reserved misses if not in exclusive or modified (whether load hit or not)
  wire lr_hit_tv =
    v_tv_r & decode_tv_r.lr_op & store_hit_tv & (amo_support_p[e_dcache_subop_lr]);
  // Succeed if the address matches and we have a store hit
  wire sc_success_tv =
    v_tv_r & decode_tv_r.sc_op & store_hit_tv & load_reservation_match_tv & (amo_support_p[e_dcache_subop_sc]);
  // Fail if we have a store conditional without success
  wire sc_fail_tv = v_tv_r & decode_tv_r.sc_op & ~sc_success_tv;

  // Store no-allocate, so keep going if we have a store miss on a writethrough cache
  wire store_miss_tv    = (decode_tv_r.store_op | decode_tv_r.lr_op) & ~decode_tv_r.sc_op & ~store_hit_tv & writeback_p;
  wire load_miss_tv     = decode_tv_r.load_op & ~decode_tv_r.sc_op & ~load_hit_tv;
  wire ldst_miss_tv     = load_miss_tv | store_miss_tv;
  wire fencei_miss_tv   = decode_tv_r.fencei_op & gdirty_r;
  wire engine_miss_tv   = cache_req_v_o & ~cache_req_yumi_i;
  wire any_miss_tv      = ldst_miss_tv | fencei_miss_tv | engine_miss_tv;

  assign data_o = (decode_tv_r.sc_op & ~uncached_op_tv_r)
    ? (sc_success_tv != 1'b1)
    : final_data;

  assign v_o       = v_tv_r & ~any_miss_tv;
  assign rd_addr_o = decode_tv_r.rd_addr;
  assign float_o   = decode_tv_r.float_op;
  assign fencei_o  = decode_tv_r.fencei_op;
  assign late_o    = snoop_tv_r;
  assign ret_o     = decode_tv_r.ret_op;
  assign store_o   = decode_tv_r.store_op;
  assign req_o     = cache_req_yumi_i;

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

  bsg_lru_pseudo_tree_encode
   #(.ways_p(assoc_p))
   lru_encoder
    (.lru_i(stat_mem_data_lo.lru)
     ,.way_id_o(lru_encode)
     );

  ///////////////////////////
  // Write buffer
  ///////////////////////////
  `declare_bp_be_dcache_wbuf_entry_s(caddr_width_p, assoc_p);
  bp_be_dcache_wbuf_entry_s wbuf_entry_in, wbuf_entry_out;
  logic wbuf_v_li, wbuf_v_lo, wbuf_force_lo, wbuf_yumi_li;

  assign wbuf_v_li = v_tv_r
        & decode_tv_r.store_op & ~uncached_op_tv_r
        & store_hit_tv & ~sc_fail_tv
        & (writeback_p | cache_req_yumi_i);

  //
  // Atomic operations
  logic [dword_width_gp-1:0] atomic_reg_data, atomic_mem_data;
  logic [dword_width_gp-1:0] atomic_alu_result, atomic_result;

  // Shift data to high bits for operations less than 64-bits
  // This allows us to share the arithmetic operators for 32/64 bit atomics
  wire [dword_width_gp-1:0] amo32_reg_in = st_data_tv_r[0+:word_width_gp] << word_width_gp;
  wire [dword_width_gp-1:0] amo64_reg_in = st_data_tv_r[0+:dword_width_gp];
  assign atomic_reg_data = decode_tv_r.double_op ? amo64_reg_in : amo32_reg_in;

  wire [dword_width_gp-1:0] amo32_mem_in = sigext_word[2][0+:word_width_gp] << word_width_gp;
  wire [dword_width_gp-1:0] amo64_mem_in = sigext_word[3][0+:dword_width_gp];
  assign atomic_mem_data = decode_tv_r.double_op ? amo64_mem_in : amo32_mem_in;

  // Atomic ALU
  always_comb
    // This logic was confirmed not to synthesize unsupported operators in
    //   Synopsys DC O-2018.06-SP4
    unique casez ({amo_support_p[decode_tv_r.amo_subop], decode_tv_r.amo_subop})
      {1'b1, e_dcache_subop_amoand }: atomic_alu_result = atomic_reg_data & atomic_mem_data;
      {1'b1, e_dcache_subop_amoor  }: atomic_alu_result = atomic_reg_data | atomic_mem_data;
      {1'b1, e_dcache_subop_amoxor }: atomic_alu_result = atomic_reg_data ^ atomic_mem_data;
      {1'b1, e_dcache_subop_amoadd }: atomic_alu_result = atomic_reg_data + atomic_mem_data;
      {1'b1, e_dcache_subop_amomin }: atomic_alu_result =
          ($signed(atomic_reg_data) < $signed(atomic_mem_data)) ? atomic_reg_data : atomic_mem_data;
      {1'b1, e_dcache_subop_amomax }: atomic_alu_result =
          ($signed(atomic_reg_data) > $signed(atomic_mem_data)) ? atomic_reg_data : atomic_mem_data;
      {1'b1, e_dcache_subop_amominu}: atomic_alu_result =
          (atomic_reg_data < atomic_mem_data) ? atomic_reg_data : atomic_mem_data;
      {1'b1, e_dcache_subop_amomaxu}: atomic_alu_result =
          (atomic_reg_data > atomic_mem_data) ? atomic_reg_data : atomic_mem_data;
      //{1'b1, e_dcache_subop_amoswap}
      //{1'b1, e_dcache_subop_sc     }
      default                       : atomic_alu_result = atomic_reg_data;
    endcase

  wire [dword_width_gp-1:0] amo32_out = atomic_alu_result >> word_width_gp;
  wire [dword_width_gp-1:0] amo64_out = atomic_alu_result;
  assign atomic_result = decode_tv_r.double_op ? amo64_out : amo32_out;

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

      if ((i == 2'b10) || (i == 2'b11))
        begin : atomic
          assign slice_data = decode_tv_r.amo_op
            ? atomic_result[0+:slice_width_lp]
            : st_data_tv_r[0+:slice_width_lp];
        end
      else
        begin : non_atomic
          assign slice_data = st_data_tv_r[0+:slice_width_lp];
        end

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
  assign wbuf_entry_in.caddr = paddr_tv_r;
  assign wbuf_entry_in.way_id = store_hit_way_tv;

  wire [caddr_width_p-1:0] ld_addr_tl = {ptag_i, vaddr_tl_r[0+:page_offset_width_gp]};
  bp_be_dcache_wbuf
   #(.bp_params_p(bp_params_p))
   wbuf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(wbuf_v_li)
     ,.wbuf_entry_i(wbuf_entry_in)

     ,.v_o(wbuf_v_lo)
     ,.force_o(wbuf_force_lo)
     ,.yumi_i(wbuf_yumi_li)
     ,.wbuf_entry_o(wbuf_entry_out)

     ,.load_addr_i(ld_addr_tl)
     ,.load_data_i(ld_data_dword_raw)
     ,.data_merged_o(ld_data_dword_merged)
     );
  wire [bindex_width_lp-1:0] wbuf_entry_out_bank_offset = wbuf_entry_out.caddr[byte_offset_width_lp+:bindex_width_lp];
  wire [sindex_width_lp-1:0] wbuf_entry_out_index = wbuf_entry_out.caddr[block_offset_width_lp+:sindex_width_lp];

  /////////////////////////////////////////////////////////////////////////////
  // Slow Path
  /////////////////////////////////////////////////////////////////////////////
  localparam block_req_size = bp_cache_req_size_e'(`BSG_SAFE_CLOG2(block_width_p/8));
  `bp_cast_o(bp_dcache_req_s, cache_req);
  `bp_cast_o(bp_dcache_req_metadata_s, cache_req_metadata);

  wire load_req            = ~uncached_op_tv_r & load_miss_tv;
  wire store_req           = ~uncached_op_tv_r & store_miss_tv;
  wire wt_req              = ~uncached_op_tv_r &  decode_tv_r.store_op & ~sc_fail_tv & !writeback_p;
  wire uncached_amo_req    =  uncached_op_tv_r &  decode_tv_r.amo_op & decode_tv_r.ret_op & ~snoop_tv_r;
  wire uncached_load_req   =  uncached_op_tv_r & ~decode_tv_r.amo_op & decode_tv_r.load_op & ~snoop_tv_r;
  wire uncached_store_req  =  uncached_op_tv_r & decode_tv_r.store_op & ~decode_tv_r.ret_op & ~snoop_tv_r;
  wire fencei_req          = fencei_miss_tv & (coherent_p == 0);
  wire backoff_req         = sc_fail_tv & (coherent_p == 1);

  // Uncached stores and writethrough requests are non-blocking
  wire nonblocking_req     = (uncached_store_req | wt_req | backoff_req);
  wire blocking_req        = (fencei_req | load_req | store_req | uncached_amo_req | uncached_load_req);
  assign nonblocking_sent  = nonblocking_req & cache_req_yumi_i;
  assign blocking_sent     = blocking_req & cache_req_yumi_i;

  assign cache_req_v_o = v_tv_r & (blocking_req | nonblocking_req);

  assign blocking_hazard = cache_req_v_o & blocking_req;
  assign engine_hazard   = cache_req_v_o & ~cache_req_yumi_i;

  always_comb
    begin
      cache_req_cast_o = '0;
      cache_req_cast_o.addr = paddr_tv_r;
      cache_req_cast_o.data = wbuf_entry_in.data;
      cache_req_cast_o.hit = load_hit_tv;

      // Assigning sizes to cache miss packet
      if (load_req | store_req)
        begin
            cache_req_cast_o.size = bp_cache_req_size_e'(block_req_size);
        end
      else
        begin
          if (decode_tv_r.double_op)
            cache_req_cast_o.size = e_size_8B;
          else if (decode_tv_r.word_op)
            cache_req_cast_o.size = e_size_4B;
          else if (decode_tv_r.half_op)
            cache_req_cast_o.size = e_size_2B;
          else if (decode_tv_r.byte_op)
            cache_req_cast_o.size = e_size_1B;
        end

      unique casez ({decode_tv_r.amo_op, decode_tv_r.amo_subop})
        {1'b1, e_dcache_subop_lr     }: cache_req_cast_o.subop = e_req_amolr;
        {1'b1, e_dcache_subop_sc     }: cache_req_cast_o.subop = e_req_amosc;
        {1'b1, e_dcache_subop_amoswap}: cache_req_cast_o.subop = e_req_amoswap;
        {1'b1, e_dcache_subop_amoadd }: cache_req_cast_o.subop = e_req_amoadd;
        {1'b1, e_dcache_subop_amoxor }: cache_req_cast_o.subop = e_req_amoxor;
        {1'b1, e_dcache_subop_amoand }: cache_req_cast_o.subop = e_req_amoand;
        {1'b1, e_dcache_subop_amoor  }: cache_req_cast_o.subop = e_req_amoor;
        {1'b1, e_dcache_subop_amomin }: cache_req_cast_o.subop = e_req_amomin;
        {1'b1, e_dcache_subop_amomax }: cache_req_cast_o.subop = e_req_amomax;
        {1'b1, e_dcache_subop_amominu}: cache_req_cast_o.subop = e_req_amominu;
        {1'b1, e_dcache_subop_amomaxu}: cache_req_cast_o.subop = e_req_amomaxu;
        default: cache_req_cast_o.subop = e_req_store;
      endcase

      if (backoff_req)
        cache_req_cast_o.msg_type = e_cache_backoff;
      else if (fencei_req)
        cache_req_cast_o.msg_type = e_cache_flush;
      else if (store_req)
        cache_req_cast_o.msg_type = e_miss_store;
      else if (load_req)
        cache_req_cast_o.msg_type = e_miss_load;
      else if (uncached_amo_req)
        cache_req_cast_o.msg_type = e_uc_amo;
      else if (uncached_store_req)
        cache_req_cast_o.msg_type = e_uc_store;
      else if (uncached_load_req)
        cache_req_cast_o.msg_type = e_uc_load;
      else
        cache_req_cast_o.msg_type = e_wt_store;
    end

  wire cache_req_metadata_v = cache_req_yumi_i;
  bsg_dff_reset
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_metadata_v)
     ,.data_o(cache_req_metadata_v_o)
     );

  logic metadata_hit_r;
  logic [lg_assoc_lp-1:0] metadata_hit_index_r;
  bsg_dff
   #(.width_p(1+lg_assoc_lp))
   cached_hit_reg
    (.clk_i(clk_i)
     ,.data_i({load_hit_tv, load_hit_way_tv})
     ,.data_o({metadata_hit_r, metadata_hit_index_r})
     );

  wire [assoc_p-1:0] hit_or_repl_way = metadata_hit_r ? metadata_hit_index_r : lru_way_li;
  assign cache_req_metadata_cast_o.hit_or_repl_way = hit_or_repl_way;
  assign cache_req_metadata_cast_o.dirty = stat_mem_data_lo.dirty[hit_or_repl_way];

  /////////////////////////////////////////////////////////////////////////////
  // State machine
  //   e_ready  : Cache is ready to accept requests
  //   e_miss   : Cache is waiting for a miss to be serviced
  /////////////////////////////////////////////////////////////////////////////
  always_comb
    case (state_r)
      e_ready : state_n = blocking_sent ? e_miss : e_ready;
      e_miss  : state_n = complete_recv ? e_ready : e_miss;
      default: state_n = e_ready;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  assign ready_and_o = is_ready & ~cache_req_busy_i;
  assign ordered_o = is_ready & ~v_tl_r & ~v_tv_r & cache_req_credits_empty_i;

  /////////////////////////////////////////////////////////////////////////////
  // SRAM Control
  /////////////////////////////////////////////////////////////////////////////

  ///////////////////////////
  // Tag Mem Control
  ///////////////////////////
  wire tag_mem_fast_read = (safe_tl_we & ~decode_lo.fencei_op) & ~tag_mem_write_hazard;
  wire tag_mem_slow_read = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_read);
  wire tag_mem_slow_write = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode != e_cache_tag_mem_read);
  wire tag_mem_fast_write = v_tv_r & (uncached_op_tv_r & load_hit_tv & ~snoop_tv_r);
  assign tag_mem_write_hazard = tag_mem_fast_write;

  assign tag_mem_v_li = tag_mem_fast_read | tag_mem_slow_read | tag_mem_slow_write | tag_mem_fast_write;
  assign tag_mem_w_li = tag_mem_slow_write | tag_mem_fast_write;
  assign tag_mem_addr_li = tag_mem_fast_write
    ? paddr_index_tv
    : tag_mem_fast_read
      ? vaddr_index
      : tag_mem_pkt_cast_i.index;
  assign tag_mem_pkt_yumi_o = tag_mem_pkt_v_i & ~tag_mem_fast_read & ~tag_mem_fast_write;

  logic [assoc_p-1:0] tag_mem_way_one_hot;
  bsg_decode
    #(.num_out_p(assoc_p))
    tag_mem_way_decode
      (.i(tag_mem_pkt_cast_i.way_id)
      ,.o(tag_mem_way_one_hot)
      );

  always_comb
    for (integer i = 0; i < assoc_p; i++)
      casez ({tag_mem_fast_write, tag_mem_pkt_cast_i.opcode})
        {1'b1, 3'b???}:
          begin
            tag_mem_data_li[i] = '{state: bp_coh_states_e'('0), tag: '0};
            tag_mem_mask_li[i] = '{state: {$bits(bp_coh_states_e){(load_hit_way_tv == i)}}
                                   ,tag : '0
                                   };
          end
       {1'b0,  e_cache_tag_mem_set_tag}:
          begin
            tag_mem_data_li[i] = '{state: tag_mem_pkt_cast_i.state, tag: tag_mem_pkt_cast_i.tag};
            tag_mem_mask_li[i] = '{state: {$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}
                                   ,tag : {ctag_width_p{tag_mem_way_one_hot[i]}}
                                   };
          end
        {1'b0, e_cache_tag_mem_set_state}:
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

  logic [lg_assoc_lp-1:0] tag_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_assoc_lp))
   tag_mem_pkt_way_reg
    (.clk_i(clk_i)
     ,.data_i(tag_mem_pkt_cast_i.way_id)
     ,.data_o(tag_mem_pkt_way_r)
     );

  assign tag_mem_o = tag_mem_data_lo[tag_mem_pkt_way_r];

  ///////////////////////////
  // Data Mem Control
  ///////////////////////////
  logic [block_size_in_fill_lp-1:0][fill_size_in_bank_lp-1:0] data_mem_pkt_fill_mask_expanded;
  bsg_expand_bitmask
   #(.in_width_p(block_size_in_fill_lp), .expand_p(fill_size_in_bank_lp))
   fill_mask_expand
    (.i(data_mem_pkt_cast_i.fill_index), .o(data_mem_pkt_fill_mask_expanded));

  logic [assoc_p-1:0] data_mem_write_bank_mask;
  wire [`BSG_SAFE_CLOG2(assoc_p)-1:0] write_mask_rot_li = data_mem_pkt_cast_i.way_id;
  bsg_rotate_left
   #(.width_p(assoc_p))
   write_mask_rotate
    (.data_i(data_mem_pkt_fill_mask_expanded)
     ,.rot_i(write_mask_rot_li)
     ,.o(data_mem_write_bank_mask)
     );

  wire [`BSG_SAFE_CLOG2(fill_width_p)-1:0] write_data_rot_li = data_mem_pkt_cast_i.way_id*bank_width_lp;
  logic [fill_width_p-1:0] data_mem_pkt_fill_data_li;
  bsg_rotate_left
   #(.width_p(fill_width_p))
   write_data_rotate
    (.data_i(data_mem_pkt_cast_i.data)
     ,.rot_i(write_data_rot_li)
     ,.o(data_mem_pkt_fill_data_li)
     );
  wire [assoc_p-1:0][bank_width_lp-1:0] data_mem_pkt_data_li = {block_size_in_fill_lp{data_mem_pkt_fill_data_li}};

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
  wire [dword_mask_width_lp-1:0] wbuf_dword_sel = wbuf_entry_out.caddr[3+:dword_mask_width_lp];
  wire [byte_offset_width_lp-1:0] mask_shift = (num_dwords_per_bank_lp > 1)
    ? (wbuf_dword_sel << 3)
    : '0;
  wire [data_mem_mask_width_lp-1:0] wbuf_data_mem_mask = wbuf_entry_out.mask << mask_shift;

  logic [assoc_p-1:0] data_mem_fast_read, data_mem_fast_write, data_mem_slow_read, data_mem_slow_write;
  logic [assoc_p-1:0] data_mem_force_write;
  for (genvar i = 0; i < assoc_p; i++)
    begin : data_mem_lines
      assign data_mem_force_write[i] = wbuf_v_lo & wbuf_force_lo & wbuf_bank_sel_one_hot[i];
      assign data_mem_slow_write[i] = data_mem_pkt_yumi_o
        & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_write) & data_mem_write_bank_mask[i];
      assign data_mem_slow_read[i] = data_mem_pkt_yumi_o
        & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_read);
      assign data_mem_fast_read[i] = safe_tl_we & decode_lo.load_op & ~data_mem_force_write[i];
      assign data_mem_fast_write[i] = wbuf_yumi_li & wbuf_bank_sel_one_hot[i];

      assign data_mem_v_li[i] = data_mem_fast_read[i]
        | data_mem_fast_write[i]
        | data_mem_slow_read[i]
        | data_mem_slow_write[i];
      assign data_mem_w_li[i] = data_mem_fast_write[i]
        | data_mem_slow_write[i];

      assign data_mem_mask_li[i] = data_mem_fast_write[i]
        ? wbuf_data_mem_mask
        : {data_mem_mask_width_lp{data_mem_write_bank_mask[i]}};

      wire [bindex_width_lp-1:0] data_mem_pkt_offset = (bindex_width_lp'(i) - data_mem_pkt_cast_i.way_id);
      assign data_mem_addr_li[i] = data_mem_fast_write[i]
        ? {wbuf_entry_out_index, {(assoc_p > 1){wbuf_entry_out_bank_offset}}}
        : data_mem_fast_read[i]
          ? {vaddr_index, {(assoc_p > 1){vaddr_bank}}}
          : {data_mem_pkt_cast_i.index, {(assoc_p > 1){data_mem_pkt_offset}}};

      assign data_mem_data_li[i] = data_mem_fast_write[i]
        ? {num_dwords_per_bank_lp{wbuf_entry_out.data}}
        : data_mem_pkt_data_li[i];
    end
  assign wbuf_yumi_li = wbuf_v_lo & |{~data_mem_fast_read & wbuf_bank_sel_one_hot};
  // If we didn't read all banks, this could be more efficient
  assign data_mem_write_hazard = (safe_tl_we & decode_lo.load_op) & |data_mem_force_write;

  // As an optimization, we could snoop the data_mem_pkt to see if there are any matching entries
  //   in the write buffer, so that the write buffer will only drain if it is full, or if there is
  //   a snoop match. However, this is a critical path, so we drain the write buffer on invalidations.
  // A similar scheme could be adopted for a non-blocking version, where we snoop the bank
  // TODO: With blocking TL and TV, we really should implement snooping for performance
  assign data_mem_pkt_yumi_o = (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached)
    ? data_mem_pkt_v_i
    : data_mem_pkt_v_i & ~|data_mem_fast_read
      & ~(v_tl_r & decode_tl_r.store_op)
      & ~(wbuf_v_lo & ~snoop_tv_r);

  logic [lg_assoc_lp-1:0] data_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_assoc_lp))
   data_mem_pkt_way_reg
    (.clk_i(clk_i)
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
  wire stat_mem_fast_read  = (v_tv_r & any_miss_tv) | tag_mem_write_hazard;
  wire stat_mem_fast_write = (v_tv_r & ~any_miss_tv & ~uncached_op_tv_r);
  wire stat_mem_slow_write = stat_mem_pkt_yumi_o & (stat_mem_pkt_cast_i.opcode != e_cache_stat_mem_read);
  wire stat_mem_slow_read  = stat_mem_pkt_yumi_o & (stat_mem_pkt_cast_i.opcode == e_cache_stat_mem_read);
  assign stat_mem_v_li = stat_mem_fast_read | stat_mem_fast_write
      | (stat_mem_slow_write | stat_mem_slow_read);
  assign stat_mem_w_li = stat_mem_fast_write | stat_mem_slow_write;
  assign stat_mem_addr_li = (stat_mem_fast_write | stat_mem_fast_read)
    ? paddr_tv_r[block_offset_width_lp+:sindex_width_lp]
    : stat_mem_pkt_cast_i.index;
  assign stat_mem_pkt_yumi_o = stat_mem_pkt_v_i & ~stat_mem_fast_read & ~stat_mem_fast_write;

  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_data_lo;
  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_mask_lo;
  wire [lg_assoc_lp-1:0] lru_decode_way_li =
    v_tv_r ? decode_tv_r.store_op ? store_hit_way_tv : load_hit_way_tv : stat_mem_pkt_cast_i.way_id;
  bsg_lru_pseudo_tree_decode
   #(.ways_p(assoc_p))
   lru_decode
    (.way_id_i(lru_decode_way_li)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
     );

  logic [assoc_p-1:0] dirty_mask_lo;
  if (writeback_p)
    begin : tdm
      wire dirty_mask_v_li = stat_mem_slow_write || (v_tv_r & decode_tv_r.store_op);
      wire [lg_assoc_lp-1:0] dirty_mask_way_li = v_tv_r ? store_hit_way_tv : stat_mem_pkt_cast_i.way_id;
      bsg_decode_with_v
       #(.num_out_p(assoc_p))
       dirty_mask_decode
        (.i(dirty_mask_way_li)
         ,.v_i(dirty_mask_v_li)
         ,.o(dirty_mask_lo)
         );
    end
  else
    begin : ntdm
      // We don't track dirty
      // Note: This will synthesize out of stat_mem...unless hardened
      assign dirty_mask_lo = '0;
    end

  if (coherent_p == 0)
    begin : tgd
      // Maintain a global dirty bit for the cache. When data is written to the write buffer, we set
      //   it. When we send a flush request to the CE, we clear it.
      // The way this works with fence.i is:
      //   1) If dirty bit is set, we force a miss and send off a flush request to the CE
      //   2) If dirty bit is not set, we do not send a request and simply return valid flush.
      //        A clear request is now sent to I$ through the FE exception mechanism
      // For a non-coherent writeback cache, we set the dirty when we have a store hit
      // For a non-coherent writethrough write-no-allocate cache, we set the dirty regardless of hit
      // For a coherent cache, we never set the dirty bit as the coherence system should handle it
      wire set_dirty = wbuf_v_li;
      wire clear_dirty = complete_recv & snoop_decode_r.fencei_op;
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
    begin : ntgd
      assign gdirty_r = '0;
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

  logic [lg_assoc_lp-1:0] stat_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_assoc_lp))
   stat_mem_pkt_way_reg
    (.clk_i(clk_i)
     ,.data_i(stat_mem_pkt_cast_i.way_id)
     ,.data_o(stat_mem_pkt_way_r)
     );

  assign stat_mem_o = stat_mem_data_lo;

  /////////////////////////////////////////////////////////////////////////////
  // Load Reservation
  /////////////////////////////////////////////////////////////////////////////
  if (amo_support_p[e_dcache_subop_lr] && amo_support_p[e_dcache_subop_sc])
    begin : l1_lrsc
      logic [sindex_width_lp-1:0] load_reserved_index_r;
      logic [ctag_width_p-1:0] load_reserved_tag_r;
      logic load_reserved_v_r;

      // Set reservation on successful LR, without a cache miss or upgrade request
      wire set_reservation = lr_hit_tv;
      // All SCs clear the reservation (regardless of success)
      // Invalidates from other harts which match the reservation address clear the reservation
      // Also invalidate on trap
      wire clear_reservation = (v_tv_r & decode_tv_r.sc_op)
        || (tag_mem_pkt_yumi_o
            & load_reserved_v_r
            & (tag_mem_pkt_cast_i.index == load_reserved_index_r)
            & (tag_mem_pkt_cast_i.tag == load_reserved_tag_r)
            );
      bsg_dff_reset_set_clear
       #(.width_p(1), .clear_over_set_p(1))
       load_reserved_v_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(set_reservation)
         ,.clear_i(clear_reservation)
         ,.data_o(load_reserved_v_r)
         );

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
    end
  else
    begin : no_l1_lrsc
        assign load_reservation_match_tv = '0;
    end

  /////////////////////////////////////////////////////////////////////////////
  // Snoop Logic
  /////////////////////////////////////////////////////////////////////////////
  bsg_dff_en
   #(.width_p(1+dword_width_gp+$bits(bp_be_dcache_decode_s)))
   snoop_metadata_reg
    (.clk_i(clk_i)
     ,.en_i(blocking_sent)
     ,.data_i({uncached_op_tv_r, st_data_tv_r, decode_tv_r})
     ,.data_o({snoop_uncached_op_r, snoop_st_data_r, snoop_decode_r})
     );

  wire [assoc_p-1:0] pseudo_hit =
    (data_mem_pkt_v_i << data_mem_pkt_cast_i.way_id) | (tag_mem_pkt_v_i << tag_mem_pkt_cast_i.way_id);
  assign snoop_hit = {3{pseudo_hit}};
  assign snoop_data = data_mem_data_li;
  assign snoop_addr = cache_req_addr_i;

  wire [bindex_width_lp-1:0] snoop_bank = cache_req_addr_i[byte_offset_width_lp+:bindex_width_lp];
  bsg_decode
   #(.num_out_p(assoc_p))
   snoop_offset_decode
    (.i(snoop_bank)
     ,.o(snoop_bank_sel_one_hot)
     );

  // synopsys translate_off
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  always_ff @(negedge clk_i)
    begin
      assert(reset_i !== '0 || ~v_tv_r || $countones(load_hit_tl) <= 1)
        else $error("multiple hit: %b. id = %0d. addr = %H", load_hit_tl, cfg_bus_cast_i.dcache_id, ptag_i);
    end
  // synopsys translate_on

endmodule

