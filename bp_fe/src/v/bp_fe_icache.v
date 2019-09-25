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
 */


module bp_fe_icache
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;  
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_fe_tag_widths(lce_assoc_p, lce_sets_p, num_lce_p, num_cce_p, dword_width_p, paddr_width_p)
    `declare_bp_icache_widths(vaddr_width_p, tag_width_lp, lce_assoc_p) 

    , parameter debug_p=0
    )
   (input                                              clk_i
    , input                                            reset_i
    , input                                            freeze_i

    , input [lce_id_width_lp-1:0]                      lce_id_i

    // Config channel
    , input                                            cfg_w_v_i
    , input [cfg_addr_width_p-1:0]                     cfg_addr_i
    , input [cfg_data_width_p-1:0]                     cfg_data_i

    , input [vaddr_width_p-1:0]                        vaddr_i
    , input                                            vaddr_v_i
    , output                                           vaddr_ready_o

    , input [ptag_width_p-1:0]                         ptag_i
    , input                                            ptag_v_i
    , input                                            uncached_i
    , input                                            poison_tl_i
    
    , output [instr_width_p-1:0]                       data_o
    , output                                           data_v_o
    , output                                           instr_access_fault_o
    , output                                           cache_miss_o

    , output [lce_cce_req_width_lp-1:0]                lce_req_o
    , output                                           lce_req_v_o
    , input                                            lce_req_ready_i

    , output [lce_cce_resp_width_lp-1:0]               lce_resp_o
    , output                                           lce_resp_v_o
    , input                                            lce_resp_ready_i

    , input [lce_cmd_width_lp-1:0]                     lce_cmd_i
    , input                                            lce_cmd_v_i
    , output                                           lce_cmd_ready_o

    , output [lce_cmd_width_lp-1:0]                    lce_cmd_o
    , output                                           lce_cmd_v_o
    , input                                            lce_cmd_ready_i 
 );

  logic [index_width_lp-1:0]            vaddr_index;

  logic [word_offset_width_lp-1:0] vaddr_offset;

  logic [lce_assoc_p-1:0]               way_v; // valid bits of each way
  logic [way_id_width_lp-1:0]           way_invalid_index; // first invalid way
  logic                                 invalid_exist;

  logic                                 invalidate_cmd_v; // an invalidate command from CCE

  assign vaddr_index      = vaddr_i[word_offset_width_lp
                                       +byte_offset_width_lp
                                       +:index_width_lp];
  assign vaddr_offset     = vaddr_i[byte_offset_width_lp+:word_offset_width_lp];
   
  // TL stage
  logic v_tl_r;
  logic tl_we;
  logic [bp_page_offset_width_gp-1:0] page_offset_tl_r;
  logic [vaddr_width_p-1:0]           vaddr_tl_r;

  assign tl_we = vaddr_v_i; 

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tl_r       <= 1'b0;
    end else begin
      v_tl_r       <= tl_we;
      if (tl_we) begin
        page_offset_tl_r <= vaddr_i[bp_page_offset_width_gp-1:0];
        vaddr_tl_r       <= vaddr_i;
      end
    end
  end

  // tag memory
  logic                                     tag_mem_v_li;
  logic                                     tag_mem_w_li;
  logic [index_width_lp-1:0]                tag_mem_addr_li;
  logic [lce_assoc_p-1:0][`bp_coh_bits+tag_width_lp-1:0] tag_mem_data_li;
  logic [lce_assoc_p-1:0][`bp_coh_bits+tag_width_lp-1:0] tag_mem_w_mask_li;
  logic [lce_assoc_p-1:0][`bp_coh_bits+tag_width_lp-1:0] tag_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(lce_assoc_p*(`bp_coh_bits+tag_width_lp))
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

  logic [lce_assoc_p-1:0][`bp_coh_bits-1:0] state_tl;
  logic [lce_assoc_p-1:0][tag_width_lp-1:0] tag_tl;

  for (genvar i = 0; i < lce_assoc_p; i++) begin
    assign state_tl[i] = tag_mem_data_lo[i][tag_width_lp+:`bp_coh_bits];
    assign tag_tl[i]   = tag_mem_data_lo[i][0+:tag_width_lp];
  end

  // data memory
  logic [lce_assoc_p-1:0]                                           data_mem_v_li;
  logic                                                             data_mem_w_li;
  logic [lce_assoc_p-1:0][index_width_lp+word_offset_width_lp-1:0]  data_mem_addr_li;
  logic [lce_assoc_p-1:0][dword_width_p-1:0]                        data_mem_data_li;
  logic [lce_assoc_p-1:0][data_mask_width_lp-1:0]                   data_mem_w_mask_li;
  logic [lce_assoc_p-1:0][dword_width_p-1:0]                        data_mem_data_lo;

  // data memory: banks
  for (genvar bank = 0; bank < lce_assoc_p; bank++)
  begin: data_mems
    bsg_mem_1rw_sync_mask_write_byte #(
      .data_width_p(dword_width_p)
      ,.els_p(lce_sets_p*lce_assoc_p) // same number of blocks and ways
    ) data_mem (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(data_mem_data_li[bank])
      ,.addr_i(data_mem_addr_li[bank])
      ,.v_i(~reset_i & data_mem_v_li[bank])
      ,.write_mask_i(data_mem_w_mask_li[bank])
      ,.w_i(data_mem_w_li)
      ,.data_o(data_mem_data_lo[bank])
    );
  end                                             

  // TV stage
  logic v_tv_r;
  logic tv_we;
  logic uncached_tv_r;
  logic [paddr_width_p-1:0]                     addr_tv_r;
  logic [vaddr_width_p-1:0]                     vaddr_tv_r; 
  logic [lce_assoc_p-1:0][tag_width_lp-1:0]     tag_tv_r;
  logic [lce_assoc_p-1:0][`bp_coh_bits-1:0]     state_tv_r;
  logic [lce_assoc_p-1:0][dword_width_p-1:0]    ld_data_tv_r;
  logic [tag_width_lp-1:0]                      addr_tag_tv;
  logic [index_width_lp-1:0]                    addr_index_tv;
  logic [word_offset_width_lp-1:0]              addr_word_offset_tv;

  assign tv_we = v_tl_r & ~poison_tl_i & ptag_v_i;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      v_tv_r       <= 1'b0;
    end
    else begin
      v_tv_r <= tv_we;
      if (tv_we) begin
        addr_tv_r    <= {ptag_i, vaddr_tl_r[0+:bp_page_offset_width_gp]};
        vaddr_tv_r   <= vaddr_tl_r;
        tag_tv_r     <= tag_tl;
        state_tv_r   <= state_tl;
        ld_data_tv_r <= data_mem_data_lo;
        uncached_tv_r <= uncached_i;
      end
    end
  end

  assign addr_tag_tv = addr_tv_r[block_offset_width_lp+index_width_lp+:tag_width_lp];
  assign addr_index_tv = addr_tv_r[block_offset_width_lp+:index_width_lp];
  assign addr_word_offset_tv = addr_tv_r[byte_offset_width_lp+:word_offset_width_lp];

  //cache hit?
  logic [lce_assoc_p-1:0]     hit_v;
  logic [way_id_width_lp-1:0] hit_index;
  logic                       hit;
  logic                       miss_tv;

  for (genvar i = 0; i < lce_assoc_p; i++) begin: tag_comp
    assign hit_v[i]   = (tag_tv_r[i] == addr_tag_tv) && (state_tv_r[i] != e_COH_I);
    assign way_v[i]   = (state_tv_r[i] != e_COH_I);
  end

  bsg_priority_encode #(
    .width_p(lce_assoc_p)
    ,.lo_to_hi_p(1)
  ) pe_load_hit (
    .i(hit_v)
    ,.v_o(hit)
    ,.addr_o(hit_index)
  );

  assign miss_tv = ~hit & v_tv_r & ~uncached_tv_r;

  // uncached request
  logic uncached_req;
  logic uncached_load_data_v_r;
  logic [dword_width_p-1:0] uncached_load_data_r;

  assign uncached_req = v_tv_r & uncached_tv_r & ~uncached_load_data_v_r;

  // stat memory
  logic                                       stat_mem_v_li;
  logic                                       stat_mem_w_li;
  logic [index_width_lp-1:0]                  stat_mem_addr_li;
  logic [bp_fe_icache_stat_width_lp-1:0]      stat_mem_data_li;
  logic [bp_fe_icache_stat_width_lp-1:0]      stat_mem_mask_li;
  logic [bp_fe_icache_stat_width_lp-1:0]      stat_mem_data_lo;

  bsg_mem_1rw_sync_mask_write_bit #(
    .width_p(bp_fe_icache_stat_width_lp)
    ,.els_p(lce_sets_p)
  ) stat_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.data_i(stat_mem_data_li)
    ,.addr_i(stat_mem_addr_li)
    ,.v_i(~reset_i & stat_mem_v_li)
    ,.w_mask_i(stat_mem_mask_li)
    ,.w_i(stat_mem_w_li)
    ,.data_o(stat_mem_data_lo)
  );

  logic [way_id_width_lp-1:0] lru_encode;

  bsg_lru_pseudo_tree_encode #(
    .ways_p(lce_assoc_p)
  ) lru_encoder (
    .lru_i(stat_mem_data_lo)
    ,.way_id_o(lru_encode)
  );

  bsg_priority_encode #(
    .width_p(lce_assoc_p)
    ,.lo_to_hi_p(1)
  ) pe_invalid (
    .i(~way_v)
    ,.v_o(invalid_exist)
    ,.addr_o(way_invalid_index)
 );
  
  // invalid way takes priority over LRU way
  logic [way_id_width_lp-1:0]           lru_way_li;
  assign lru_way_li = invalid_exist ? way_invalid_index : lru_encode;

  // LCE
  `declare_bp_fe_icache_lce_data_mem_pkt_s(lce_sets_p, lce_assoc_p, lce_data_width_lp);
  `declare_bp_fe_icache_lce_tag_mem_pkt_s(lce_sets_p, lce_assoc_p, tag_width_lp);
  `declare_bp_fe_icache_lce_stat_mem_pkt_s(lce_sets_p, lce_assoc_p);

  bp_fe_icache_lce_data_mem_pkt_s lce_data_mem_pkt;
  bp_fe_icache_lce_tag_mem_pkt_s tag_mem_pkt;
  bp_fe_icache_lce_stat_mem_pkt_s stat_mem_pkt;

  logic [lce_assoc_p-1:0][dword_width_p-1:0] lce_data_mem_data_li;
  logic                                      lce_data_mem_pkt_v_lo;
  logic                                      lce_data_mem_pkt_yumi_li;

  logic                                      tag_mem_pkt_v_lo;
  logic                                      tag_mem_pkt_yumi_li;

  logic                                      stat_mem_pkt_v_lo;
  logic                                      stat_mem_pkt_yumi_li;

  bp_fe_icache_lce_mode_e lce_mode_lo;

  bp_fe_lce
    #(.cfg_p(cfg_p))
  lce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.freeze_i(freeze_i)

     ,.cfg_w_v_i(cfg_w_v_i)
     ,.cfg_addr_i(cfg_addr_i)
     ,.cfg_data_i(cfg_data_i)

     ,.lce_id_i(lce_id_i)

     ,.ready_o(vaddr_ready_o)
     ,.cache_miss_o(cache_miss_o)

     ,.miss_i(miss_tv)
     ,.miss_addr_i(addr_tv_r)

     ,.uncached_req_i(uncached_req)

     ,.data_mem_data_i(lce_data_mem_data_li)
     ,.data_mem_pkt_o(lce_data_mem_pkt)
     ,.data_mem_pkt_v_o(lce_data_mem_pkt_v_lo)
     ,.data_mem_pkt_yumi_i(lce_data_mem_pkt_yumi_li)

     ,.tag_mem_pkt_o(tag_mem_pkt)
     ,.tag_mem_pkt_v_o(tag_mem_pkt_v_lo)
     ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_li)

     ,.stat_mem_pkt_v_o(stat_mem_pkt_v_lo)
     ,.stat_mem_pkt_o(stat_mem_pkt)
     ,.lru_way_i(lru_way_li)
     ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_li)

     ,.lce_req_o(lce_req_o)
     ,.lce_req_v_o(lce_req_v_o)
     ,.lce_req_ready_i(lce_req_ready_i)

     ,.lce_resp_o(lce_resp_o)
     ,.lce_resp_v_o(lce_resp_v_o)
     ,.lce_resp_ready_i(lce_resp_ready_i)

     ,.lce_cmd_i(lce_cmd_i)
     ,.lce_cmd_v_i(lce_cmd_v_i)
     ,.lce_cmd_ready_o(lce_cmd_ready_o)

     ,.lce_cmd_o(lce_cmd_o)
     ,.lce_cmd_v_o(lce_cmd_v_o)
     ,.lce_cmd_ready_i(lce_cmd_ready_i)

     ,.lce_mode_o(lce_mode_lo)
     ); 

  // Fault if in uncached mode but access is not for an uncached address
  assign instr_access_fault_o = (lce_mode_lo == e_icache_lce_mode_uncached)
    ? ~uncached_tv_r
    : 1'b0;

  assign data_v_o = v_tv_r & ((uncached_tv_r & uncached_load_data_v_r) | ~cache_miss_o);

  logic [dword_width_p-1:0]   ld_data_way_picked;

  bsg_mux #(
    .width_p(dword_width_p)
    ,.els_p(lce_assoc_p)
  ) data_set_select_mux (
    .data_i(ld_data_tv_r)
    ,.sel_i(hit_index ^ addr_word_offset_tv)
    ,.data_o(ld_data_way_picked)
  );

  logic [dword_width_p-1:0] final_data;
  bsg_mux #(
    .width_p(dword_width_p)
    ,.els_p(2)
  ) final_data_mux (
    .data_i({uncached_load_data_r, ld_data_way_picked})
    ,.sel_i(uncached_load_data_v_r)
    ,.data_o(final_data)
  );

  logic lower_upper_sel;

  assign lower_upper_sel             = addr_tv_r[byte_offset_width_lp-1];
  assign data_o = lower_upper_sel
    ? final_data[instr_width_p+:instr_width_p]
    : final_data[instr_width_p-1:0];

  // data mem

  logic lce_data_mem_v;
  assign lce_data_mem_v = (lce_data_mem_pkt.opcode != e_icache_lce_data_mem_uncached)
    & lce_data_mem_pkt_yumi_li;

  assign data_mem_v_li = tl_we
    ? {lce_assoc_p{1'b1}}
    : {lce_assoc_p{lce_data_mem_v}};

  assign data_mem_w_li = lce_data_mem_pkt_yumi_li
    & (lce_data_mem_pkt.opcode == e_icache_lce_data_mem_write);   

  logic [lce_assoc_p-1:0][dword_width_p-1:0] lce_data_mem_write_data;

  for (genvar i = 0; i < lce_assoc_p; i++) begin
    assign data_mem_addr_li[i] = tl_we
      ? {vaddr_index, vaddr_offset}
      : {lce_data_mem_pkt.index, lce_data_mem_pkt.way_id ^ ((word_offset_width_lp)'(i))};

    assign data_mem_data_li[i] = lce_data_mem_write_data[i];
    assign data_mem_w_mask_li[i] = {data_mask_width_lp{1'b1}};
  end

  bsg_mux_butterfly #(
    .width_p(dword_width_p)
    ,.els_p(lce_assoc_p)
  ) write_mux_butterfly (
    .data_i(lce_data_mem_pkt.data)
    ,.sel_i(lce_data_mem_pkt.way_id)
    ,.data_o(lce_data_mem_write_data)
  );
   
  // tag_mem
  assign tag_mem_v_li = tl_we | tag_mem_pkt_yumi_li;
  assign tag_mem_w_li = ~tl_we & tag_mem_pkt_v_lo;
  assign tag_mem_addr_li = tl_we
    ? vaddr_index
    : tag_mem_pkt.index;

  logic [lce_assoc_p-1:0] lce_tag_mem_way_one_hot;
  bsg_decode #(
    .num_out_p(lce_assoc_p)
  ) lce_tag_mem_way_decode (
    .i(tag_mem_pkt.way_id)
    ,.o(lce_tag_mem_way_one_hot)
  );

  always_comb begin
    case (tag_mem_pkt.opcode)
      e_tag_mem_set_clear: begin
        for (integer i = 0 ; i < lce_assoc_p; i++) begin
          tag_mem_data_li[i]    = '0;
          tag_mem_w_mask_li[i]  = {(`bp_coh_bits+tag_width_lp){1'b1}};
        end
      end
      e_tag_mem_invalidate: begin
        for (integer i = 0; i < lce_assoc_p; i++) begin
          tag_mem_data_li[i]    = '0;
          tag_mem_w_mask_li[i] = {{`bp_coh_bits{lce_tag_mem_way_one_hot[i]}}, {tag_width_lp{1'b0}}};
        end
      end
      e_tag_mem_set_tag: begin
        for (integer i = 0; i < lce_assoc_p; i++) begin
          tag_mem_data_li[i]   = {tag_mem_pkt.state, tag_mem_pkt.tag};
          tag_mem_w_mask_li[i] = {(`bp_coh_bits+tag_width_lp){lce_tag_mem_way_one_hot[i]}};
        end
      end
      default: begin
        tag_mem_data_li   = '0;
        tag_mem_w_mask_li = '0;
      end
    endcase
  end

  // stat mem
  assign stat_mem_v_li = (v_tv_r & ~uncached_tv_r) | stat_mem_pkt_yumi_li;
  assign stat_mem_w_li = v_tv_r
    ? ~miss_tv
    : stat_mem_pkt_yumi_li & (stat_mem_pkt.opcode != e_stat_mem_read);
  assign stat_mem_addr_li = v_tv_r
    ? addr_index_tv 
    : stat_mem_pkt.index;

  logic [lce_assoc_p-2:0] lru_decode_data_lo;
  logic [lce_assoc_p-2:0] lru_decode_mask_lo;

  bsg_lru_pseudo_tree_decode #(
     .ways_p(lce_assoc_p)
  ) lru_decode (
     .way_id_i(hit_index)
     ,.data_o(lru_decode_data_lo)
     ,.mask_o(lru_decode_mask_lo)
  );

  always_comb begin
    if (v_tv_r) begin
      stat_mem_data_li = lru_decode_data_lo;
      stat_mem_mask_li = lru_decode_mask_lo;
    end else begin
      stat_mem_data_li = {(lce_assoc_p-1){1'b0}};
      stat_mem_mask_li = {(lce_assoc_p-1){1'b1}};
    end
  end
   
  // LCE: data mem
  logic [way_id_width_lp-1:0] lce_data_mem_pkt_way_r;

  always_ff @ (posedge clk_i) begin
    if (lce_data_mem_pkt_yumi_li & (lce_data_mem_pkt.opcode == e_icache_lce_data_mem_read)) begin
      lce_data_mem_pkt_way_r <= lce_data_mem_pkt.way_id;
    end
  end

  bsg_mux_butterfly #(
    .width_p(dword_width_p)
    ,.els_p(lce_assoc_p)
  ) read_mux_butterfly (
    .data_i(data_mem_data_lo)
    ,.sel_i(lce_data_mem_pkt_way_r)
    ,.data_o(lce_data_mem_data_li)
  );

  assign lce_data_mem_pkt_yumi_li = (lce_data_mem_pkt.opcode == e_icache_lce_data_mem_uncached)
    ? lce_data_mem_pkt_v_lo
    : lce_data_mem_pkt_v_lo & ~tl_we;

  // uncached load data logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      uncached_load_data_v_r <= 1'b0;
    end
    else begin
      if (lce_data_mem_pkt_yumi_li & (lce_data_mem_pkt.opcode == e_icache_lce_data_mem_uncached)) begin
        uncached_load_data_r <= lce_data_mem_pkt.data[0+:dword_width_p];
        uncached_load_data_v_r <= 1'b1;
      end
      else begin
        // once the uncached load is replayed, and v_o goes high, clear the valid bit
        if (data_v_o) begin
          uncached_load_data_v_r <= 1'b0;
        end
      end
    end
  end

  // LCE: tag_mem
  assign tag_mem_pkt_yumi_li = tag_mem_pkt_v_lo & ~tl_we;

  // LCE: stat_mem
  assign stat_mem_pkt_yumi_li = ~(v_tv_r & ~uncached_tv_r) & stat_mem_pkt_v_lo;

  // synopsys translate_off
  if (debug_p) begin
    bp_fe_icache_axe_trace_gen #(
      .addr_width_p(paddr_width_p)
      ,.dword_width_p(instr_width_p)
    ) cc (
      .clk_i(clk_i)
      ,.id_i(lce_id_i)
      ,.v_i(icache_pc_gen_data_v_o)
      ,.addr_i(addr_tv_r)
      ,.data_i(data_o)
    );
  end
  // synopsys translate_on
   
endmodule
