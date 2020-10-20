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

module bp_be_dcache
  import bp_common_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_be_hardfloat_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache)

    , parameter writethrough_p=l1_writethrough_p

    , parameter debug_p=0
    , parameter lock_max_limit_p=8

    , localparam lg_dcache_assoc_lp=`BSG_SAFE_CLOG2(dcache_assoc_p)
    , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
    , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
    , localparam wbuf_data_mask_width_lp = (dword_width_p >> 3)
    , localparam data_mem_mask_width_lp = (bank_width_lp >> 3)
    , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3)
    , localparam bank_offset_width_lp = `BSG_SAFE_CLOG2(dcache_assoc_p)
    , localparam block_offset_width_lp=(bank_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(dcache_sets_p)
    , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
    , localparam block_size_in_fill_lp = dcache_block_width_p / dcache_fill_width_p
    , localparam fill_size_in_bank_lp = dcache_fill_width_p / bank_width_lp

    , localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(bp_page_offset_width_gp,dpath_width_p)
    , localparam tag_info_width_lp=`bp_be_dcache_tag_info_width(ptag_width_lp)
  )
  (
    input clk_i
    , input reset_i

    , input [cfg_bus_width_lp-1:0] cfg_bus_i

    , input [dcache_pkt_width_lp-1:0] dcache_pkt_i
    , input v_i
    , output logic ready_o

    // TLB interface
    , input [ptag_width_lp-1:0] ptag_i
    , input ptag_v_i
    , input uncached_i

    , output logic [dpath_width_p-1:0] early_data_o
    , output logic                     early_v_o
    , output logic [dpath_width_p-1:0] final_data_o
    , output logic                     final_v_o

    // ctrl
    , input flush_i

    // D$-LCE Interface
    // signals to LCE
    , output [dcache_req_width_lp-1:0] cache_req_o
    , output logic cache_req_v_o
    , input cache_req_ready_i
    , output [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
    , output cache_req_metadata_v_o

    , input cache_req_complete_i
    , input cache_req_critical_i

    // data_mem
    , input data_mem_pkt_v_i
    , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
    , output logic data_mem_pkt_yumi_o
    , output logic [dcache_block_width_p-1:0] data_mem_o

    // tag_mem
    , input tag_mem_pkt_v_i
    , input [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_i
    , output logic tag_mem_pkt_yumi_o
    , output logic [ptag_width_lp-1:0] tag_mem_o

    // stat_mem
    , input stat_mem_pkt_v_i
    , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
    , output logic stat_mem_pkt_yumi_o
    , output logic [dcache_stat_info_width_lp-1:0] stat_mem_o

  );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache);
  bp_dcache_req_s cache_req_cast_o;
  bp_dcache_req_metadata_s cache_req_metadata_cast_o;
  assign cache_req_o = cache_req_cast_o;
  assign cache_req_metadata_o = cache_req_metadata_cast_o;

  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dpath_width_p);
  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = dcache_pkt_i;

  `declare_bp_be_dcache_pipeline_s
  bp_be_dcache_pipeline_s decode_lo, decode_tl_r, decode_tv_r;
  logic [index_width_lp-1:0] addr_index;
  logic [bank_offset_width_lp-1:0] addr_bank_offset;

  bp_be_dcache_decoder
  #(.bp_params_p(bp_params_p))
    pkt_decoder
    (.pkt_i(dcache_pkt_i)
    ,.decoded_o(decode_lo)
    );

  assign addr_index = dcache_pkt.page_offset[block_offset_width_lp+:index_width_lp];
  assign addr_bank_offset = dcache_pkt.page_offset[byte_offset_width_lp+:bank_offset_width_lp];

  // TL stage
  //
  logic v_tl_r; // valid bit
  logic tl_we;
  logic [bp_page_offset_width_gp-1:0] page_offset_tl_r;
  logic [dpath_width_p-1:0] data_tl_r;
  logic gdirty_r;

  assign tl_we = v_i;

  always_ff @ (negedge clk_i) begin
    if (reset_i) begin
      v_tl_r <= 1'b0;
    end
    else begin
      // We poison the valid of the stage rather than tl_we, to relieve critical paths on the
      //   large memory enables. The tradeoff is an additional toggle whenever there is a flush
      //   during an incoming dcache request
      v_tl_r <= tl_we & ~flush_i;
      if (tl_we) begin
        decode_tl_r <= decode_lo;
        page_offset_tl_r <= dcache_pkt.page_offset;
      end

      if (tl_we & decode_lo.store_op) begin
        data_tl_r <= dcache_pkt.data;
      end
    end
  end

  // tag_mem
  //
  `declare_bp_be_dcache_tag_info_s(ptag_width_lp);
  logic tag_mem_v_li;
  logic tag_mem_w_li;
  logic [index_width_lp-1:0] tag_mem_addr_li;
  bp_be_dcache_tag_info_s [dcache_assoc_p-1:0] tag_mem_data_li;
  bp_be_dcache_tag_info_s [dcache_assoc_p-1:0] tag_mem_mask_li;
  bp_be_dcache_tag_info_s [dcache_assoc_p-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(tag_info_width_lp*dcache_assoc_p)
      ,.els_p(dcache_sets_p)
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

  // data_mem
  //
  logic [dcache_assoc_p-1:0] data_mem_v_li;
  logic data_mem_w_li;
  logic [dcache_assoc_p-1:0][index_width_lp+bank_offset_width_lp-1:0] data_mem_addr_li;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] data_mem_data_li;
  logic [dcache_assoc_p-1:0][data_mem_mask_width_lp-1:0] data_mem_mask_li;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] data_mem_data_lo;

  for (genvar i = 0; i < dcache_assoc_p; i++) begin: data_mem
    bsg_mem_1rw_sync_mask_write_byte
      #(.data_width_p(bank_width_lp)
        ,.els_p(dcache_sets_p*dcache_assoc_p)
        )
      data_mem
        (.clk_i(~clk_i)
        ,.reset_i(reset_i)
        ,.v_i(data_mem_v_li[i])
        ,.w_i(data_mem_w_li)
        ,.addr_i(data_mem_addr_li[i])
        ,.data_i(data_mem_data_li[i])
        ,.write_mask_i(data_mem_mask_li[i])
        ,.data_o(data_mem_data_lo[i])
        );
  end

  // miss_detect
  //
  logic [dcache_assoc_p-1:0] tag_match_tl;
  logic [dcache_assoc_p-1:0] load_hit_tl;
  logic [dcache_assoc_p-1:0] store_hit_tl;
  logic [dcache_assoc_p-1:0] invalid_tl;
  logic [paddr_width_p-1:0]  paddr_tl;
  logic [ptag_width_lp-1:0] addr_tag_tl;
  logic [bank_offset_width_lp-1:0] addr_bank_offset_tl;
  logic [dcache_assoc_p-1:0] addr_bank_offset_dec_tl;

  assign paddr_tl = {ptag_i, page_offset_tl_r};

  assign addr_tag_tl = paddr_tl[block_offset_width_lp+index_width_lp+:ptag_width_lp];
  assign addr_bank_offset_tl = paddr_tl[byte_offset_width_lp+:bank_offset_width_lp];

  for (genvar i = 0; i < dcache_assoc_p; i++) begin: tag_comp_tl
    assign tag_match_tl[i] = addr_tag_tl == tag_mem_data_lo[i].tag;
    assign load_hit_tl[i] = tag_match_tl[i] & (tag_mem_data_lo[i].coh_state != e_COH_I);
    assign store_hit_tl[i] = tag_match_tl[i] & ((tag_mem_data_lo[i].coh_state == e_COH_M)
                                                || (tag_mem_data_lo[i].coh_state == e_COH_E));
    assign invalid_tl[i] = (tag_mem_data_lo[i].coh_state == e_COH_I);
  end

  bsg_decode
   #(.num_out_p(dcache_assoc_p))
   offset_decode
    (.i(addr_bank_offset_tl)
     ,.o(addr_bank_offset_dec_tl)
     );

  // TV stage
  //
  logic v_tv_r;
  logic tv_we;
  logic uncached_tv_r;
  logic [paddr_width_p-1:0] paddr_tv_r;
  logic [dpath_width_p-1:0] data_tv_r;
  bp_be_dcache_tag_info_s [dcache_assoc_p-1:0] tag_info_tv_r;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] ld_data_tv_r;
  logic [ptag_width_lp-1:0] addr_tag_tv_r;
  logic [index_width_lp-1:0] addr_index_tv;
  logic [dcache_assoc_p-1:0] load_hit_tv_r;
  logic [dcache_assoc_p-1:0] store_hit_tv_r;
  logic [dcache_assoc_p-1:0] invalid_tv_r;
  logic [dcache_assoc_p-1:0] addr_bank_offset_dec_tv_r;
  logic [lg_dcache_assoc_lp-1:0] load_hit_way_tv;
  logic [lg_dcache_assoc_lp-1:0] store_hit_way_tv;
  logic load_hit_tv;
  logic store_hit_tv;

  // fencei does not require a ptag
  assign tv_we = v_tl_r & (ptag_v_i | decode_tl_r.fencei_op);

  always_ff @(negedge clk_i) begin
    if (reset_i) begin
      v_tv_r <= 1'b0;

      decode_tv_r <= '0;
      paddr_tv_r <= '0;
      tag_info_tv_r <= '0;
      load_hit_tv_r <= '0;
      store_hit_tv_r <= '0;
      invalid_tv_r <= '0;
      addr_bank_offset_dec_tv_r <= '0;
    end
    else begin
      // We poison the valid of the stage rather than tl_we, to relieve critical paths on the
      //   large memory enables. The tradeoff is an additional toggle whenever there is a flush
      //   during an incoming dcache request
      v_tv_r <= tv_we & ~flush_i;

      if (tv_we) begin
        decode_tv_r <= decode_tl_r;
        paddr_tv_r <= paddr_tl;
        tag_info_tv_r <= tag_mem_data_lo;
        uncached_tv_r <= uncached_i | decode_tl_r.l2_op;
        load_hit_tv_r <= load_hit_tl;
        store_hit_tv_r <= store_hit_tl;
        addr_tag_tv_r <= addr_tag_tl;
        invalid_tv_r <= invalid_tl;
        addr_bank_offset_dec_tv_r <= addr_bank_offset_dec_tl;
      end

      if (tv_we & decode_tl_r.load_op) begin
        ld_data_tv_r <= data_mem_data_lo;
      end

      if (tv_we & decode_tl_r.store_op) begin
        data_tv_r <= data_tl_r;
      end
    end
  end

  assign addr_index_tv = paddr_tv_r[block_offset_width_lp+:index_width_lp];

  // uncached req
  //
  logic uncached_load_req;
  logic uncached_store_req;
  logic fencei_req;

  // For L2 atomics
  wire lr_req      = v_tv_r & decode_tv_r.lr_op;
  wire sc_req      = v_tv_r & decode_tv_r.sc_op;
  wire amoswap_req = v_tv_r & decode_tv_r.amoswap_op;
  wire amoadd_req  = v_tv_r & decode_tv_r.amoadd_op;
  wire amoxor_req  = v_tv_r & decode_tv_r.amoxor_op;
  wire amoand_req  = v_tv_r & decode_tv_r.amoand_op;
  wire amoor_req   = v_tv_r & decode_tv_r.amoor_op;
  wire amomin_req  = v_tv_r & decode_tv_r.amomin_op;
  wire amomax_req  = v_tv_r & decode_tv_r.amomax_op;
  wire amominu_req = v_tv_r & decode_tv_r.amominu_op;
  wire amomaxu_req = v_tv_r & decode_tv_r.amomaxu_op;
  wire l2_amo_req  = v_tv_r & decode_tv_r.l2_op;

  // Uncached and L2 atomic refactor
  logic uncached_load_data_v_r;
  logic [dword_width_p-1:0] uncached_load_data_r;

  // load reserved / store conditional
  logic lr_hit_tv;
  logic sc_success;
  logic sc_fail;
  logic [ptag_width_lp-1:0]  load_reserved_tag_r;
  logic [index_width_lp-1:0] load_reserved_index_r;
  logic load_reserved_v_r;

  bsg_encode_one_hot
   #(.width_p(dcache_assoc_p)
     ,.lo_to_hi_p(1)
     )
   store_hit_index_encoder
    (.i(store_hit_tv_r)
     ,.addr_o(store_hit_way_tv)
     ,.v_o(store_hit_tv)
     );

  bsg_encode_one_hot
   #(.width_p(dcache_assoc_p)
     ,.lo_to_hi_p(1)
     )
   load_hit_index_encoder
    (.i(load_hit_tv_r)
     ,.addr_o(load_hit_way_tv)
     ,.v_o(load_hit_tv)
     );

  wire load_miss_tv = ~load_hit_tv & v_tv_r & decode_tv_r.load_op & ~uncached_tv_r & ~decode_tv_r.l2_op;
  wire store_miss_tv = ~store_hit_tv & v_tv_r & decode_tv_r.store_op & ~uncached_tv_r & ~decode_tv_r.sc_op & ~decode_tv_r.l2_op;
  wire lr_miss_tv = v_tv_r & decode_tv_r.lr_op & ~store_hit_tv & ~decode_tv_r.l2_op;
  wire wt_miss_tv = v_tv_r & decode_tv_r.store_op & store_hit_tv & ~sc_fail & ~uncached_tv_r & ~cache_req_ready_i & (writethrough_p == 1);

  wire miss_tv = load_miss_tv | store_miss_tv | lr_miss_tv | wt_miss_tv;

  // Load reserved misses if not in exclusive or modified (whether load hit or not)
  assign lr_hit_tv = v_tv_r & decode_tv_r.lr_op & store_hit_tv & (lr_sc_p == e_l1);
  // Succeed if the address matches and we have a store hit
  assign sc_success  = v_tv_r & decode_tv_r.sc_op & store_hit_tv & load_reserved_v_r
                       & (load_reserved_tag_r == addr_tag_tv_r)
                       & (load_reserved_index_r == addr_index_tv) & (lr_sc_p == e_l1);

  // Fail if we have a store conditional without success
  assign sc_fail     = v_tv_r & decode_tv_r.sc_op & ~sc_success;
  assign uncached_load_req = v_tv_r & decode_tv_r.load_op & uncached_tv_r & ~uncached_load_data_v_r;
  assign uncached_store_req = v_tv_r & decode_tv_r.store_op & uncached_tv_r;
  assign fencei_req = v_tv_r & decode_tv_r.fencei_op;

  // write buffer
  //
  `declare_bp_be_dcache_wbuf_entry_s(paddr_width_p, dword_width_p, dcache_assoc_p);

  bp_be_dcache_wbuf_entry_s wbuf_entry_in;
  logic wbuf_success;
  logic wbuf_v_li;

  bp_be_dcache_wbuf_entry_s wbuf_entry_out;
  logic wbuf_v_lo;
  logic wbuf_yumi_li;

  logic wbuf_empty_lo;
  logic wbuf_full_lo;

  logic bypass_v_li;
  logic bypass_addr_li;
  logic [dword_width_p-1:0] bypass_data_lo;
  logic [wbuf_data_mask_width_lp-1:0] bypass_mask_lo;

  logic [index_width_lp-1:0] lce_snoop_index_li;
  logic [lg_dcache_assoc_lp-1:0] lce_snoop_way_li;
  logic lce_snoop_match_lo;

  bp_be_dcache_wbuf
    #(.data_width_p(dword_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.ways_p(dcache_assoc_p)
      ,.sets_p(dcache_sets_p)
      )
    wbuf
    ( .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.v_i(wbuf_v_li)
      ,.wbuf_entry_i(wbuf_entry_in)

      ,.v_o(wbuf_v_lo)
      ,.yumi_i(wbuf_yumi_li)
      ,.wbuf_entry_o(wbuf_entry_out)

      ,.empty_o(wbuf_empty_lo)
      ,.full_o(wbuf_full_lo)

      ,.bypass_v_i(bypass_v_li)
      ,.bypass_addr_i({ptag_i, page_offset_tl_r})
      ,.bypass_data_o(bypass_data_lo)
      ,.bypass_mask_o(bypass_mask_lo)

      ,.lce_snoop_index_i(lce_snoop_index_li)
      ,.lce_snoop_way_i(lce_snoop_way_li)
      ,.lce_snoop_match_o(lce_snoop_match_lo)
      );

  logic [bank_offset_width_lp-1:0] wbuf_entry_out_bank_offset;
  logic [index_width_lp-1:0] wbuf_entry_out_index;

  assign wbuf_entry_out_bank_offset = wbuf_entry_out.paddr[byte_offset_width_lp+:bank_offset_width_lp];
  assign wbuf_entry_out_index = wbuf_entry_out.paddr[block_offset_width_lp+:index_width_lp];

  assign wbuf_entry_in.paddr = paddr_tv_r;
  assign wbuf_entry_in.way_id = store_hit_way_tv;

  bp_be_fp_reg_s fp_reg;
  assign fp_reg = data_tv_r;

  logic [dword_width_p-1:0] fp_raw_data;
  bp_be_rec_to_fp
   #(.bp_params_p(bp_params_p))
   rec_to_fp
    (.rec_i(fp_reg.rec)

     ,.raw_sp_not_dp_i(fp_reg.sp_not_dp)
     ,.raw_o(fp_raw_data)
     );

  logic [3:0][dword_width_p-1:0] wbuf_data_in;
  logic [3:0][wbuf_data_mask_width_lp-1:0] wbuf_mask_in;
  for (genvar i = 0; i < 4; i++)
    begin : wbuf_in
      localparam slice_width_lp = 8*(2**i);
      logic [slice_width_lp-1:0] slice_data;

      logic [(dword_width_p/slice_width_lp)-1:0] addr_dec;
      bsg_decode
       #(.num_out_p(dword_width_p/slice_width_lp))
       decode
        (.i(paddr_tv_r[i+:`BSG_MAX(3-i,1)])
         ,.o(addr_dec)
         );

      bsg_expand_bitmask
       #(.in_width_p(dword_width_p/slice_width_lp)
         ,.expand_p(2**i)
         )
       expand
        (.i(addr_dec)
         ,.o(wbuf_mask_in[i])
         );

      if ((i == 2'b10) || (i == 2'b11))
        begin
          assign slice_data = decode_tv_r.float_op ? fp_raw_data[0+:slice_width_lp] : data_tv_r[0+:slice_width_lp];
        end
      else
        begin : fi
          assign slice_data = data_tv_r[0+:slice_width_lp];
        end

      assign wbuf_data_in[i] = {(dword_width_p/slice_width_lp){slice_data}};
    end

  bsg_mux_one_hot
   #(.width_p(dword_width_p)
     ,.els_p(4)
     )
   wbuf_data_in_mux
    (.data_i(wbuf_data_in)
     ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op, decode_tv_r.half_op, decode_tv_r.byte_op})
     ,.data_o(wbuf_entry_in.data)
     );

  bsg_mux_one_hot
   #(.width_p(wbuf_data_mask_width_lp)
     ,.els_p(4)
     )
   wbuf_mask_in_mux
    (.data_i(wbuf_mask_in)
     ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op, decode_tv_r.half_op, decode_tv_r.byte_op})
     ,.data_o(wbuf_entry_in.mask)
     );

  // stat_mem {lru, dirty}
  // It has (ways_p-1) bits to form pseudo-LRU tree, and ways_p bits for dirty
  // bit for each block in set.
  logic stat_mem_v_li;
  logic stat_mem_w_li;
  logic [index_width_lp-1:0] stat_mem_addr_li;
  bp_dcache_stat_info_s stat_mem_data_li;
  bp_dcache_stat_info_s stat_mem_mask_li;
  bp_dcache_stat_info_s stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(dcache_stat_info_width_lp)
      ,.els_p(dcache_sets_p)
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

  logic [lg_dcache_assoc_lp-1:0] lru_encode;

  bsg_lru_pseudo_tree_encode #(
    .ways_p(dcache_assoc_p)
  ) lru_encoder (
    .lru_i(stat_mem_data_lo.lru)
    ,.way_id_o(lru_encode)
  );

  logic invalid_exist;
  logic [lg_dcache_assoc_lp-1:0] invalid_way;
  bsg_priority_encode
    #(.width_p(dcache_assoc_p)
      ,.lo_to_hi_p(1)
      )
    pe_invalid
      (.i(invalid_tv_r)
      ,.v_o(invalid_exist)
      ,.addr_o(invalid_way)
      );

  // if there is invalid way, then it take prioirty over LRU way.
  wire [lg_dcache_assoc_lp-1:0] lru_way_li = invalid_exist ? invalid_way : lru_encode;

  // LCE Packet casting
  //
  bp_dcache_data_mem_pkt_s data_mem_pkt;
  assign data_mem_pkt = data_mem_pkt_i;
  bp_dcache_tag_mem_pkt_s tag_mem_pkt;
  assign tag_mem_pkt = tag_mem_pkt_i;
  bp_dcache_stat_mem_pkt_s stat_mem_pkt;
  assign stat_mem_pkt = stat_mem_pkt_i;

  logic data_mem_pkt_v;
  logic tag_mem_pkt_v;
  logic stat_mem_pkt_v;

  wire wt_req = (wbuf_v_li & (writethrough_p == 1));

  // Assigning message types
  always_comb begin
    cache_req_v_o = 1'b0;

    cache_req_cast_o = '0;

    // Assigning sizes to cache miss packet
    if (uncached_tv_r | wt_req | l2_amo_req) begin
      if (decode_tv_r.double_op)
        cache_req_cast_o.size = e_size_8B;
      else if (decode_tv_r.word_op)
        cache_req_cast_o.size = e_size_4B;
      else if (decode_tv_r.half_op)
        cache_req_cast_o.size = e_size_2B;
      else if (decode_tv_r.byte_op)
        cache_req_cast_o.size = e_size_1B;
    end
    else
      cache_req_cast_o.size = e_size_64B;

    if(load_miss_tv) begin
      cache_req_cast_o.msg_type = e_miss_load;
      cache_req_v_o = cache_req_ready_i & ~flush_i;
    end
    else if(store_miss_tv | lr_miss_tv) begin
      cache_req_cast_o.msg_type = e_miss_store;
      cache_req_v_o = cache_req_ready_i & ~flush_i;
    end
    else if(wt_req) begin
      cache_req_cast_o.msg_type = e_wt_store;
      cache_req_v_o = cache_req_ready_i & ~flush_i;
    end
    else if (l2_amo_req & ~uncached_load_data_v_r) begin
      cache_req_v_o = cache_req_ready_i;
      unique if (lr_req)
        cache_req_cast_o.msg_type = e_amo_lr;
      else if (sc_req)
        cache_req_cast_o.msg_type = e_amo_sc;
      else if (amoswap_req)
        cache_req_cast_o.msg_type = e_amo_swap;
      else if (amoadd_req)
        cache_req_cast_o.msg_type = e_amo_add;
      else if (amoxor_req)
        cache_req_cast_o.msg_type = e_amo_xor;
      else if (amoand_req)
        cache_req_cast_o.msg_type = e_amo_and;
      else if (amoor_req)
        cache_req_cast_o.msg_type = e_amo_or;
      else if (amomin_req)
        cache_req_cast_o.msg_type = e_amo_min;
      else if (amomax_req)
        cache_req_cast_o.msg_type = e_amo_max;
      else if (amominu_req)
        cache_req_cast_o.msg_type = e_amo_minu;
      else if (amomaxu_req)
        cache_req_cast_o.msg_type = e_amo_maxu;
    end
    else if(uncached_load_req) begin
      cache_req_cast_o.msg_type = e_uc_load;
      cache_req_v_o = cache_req_ready_i & ~flush_i;
    end
    else if(uncached_store_req) begin
      cache_req_cast_o.msg_type = e_uc_store;
      cache_req_v_o = cache_req_ready_i & ~flush_i;
    end
    else if(fencei_req) begin
      // Don't flush on fencei when coherent
      cache_req_cast_o.msg_type = e_cache_flush;
      cache_req_v_o = cache_req_ready_i & gdirty_r & (l1_coherent_p == 0);
    end

    cache_req_cast_o.addr = paddr_tv_r;
    cache_req_cast_o.data = data_tv_r;
  end

  // Cache metadata is valid after the request goes out
  bsg_dff_reset
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(stat_mem_v_li & ~stat_mem_w_li)
     ,.data_o(cache_req_metadata_v_o)
     );

  assign cache_req_metadata_cast_o.repl_way = lru_way_li;
  assign cache_req_metadata_cast_o.dirty = stat_mem_data_lo.dirty[lru_way_li];

  // output stage
  // Cache Miss Tracking logic
  logic cache_miss_r;
  bsg_dff_reset_set_clear
   #(.width_p(1), .clear_over_set_p(1))
   cache_miss_tracker
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     // We don't wait for ack on uncached stores or writethrough requests
     ,.set_i(cache_req_v_o & ~uncached_store_req & ~wt_req)
     ,.clear_i(cache_req_complete_i)
     ,.data_o(cache_miss_r)
     );
  assign ready_o = cache_req_ready_i & ~cache_miss_r;

  assign early_v_o = v_tv_r & ((uncached_tv_r & (decode_tv_r.load_op & uncached_load_data_v_r))
                              | (uncached_tv_r & (decode_tv_r.store_op & cache_req_ready_i))
                              | (~uncached_tv_r & ~decode_tv_r.l2_op & ~decode_tv_r.fencei_op & ~miss_tv)
                              // Always send fencei when coherent
                              | (fencei_req & (~gdirty_r | (l1_coherent_p == 1)))
                              );

  // Locking logic - Block processing of new dcache_packets
  logic cache_miss_resolved;
  bsg_edge_detect
   #(.falling_not_rising_p(1))
   cache_miss_detect
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.sig_i(cache_miss_r)
     ,.detect_o(cache_miss_resolved)
     );

  // Maintain a global dirty bit for the cache. When data is written to the write buffer, we set
  //   it. When we send a flush request to the CE, we clear it.
  // The way this works with fence.i is:
  //   1) If dirty bit is set, we force a miss and send off a flush request to the CE
  //   2) If dirty bit is not set, we do not send a request and simply return valid flush.
  //        The CSR unit is now responsible for sending the clear request to the I$.
  wire flush_req = cache_req_v_o & (cache_req_cast_o.msg_type == e_cache_flush);

  if (writethrough_p == 1)
    begin : wt
      assign gdirty_r = '0;
    end
  else
    begin : wb
      bsg_dff_reset_en
       #(.width_p(1))
       gdirty_reg
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.en_i(wbuf_v_li | flush_req)
        ,.data_i(wbuf_v_li)

        ,.data_o(gdirty_r)
        );
    end

  logic [`BSG_SAFE_CLOG2(lock_max_limit_p+1)-1:0] lock_cnt_r;
  wire lock_clr = early_v_o || (lock_cnt_r == lock_max_limit_p);
  wire lock_inc = ~lock_clr & (cache_miss_resolved || lr_hit_tv || (lock_cnt_r > 0));

  bsg_counter_clear_up
   #(.max_val_p(lock_max_limit_p)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   lock_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(lock_clr)
     ,.up_i(lock_inc)
     ,.count_o(lock_cnt_r)
     );

  wire cache_lock = (lock_cnt_r != '0);

  assign data_mem_pkt_v = data_mem_pkt_v_i & ~cache_lock;
  assign tag_mem_pkt_v = tag_mem_pkt_v_i & ~cache_lock;
  assign stat_mem_pkt_v = stat_mem_pkt_v_i & ~cache_lock;


  logic [bank_width_lp-1:0] ld_data_way_picked;
  logic [dword_width_p-1:0] ld_data_dword_picked;
  logic [dword_width_p-1:0] ld_data_final;
  logic [dword_width_p-1:0] bypass_data_masked;
  logic [dcache_assoc_p-1:0] ld_data_way_select;

  bsg_adder_one_hot
   #(.width_p(dcache_assoc_p))
   select_adder
    (.a_i(load_hit_tv_r)
     ,.b_i(addr_bank_offset_dec_tv_r)
     ,.o(ld_data_way_select)
     );

  bsg_mux_one_hot #(
    .width_p(bank_width_lp)
    ,.els_p(dcache_assoc_p)
  ) ld_data_set_select_mux (
    .data_i(ld_data_tv_r)
    ,.sel_one_hot_i(ld_data_way_select)
    ,.data_o(ld_data_way_picked)
  );

  bsg_mux #(
    .width_p(dword_width_p)
    ,.els_p(num_dwords_per_bank_lp)
  ) dword_mux (
    .data_i(ld_data_way_picked)
    ,.sel_i(paddr_tv_r[3+:`BSG_CDIV(num_dwords_per_bank_lp, 2)])
    ,.data_o(ld_data_dword_picked)
    );

  bsg_mux_segmented #(
    .segments_p(wbuf_data_mask_width_lp)
    ,.segment_width_p(8)
  ) bypass_mux_segmented (
    .data0_i(ld_data_dword_picked)
    ,.data1_i(bypass_data_lo)
    ,.sel_i(bypass_mask_lo)
    ,.data_o(bypass_data_masked)
  );

  logic [dword_width_p-1:0] result_data;
  bsg_mux #(
    .width_p(dword_width_p)
    ,.els_p(2)
  ) final_data_mux (
    .data_i({uncached_load_data_r, bypass_data_masked})
    ,.sel_i(uncached_tv_r)
    ,.data_o(result_data)
  );

  logic [3:0][dword_width_p-1:0] sigext_data;
  for (genvar i = 0; i < 4; i++)
    begin : alignment
      localparam slice_width_lp = 8*(2**i);

      logic [slice_width_lp-1:0] slice_data;
      bsg_mux #(
        .width_p(slice_width_lp)
        ,.els_p(dword_width_p/slice_width_lp)
      ) align_mux (
        .data_i(result_data)
        ,.sel_i(paddr_tv_r[i+:`BSG_MAX(1, 3-i)])
        ,.data_o(slice_data)
      );

      wire sigext = decode_tv_r.signed_op & slice_data[slice_width_lp-1];
      assign sigext_data[i] = {{(dword_width_p-slice_width_lp){sigext}}, slice_data};
    end

  logic [dword_width_p-1:0] final_data;
  bsg_mux_one_hot #(
    .width_p(dword_width_p)
    ,.els_p(4)
  ) byte_mux (
    .data_i(sigext_data)
    ,.sel_one_hot_i({decode_tv_r.double_op, decode_tv_r.word_op, decode_tv_r.half_op, decode_tv_r.byte_op})
    ,.data_o(final_data)
  );

  assign early_data_o = (decode_tv_r.load_op | (sc_req & decode_tv_r.l2_op))
    ? final_data
    : decode_tv_r.sc_op & ~sc_success;

  // DM stage
  //
  logic dm_we;
  logic v_dm_r;
  logic [dword_width_p-1:0] data_dm_r;
  logic [3:0] byte_offset_dm_r;
  logic double_op_dm_r, word_op_dm_r, half_op_dm_r, byte_op_dm_r;
  logic signed_op_dm_r, float_op_dm_r;

  assign dm_we = v_tv_r & early_v_o;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      v_dm_r <= '0;
    end else begin
      v_dm_r <= dm_we & ~flush_i;

      if (dm_we) begin
        data_dm_r        <= early_data_o;
        byte_offset_dm_r <= paddr_tv_r[0+:4];
        signed_op_dm_r   <= decode_tv_r.signed_op;
        float_op_dm_r    <= decode_tv_r.float_op;
        double_op_dm_r   <= decode_tv_r.double_op;
        word_op_dm_r     <= decode_tv_r.word_op;
        half_op_dm_r     <= decode_tv_r.half_op;
        byte_op_dm_r     <= decode_tv_r.byte_op;
      end
    end
  end

  bp_be_fp_reg_s final_float_data;
  bp_be_fp_to_rec
   #(.bp_params_p(bp_params_p))
   fp_to_rec
    (.raw_i(data_dm_r)
     ,.raw_sp_not_dp_i(word_op_dm_r)

     ,.rec_sp_not_dp_o(final_float_data.sp_not_dp)
     ,.rec_o(final_float_data.rec)
     );

  assign final_data_o = float_op_dm_r ? final_float_data : data_dm_r;
  assign final_v_o = v_dm_r;

  // ctrl logic
  //

  // data_mem
  //
  logic [dcache_assoc_p-1:0] wbuf_data_mem_v;
  logic [bank_offset_width_lp-1:0] wbuf_data_mem_offset;
  assign wbuf_data_mem_offset = (bank_offset_width_lp'(wbuf_entry_out.way_id) + wbuf_entry_out_bank_offset);
  bsg_decode #(
    .num_out_p(dcache_assoc_p)
  ) wbuf_data_mem_v_decode (
    .i(wbuf_data_mem_offset)
    ,.o(wbuf_data_mem_v)
  );

  wire lce_data_mem_v = (data_mem_pkt.opcode != e_cache_data_mem_uncached)
    & data_mem_pkt_yumi_o;

  assign data_mem_v_li = lce_data_mem_v
    ? {dcache_assoc_p{lce_data_mem_v}}
    : wbuf_yumi_li
      ? wbuf_data_mem_v
      : {dcache_assoc_p{decode_lo.load_op & tl_we}};

  assign data_mem_w_li = wbuf_yumi_li
    | (data_mem_pkt_yumi_o & data_mem_pkt.opcode == e_cache_data_mem_write);

  logic [dcache_assoc_p-1:0][bank_width_lp-1:0]               lce_data_mem_write_data;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0]               data_mem_pkt_data_expanded;
  logic [block_size_in_fill_lp-1:0][fill_size_in_bank_lp-1:0] data_mem_pkt_fill_mask_expanded;
  logic [dcache_assoc_p-1:0]                                  data_mem_write_bank_mask;

  // use fill_index to generate brank write mask
  for (genvar i = 0; i < block_size_in_fill_lp; i++) begin
    assign data_mem_pkt_fill_mask_expanded[i] = {fill_size_in_bank_lp{data_mem_pkt.fill_index[i]}};
  end

  logic [data_mem_mask_width_lp-1:0] wbuf_mask;
  logic [byte_offset_width_lp-1:0] mask_shift;
  if (num_dwords_per_bank_lp == 1) begin : passthrough_wbuf_mask
    assign mask_shift = '0;
    assign wbuf_mask = wbuf_entry_out.mask;
  end
  else begin : shift_wbuf_mask
    assign mask_shift = wbuf_entry_out.paddr[3+:`BSG_SAFE_CLOG2(num_dwords_per_bank_lp)] << 3;
    assign wbuf_mask = wbuf_entry_out.mask << mask_shift;
  end

  for (genvar i = 0; i < dcache_assoc_p; i++) begin
    wire [bank_offset_width_lp-1:0] data_mem_pkt_offset = (bank_offset_width_lp'(i) - data_mem_pkt.way_id);

    assign data_mem_addr_li[i] = (decode_lo.load_op & tl_we)
      ? {addr_index, addr_bank_offset}
      : wbuf_yumi_li
        ? {wbuf_entry_out_index, wbuf_entry_out_bank_offset}
        : {data_mem_pkt.index, data_mem_pkt_offset};

    assign data_mem_data_li[i] = wbuf_yumi_li
      ? {num_dwords_per_bank_lp{wbuf_entry_out.data}}
      : lce_data_mem_write_data[i];

    // Expand the bank write mask to bank width
    assign data_mem_mask_li[i] = wbuf_yumi_li
      ? wbuf_mask
      : {data_mem_mask_width_lp{data_mem_write_bank_mask[i]}};
  end

  // Expand data_mem_pkt.data (fill width) to cacheline width
  assign data_mem_pkt_data_expanded = {block_size_in_fill_lp{data_mem_pkt.data}};

  wire [`BSG_SAFE_CLOG2(dcache_block_width_p)-1:0] write_data_rot_li = data_mem_pkt.way_id*bank_width_lp;
  bsg_rotate_left #(
    .width_p(dcache_block_width_p)
  ) write_data_rotate (
    .data_i(data_mem_pkt_data_expanded)
    ,.rot_i(write_data_rot_li)
    ,.o(lce_data_mem_write_data)
  );

  wire [`BSG_SAFE_CLOG2(dcache_assoc_p)-1:0] write_mask_rot_li = data_mem_pkt.way_id;
  bsg_rotate_left #(
    .width_p(dcache_assoc_p)
  ) write_mask_rotate (
    .data_i(data_mem_pkt_fill_mask_expanded)
    ,.rot_i(write_mask_rot_li)
    ,.o(data_mem_write_bank_mask)
  );

  // tag_mem
  //
  assign tag_mem_v_li = tl_we | tag_mem_pkt_yumi_o;
  assign tag_mem_w_li = tag_mem_pkt_yumi_o & (tag_mem_pkt.opcode != e_cache_tag_mem_read);
  assign tag_mem_addr_li = tag_mem_pkt_yumi_o
    ? tag_mem_pkt.index
    : addr_index;

  logic [dcache_assoc_p-1:0] lce_tag_mem_way_one_hot;
  bsg_decode
    #(.num_out_p(dcache_assoc_p))
    lce_tag_mem_way_decode
      (.i(tag_mem_pkt.way_id)
      ,.o(lce_tag_mem_way_one_hot)
      );

  always_comb begin
    case (tag_mem_pkt.opcode)
      e_cache_tag_mem_set_clear: begin
        tag_mem_data_li = {(tag_info_width_lp*dcache_assoc_p){1'b0}};
        tag_mem_mask_li = {(tag_info_width_lp*dcache_assoc_p){1'b1}};
      end
      e_cache_tag_mem_set_tag: begin
        tag_mem_data_li = {dcache_assoc_p{tag_mem_pkt.state, tag_mem_pkt.tag}};
        for (integer i = 0; i < dcache_assoc_p; i++) begin
          tag_mem_mask_li[i].coh_state = bp_coh_states_e'({$bits(bp_coh_states_e){lce_tag_mem_way_one_hot[i]}});
          tag_mem_mask_li[i].tag = {ptag_width_lp{lce_tag_mem_way_one_hot[i]}};
        end
      end
      e_cache_tag_mem_set_state: begin
        tag_mem_data_li = {dcache_assoc_p{tag_mem_pkt.state, tag_mem_pkt.tag}};
        for (integer i = 0; i < dcache_assoc_p; i++) begin
          tag_mem_mask_li[i].coh_state = bp_coh_states_e'({$bits(bp_coh_states_e){lce_tag_mem_way_one_hot[i]}});
          tag_mem_mask_li[i].tag = {ptag_width_lp{1'b0}};
        end
      end
      default: begin
        tag_mem_data_li = {(tag_info_width_lp*dcache_assoc_p){1'b0}};
        tag_mem_mask_li = {(tag_info_width_lp*dcache_assoc_p){1'b0}};
      end
    endcase
  end

  // stat_mem
  //
  assign stat_mem_v_li = (v_tv_r & ~uncached_tv_r & ~decode_tv_r.fencei_op & ~flush_i & ~decode_tv_r.l2_op) | stat_mem_pkt_yumi_o;
  assign stat_mem_w_li = stat_mem_pkt_yumi_o
    ? (stat_mem_pkt.opcode != e_cache_stat_mem_read)
    : ~miss_tv & ~decode_tv_r.l2_op;
  assign stat_mem_addr_li = stat_mem_pkt_yumi_o
    ? stat_mem_pkt.index
    : addr_index_tv;

  logic [lg_dcache_assoc_lp-1:0] lru_decode_way_li;
  logic [dcache_assoc_p-2:0] lru_decode_data_lo;
  logic [dcache_assoc_p-2:0] lru_decode_mask_lo;

  bsg_lru_pseudo_tree_decode #(
    .ways_p(dcache_assoc_p)
  ) lru_decode (
    .way_id_i(lru_decode_way_li)
    ,.data_o(lru_decode_data_lo)
    ,.mask_o(lru_decode_mask_lo)
  );


  logic [lg_dcache_assoc_lp-1:0] dirty_mask_way_li;
  logic dirty_mask_v_li;
  logic [dcache_assoc_p-1:0] dirty_mask_lo;

  bsg_decode_with_v
    #(.num_out_p(dcache_assoc_p))
    dirty_mask_decode
      (.i(dirty_mask_way_li)
      ,.v_i(dirty_mask_v_li)
      ,.o(dirty_mask_lo)
      );

  always_comb begin
    if (v_tv_r) begin
      lru_decode_way_li = decode_tv_r.store_op ? store_hit_way_tv : load_hit_way_tv;
      dirty_mask_way_li = store_hit_way_tv;
      dirty_mask_v_li = decode_tv_r.store_op & (writethrough_p == 0); // Blocks are never dirty in a writethrough cache

      stat_mem_data_li.lru = lru_decode_data_lo;
      stat_mem_data_li.dirty = {dcache_assoc_p{1'b1}};
      stat_mem_mask_li = {lru_decode_mask_lo, dirty_mask_lo};
    end
    else begin
      lru_decode_way_li = stat_mem_pkt.way_id;
      dirty_mask_way_li = stat_mem_pkt.way_id;
      dirty_mask_v_li = 1'b1;
      case (stat_mem_pkt.opcode)
        e_cache_stat_mem_set_clear: begin
          stat_mem_data_li = {(dcache_stat_info_width_lp){1'b0}};
          stat_mem_mask_li = {(dcache_stat_info_width_lp){1'b1}};
        end
        e_cache_stat_mem_clear_dirty: begin
          stat_mem_data_li = {(dcache_stat_info_width_lp){1'b0}};
          stat_mem_mask_li.lru = {(dcache_assoc_p-1){1'b0}};
          stat_mem_mask_li.dirty = dirty_mask_lo;
        end
        default: begin
          stat_mem_data_li = {(dcache_stat_info_width_lp){1'b0}};
          stat_mem_mask_li = {(dcache_stat_info_width_lp){1'b0}};
        end
      endcase
    end
  end


  // write buffer
  //
  // We break out wbuf_sucess from wbuf_v_li to break a critical path from
  //   flush to the data mem address lines. We pessimistically consider the
  //   wbuf to have an incoming entry if there's something going into the
  //   write buffer, regardless of if it's poisoned or not
  if (writethrough_p == 0) begin : wb_wbuf
    assign wbuf_success = v_tv_r & decode_tv_r.store_op & store_hit_tv & ~sc_fail & ~uncached_tv_r & ~decode_tv_r.l2_op;
  end
  else begin : wt_wbuf
    assign wbuf_success = v_tv_r & decode_tv_r.store_op & store_hit_tv & ~sc_fail & ~uncached_tv_r & ~decode_tv_r.l2_op & cache_req_ready_i;
  end
  assign wbuf_v_li = wbuf_success & ~flush_i;
  assign wbuf_yumi_li = wbuf_v_lo & ~(decode_lo.load_op & tl_we) & ~data_mem_pkt_yumi_o;

  assign bypass_v_li = tv_we & decode_tl_r.load_op;
  assign lce_snoop_index_li = data_mem_pkt.index;
  assign lce_snoop_way_li = data_mem_pkt.way_id;

  // LCE data_mem
  //
  logic [lg_dcache_assoc_lp-1:0] data_mem_pkt_way_r;

  always_ff @ (negedge clk_i) begin
    if (data_mem_pkt_yumi_o & (data_mem_pkt.opcode == e_cache_data_mem_read)) begin
      data_mem_pkt_way_r <= data_mem_pkt.way_id;
    end
  end

  wire [`BSG_SAFE_CLOG2(dcache_block_width_p)-1:0] read_data_rot_li = data_mem_pkt_way_r*bank_width_lp;
  bsg_rotate_right #(
    .width_p(dcache_block_width_p)
  ) read_data_rotate (
    .data_i(data_mem_data_lo)
    ,.rot_i(read_data_rot_li)
    ,.o(data_mem_o)
  );

  // A similar scheme could be adopted for a non-blocking version, where we snoop the bank
  // As an optimization, we could snoop the data_mem_pkt to see if there are any matching entries
  //   in the write buffer, so that the write buffer will only drain if it is full, or if there is
  //   a snoop match. However, this is a critical path, so we simply drain the write buffer on
  //   invalidations.
  // A similar scheme could be adopted for a non-blocking version, where we snoop the bank
  assign data_mem_pkt_yumi_o = (data_mem_pkt.opcode == e_cache_data_mem_uncached)
                               ? data_mem_pkt_v
                               : data_mem_pkt_v & ~(decode_lo.load_op & tl_we) & wbuf_empty_lo & ~wbuf_success;

  if (lr_sc_p == e_l1)
    begin : l1_lrsc
      // Set reservation on successful LR, without a cache miss or upgrade request
      wire set_reservation = decode_tv_r.lr_op & early_v_o;
      // All SCs clear the reservation (regardless of success)
      // Invalidates from other harts which match the reservation address clear the reservation
      wire clear_reservation = decode_tv_r.sc_op
                               || ((tag_mem_pkt_yumi_o & (tag_mem_pkt.opcode == e_cache_tag_mem_set_state) && (tag_mem_pkt.state == e_COH_I))
                                   & (tag_mem_pkt.tag == load_reserved_tag_r) & (tag_mem_pkt.index == load_reserved_index_r));
      bsg_dff_reset_set_clear
       #(.width_p(1))
       load_reserved_v_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.set_i(set_reservation)
         ,.clear_i(clear_reservation)
         ,.data_o(load_reserved_v_r)
         );

      bsg_dff_en
       #(.width_p(ptag_width_lp+index_width_lp))
       load_reserved_addr
        (.clk_i(clk_i)
         ,.en_i(set_reservation)
         ,.data_i(paddr_tv_r[paddr_width_p-1:block_offset_width_lp])
         ,.data_o({load_reserved_tag_r, load_reserved_index_r})
         );
    end
  else
    begin : no_l1_lrsc
      assign load_reserved_v_r = '0;
      assign load_reserved_tag_r = '0;
      assign load_reserved_index_r = '0;
    end

  //  uncached load data logic
  //
  wire uncached_load_set = data_mem_pkt_yumi_o & (data_mem_pkt.opcode == e_cache_data_mem_uncached);
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
   #(.width_p(dword_width_p))
   uncached_load_data_reg
    (.clk_i(clk_i)
     ,.en_i(uncached_load_set)

     ,.data_i(data_mem_pkt.data[0+:dword_width_p])
     ,.data_o(uncached_load_data_r)
     );

  // LCE tag_mem

  logic [lg_dcache_assoc_lp-1:0] tag_mem_pkt_way_r;

  always_ff @ (negedge clk_i) begin
    if (tag_mem_pkt_yumi_o & (tag_mem_pkt.opcode == e_cache_tag_mem_read)) begin
      tag_mem_pkt_way_r <= tag_mem_pkt.way_id;
    end
  end

  assign tag_mem_o =  tag_mem_data_lo[tag_mem_pkt_way_r].tag;

  assign tag_mem_pkt_yumi_o = ~tl_we & tag_mem_pkt_v;

  // LCE stat_mem
  //
  assign stat_mem_pkt_yumi_o = ~(v_tv_r & ~uncached_tv_r) & stat_mem_pkt_v;

  logic [lg_dcache_assoc_lp-1:0] stat_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (stat_mem_pkt_yumi_o & (stat_mem_pkt.opcode == e_cache_stat_mem_read)) begin
      stat_mem_pkt_way_r <= stat_mem_pkt.way_id;
    end
  end

  assign stat_mem_o = stat_mem_data_lo;

  // synopsys translate_off
  if (debug_p) begin: axe
    bp_be_dcache_axe_trace_gen
      #(.addr_width_p(paddr_width_p)
        ,.data_width_p(dword_width_p)
        ,.num_lce_p(num_lce_p)
        )
      axe_trace_gen
        (.clk_i(clk_i)
        ,.id_i(cfg_bus_cast_i.dcache_id)
        ,.v_i(early_v_o)
        ,.addr_i(paddr_tv_r)
        ,.load_data_i(final_data_o)
        ,.store_data_i(data_tv_r)
        ,.load_i(decode_tv_r.load_op)
        ,.store_i(decode_tv_r.store_op)
        );
  end

  always_ff @ (posedge clk_i) begin
    if (v_tv_r) begin
      assert($countones(load_hit_tl) <= 1)
        else $error("multiple load hit: %b. id = %0d. addr = %H", load_hit_tl, cfg_bus_cast_i.dcache_id, addr_tag_tl);
      assert($countones(store_hit_tl) <= 1)
        else $error("multiple store hit: %b. id = %0d. addr = %H", store_hit_tl, cfg_bus_cast_i.dcache_id, addr_tag_tl);
    end
  end

  initial begin
    assert(dword_width_p == 64) else $error("dword_width_p has to be 64");
    assert(dcache_assoc_p == 8 | dcache_assoc_p == 4 | dcache_assoc_p == 2) else $error("dcache_assoc_p has to be 8, 4 or 2");
  end
  // synopsys translate_on

endmodule
