/**
 *
 * Name:
 *   bp_fe_icache.v
 *
 * Description:
 *   To	be updated
 * The icache module implements a virtually-indexed physically-tagged cache. Although the cache
 * design is parameterized, our default icache configuration is a 4-way set associative cache. Our
 * icache has an LCE as part of the cache controller that communicates with the CCE. For replacement
 * policy, we use the pseudo-LRU module implemnted for dcache.
 *
 * Notes:
 *
 *    Both I-cache and D-cache support multi-cycle fill/eviction with the UCE in unicore configuration.
 *    The key to fill the data_mem with fill_width <= block_width is using the fill_index newly added in
 *    data_mem_pkt to generate write mask.
 *    Some key concepts and their relation can be summarized as:
 *      bank_width = block_width / assoc >= dword_width
 *      fill_width = N*bank_width <= block_width
 *    For detailed description and supported fill width parameters, please refer to Cache Serivce Interface Doc
 */


module bp_fe_icache
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache_fill_width_p, icache)

    , localparam lg_icache_assoc_lp=`BSG_SAFE_CLOG2(icache_assoc_p)
    , localparam bank_width_lp = icache_block_width_p / icache_assoc_p
    , localparam num_words_per_bank_lp = bank_width_lp / word_width_p
    , localparam data_mem_mask_width_lp=(bank_width_lp >> 3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp >> 3)
    , localparam bank_offset_width_lp = `BSG_SAFE_CLOG2(icache_assoc_p)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(icache_sets_p)
    , localparam block_offset_width_lp = (bank_offset_width_lp+byte_offset_width_lp)
    , localparam block_size_in_fill_lp = icache_block_width_p / icache_fill_width_p
    , localparam fill_size_in_bank_lp = icache_fill_width_p / bank_width_lp
    , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    , parameter debug_p=0
    )
   (input                                              clk_i
    , input                                            reset_i

    , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

    , input [icache_pkt_width_lp-1:0]                  icache_pkt_i
    , input                                            v_i
    , output logic                                     yumi_o

    , input [ptag_width_p-1:0]                         ptag_i
    , input                                            ptag_v_i
    , input                                            uncached_i

    // Used to keep I$ and pc_gen in sync
    , output logic                                     tl_we_o
    , output logic                                     tv_we_o

    , output [instr_width_p-1:0]                       data_o
    , output [vaddr_width_p-1:0]                       vaddr_o
    , output logic                                     miss_not_data_o
    , output logic                                     data_v_o
    , input                                            data_yumi_i

    // LCE Interface

    , output [icache_req_width_lp-1:0]                 cache_req_o
    , output logic                                     cache_req_v_o
    , input                                            cache_req_ready_i
    , output [icache_req_metadata_width_lp-1:0]        cache_req_metadata_o
    , output logic                                     cache_req_metadata_v_o

    , input                                            cache_req_complete_i
    , input                                            cache_req_critical_i

    // data_mem
    , input                                            data_mem_pkt_v_i
    , input [icache_data_mem_pkt_width_lp-1:0]         data_mem_pkt_i
    , output logic                                     data_mem_pkt_yumi_o
    , output logic [icache_block_width_p-1:0]          data_mem_o

    // tag_mem
    , input                                            tag_mem_pkt_v_i
    , input [icache_tag_mem_pkt_width_lp-1:0]          tag_mem_pkt_i
    , output logic                                     tag_mem_pkt_yumi_o
    , output logic [ptag_width_p-1:0]                  tag_mem_o

    // stat_mem
    , input                                            stat_mem_pkt_v_i
    , input [icache_stat_mem_pkt_width_lp-1:0]         stat_mem_pkt_i
    , output logic                                     stat_mem_pkt_yumi_o
    , output logic [icache_stat_info_width_lp-1:0]     stat_mem_o
 );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, icache_sets_p, icache_assoc_p, dword_width_p, icache_block_width_p, icache_fill_width_p, icache);
  bp_icache_req_s cache_req_cast_lo;
  bp_icache_req_metadata_s cache_req_metadata_cast_lo;
  assign cache_req_o = cache_req_cast_lo;
  assign cache_req_metadata_o = cache_req_metadata_cast_lo;

  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt;
  assign icache_pkt = icache_pkt_i;

  enum logic [1:0] {e_ready, e_miss, e_recover} state_n, state_r;
  wire is_ready   = (state_r == e_ready);
  wire is_miss    = (state_r == e_miss);
  wire is_recover = (state_r == e_recover);

  wire [vtag_width_p-1:0]           vaddr_vtag = icache_pkt.vaddr[block_offset_width_lp+index_width_lp+:vtag_width_p];
  wire [index_width_lp-1:0]        vaddr_index = icache_pkt.vaddr[block_offset_width_lp+:index_width_lp];
  wire [bank_offset_width_lp-1:0] vaddr_offset = icache_pkt.vaddr[byte_offset_width_lp+:bank_offset_width_lp];

  logic tl_we, tv_we;

  // TL stage
  logic v_tl_r;
  logic [vaddr_width_p-1:0] vaddr_tl_r;
  logic fetch_op_tl_r, fencei_op_tl_r, fill_op_tl_r;

  wire is_fetch  = v_i & (icache_pkt.op inside {e_icache_fetch, e_icache_redir});
  wire is_fencei = v_i & (icache_pkt.op == e_icache_fencei);
  wire is_fill   = v_i & (icache_pkt.op == e_icache_fill);
  wire is_redir  = v_i & (icache_pkt.op == e_icache_redir);

  assign tl_we = yumi_o;
  assign tl_we_o = tl_we;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tl_r       <= 1'b0;
    end else begin
      if (tl_we | tv_we) begin
        v_tl_r           <= tl_we;
      end
      if (tl_we) begin
        vaddr_tl_r       <= icache_pkt.vaddr;
        fetch_op_tl_r    <= is_fetch;
        fencei_op_tl_r   <= is_fencei;
        fill_op_tl_r     <= is_fill;
      end
    end
  end

  // tag memory
  logic                                                               tag_mem_v_li;
  logic                                                               tag_mem_w_li;
  logic [index_width_lp-1:0]                                          tag_mem_addr_li;
  logic [icache_assoc_p-1:0][$bits(bp_coh_states_e)+ptag_width_p-1:0] tag_mem_data_li;
  logic [icache_assoc_p-1:0][$bits(bp_coh_states_e)+ptag_width_p-1:0] tag_mem_w_mask_li;
  logic [icache_assoc_p-1:0][$bits(bp_coh_states_e)+ptag_width_p-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(icache_assoc_p*($bits(bp_coh_states_e)+ptag_width_p))
    ,.els_p(icache_sets_p)
    ,.latch_last_read_p(1)
  ) tag_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(tag_mem_data_li)
    ,.addr_i(tag_mem_addr_li)
    ,.v_i(tag_mem_v_li)
    ,.w_mask_i(tag_mem_w_mask_li)
    ,.w_i(tag_mem_w_li)
    ,.data_o(tag_mem_data_lo)
  );

  logic [icache_assoc_p-1:0][$bits(bp_coh_states_e)-1:0] state_tl;
  logic [icache_assoc_p-1:0][ptag_width_p-1:0] tag_tl;

  for (genvar i = 0; i < icache_assoc_p; i++) begin
    assign state_tl[i] = tag_mem_data_lo[i][ptag_width_p+:$bits(bp_coh_states_e)];
    assign tag_tl[i]   = tag_mem_data_lo[i][0+:ptag_width_p];
  end

  // data memory
  logic [icache_assoc_p-1:0]                                           data_mem_v_li;
  logic                                                                data_mem_w_li;
  logic [icache_assoc_p-1:0][index_width_lp+bank_offset_width_lp-1:0]  data_mem_addr_li;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]                        data_mem_data_li;
  logic [icache_assoc_p-1:0][data_mem_mask_width_lp-1:0]               data_mem_w_mask_li;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]                        data_mem_data_lo;

  for (genvar bank = 0; bank < icache_assoc_p; bank++)
  begin: data_mems
    bsg_mem_1rw_sync_mask_write_byte #(
      .data_width_p(bank_width_lp)
      ,.els_p(icache_sets_p*icache_assoc_p)
      ,.latch_last_read_p(1)
    ) data_mem (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(data_mem_data_li[bank])
      ,.addr_i(data_mem_addr_li[bank])
      ,.v_i(data_mem_v_li[bank])
      ,.write_mask_i(data_mem_w_mask_li[bank])
      ,.w_i(data_mem_w_li)
      ,.data_o(data_mem_data_lo[bank])
    );
  end

  logic [ptag_width_p-1:0]         addr_tag_tl;
  logic [bank_offset_width_lp-1:0] addr_bank_offset_tl;
  logic [icache_assoc_p-1:0]       addr_bank_offset_dec_tl;
  logic [icache_assoc_p-1:0]       hit_v_tl;
  logic [paddr_width_p-1:0]        addr_tl;
  logic [icache_assoc_p-1:0]       way_v_tl;
  logic [index_width_lp-1:0]       vaddr_index_tl;
  logic [vtag_width_p-1:0]         vaddr_vtag_tl;
   
  assign addr_tl = {ptag_i, vaddr_tl_r[0+:bp_page_offset_width_gp]};
  assign addr_tag_tl = addr_tl[block_offset_width_lp+index_width_lp+:ptag_width_p];
  assign addr_bank_offset_tl = addr_tl[byte_offset_width_lp+:bank_offset_width_lp];

  assign vaddr_index_tl = vaddr_tl_r[block_offset_width_lp+:index_width_lp];
  assign vaddr_vtag_tl = vaddr_tl_r[block_offset_width_lp+index_width_lp+:vtag_width_p];

  for (genvar i = 0; i < icache_assoc_p; i++) begin: tag_comp_tl
    assign hit_v_tl[i]   = (tag_tl[i] == addr_tag_tl) && (state_tl[i] != e_COH_I);
    assign way_v_tl[i]   = (state_tl[i] != e_COH_I);
  end

  bsg_decode
   #(.num_out_p(icache_assoc_p))
   offset_decode
    (.i(addr_bank_offset_tl)
     ,.o(addr_bank_offset_dec_tl)
     );

  // TV stage
  logic                                                      v_tv_r;
  logic                                                      cached_tv_r;
  logic                                                      uncached_tv_r;
  logic [paddr_width_p-1:0]                                  addr_tv_r;
  logic [vaddr_width_p-1:0]                                  vaddr_tv_r;
  logic [icache_assoc_p-1:0][ptag_width_p-1:0]               tag_tv_r;
  logic [icache_assoc_p-1:0][$bits(bp_coh_states_e)-1:0]     state_tv_r;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]              ld_data_tv_r;
  logic [ptag_width_p-1:0]                                   addr_tag_tv_r;
  logic [icache_assoc_p-1:0]                                 addr_bank_offset_dec_tv_r;
  logic [index_width_lp-1:0]                                 addr_index_tv;
  logic                                                      fencei_op_tv_r;
  logic                                                      fill_op_tv_r;
  logic [icache_assoc_p-1:0]                                 hit_v_tv_r;
  logic                                                      complete_tv_r;

  logic [instr_width_p-1:0] snoop_word;
  localparam snoop_offset_width_p = `BSG_SAFE_CLOG2(icache_fill_width_p/instr_width_p);
  wire [snoop_offset_width_p-1:0] snoop_word_offset = vaddr_tv_r[2+:snoop_offset_width_p];
  bsg_mux
   #(.width_p(instr_width_p), .els_p(icache_fill_width_p/instr_width_p))
   snoop_mux
    (.data_i(data_mem_pkt.data)
     ,.sel_i(snoop_word_offset)
     ,.data_o(snoop_word)
     );
  wire [icache_block_width_p-1:0] snoop_data_lo = {icache_block_width_p/instr_width_p{snoop_word}};

  logic [icache_block_width_p-1:0] ld_data_tv_n;
  bsg_mux
   #(.width_p(icache_assoc_p*bank_width_lp), .els_p(2))
   ld_data_mux
    (.data_i({snoop_data_lo, data_mem_data_lo})
     ,.sel_i(cache_req_critical_i)
     ,.data_o(ld_data_tv_n)
     );

  logic [icache_assoc_p-1:0]     way_v_tv_r;
  logic [lg_icache_assoc_lp-1:0] way_invalid_index;
  logic                          invalid_exist;

  assign tv_we = ~v_tv_r | data_yumi_i | is_redir;
  assign tv_we_o = tv_we;
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tv_r       <= 1'b0;
    end
    else begin
      if (tv_we) begin
        v_tv_r         <= v_tl_r & ~is_redir;
        addr_tv_r      <= addr_tl;
        vaddr_tv_r     <= vaddr_tl_r;
        tag_tv_r       <= tag_tl;
        state_tv_r     <= state_tl;
        cached_tv_r    <= (fetch_op_tl_r | fill_op_tl_r) & ~uncached_i;
        uncached_tv_r  <= (fetch_op_tl_r | fill_op_tl_r) &  uncached_i;
        fencei_op_tv_r <= fencei_op_tl_r;
        fill_op_tv_r   <= fill_op_tl_r;
        addr_tag_tv_r  <= addr_tag_tl;
        addr_bank_offset_dec_tv_r <= addr_bank_offset_dec_tl;
        way_v_tv_r     <= way_v_tl;
      end
      if (tv_we | cache_req_critical_i) begin
        ld_data_tv_r   <= ld_data_tv_n;
      end
      if (tv_we) begin
        hit_v_tv_r    <= hit_v_tl;
        complete_tv_r <= ~fencei_op_tl_r & ~(fill_op_tl_r & (~|hit_v_tl | uncached_i));
      end else if (cache_req_complete_i) begin
        // We make a hit so that an arbitrary data word is selected from the
        //   snooped line, which has replicated versions of the word
        hit_v_tv_r    <= 1'b1;
        complete_tv_r <= 1'b1;
      end
    end
  end

  assign addr_index_tv = addr_tv_r[block_offset_width_lp+:index_width_lp];

  always_comb
    begin
      case (state_r)
        e_ready  : state_n = cache_req_v_o ? e_miss : e_ready;
        e_miss   : state_n = (cache_req_complete_i & v_tl_r) ? e_recover : e_miss;
        e_recover: state_n = e_ready;
        default: state_n = e_ready;
      endcase
    end

  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  wire uncached_req = is_ready & v_tv_r & fill_op_tv_r & uncached_tv_r & ~complete_tv_r;
  wire fencei_req   = is_ready & v_tv_r & fencei_op_tv_r;
  wire cached_req   = is_ready & v_tv_r & fill_op_tv_r & ~uncached_tv_r & ~complete_tv_r;

  // stat memory
  logic                          stat_mem_v_li;
  logic                          stat_mem_w_li;
  logic [index_width_lp-1:0]     stat_mem_addr_li;
  bp_icache_stat_info_s          stat_mem_data_li;
  bp_icache_stat_info_s          stat_mem_mask_li;
  bp_icache_stat_info_s          stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(icache_assoc_p-1)
    ,.els_p(icache_sets_p)
    ,.latch_last_read_p(1)
  ) stat_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(stat_mem_data_li.lru)
    ,.addr_i(stat_mem_addr_li)
    ,.v_i(stat_mem_v_li)
    ,.w_mask_i(stat_mem_mask_li.lru)
    ,.w_i(stat_mem_w_li)
    ,.data_o(stat_mem_data_lo.lru)
  );

  logic [lg_icache_assoc_lp-1:0] lru_encode;

  bsg_lru_pseudo_tree_encode #(
    .ways_p(icache_assoc_p)
  ) lru_encoder (
    .lru_i(stat_mem_data_lo.lru)
    ,.way_id_o(lru_encode)
  );

  bsg_priority_encode #(
    .width_p(icache_assoc_p)
    ,.lo_to_hi_p(1)
  ) pe_invalid (
    .i(~way_v_tv_r)
    ,.v_o(invalid_exist)
    ,.addr_o(way_invalid_index)
 );

  // LCE
  bp_icache_data_mem_pkt_s data_mem_pkt;
  assign data_mem_pkt = data_mem_pkt_i;
  bp_icache_tag_mem_pkt_s tag_mem_pkt;
  assign tag_mem_pkt = tag_mem_pkt_i;
  bp_icache_stat_mem_pkt_s stat_mem_pkt;
  assign stat_mem_pkt = stat_mem_pkt_i;

  always_comb begin
    cache_req_cast_lo = '0;
    cache_req_v_o = '0;

    if (cached_req) begin
      cache_req_cast_lo.addr = addr_tv_r;
      cache_req_cast_lo.msg_type = e_miss_load;
      cache_req_cast_lo.size = e_size_64B;
      cache_req_v_o = cache_req_ready_i;
    end
    else if (uncached_req) begin
      cache_req_cast_lo.addr = addr_tv_r;
      cache_req_cast_lo.msg_type = e_uc_load;
      cache_req_cast_lo.size = e_size_4B;
      cache_req_v_o = cache_req_ready_i;
    end
    else if (fencei_req) begin
      // Don't flush on fencei when coherent
      cache_req_cast_lo.msg_type = e_cache_clear;
      cache_req_v_o = cache_req_ready_i & (l1_coherent_p == 0);
    end
  end

  // The cache pipeline is designed to always send metadata a cycle after the request
  bsg_dff_reset
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(cache_req_v_o)
     ,.data_o(cache_req_metadata_v_o)
     );

  // invalid way takes priority over LRU way
  assign cache_req_metadata_cast_lo.repl_way = invalid_exist ? way_invalid_index : lru_encode;
  assign cache_req_metadata_cast_lo.dirty = '0;

  always_comb
    case (icache_pkt.op)
      e_icache_fetch, e_icache_fill, e_icache_fencei:
        yumi_o = cache_req_ready_i & is_ready & (~v_tl_r | tv_we) & v_i;
      e_icache_redir:
        yumi_o = cache_req_ready_i & is_ready & v_i;
      default:
        yumi_o = '0;
    endcase

  assign data_v_o        = v_tv_r & complete_tv_r & ~is_redir;
  assign miss_not_data_o = v_tv_r & complete_tv_r & ~hit_v_tv_r;

  logic [bank_width_lp-1:0]   ld_data_way_picked;
  logic [icache_assoc_p-1:0]  ld_data_way_select;

  bsg_adder_one_hot
   #(.width_p(icache_assoc_p))
   select_adder
    (.a_i(hit_v_tv_r)
     ,.b_i(addr_bank_offset_dec_tv_r)
     ,.o(ld_data_way_select)
     );

  bsg_mux_one_hot #(
    .width_p(bank_width_lp)
    ,.els_p(icache_assoc_p)
  ) data_set_select_mux (
    .data_i(ld_data_tv_r)
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
     ,.sel_i(addr_tv_r[2+:`BSG_SAFE_CLOG2(num_words_per_bank_lp)])
     ,.data_o(final_data)
     );
  assign data_o = final_data;
  assign vaddr_o = vaddr_tv_r;

  // data mem
  logic                                                       data_mem_v;
  logic [icache_assoc_p-1:0]                                  data_mem_write_bank_mask;
  logic [icache_assoc_p-1:0][bank_width_lp-1:0]               data_mem_pkt_data_expanded;
  logic [block_size_in_fill_lp-1:0][fill_size_in_bank_lp-1:0] data_mem_pkt_fill_mask_expanded;

  logic                      data_mem_last_read_r;
  logic                      data_mem_bypass;
  logic [icache_assoc_p-1:0] data_mem_bypass_select;
  logic [icache_assoc_p-1:0] vaddr_offset_dec;

  // during a data mem bypass, only the necessary bank of data memory will be valid
  bsg_dff_reset #(.width_p(1))
    data_mem_last_read_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i(tl_we)
     ,.data_o(data_mem_last_read_r)
    );

  bsg_decode #(.num_out_p(icache_assoc_p)) 
    input_offset_decode 
    (.i(vaddr_offset)
     ,.o(vaddr_offset_dec)
    );

  bsg_adder_one_hot #(.width_p(icache_assoc_p))
    data_mem_bank_select_adder
    (.a_i(hit_v_tl)
     ,.b_i(vaddr_offset_dec)
     ,.o(data_mem_bypass_select)
    );

  // the following bypass logic assumes that vtag->ptag mapping will not change during bypass
  assign data_mem_bypass = (vaddr_vtag == vaddr_vtag_tl) & (vaddr_index == vaddr_index_tl) & data_mem_last_read_r;

  assign data_mem_v = (data_mem_pkt.opcode != e_cache_data_mem_uncached) & data_mem_pkt_yumi_o;

  assign data_mem_v_li = (tl_we | is_recover)
    ? data_mem_bypass
      ? data_mem_bypass_select 
      : {icache_assoc_p{1'b1}}
    : {icache_assoc_p{data_mem_v}};

  assign data_mem_w_li = data_mem_pkt_yumi_o
    & (data_mem_pkt.opcode == e_cache_data_mem_write);

  for (genvar i = 0; i < icache_assoc_p; i++) begin : rof1
    wire [bank_offset_width_lp-1:0] data_mem_pkt_offset = (bank_offset_width_lp'(i) - data_mem_pkt.way_id);

    assign data_mem_addr_li[i] = tl_we
      ? {vaddr_index, vaddr_offset}
      : is_recover
        ? vaddr_index_tl
        : {data_mem_pkt.index, data_mem_pkt_offset};

    // use fill_index to generate write_mask
    assign data_mem_w_mask_li[i] = {data_mem_mask_width_lp{data_mem_write_bank_mask[i]}};
  end

  // Expand the bank write mask to bank width
  assign data_mem_pkt_data_expanded = {block_size_in_fill_lp{data_mem_pkt.data}};

  wire [`BSG_SAFE_CLOG2(icache_block_width_p)-1:0] write_data_rot_li = data_mem_pkt.way_id*bank_width_lp;
  bsg_rotate_left #(
    .width_p(icache_block_width_p)
  ) write_data_rotate (
    .data_i(data_mem_pkt_data_expanded)
    ,.rot_i(write_data_rot_li)
    ,.o(data_mem_data_li)
  );

  // use fill_index to generate brank write mask
  for (genvar i = 0; i < block_size_in_fill_lp; i++) begin
    assign data_mem_pkt_fill_mask_expanded[i] = {fill_size_in_bank_lp{data_mem_pkt.fill_index[i]}};
  end

  wire [`BSG_SAFE_CLOG2(icache_assoc_p)-1:0] write_mask_rot_li = data_mem_pkt.way_id;
  bsg_rotate_left #(
    .width_p(icache_assoc_p)
  ) write_mask_rotate (
    .data_i(data_mem_pkt_fill_mask_expanded)
    ,.rot_i(write_mask_rot_li)
    ,.o(data_mem_write_bank_mask)
  );

  // tag_mem
  logic tag_mem_bypass;
  logic tag_mem_last_read_r;

  // tag mem is bypassed if the index is the same on consecutive reads
  bsg_dff_reset_set_clear #(
    .width_p(1)
    ,.clear_over_set_p(1)
  ) tag_mem_last_read_reg (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(tl_we)
    ,.clear_i(tag_mem_w_li)
    ,.data_o(tag_mem_last_read_r)
  ); 

  // Suboptimially blocks on last read
  assign tag_mem_bypass = (vaddr_index == vaddr_index_tl) & tag_mem_last_read_r;
  assign tag_mem_v_li = (tl_we & ~tag_mem_bypass) | is_recover | tag_mem_pkt_yumi_o;
  assign tag_mem_w_li = ~tl_we & ~is_recover & tag_mem_pkt_v_i & (tag_mem_pkt.opcode != e_cache_tag_mem_read);
  assign tag_mem_addr_li = tl_we
    ? vaddr_index
    : is_recover
      ? vaddr_index_tl
      : tag_mem_pkt.index;

  logic [icache_assoc_p-1:0] tag_mem_way_one_hot;
  bsg_decode #(
    .num_out_p(icache_assoc_p)
  ) tag_mem_way_decode (
    .i(tag_mem_pkt.way_id)
    ,.o(tag_mem_way_one_hot)
  );

  always_comb begin
    case (tag_mem_pkt.opcode)
      e_cache_tag_mem_set_clear: begin
        for (integer i = 0 ; i < icache_assoc_p; i++) begin
          tag_mem_data_li[i]    = '0;
          tag_mem_w_mask_li[i]  = {($bits(bp_coh_states_e)+ptag_width_p){1'b1}};
        end
      end
      e_cache_tag_mem_set_tag: begin
        for (integer i = 0; i < icache_assoc_p; i++) begin
          tag_mem_data_li[i]   = {tag_mem_pkt.state, tag_mem_pkt.tag};
          tag_mem_w_mask_li[i] = {($bits(bp_coh_states_e)+ptag_width_p){tag_mem_way_one_hot[i]}};
        end
      end
      e_cache_tag_mem_set_state: begin
        for (integer i = 0; i < icache_assoc_p; i++) begin
          tag_mem_data_li[i]   = {tag_mem_pkt.state, '0};
          tag_mem_w_mask_li[i] = {{$bits(bp_coh_states_e){tag_mem_way_one_hot[i]}}, {ptag_width_p{1'b0}}};
        end
      end
      default: begin
        tag_mem_data_li   = '0;
        tag_mem_w_mask_li = '0;
      end
    endcase
  end

  // stat mem
  assign stat_mem_v_li = (v_tv_r & cached_tv_r) | stat_mem_pkt_yumi_o;
  assign stat_mem_w_li = (v_tv_r & cached_tv_r)
    ? complete_tv_r
    : stat_mem_pkt_yumi_o & (stat_mem_pkt.opcode != e_cache_stat_mem_read);
  assign stat_mem_addr_li = (v_tv_r & ~uncached_tv_r & ~fencei_op_tv_r)
    ? addr_index_tv
    : stat_mem_pkt.index;

  logic [icache_assoc_p-2:0] lru_decode_data_lo;
  logic [icache_assoc_p-2:0] lru_decode_mask_lo;

  logic [lg_icache_assoc_lp-1:0] hit_index_tv;
  bsg_encode_one_hot
   #(.width_p(icache_assoc_p)
     ,.lo_to_hi_p(1)
     )
   hit_index_encoder
    (.i(hit_v_tv_r)
     ,.addr_o(hit_index_tv)
     ,.v_o()
     );

  bsg_lru_pseudo_tree_decode #(
     .ways_p(icache_assoc_p)
  ) lru_decode (
     .way_id_i(hit_index_tv)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
  );

  always_comb begin
    if (v_tv_r) begin
      stat_mem_data_li.lru = lru_decode_data_lo;
      stat_mem_mask_li.lru = lru_decode_mask_lo;
    end else begin
      stat_mem_data_li.lru = {(icache_assoc_p-1){1'b0}};
      stat_mem_mask_li.lru = {(icache_assoc_p-1){1'b1}};
    end
  end

  // LCE: data mem
  logic [lg_icache_assoc_lp-1:0] data_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (data_mem_pkt_yumi_o & (data_mem_pkt.opcode == e_cache_data_mem_read)) begin
      data_mem_pkt_way_r <= data_mem_pkt.way_id;
    end
  end

  wire [`BSG_SAFE_CLOG2(icache_block_width_p)-1:0] read_data_rot_li = data_mem_pkt_way_r*bank_width_lp;
  bsg_rotate_right #(
    .width_p(icache_block_width_p)
  ) read_data_rotate (
    .data_i(data_mem_data_lo)
    ,.rot_i(read_data_rot_li)
    ,.o(data_mem_o)
  );

  assign data_mem_pkt_yumi_o = (data_mem_pkt.opcode == e_cache_data_mem_uncached)
                               ? data_mem_pkt_v_i
                               : data_mem_pkt_v_i & ~tl_we;

  // LCE: tag_mem

  logic [lg_icache_assoc_lp-1:0] tag_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (tag_mem_pkt_yumi_o & (tag_mem_pkt.opcode == e_cache_tag_mem_read)) begin
      tag_mem_pkt_way_r <= tag_mem_pkt.way_id;
    end
  end

  assign tag_mem_o = tag_mem_data_lo[tag_mem_pkt_way_r][0+:ptag_width_p];
  assign tag_mem_pkt_yumi_o = tag_mem_pkt_v_i & ~tl_we;

  // LCE: stat_mem
  // Stub out dirty bits in icache
  assign stat_mem_o = {stat_mem_data_lo.lru, icache_assoc_p'(0)};
  assign stat_mem_pkt_yumi_o = ~(v_tv_r & ~uncached_tv_r & ~fencei_op_tv_r) & stat_mem_pkt_v_i;

endmodule

