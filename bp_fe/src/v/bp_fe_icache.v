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
 * Parameters:
 *
 * Inputs:
 *
 * Outputs:
 *
 * Keywords:
 *
 * Notes:
 *
 */


module icache
  import bp_common_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;  
  #(parameter eaddr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter inst_width_p="inv"
    , parameter tag_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter ways_p="inv"
    , parameter lce_sets_p="inv"
    , parameter block_size_in_bytes_p="inv"
    , localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    , localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , localparam data_mask_width_lp=(data_width_p>>3)
    , localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , localparam vaddr_width_lp=(lg_lce_sets_lp+lg_ways_lp+lg_data_mask_width_lp)
    , localparam addr_width_lp=(vaddr_width_lp+tag_width_p)
    , localparam lce_data_width_lp=(ways_p*data_width_p)
    , localparam cce_coh_bits_lp=`bp_cce_coh_bits
    , parameter debug_p=0

    , localparam bp_fe_pc_gen_icache_width_lp=`bp_fe_pc_gen_icache_width(eaddr_width_p)
    , localparam bp_fe_itlb_icache_data_resp_width_lp=`bp_fe_itlb_icache_data_resp_width(tag_width_p)

    , localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                              ,num_lce_p
                                                              ,addr_width_lp
                                                              ,ways_p
                                                             )
    , localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                                ,num_lce_p
                                                                ,addr_width_lp
                                                               )
    , localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                          ,num_lce_p
                                                                          ,addr_width_lp
                                                                          ,lce_data_width_lp
                                                                         )
    , localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                              ,num_lce_p
                                                              ,addr_width_lp
                                                              ,ways_p
                                                             )
    , localparam bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                        ,num_lce_p
                                                                        ,addr_width_lp
                                                                        ,lce_data_width_lp
                                                                        ,ways_p
                                                                       )
    , localparam bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                      ,addr_width_lp
                                                                      ,lce_data_width_lp
                                                                      ,ways_p
                                                                     )

    , localparam bp_fe_icache_tag_set_width_lp=`bp_fe_icache_tag_set_width(tag_width_p
                                                                          ,ways_p
                                                                         )
    , localparam bp_fe_icache_tag_state_width_lp=`bp_fe_icache_tag_state_width(tag_width_p)

    , localparam bp_fe_icache_metadata_width_lp=`bp_fe_icache_metadata_width(ways_p)

    , parameter bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(eaddr_width_p)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)
   )
   (
    input                                              clk_i
    , input                                            reset_i
    , input [lce_id_width_lp-1:0]                      id_i

    , input [bp_fe_pc_gen_icache_width_lp-1:0]         pc_gen_icache_vaddr_i
    , input                                            pc_gen_icache_vaddr_v_i
    , output logic                                     pc_gen_icache_vaddr_ready_o

    , output logic [bp_fe_icache_pc_gen_width_lp-1:0]  icache_pc_gen_data_o
    , output logic                                     icache_pc_gen_data_v_o
    , input                                            icache_pc_gen_data_ready_i // Not used

    , input [bp_fe_itlb_icache_data_resp_width_lp-1:0] itlb_icache_data_resp_i
    , input                                            itlb_icache_data_resp_v_i
    , output logic                                     itlb_icache_data_resp_ready_o

    , output logic                                     cache_miss_o
    , input                                            poison_i

    , output logic [bp_lce_cce_req_width_lp-1:0]       lce_req_o
    , output logic                                     lce_req_v_o
    , input                                            lce_req_ready_i

    , output logic [bp_lce_cce_resp_width_lp-1:0]      lce_resp_o
    , output logic                                     lce_resp_v_o
    , input                                            lce_resp_ready_i

    , output logic [bp_lce_cce_data_resp_width_lp-1:0] lce_data_resp_o     
    , output logic                                     lce_data_resp_v_o 
    , input                                            lce_data_resp_ready_i

    , input [bp_cce_lce_cmd_width_lp-1:0]              lce_cmd_i
    , input                                            lce_cmd_v_i
    , output logic                                     lce_cmd_ready_o

    , input [bp_cce_lce_data_cmd_width_lp-1:0]         lce_data_cmd_i
    , input                                            lce_data_cmd_v_i
    , output logic                                     lce_data_cmd_ready_o

    , input [bp_lce_lce_tr_resp_width_lp-1:0]          lce_tr_resp_i
    , input                                            lce_tr_resp_v_i
    , output logic                                     lce_tr_resp_ready_o

    , output logic [bp_lce_lce_tr_resp_width_lp-1:0]   lce_tr_resp_o
    , output logic                                     lce_tr_resp_v_o
    , input                                            lce_tr_resp_ready_i

 );

  // Suppress unused signal warnings
  wire unused0 = icache_pc_gen_data_ready_i;

  logic [lg_lce_sets_lp-1:0]            vaddr_index;
  logic [lg_block_size_in_bytes_lp-1:0] vaddr_offset;

  logic [ways_p-1:0]                    way_v; // valid bits of each way
  logic [lg_ways_lp-1:0]                way_invalid_index; // first invalid way
  logic                                 invalid_exist;

  logic [lg_ways_lp-1:0]                lru_way_li;

  logic                                 invalidate_cmd_v; // an invalidate command from CCE

  logic [lg_num_cce_lp-1:0]             cce_dst_r, cce_dst_n;
  logic [lg_num_lce_lp-1:0]             lce_dst_r, lce_dst_n;

  `declare_bp_fe_itlb_icache_data_resp_s(tag_width_p);
  bp_fe_itlb_icache_data_resp_s itlb_icache_data_resp_li;
  assign itlb_icache_data_resp_li = itlb_icache_data_resp_i;

  assign vaddr_index      = pc_gen_icache_vaddr_i[lg_block_size_in_bytes_lp
                                                  +lg_data_mask_width_lp
                                                  +:lg_lce_sets_lp];
  assign vaddr_offset     = pc_gen_icache_vaddr_i[lg_data_mask_width_lp+:lg_block_size_in_bytes_lp];
   
  // TL stage
  logic                      v_tl_r;
  logic                      tl_we;
  logic [vaddr_width_lp-1:0] vaddr_tl_r;
  logic [eaddr_width_p-1:0]  eaddr_tl_r;

  assign tl_we = pc_gen_icache_vaddr_v_i & pc_gen_icache_vaddr_ready_o & ~poison_i;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tl_r       <= 1'b0;
      vaddr_tl_r   <= '0;
      eaddr_tl_r   <= '0;
    end else begin
      v_tl_r       <= tl_we;
      if (tl_we) begin
        vaddr_tl_r <= pc_gen_icache_vaddr_i[vaddr_width_lp-1:0];
        eaddr_tl_r <= pc_gen_icache_vaddr_i;
      end
    end
  end

  // tag memory
  logic [bp_fe_icache_tag_set_width_lp-1:0] tag_mem_data_li;
  logic [lg_lce_sets_lp-1:0]                tag_mem_addr_li;
  logic                                     tag_mem_v_li;
  logic [bp_fe_icache_tag_set_width_lp-1:0] tag_mem_w_mask_li;
  logic                                     tag_mem_w_li;
  logic [bp_fe_icache_tag_set_width_lp-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(bp_fe_icache_tag_set_width_lp)
    ,.els_p(lce_sets_p)
  ) tag_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(tag_mem_data_li)
    ,.addr_i(tag_mem_addr_li)
    ,.v_i(~reset_i & tag_mem_v_li)
    ,.w_mask_i(tag_mem_w_mask_li)
    ,.w_i(tag_mem_w_li)
    ,.data_o(tag_mem_data_lo)
  );

  logic [ways_p-1:0][cce_coh_bits_lp-1:0] state_tl;
  logic [ways_p-1:0][tag_width_p-1:0]      tag_tl;

  for (genvar way = 0; way < ways_p; way++)
  begin: state_tag
    assign state_tl[way] = tag_mem_data_lo[(bp_fe_icache_tag_state_width_lp*way+tag_width_p)
                                              +:cce_coh_bits_lp];
    assign tag_tl[way]   = tag_mem_data_lo[(bp_fe_icache_tag_state_width_lp*way)+:tag_width_p];
  end

  // data memory
  logic [ways_p-1:0][data_width_p-1:0]                             data_mem_bank_data_li;
  logic [ways_p-1:0][lg_lce_sets_lp+lg_block_size_in_bytes_lp-1:0] data_mem_bank_addr_li;
  logic [ways_p-1:0]                                               data_mem_bank_v_li;
  logic [ways_p-1:0][data_mask_width_lp-1:0]                       data_mem_bank_w_mask_li;
  logic [ways_p-1:0]                                               data_mem_bank_w_li;
  logic [ways_p-1:0][data_width_p-1:0]                             data_mem_bank_data_lo;

  // data memory: banks
  for (genvar bank = 0; bank < ways_p; bank++)
  begin: data_mem_banks
    bsg_mem_1rw_sync_mask_write_byte #(
      .data_width_p(data_width_p)
      ,.els_p(lce_sets_p*ways_p) // same number of blocks and ways
    ) data_mem_bank (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(data_mem_bank_data_li[bank])
      ,.addr_i(data_mem_bank_addr_li[bank])
      ,.v_i(~reset_i & data_mem_bank_v_li[bank])
      ,.write_mask_i(data_mem_bank_w_mask_li[bank])
      ,.w_i(data_mem_bank_w_li[bank])
      ,.data_o(data_mem_bank_data_lo[bank])
    );
  end                                             

  assign itlb_icache_data_resp_ready_o = v_tl_r;
   
  // TV stage
  logic v_tv_r;
  logic tv_we;
  logic [addr_width_lp-1:0]                     addr_tv_r;
  logic [eaddr_width_p-1:0]                     eaddr_tv_r; 
  logic [ways_p-1:0][tag_width_p-1:0]      tag_tv_r;
  logic [ways_p-1:0][cce_coh_bits_lp-1:0] state_tv_r;
  logic [ways_p-1:0][data_width_p-1:0]     ld_data_tv_r;
  logic [tag_width_p-1:0]                       addr_tag_tv;
  logic [lg_lce_sets_lp-1:0]                    addr_index_tv;
  logic [lg_block_size_in_bytes_lp-1:0]         addr_block_offset_tv;

  assign tv_we = v_tl_r & ~poison_i & itlb_icache_data_resp_v_i;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tv_r       <= 1'b0;
      addr_tv_r    <= '0;
      eaddr_tv_r   <= '0;
      tag_tv_r     <= '0;
      state_tv_r   <= '0;
      ld_data_tv_r <= '0;
    end
    else begin
      v_tv_r <= tv_we;
      if (tv_we) begin
        addr_tv_r    <= {itlb_icache_data_resp_li.ppn, vaddr_tl_r};
        eaddr_tv_r   <= eaddr_tl_r ;
        tag_tv_r     <= tag_tl;
        state_tv_r   <= state_tl;
        ld_data_tv_r <= data_mem_bank_data_lo;
      end
    end
  end

  assign addr_tag_tv          = addr_tv_r[lg_data_mask_width_lp
                                          +lg_block_size_in_bytes_lp
                                          +lg_lce_sets_lp
                                          +:tag_width_p];
  assign addr_index_tv        = addr_tv_r[lg_data_mask_width_lp
                                          +lg_block_size_in_bytes_lp
                                          +:lg_lce_sets_lp];
  assign addr_block_offset_tv = addr_tv_r[lg_data_mask_width_lp+:lg_block_size_in_bytes_lp];

  //cache hit?
  logic [ways_p-1:0]          hit_v;
  logic [lg_ways_lp-1:0] hit_index;
  logic                       hit;
  logic                       miss_v;

  for (genvar i = 0; i < ways_p; i++)
  begin: tag_comp
    assign hit_v[i]   = (tag_tv_r[i] == addr_tag_tv) && (state_tv_r[i] != e_VI_I);
    assign way_v[i]   = (state_tv_r[i] != e_VI_I);
  end

  bsg_priority_encode #(
    .width_p(ways_p)
    ,.lo_to_hi_p(1)
  ) pe_load_hit (
    .i(hit_v)
    ,.v_o(hit)
    ,.addr_o(hit_index)
  );

  assign miss_v = ~hit & v_tv_r;

  // metadata memory
  logic [bp_fe_icache_metadata_width_lp-1:0] metadata_mem_data_li;
  logic [lg_lce_sets_lp-1:0]                  metadata_mem_addr_li;
  logic                                       metadata_mem_v_li;
  logic [bp_fe_icache_metadata_width_lp-1:0] metadata_mem_mask_li;
  logic                                       metadata_mem_w_li;
  logic [bp_fe_icache_metadata_width_lp-1:0] metadata_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(bp_fe_icache_metadata_width_lp)
    ,.els_p(lce_sets_p)
  ) metadata_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(metadata_mem_data_li)
    ,.addr_i(metadata_mem_addr_li)
    ,.v_i(~reset_i & metadata_mem_v_li)
    ,.w_mask_i(metadata_mem_mask_li)
    ,.w_i(metadata_mem_w_li)
    ,.data_o(metadata_mem_data_lo)
  );

  logic [ways_p-2:0] lru_bits;
  logic [lg_ways_lp-1:0] lru_encode;

  assign lru_bits = metadata_mem_data_lo;

  bp_be_dcache_lru_encode #(
    .ways_p(ways_p)
    ) lru_encoder (
    .lru_i(lru_bits)
    ,.way_id_o(lru_encode)
  );

  bsg_priority_encode #(
    .width_p(ways_p)
    ,.lo_to_hi_p(1)
  ) pe_invalid (
    .i(~way_v)
    ,.v_o(invalid_exist)
    ,.addr_o(way_invalid_index)
 );
   
  assign lru_way_li = invalid_exist
    ? way_invalid_index
    : lru_encode;

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, ways_p, lce_data_width_lp);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt;
  logic [ways_p-1:0][data_width_p-1:0]      data_mem_data_li;
  logic                                     data_mem_pkt_v_lo;
  logic                                     data_mem_pkt_yumi_li;

  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, ways_p, tag_width_p);
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt;
  logic                                     tag_mem_pkt_v_lo;
  logic                                     tag_mem_pkt_yumi_li;

  `declare_bp_fe_icache_lce_metadata_mem_pkt_s(lce_sets_p, ways_p);
  bp_fe_icache_lce_metadata_mem_pkt_s metadata_mem_pkt;
  logic                                     metadata_mem_pkt_v_lo;
  logic                                     metadata_mem_pkt_yumi_li;


  bp_fe_lce #(
   .data_width_p(data_width_p)
   ,.lce_data_width_p(lce_data_width_lp)
   ,.lce_addr_width_p(addr_width_lp)
   ,.lce_sets_p(lce_sets_p)
   ,.ways_p(ways_p)
   ,.tag_width_p(tag_width_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.block_size_in_bytes_p(block_size_in_bytes_p)
  ) lce (
   .clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.id_i(id_i)

   ,.ready_o(pc_gen_icache_vaddr_ready_o)
   ,.cache_miss_o(cache_miss_o)

   ,.miss_i(miss_v)
   ,.miss_addr_i(addr_tv_r)

   ,.data_mem_data_i(data_mem_data_li)
   ,.data_mem_pkt_o(data_mem_pkt)
   ,.data_mem_pkt_v_o(data_mem_pkt_v_lo)
   ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_li)

   ,.tag_mem_pkt_o(tag_mem_pkt)
   ,.tag_mem_pkt_v_o(tag_mem_pkt_v_lo)
   ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_li)

   ,.metadata_mem_pkt_v_o(metadata_mem_pkt_v_lo)
   ,.metadata_mem_pkt_o(metadata_mem_pkt)
   ,.lru_way_i(lru_way_li)
   ,.metadata_mem_pkt_yumi_i(metadata_mem_pkt_yumi_li)

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

   ,.lce_tr_resp_i(lce_tr_resp_i)
   ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
   ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)

   ,.lce_tr_resp_o(lce_tr_resp_o)
   ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
   ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)
  ); 

  // output stage
  assign icache_pc_gen_data_v_o = v_tv_r & (~miss_v) & (~reset_i);
  logic [data_width_p-1:0]   ld_data_way_picked;

  bsg_mux #(
    .width_p(data_width_p)
    ,.els_p(ways_p)
  ) data_set_select_mux (
    .data_i(ld_data_tv_r)
    ,.sel_i(hit_index ^ addr_block_offset_tv)
    ,.data_o(ld_data_way_picked)
  );

  logic                     lower_upper_sel;

  `declare_bp_fe_icache_pc_gen_s(eaddr_width_p);
  bp_fe_icache_pc_gen_s icache_pc_gen_data_lo;
  assign lower_upper_sel             = addr_tv_r[lg_data_mask_width_lp-1+:1];
  assign icache_pc_gen_data_lo.instr = lower_upper_sel
    ? ld_data_way_picked[inst_width_p+:inst_width_p]
    : ld_data_way_picked[inst_width_p-1:0];
  assign icache_pc_gen_data_lo.addr  = eaddr_tv_r;
  assign icache_pc_gen_data_o        = icache_pc_gen_data_lo;


  // data mem
  assign data_mem_bank_v_li = tl_we ? {ways_p{1'b1}} : {ways_p{data_mem_pkt_yumi_li}};
  assign data_mem_bank_w_li = {ways_p{(data_mem_pkt_yumi_li & data_mem_pkt.we)}};   

  logic [ways_p-1:0][data_width_p-1:0] data_mem_write_data;
  for (genvar i = 0; i < ways_p; i++) begin
    assign data_mem_bank_addr_li[i] = tl_we
      ? {vaddr_index, vaddr_offset}
      : {data_mem_pkt.index, data_mem_pkt.way_id ^ ((lg_data_mask_width_lp)'(i))};

    bsg_mux #(
      .els_p(ways_p)
      ,.width_p(data_width_p)
    ) data_mem_write_mux (
      .data_i(data_mem_pkt.data)
      ,.sel_i(data_mem_pkt.way_id ^ ((lg_data_mask_width_lp)'(i)))
      ,.data_o(data_mem_write_data[i])
    );

    assign data_mem_bank_data_li[i] = data_mem_write_data[i];
    assign data_mem_bank_w_mask_li[i] = {ways_p{1'b1}};
  end
   
  // tag_mem
  assign tag_mem_v_li = tl_we | tag_mem_pkt_yumi_li;
  assign tag_mem_w_li = ~tl_we & tag_mem_pkt_v_lo;
  assign tag_mem_addr_li = tl_we ? vaddr_index : tag_mem_pkt.index;

  always_comb begin
    case (tag_mem_pkt.opcode)
      e_tag_mem_set_clear: begin
        tag_mem_data_li    = '0;
        tag_mem_w_mask_li  = '1;
      end
      e_tag_mem_ivalidate: begin
        tag_mem_data_li    = '0;
        tag_mem_w_mask_li  = {{cce_coh_bits_lp}{1'b1}}<<{tag_mem_pkt.way_id*bp_fe_icache_tag_state_width_lp+tag_width_p};
      end
      e_tag_mem_set_tag: begin
         tag_mem_data_li   = {ways_p{tag_mem_pkt.state, tag_mem_pkt.tag}};
         tag_mem_w_mask_li = {{bp_fe_icache_tag_state_width_lp}{1'b1}}<<{tag_mem_pkt.way_id*bp_fe_icache_tag_state_width_lp};
      end
      default: begin
        tag_mem_data_li   = '0;
        tag_mem_w_mask_li = '0;
      end
    endcase
  end

  // metadata mem
  assign metadata_mem_v_li = v_tv_r | metadata_mem_pkt_yumi_li;
  assign metadata_mem_w_li = (v_tv_r & ~miss_v) | metadata_mem_pkt_yumi_li;
  assign metadata_mem_addr_li = v_tv_r ? addr_index_tv : metadata_mem_pkt.index;

  logic [lg_ways_lp-1:0] lru_decode_way_li;
  logic [ways_p-2:0] lru_decode_data_lo;
  logic [ways_p-2:0] lru_decode_mask_lo;

   bp_be_dcache_lru_decode #(
     .ways_p(ways_p)
   ) lru_decode (
     .way_id_i(lru_decode_way_li)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
   );

  always_comb begin
    if (v_tv_r) begin
      lru_decode_way_li     = hit_index;
      metadata_mem_data_li = lru_decode_data_lo;
      metadata_mem_mask_li = lru_decode_mask_lo;
    end else begin
      lru_decode_way_li = metadata_mem_pkt.way;

      case (metadata_mem_pkt.opcode)
        e_metadata_mem_set_clear: begin
          metadata_mem_data_li = {(ways_p-1){1'b0}};
          metadata_mem_mask_li = {(ways_p-1){1'b1}};
        end
        
        e_metadata_mem_set_lru: begin
          metadata_mem_data_li = ~lru_decode_data_lo;
          metadata_mem_mask_li = lru_decode_mask_lo;
        end

        default: begin
          metadata_mem_data_li = {(ways_p-1){1'b0}};
          metadata_mem_mask_li = {(ways_p-1){1'b0}};
        end
      endcase
    end
  end
   
  // LCE: data mem
  logic [lg_ways_lp-1:0] data_mem_pkt_way_r;
  always_ff @ (posedge clk_i) begin
    data_mem_pkt_way_r <= (data_mem_pkt_v_lo & data_mem_pkt_yumi_li)
      ? data_mem_pkt.way_id
      : data_mem_pkt_way_r;
  end

  for (genvar i = 0; i < ways_p; i++) begin
    bsg_mux #(
      .els_p(ways_p)
      ,.width_p(data_width_p)
    ) lce_data_mem_read_mux (
      .data_i(data_mem_bank_data_lo)
      ,.sel_i(data_mem_pkt_way_r ^ ((lg_ways_lp)'(i)))
      ,.data_o(data_mem_data_li[i])
    );
  end

  assign data_mem_pkt_yumi_li = data_mem_pkt_v_lo & ~tl_we;

  // LCE: tag_mem
  assign tag_mem_pkt_yumi_li = tag_mem_pkt_v_lo & ~tl_we;

  // LCE: metadata_mem
  assign metadata_mem_pkt_yumi_li = ~v_tv_r & metadata_mem_pkt_v_lo;

  // synopsys translate_off
  if (debug_p) begin
    bp_fe_icache_axe_trace_gen #(
      .addr_width_p(addr_width_lp)
      ,.data_width_p(inst_width_p)
    ) cc (
      .clk_i(clk_i)
      ,.id_i(id_i)
      ,.v_i(icache_pc_gen_data_v_o)
      ,.addr_i(addr_tv_r)
      ,.data_i(icache_pc_gen_data_o)
    );
  end
  // synopsys translate_on
   
endmodule
