/**
 *  bp_be_dcache.v
 */

`include "bp_be_dcache_pkt.vh"
`include "bp_be_dcache_lce_pkt.vh"

module bp_be_dcache
  import bp_be_dcache_pkg::*;
  import bp_be_dcache_lce_pkg::*;
  #(parameter lce_id_width_p="inv"
    ,parameter data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
   
    ,parameter debug_p=0 

    ,localparam data_mask_width_lp=(data_width_p>>3)
    ,localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,localparam vaddr_width_lp=(lg_sets_lp+lg_ways_lp+lg_data_mask_width_lp)
    ,localparam addr_width_lp=(vaddr_width_lp+tag_width_p)
    ,localparam lce_data_width_lp=(ways_p*data_width_p)
  
    ,localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(vaddr_width_lp, data_width_p)
    
    ,localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_lp, ways_p)
    ,localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_lp)
    ,localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp)
    ,localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_lp, ways_p, 4)
    ,localparam cce_lce_data_cmd_width_lp=
      `bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p)
    ,localparam lce_lce_tr_resp_width_lp=
      `bp_lce_lce_tr_resp_width(num_lce_p, addr_width_lp, lce_data_width_lp, ways_p)
  )
  (
    input clk_i
    ,input reset_i
    
    ,input [lce_id_width_p-1:0] id_i

    ,input [dcache_pkt_width_lp-1:0] dcache_pkt_i
    ,input v_i
    ,output logic ready_o

    ,output logic [data_width_p-1:0] data_o
    ,output logic v_o

    // TLB interface
    ,input tlb_miss_i
    ,input [tag_width_p-1:0] paddr_i

    // ctrl
    ,output logic cache_miss_o
    ,input poison_i

    // LCE-CCE interface
    ,output logic [lce_cce_req_width_lp-1:0] lce_cce_req_o
    ,output logic lce_cce_req_v_o
    ,input lce_cce_req_ready_i

    ,output logic [lce_cce_resp_width_lp-1:0] lce_cce_resp_o
    ,output logic lce_cce_resp_v_o
    ,input lce_cce_resp_ready_i

    ,output logic [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o
    ,output logic lce_cce_data_resp_v_o
    ,input lce_cce_data_resp_ready_i

    // CCE-LCE interface
    ,input [cce_lce_cmd_width_lp-1:0] cce_lce_cmd_i
    ,input cce_lce_cmd_v_i
    ,output logic cce_lce_cmd_ready_o

    ,input [cce_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_i
    ,input cce_lce_data_cmd_v_i
    ,output logic cce_lce_data_cmd_ready_o

    // LCE-LCE interface
    ,input [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_i
    ,input lce_lce_tr_resp_v_i
    ,output logic lce_lce_tr_resp_ready_o

    ,output logic [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_o
    ,output logic lce_lce_tr_resp_v_o
    ,input lce_lce_tr_resp_ready_i 
  );

  // packet decoding
  //
  `declare_bp_be_dcache_pkt_s(vaddr_width_lp, data_width_p);
  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = dcache_pkt_i;

  logic load_op;
  logic store_op;
  logic signed_op;
  logic double_op;
  logic word_op;
  logic half_op;
  logic byte_op;
  logic [lg_sets_lp-1:0] vaddr_index;
  logic [lg_ways_lp-1:0] vaddr_block_offset;

  assign load_op = ~dcache_pkt.opcode[3];
  assign store_op = dcache_pkt.opcode[3];
  assign signed_op = ~dcache_pkt.opcode[2];
  assign double_op = (dcache_pkt.opcode[1:0] == 2'b11);
  assign word_op = (dcache_pkt.opcode[1:0] == 2'b10);
  assign half_op = (dcache_pkt.opcode[1:0] == 2'b01);
  assign byte_op = (dcache_pkt.opcode[1:0] == 2'b00);
  assign vaddr_index = dcache_pkt.vaddr[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp];
  assign vaddr_block_offset = dcache_pkt.vaddr[lg_data_mask_width_lp+:lg_ways_lp];
  
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
  logic [vaddr_width_lp-1:0] vaddr_tl_r;
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
        vaddr_tl_r <= dcache_pkt.vaddr;
      end
    
      if (tl_we & store_op) begin
        data_tl_r <= dcache_pkt.data;
      end
    end
  end 
 
  // tag_mem
  //
  logic tag_mem_v_li;
  logic tag_mem_w_li;
  logic [lg_sets_lp-1:0] tag_mem_addr_li;
  logic [ways_p-1:0][(tag_width_p+2)-1:0] tag_mem_data_li;
  logic [ways_p-1:0][(tag_width_p+2)-1:0] tag_mem_mask_li;
  logic [ways_p-1:0][(tag_width_p+2)-1:0] tag_mem_data_lo;
  logic [ways_p-1:0][tag_width_p-1:0] tag_tl;
  logic [ways_p-1:0][1:0] coh_tl;
  
  // tag_mem width: (tag_width_p + 2) +  ways_p
  // it contains coherence states and associated tags for each way in sets.
  // {coh_state[n], tag[n], coh_state[n-1], tag[n-1], ... , coh_state[0], tag[0]}
  //
  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p((tag_width_p+2)*ways_p)
    ,.els_p(sets_p)
  ) tag_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.v_i(~reset_i & tag_mem_v_li)
    ,.w_i(tag_mem_w_li)
    ,.addr_i(tag_mem_addr_li)
    ,.data_i(tag_mem_data_li)
    ,.w_mask_i(tag_mem_mask_li)
    ,.data_o(tag_mem_data_lo)
  );

  for (genvar i = 0; i < ways_p; i++) begin
    assign tag_tl[i] = tag_mem_data_lo[i][0+:tag_width_p];
    assign coh_tl[i] = tag_mem_data_lo[i][tag_width_p+:2];
  end

  // data_mem
  //
  logic [ways_p-1:0] data_mem_v_li;
  logic [ways_p-1:0] data_mem_w_li;
  logic [ways_p-1:0][lg_sets_lp+lg_ways_lp-1:0] data_mem_addr_li;
  logic [ways_p-1:0][data_width_p-1:0] data_mem_data_li;
  logic [ways_p-1:0][data_mask_width_lp-1:0] data_mem_mask_li;
  logic [ways_p-1:0][data_width_p-1:0] data_mem_data_lo;
  
  for (genvar i = 0; i < ways_p; i++) begin
    bsg_mem_1rw_sync_mask_write_byte #(
      .data_width_p(data_width_p)
      ,.els_p(sets_p*ways_p)
    ) data_mem (
      .clk_i(clk_i)
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
  logic [addr_width_lp-1:0] addr_tv_r;
  logic [data_width_p-1:0] data_tv_r;
  logic [ways_p-1:0][tag_width_p-1:0] tag_tv_r;
  logic [ways_p-1:0][1:0] coh_tv_r;
  logic [ways_p-1:0][data_width_p-1:0] ld_data_tv_r;
  logic [tag_width_p-1:0] addr_tag_tv;
  logic [lg_sets_lp-1:0] addr_index_tv;
  logic [lg_ways_lp-1:0] addr_block_offset_tv;

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
        addr_tv_r <= {paddr_i, vaddr_tl_r};
        tag_tv_r <= tag_tl;
        coh_tv_r <= coh_tl;
      end

      if (tv_we & load_op_tl_r) begin
        ld_data_tv_r <= data_mem_data_lo;
      end

      if (tv_we & store_op_tl_r) begin
        data_tv_r <= data_tl_r;
      end
    end
  end

  assign addr_tag_tv = addr_tv_r[lg_data_mask_width_lp+lg_ways_lp+lg_sets_lp+:tag_width_p];
  assign addr_index_tv = addr_tv_r[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp];
  assign addr_block_offset_tv = addr_tv_r[lg_data_mask_width_lp+:lg_ways_lp];

  // miss_detect
  //
  logic [ways_p-1:0] load_hit_tv;
  logic [ways_p-1:0] store_hit_tv;
  logic [ways_p-1:0] invalid_tv;
  logic load_miss_tv;
  logic store_miss_tv;
  logic load_hit;
  logic store_hit;
  logic [lg_ways_lp-1:0] load_hit_way;
  logic [lg_ways_lp-1:0] store_hit_way;

  for (genvar i = 0; i < ways_p; i++) begin
    assign load_hit_tv[i] = (addr_tag_tv == tag_tv_r[i]) & (coh_tv_r[i] != e_MESI_I);
    assign store_hit_tv[i] = (addr_tag_tv == tag_tv_r[i]) & (coh_tv_r[i] == e_MESI_E);
    assign invalid_tv[i] = (coh_tv_r[i] == e_MESI_I);
  end

  bsg_priority_encode #(
    .width_p(ways_p)
    ,.lo_to_hi_p(1)
  ) pe_load_hit (
    .i(load_hit_tv)
    ,.v_o(load_hit)
    ,.addr_o(load_hit_way)
  );
  
  bsg_priority_encode #(
    .width_p(ways_p)
    ,.lo_to_hi_p(1)
  ) pe_store_hit (
    .i(store_hit_tv)
    ,.v_o(store_hit)
    ,.addr_o(store_hit_way)
  );

  assign load_miss_tv = ~load_hit & v_tv_r & load_op_tv_r;
  assign store_miss_tv = ~store_hit & v_tv_r & store_op_tv_r;


  // write buffer
  //
  logic wbuf_v_li;
  logic [data_width_p-1:0] wbuf_data_li;
  logic [data_mask_width_lp-1:0] wbuf_mask_li;
  logic [lg_ways_lp-1:0] wbuf_way_li;
  
  logic wbuf_v_lo;
  logic [addr_width_lp-1:0] wbuf_addr_lo;
  logic [data_width_p-1:0] wbuf_data_lo;
  logic [data_mask_width_lp-1:0] wbuf_mask_lo;
  logic [lg_ways_lp-1:0] wbuf_way_lo;
  logic wbuf_yumi_li;
  
  logic wbuf_empty_lo;
  
  logic bypass_v_li;
  logic bypass_addr_li;
  logic [data_width_p-1:0] bypass_data_lo;
  logic [data_mask_width_lp-1:0] bypass_mask_lo;

  logic [lg_sets_lp-1:0] lce_snoop_index_li;
  logic [lg_ways_lp-1:0] lce_snoop_way_li;
  logic lce_snoop_match_lo; 
 
  bp_be_dcache_wbuf #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_lp)
    ,.ways_p(ways_p)
    ,.sets_p(sets_p)
  ) wbuf (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(wbuf_v_li)
    ,.addr_i(addr_tv_r)
    ,.data_i(wbuf_data_li)
    ,.mask_i(wbuf_mask_li)
    ,.way_i(store_hit_way)

    ,.v_o(wbuf_v_lo)
    ,.addr_o(wbuf_addr_lo)
    ,.data_o(wbuf_data_lo)
    ,.mask_o(wbuf_mask_lo)
    ,.way_o(wbuf_way_lo)
    ,.yumi_i(wbuf_yumi_li)

    ,.empty_o(wbuf_empty_lo)
    
    ,.bypass_v_i(bypass_v_li)
    ,.bypass_addr_i({paddr_i, vaddr_tl_r})
    ,.bypass_data_o(bypass_data_lo)
    ,.bypass_mask_o(bypass_mask_lo)

    ,.lce_snoop_index_i(lce_snoop_index_li)
    ,.lce_snoop_way_i(lce_snoop_way_li)
    ,.lce_snoop_match_o(lce_snoop_match_lo)
  );

  logic [lg_ways_lp-1:0] wbuf_addr_lo_block_offset;
  logic [lg_sets_lp-1:0] wbuf_addr_lo_index;
  assign wbuf_addr_lo_block_offset = wbuf_addr_lo[lg_data_mask_width_lp+:lg_ways_lp];
  assign wbuf_addr_lo_index = wbuf_addr_lo[lg_data_mask_width_lp+lg_ways_lp+:lg_sets_lp];

  if (data_width_p == 64) begin
    assign wbuf_data_li = double_op_tv_r
      ? data_tv_r
      : (word_op_tv_r
        ? {2{data_tv_r[0+:32]}}
        : (half_op_tv_r
          ? {4{data_tv_r[0+:16]}}
          : {8{data_tv_r[0+:8]}}));

    assign wbuf_mask_li = double_op_tv_r
      ? 8'b1111_1111
      : (word_op_tv_r
        ? {{4{addr_tv_r[2]}}, {4{~addr_tv_r[2]}}}
        : (half_op_tv_r
          ? {{2{addr_tv_r[2] & addr_tv_r[1]}}, {2{addr_tv_r[2] & ~addr_tv_r[1]}},
             {2{~addr_tv_r[2] & addr_tv_r[1]}}, {2{~addr_tv_r[2] & ~addr_tv_r[1]}}}
          : {(addr_tv_r[2] & addr_tv_r[1] & addr_tv_r[0]), 
             (addr_tv_r[2] & addr_tv_r[1] & ~addr_tv_r[0]),
             (addr_tv_r[2] & ~addr_tv_r[1] & addr_tv_r[0]),
             (addr_tv_r[2] & ~addr_tv_r[1] & ~addr_tv_r[0]),
             (~addr_tv_r[2] & addr_tv_r[1] & addr_tv_r[0]),
             (~addr_tv_r[2] & addr_tv_r[1] & ~addr_tv_r[0]),
             (~addr_tv_r[2] & ~addr_tv_r[1] & addr_tv_r[0]),
             (~addr_tv_r[2] & ~addr_tv_r[1] & ~addr_tv_r[0])
            }));
  end

  // stat_mem {lru, dirty}
  //
  logic stat_mem_v_li;
  logic stat_mem_w_li;
  logic [lg_sets_lp-1:0] stat_mem_addr_li;
  logic [(2*ways_p)-2:0] stat_mem_data_li;
  logic [(2*ways_p)-2:0] stat_mem_mask_li;
  logic [(2*ways_p)-2:0] stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p((2*ways_p)-1)
    ,.els_p(sets_p)
  ) stat_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.v_i(~reset_i & stat_mem_v_li)
    ,.w_i(stat_mem_w_li)
    ,.addr_i(stat_mem_addr_li)
    ,.data_i(stat_mem_data_li)
    ,.w_mask_i(stat_mem_mask_li)
    ,.data_o(stat_mem_data_lo)
  );
  
  logic [ways_p-1:0] lce_dirty_li;
  logic [ways_p-2:0] lru_bits;
  logic [lg_ways_lp-1:0] lru_encode;
  assign lce_dirty_li = stat_mem_data_lo[ways_p-1:0];
  assign lru_bits = stat_mem_data_lo[ways_p+:ways_p-1];

  bp_be_dcache_lru_encode #(
    .ways_p(8)
  ) lru_encoder (
    .lru_i(lru_bits)
    ,.way_o(lru_encode)
  );


  logic invalid_exist;
  logic [lg_ways_lp-1:0] invalid_way;
  bsg_priority_encode #(
    .width_p(ways_p)
    ,.lo_to_hi_p(1)
  ) pe_invalid (
    .i(invalid_tv)
    ,.v_o(invalid_exist)
    ,.addr_o(invalid_way)
  );

  // if there is invalid way, then it take prioirty over LRU way.
  logic [lg_ways_lp-1:0] lce_lru_way_li;
  assign lce_lru_way_li = invalid_exist ? invalid_way : lru_encode;
 
  // LCE
  //
  `declare_bp_be_dcache_lce_data_mem_pkt_s(sets_p, ways_p, data_width_p*ways_p);
  `declare_bp_be_dcache_lce_tag_mem_pkt_s(sets_p, ways_p, tag_width_p);
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
 
  bp_be_dcache_lce #(
    .lce_id_width_p(lce_id_width_p)
    ,.data_width_p(data_width_p)
    ,.lce_data_width_p(ways_p*data_width_p)
    ,.lce_addr_width_p(addr_width_lp)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.tag_width_p(tag_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
  ) lce (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.id_i(id_i)

    ,.ready_o(ready_o)
    ,.cache_miss_o(cache_miss_o)

    ,.load_miss_i(load_miss_tv)
    ,.store_miss_i(store_miss_tv)
    ,.miss_addr_i(addr_tv_r)

    // data_mem
    ,.data_mem_pkt_v_o(lce_data_mem_pkt_v_lo)
    ,.data_mem_pkt_o(lce_data_mem_pkt)
    ,.data_mem_data_i(lce_data_mem_data_li)
    ,.data_mem_pkt_yumi_i(lce_data_mem_pkt_yumi_li)

    // tag_mem
    ,.tag_mem_pkt_v_o(lce_tag_mem_pkt_v_lo)
    ,.tag_mem_pkt_o(lce_tag_mem_pkt)
    ,.tag_mem_pkt_yumi_i(lce_tag_mem_pkt_yumi_li)

    // stat_mem
    ,.stat_mem_pkt_v_o(lce_stat_mem_pkt_v_lo)
    ,.stat_mem_pkt_o(lce_stat_mem_pkt)
    ,.dirty_i(lce_dirty_li)
    ,.lru_way_i(lce_lru_way_li)
    ,.stat_mem_pkt_yumi_i(lce_stat_mem_pkt_yumi_li)
  
    // LCE-CCE interface 
    ,.lce_cce_req_o(lce_cce_req_o)
    ,.lce_cce_req_v_o(lce_cce_req_v_o)
    ,.lce_cce_req_ready_i(lce_cce_req_ready_i)

    ,.lce_cce_resp_o(lce_cce_resp_o)
    ,.lce_cce_resp_v_o(lce_cce_resp_v_o)
    ,.lce_cce_resp_ready_i(lce_cce_resp_ready_i)

    ,.lce_cce_data_resp_o(lce_cce_data_resp_o)
    ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v_o)
    ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_ready_i)

    // CCE-LCE interface
    ,.cce_lce_cmd_i(cce_lce_cmd_i)
    ,.cce_lce_cmd_v_i(cce_lce_cmd_v_i)
    ,.cce_lce_cmd_ready_o(cce_lce_cmd_ready_o)

    ,.cce_lce_data_cmd_i(cce_lce_data_cmd_i)
    ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
    ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_ready_o)

    // LCE-LCE interface
    ,.lce_lce_tr_resp_i(lce_lce_tr_resp_i)
    ,.lce_lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
    ,.lce_lce_tr_resp_ready_o(lce_lce_tr_resp_ready_o)

    ,.lce_lce_tr_resp_o(lce_lce_tr_resp_o)
    ,.lce_lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
    ,.lce_lce_tr_resp_ready_i(lce_lce_tr_resp_ready_i)
  );
 
  // output stage
  //
  assign v_o = v_tv_r & ~(load_miss_tv | store_miss_tv) & (~reset_i); 

  logic [data_width_p-1:0] ld_data_way_picked;
  logic [data_width_p-1:0] bypass_data_masked;

  bsg_mux #(
    .width_p(data_width_p)
    ,.els_p(ways_p)
  ) ld_data_set_select_mux (
    .data_i(ld_data_tv_r)
    ,.sel_i(load_hit_way ^ addr_block_offset_tv)
    ,.data_o(ld_data_way_picked)
  );

  bsg_mux_segmented #(
    .segments_p(data_mask_width_lp)
    ,.segment_width_p(8)
  ) bypass_mux_segmented (
    .data0_i(ld_data_way_picked)
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
    
    bsg_mux #(
      .width_p(32)
      ,.els_p(2)
    ) word_mux (
      .data_i(bypass_data_masked)
      ,.sel_i(addr_tv_r[2])
      ,.data_o(data_word_selected)
    );
    
    bsg_mux #(
      .width_p(16)
      ,.els_p(4)
    ) half_mux (
      .data_i(bypass_data_masked)
      ,.sel_i(addr_tv_r[2:1])
      ,.data_o(data_half_selected)
    );

    bsg_mux #(
      .width_p(8)
      ,.els_p(8)
    ) byte_mux (
      .data_i(bypass_data_masked)
      ,.sel_i(addr_tv_r[2:0])
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
  bsg_decode #(
    .num_out_p(ways_p)
  ) wbuf_data_mem_v_decode (
    .i(wbuf_way_lo ^ wbuf_addr_lo_block_offset)
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
      ? {vaddr_index, vaddr_block_offset}
      : (wbuf_yumi_li
        ? {wbuf_addr_lo_index}
        : {lce_data_mem_pkt.index, lce_data_mem_pkt.way ^ ((lg_data_mask_width_lp)'(i))});

    bsg_mux #(
      .els_p(ways_p)
      ,.width_p(data_width_p)
    ) lce_data_mem_write_mux (
      .data_i(lce_data_mem_pkt.data)
      ,.sel_i(lce_data_mem_pkt.way ^ ((lg_data_mask_width_lp)'(i)))
      ,.data_o(lce_data_mem_write_data[i])
    );

    assign data_mem_data_li[i] = wbuf_yumi_li
      ? wbuf_data_lo
      : lce_data_mem_write_data[i];
  
    assign data_mem_mask_li[i] = wbuf_yumi_li
      ? wbuf_mask_lo
      : {ways_p{1'b1}};
  end
 
  // tag_mem
  //
  assign tag_mem_v_li = tl_we | lce_tag_mem_pkt_yumi_li; 
  assign tag_mem_w_li = ~tl_we & lce_tag_mem_pkt_v_lo;
  assign tag_mem_addr_li = tl_we 
    ? vaddr_index
    : lce_tag_mem_pkt.index;

  logic [ways_p-1:0] lce_tag_mem_way_one_hot;
  bsg_decode #(
    .num_out_p(ways_p)
  ) lce_tag_mem_way_decode (
    .i(lce_tag_mem_pkt.way)
    ,.o(lce_tag_mem_way_one_hot)
  );

  always_comb begin
    case (lce_tag_mem_pkt.opcode)
      e_dcache_lce_tag_mem_set_clear: begin
        tag_mem_data_li = {((tag_width_p+2)*ways_p){1'b0}};
        tag_mem_mask_li = {((tag_width_p+2)*ways_p){1'b1}};
      end
      e_dcache_lce_tag_mem_invalidate: begin
        tag_mem_data_li = {((tag_width_p+2)*ways_p){1'b0}};
        for (integer i = 0; i < ways_p; i++) begin
          tag_mem_mask_li[i] = {{2{lce_tag_mem_way_one_hot[i]}}, {tag_width_p{1'b0}}};
        end
      end
      e_dcache_lce_tag_mem_set_tag: begin
        tag_mem_data_li = {ways_p{lce_tag_mem_pkt.state, lce_tag_mem_pkt.tag}};
        for (integer i = 0; i < ways_p; i++) begin
          tag_mem_mask_li[i] = {(2+tag_width_p){lce_tag_mem_way_one_hot[i]}};
        end
      end
      default: begin
        tag_mem_data_li = {((tag_width_p+2)*ways_p){1'b0}};
        tag_mem_mask_li = {((tag_width_p+2)*ways_p){1'b0}};
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

  logic [lg_ways_lp-1:0] lru_decode_way_li;
  logic [ways_p-2:0] lru_decode_data_lo;
  logic [ways_p-2:0] lru_decode_mask_lo;

  bp_be_dcache_lru_decode #(
    .ways_p(ways_p)
  ) lru_decode (
    .way_i(lru_decode_way_li)
    ,.data_o(lru_decode_data_lo)
    ,.mask_o(lru_decode_mask_lo)
  );

  logic [lg_ways_lp-1:0] dirty_mask_way_li;
  logic dirty_mask_v_li;
  logic [ways_p-1:0] dirty_mask_lo;

  bsg_decode_with_v #(
    .num_out_p(ways_p)
  ) dirty_mask_decode (
    .i(dirty_mask_way_li)
    ,.v_i(dirty_mask_v_li)
    ,.o(dirty_mask_lo)
  );

  always_comb begin
    if (v_tv_r) begin
      lru_decode_way_li = store_op_tv_r ? store_hit_way : load_hit_way;
      dirty_mask_way_li = store_hit_way;
      dirty_mask_v_li = store_op_tv_r;
      
      stat_mem_data_li = {lru_decode_data_lo, {ways_p{1'b1}}};
      stat_mem_mask_li = {lru_decode_mask_lo, dirty_mask_lo};
    end
    else begin
      lru_decode_way_li = lce_stat_mem_pkt.way;
      dirty_mask_way_li = lce_stat_mem_pkt.way;
      dirty_mask_v_li = 1'b1;
      case (lce_stat_mem_pkt.opcode)
        e_dcache_lce_stat_mem_set_clear: begin
          stat_mem_data_li = {(2*ways_p-1){1'b0}};
          stat_mem_mask_li = {(2*ways_p-1){1'b1}};
        end
        e_dcache_lce_stat_mem_clear_dirty: begin
          stat_mem_data_li = {(2*ways_p-1){1'b0}};
          stat_mem_mask_li = {{(ways_p-1){1'b0}}, dirty_mask_lo};
        end
        e_dcache_lce_stat_mem_set_lru: begin
          stat_mem_data_li = {~lru_decode_data_lo, {ways_p{1'b0}}};
          stat_mem_mask_li = {lru_decode_mask_lo, {ways_p{1'b0}}};
        end
        default: begin
          stat_mem_data_li = {(2*ways_p-1){1'b0}};
          stat_mem_mask_li = {(2*ways_p-1){1'b0}};
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
  assign lce_snoop_way_li = lce_data_mem_pkt.way;

  // LCE data_mem
  //
  logic [lg_ways_lp-1:0] lce_data_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (lce_data_mem_pkt_v_lo & lce_data_mem_pkt_yumi_li & ~lce_data_mem_pkt.write_not_read) begin
      lce_data_mem_pkt_way_r <= lce_data_mem_pkt.way;
    end
  end

  for (genvar i = 0; i < ways_p; i++) begin
    bsg_mux #(
      .els_p(ways_p)
      ,.width_p(data_width_p)
    ) lce_data_mem_read_mux (
      .data_i(data_mem_data_lo)
      ,.sel_i(lce_data_mem_pkt_way_r ^ ((lg_ways_lp)'(i)))
      ,.data_o(lce_data_mem_data_li[i])
    );
  end

  assign lce_data_mem_pkt_yumi_li = ~(load_op & tl_we) & ~wbuf_v_lo & ~lce_snoop_match_lo & lce_data_mem_pkt_v_lo;
  
  // LCE tag_mem
  //
  assign lce_tag_mem_pkt_yumi_li = lce_tag_mem_pkt_v_lo & ~tl_we;
  
  // LCE stat_mem
  //
  assign lce_stat_mem_pkt_yumi_li = ~v_tv_r & lce_stat_mem_pkt_v_lo;

  // synopsys translate_off
  if (debug_p) begin
    bp_be_dcache_axe_trace_gen #(
      .addr_width_p(addr_width_lp)
      ,.data_width_p(data_width_p)
    ) cc (
      .clk_i(clk_i)
      ,.id_i(id_i)
      ,.v_i(v_o)
      ,.addr_i(addr_tv_r)
      ,.load_data_i(data_o)
      ,.store_data_i(data_tv_r)
      ,.load_i(load_op_tv_r)
      ,.store_i(store_op_tv_r)
    );
  end

  always_ff @ (negedge clk_i) begin
    if (v_tv_r) begin
      assert($countones(load_hit_tv) <= 1) else $error("multiple load hit: %b. id = %0d", load_hit_tv, id_i);
      assert($countones(store_hit_tv) <= 1) else $error("multiple store hit: %b. id = %0d", store_hit_tv, id_i);
    end
  end

  initial begin
    assert(data_width_p == 64) else $error("data_width_p has to be 64").
    assert(ways_p == 8) else $error("ways_p has to be 8").
  end
  // synopsys translate_on

endmodule
