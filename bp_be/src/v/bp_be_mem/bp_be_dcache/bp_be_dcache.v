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
 *
 *    Load reserved and store conditional are implemented at a cache line granularity.
 *    A load reserved acts as a normal load with the following addtional properties:
 *    1) If the block is not in an exclusive ownership state (M or E in MESI), then the cache
 *    will send an upgrade request (store miss).
 *    2) If the LR is successful, a reservation is placed on the cache line. This reservation is 
 *    valid for the current hart only.
 *    A store conditional will succeed (return 0) if there is a valid reservation on the address of
 *    the SC. Else, it will fail (return nonzero and will not commit the store). A failing store 
 *    conditional will not produce a cache miss.
 *
 *    The reservation can be cleared by:
 *    1) Any SC to any address by this hart.
 *    2) A second LR (this will not clear the reservation, but it will change the reservation
 *    address).
 *    3) An invalidate received from the LCE. This command covers all cases of losing exclusive
 *    access to the block in this hart, including eviction and a cache miss.
 
 *    RISC-V guarantees forward progress for LR/SC sequences that match a set of conditions.
 *    Currently, BlackParrot makes no guarantees about these sequences, but one option to guarantee
 *    progress is to block reservation invalidates from other harts until a following SC. There is
 *    a design space exploration to be done between QoS and performance based on the backoff model
 *    used for these schemes.
 *
 *    LR/SC aq/rl semantics are irrelevant for BlackParrot. Since we are in-order single issue and
 *    do not use a store buffer that allows stores before cache lines have been fetched,, all
 *     memory requests are inherently ordered within a hart. 
 */

module bp_be_dcache
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache)
   
    , parameter writethrough_p=0
    , parameter debug_p=0 
    , parameter lock_max_limit_p=8

    , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
    , localparam block_size_in_words_lp = dcache_assoc_p
    , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
    , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
    , localparam bypass_data_mask_width_lp = (dword_width_p >> 3)
    , localparam data_mem_mask_width_lp = (bank_width_lp >> 3) 
    , localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(bank_width_lp>>3) 
    , localparam word_offset_width_lp = `BSG_SAFE_CLOG2(block_size_in_words_lp)
    , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
    , localparam index_width_lp=`BSG_SAFE_CLOG2(dcache_sets_p)
    , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
    , localparam way_id_width_lp=`BSG_SAFE_CLOG2(dcache_assoc_p)
  
    , localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(bp_page_offset_width_gp,dword_width_p)
    , localparam tag_info_width_lp=`bp_be_dcache_tag_info_width(ptag_width_lp)
    , localparam stat_info_width_lp=`bp_cache_stat_info_width(dcache_assoc_p)
  )
  (
    input clk_i
    , input reset_i
    
    , input [cfg_bus_width_lp-1:0] cfg_bus_i

    , input [dcache_pkt_width_lp-1:0] dcache_pkt_i
    , input v_i
    , output logic ready_o

    , output logic [dword_width_p-1:0] data_o
    , output logic v_o
    , output logic fencei_v_o

    // TLB interface
    , input tlb_miss_i
    , input [ptag_width_lp-1:0] ptag_i
    , input uncached_i

    , output logic load_op_tl_o
    , output logic store_op_tl_o

    // ctrl
    , output dcache_miss_o // Used for mem connections (ptw and MMU resp connections)
    , input poison_i

    // D$-LCE Interface
    // signals to LCE
    , output [dcache_req_width_lp-1:0] cache_req_o
    , output logic cache_req_v_o 
    , input cache_req_ready_i
    , output [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
    , output cache_req_metadata_v_o

    , input cache_req_complete_i

    // data_mem
    , input data_mem_pkt_v_i
    , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
    , output logic data_mem_pkt_ready_o
    , output logic [dcache_block_width_p-1:0] data_mem_o

    // tag_mem
    , input tag_mem_pkt_v_i
    , input [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_i
    , output logic tag_mem_pkt_ready_o
    , output logic [ptag_width_lp-1:0] tag_mem_o

    // stat_mem
    , input stat_mem_pkt_v_i
    , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
    , output logic stat_mem_pkt_ready_o
    , output logic [stat_info_width_lp-1:0] stat_mem_o

  );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache);
  bp_dcache_req_s cache_req_cast_o;
  bp_dcache_req_metadata_s cache_req_metadata_cast_o;
  assign cache_req_o = cache_req_cast_o;
  assign cache_req_metadata_o = cache_req_metadata_cast_o;

  
  // packet decoding
  //
  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_p);
  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = dcache_pkt_i;

  typedef enum logic [1:0] {
      e_dword
    , e_word
    , e_halfword
    , e_byte
  } size_op_e;


  logic lr_op;
  logic sc_op;
  logic load_op;
  logic store_op;
  logic signed_op;
  size_op_e  size_op;
  logic double_op;
  logic word_op;
  logic half_op;
  logic byte_op;
  logic fencei_op;
  logic [index_width_lp-1:0] addr_index;
  logic [word_offset_width_lp-1:0] addr_word_offset;

  always_comb begin
    lr_op     = 1'b0;
    sc_op     = 1'b0;
    load_op   = 1'b0;
    store_op  = 1'b0;
    signed_op = 1'b1;
    double_op = 1'b0;
    word_op   = 1'b0;
    half_op   = 1'b0;
    byte_op   = 1'b0;
    size_op   = e_byte;
    fencei_op  = 1'b0;

    unique case (dcache_pkt.opcode)
      e_dcache_opcode_lrw, e_dcache_opcode_lrd: begin
        // An LR is a load operation of either double word or word size, inherently signed
        lr_op     = 1'b1;
        load_op   = 1'b1;
      end
      e_dcache_opcode_scw, e_dcache_opcode_scd: begin
        // An SC is a store operation of either double word or word size, inherently signed
        sc_op     = 1'b1;
        store_op  = 1'b1;
      end
      e_dcache_opcode_ld, e_dcache_opcode_lw, e_dcache_opcode_lh, e_dcache_opcode_lb: begin
        load_op   = 1'b1;
      end
      e_dcache_opcode_lwu, e_dcache_opcode_lhu, e_dcache_opcode_lbu: begin
        load_op   = 1'b1;
        signed_op = 1'b0;
      end
      e_dcache_opcode_sd, e_dcache_opcode_sw, e_dcache_opcode_sh, e_dcache_opcode_sb: begin
        store_op  = 1'b1;
      end
      e_dcache_opcode_fencei: begin
        fencei_op  = 1'b1;
      end
      default: begin end
    endcase

    unique case (dcache_pkt.opcode)
      e_dcache_opcode_ld, e_dcache_opcode_lrd, e_dcache_opcode_sd, e_dcache_opcode_scd: begin
        double_op = 1'b1;
        size_op   = e_dword;
      end
      e_dcache_opcode_lw, e_dcache_opcode_lwu, e_dcache_opcode_sw
        , e_dcache_opcode_lrw, e_dcache_opcode_scw: begin
        word_op = 1'b1;
        size_op = e_word;
      end
      e_dcache_opcode_lh, e_dcache_opcode_lhu, e_dcache_opcode_sh: begin
        half_op = 1'b1;
        size_op = e_halfword;
      end
      e_dcache_opcode_lb, e_dcache_opcode_lbu, e_dcache_opcode_sb: begin
        byte_op = 1'b1;
        size_op = e_byte;
      end
      default: begin end
    endcase
  end

  assign addr_index = dcache_pkt.page_offset[block_offset_width_lp+:index_width_lp];
  assign addr_word_offset = dcache_pkt.page_offset[byte_offset_width_lp+:word_offset_width_lp];
  
  // TL stage
  //
  logic v_tl_r; // valid bit
  logic tl_we;
  logic lr_op_tl_r;
  logic sc_op_tl_r;
  logic load_op_tl_r;
  logic store_op_tl_r;
  logic signed_op_tl_r;
  size_op_e  size_op_tl_r;
  logic double_op_tl_r;
  logic word_op_tl_r;
  logic half_op_tl_r;
  logic byte_op_tl_r;
  logic fencei_op_tl_r;
  logic [bp_page_offset_width_gp-1:0] page_offset_tl_r;
  logic [dword_width_p-1:0] data_tl_r;
  logic fencei_req;
  logic gdirty_r;

  assign tl_we = v_i & cache_req_ready_i & ~fencei_req;
  
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tl_r <= 1'b0;
    end
    else begin 
      v_tl_r <= tl_we;
      if (tl_we) begin
        lr_op_tl_r <= lr_op;
        sc_op_tl_r <= sc_op;
        load_op_tl_r <= load_op;
        store_op_tl_r <= store_op;
        signed_op_tl_r <= signed_op;
        size_op_tl_r <= size_op;
        double_op_tl_r <= double_op;
        word_op_tl_r <= word_op;
        half_op_tl_r <= half_op;
        byte_op_tl_r <= byte_op;
        fencei_op_tl_r <= fencei_op;
        page_offset_tl_r <= dcache_pkt.page_offset;
      end
    
      if (tl_we & store_op) begin
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
  logic [dcache_assoc_p-1:0] data_mem_v_li;
  logic data_mem_w_li;
  logic [dcache_assoc_p-1:0][index_width_lp+word_offset_width_lp-1:0] data_mem_addr_li;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] data_mem_data_li;
  logic [dcache_assoc_p-1:0][data_mem_mask_width_lp-1:0] data_mem_mask_li;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] data_mem_data_lo;
  
  for (genvar i = 0; i < dcache_assoc_p; i++) begin: data_mem
    bsg_mem_1rw_sync_mask_write_byte
      #(.data_width_p(bank_width_lp)
        ,.els_p(dcache_sets_p*dcache_assoc_p)
        )
      data_mem
        (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.v_i(~reset_i & data_mem_v_li[i])
        ,.w_i(data_mem_w_li)
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
  logic lr_op_tv_r;
  logic sc_op_tv_r;
  logic load_op_tv_r;
  logic store_op_tv_r;
  logic signed_op_tv_r;
  size_op_e  size_op_tv_r;
  logic double_op_tv_r;
  logic word_op_tv_r;
  logic half_op_tv_r;
  logic byte_op_tv_r;
  logic fencei_op_tv_r;
  logic uncached_tv_r;
  logic [paddr_width_p-1:0] paddr_tv_r;
  logic [dword_width_p-1:0] data_tv_r;
  bp_be_dcache_tag_info_s [dcache_assoc_p-1:0] tag_info_tv_r;
  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] ld_data_tv_r;
  logic [ptag_width_lp-1:0] addr_tag_tv;
  logic [index_width_lp-1:0] addr_index_tv;
  logic [word_offset_width_lp-1:0] addr_word_offset_tv;

  assign tv_we = v_tl_r & ~poison_i & ~tlb_miss_i & ~fencei_req;

  assign store_op_tl_o = v_tl_r & ~tlb_miss_i & store_op_tl_r;
  assign load_op_tl_o  = v_tl_r & ~tlb_miss_i & load_op_tl_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tv_r <= 1'b0;

      lr_op_tv_r <= '0;
      sc_op_tv_r <= '0;
      load_op_tv_r <= '0;
      store_op_tv_r <= '0;
      uncached_tv_r <= '0;
      signed_op_tv_r <= '0;
      size_op_tv_r <= e_byte;
      double_op_tv_r <= '0;
      word_op_tv_r <= '0;
      half_op_tv_r <= '0;
      byte_op_tv_r <= '0;
      fencei_op_tv_r <= '0;
      paddr_tv_r <= '0;
      tag_info_tv_r <= '0;

    end
    else begin
      v_tv_r <= tv_we;

      if (tv_we) begin
        lr_op_tv_r <= lr_op_tl_r;
        sc_op_tv_r <= sc_op_tl_r;
        load_op_tv_r <= load_op_tl_r;
        store_op_tv_r <= store_op_tl_r;
        signed_op_tv_r <= signed_op_tl_r;
        size_op_tv_r <= size_op_tl_r;
        double_op_tv_r <= double_op_tl_r;
        word_op_tv_r <= word_op_tl_r;
        half_op_tv_r <= half_op_tl_r;
        byte_op_tv_r <= byte_op_tl_r;
        fencei_op_tv_r <= fencei_op_tl_r;
        paddr_tv_r <= {ptag_i, page_offset_tl_r};
        tag_info_tv_r <= tag_mem_data_lo;
        uncached_tv_r <= uncached_i;
      end

      if (tv_we & load_op_tl_r) begin
        ld_data_tv_r <= data_mem_data_lo;
      end

      if (tv_we & store_op_tl_r) begin
        data_tv_r <= data_tl_r;
      end
    end
  end

  assign addr_tag_tv = paddr_tv_r[block_offset_width_lp+index_width_lp+:ptag_width_lp];
  assign addr_index_tv = paddr_tv_r[block_offset_width_lp+:index_width_lp];
  assign addr_word_offset_tv = paddr_tv_r[byte_offset_width_lp+:word_offset_width_lp];

  // miss_detect
  //
  logic [dcache_assoc_p-1:0] tag_match_tv;
  logic [dcache_assoc_p-1:0] load_hit_tv;
  logic [dcache_assoc_p-1:0] store_hit_tv;
  logic [dcache_assoc_p-1:0] invalid_tv;
  logic load_hit;
  logic store_hit;
  logic [way_id_width_lp-1:0] load_hit_way;
  logic [way_id_width_lp-1:0] store_hit_way;

  for (genvar i = 0; i < dcache_assoc_p; i++) begin: tag_comp
    assign tag_match_tv[i] = addr_tag_tv == tag_info_tv_r[i].tag;
    assign load_hit_tv[i] = tag_match_tv[i] & (tag_info_tv_r[i].coh_state != e_COH_I);
    assign store_hit_tv[i] = tag_match_tv[i] & ((tag_info_tv_r[i].coh_state == e_COH_M)
                                                || (tag_info_tv_r[i].coh_state == e_COH_E));
    assign invalid_tv[i] = (tag_info_tv_r[i].coh_state == e_COH_I);
  end

  bsg_priority_encode
    #(.width_p(dcache_assoc_p)
      ,.lo_to_hi_p(1)
      )
    pe_load_hit
    (.i(load_hit_tv)
      ,.v_o(load_hit)
      ,.addr_o(load_hit_way)
      );
  
  bsg_priority_encode
    #(.width_p(dcache_assoc_p)
      ,.lo_to_hi_p(1)
      )
    pe_store_hit
    (.i(store_hit_tv)
      ,.v_o(store_hit)
      ,.addr_o(store_hit_way)
      );

  wire load_miss_tv = ~load_hit & v_tv_r & load_op_tv_r & ~uncached_tv_r;
  wire store_miss_tv = ~store_hit & v_tv_r & store_op_tv_r & ~uncached_tv_r & ~sc_op_tv_r;
  wire lr_miss_tv = v_tv_r & lr_op_tv_r & ~store_hit;

  wire miss_tv = load_miss_tv | store_miss_tv | lr_miss_tv;

  // uncached req
  //
  logic uncached_load_req;
  logic uncached_store_req;
  logic uncached_load_data_v_r;
  logic [dword_width_p-1:0] uncached_load_data_r;

  // load reserved / store conditional
  logic lr_hit_tv;
  logic sc_success;
  logic sc_fail;
  logic [ptag_width_lp-1:0]  load_reserved_tag_r;
  logic [index_width_lp-1:0] load_reserved_index_r;
  logic load_reserved_v_r;

  // Load reserved misses if not in exclusive or modified (whether load hit or not)
  assign lr_hit_tv = v_tv_r & lr_op_tv_r & store_hit;
  // Succeed if the address matches and we have a store hit
  assign sc_success  = v_tv_r & sc_op_tv_r & store_hit & load_reserved_v_r 
                       & (load_reserved_tag_r == addr_tag_tv)
                       & (load_reserved_index_r == addr_index_tv);
  // Fail if we have a store conditional without success
  assign sc_fail     = v_tv_r & sc_op_tv_r & ~sc_success;
  assign uncached_load_req = v_tv_r & load_op_tv_r & uncached_tv_r & ~uncached_load_data_v_r;
  assign uncached_store_req = v_tv_r & store_op_tv_r & uncached_tv_r;
  assign fencei_req = v_tv_r & fencei_op_tv_r;

  // write buffer
  //
  `declare_bp_be_dcache_wbuf_entry_s(paddr_width_p, dword_width_p, dcache_assoc_p);

  bp_be_dcache_wbuf_entry_s wbuf_entry_in;
  logic wbuf_v_li;

  bp_be_dcache_wbuf_entry_s wbuf_entry_out;
  logic wbuf_v_lo;
  logic wbuf_yumi_li;
  
  logic wbuf_empty_lo;
  
  logic bypass_v_li;
  logic bypass_addr_li;
  logic [dword_width_p-1:0] bypass_data_lo;
  logic [bypass_data_mask_width_lp-1:0] bypass_mask_lo;

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
    
      ,.bypass_v_i(bypass_v_li)
      ,.bypass_addr_i({ptag_i, page_offset_tl_r})
      ,.bypass_data_o(bypass_data_lo)
      ,.bypass_mask_o(bypass_mask_lo)
      );

  logic [word_offset_width_lp-1:0] wbuf_entry_out_word_offset;
  logic [index_width_lp-1:0] wbuf_entry_out_index;

  assign wbuf_entry_out_word_offset = wbuf_entry_out.paddr[byte_offset_width_lp+:word_offset_width_lp];
  assign wbuf_entry_out_index = wbuf_entry_out.paddr[block_offset_width_lp+:index_width_lp];

  assign wbuf_entry_in.paddr = paddr_tv_r;
  assign wbuf_entry_in.way_id = store_hit_way;

  // TODO: Add assertion, otherwise this will just infer latches....
  if (dword_width_p == 64) begin
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
  `declare_bp_cache_stat_info_s(dcache_assoc_p, dcache);

  logic stat_mem_v_li;
  logic stat_mem_w_li;
  logic [index_width_lp-1:0] stat_mem_addr_li;
  bp_dcache_stat_info_s stat_mem_data_li;
  bp_dcache_stat_info_s stat_mem_mask_li;
  bp_dcache_stat_info_s stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(stat_info_width_lp)
      ,.els_p(dcache_sets_p)
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
    .ways_p(dcache_assoc_p)
  ) lru_encoder (
    .lru_i(stat_mem_data_lo.lru)
    ,.way_id_o(lru_encode)
  );

  logic invalid_exist;
  logic [way_id_width_lp-1:0] invalid_way;
  bsg_priority_encode
    #(.width_p(dcache_assoc_p)
      ,.lo_to_hi_p(1)
      )
    pe_invalid
      (.i(invalid_tv)
      ,.v_o(invalid_exist)
      ,.addr_o(invalid_way)
      );

  // if there is invalid way, then it take prioirty over LRU way.
  wire [way_id_width_lp-1:0] lru_way_li = invalid_exist ? invalid_way : lru_encode;
 
  // LCE Packet casting
  //
  bp_dcache_data_mem_pkt_s data_mem_pkt;
  assign data_mem_pkt = data_mem_pkt_i;
  bp_dcache_tag_mem_pkt_s tag_mem_pkt;
  assign tag_mem_pkt = tag_mem_pkt_i;
  bp_dcache_stat_mem_pkt_s stat_mem_pkt;
  assign stat_mem_pkt = stat_mem_pkt_i;

  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] lce_data_mem_data_li;
 
  logic data_mem_pkt_ready;
  logic tag_mem_pkt_ready;
  logic stat_mem_pkt_ready;

  
  // Assigning message types
  always_comb begin
    cache_req_v_o = 1'b0;

    cache_req_cast_o = '0;

    // Assigning sizes to cache miss packet
    if (uncached_tv_r)
      unique case (size_op_tv_r)
        e_dword: cache_req_cast_o.size = e_size_8B;
        e_word: cache_req_cast_o.size = e_size_4B;
        e_halfword: cache_req_cast_o.size = e_size_2B;
        e_byte: cache_req_cast_o.size = e_size_1B;
        default: cache_req_cast_o.size = e_size_8B;
      endcase
    else
      cache_req_cast_o.size = e_size_64B;

    if(load_miss_tv) begin
      cache_req_cast_o.msg_type = e_miss_load;
      cache_req_v_o = cache_req_ready_i;
    end
    else if(store_miss_tv | lr_miss_tv) begin
      cache_req_cast_o.msg_type = e_miss_store;
      cache_req_v_o = cache_req_ready_i;
    end
    else if(uncached_load_req) begin
      cache_req_cast_o.msg_type = e_uc_load;
      cache_req_v_o = cache_req_ready_i;
    end
    else if(uncached_store_req) begin
      cache_req_cast_o.msg_type = e_uc_store;
      cache_req_v_o = cache_req_ready_i;
    end
    else if(fencei_req) begin
      // Don't flush on fencei when coherent
      cache_req_cast_o.msg_type = e_cache_flush;
      cache_req_v_o = cache_req_ready_i & gdirty_r & (coherent_l1_p == 0);
    end

    cache_req_cast_o.addr = paddr_tv_r;
    cache_req_cast_o.data = data_tv_r;
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

  assign cache_req_metadata_cast_o.repl_way = lru_way_li;
  assign cache_req_metadata_cast_o.dirty = stat_mem_data_lo.dirty[lru_way_li];
  
  // output stage
  // Cache Miss Tracking logic
  logic cache_miss_r;
  wire miss_tracker_en_li = cache_req_v_o & ~uncached_store_req & ~fencei_req;
  bsg_dff_reset_en
   #(.width_p(1))
   cache_miss_tracker
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(miss_tracker_en_li | cache_req_complete_i)
     ,.data_i(cache_req_v_o)
     ,.data_o(cache_miss_r)
     );
  assign dcache_miss_o = cache_miss_r || miss_tracker_en_li;
  assign ready_o = cache_req_ready_i & ~cache_miss_r;

  assign v_o = v_tv_r & ((uncached_tv_r & (load_op_tv_r & uncached_load_data_v_r))
                         | (uncached_tv_r & (store_op_tv_r & cache_req_ready_i))
                         | (~uncached_tv_r & ~fencei_op_tv_r & ~miss_tv)
                         );
  // Always send fencei when coherent
  assign fencei_v_o = fencei_req & (~gdirty_r | (coherent_l1_p == 1));

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
  bsg_dff_reset_en
   #(.width_p(1))
   gdirty_reg
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.en_i(wbuf_v_li | flush_req)
    ,.data_i(wbuf_v_li)

    ,.data_o(gdirty_r)
    );

  logic [`BSG_SAFE_CLOG2(lock_max_limit_p+1)-1:0] lock_cnt_r;
  wire lock_clr = v_o || (lock_cnt_r == lock_max_limit_p);
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
  
  assign data_mem_pkt_ready_o = data_mem_pkt_ready & ~cache_lock;
  assign tag_mem_pkt_ready_o = tag_mem_pkt_ready & ~cache_lock;
  assign stat_mem_pkt_ready_o = stat_mem_pkt_ready & ~cache_lock;

  logic [bank_width_lp-1:0] ld_data_way_picked;
  logic [dword_width_p-1:0] ld_data_dword_picked;
  logic [dword_width_p-1:0] bypass_data_masked;

  bsg_mux #(
    .width_p(bank_width_lp)
    ,.els_p(dcache_assoc_p)
  ) ld_data_set_select_mux (
    .data_i(ld_data_tv_r)
    ,.sel_i(load_hit_way ^ addr_word_offset_tv)
    ,.data_o(ld_data_way_picked)
  );

  bsg_mux
    #(.width_p(dword_width_p)
    ,.els_p(num_dwords_per_bank_lp)
    )
    dword_mux
    (.data_i(ld_data_way_picked)
    ,.sel_i(paddr_tv_r[3+:`BSG_CDIV(num_dwords_per_bank_lp, 2)])
    ,.data_o(ld_data_dword_picked)
    );

  bsg_mux_segmented #(
    .segments_p(bypass_data_mask_width_lp)
    ,.segment_width_p(8)
  ) bypass_mux_segmented (
    .data0_i(ld_data_dword_picked)
    ,.data1_i(bypass_data_lo)
    ,.sel_i(bypass_mask_lo)
    ,.data_o(bypass_data_masked)
  );

  logic [dword_width_p-1:0] final_data;
  bsg_mux #(
    .width_p(dword_width_p)
    ,.els_p(2)
  ) final_data_mux (
    .data_i({uncached_load_data_r, bypass_data_masked})
    ,.sel_i(uncached_tv_r)
    ,.data_o(final_data)
  );

  if (dword_width_p == 64) begin: output64
    logic [31:0] data_word_selected;
    logic [15:0] data_half_selected;
    logic [7:0] data_byte_selected;
    logic word_sigext;
    logic half_sigext;
    logic byte_sigext;
    
    bsg_mux #(
      .width_p(32)
      ,.els_p(2)
    ) word_mux (
      .data_i(final_data)
      ,.sel_i(paddr_tv_r[2])
      ,.data_o(data_word_selected)
    );
    
    bsg_mux #(
      .width_p(16)
      ,.els_p(4)
    ) half_mux (
      .data_i(final_data)
      ,.sel_i(paddr_tv_r[2:1])
      ,.data_o(data_half_selected)
    );

    bsg_mux #(
      .width_p(8)
      ,.els_p(8)
    ) byte_mux (
      .data_i(final_data)
      ,.sel_i(paddr_tv_r[2:0])
      ,.data_o(data_byte_selected)
    );

    assign word_sigext = signed_op_tv_r & data_word_selected[31]; 
    assign half_sigext = signed_op_tv_r & data_half_selected[15]; 
    assign byte_sigext = signed_op_tv_r & data_byte_selected[7]; 

    assign data_o = load_op_tv_r
      ? (double_op_tv_r
        ? final_data
        : (word_op_tv_r
          ? {{32{word_sigext}}, data_word_selected}
          : (half_op_tv_r
            ? {{48{half_sigext}}, data_half_selected}
            : {{56{byte_sigext}}, data_byte_selected})))
      : (sc_op_tv_r & ~sc_success
         ? 64'b1
         : 64'b0);

  end
 
  // ctrl logic
  //

  // data_mem
  //
  logic [dcache_assoc_p-1:0] wbuf_data_mem_v;
  bsg_decode #(
    .num_out_p(dcache_assoc_p)
  ) wbuf_data_mem_v_decode (
    .i(wbuf_entry_out.way_id ^ wbuf_entry_out_word_offset)
    ,.o(wbuf_data_mem_v)
  );  

  logic lce_data_mem_v;
  assign lce_data_mem_v = (data_mem_pkt.opcode != e_cache_data_mem_uncached)
    & data_mem_pkt_v_i;

  assign data_mem_v_li = (load_op & tl_we)
    ? {dcache_assoc_p{1'b1}}
    : (wbuf_yumi_li
      ? wbuf_data_mem_v
      : {dcache_assoc_p{lce_data_mem_v}});

  assign data_mem_w_li = wbuf_yumi_li
    | (data_mem_pkt_v_i & data_mem_pkt.opcode == e_cache_data_mem_write);

  logic [dcache_assoc_p-1:0][bank_width_lp-1:0] lce_data_mem_write_data;

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
    assign data_mem_addr_li[i] = (load_op & tl_we)
      ? {addr_index, addr_word_offset}
      : (wbuf_yumi_li
        ? {wbuf_entry_out_index, wbuf_entry_out_word_offset}
        : {data_mem_pkt.index, data_mem_pkt.way_id ^ ((word_offset_width_lp)'(i))});
    assign data_mem_data_li[i] = wbuf_yumi_li
      ? {num_dwords_per_bank_lp{wbuf_entry_out.data}}
      : lce_data_mem_write_data[i];
  
    assign data_mem_mask_li[i] = wbuf_yumi_li
      ? wbuf_mask
      : {data_mem_mask_width_lp{1'b1}};
  end

  bsg_mux_butterfly#(
    .width_p(bank_width_lp)
    ,.els_p(dcache_assoc_p)
  ) write_mux_butterfly (
    .data_i(data_mem_pkt.data)
    ,.sel_i(data_mem_pkt.way_id)
    ,.data_o(lce_data_mem_write_data)
  );
 
  // tag_mem
  //
  assign tag_mem_v_li = tl_we | tag_mem_pkt_v_i; 
  assign tag_mem_w_li = ~tl_we & tag_mem_pkt_v_i & (tag_mem_pkt.opcode != e_cache_tag_mem_read);
  assign tag_mem_addr_li = tl_we 
    ? addr_index
    : tag_mem_pkt.index;

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
      e_cache_tag_mem_invalidate: begin
        tag_mem_data_li = {((tag_info_width_lp)*dcache_assoc_p){1'b0}};
        for (integer i = 0; i < dcache_assoc_p; i++) begin 
          tag_mem_mask_li[i].coh_state = {`bp_coh_bits{lce_tag_mem_way_one_hot[i]}};
          tag_mem_mask_li[i].tag = {ptag_width_lp{1'b0}};
        end
      end
      e_cache_tag_mem_set_tag: begin
        tag_mem_data_li = {dcache_assoc_p{tag_mem_pkt.state, tag_mem_pkt.tag}};
        for (integer i = 0; i < dcache_assoc_p; i++) begin
          tag_mem_mask_li[i].coh_state = {`bp_coh_bits{lce_tag_mem_way_one_hot[i]}};
          tag_mem_mask_li[i].tag = {ptag_width_lp{lce_tag_mem_way_one_hot[i]}};
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
  assign stat_mem_v_li = (v_tv_r & ~uncached_tv_r & ~fencei_op_tv_r) | stat_mem_pkt_v_i;
  assign stat_mem_w_li = (v_tv_r & ~uncached_tv_r & ~fencei_op_tv_r)
    ? ~(load_miss_tv | store_miss_tv | lr_miss_tv)
    : stat_mem_pkt_v_i & (stat_mem_pkt.opcode != e_cache_stat_mem_read);
  assign stat_mem_addr_li = (v_tv_r & ~uncached_tv_r & ~fencei_op_tv_r)
    ? addr_index_tv
    : stat_mem_pkt.index;

  logic [way_id_width_lp-1:0] lru_decode_way_li;
  logic [dcache_assoc_p-2:0] lru_decode_data_lo;
  logic [dcache_assoc_p-2:0] lru_decode_mask_lo;

  bsg_lru_pseudo_tree_decode #(
    .ways_p(dcache_assoc_p)
  ) lru_decode (
    .way_id_i(lru_decode_way_li)
    ,.data_o(lru_decode_data_lo)
    ,.mask_o(lru_decode_mask_lo)
  );
  

  logic [way_id_width_lp-1:0] dirty_mask_way_li;
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
      lru_decode_way_li = store_op_tv_r ? store_hit_way : load_hit_way;
      dirty_mask_way_li = store_hit_way;
      dirty_mask_v_li = store_op_tv_r;
      
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
          stat_mem_data_li = {(stat_info_width_lp){1'b0}};
          stat_mem_mask_li = {(stat_info_width_lp){1'b1}};
        end
        e_cache_stat_mem_clear_dirty: begin
          stat_mem_data_li = {(stat_info_width_lp){1'b0}};
          stat_mem_mask_li.lru = {(dcache_assoc_p-1){1'b0}};
          stat_mem_mask_li.dirty = dirty_mask_lo;
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
  assign wbuf_v_li = v_tv_r & store_op_tv_r & store_hit & ~sc_fail & ~uncached_tv_r; 
  assign wbuf_yumi_li = wbuf_v_lo & ~(load_op & tl_we);
  assign bypass_v_li = tv_we & load_op_tl_r;

  // LCE data_mem
  //
  logic [way_id_width_lp-1:0] data_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (data_mem_pkt_v_i & (data_mem_pkt.opcode == e_cache_data_mem_read)) begin
      data_mem_pkt_way_r <= data_mem_pkt.way_id;
    end
  end

  bsg_mux_butterfly
   #(.width_p(bank_width_lp)
    ,.els_p(dcache_assoc_p))
    read_mux_butterfly
    (.data_i(data_mem_data_lo)
    ,.sel_i(data_mem_pkt_way_r)
    ,.data_o(lce_data_mem_data_li)
    );
  
  assign data_mem_o = lce_data_mem_data_li; 
  assign data_mem_pkt_ready = ~(load_op & tl_we) & ~wbuf_v_lo;

  // load reservation logic
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      load_reserved_v_r <= 1'b0;
    end
    else begin
      // The LR has successfully completed, without a cache miss or upgrade request
      if (lr_op_tv_r & v_o & ~lr_miss_tv) begin
        load_reserved_v_r     <= 1'b1;
        load_reserved_tag_r   <= paddr_tv_r[block_offset_width_lp+index_width_lp+:ptag_width_lp];
        load_reserved_index_r <= paddr_tv_r[block_offset_width_lp+:index_width_lp];
      // All SCs clear the reservation (regardless of success)
      end else if (sc_op_tv_r) begin
        load_reserved_v_r <= 1'b0;
      // Invalidates from other harts which match the reservation address clear the reservation
      end else if (tag_mem_pkt_v_i & (tag_mem_pkt.opcode == e_cache_tag_mem_invalidate)
                  & (tag_mem_pkt.tag == load_reserved_tag_r) 
                  & (tag_mem_pkt.index == load_reserved_index_r)) begin
        load_reserved_v_r <= 1'b0;
      end
    end
  end

  //  uncached load data logic
  //
  //synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      uncached_load_data_v_r <= 1'b0;
    end
    else begin
      if (data_mem_pkt_v_i & (data_mem_pkt.opcode == e_cache_data_mem_uncached)) begin
        uncached_load_data_r <= data_mem_pkt.data[0+:dword_width_p];
        uncached_load_data_v_r <= 1'b1;
      end
      else if (poison_i)
          uncached_load_data_v_r <= 1'b0;
      else begin
        // once uncached load request is replayed, and v_o goes high,
        // cleared the valid bit.
        if (v_o | fencei_v_o) begin
          uncached_load_data_v_r <= 1'b0;
        end
      end
    end
  end
  
  // LCE tag_mem
  
  logic [way_id_width_lp-1:0] tag_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (tag_mem_pkt_v_i & (tag_mem_pkt.opcode == e_cache_tag_mem_read)) begin
      tag_mem_pkt_way_r <= tag_mem_pkt.way_id;
    end
  end

  assign tag_mem_o =  tag_mem_data_lo[tag_mem_pkt_way_r].tag;

  assign tag_mem_pkt_ready = ~tl_we;
  
  // LCE stat_mem
  //
  assign stat_mem_pkt_ready = ~(v_tv_r & ~uncached_tv_r);

  logic [way_id_width_lp-1:0] stat_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (stat_mem_pkt_v_i & (stat_mem_pkt.opcode == e_cache_stat_mem_read)) begin
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
        else $error("multiple load hit: %b. id = %0d. addr = %H", load_hit_tv, cfg_bus_cast_i.dcache_id, addr_tag_tv);
      assert($countones(store_hit_tv) <= 1)
        else $error("multiple store hit: %b. id = %0d. addr = %H", store_hit_tv, cfg_bus_cast_i.dcache_id, addr_tag_tv);
      assert (~(sc_op_tv_r & load_reserved_v_r & (load_reserved_tag_r == addr_tag_tv) & (load_reserved_index_r == addr_index_tv)) | store_hit)
          else $error("sc success without exclusive ownership of cache line: %x %x", load_reserved_tag_r, load_reserved_index_r);
    end
  end

  initial begin
    assert(dword_width_p == 64) else $error("dword_width_p has to be 64");
    assert(dcache_assoc_p == 8 | dcache_assoc_p == 4 | dcache_assoc_p == 2) else $error("dcache_assoc_p has to be 8, 4 or 2");
  end
  // synopsys translate_on

endmodule
