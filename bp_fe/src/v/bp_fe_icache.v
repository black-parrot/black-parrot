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

`include "bsg_defines.v"
`include "bp_common_me_if.vh"
`include "bp_fe_icache.vh"
`include "bp_fe_pc_gen.vh"
`include "bp_fe_itlb.vh"

module icache
  import bp_common_pkg::*;
  #(parameter eaddr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter inst_width_p="inv"
    , parameter tag_width_p="inv"
    , parameter num_cce_p="inv"
    , parameter num_lce_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter lce_sets_p="inv"
    , parameter coh_states_p="inv"
    , parameter block_size_in_bytes_p="inv"
    , parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    , parameter lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_coh_states_lp=`BSG_SAFE_CLOG2(coh_states_p)
    , parameter lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , parameter data_mask_width_lp=(data_width_p>>3)
    , parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    , parameter lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    , parameter vaddr_width_lp=(lg_lce_sets_lp+lg_lce_assoc_lp+lg_data_mask_width_lp)
    , parameter addr_width_lp=(vaddr_width_lp+tag_width_p)
    , parameter lce_data_width_lp=(lce_assoc_p*data_width_p)
    , parameter debug_p=0

    , parameter bp_fe_pc_gen_icache_width_lp=`bp_fe_pc_gen_icache_width(eaddr_width_p)
    , parameter bp_fe_itlb_icache_width_lp=44

    , parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                              ,num_lce_p
                                                              ,addr_width_lp
                                                              ,lce_assoc_p
                                                             )
    , parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                                ,num_lce_p
                                                                ,addr_width_lp
                                                               )
    , parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                          ,num_lce_p
                                                                          ,addr_width_lp
                                                                          ,lce_data_width_lp
                                                                         )
    , parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                              ,num_lce_p
                                                              ,addr_width_lp
                                                              ,lce_assoc_p
                                                              ,coh_states_p
                                                             )
    , parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                        ,num_lce_p
                                                                        ,addr_width_lp
                                                                        ,lce_data_width_lp
                                                                        ,lce_assoc_p
                                                                       )
    , parameter bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                      ,addr_width_lp
                                                                      ,lce_data_width_lp
                                                                      ,lce_assoc_p
                                                                     )

    , localparam bp_fe_icache_tag_set_width_lp=`bp_fe_icache_tag_set_width(coh_states_p
                                                                          ,tag_width_p
                                                                          ,lce_assoc_p
                                                                         )
    , localparam bp_fe_icache_tag_state_width_lp=`bp_fe_icache_tag_state_width(coh_state_p
                                                                              ,tag_width_p
                                                                             )
    , localparam bp_fe_icache_meta_data_width_lp=`bp_fe_icache_meta_data_width(lce_assoc_p)

    , parameter bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(eaddr_width_p)

    , localparam lce_id_width_lp='bp_lce_id_width
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

    , input [bp_fe_itlb_icache_width_lp-1:0]           itlb_icache_data_resp_i
    , input                                            itlb_icache_data_resp_v_i
    , output logic                                     itlb_icache_data_resp_ready_o

    , output logic                                     cache_miss_o
    , input                                            poison_i

    , output logic [bp_lce_cce_req_width_lp-1:0]       lce_cce_req_o
    , output logic                                     lce_cce_req_v_o
    , input  logic                                     lce_cce_req_ready_i

    , output logic [bp_lce_cce_resp_width_lp-1:0]      lce_cce_resp_o
    , output logic                                     lce_cce_resp_v_o
    , input  logic                                     lce_cce_resp_ready_i

    , output logic [bp_lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o     
    , output logic                                     lce_cce_data_resp_v_o 
    , input                                            lce_cce_data_resp_ready_i

    , input [bp_cce_lce_cmd_width_lp-1:0]              cce_lce_cmd_i
    , input                                            cce_lce_cmd_v_i
    , output logic                                     cce_lce_cmd_ready_o

    , input [bp_cce_lce_data_cmd_width_lp-1:0]         cce_lce_data_cmd_i
    , input                                            cce_lce_data_cmd_v_i
    , output logic                                     cce_lce_data_cmd_ready_o

    , input [bp_lce_lce_tr_resp_width_lp-1:0]          lce_lce_tr_resp_i
    , input                                            lce_lce_tr_resp_v_i
    , output logic                                     lce_lce_tr_resp_ready_o

    , output logic [bp_lce_lce_tr_resp_width_lp-1:0]   lce_lce_tr_resp_o
    , output logic                                     lce_lce_tr_resp_v_o
    , input                                            lce_lce_tr_resp_ready_i

 );

  logic [lg_lce_sets_lp-1:0]            vaddr_index;
  logic [lg_block_size_in_bytes_lp-1:0] vaddr_offset;

  logic [lce_assoc_p-1:0]               assoc_v; // valid bits of each way
  logic [lg_lce_assoc_lp-1:0]           assoc_invalid_index; // first invalid way
  logic                                 invalid_exist;

  logic [lg_lce_assoc_lp-1:0]           lru_way_li;

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

  logic [lce_assoc_p-1:0][lg_coh_states_lp-1:0] state_tl;
  logic [lce_assoc_p-1:0][tag_width_p-1:0]      tag_tl;

  for (genvar assoc = 0; assoc < lce_assoc_p; assoc++)
  begin: state_tag
    assign state_tl[assoc] = tag_mem_data_lo[(bp_fe_icache_tag_state_width_lp*assoc+tag_width_p)
                                              +:lg_coh_states_lp];
    assign tag_tl[assoc]   = tag_mem_data_lo[(bp_fe_icache_tag_state_width_lp*assoc)+:tag_width_p];
  end

  // data memory
  logic [lce_assoc_p-1:0][data_width_p-1:0]                             data_mem_bank_data_li;
  logic [lce_assoc_p-1:0][lg_lce_sets_lp+lg_block_size_in_bytes_lp-1:0] data_mem_bank_addr_li;
  logic [lce_assoc_p-1:0]                                               data_mem_bank_v_li;
  logic [lce_assoc_p-1:0][data_mask_width_lp-1:0]                       data_mem_bank_w_mask_li;
  logic [lce_assoc_p-1:0]                                               data_mem_bank_w_li;
  logic [lce_assoc_p-1:0][data_width_p-1:0]                             data_mem_bank_data_lo;

  // data memory: banks
  for (genvar bank = 0; bank < lce_assoc_p; bank++)
  begin: data_mem_banks
    bsg_mem_1rw_sync_mask_write_byte #(
      .data_width_p(data_width_p)
      ,.els_p(lce_sets_p*lce_assoc_p) // same number of blocks and ways
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
  logic [lce_assoc_p-1:0][tag_width_p-1:0]      tag_tv_r;
  logic [lce_assoc_p-1:0][lg_coh_states_lp-1:0] state_tv_r;
  logic [lce_assoc_p-1:0][data_width_p-1:0]     ld_data_tv_r;
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
  logic [lce_assoc_p-1:0]     hit_v;
  logic [lg_lce_assoc_lp-1:0] hit_index;
  logic                       hit;
  logic                       miss_v;

  for (genvar i = 0; i < lce_assoc_p; i++)
  begin: tag_comp
    assign hit_v[i]   = (tag_tv_r[i] == addr_tag_tv) && (state_tv_r[i] != e_VI_I);
    assign assoc_v[i] = (state_tv_r[i] != e_VI_I);
  end

  bsg_priority_encode #(
    .width_p(lce_assoc_p)
    ,.lo_to_hi_p(1)
  ) pe_load_hit (
    .i(hit_v)
    ,.v_o(hit)
    ,.addr_o(hit_index)
  );

  assign miss_v = ~hit & v_tv_r;

  // meta_data memory
  logic [bp_fe_icache_meta_data_width_lp-1:0] meta_data_mem_data_li;
  logic [lg_lce_sets_lp-1:0]                  meta_data_mem_addr_li;
  logic                                       meta_data_mem_v_li;
  logic [bp_fe_icache_meta_data_width_lp-1:0] meta_data_mem_mask_li;
  logic                                       meta_data_mem_w_li;
  logic [bp_fe_icache_meta_data_width_lp-1:0] meta_data_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(bp_fe_icache_meta_data_width_lp)
    ,.els_p(lce_sets_p)
  ) meta_data_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(meta_data_mem_data_li)
    ,.addr_i(meta_data_mem_addr_li)
    ,.v_i(~reset_i & meta_data_mem_v_li)
    ,.w_mask_i(meta_data_mem_mask_li)
    ,.w_i(meta_data_mem_w_li)
    ,.data_o(meta_data_mem_data_lo)
  );

  logic [lce_assoc_p-2:0]     lru_bits;
  logic [lg_lce_assoc_lp-1:0] lru_encode;

  assign lru_bits = meta_data_mem_data_lo;

  bp_be_dcache_lru_encode #(
    .ways_p(lce_assoc_p)
    ) lru_encoder (
    .lru_i(lru_bits)
    ,.way_o(lru_encode)
  );

  bsg_priority_encode #(
    .width_p(lce_assoc_p)
    ,.lo_to_hi_p(1)
  ) pe_invalid (
    .i(~assoc_v)
    ,.v_o(invalid_exist)
    ,.addr_o(assoc_invalid_index)
 );
   
  assign lru_way_li = invalid_exist
    ? assoc_invalid_index
    : lru_encode;

  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, lce_data_width_lp);
  bp_fe_icache_lce_data_mem_pkt_s data_mem_pkt;
  logic [lce_assoc_p-1:0][data_width_p-1:0] data_mem_data_li;
  logic                                     data_mem_pkt_v_lo;
  logic                                     data_mem_pkt_yumi_li;

  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, coh_states_p, tag_width_p);
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt;
  logic                                     tag_mem_pkt_v_lo;
  logic                                     tag_mem_pkt_yumi_li;

  `declare_bp_fe_icache_lce_meta_data_mem_pkt_s(lce_sets_p, lce_assoc_p);
  bp_fe_icache_lce_meta_data_mem_pkt_s meta_data_mem_pkt;
  logic                                     meta_data_mem_pkt_v_lo;
  logic                                     meta_data_mem_pkt_yumi_li;


  bp_fe_lce #(
   .data_width_p(data_width_p)
   ,.lce_data_width_p(lce_data_width_lp)
   ,.lce_addr_width_p(addr_width_lp)
   ,.lce_sets_p(lce_sets_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.tag_width_p(tag_width_p)
   ,.coh_states_p(coh_states_p)
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

   ,.meta_data_mem_pkt_v_o(meta_data_mem_pkt_v_lo)
   ,.meta_data_mem_pkt_o(meta_data_mem_pkt)
   ,.lru_way_i(lru_way_li)
   ,.meta_data_mem_pkt_yumi_i(meta_data_mem_pkt_yumi_li)

   ,.lce_cce_req_o(lce_cce_req_o)
   ,.lce_cce_req_v_o(lce_cce_req_v_o)
   ,.lce_cce_req_ready_i(lce_cce_req_ready_i)

   ,.lce_cce_resp_o(lce_cce_resp_o)
   ,.lce_cce_resp_v_o(lce_cce_resp_v_o)
   ,.lce_cce_resp_ready_i(lce_cce_resp_ready_i)

   ,.lce_cce_data_resp_o(lce_cce_data_resp_o)
   ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v_o)
   ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_ready_i)

   ,.cce_lce_cmd_i(cce_lce_cmd_i)
   ,.cce_lce_cmd_v_i(cce_lce_cmd_v_i)
   ,.cce_lce_cmd_ready_o(cce_lce_cmd_ready_o)

   ,.cce_lce_data_cmd_i(cce_lce_data_cmd_i)
   ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
   ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_ready_o)

   ,.lce_lce_tr_resp_i(lce_lce_tr_resp_i)
   ,.lce_lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
   ,.lce_lce_tr_resp_ready_o(lce_lce_tr_resp_ready_o)

   ,.lce_lce_tr_resp_o(lce_lce_tr_resp_o)
   ,.lce_lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
   ,.lce_lce_tr_resp_ready_i(lce_lce_tr_resp_ready_i)
  ); 

  // output stage
  assign icache_pc_gen_data_v_o = v_tv_r & (~miss_v) & (~reset_i);
  logic [data_width_p-1:0]   ld_data_way_picked;

  bsg_mux #(
    .width_p(data_width_p)
    ,.els_p(lce_assoc_p)
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
  assign data_mem_bank_v_li = tl_we ? {lce_assoc_p{1'b1}} : {lce_assoc_p{data_mem_pkt_yumi_li}};
  assign data_mem_bank_w_li = {lce_assoc_p{(data_mem_pkt_yumi_li & data_mem_pkt.we)}};   

  logic [lce_assoc_p-1:0][data_width_p-1:0] data_mem_write_data;
  for (genvar i = 0; i < lce_assoc_p; i++) begin
    assign data_mem_bank_addr_li[i] = tl_we
      ? {vaddr_index, vaddr_offset}
      : {data_mem_pkt.index, data_mem_pkt.assoc ^ ((lg_data_mask_width_lp)'(i))};

    bsg_mux #(
      .els_p(lce_assoc_p)
      ,.width_p(data_width_p)
    ) data_mem_write_mux (
      .data_i(data_mem_pkt.data)
      ,.sel_i(data_mem_pkt.assoc ^ ((lg_data_mask_width_lp)'(i)))
      ,.data_o(data_mem_write_data[i])
    );

    assign data_mem_bank_data_li[i] = data_mem_write_data[i];
    assign data_mem_bank_w_mask_li[i] = {lce_assoc_p{1'b1}};
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
        tag_mem_w_mask_li  = {{lg_coh_states_lp}{1'b1}}<<{tag_mem_pkt.assoc*bp_fe_icache_tag_state_width_lp+tag_width_p};
      end
      e_tag_mem_set_tag: begin
         tag_mem_data_li   = {lce_assoc_p{tag_mem_pkt.state, tag_mem_pkt.tag}};
         tag_mem_w_mask_li = {{bp_fe_icache_tag_state_width_lp}{1'b1}}<<{tag_mem_pkt.assoc*bp_fe_icache_tag_state_width_lp};
      end
      default: begin
        tag_mem_data_li   = '0;
        tag_mem_w_mask_li = '0;
      end
    endcase
  end

  // meta_data mem
  assign meta_data_mem_v_li = v_tv_r | meta_data_mem_pkt_yumi_li;
  assign meta_data_mem_w_li = (v_tv_r & ~miss_v) | meta_data_mem_pkt_yumi_li;
  assign meta_data_mem_addr_li = v_tv_r ? addr_index_tv : meta_data_mem_pkt.index;

  logic [lg_lce_assoc_lp-1:0] lru_decode_way_li;
  logic [lce_assoc_p-2:0]     lru_decode_data_lo;
  logic [lce_assoc_p-2:0]     lru_decode_mask_lo;

   bp_be_dcache_lru_decode #(
     .ways_p(lce_assoc_p)
   ) lru_decode (
     .way_i(lru_decode_way_li)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
   );

  always_comb begin
    if (v_tv_r) begin
      lru_decode_way_li     = hit_index;
      meta_data_mem_data_li = lru_decode_data_lo;
      meta_data_mem_mask_li = lru_decode_mask_lo;
    end else begin
      lru_decode_way_li = meta_data_mem_pkt.way;

      case (meta_data_mem_pkt.opcode)
        e_meta_data_mem_set_clear: begin
          meta_data_mem_data_li = {(lce_assoc_p-1){1'b0}};
          meta_data_mem_mask_li = {(lce_assoc_p-1){1'b1}};
        end
        
        e_meta_data_mem_set_lru: begin
          meta_data_mem_data_li = ~lru_decode_data_lo;
          meta_data_mem_mask_li = lru_decode_mask_lo;
        end

        default: begin
          meta_data_mem_data_li = {(lce_assoc_p-1){1'b0}};
          meta_data_mem_mask_li = {(lce_assoc_p-1){1'b0}};
        end
      endcase
    end
  end
   
  // LCE: data mem
  logic [lg_lce_assoc_lp-1:0] data_mem_pkt_assoc_r;
  always_ff @ (posedge clk_i) begin
    data_mem_pkt_assoc_r <= (data_mem_pkt_v_lo & data_mem_pkt_yumi_li)
      ? data_mem_pkt.assoc
      : data_mem_pkt_assoc_r;
  end

  for (genvar i = 0; i < lce_assoc_p; i++) begin
    bsg_mux #(
      .els_p(lce_assoc_p)
      ,.width_p(data_width_p)
    ) lce_data_mem_read_mux (
      .data_i(data_mem_bank_data_lo)
      ,.sel_i(data_mem_pkt_assoc_r ^ ((lg_lce_assoc_lp)'(i)))
      ,.data_o(data_mem_data_li[i])
    );
  end

  assign data_mem_pkt_yumi_li = data_mem_pkt_v_lo & ~tl_we;

  // LCE: tag_mem
  assign tag_mem_pkt_yumi_li = tag_mem_pkt_v_lo & ~tl_we;

  // LCE: meta_data_mem
  assign meta_data_mem_pkt_yumi_li = ~v_tv_r & meta_data_mem_pkt_v_lo;

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
