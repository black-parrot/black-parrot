/**
 *
 * Name:
 *   bp_fe_icache.sv
 *
 * Description:
 *   L1 Instruction Cache. Features:
 *   - Virtually-indexed, physically-tagged
 *   - 2-8 way set-associative
 *   - 128-512 bit block size (minimum 64-bit data mem bank size)
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
 * Notes:
 *    Supports multi-cycle fill/eviction with the UCE in unicore configuration
 *    Uses fill_index in data_mem_pkt to generate a write_mask for the data banks
 *      bank_width = block_width / assoc >= dword_width
 *      fill_width = N*bank_width <= block_width
 */

module bp_fe_icache
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache_fill_width_p, icache)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   // Unused except for tracers
   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   // Cycle 0: "Decode"
   // New I$ packet comes in for a fetch, fence or fill request.
   , input [icache_pkt_width_lp-1:0]                  icache_pkt_i
   , input                                            v_i
   , output                                           ready_o

   // Cycle 1: "Tag Lookup"
   // TLB and PMA information comes in this cycle
   , input [ptag_width_p-1:0]                         ptag_i
   , input                                            ptag_v_i
   , input                                            uncached_i
   , input                                            poison_tl_i

   // Cycle 2: "Tag Verify"
   // Data (or miss result) comes out of the cache
   , output [instr_width_p-1:0]                       data_o
   , output                                           data_v_o
   , input                                            poison_tv_i

   // Cache Engine Interface
   // This is considered the "slow path", handling uncached requests
   //   and fill DMAs. It also handles coherence transactions for
   //   configurations which support that behavior
   , output logic [icache_req_width_lp-1:0]           cache_req_o
   , output logic                                     cache_req_v_o
   , input                                            cache_req_yumi_i
   , input                                            cache_req_busy_i
   , output logic [icache_req_metadata_width_lp-1:0]  cache_req_metadata_o
   , output logic                                     cache_req_metadata_v_o
   , input                                            cache_req_critical_i
   , input                                            cache_req_complete_i
   , input                                            cache_req_credits_full_i
   , input                                            cache_req_credits_empty_i

   , input                                            data_mem_pkt_v_i
   , input [icache_data_mem_pkt_width_lp-1:0]         data_mem_pkt_i
   , output logic                                     data_mem_pkt_yumi_o
   , output logic [icache_block_width_p-1:0]          data_mem_o

   , input                                            tag_mem_pkt_v_i
   , input [icache_tag_mem_pkt_width_lp-1:0]          tag_mem_pkt_i
   , output logic                                     tag_mem_pkt_yumi_o
   , output logic [icache_tag_info_width_lp-1:0]      tag_mem_o

   , input                                            stat_mem_pkt_v_i
   , input [icache_stat_mem_pkt_width_lp-1:0]         stat_mem_pkt_i
   , output logic                                     stat_mem_pkt_yumi_o
   , output logic [icache_stat_info_width_lp-1:0]     stat_mem_o
   );

  `declare_bp_cache_engine_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache_fill_width_p, icache);
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  // Various localparameters
  localparam lg_icache_assoc_lp     =`BSG_SAFE_CLOG2(icache_assoc_p);
  localparam bank_width_lp          = icache_block_width_p / icache_assoc_p;
  localparam num_words_per_bank_lp  = bank_width_lp / word_width_p;
  localparam data_mem_mask_width_lp = (bank_width_lp >> 3);
  localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(bank_width_lp >> 3);
  localparam bindex_width_lp        = `BSG_SAFE_CLOG2(icache_assoc_p);
  localparam sindex_width_lp        = `BSG_SAFE_CLOG2(icache_sets_p);
  localparam block_offset_width_lp  = (icache_assoc_p > 1)
    ? (bindex_width_lp+byte_offset_width_lp)
    : byte_offset_width_lp;
  localparam block_size_in_fill_lp  = icache_block_width_p / icache_fill_width_p;
  localparam fill_size_in_bank_lp   = icache_fill_width_p / bank_width_lp;

  // State machine declaration
  enum logic [1:0] {e_ready, e_miss, e_recover} state_n, state_r;
  wire is_ready   = (state_r == e_ready);
  wire is_miss    = (state_r == e_miss);

  // Feedback signals between stages
  logic tl_we, tv_we;
  logic v_tl_r, v_tv_r;

  // Uncached storage
  logic [paddr_width_p-1:0] uncached_paddr_r;
  logic [dword_width_p-1:0] uncached_data_r;

  /////////////////////////////////////////////////////////////////////////////
  // Decode stage
  /////////////////////////////////////////////////////////////////////////////
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  `bp_cast_i(bp_fe_icache_pkt_s, icache_pkt);

  wire is_fetch = (icache_pkt_cast_i.op == e_icache_fetch);
  wire is_fencei = (icache_pkt_cast_i.op == e_icache_fencei);

  wire [vaddr_width_p-1:0]   vaddr       = icache_pkt_cast_i.vaddr;
  wire [vtag_width_p-1:0]    vaddr_vtag  = vaddr[block_offset_width_lp+sindex_width_lp+:vtag_width_p];
  wire [sindex_width_lp-1:0] vaddr_index = vaddr[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0] vaddr_bank  = vaddr[byte_offset_width_lp+:bindex_width_lp];

  ///////////////////////////
  // Tag Mem Storage
  ///////////////////////////
  `bp_cast_i(bp_icache_tag_mem_pkt_s, tag_mem_pkt);
  logic                                     tag_mem_v_li;
  logic                                     tag_mem_w_li;
  logic [sindex_width_lp-1:0]               tag_mem_addr_li;
  bp_icache_tag_info_s [icache_assoc_p-1:0] tag_mem_w_mask_li;
  bp_icache_tag_info_s [icache_assoc_p-1:0] tag_mem_data_li;
  bp_icache_tag_info_s [icache_assoc_p-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
   #(.width_p(icache_assoc_p*($bits(bp_icache_tag_info_s)))
     ,.els_p(icache_sets_p)
     ,.latch_last_read_p(1)
     )
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
  localparam data_mem_addr_width_lp = (icache_assoc_p > 1) ? (sindex_width_lp+bindex_width_lp) : sindex_width_lp;
  logic [icache_assoc_p-1:0]                             data_mem_v_li;
  logic [icache_assoc_p-1:0]                             data_mem_w_li;
  logic [icache_assoc_p-1:0][data_mem_addr_width_lp-1:0] data_mem_addr_li;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]          data_mem_data_li;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]          data_mem_data_lo;

  for (genvar bank = 0; bank < icache_assoc_p; bank++)
    begin: data_mems
      bsg_mem_1rw_sync
       #(.width_p(bank_width_lp)
         ,.els_p(icache_sets_p*icache_assoc_p)
         ,.latch_last_read_p(1)
         )
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
  // TL stage
  /////////////////////////////////////////////////////////////////////////////
  logic [vaddr_width_p-1:0] vaddr_tl_r;
  logic fetch_op_tl_r, fencei_op_tl_r;

  // Valid when we accept new data, clear when we advance to tv
  assign tl_we = ready_o & v_i & ~cache_req_yumi_i;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_tl_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(tl_we)
     // We always advance in the non-stalling I$
     ,.clear_i(1'b1)
     ,.data_o(v_tl_r)
     );

  // Save stage information
  bsg_dff_reset_en
   #(.width_p(vaddr_width_p+2))
   tl_stage_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(tl_we)
     ,.data_i({vaddr, is_fetch, is_fencei})
     ,.data_o({vaddr_tl_r, fetch_op_tl_r, fencei_op_tl_r})
     );

  wire [paddr_width_p-1:0]         paddr_tl = {ptag_i, vaddr_tl_r[0+:bp_page_offset_width_gp]};
  wire [vtag_width_p-1:0]     vaddr_vtag_tl = vaddr_tl_r[block_offset_width_lp+sindex_width_lp+:vtag_width_p];
  wire [sindex_width_lp-1:0] vaddr_index_tl = vaddr_tl_r[block_offset_width_lp+:sindex_width_lp];
  wire [bindex_width_lp-1:0]  vaddr_bank_tl = vaddr_tl_r[byte_offset_width_lp+:bindex_width_lp];

  logic [icache_assoc_p-1:0] way_v_tl, hit_v_tl;
  for (genvar i = 0; i < icache_assoc_p; i++) begin: tag_comp_tl
    assign way_v_tl[i] = (tag_mem_data_lo[i].state != e_COH_I);
    assign hit_v_tl[i] = (tag_mem_data_lo[i].tag == ptag_i) && way_v_tl[i];
  end
  wire cached_hit_tl     = |hit_v_tl;
  wire uncached_hit_tl   = (paddr_tl[paddr_width_p-1:2] == uncached_paddr_r[paddr_width_p-1:2]);
  wire fetch_uncached_tl = (fetch_op_tl_r &  uncached_i);
  wire fetch_cached_tl   = (fetch_op_tl_r & ~uncached_i);

  logic [icache_assoc_p-1:0] bank_sel_one_hot_tl;
  bsg_decode
   #(.num_out_p(icache_assoc_p))
   offset_decode
    (.i(vaddr_bank_tl)
     ,.o(bank_sel_one_hot_tl)
     );

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
   #(.width_p(icache_assoc_p-1)
     ,.els_p(icache_sets_p)
     ,.latch_last_read_p(1)
     )
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

  /////////////////////////////////////////////////////////////////////////////
  // TV stage
  /////////////////////////////////////////////////////////////////////////////
  logic [paddr_width_p-1:0]                     paddr_tv_r;
  logic [icache_assoc_p-1:0]                    bank_sel_one_hot_tv_r;
  logic [icache_assoc_p-1:0]                    way_v_tv_r, hit_v_tv_r;
  logic                                         cached_hit_tv_r, uncached_hit_tv_r;
  logic                                         fencei_op_tv_r, uncached_op_tv_r, cached_op_tv_r;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0] ld_data_tv_r;

  // fence.i does not check tags
  assign tv_we = v_tl_r & (ptag_v_i | fencei_op_tl_r) & ~poison_tl_i & ~cache_req_yumi_i;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   v_tv_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(tv_we)
     // We always advance in the non-stalling I$
     ,.clear_i(1'b1)
     ,.data_o(v_tv_r)
     );

  logic [icache_block_width_p-1:0] ld_data_tv_n;
  assign ld_data_tv_n = data_mem_data_lo;
  bsg_dff_en
   #(.width_p(icache_block_width_p))
   ld_data_tv_reg
    (.clk_i(clk_i)
     ,.en_i(tv_we)
     ,.data_i(ld_data_tv_n)
     ,.data_o(ld_data_tv_r)
     );

  bsg_dff_en
   #(.width_p(paddr_width_p+3*icache_assoc_p+5))
   tv_stage_reg
    (.clk_i(clk_i)
     ,.en_i(tv_we)
     ,.data_i({paddr_tl
               ,bank_sel_one_hot_tl, way_v_tl, hit_v_tl, cached_hit_tl, uncached_hit_tl
               ,fencei_op_tl_r, fetch_uncached_tl, fetch_cached_tl
               })
     ,.data_o({paddr_tv_r
               ,bank_sel_one_hot_tv_r, way_v_tv_r, hit_v_tv_r, cached_hit_tv_r, uncached_hit_tv_r
               ,fencei_op_tv_r, uncached_op_tv_r, cached_op_tv_r
               })
     );

  // One-hot data muxing
  logic [icache_assoc_p-1:0] ld_data_way_select;
  bsg_adder_one_hot
   #(.width_p(icache_assoc_p))
   select_adder
    (.a_i(hit_v_tv_r)
     ,.b_i(bank_sel_one_hot_tv_r)
     ,.o(ld_data_way_select)
     );

  logic [bank_width_lp-1:0] ld_data_way_picked;
  bsg_mux_one_hot
   #(.width_p(bank_width_lp)
     ,.els_p(icache_assoc_p)
     )
   data_set_select_mux
    (.data_i(ld_data_tv_r)
     ,.sel_one_hot_i(ld_data_way_select)
     ,.data_o(ld_data_way_picked)
     );

  logic [instr_width_p-1:0] final_data;
  bsg_mux
   #(.width_p(instr_width_p)
     ,.els_p(num_words_per_bank_lp)
     )
   dword_select_mux
    (.data_i(ld_data_way_picked)
     ,.sel_i(paddr_tv_r[2+:`BSG_SAFE_CLOG2(num_words_per_bank_lp)])
     ,.data_o(final_data)
     );

  assign data_o = uncached_op_tv_r ? uncached_data_r : final_data;
  assign data_v_o = v_tv_r & ((uncached_op_tv_r & uncached_hit_tv_r)
                              | (cached_op_tv_r & cached_hit_tv_r)
                              );

  /////////////////////////////////////////////////////////////////////////////
  // Slow Path
  /////////////////////////////////////////////////////////////////////////////
  `bp_cast_o(bp_icache_req_s, cache_req);
  `bp_cast_o(bp_icache_req_metadata_s, cache_req_metadata);

  localparam bp_cache_req_size_e block_req_size = bp_cache_req_size_e'(`BSG_SAFE_CLOG2(icache_block_width_p/8));
  localparam bp_cache_req_size_e uncached_req_size = e_size_4B;

  wire cached_req   = v_tv_r & cached_op_tv_r & ~cached_hit_tv_r;
  wire uncached_req = v_tv_r & uncached_op_tv_r & ~uncached_hit_tv_r;
  wire fencei_req   = v_tv_r & fencei_op_tv_r & !l1_coherent_p;

  assign cache_req_v_o = |{uncached_req, cached_req, fencei_req} & ~poison_tv_i;
  assign cache_req_cast_o =
   '{addr     : paddr_tv_r
     ,size    : cached_req ? block_req_size : uncached_req_size
     ,msg_type: cached_req ? e_miss_load : uncached_req ? e_uc_load : e_cache_clear
     ,data    : '0
     };

  // The cache pipeline is designed to always send metadata a cycle after the request
  bsg_dff_reset
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_yumi_i)
     ,.data_o(cache_req_metadata_v_o)
     );

  logic [lg_icache_assoc_lp-1:0] lru_encode;
  bsg_lru_pseudo_tree_encode
   #(.ways_p(icache_assoc_p))
   lru_encoder
    (.lru_i(stat_mem_data_lo.lru)
     ,.way_id_o(lru_encode)
     );

  logic [lg_icache_assoc_lp-1:0] way_invalid_index;
  logic invalid_exist;
  bsg_priority_encode
   #(.width_p(icache_assoc_p), .lo_to_hi_p(1))
   pe_invalid
    (.i(~way_v_tv_r)
     ,.v_o(invalid_exist)
     ,.addr_o(way_invalid_index)
     );

  // invalid way takes priority over LRU way
  assign cache_req_metadata_cast_o.repl_way = invalid_exist ? way_invalid_index : lru_encode;
  assign cache_req_metadata_cast_o.dirty = '0;

  /////////////////////////////////////////////////////////////////////////////
  // State machine
  //   e_ready  : Cache is ready to accept requests
  //   e_miss   : Cache is waiting for a cache request to be serviced
  /////////////////////////////////////////////////////////////////////////////
  always_comb
    case (state_r)
      e_ready  : state_n = cache_req_yumi_i ? e_miss : e_ready;
      e_miss   : state_n = cache_req_complete_i ? e_ready : e_miss;
      default: state_n = e_ready;
    endcase

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  assign ready_o = is_ready & ~cache_req_busy_i;

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
     ,.set_i(tl_we)
     ,.clear_i(tag_mem_w_li)
     ,.data_o(tag_mem_last_read_r)
     );

  // Tag mem is bypassed if the index is the same on consecutive reads
  wire tag_mem_bypass = (vaddr_index == vaddr_index_tl) & tag_mem_last_read_r;
  wire tag_mem_fast_read = (tl_we & ~tag_mem_bypass);
  assign tag_mem_v_li = tag_mem_fast_read | tag_mem_pkt_yumi_o;
  assign tag_mem_w_li = tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode != e_cache_tag_mem_read);
  assign tag_mem_addr_li = tag_mem_fast_read
    ? vaddr_index
    : tag_mem_pkt_cast_i.index;
  assign tag_mem_pkt_yumi_o = tag_mem_pkt_v_i & ~tag_mem_fast_read;

  logic [icache_assoc_p-1:0] tag_mem_way_one_hot;
  bsg_decode
   #(.num_out_p(icache_assoc_p))
   tag_mem_way_decode
    (.i(tag_mem_pkt_cast_i.way_id)
     ,.o(tag_mem_way_one_hot)
     );

  always_comb
    for (integer i = 0; i < icache_assoc_p; i++)
      case (tag_mem_pkt_cast_i.opcode)
        e_cache_tag_mem_set_tag:
          begin
            tag_mem_data_li[i]   = '{state: tag_mem_pkt_cast_i.state, tag: tag_mem_pkt_cast_i.tag};
            tag_mem_w_mask_li[i] = '{state: {$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}
                                     ,tag : {ptag_width_p{tag_mem_way_one_hot[i]}}
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

  logic [lg_icache_assoc_lp-1:0] tag_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_icache_assoc_lp))
   tag_mem_pkt_way_reg
    (.clk_i(clk_i)
     ,.data_i(tag_mem_pkt_cast_i.way_id)
     ,.data_o(tag_mem_pkt_way_r)
     );

  assign tag_mem_o = tag_mem_data_lo[tag_mem_pkt_way_r];

  ///////////////////////////
  // Data Mem Control
  ///////////////////////////
  logic data_mem_last_read_r;
  bsg_dff_reset
   #(.width_p(1))
   data_mem_last_read_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(tl_we)
     ,.data_o(data_mem_last_read_r)
     );

  logic [icache_assoc_p-1:0] vaddr_bank_dec;
  bsg_decode
   #(.num_out_p(icache_assoc_p))
   bypass_bank_decode
    (.i(vaddr_bank)
     ,.o(vaddr_bank_dec)
     );

  wire data_mem_bypass = (vaddr_vtag == vaddr_vtag_tl) & (vaddr_index == vaddr_index_tl) & data_mem_last_read_r;
  // During a data mem bypass, only the necessary bank of data memory is read
  logic [icache_assoc_p-1:0] data_mem_bypass_select;
  bsg_adder_one_hot
   #(.width_p(icache_assoc_p))
   data_mem_bank_select_adder
    (.a_i(hit_v_tl)
     ,.b_i(vaddr_bank_dec)
     ,.o(data_mem_bypass_select)
     );

  logic [icache_assoc_p-1:0]                                  data_mem_write_bank_mask;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]               data_mem_pkt_data_expanded;
  logic [block_size_in_fill_lp-1:0][fill_size_in_bank_lp-1:0] data_mem_pkt_fill_mask_expanded;

  wire [`BSG_SAFE_CLOG2(icache_block_width_p)-1:0] write_data_rot_li = data_mem_pkt_cast_i.way_id*bank_width_lp;
  // Expand the bank write mask to bank width
  assign data_mem_pkt_data_expanded = {block_size_in_fill_lp{data_mem_pkt_cast_i.data}};
  bsg_rotate_left
   #(.width_p(icache_block_width_p))
   write_data_rotate
    (.data_i(data_mem_pkt_data_expanded)
     ,.rot_i(write_data_rot_li)
     ,.o(data_mem_data_li)
     );

  // use fill_index to generate bank write mask
  for (genvar i = 0; i < block_size_in_fill_lp; i++) begin
    assign data_mem_pkt_fill_mask_expanded[i] = {fill_size_in_bank_lp{data_mem_pkt_cast_i.fill_index[i]}};
  end

  wire [`BSG_SAFE_CLOG2(icache_assoc_p)-1:0] write_mask_rot_li = data_mem_pkt_cast_i.way_id;
  bsg_rotate_left
   #(.width_p(icache_assoc_p))
   write_mask_rotate
    (.data_i(data_mem_pkt_fill_mask_expanded)
     ,.rot_i(write_mask_rot_li)
     ,.o(data_mem_write_bank_mask)
     );

  wire data_mem_slow_uncached = data_mem_pkt_v_i & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached);
  wire data_mem_slow_read     = data_mem_pkt_v_i & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_read);
  logic [icache_assoc_p-1:0] data_mem_fast_read;
  for (genvar i = 0; i < icache_assoc_p; i++)
    begin : data_mem_lines
      wire data_mem_slow_write     = data_mem_pkt_v_i & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_write) & data_mem_write_bank_mask[i];
      assign data_mem_fast_read[i] = tl_we & (~data_mem_bypass | data_mem_bypass_select[i]);

      assign data_mem_v_li[i] = data_mem_fast_read[i] | (data_mem_pkt_yumi_o & (data_mem_slow_read | data_mem_slow_write));
      assign data_mem_w_li[i] = data_mem_pkt_yumi_o & data_mem_slow_write;
      wire [bindex_width_lp-1:0] data_mem_pkt_offset = (bindex_width_lp'(i) - data_mem_pkt_cast_i.way_id);
      assign data_mem_addr_li[i] = data_mem_fast_read[i]
        ? {vaddr_index, {(icache_assoc_p > 1){vaddr_bank}}}
        : {data_mem_pkt_cast_i.index, {(icache_assoc_p > 1){data_mem_pkt_offset}}};
    end
  assign data_mem_pkt_yumi_o = data_mem_pkt_v_i & (~|data_mem_fast_read | data_mem_slow_uncached);

  logic [lg_icache_assoc_lp-1:0] data_mem_pkt_way_r;
  bsg_dff
   #(.width_p(lg_icache_assoc_lp))
   data_mem_pkt_way_reg
    (.clk_i(clk_i)
     ,.data_i(data_mem_pkt_cast_i.way_id)
     ,.data_o(data_mem_pkt_way_r)
     );

  wire [`BSG_SAFE_CLOG2(icache_block_width_p)-1:0] read_data_rot_li = data_mem_pkt_way_r*bank_width_lp;
  bsg_rotate_right
   #(.width_p(icache_block_width_p))
   read_data_rotate
    (.data_i(data_mem_data_lo)
     ,.rot_i(read_data_rot_li)
     ,.o(data_mem_o)
     );

  ///////////////////////////
  // Stat Mem Control
  ///////////////////////////
  wire stat_mem_fast_read = (v_tv_r & ~data_v_o & cached_op_tv_r);
  wire stat_mem_fast_write = (v_tv_r & data_v_o & cached_op_tv_r);
  wire stat_mem_slow_write = stat_mem_pkt_v_i & (stat_mem_pkt_cast_i.opcode != e_cache_stat_mem_read);
  assign stat_mem_pkt_yumi_o = stat_mem_pkt_v_i & ~stat_mem_fast_write & ~stat_mem_fast_read;
  assign stat_mem_v_li = stat_mem_fast_read | stat_mem_fast_write | stat_mem_pkt_yumi_o;
  assign stat_mem_w_li = stat_mem_fast_write | (stat_mem_pkt_yumi_o & stat_mem_slow_write);
  assign stat_mem_addr_li = (stat_mem_fast_write | stat_mem_fast_read)
    ? paddr_tv_r[block_offset_width_lp+:sindex_width_lp]
    : stat_mem_pkt_cast_i.index;

  logic [lg_icache_assoc_lp-1:0] hit_index_tv;
  bsg_encode_one_hot
   #(.width_p(icache_assoc_p), .lo_to_hi_p(1))
   hit_index_encoder
    (.i(hit_v_tv_r)
     ,.addr_o(hit_index_tv)
     ,.v_o()
     );

  logic [`BSG_SAFE_MINUS(icache_assoc_p, 2):0] lru_decode_data_lo, lru_decode_mask_lo;
  bsg_lru_pseudo_tree_decode
   #(.ways_p(icache_assoc_p))
   lru_decode
    (.way_id_i(hit_index_tv)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
     );

  assign stat_mem_data_li.lru = stat_mem_fast_write ? lru_decode_data_lo : '0;
  assign stat_mem_mask_li.lru = stat_mem_fast_write ? lru_decode_mask_lo : '1;

  assign stat_mem_o = {stat_mem_data_lo.lru, icache_assoc_p'(0)};

  ///////////////////////////
  // Uncached data storage
  ///////////////////////////
  // TODO: This goes away with the I$ fill op
  bsg_dff_reset_en
   #(.width_p(paddr_width_p))
   uncached_paddr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(uncached_req)
     ,.data_i(paddr_tv_r)
     ,.data_o(uncached_paddr_r)
     );

  wire uncached_load_set = data_mem_pkt_yumi_o & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached);
  wire [dword_width_p-1:0] uncached_data = data_mem_pkt_cast_i.data[0+:dword_width_p];
  bsg_dff_en
   #(.width_p(dword_width_p))
   uncached_data_reg
    (.clk_i(clk_i)
     ,.en_i(uncached_load_set)
     ,.data_i(uncached_data)
     ,.data_o(uncached_data_r)
     );

  //synopsys translate_off
  if (`BSG_SAFE_CLOG2(icache_block_width_p*icache_sets_p/8) != page_offset_width_p) begin
    $error("Total cache size must be equal to 4kB * associativity");
  end
  //synopsys translate_on

endmodule

