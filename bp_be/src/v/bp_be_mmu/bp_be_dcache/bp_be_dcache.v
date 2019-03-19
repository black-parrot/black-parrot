/**
 *  Name:
 *    bp_be_dcache.v
 *
 *  Description:
 *    L1 data cache. It receives load or store instruction from the mmu. This
 *    is virtually-indexed and physically-tagged cache. It is 8-way
 *    set-associative.
 *
 *    There are three different 1rw memory blocks: data_mem, tag_mem, stat_mem.
 *    
 *    data_mem is divided into 8 different banks, and cache blocks are
 *    interleaved among the banks. The governing relationship is "bank_id =
 *    word_offset ^ way_id".  
 *    
 *    tag_mem contains tag and coherence state bits.
 *    
 *    stat_mem contains information about dirty bits for each cache block and
 *    LRU info about each way group. This cache uses pseudo tree-LRU
 *    algorithm.
 *
 *    There are two pipeline stages: tag lookup (tl) and tag verity (tv) stages.
 *    Signals or registers belonging to each stage is suffixed by "_tl" or
 *    "tv". We could also think of input as another stage.
 *
 *    Physical tag translated by TLB arrives in tag lookup stages. tag_mem and
 *    TLB are accessed in the same cycle for each instruction. tlb_miss_i
 *    indicates that there is TLB miss and all instructions in tl and input stage
 *    has to be poisoned.
 *
 *    Instructions from mmu arrives in the form of bp_be_dcache_pkt_s. It
 *    contains opcode, addr, data.
 *    
 *    There is write buffer which allows holding write data info that left tv stage,
 *    in forms of "bp_be_dcache_wbuf_entry_s" until data_mem becomes free from incoming
 *    load instructions. It also allows bypassing of store data when load moving
 *    from tl to tv stage has the same address as the entries in write buffer.
 *    LCE can snoop write buffer entries to hold off lce_data_mem operations until entries
 *    with matching address is no longer present in write buffer.
 *
 *    There are tags in two different contexts: 'ptag' and 'tag'. 'ptag' is
 *    used in the context of translating 'vtag' into 'ptag', and its width is
 *    fixed as defined by sv39. 'tag' width can vary with the number of sets,
 *    and it is the width of the tag that is stored inside the cache.
 *    
 *    paddr_width = ptag_width + page_offset_width = tag_width + index_width
 *    + block_offset_width
 */

module bp_be_dcache
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter data_width_p="inv"
    , parameter paddr_width_p="inv"
    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
   
    , parameter debug_p=0 
 
    , localparam block_size_in_words_lp=ways_p
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_width_p>>3)
    , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
    , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(ways_p)
  
    , localparam lce_data_width_lp=(ways_p*data_width_p)
    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    , localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(bp_page_offset_width_gp,data_width_p)
    , localparam tag_info_width_lp=`bp_be_dcache_tag_info_width(tag_width_lp)
    , localparam stat_info_width_lp=`bp_be_dcache_stat_info_width(ways_p)
    
    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_lp)
    , localparam cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p)
    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, lce_data_width_lp, ways_p)
  )
  (
    input clk_i
    , input reset_i
    
    , input [lce_id_width_lp-1:0] lce_id_i

    , input [dcache_pkt_width_lp-1:0] dcache_pkt_i
    , input v_i
    , output logic ready_o

    , output logic [data_width_p-1:0] data_o
    , output logic v_o

    // TLB interface
    , input tlb_miss_i
    , input [ptag_width_lp-1:0] ptag_i

    // ctrl
    , output logic cache_miss_o
    , input poison_i

    // LCE-CCE interface
    , output logic [lce_cce_req_width_lp-1:0] lce_req_o
    , output logic lce_req_v_o
    , input lce_req_ready_i

    , output logic [lce_cce_resp_width_lp-1:0] lce_resp_o
    , output logic lce_resp_v_o
    , input lce_resp_ready_i

    , output logic [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
    , output logic lce_data_resp_v_o
    , input lce_data_resp_ready_i

    // CCE-LCE interface
    , input [cce_lce_cmd_width_lp-1:0] lce_cmd_i
    , input lce_cmd_v_i
    , output logic lce_cmd_ready_o

    , input [lce_data_cmd_width_lp-1:0] lce_data_cmd_i
    , input lce_data_cmd_v_i
    , output logic lce_data_cmd_ready_o

    // LCE-LCE interface
    , output logic [lce_data_cmd_width_lp-1:0] lce_data_cmd_o
    , output logic lce_data_cmd_v_o
    , input lce_data_cmd_ready_i 
  );

  // packet decoding
  //
  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, data_width_p);
  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = dcache_pkt_i;

  logic load_op;
  logic store_op;
  logic signed_op;
  logic double_op;
  logic word_op;
  logic half_op;
  logic byte_op;
  logic [index_width_lp-1:0] addr_index;
  logic [word_offset_width_lp-1:0] addr_word_offset;

  assign load_op = ~dcache_pkt.opcode[3];
  assign store_op = dcache_pkt.opcode[3];
  assign signed_op = ~dcache_pkt.opcode[2];
  assign double_op = (dcache_pkt.opcode[1:0] == 2'b11);
  assign word_op = (dcache_pkt.opcode[1:0] == 2'b10);
  assign half_op = (dcache_pkt.opcode[1:0] == 2'b01);
  assign byte_op = (dcache_pkt.opcode[1:0] == 2'b00);
  assign addr_index = dcache_pkt.page_offset[block_offset_width_lp+:index_width_lp];
  assign addr_word_offset = dcache_pkt.page_offset[byte_offset_width_lp+:word_offset_width_lp];
  
  // TL stage
  //
  logic v_tl_r; // valid bit
  logic tl_we;
  logic load_op_tl_r;
  logic store_op_tl_r;
  logic signed_op_tl_r;
  logic double_op_tl_r;
  logic word_op_tl_r;
  logic half_op_tl_r;
  logic byte_op_tl_r;
  logic [bp_page_offset_width_gp-1:0] page_offset_tl_r;
  logic [data_width_p-1:0] data_tl_r;

  assign tl_we = v_i & ready_o & ~poison_i;
 
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tl_r <= 1'b0;
    end
    else begin 
      v_tl_r <= tl_we;
      if (tl_we) begin
        load_op_tl_r <= load_op;
        store_op_tl_r <= store_op;
        signed_op_tl_r <= signed_op;
        double_op_tl_r <= double_op;
        word_op_tl_r <= word_op;
        half_op_tl_r <= half_op;
        byte_op_tl_r <= byte_op;
        page_offset_tl_r <= dcache_pkt.page_offset;
      end
    
      if (tl_we & store_op) begin
        data_tl_r <= dcache_pkt.data;
      end
    end
  end 
 
  // tag_mem
  //
  `declare_bp_be_dcache_tag_info_s(tag_width_lp);
  logic tag_mem_v_li;
  logic tag_mem_w_li;
  logic [index_width_lp-1:0] tag_mem_addr_li;
  bp_be_dcache_tag_info_s [ways_p-1:0] tag_mem_data_li;
  bp_be_dcache_tag_info_s [ways_p-1:0] tag_mem_mask_li;
  bp_be_dcache_tag_info_s [ways_p-1:0] tag_mem_data_lo;
  
  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(tag_info_width_lp*ways_p)
      ,.els_p(sets_p)
    )
    tag_mem
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(~reset_i & tag_mem_v_li)
      ,.w_i(tag_mem_w_li)
      ,.addr_i(tag_mem_addr_li)
      ,.data_i(tag_mem_data_li)
      ,.w_mask_i(tag_mem_mask_li)
      ,.data_o(tag_mem_data_lo)
      );

  // data_mem
  //
  logic [ways_p-1:0] data_mem_v_li;
  logic [ways_p-1:0] data_mem_w_li;
  logic [ways_p-1:0][index_width_lp+word_offset_width_lp-1:0] data_mem_addr_li;
  logic [ways_p-1:0][data_width_p-1:0] data_mem_data_li;
  logic [ways_p-1:0][data_mask_width_lp-1:0] data_mem_mask_li;
  logic [ways_p-1:0][data_width_p-1:0] data_mem_data_lo;
  
  for (genvar i = 0; i < ways_p; i++) begin: data_mem
    bsg_mem_1rw_sync_mask_write_byte
      #(.data_width_p(data_width_p)
        ,.els_p(sets_p*ways_p)
        )
      data_mem
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.v_i(~reset_i & data_mem_v_li[i])
        ,.w_i(data_mem_w_li[i])
        ,.addr_i(data_mem_addr_li[i])
        ,.data_i(data_mem_data_li[i])
        ,.write_mask_i(data_mem_mask_li[i])
        ,.data_o(data_mem_data_lo[i])
        );
  end

  // TV stage
  //
  logic v_tv_r;
  logic tv_we;
  logic load_op_tv_r;
  logic store_op_tv_r;
  logic signed_op_tv_r;
  logic double_op_tv_r;
  logic word_op_tv_r;
  logic half_op_tv_r;
  logic byte_op_tv_r;
  logic [paddr_width_p-1:0] paddr_tv_r;
  logic [data_width_p-1:0] data_tv_r;
  bp_be_dcache_tag_info_s [ways_p-1:0] tag_info_tv_r;
  logic [ways_p-1:0][data_width_p-1:0] ld_data_tv_r;
  logic [tag_width_lp-1:0] addr_tag_tv;
  logic [index_width_lp-1:0] addr_index_tv;
  logic [word_offset_width_lp-1:0] addr_word_offset_tv;

  assign tv_we = v_tl_r & ~poison_i & ~tlb_miss_i;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tv_r <= 1'b0;
    end
    else begin
      v_tv_r <= tv_we;

      if (tv_we) begin
        load_op_tv_r <= load_op_tl_r;
        store_op_tv_r <= store_op_tl_r;
        double_op_tv_r <= double_op_tl_r;
        signed_op_tv_r <= signed_op_tl_r;
        word_op_tv_r <= word_op_tl_r;
        half_op_tv_r <= half_op_tl_r;
        byte_op_tv_r <= byte_op_tl_r;
        paddr_tv_r <= {ptag_i, page_offset_tl_r};
        tag_info_tv_r <= tag_mem_data_lo;
      end

      if (tv_we & load_op_tl_r) begin
        ld_data_tv_r <= data_mem_data_lo;
      end

      if (tv_we & store_op_tl_r) begin
        data_tv_r <= data_tl_r;
      end
    end
  end

  assign addr_tag_tv = paddr_tv_r[block_offset_width_lp+index_width_lp+:tag_width_lp];
  assign addr_index_tv = paddr_tv_r[block_offset_width_lp+:index_width_lp];
  assign addr_word_offset_tv = paddr_tv_r[byte_offset_width_lp+:word_offset_width_lp];

  // miss_detect
  //
  logic [ways_p-1:0] load_hit_tv;
  logic [ways_p-1:0] store_hit_tv;
  logic [ways_p-1:0] invalid_tv;
  logic load_miss_tv;
  logic store_miss_tv;
  logic load_hit;
  logic store_hit;
  logic [way_id_width_lp-1:0] load_hit_way;
  logic [way_id_width_lp-1:0] store_hit_way;

  for (genvar i = 0; i < ways_p; i++) begin
    assign load_hit_tv[i] = (addr_tag_tv == tag_info_tv_r[i].tag)
      & (tag_info_tv_r[i].coh_state != e_MESI_I);
    assign store_hit_tv[i] = (addr_tag_tv == tag_info_tv_r[i].tag)
      & (tag_info_tv_r[i].coh_state == e_MESI_E);
    assign invalid_tv[i] = (tag_info_tv_r[i].coh_state == e_MESI_I);
  end

  bsg_priority_encode
    #(.width_p(ways_p)
      ,.lo_to_hi_p(1)
      )
    pe_load_hit
    (.i(load_hit_tv)
      ,.v_o(load_hit)
      ,.addr_o(load_hit_way)
      );
  
  bsg_priority_encode
    #(.width_p(ways_p)
      ,.lo_to_hi_p(1)
      )
    pe_store_hit
    (.i(store_hit_tv)
      ,.v_o(store_hit)
      ,.addr_o(store_hit_way)
      );

  assign load_miss_tv = ~load_hit & v_tv_r & load_op_tv_r;
  assign store_miss_tv = ~store_hit & v_tv_r & store_op_tv_r;


  // write buffer
  //
  `declare_bp_be_dcache_wbuf_entry_s(paddr_width_p, data_width_p, ways_p);

  bp_be_dcache_wbuf_entry_s wbuf_entry_in;
  logic wbuf_v_li;

  bp_be_dcache_wbuf_entry_s wbuf_entry_out;
  logic wbuf_v_lo;
  logic wbuf_yumi_li;
  
  logic wbuf_empty_lo;
  
  logic bypass_v_li;
  logic bypass_addr_li;
  logic [data_width_p-1:0] bypass_data_lo;
  logic [data_mask_width_lp-1:0] bypass_mask_lo;

  logic [index_width_lp-1:0] lce_snoop_index_li;
  logic [way_id_width_lp-1:0] lce_snoop_way_li;
  logic lce_snoop_match_lo; 
 
  bp_be_dcache_wbuf
    #(.data_width_p(data_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.ways_p(ways_p)
      ,.sets_p(sets_p)
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
    
      ,.bypass_v_i(bypass_v_li)
      ,.bypass_addr_i({ptag_i, page_offset_tl_r})
      ,.bypass_data_o(bypass_data_lo)
      ,.bypass_mask_o(bypass_mask_lo)

      ,.lce_snoop_index_i(lce_snoop_index_li)
      ,.lce_snoop_way_i(lce_snoop_way_li)
      ,.lce_snoop_match_o(lce_snoop_match_lo)
      );

  logic [word_offset_width_lp-1:0] wbuf_entry_out_word_offset;
  logic [index_width_lp-1:0] wbuf_entry_out_index;

  assign wbuf_entry_out_word_offset = wbuf_entry_out.paddr[byte_offset_width_lp+:word_offset_width_lp];
  assign wbuf_entry_out_index = wbuf_entry_out.paddr[block_offset_width_lp+:index_width_lp];

  assign wbuf_entry_in.paddr = paddr_tv_r;
  assign wbuf_entry_in.way_id = store_hit_way;

  if (data_width_p == 64) begin
    assign wbuf_entry_in.data = double_op_tv_r
      ? data_tv_r
      : (word_op_tv_r
        ? {2{data_tv_r[0+:32]}}
        : (half_op_tv_r
          ? {4{data_tv_r[0+:16]}}
          : {8{data_tv_r[0+:8]}}));

    assign wbuf_entry_in.mask = double_op_tv_r
      ? 8'b1111_1111
      : (word_op_tv_r
        ? {{4{paddr_tv_r[2]}}, {4{~paddr_tv_r[2]}}}
        : (half_op_tv_r
          ? {{2{paddr_tv_r[2] & paddr_tv_r[1]}}, {2{paddr_tv_r[2] & ~paddr_tv_r[1]}},
             {2{~paddr_tv_r[2] & paddr_tv_r[1]}}, {2{~paddr_tv_r[2] & ~paddr_tv_r[1]}}}
          : {(paddr_tv_r[2] & paddr_tv_r[1] & paddr_tv_r[0]), 
             (paddr_tv_r[2] & paddr_tv_r[1] & ~paddr_tv_r[0]),
             (paddr_tv_r[2] & ~paddr_tv_r[1] & paddr_tv_r[0]),
             (paddr_tv_r[2] & ~paddr_tv_r[1] & ~paddr_tv_r[0]),
             (~paddr_tv_r[2] & paddr_tv_r[1] & paddr_tv_r[0]),
             (~paddr_tv_r[2] & paddr_tv_r[1] & ~paddr_tv_r[0]),
             (~paddr_tv_r[2] & ~paddr_tv_r[1] & paddr_tv_r[0]),
             (~paddr_tv_r[2] & ~paddr_tv_r[1] & ~paddr_tv_r[0])
            }));
  end

  // stat_mem {lru, dirty}
  // It has (ways_p-1) bits to form pseudo-LRU tree, and ways_p bits for dirty
  // bit for each block in set.
  `declare_bp_be_dcache_stat_info_s(ways_p);

  logic stat_mem_v_li;
  logic stat_mem_w_li;
  logic [index_width_lp-1:0] stat_mem_addr_li;
  bp_be_dcache_stat_info_s stat_mem_data_li;
  bp_be_dcache_stat_info_s stat_mem_mask_li;
  bp_be_dcache_stat_info_s stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(stat_info_width_lp)
      ,.els_p(sets_p)
      )
    stat_mem
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(~reset_i & stat_mem_v_li)
      ,.w_i(stat_mem_w_li)
      ,.addr_i(stat_mem_addr_li)
      ,.data_i(stat_mem_data_li)
      ,.w_mask_i(stat_mem_mask_li)
      ,.data_o(stat_mem_data_lo)
      );
  
  logic [way_id_width_lp-1:0] lru_encode;

  bsg_lru_pseudo_tree_encode #(
    .ways_p(ways_p)
  ) lru_encoder (
    .lru_i(stat_mem_data_lo.lru)
    ,.way_id_o(lru_encode)
  );


  logic invalid_exist;
  logic [way_id_width_lp-1:0] invalid_way;
  bsg_priority_encode
    #(.width_p(ways_p)
      ,.lo_to_hi_p(1)
      )
    pe_invalid
      (.i(invalid_tv)
      ,.v_o(invalid_exist)
      ,.addr_o(invalid_way)
      );

  // if there is invalid way, then it take prioirty over LRU way.
  logic [way_id_width_lp-1:0] lce_lru_way_li;
  assign lce_lru_way_li = invalid_exist ? invalid_way : lru_encode;
 
  // LCE
  //
  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, data_width_p*ways_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_lp);
  `declare_bp_be_dcache_lce_stat_mem_pkt_s(sets_p, ways_p);

  bp_be_dcache_lce_data_mem_pkt_s lce_data_mem_pkt;
  bp_be_dcache_lce_tag_mem_pkt_s lce_tag_mem_pkt;
  bp_be_dcache_lce_stat_mem_pkt_s lce_stat_mem_pkt;

  logic lce_data_mem_pkt_v_lo;
  logic [ways_p-1:0][data_width_p-1:0] lce_data_mem_data_li;
  logic lce_data_mem_pkt_yumi_li;

  logic lce_tag_mem_pkt_v_lo;
  logic lce_tag_mem_pkt_yumi_li;

  logic lce_stat_mem_pkt_v_lo;
  logic lce_stat_mem_pkt_yumi_li;
 
  bp_be_dcache_lce
    #(.lce_data_width_p(ways_p*data_width_p)
      ,.data_width_p(data_width_p)
      ,.paddr_width_p(paddr_width_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      )
    lce
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
    
      ,.lce_id_i(lce_id_i)

      ,.ready_o(ready_o)
      ,.cache_miss_o(cache_miss_o)

      ,.load_miss_i(load_miss_tv)
      ,.store_miss_i(store_miss_tv)
      ,.miss_addr_i(paddr_tv_r)

      ,.data_mem_pkt_v_o(lce_data_mem_pkt_v_lo)
      ,.data_mem_pkt_o(lce_data_mem_pkt)
      ,.data_mem_data_i(lce_data_mem_data_li)
      ,.data_mem_pkt_yumi_i(lce_data_mem_pkt_yumi_li)

      ,.tag_mem_pkt_v_o(lce_tag_mem_pkt_v_lo)
      ,.tag_mem_pkt_o(lce_tag_mem_pkt)
      ,.tag_mem_pkt_yumi_i(lce_tag_mem_pkt_yumi_li)

      ,.stat_mem_pkt_v_o(lce_stat_mem_pkt_v_lo)
      ,.stat_mem_pkt_o(lce_stat_mem_pkt)
      ,.dirty_i(stat_mem_data_lo.dirty)
      ,.lru_way_i(lce_lru_way_li)
      ,.stat_mem_pkt_yumi_i(lce_stat_mem_pkt_yumi_li)
  
      ,.lce_req_o(lce_req_o)
      ,.lce_req_v_o(lce_req_v_o)
      ,.lce_req_ready_i(lce_req_ready_i)

      ,.lce_resp_o(lce_resp_o)
      ,.lce_resp_v_o(lce_resp_v_o)
      ,.lce_resp_ready_i(lce_resp_ready_i)

      ,.lce_data_resp_o(lce_data_resp_o)
      ,.lce_data_resp_v_o(lce_data_resp_v_o)
      ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

      ,.lce_cmd_i(lce_cmd_i)
      ,.lce_cmd_v_i(lce_cmd_v_i)
      ,.lce_cmd_ready_o(lce_cmd_ready_o)

      ,.lce_data_cmd_i(lce_data_cmd_i)
      ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
      ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

      ,.lce_data_cmd_o(lce_data_cmd_o)
      ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)
      );
 
  // output stage
  //
  assign v_o = v_tv_r & ~(load_miss_tv | store_miss_tv) & (~reset_i); 

  logic [data_width_p-1:0] ld_data_way_picked;
  logic [data_width_p-1:0] bypass_data_masked;

  bsg_mux
    #(.width_p(data_width_p)
      ,.els_p(ways_p)
      )
    ld_data_set_select_mux
      (.data_i(ld_data_tv_r)
      ,.sel_i(load_hit_way ^ addr_word_offset_tv)
      ,.data_o(ld_data_way_picked)
      );

  bsg_mux_segmented
    #(.segments_p(data_mask_width_lp)
      ,.segment_width_p(8)
      )
    bypass_mux_segmented
      (.data0_i(ld_data_way_picked)
      ,.data1_i(bypass_data_lo)
      ,.sel_i(bypass_mask_lo)
      ,.data_o(bypass_data_masked)
      );

  if (data_width_p == 64) begin
    logic [31:0] data_word_selected;
    logic [15:0] data_half_selected;
    logic [7:0] data_byte_selected;
    logic word_sigext;
    logic half_sigext;
    logic byte_sigext;
    
    bsg_mux 
      #(.width_p(32)
        ,.els_p(2)
        )
      word_mux
      (.data_i(bypass_data_masked)
      ,.sel_i(paddr_tv_r[2])
      ,.data_o(data_word_selected)
      );
    
    bsg_mux
      #(.width_p(16)
        ,.els_p(4)
        )
      half_mux
      (.data_i(bypass_data_masked)
      ,.sel_i(paddr_tv_r[2:1])
      ,.data_o(data_half_selected)
      );

    bsg_mux
      #(.width_p(8)
        ,.els_p(8)
      )
      byte_mux
      (.data_i(bypass_data_masked)
      ,.sel_i(paddr_tv_r[2:0])
      ,.data_o(data_byte_selected)
      );

    assign word_sigext = signed_op_tv_r & data_word_selected[31]; 
    assign half_sigext = signed_op_tv_r & data_half_selected[15]; 
    assign byte_sigext = signed_op_tv_r & data_byte_selected[7]; 

    assign data_o = load_op_tv_r
      ? (double_op_tv_r
        ? bypass_data_masked
        : (word_op_tv_r
          ? {{32{word_sigext}}, data_word_selected}
          : (half_op_tv_r
            ? {{48{half_sigext}}, data_half_selected}
            : {{56{byte_sigext}}, data_byte_selected})))
      : 64'b0;
  end
 
  // ctrl logic
  //

  // data_mem
  //
  logic [ways_p-1:0] wbuf_data_mem_v;
  bsg_decode
    #(.num_out_p(ways_p))
    wbuf_data_mem_v_decode
    ( .i(wbuf_entry_out.way_id ^ wbuf_entry_out_word_offset)
      ,.o(wbuf_data_mem_v)
      );  

  assign data_mem_v_li = (load_op & tl_we)
    ? {ways_p{1'b1}}
    : (wbuf_yumi_li
      ? wbuf_data_mem_v
      : {ways_p{lce_data_mem_pkt_yumi_li}});

  assign data_mem_w_li = {ways_p{(wbuf_yumi_li | (lce_data_mem_pkt_yumi_li & lce_data_mem_pkt.write_not_read))}};

  logic [ways_p-1:0][data_width_p-1:0] lce_data_mem_write_data;

  for (genvar i = 0; i < ways_p; i++) begin
    assign data_mem_addr_li[i] = (load_op & tl_we)
      ? {addr_index, addr_word_offset}
      : (wbuf_yumi_li
        ? {wbuf_entry_out_index, wbuf_entry_out_word_offset}
        : {lce_data_mem_pkt.index, lce_data_mem_pkt.way_id ^ ((word_offset_width_lp)'(i))});

    bsg_mux
      #(.els_p(ways_p)
        ,.width_p(data_width_p)
        )
      lce_data_mem_write_mux
        (.data_i(lce_data_mem_pkt.data)
        ,.sel_i(lce_data_mem_pkt.way_id ^ ((word_offset_width_lp)'(i)))
        ,.data_o(lce_data_mem_write_data[i])
        );

    assign data_mem_data_li[i] = wbuf_yumi_li
      ? wbuf_entry_out.data
      : lce_data_mem_write_data[i];
  
    assign data_mem_mask_li[i] = wbuf_yumi_li
      ? wbuf_entry_out.mask
      : {ways_p{1'b1}};
  end
 
  // tag_mem
  //
  assign tag_mem_v_li = tl_we | lce_tag_mem_pkt_yumi_li; 
  assign tag_mem_w_li = ~tl_we & lce_tag_mem_pkt_v_lo;
  assign tag_mem_addr_li = tl_we 
    ? addr_index
    : lce_tag_mem_pkt.index;

  logic [ways_p-1:0] lce_tag_mem_way_one_hot;
  bsg_decode
    #(.num_out_p(ways_p))
    lce_tag_mem_way_decode
      (.i(lce_tag_mem_pkt.way_id)
      ,.o(lce_tag_mem_way_one_hot)
      );

  always_comb begin
    case (lce_tag_mem_pkt.opcode)
      e_dcache_lce_tag_mem_set_clear: begin
        tag_mem_data_li = {(tag_info_width_lp*ways_p){1'b0}};
        tag_mem_mask_li = {(tag_info_width_lp*ways_p){1'b1}};
      end
      e_dcache_lce_tag_mem_invalidate: begin
        tag_mem_data_li = {((tag_info_width_lp)*ways_p){1'b0}};
        for (integer i = 0; i < ways_p; i++) begin
          tag_mem_mask_li[i].coh_state = {2{lce_tag_mem_way_one_hot[i]}};
          tag_mem_mask_li[i].tag = {tag_width_lp{1'b0}};
        end
      end
      e_dcache_lce_tag_mem_set_tag: begin
        tag_mem_data_li = {ways_p{lce_tag_mem_pkt.state, lce_tag_mem_pkt.tag}};
        for (integer i = 0; i < ways_p; i++) begin
          tag_mem_mask_li[i].coh_state = {2{lce_tag_mem_way_one_hot[i]}};
          tag_mem_mask_li[i].tag = {tag_width_lp{lce_tag_mem_way_one_hot[i]}};
        end
      end
      default: begin
        tag_mem_data_li = {(tag_info_width_lp*ways_p){1'b0}};
        tag_mem_mask_li = {(tag_info_width_lp*ways_p){1'b0}};
      end
    endcase
  end

  // stat_mem
  //
  assign stat_mem_v_li = v_tv_r | lce_stat_mem_pkt_yumi_li;
  assign stat_mem_w_li = v_tv_r 
    ? ~(load_miss_tv | store_miss_tv)
    : lce_stat_mem_pkt_yumi_li & (lce_stat_mem_pkt.opcode != e_dcache_lce_stat_mem_read);
  assign stat_mem_addr_li = v_tv_r
    ? addr_index_tv
    : lce_stat_mem_pkt.index;

  logic [way_id_width_lp-1:0] lru_decode_way_li;
  logic [ways_p-2:0] lru_decode_data_lo;
  logic [ways_p-2:0] lru_decode_mask_lo;

  bsg_lru_pseudo_tree_decode #(
    .ways_p(ways_p)
  ) lru_decode (
    .way_id_i(lru_decode_way_li)
    ,.data_o(lru_decode_data_lo)
    ,.mask_o(lru_decode_mask_lo)
  );
  

  logic [way_id_width_lp-1:0] dirty_mask_way_li;
  logic dirty_mask_v_li;
  logic [ways_p-1:0] dirty_mask_lo;

  bsg_decode_with_v
    #(.num_out_p(ways_p))
    dirty_mask_decode
      (.i(dirty_mask_way_li)
      ,.v_i(dirty_mask_v_li)
      ,.o(dirty_mask_lo)
      );

  always_comb begin
    if (v_tv_r) begin
      lru_decode_way_li = store_op_tv_r ? store_hit_way : load_hit_way;
      dirty_mask_way_li = store_hit_way;
      dirty_mask_v_li = store_op_tv_r;
      
      stat_mem_data_li.lru = lru_decode_data_lo;
      stat_mem_data_li.dirty = {ways_p{1'b1}};
      stat_mem_mask_li = {lru_decode_mask_lo, dirty_mask_lo};
    end
    else begin
      lru_decode_way_li = lce_stat_mem_pkt.way_id;
      dirty_mask_way_li = lce_stat_mem_pkt.way_id;
      dirty_mask_v_li = 1'b1;
      case (lce_stat_mem_pkt.opcode)
        e_dcache_lce_stat_mem_set_clear: begin
          stat_mem_data_li = {(stat_info_width_lp){1'b0}};
          stat_mem_mask_li = {(stat_info_width_lp){1'b1}};
        end
        e_dcache_lce_stat_mem_clear_dirty: begin
          stat_mem_data_li = {(stat_info_width_lp){1'b0}};
          stat_mem_mask_li.lru = {(ways_p-1){1'b0}};
          stat_mem_mask_li.dirty = dirty_mask_lo;
        end
        e_dcache_lce_stat_mem_set_lru: begin
          stat_mem_data_li.lru = ~lru_decode_data_lo;
          stat_mem_data_li.dirty = {ways_p{1'b0}};
          stat_mem_mask_li.lru = lru_decode_mask_lo;
          stat_mem_mask_li.dirty = {ways_p{1'b0}};
        end
        default: begin
          stat_mem_data_li = {(stat_info_width_lp){1'b0}};
          stat_mem_mask_li = {(stat_info_width_lp){1'b0}};
        end
      endcase
    end
  end


  // write buffer
  //
  assign wbuf_v_li = v_tv_r & store_op_tv_r & store_hit;
  assign wbuf_yumi_li = wbuf_v_lo & ~(load_op & tl_we);
  assign bypass_v_li = tv_we & load_op_tl_r;
  assign lce_snoop_index_li = lce_data_mem_pkt.index;
  assign lce_snoop_way_li = lce_data_mem_pkt.way_id;

  // LCE data_mem
  //
  logic [way_id_width_lp-1:0] lce_data_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (lce_data_mem_pkt_v_lo & lce_data_mem_pkt_yumi_li & ~lce_data_mem_pkt.write_not_read) begin
      lce_data_mem_pkt_way_r <= lce_data_mem_pkt.way_id;
    end
  end

  for (genvar i = 0; i < ways_p; i++) begin
    bsg_mux 
      #(.els_p(ways_p)
        ,.width_p(data_width_p)
        )
      lce_data_mem_read_mux
        (.data_i(data_mem_data_lo)
        ,.sel_i(lce_data_mem_pkt_way_r ^ ((word_offset_width_lp)'(i)))
        ,.data_o(lce_data_mem_data_li[i])
        );
  end

  assign lce_data_mem_pkt_yumi_li = ~(load_op & tl_we)
    & ~wbuf_v_lo & ~lce_snoop_match_lo & lce_data_mem_pkt_v_lo;
  
  // LCE tag_mem
  //
  assign lce_tag_mem_pkt_yumi_li = lce_tag_mem_pkt_v_lo & ~tl_we;
  
  // LCE stat_mem
  //
  assign lce_stat_mem_pkt_yumi_li = ~v_tv_r & lce_stat_mem_pkt_v_lo;

  // synopsys translate_off
  if (debug_p) begin
    bp_be_dcache_axe_trace_gen
      #(.addr_width_p(paddr_width_p)
        ,.data_width_p(data_width_p)
        ,.num_lce_p(num_lce_p)
        )
      axe_trace_gen
        (.clk_i(clk_i)
        ,.id_i(lce_id_i)
        ,.v_i(v_o)
        ,.addr_i(paddr_tv_r)
        ,.load_data_i(data_o)
        ,.store_data_i(data_tv_r)
        ,.load_i(load_op_tv_r)
        ,.store_i(store_op_tv_r)
        );
  end

  always_ff @ (negedge clk_i) begin
    if (v_tv_r) begin
      assert($countones(load_hit_tv) <= 1)
        else $error("multiple load hit: %b. id = %0d", load_hit_tv, lce_id_i);
      assert($countones(store_hit_tv) <= 1)
        else $error("multiple store hit: %b. id = %0d", store_hit_tv, lce_id_i);
    end
  end

  initial begin
    assert(data_width_p == 64) else $error("data_width_p has to be 64");
    assert(ways_p == 8) else $error("ways_p has to be 8");
  end
  // synopsys translate_on

endmodule
