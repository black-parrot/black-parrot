/**
 *
 * Name:
 *   bp_fe_icache.sv
 *
 * Description:
 *   L1 Instruction Cache. Features:
 *   - Virtually-indexed, physically-tagged
 *   - 1-8 way set-associative
 *   - 64-512 bit block size (minimum 64-bit data mem bank size)
 *   - Separate speculative and non-speculative fetch commands
 *
 *   An address is broken down as follows:
 *     physical address = [physical tag | virtual index | block offset]
 *
 *   There are 3 large SRAMs (must be hardened for good QoR):
 *   - Tag Mem: Physical tags and coherence state
 *   - Data Mem: Cache data blocks. 1 bank per way, with data
 *       interleaved between the banks as bank_id = word_offset + way_id
 *   - Stat Mem: Contains the LRU and information for the cache line
 *
 * See interface for usage notes
 *
 * Notes:
 *    Supports multi-cycle fill/eviction with the UCE in unicore configuration
 *    Uses fill_index in data_mem_pkt to generate a write_mask for the data banks
 *      bank_width = block_width / assoc >= dword_width
 *      fill_width = N*bank_width <= block_width
 */

`include "bp_common_defines.svh"
`include "bp_fe_defines.svh"

module bp_fe_icache
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Default to icache parameters, but can override if needed
   , parameter coherent_p    = icache_coherent_p
   , parameter sets_p        = icache_sets_p
   , parameter assoc_p       = icache_assoc_p
   , parameter block_width_p = icache_block_width_p
   , parameter fill_width_p  = icache_fill_width_p

   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, icache)
   , localparam cfg_bus_width_lp    = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   // Unused except for tracers
   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   // Cycle 0: "Decode"
   // New I$ packet comes in for a fetch, fence or fill request
   // v_i is raised when there is a new request
   // yumi_o is raised when that request is accepted
   // poison_tl_i negates the yumi_o without putting pressure on SRAM paths
   // Normally, yumi_o waits for TL to be empty so as to not lose
   //   requests. However, when we're redirecting the I$ we may want
   //   to override the TL message right away. force_i says to accept
   //   regardless of v_tl_r status
   , input [icache_pkt_width_lp-1:0]                  icache_pkt_i
   , input                                            v_i
   , input                                            force_i
   , output                                           yumi_o
   , input                                            poison_tl_i

   // Cycle 1: "Tag Lookup"
   // TLB and PMA information comes in this cycle
   // poison_tv_i eliminates the request in this stage, used for redirections
   // We output tv_we as a signal to move parallel pipelines forward
   , input [ptag_width_p-1:0]                         ptag_i
   , input                                            ptag_v_i
   , input                                            ptag_uncached_i
   , input                                            ptag_nonidem_i
   , input                                            ptag_dram_i
   , input                                            poison_tv_i
   , output logic                                     tv_we_o

   // Cycle 2: "Tag Verify"
   // Data (or miss result) comes out of the cache
   // Cache engine requests cannot be cancelled once they come here, but poison_tv_i
   //   will prevent them from escaping the I$.
   // data_o is the outgoing data, with data_v_o being valid
   // fence_v_o is if a fence instruction has completed
   // spec_v_o is if there is a cache miss, but we have decided not to send it out
   //   because we need backend confirmation of its validity
   // yumi_i is required to dequeue any of these outputs
   , output logic [instr_width_gp-1:0]                data_o
   , output logic                                     data_v_o
   , output logic                                     fence_v_o
   , output logic                                     spec_v_o
   , input                                            yumi_i

   // Cache Engine Interface
   // This is considered the "slow path", handling uncached requests
   //   and fill DMAs. It also handles coherence transactions for
   //   configurations which support that behavior
   , output logic [icache_req_width_lp-1:0]           cache_req_o
   , output logic                                     cache_req_v_o
   , input                                            cache_req_ready_and_i
   , input                                            cache_req_busy_i
   , output logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o
   , output logic                                     cache_req_metadata_v_o
   , input                                            cache_req_critical_tag_i
   , input                                            cache_req_critical_data_i
   , input                                            cache_req_complete_i
   , input                                            cache_req_credits_full_i
   , input                                            cache_req_credits_empty_i

   , input                                            data_mem_pkt_v_i
   , input [icache_data_mem_pkt_width_lp-1:0]         data_mem_pkt_i
   , output logic                                     data_mem_pkt_yumi_o
   , output logic [block_width_p-1:0]                 data_mem_o

   , input                                            tag_mem_pkt_v_i
   , input [icache_tag_mem_pkt_width_lp-1:0]          tag_mem_pkt_i
   , output logic                                     tag_mem_pkt_yumi_o
   , output logic [icache_tag_info_width_lp-1:0]      tag_mem_o

   , input                                            stat_mem_pkt_v_i
   , input [icache_stat_mem_pkt_width_lp-1:0]         stat_mem_pkt_i
   , output logic                                     stat_mem_pkt_yumi_o
   , output logic [icache_stat_info_width_lp-1:0]     stat_mem_o
   );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, icache);
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  // Various localparameters
  localparam lg_assoc_lp            =`BSG_SAFE_CLOG2(assoc_p);
  localparam bank_width_lp          = block_width_p / assoc_p;
  localparam num_words_per_bank_lp  = bank_width_lp / word_width_gp;
  localparam data_mem_mask_width_lp = (bank_width_lp >> 3);
  localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(bank_width_lp >> 3);
  localparam bindex_width_lp        = `BSG_SAFE_CLOG2(assoc_p);
  localparam sindex_width_lp        = `BSG_SAFE_CLOG2(sets_p);
  localparam block_offset_width_lp  = (assoc_p > 1)
    ? (bindex_width_lp+byte_offset_width_lp)
    : byte_offset_width_lp;
  localparam block_size_in_fill_lp  = block_width_p / fill_width_p;
  localparam fill_size_in_bank_lp   = fill_width_p / bank_width_lp;

  // State machine declaration
  enum logic [1:0] {e_busy, e_ready, e_miss, e_recover} state_n, state_r;
  wire is_busy    = (state_r == e_busy);
  wire is_ready   = (state_r == e_ready);
  wire is_miss    = (state_r == e_miss);
  wire is_recover = (state_r == e_recover);

  // Feedback signals between stages
  logic safe_tl_we, tl_we, safe_tv_we, tv_we;
  logic v_tl_n, v_tl_r, v_tv_n, v_tv_r;

  /////////////////////////////////////////////////////////////////////////////
  // Decode stage
  /////////////////////////////////////////////////////////////////////////////
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  `bp_cast_i(bp_fe_icache_pkt_s, icache_pkt);

  wire fetch_op  = (icache_pkt_cast_i.op inside {e_icache_fetch});
  wire fencei_op = (icache_pkt_cast_i.op inside {e_icache_fencei});

  wire [vaddr_width_p-1:0]   vaddr       = icache_pkt_cast_i.vaddr;
  wire [vtag_width_p-1:0]    vaddr_vtag  = vaddr[block_offset_width_lp+sindex_width_lp+:vtag_width_p];
  wire [sindex_width_lp-1:0] vaddr_index = vaddr[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0] vaddr_bank  = vaddr[byte_offset_width_lp+:bindex_width_lp];

  wire spec = icache_pkt_cast_i.spec;

  assign yumi_o = safe_tl_we;

  ///////////////////////////
  // Tag Mem Storage
  ///////////////////////////
  `bp_cast_i(bp_icache_tag_mem_pkt_s, tag_mem_pkt);
  logic                              tag_mem_v_li;
  logic                              tag_mem_w_li;
  logic [sindex_width_lp-1:0]        tag_mem_addr_li;
  bp_icache_tag_info_s [assoc_p-1:0] tag_mem_w_mask_li;
  bp_icache_tag_info_s [assoc_p-1:0] tag_mem_data_li;
  bp_icache_tag_info_s [assoc_p-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
   #(.width_p(assoc_p*($bits(bp_icache_tag_info_s))), .els_p(sets_p), .latch_last_read_p(1))
   tag_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(tag_mem_data_li)
     ,.addr_i(tag_mem_addr_li)
     ,.v_i(tag_mem_v_li)
     ,.w_mask_i(tag_mem_w_mask_li)
     ,.w_i(tag_mem_w_li)
     ,.data_o(tag_mem_data_lo)
     );

  ///////////////////////////
  // Data Mem Storage
  ///////////////////////////
  `bp_cast_i(bp_icache_data_mem_pkt_s, data_mem_pkt);
  localparam data_mem_addr_width_lp = (assoc_p > 1) ? (sindex_width_lp+bindex_width_lp) : sindex_width_lp;
  logic [assoc_p-1:0]                             data_mem_v_li;
  logic [assoc_p-1:0]                             data_mem_w_li;
  logic [assoc_p-1:0][data_mem_addr_width_lp-1:0] data_mem_addr_li;
  logic [assoc_p-1:0][bank_width_lp-1:0]          data_mem_data_li;
  logic [assoc_p-1:0][bank_width_lp-1:0]          data_mem_data_lo;

  for (genvar bank = 0; bank < assoc_p; bank++)
    begin: data_mems
      bsg_mem_1rw_sync #(.width_p(bank_width_lp), .els_p(sets_p*assoc_p), .latch_last_read_p(1))
       data_mem
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.data_i(data_mem_data_li[bank])
         ,.addr_i(data_mem_addr_li[bank])
         ,.v_i(data_mem_v_li[bank])
         ,.w_i(data_mem_w_li[bank])
         ,.data_o(data_mem_data_lo[bank])
         );
    end

  /////////////////////////////////////////////////////////////////////////////
  // TL Stage
  /////////////////////////////////////////////////////////////////////////////
  logic [vaddr_width_p-1:0] vaddr_tl_r;
  logic spec_tl_r, fetch_op_tl_r, fencei_op_tl_r;

  // Accept requests when we're in ready state and there's no blocked request in TL
  // Also accept request when 'forced'
  assign safe_tl_we = is_ready & v_i & (~v_tl_r | tv_we | force_i);
  assign tl_we = safe_tl_we | poison_tl_i;
  assign v_tl_n = yumi_o & ~poison_tl_i;
  bsg_dff_reset_en
   #(.width_p(1))
   v_tl_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tl_we)

     ,.data_i(v_tl_n)
     ,.data_o(v_tl_r)
     );

  wire v_tl = is_ready & v_tl_r;

  // Save stage information
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p+3))
   tl_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tl_we)
     ,.data_i({vaddr, spec, fetch_op, fencei_op})
     ,.data_o({vaddr_tl_r, spec_tl_r, fetch_op_tl_r, fencei_op_tl_r})
     );

  wire [paddr_width_p-1:0]         paddr_tl = {ptag_i, vaddr_tl_r[0+:page_offset_width_gp]};
  wire [vtag_width_p-1:0]     vaddr_vtag_tl = vaddr_tl_r[block_offset_width_lp+sindex_width_lp+:vtag_width_p];
  wire [sindex_width_lp-1:0] vaddr_index_tl = vaddr_tl_r[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0]  vaddr_bank_tl = vaddr_tl_r[byte_offset_width_lp+:bindex_width_lp];

  logic [assoc_p-1:0] way_v_tl, hit_v_tl;
  for (genvar i = 0; i < assoc_p; i++) begin: tag_comp_tl
    assign way_v_tl[i] = (tag_mem_data_lo[i].state != e_COH_I);
    assign hit_v_tl[i] = (tag_mem_data_lo[i].tag == ptag_i) && way_v_tl[i];
  end
  wire fetch_uncached_tl = (fetch_op_tl_r &  ptag_uncached_i);
  wire fetch_cached_tl   = (fetch_op_tl_r & ~ptag_uncached_i);
  wire fill_tl           = (spec_tl_r & ptag_nonidem_i);

  logic [assoc_p-1:0] bank_sel_one_hot_tl;
  bsg_decode
   #(.num_out_p(assoc_p))
   offset_decode
    (.i(vaddr_bank_tl)
     ,.o(bank_sel_one_hot_tl)
     );

  /////////////////////////////////////////////////////////////////////////////
  // TV Stage
  /////////////////////////////////////////////////////////////////////////////
  localparam snoop_offset_width_lp = `BSG_SAFE_CLOG2(fill_width_p/word_width_gp);
  logic [paddr_width_p-1:0]              paddr_tv_r;
  logic [assoc_p-1:0]                    bank_sel_one_hot_tv_r;
  logic [assoc_p-1:0]                    way_v_tv_r, hit_v_tv_r;
  logic                                  fetch_op_tv_r, fencei_op_tv_r, uncached_op_tv_r;
  logic                                  fill_tv_r;
  logic [assoc_p-1:0][bank_width_lp-1:0] ld_data_tv_r;

  // fence.i does not check tags
  assign safe_tv_we = v_tl & (~v_tv_r || yumi_i);
  assign tv_we = safe_tv_we | poison_tv_i;
  assign v_tv_n = v_tl & (ptag_v_i | fencei_op_tl_r) & ~poison_tv_i;
  bsg_dff_reset_en
   #(.width_p(1))
   v_tv_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tv_we)
     ,.data_i(v_tv_n)
     ,.data_o(v_tv_r)
     );
  assign tv_we_o = tv_we;

  // Mask valid signal when we are recovering from a cache miss
  wire v_tv = is_ready & v_tv_r;

  logic [assoc_p-1:0] way_v_tv_n, hit_v_tv_n;
  wire [assoc_p-1:0] tag_mem_pseudo_hit = 1'b1 << tag_mem_pkt_cast_i.way_id;
  bsg_mux
   #(.width_p(2*assoc_p), .els_p(2))
   hit_mux
    (.data_i({{2{tag_mem_pseudo_hit}}, {way_v_tl, hit_v_tl}})
     ,.sel_i(cache_req_critical_tag_i)
     ,.data_o({way_v_tv_n, hit_v_tv_n})
     );

  bsg_dff_reset_en
   #(.width_p(2*assoc_p))
   hit_tv_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tv_we | cache_req_critical_tag_i)
     ,.data_i({way_v_tv_n, hit_v_tv_n})
     ,.data_o({way_v_tv_r, hit_v_tv_r})
     );

  wire fill_tv_n = cache_req_complete_i || fill_tl || (fencei_op_tl_r & coherent_p);
  bsg_dff_reset_en
   #(.width_p(1))
   fill_tv_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tv_we | cache_req_complete_i)
     ,.data_i(fill_tv_n)
     ,.data_o(fill_tv_r)
     );

  // Snoop logic
  logic [word_width_gp-1:0] snoop_word;
  wire [snoop_offset_width_lp-1:0] snoop_word_offset = paddr_tv_r[2+:snoop_offset_width_lp];
  bsg_mux
   #(.width_p(word_width_gp), .els_p(fill_width_p/word_width_gp))
   snoop_mux
    (.data_i(data_mem_pkt_cast_i.data)
     ,.sel_i(snoop_word_offset)
     ,.data_o(snoop_word)
     );
  wire [block_width_p-1:0] snoop_data_lo = {block_width_p/word_width_gp{snoop_word}};

  logic [block_width_p-1:0] ld_data_tv_n;
  bsg_mux
   #(.width_p(block_width_p), .els_p(2))
   ld_data_mux
    (.data_i({snoop_data_lo, data_mem_data_lo})
     ,.sel_i(cache_req_critical_data_i)
     ,.data_o(ld_data_tv_n)
     );

  bsg_dff_en
   #(.width_p(block_width_p))
   ld_data_tv_reg
    (.clk_i(clk_i)
     ,.en_i(tv_we | cache_req_critical_data_i)
     ,.data_i(ld_data_tv_n)
     ,.data_o(ld_data_tv_r)
     );

  bsg_dff_en
   #(.width_p(paddr_width_p+assoc_p+3))
   tv_stage_reg
    (.clk_i(clk_i)
     ,.en_i(tv_we)
     ,.data_i({paddr_tl
               ,bank_sel_one_hot_tl
               ,fetch_op_tl_r, fencei_op_tl_r, fetch_uncached_tl
               })
     ,.data_o({paddr_tv_r
               ,bank_sel_one_hot_tv_r
               ,fetch_op_tv_r, fencei_op_tv_r, uncached_op_tv_r
               })
     );

  logic [lg_assoc_lp-1:0] invalid_way_tv;
  logic invalid_exist_tv;
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

  logic [lg_assoc_lp-1:0] hit_index_tv;
  logic hit_v_tv;
  bsg_encode_one_hot
   #(.width_p(assoc_p), .lo_to_hi_p(1))
   hit_index_encoder
    (.i(hit_v_tv_r)
     ,.addr_o(hit_index_tv)
     ,.v_o(hit_v_tv)
     );

  // One-hot data muxing
  logic [assoc_p-1:0] ld_data_way_select;
  bsg_adder_one_hot
   #(.width_p(assoc_p))
   select_adder
    (.a_i(hit_v_tv_r)
     ,.b_i(bank_sel_one_hot_tv_r)
     ,.o(ld_data_way_select)
     );

  logic [bank_width_lp-1:0] ld_data_way_picked;
  bsg_mux_one_hot
   #(.width_p(bank_width_lp), .els_p(assoc_p))
   data_set_select_mux
    (.data_i(ld_data_tv_r)
     ,.sel_one_hot_i(ld_data_way_select)
     ,.data_o(ld_data_way_picked)
     );

  logic [instr_width_gp-1:0] final_data;
  bsg_mux
   #(.width_p(instr_width_gp), .els_p(num_words_per_bank_lp))
   word_select_mux
    (.data_i(ld_data_way_picked)
     ,.sel_i(paddr_tv_r[2+:`BSG_SAFE_CLOG2(num_words_per_bank_lp)])
     ,.data_o(final_data)
     );

  assign data_o = final_data;
  assign fence_v_o = v_tv &  fencei_op_tv_r & fill_tv_r;
  assign data_v_o  = v_tv & ~fencei_op_tv_r &  hit_v_tv;
  assign spec_v_o  = v_tv & ~fencei_op_tv_r & ~hit_v_tv & fill_tv_r;

  ///////////////////////////
  // Stat Mem Storage
  ///////////////////////////
  `bp_cast_i(bp_icache_stat_mem_pkt_s, stat_mem_pkt);
  logic                       stat_mem_v_li;
  logic                       stat_mem_w_li;
  logic [sindex_width_lp-1:0] stat_mem_addr_li;
  bp_icache_stat_info_s       stat_mem_data_li;
  bp_icache_stat_info_s       stat_mem_mask_li;
  bp_icache_stat_info_s       stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
   #(.width_p(assoc_p-1), .els_p(sets_p), .latch_last_read_p(1))
   stat_mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(stat_mem_data_li.lru)
     ,.addr_i(stat_mem_addr_li)
     ,.v_i(stat_mem_v_li)
     ,.w_mask_i(stat_mem_mask_li.lru)
     ,.w_i(stat_mem_w_li)
     ,.data_o(stat_mem_data_lo.lru)
     );
  assign stat_mem_data_lo.dirty = '0;

  bsg_lru_pseudo_tree_encode
   #(.ways_p(assoc_p))
   lru_encoder
    (.lru_i(stat_mem_data_lo.lru)
     ,.way_id_o(lru_encode)
     );

  /////////////////////////////////////////////////////////////////////////////
  // Slow Path
  /////////////////////////////////////////////////////////////////////////////
  `bp_cast_o(bp_icache_req_s, cache_req);
  `bp_cast_o(bp_icache_req_metadata_s, cache_req_metadata);

  localparam bp_cache_req_size_e block_req_size = bp_cache_req_size_e'(`BSG_SAFE_CLOG2(block_width_p/8));
  localparam bp_cache_req_size_e uncached_req_size = e_size_4B;

  wire cached_req   = fetch_op_tv_r & ~uncached_op_tv_r & ~fill_tv_r & ~hit_v_tv;
  wire uncached_req = fetch_op_tv_r &  uncached_op_tv_r & ~fill_tv_r & ~hit_v_tv;
  wire fencei_req   = fencei_op_tv_r & ~fill_tv_r;

  assign cache_req_v_o = v_tv & ~fill_tv_r & |{uncached_req, cached_req, fencei_req};
  assign cache_req_cast_o =
   '{addr     : paddr_tv_r
     ,size    : cached_req ? block_req_size : uncached_req_size
     ,msg_type: cached_req ? e_miss_load : uncached_req ? e_uc_load : e_cache_clear
     ,subop   : e_req_amoswap
     ,data    : '0
     ,hit     : hit_v_tv
     };

  // The cache pipeline is designed to always send metadata a cycle after the request
  bsg_dff_reset
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_v_o)
     ,.data_o(cache_req_metadata_v_o)
     );

  logic metadata_hit_r;
  logic [lg_assoc_lp-1:0] metadata_hit_index_r;
  bsg_dff
   #(.width_p(1+lg_assoc_lp))
   hit_reg
    (.clk_i(clk_i)
     ,.data_i({hit_v_tv, hit_index_tv})
     ,.data_o({metadata_hit_r, metadata_hit_index_r})
     );

  wire [assoc_p-1:0] hit_or_repl_way = metadata_hit_r ? metadata_hit_index_r : lru_way_li;
  assign cache_req_metadata_cast_o.hit_or_repl_way = hit_or_repl_way;
  assign cache_req_metadata_cast_o.dirty = '0;

  /////////////////////////////////////////////////////////////////////////////
  // State machine
  //   e_busy   : Cache engine needs to interact with the memories quickly
  //   e_ready  : Cache is ready to accept requests
  //   e_miss   : Cache is waiting for a cache request to be serviced
  //   e_recover: Reread the SRAMs to recover the updated TL state
  /////////////////////////////////////////////////////////////////////////////
  always_comb
    case (state_r)
      e_busy   : state_n = ~cache_req_busy_i ? e_ready : e_busy;
      e_ready  : state_n = (cache_req_ready_and_i & cache_req_v_o) ? e_miss : cache_req_busy_i ? e_busy : e_ready;
      e_miss   : state_n = cache_req_complete_i ? e_recover: e_miss;
      // e_recover:
      default  : state_n = e_ready;
    endcase

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_busy;
    else
      state_r <= state_n;

  /////////////////////////////////////////////////////////////////////////////
  // SRAM Control
  /////////////////////////////////////////////////////////////////////////////

  ///////////////////////////
  // Tag Mem Control
  ///////////////////////////
  logic tag_mem_last_read_r;
  bsg_dff_reset_set_clear
   #(.width_p(1), .clear_over_set_p(1))
   tag_mem_last_read_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(tag_mem_v_li)
     ,.clear_i(tag_mem_w_li)
     ,.data_o(tag_mem_last_read_r)
     );

  // Tag mem is bypassed if the index is the same on consecutive reads
  wire tag_mem_bypass = (vaddr_index == vaddr_index_tl) & tag_mem_last_read_r;
  wire tag_mem_fast_read = is_recover || safe_tl_we & ~tag_mem_bypass;
  wire tag_mem_fast_write = 1'b0;
  wire tag_mem_slow_read = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_read) ;
  wire tag_mem_slow_write = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode != e_cache_tag_mem_read);
  assign tag_mem_v_li = tag_mem_fast_read | tag_mem_fast_write | tag_mem_slow_read | tag_mem_slow_write;
  assign tag_mem_w_li = tag_mem_fast_write | tag_mem_slow_write;
  assign tag_mem_addr_li = tag_mem_fast_read
    ? is_recover ? vaddr_index_tl : vaddr_index
    : tag_mem_pkt_cast_i.index;
  assign tag_mem_pkt_yumi_o = tag_mem_pkt_v_i & ~tag_mem_fast_read;

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
            tag_mem_data_li[i]   = '{state: tag_mem_pkt_cast_i.state, tag: tag_mem_pkt_cast_i.tag};
            tag_mem_w_mask_li[i] = '{state: {$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}
                                     ,tag : {ctag_width_p{tag_mem_way_one_hot[i]}}
                                     };
          end
        e_cache_tag_mem_set_state:
          begin
            tag_mem_data_li[i]   = '{state: tag_mem_pkt_cast_i.state, tag: '0};
            tag_mem_w_mask_li[i] = '{state: {$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}, tag: '0};
          end
        default: // e_cache_tag_mem_set_clear
          begin
            tag_mem_data_li[i]   = '{state: bp_coh_states_e'('0), tag: '0};
            tag_mem_w_mask_li[i] = '{state: bp_coh_states_e'('1), tag: '1};
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
  logic [assoc_p-1:0] vaddr_bank_dec;
  bsg_decode
   #(.num_out_p(assoc_p))
   bypass_bank_decode
    (.i(vaddr_bank)
     ,.o(vaddr_bank_dec)
     );

  // During a data mem bypass, only the necessary bank of data memory is read
  logic [assoc_p-1:0] data_mem_bypass_select;
  bsg_adder_one_hot
   #(.width_p(assoc_p))
   data_mem_bank_select_adder
    (.a_i(hit_v_tl)
     ,.b_i(vaddr_bank_dec)
     ,.o(data_mem_bypass_select)
     );

  wire [`BSG_SAFE_CLOG2(fill_width_p)-1:0] write_data_rot_li = data_mem_pkt_cast_i.way_id*bank_width_lp;
  // Expand the bank write mask to bank width
  logic [fill_width_p-1:0] data_mem_pkt_fill_data_li;
  bsg_rotate_left
   #(.width_p(fill_width_p))
   write_data_rotate
    (.data_i(data_mem_pkt_cast_i.data)
     ,.rot_i(write_data_rot_li)
     ,.o(data_mem_pkt_fill_data_li)
     );
  wire [assoc_p-1:0][bank_width_lp-1:0] data_mem_pkt_data_li = {block_size_in_fill_lp{data_mem_pkt_fill_data_li}};

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

  wire data_mem_bypass = (vaddr_vtag == vaddr_vtag_tl) & (vaddr_index == vaddr_index_tl) & v_tl;

  logic [assoc_p-1:0] data_mem_fast_read, data_mem_fast_write, data_mem_slow_read, data_mem_slow_write;
  for (genvar i = 0; i < assoc_p; i++)
    begin : data_mem_lines
      assign data_mem_slow_read[i] = data_mem_pkt_yumi_o & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_read);
      assign data_mem_slow_write[i] = data_mem_pkt_yumi_o & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_write) & data_mem_write_bank_mask[i];

      assign data_mem_fast_read[i] = is_recover || safe_tl_we & fetch_op & (~data_mem_bypass | data_mem_bypass_select[i]);

      assign data_mem_v_li[i] = data_mem_fast_read[i] | data_mem_slow_read[i] | data_mem_slow_write[i];
      assign data_mem_w_li[i] = data_mem_slow_write[i];
      wire [bindex_width_lp-1:0] data_mem_pkt_offset = (bindex_width_lp'(i) - data_mem_pkt_cast_i.way_id);
      assign data_mem_addr_li[i] = data_mem_fast_read[i]
        ? is_recover ? {vaddr_index_tl, {(assoc_p>1){vaddr_bank_tl}}} : {vaddr_index, {(assoc_p > 1){vaddr_bank}}}
        : {data_mem_pkt_cast_i.index, {(assoc_p > 1){data_mem_pkt_offset}}};
      assign data_mem_data_li[i] = data_mem_pkt_data_li[i];
    end
  assign data_mem_pkt_yumi_o = (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached)
    ? data_mem_pkt_v_i
    : data_mem_pkt_v_i & ~|data_mem_fast_read;

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
  wire stat_mem_fast_read = (v_tv & cache_req_v_o & ~uncached_op_tv_r);
  wire stat_mem_fast_write = (v_tv & data_v_o & ~uncached_op_tv_r);
  wire stat_mem_slow_write = stat_mem_pkt_v_i & (stat_mem_pkt_cast_i.opcode != e_cache_stat_mem_read);
  assign stat_mem_pkt_yumi_o = stat_mem_pkt_v_i & ~stat_mem_fast_write & ~stat_mem_fast_read;
  assign stat_mem_v_li = stat_mem_fast_read | stat_mem_fast_write | stat_mem_pkt_yumi_o;
  assign stat_mem_w_li = stat_mem_fast_write | (stat_mem_pkt_yumi_o & stat_mem_slow_write);
  assign stat_mem_addr_li = (stat_mem_fast_write | stat_mem_fast_read)
    ? paddr_tv_r[block_offset_width_lp+:sindex_width_lp]
    : stat_mem_pkt_cast_i.index;

  logic [`BSG_SAFE_MINUS(assoc_p, 2):0] lru_decode_data_lo, lru_decode_mask_lo;
  bsg_lru_pseudo_tree_decode
   #(.ways_p(assoc_p))
   lru_decode
    (.way_id_i(hit_index_tv)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
     );

  assign stat_mem_data_li.lru = stat_mem_fast_write ? lru_decode_data_lo : '0;
  assign stat_mem_mask_li.lru = stat_mem_fast_write ? lru_decode_mask_lo : '1;

  assign stat_mem_o = stat_mem_data_lo;

  if (`BSG_SAFE_CLOG2(block_width_p*sets_p/8) != page_offset_width_gp) begin
    $error("Total cache size must be equal to 4kB * associativity");
  end

endmodule

