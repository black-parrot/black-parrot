/**
 *  bp_icache_dcache.v
 */ 

`include "bp_be_dcache_pkt.vh"

module bp_icache_dcache
  import bp_be_dcache_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_mem_p="inv"
    ,parameter boot_rom_els_p="inv"
    ,parameter num_core_p="inv" 
    ,parameter inst_width_p="inv"

    ,parameter num_lce_lp=(num_core_p*2)
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter vaddr_width_lp=(lg_sets_lp+lg_ways_lp+lg_data_mask_width_lp)
    ,parameter addr_width_lp=(vaddr_width_lp+tag_width_p)
    ,parameter lce_data_width_lp=(ways_p*data_width_p)
    ,parameter lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)
      
    ,parameter bp_be_dcache_pkt_width_lp=`bp_be_dcache_pkt_width(vaddr_width_lp, data_width_p)

    ,parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_lp, addr_width_lp, ways_p)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_lp, addr_width_lp)
    ,parameter lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_lp, addr_width_lp, lce_data_width_lp)
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_lp, addr_width_lp, ways_p, 4)
    ,parameter cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_lp, addr_width_lp, lce_data_width_lp, ways_p)
    ,parameter lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_lp, addr_width_lp, lce_data_width_lp, ways_p)
  )
  (
    input clk_i
    ,input reset_i

    // icache
    ,input [num_core_p-1:0][addr_width_lp-1:0] icache_addr_i
    ,input [num_core_p-1:0] icache_addr_v_i
    ,output logic [num_core_p-1:0] icache_addr_ready_o

    ,output logic [num_core_p-1:0] icache_v_o
    ,output logic [num_core_p-1:0][inst_width_p-1:0] icache_data_o
  
    // dcache 
    ,input [num_core_p-1:0][bp_be_dcache_pkt_width_lp-1:0] dcache_pkt_i
    ,input [num_core_p-1:0][tag_width_p-1:0] dcache_paddr_i
    ,input [num_core_p-1:0] dcache_pkt_v_i
    ,output logic [num_core_p-1:0] dcache_pkt_ready_o

    ,output logic [num_core_p-1:0] dcache_v_o
    ,output logic [num_core_p-1:0][data_width_p-1:0] dcache_data_o

    ,output logic all_cache_ready_o
  );

  // declare structs
  //
  `declare_bp_be_dcache_pkt_s(vaddr_width_lp, data_width_p);
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_lp, addr_width_lp, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_lp, addr_width_lp);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_lp, addr_width_lp, lce_data_width_lp);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_lp, addr_width_lp, ways_p, 4);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_lp, addr_width_lp, lce_data_width_lp, ways_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_lp, addr_width_lp, lce_data_width_lp, ways_p);

  // dcache rolly fifo
  //
  logic [num_core_p-1:0] dcache_rollback_li;
  logic [num_core_p-1:0][tag_width_p-1:0] dcache_rolly_paddr_lo;
  bp_be_dcache_pkt_s [num_core_p-1:0] dcache_rolly_pkt_lo;
  logic [num_core_p-1:0] dcache_rolly_v_lo;
  logic [num_core_p-1:0] dcache_rolly_yumi_li;

  for (genvar i = 0; i < num_core_p; i++) begin
    bsg_fifo_1r1w_rolly #(
      .width_p(bp_be_dcache_pkt_width_lp+tag_width_p)
      ,.els_p(8)
    ) dcache_rolly (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.rollback_v_i(dcache_rollback_li[i])
      ,.clear_i(1'b0)
    
      ,.ckpt_inc_v_i(dcache_v_o[i])
      ,.ckpt_inc_ready_o()

      ,.data_i({dcache_paddr_i[i], dcache_pkt_i[i]})
      ,.v_i(dcache_pkt_v_i[i] & dcache_pkt_ready_o[i])
      ,.ready_o(dcache_pkt_ready_o[i])
  
      ,.data_o({dcache_rolly_paddr_lo[i], dcache_rolly_pkt_lo[i]})
      ,.v_o(dcache_rolly_v_lo[i])
      ,.yumi_i(dcache_rolly_yumi_li[i])
    );
  end

  // cache-side coherency interface
  //
  bp_lce_cce_req_s [num_lce_lp-1:0] cache_lce_cce_req_lo;
  logic [num_lce_lp-1:0] cache_lce_cce_req_v_lo;
  logic [num_lce_lp-1:0] cache_lce_cce_req_ready_li;

  bp_lce_cce_resp_s [num_lce_lp-1:0] cache_lce_cce_resp_lo;
  logic [num_lce_lp-1:0] cache_lce_cce_resp_v_lo;
  logic [num_lce_lp-1:0] cache_lce_cce_resp_ready_li;

  bp_lce_cce_data_resp_s [num_lce_lp-1:0] cache_lce_cce_data_resp_lo;
  logic [num_lce_lp-1:0] cache_lce_cce_data_resp_v_lo;
  logic [num_lce_lp-1:0] cache_lce_cce_data_resp_ready_li;

  bp_cce_lce_cmd_s [num_lce_lp-1:0] cache_cce_lce_cmd_li;
  logic [num_lce_lp-1:0] cache_cce_lce_cmd_v_li;
  logic [num_lce_lp-1:0] cache_cce_lce_cmd_ready_lo;

  bp_cce_lce_data_cmd_s [num_lce_lp-1:0] cache_cce_lce_data_cmd_li;
  logic [num_lce_lp-1:0] cache_cce_lce_data_cmd_v_li;
  logic [num_lce_lp-1:0] cache_cce_lce_data_cmd_ready_lo;

  bp_lce_lce_tr_resp_s [num_lce_lp-1:0] cache_lce_lce_tr_resp_li;
  logic [num_lce_lp-1:0] cache_lce_lce_tr_resp_v_li;
  logic [num_lce_lp-1:0] cache_lce_lce_tr_resp_ready_lo;

  bp_lce_lce_tr_resp_s [num_lce_lp-1:0] cache_lce_lce_tr_resp_lo;
  logic [num_lce_lp-1:0] cache_lce_lce_tr_resp_v_lo;
  logic [num_lce_lp-1:0] cache_lce_lce_tr_resp_ready_li;

  // icache rolly_fifo
  //
  logic [num_core_p-1:0] icache_rollback_li;
  logic [num_core_p-1:0][tag_width_p-1:0] icache_rolly_paddr_lo;
  logic [num_core_p-1:0][vaddr_width_lp-1:0] icache_rolly_vaddr_lo;
  logic [num_core_p-1:0] icache_rolly_v_lo;
  logic [num_core_p-1:0] icache_rolly_yumi_li;

  for (genvar i = 0; i < num_core_p; i++) begin
    bsg_fifo_1r1w_rolly #(
      .width_p(addr_width_lp)
      ,.els_p(8)
    ) icache_rolly (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.rollback_v_i(icache_rollback_li[i])
      ,.clear_i(1'b0)
    
      ,.ckpt_inc_v_i(icache_v_o[i])
      ,.ckpt_inc_ready_o()

      ,.data_i(icache_addr_i[i])
      ,.v_i(icache_addr_v_i[i])
      ,.ready_o(icache_addr_ready_o[i])
  
      ,.data_o({icache_rolly_paddr_lo[i], icache_rolly_vaddr_lo[i]})
      ,.v_o(icache_rolly_v_lo[i])
      ,.yumi_i(icache_rolly_yumi_li[i])
    );
  end
 
  // icache mock tlb
  //
  logic [num_core_p-1:0][tag_width_p-1:0] icache_tlb_paddr_lo;
  logic [num_core_p-1:0] icache_tlb_miss_lo;

  for (genvar i = 0; i < num_core_p; i++) begin
    mock_tlb #(
      .tag_width_p(tag_width_p)
    ) icache_mock_tlb (
      .clk_i(clk_i)

      ,.v_i(icache_rolly_yumi_li[i])
      ,.tag_i(icache_rolly_paddr_lo[i])

      ,.tag_o(icache_tlb_paddr_lo[i])
      ,.tlb_miss_o(icache_tlb_miss_lo[i])
    );
  end

  // icache
  //
  logic [num_core_p-1:0] icache_ready_lo;
  logic [num_core_p-1:0] icache_miss_lo;

  for (genvar i = 0; i < num_core_p; i++) begin
    icache #(
      .lce_id_p(2*i)
      ,.eaddr_width_p(vaddr_width_lp)
      ,.data_width_p(data_width_p)
      ,.inst_width_p(inst_width_p)
      ,.lce_sets_p(sets_p)
      ,.lce_assoc_p(ways_p)
      ,.tag_width_p(tag_width_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_lp)
      ,.block_size_in_bytes_p(ways_p)
    ) icache (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.pc_gen_icache_vaddr_i(icache_rolly_vaddr_lo[i])
      ,.pc_gen_icache_vaddr_v_i(icache_rolly_v_lo[i])
      ,.pc_gen_icache_vaddr_ready_o(icache_ready_lo[i])

      ,.itlb_icache_data_resp_v_i(~icache_tlb_miss_lo[i])
      ,.itlb_icache_data_resp_i({{(44-tag_width_p){1'b0}}, icache_tlb_paddr_lo[i]})
      ,.itlb_icache_data_resp_ready_o()

      ,.icache_pc_gen_data_v_o(icache_v_o[i])
      ,.icache_pc_gen_data_o(icache_data_o[i])
      ,.icache_pc_gen_data_ready_i(1'b1)

      ,.cache_miss_o(icache_miss_lo[i])
      ,.poison_i(icache_miss_lo[i])

      ,.lce_cce_req_o(cache_lce_cce_req_lo[2*i])
      ,.lce_cce_req_v_o(cache_lce_cce_req_v_lo[2*i])
      ,.lce_cce_req_ready_i(cache_lce_cce_req_ready_li[2*i])

      ,.lce_cce_resp_o(cache_lce_cce_resp_lo[2*i])
      ,.lce_cce_resp_v_o(cache_lce_cce_resp_v_lo[2*i])
      ,.lce_cce_resp_ready_i(cache_lce_cce_resp_ready_li[2*i])

      ,.lce_cce_data_resp_o(cache_lce_cce_data_resp_lo[2*i])
      ,.lce_cce_data_resp_v_o(cache_lce_cce_data_resp_v_lo[2*i])
      ,.lce_cce_data_resp_ready_i(cache_lce_cce_resp_ready_li[2*i])

      ,.cce_lce_cmd_i(cache_cce_lce_cmd_li[2*i])
      ,.cce_lce_cmd_v_i(cache_cce_lce_cmd_v_li[2*i])
      ,.cce_lce_cmd_ready_o(cache_cce_lce_cmd_ready_lo[2*i])

      ,.cce_lce_data_cmd_i(cache_cce_lce_data_cmd_li[2*i])
      ,.cce_lce_data_cmd_v_i(cache_cce_lce_data_cmd_v_li[2*i])
      ,.cce_lce_data_cmd_ready_o(cache_cce_lce_data_cmd_ready_lo[2*i])

      ,.lce_lce_tr_resp_i(cache_lce_lce_tr_resp_li[2*i])
      ,.lce_lce_tr_resp_v_i(cache_lce_lce_tr_resp_v_li[2*i])
      ,.lce_lce_tr_resp_ready_o(cache_lce_lce_tr_resp_ready_lo[2*i])

      ,.lce_lce_tr_resp_o(cache_lce_lce_tr_resp_lo[2*i])
      ,.lce_lce_tr_resp_v_o(cache_lce_lce_tr_resp_v_lo[2*i])
      ,.lce_lce_tr_resp_ready_i(cache_lce_lce_tr_resp_ready_li[2*i])
    );
  end

  for (genvar i = 0; i < num_core_p; i++) begin
    assign icache_rollback_li[i] = icache_miss_lo[i];
    assign icache_rolly_yumi_li[i] = icache_rolly_v_lo[i] & icache_ready_lo[i];
  end
 
  // dcache
  //
  logic [num_core_p-1:0] dcache_tlb_miss_li;
  logic [num_core_p-1:0][tag_width_p-1:0] dcache_paddr_li;
  logic [num_core_p-1:0] dcache_miss_lo;
  logic [num_core_p-1:0] dcache_ready_lo;

  for (genvar i = 0; i < num_core_p; i++) begin
    bp_be_dcache #(
      .id_p(2*i+1)
      ,.data_width_p(data_width_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
      ,.tag_width_p(tag_width_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_lp)
      ,.debug_p(1)
    ) dcache (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
 
      ,.dcache_pkt_i(dcache_rolly_pkt_lo[i])
      ,.v_i(dcache_rolly_v_lo[i])
      ,.ready_o(dcache_ready_lo[i])

      ,.v_o(dcache_v_o[i])
      ,.data_o(dcache_data_o[i])

      ,.tlb_miss_i(dcache_tlb_miss_li[i])
      ,.paddr_i(dcache_paddr_li[i])

      // ctrl
      ,.cache_miss_o(dcache_miss_lo[i])
      ,.poison_i(dcache_miss_lo[i])

      // LCE-CCE interface
      ,.lce_cce_req_o(cache_lce_cce_req_lo[2*i+1])
      ,.lce_cce_req_v_o(cache_lce_cce_req_v_lo[2*i+1])
      ,.lce_cce_req_ready_i(cache_lce_cce_req_ready_li[2*i+1])

      ,.lce_cce_resp_o(cache_lce_cce_resp_lo[2*i+1])
      ,.lce_cce_resp_v_o(cache_lce_cce_resp_v_lo[2*i+1])
      ,.lce_cce_resp_ready_i(cache_lce_cce_resp_ready_li[2*i+1])

      ,.lce_cce_data_resp_o(cache_lce_cce_data_resp_lo[2*i+1])
      ,.lce_cce_data_resp_v_o(cache_lce_cce_data_resp_v_lo[2*i+1])
      ,.lce_cce_data_resp_ready_i(cache_lce_cce_resp_ready_li[2*i+1])

      // CCE-LCE interface
      ,.cce_lce_cmd_i(cache_cce_lce_cmd_li[2*i+1])
      ,.cce_lce_cmd_v_i(cache_cce_lce_cmd_v_li[2*i+1])
      ,.cce_lce_cmd_ready_o(cache_cce_lce_cmd_ready_lo[2*i+1])

      ,.cce_lce_data_cmd_i(cache_cce_lce_data_cmd_li[2*i+1])
      ,.cce_lce_data_cmd_v_i(cache_cce_lce_data_cmd_v_li[2*i+1])
      ,.cce_lce_data_cmd_ready_o(cache_cce_lce_data_cmd_ready_lo[2*i+1])

      // LCE-LCE interface
      ,.lce_lce_tr_resp_i(cache_lce_lce_tr_resp_li[2*i+1])
      ,.lce_lce_tr_resp_v_i(cache_lce_lce_tr_resp_v_li[2*i+1])
      ,.lce_lce_tr_resp_ready_o(cache_lce_lce_tr_resp_ready_lo[2*i+1])

      ,.lce_lce_tr_resp_o(cache_lce_lce_tr_resp_lo[2*i+1])
      ,.lce_lce_tr_resp_v_o(cache_lce_lce_tr_resp_v_lo[2*i+1])
      ,.lce_lce_tr_resp_ready_i(cache_lce_lce_tr_resp_ready_li[2*i+1])
    );
  end

  for (genvar i = 0; i < num_core_p; i++) begin
    assign dcache_rollback_li[i] = dcache_miss_lo[i];
    assign dcache_rolly_yumi_li[i] = dcache_rolly_v_lo[i] & dcache_ready_lo[i];
  end

  // dcache mock tlb
  //
  for (genvar i = 0; i < num_core_p; i++) begin
    mock_tlb #(
      .tag_width_p(tag_width_p)
    ) dcache_mock_tlb (
      .clk_i(clk_i)

      ,.v_i(dcache_rolly_yumi_li[i])
      ,.tag_i(dcache_rolly_paddr_lo[i])

      ,.tag_o(dcache_paddr_li[i])
      ,.tlb_miss_o(dcache_tlb_miss_li[i])
    );
  end
   
  // CCE-side coherency interface
  //
  `declare_bp_mem_cce_resp_s(num_mem_p, num_cce_p, addr_width_lp, num_lce_lp, ways_p);
  `declare_bp_mem_cce_data_resp_s(num_mem_p, num_cce_p, addr_width_lp, lce_data_width_lp, num_lce_lp, ways_p);
  `declare_bp_cce_mem_cmd_s(num_mem_p, num_cce_p, addr_width_lp, num_lce_lp, ways_p);
  `declare_bp_cce_mem_data_cmd_s(num_mem_p, num_cce_p, addr_width_lp, lce_data_width_lp, num_lce_lp, ways_p);

  bp_lce_cce_req_s [num_cce_p-1:0] lce_req_li;
  logic [num_cce_p-1:0] lce_req_v_li;
  logic [num_cce_p-1:0] lce_req_ready_lo;

  bp_lce_cce_resp_s [num_cce_p-1:0] lce_resp_li;
  logic [num_cce_p-1:0] lce_resp_v_li;
  logic [num_cce_p-1:0] lce_resp_ready_lo;

  bp_lce_cce_data_resp_s [num_cce_p-1:0] lce_data_resp_li;
  logic [num_cce_p-1:0] lce_data_resp_v_li;
  logic [num_cce_p-1:0] lce_data_resp_ready_lo;

  bp_cce_lce_cmd_s [num_cce_p-1:0] lce_cmd_lo;
  logic [num_cce_p-1:0] lce_cmd_v_lo;
  logic [num_cce_p-1:0] lce_cmd_ready_li;

  bp_cce_lce_data_cmd_s [num_cce_p-1:0] lce_data_cmd_lo;
  logic [num_cce_p-1:0] lce_data_cmd_v_lo;
  logic [num_cce_p-1:0] lce_data_cmd_ready_li;

  bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp_li;
  logic [num_cce_p-1:0] mem_resp_v_li;
  logic [num_cce_p-1:0] mem_resp_ready_lo;
    
  bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp_li;
  logic [num_cce_p-1:0] mem_data_resp_v_li;
  logic [num_cce_p-1:0] mem_data_resp_ready_lo;

  bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd_lo;
  logic [num_cce_p-1:0] mem_cmd_v_lo;
  logic [num_cce_p-1:0] mem_cmd_yumi_li;
    
  bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd_lo;
  logic [num_cce_p-1:0] mem_data_cmd_v_lo;
  logic [num_cce_p-1:0] mem_data_cmd_yumi_li;

  for (genvar i = 0; i < num_cce_p; i++) begin
    bp_cce_top #(
      .cce_id_p(i)
      ,.num_lce_p(num_lce_lp)
      ,.num_cce_p(num_cce_p)
      ,.num_mem_p(num_mem_p)
      ,.addr_width_p(addr_width_lp)
      ,.lce_assoc_p(ways_p)
      ,.lce_sets_p(sets_p)
      ,.block_size_in_bytes_p(ways_p*8)
      ,.num_inst_ram_els_p(256)
    ) cce (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      
      ,.lce_req_i(lce_req_li[i])
      ,.lce_req_v_i(lce_req_v_li[i])
      ,.lce_req_ready_o(lce_req_ready_lo[i])

      ,.lce_resp_i(lce_resp_li[i])
      ,.lce_resp_v_i(lce_resp_v_li[i])
      ,.lce_resp_ready_o(lce_resp_ready_lo[i])

      ,.lce_data_resp_i(lce_data_resp_li[i])
      ,.lce_data_resp_v_i(lce_data_resp_v_li[i])
      ,.lce_data_resp_ready_o(lce_data_resp_ready_lo[i])

      ,.lce_cmd_o(lce_cmd_lo[i])
      ,.lce_cmd_v_o(lce_cmd_v_lo[i])
      ,.lce_cmd_ready_i(lce_cmd_ready_li[i])

      ,.lce_data_cmd_o(lce_data_cmd_lo[i])
      ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[i])
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[i])

      ,.mem_resp_i(mem_resp_li[i])
      ,.mem_resp_v_i(mem_resp_v_li[i])
      ,.mem_resp_ready_o(mem_resp_ready_lo[i])
    
      ,.mem_data_resp_i(mem_data_resp_li[i])
      ,.mem_data_resp_v_i(mem_data_resp_v_li[i])
      ,.mem_data_resp_ready_o(mem_data_resp_ready_lo[i])

      ,.mem_cmd_o(mem_cmd_lo[i])
      ,.mem_cmd_v_o(mem_cmd_v_lo[i])
      ,.mem_cmd_yumi_i(mem_cmd_yumi_li[i])
    
      ,.mem_data_cmd_o(mem_data_cmd_lo[i])
      ,.mem_data_cmd_v_o(mem_data_cmd_v_lo[i])
      ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li[i])
    );
  end 

  // bp_mem
  logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0] boot_rom_addr;
  logic [num_cce_p-1:0][lce_data_width_lp-1:0] boot_rom_data;

  for (genvar i = 0; i < num_cce_p; i++) begin
    bp_mem #(
      .num_lce_p(num_lce_lp)
      ,.num_cce_p(num_cce_p)
      ,.num_mem_p(num_mem_p)
      ,.mem_els_p(2**12)
      ,.addr_width_p(addr_width_lp)
      ,.lce_assoc_p(ways_p)
      ,.block_size_in_bytes_p(ways_p*8)
      ,.lce_sets_p(sets_p)
      ,.boot_rom_els_p(boot_rom_els_p)
      ,.boot_rom_width_p(ways_p*8*8)
    ) bp_mem_inst (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.mem_cmd_i(mem_cmd_lo[i])
      ,.mem_cmd_v_i(mem_cmd_v_lo[i])
      ,.mem_cmd_yumi_o(mem_cmd_yumi_li[i])
      ,.mem_data_cmd_i(mem_data_cmd_lo[i])
      ,.mem_data_cmd_v_i(mem_data_cmd_v_lo[i])
      ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_li[i])

      ,.mem_resp_o(mem_resp_li[i])
      ,.mem_resp_v_o(mem_resp_v_li[i])
      ,.mem_resp_ready_i(mem_resp_ready_lo[i])
      ,.mem_data_resp_o(mem_data_resp_li[i])
      ,.mem_data_resp_v_o(mem_data_resp_v_li[i])
      ,.mem_data_resp_ready_i(mem_data_resp_ready_lo[i])

      ,.boot_rom_addr_o(boot_rom_addr[i])
      ,.boot_rom_data_i(boot_rom_data[i]) 
    );

    boot_rom #(
      .data_width_p(lce_data_width_lp)
      ,.addr_width_p(lg_boot_rom_els_lp)
    ) boot_rom_inst (
      .addr_i(boot_rom_addr[i])
      ,.data_o(boot_rom_data[i])
    );
  end


  // coherence network
  //
  bp_coherence_network #(
    .num_lce_p(num_lce_lp)
    ,.num_cce_p(num_cce_p)
    ,.addr_width_p(addr_width_lp)
    ,.lce_assoc_p(ways_p)
    ,.block_size_in_bytes_p(ways_p*8)
  ) network (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    // CCE Command Network - (CCE->trans_net->LCE)
    // (LCE side)
    ,.lce_cmd_o(cache_cce_lce_cmd_li)
    ,.lce_cmd_v_o(cache_cce_lce_cmd_v_li)
    ,.lce_cmd_ready_i(cache_cce_lce_cmd_ready_lo)
    // (CCE side)
    ,.lce_cmd_i(lce_cmd_lo)
    ,.lce_cmd_v_i(lce_cmd_v_lo)
    ,.lce_cmd_ready_o(lce_cmd_ready_li)

    // CCE Data Command Network - (CCE->trans_net->LCE)
    // (LCE side)
    ,.lce_data_cmd_o(cache_cce_lce_data_cmd_li)
    ,.lce_data_cmd_v_o(cache_cce_lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_i(cache_cce_lce_data_cmd_ready_lo)
    // (CCE side)
    ,.lce_data_cmd_i(lce_data_cmd_lo)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

    // LCE Request Network - (LCE->trans_net->CCE)
    // (LCE side)
    ,.lce_req_i(cache_lce_cce_req_lo)
    ,.lce_req_v_i(cache_lce_cce_req_v_lo)
    ,.lce_req_ready_o(cache_lce_cce_req_ready_li)
    // (CCE side)
    ,.lce_req_o(lce_req_li)
    ,.lce_req_v_o(lce_req_v_li)
    ,.lce_req_ready_i(lce_req_ready_lo)

    // LCE Response Network - (LCE->trans_net->CCE)
	  // (LCE side)
    ,.lce_resp_i(cache_lce_cce_resp_lo)
    ,.lce_resp_v_i(cache_lce_cce_resp_v_lo)
    ,.lce_resp_ready_o(cache_lce_cce_resp_ready_li)
    // (CCE side)
    ,.lce_resp_o(lce_resp_li)
    ,.lce_resp_v_o(lce_resp_v_li)
    ,.lce_resp_ready_i(lce_resp_ready_lo)

    // LCE Data Response Network - (LCE->trans_net->CCE)
    // (LCE side)
    ,.lce_data_resp_i(cache_lce_cce_data_resp_lo)
    ,.lce_data_resp_v_i(cache_lce_cce_data_resp_v_lo)
    ,.lce_data_resp_ready_o(cache_lce_cce_data_resp_ready_li)
    // (CCE side)
    ,.lce_data_resp_o(lce_data_resp_li)
    ,.lce_data_resp_v_o(lce_data_resp_v_li)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_lo)

    // LCE-LCE Transfer Network - (LCE(s)->trans_net->LCE(d))
    // (LCE source side)
    ,.lce_tr_resp_i(cache_lce_lce_tr_resp_lo)
    ,.lce_tr_resp_v_i(cache_lce_lce_tr_resp_v_lo)
    ,.lce_tr_resp_ready_o(cache_lce_lce_tr_resp_ready_li)
    // (LCE dest side)
    ,.lce_tr_resp_o(cache_lce_lce_tr_resp_li)
    ,.lce_tr_resp_v_o(cache_lce_lce_tr_resp_v_li)
    ,.lce_tr_resp_ready_i(cache_lce_lce_tr_resp_ready_lo)
  );

  // are all caches ready?
  logic [num_lce_lp-1:0] cache_ready;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      cache_ready <= '0;
    end
    else begin
      for (integer i = 0; i < num_lce_lp; i++) begin
        if (i % 2 == 0) begin
          cache_ready[i] <= cache_ready[i]
            ? 1'b1
            : icache_ready_lo[i/2];
        end
        else begin
          cache_ready[i] <= cache_ready[i]
            ? 1'b1
            : dcache_ready_lo[i/2];
        end
      end
    end
  end

  assign all_cache_ready_o= &cache_ready;

endmodule
