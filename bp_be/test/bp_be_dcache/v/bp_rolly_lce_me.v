/**
 *  bp_rolly_lce_me.v
 */ 

`include "bp_be_dcache_pkt.vh"

module bp_rolly_lce_me
  import bp_be_dcache_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_mem_p="inv"
    ,parameter mem_els_p="inv"
    ,parameter boot_rom_els_p="inv"
    
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter vaddr_width_lp=(lg_sets_lp+lg_ways_lp+lg_data_mask_width_lp)
    ,parameter addr_width_lp=(vaddr_width_lp+tag_width_p)
    ,parameter lce_data_width_lp=(ways_p*data_width_p)
    ,parameter lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)
      
    ,parameter bp_be_dcache_pkt_width_lp=`bp_be_dcache_pkt_width(vaddr_width_lp, data_width_p)

    ,parameter lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_lp, ways_p)
    ,parameter lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_lp)
    ,parameter lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp)
    ,parameter cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_lp, ways_p, 4)
    ,parameter cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p)
    ,parameter lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, addr_width_lp, lce_data_width_lp, ways_p)
  )
  (
    input clk_i
    ,input reset_i
  
    ,input [num_lce_p-1:0][bp_be_dcache_pkt_width_lp-1:0] dcache_pkt_i
    ,input [num_lce_p-1:0][tag_width_p-1:0] paddr_i
    ,input [num_lce_p-1:0] dcache_pkt_v_i
    ,output logic [num_lce_p-1:0] dcache_pkt_ready_o

    ,output logic [num_lce_p-1:0] v_o
    ,output logic [num_lce_p-1:0][data_width_p-1:0] data_o    
  );

  // casting structs
  //
  `declare_bp_be_dcache_pkt_s(vaddr_width_lp, data_width_p);

  // rolly fifo
  //
  logic [num_lce_p-1:0] rollback_li;
  logic [num_lce_p-1:0][tag_width_p-1:0] rolly_paddr_lo;
  bp_be_dcache_pkt_s [num_lce_p-1:0] rolly_dcache_pkt_lo;
  logic [num_lce_p-1:0] rolly_v_lo;
  logic [num_lce_p-1:0] rolly_yumi_li;

  for (genvar i = 0; i < num_lce_p; i++) begin
    bsg_fifo_1r1w_rolly #(
      .width_p(bp_be_dcache_pkt_width_lp+tag_width_p)
      ,.els_p(8)
    ) rolly (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.roll_v_i(rollback_li[i])
      ,.clr_v_i(1'b0)
    
      ,.ckpt_v_i(v_o[i])

      ,.data_i({paddr_i[i], dcache_pkt_i[i]})
      ,.v_i(dcache_pkt_v_i[i] & dcache_pkt_ready_o[i])
      ,.ready_o(dcache_pkt_ready_o[i])
  
      ,.data_o({rolly_paddr_lo[i], rolly_dcache_pkt_lo[i]})
      ,.v_o(rolly_v_lo[i])
      ,.yumi_i(rolly_yumi_li[i])
    );
  end

  // dcache
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, addr_width_lp, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, addr_width_lp);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, addr_width_lp, ways_p, 4);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p);
  `declare_bp_lce_lce_tr_resp_s(num_lce_p, addr_width_lp, lce_data_width_lp, ways_p);

  bp_lce_cce_req_s [num_lce_p-1:0] dcache_lce_cce_req_lo;
  logic [num_lce_p-1:0] dcache_lce_cce_req_v_lo;
  logic [num_lce_p-1:0] dcache_lce_cce_req_ready_li;

  bp_lce_cce_resp_s [num_lce_p-1:0] dcache_lce_cce_resp_lo;
  logic [num_lce_p-1:0] dcache_lce_cce_resp_v_lo;
  logic [num_lce_p-1:0] dcache_lce_cce_resp_ready_li;

  bp_lce_cce_data_resp_s [num_lce_p-1:0] dcache_lce_cce_data_resp_lo;
  logic [num_lce_p-1:0] dcache_lce_cce_data_resp_v_lo;
  logic [num_lce_p-1:0] dcache_lce_cce_data_resp_ready_li;

  bp_cce_lce_cmd_s [num_lce_p-1:0] dcache_cce_lce_cmd_li;
  logic [num_lce_p-1:0] dcache_cce_lce_cmd_v_li;
  logic [num_lce_p-1:0] dcache_cce_lce_cmd_ready_lo;

  bp_cce_lce_data_cmd_s [num_lce_p-1:0] dcache_cce_lce_data_cmd_li;
  logic [num_lce_p-1:0] dcache_cce_lce_data_cmd_v_li;
  logic [num_lce_p-1:0] dcache_cce_lce_data_cmd_ready_lo;

  bp_lce_lce_tr_resp_s [num_lce_p-1:0] dcache_lce_lce_tr_resp_li;
  logic [num_lce_p-1:0] dcache_lce_lce_tr_resp_v_li;
  logic [num_lce_p-1:0] dcache_lce_lce_tr_resp_ready_lo;

  bp_lce_lce_tr_resp_s [num_lce_p-1:0] dcache_lce_lce_tr_resp_lo;
  logic [num_lce_p-1:0] dcache_lce_lce_tr_resp_v_lo;
  logic [num_lce_p-1:0] dcache_lce_lce_tr_resp_ready_li;
  
  logic [num_lce_p-1:0] dcache_tlb_miss_li;
  logic [num_lce_p-1:0][tag_width_p-1:0] dcache_paddr_li;
  logic [num_lce_p-1:0] cache_miss_lo;
  logic [num_lce_p-1:0] dcache_ready_lo;

  for (genvar i = 0; i < num_lce_p; i++) begin
    bp_be_dcache #(
      .id_p(i)
      ,.data_width_p(data_width_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)
      ,.tag_width_p(tag_width_p)
      ,.num_cce_p(num_cce_p)
      ,.num_lce_p(num_lce_p)
      ,.debug_p(1)
    ) dcache (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
 
      ,.dcache_pkt_i(rolly_dcache_pkt_lo[i])
      ,.v_i(rolly_v_lo[i])
      ,.ready_o(dcache_ready_lo[i])

      ,.v_o(v_o[i])
      ,.data_o(data_o[i])

      ,.tlb_miss_i(dcache_tlb_miss_li[i])
      ,.paddr_i(dcache_paddr_li[i])

      // ctrl
      ,.cache_miss_o(cache_miss_lo[i])
      ,.poison_i(cache_miss_lo[i])

      // LCE-CCE interface
      ,.lce_cce_req_o(dcache_lce_cce_req_lo[i])
      ,.lce_cce_req_v_o(dcache_lce_cce_req_v_lo[i])
      ,.lce_cce_req_ready_i(dcache_lce_cce_req_ready_li[i])

      ,.lce_cce_resp_o(dcache_lce_cce_resp_lo[i])
      ,.lce_cce_resp_v_o(dcache_lce_cce_resp_v_lo[i])
      ,.lce_cce_resp_ready_i(dcache_lce_cce_resp_ready_li[i])

      ,.lce_cce_data_resp_o(dcache_lce_cce_data_resp_lo[i])
      ,.lce_cce_data_resp_v_o(dcache_lce_cce_data_resp_v_lo[i])
      ,.lce_cce_data_resp_ready_i(dcache_lce_cce_resp_ready_li[i])

      // CCE-LCE interface
      ,.cce_lce_cmd_i(dcache_cce_lce_cmd_li[i])
      ,.cce_lce_cmd_v_i(dcache_cce_lce_cmd_v_li[i])
      ,.cce_lce_cmd_ready_o(dcache_cce_lce_cmd_ready_lo[i])

      ,.cce_lce_data_cmd_i(dcache_cce_lce_data_cmd_li[i])
      ,.cce_lce_data_cmd_v_i(dcache_cce_lce_data_cmd_v_li[i])
      ,.cce_lce_data_cmd_ready_o(dcache_cce_lce_data_cmd_ready_lo[i])

      // LCE-LCE interface
      ,.lce_lce_tr_resp_i(dcache_lce_lce_tr_resp_li[i])
      ,.lce_lce_tr_resp_v_i(dcache_lce_lce_tr_resp_v_li[i])
      ,.lce_lce_tr_resp_ready_o(dcache_lce_lce_tr_resp_ready_lo[i])

      ,.lce_lce_tr_resp_o(dcache_lce_lce_tr_resp_lo[i])
      ,.lce_lce_tr_resp_v_o(dcache_lce_lce_tr_resp_v_lo[i])
      ,.lce_lce_tr_resp_ready_i(dcache_lce_lce_tr_resp_ready_li[i])
    );
  end

  for (genvar i = 0; i < num_lce_p; i++) begin
    assign rollback_li[i] = cache_miss_lo[i];
    assign rolly_yumi_li[i] = rolly_v_lo[i] & dcache_ready_lo[i];
  end

  // mock tlb
  //
  for (genvar i = 0; i < num_lce_p; i++) begin
    mock_tlb #(
      .tag_width_p(tag_width_p)
    ) tlb (
      .clk_i(clk_i)

      ,.v_i(rolly_yumi_li[i])
      ,.tag_i(rolly_paddr_lo[i])

      ,.tag_o(dcache_paddr_li[i])
      ,.tlb_miss_o(dcache_tlb_miss_li[i])
    );
  end
   
  // Memory End
  bp_me_top #(
    .num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.num_mem_p(num_mem_p)
    ,.addr_width_p(addr_width_lp)
    ,.lce_assoc_p(ways_p)
    ,.lce_sets_p(sets_p)
    ,.block_size_in_bytes_p(ways_p*8)
    ,.num_inst_ram_els_p(256)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_width_p(ways_p*8*8)
    ,.boot_rom_els_p(boot_rom_els_p)
  ) me (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_cmd_o(dcache_cce_lce_cmd_li)
    ,.lce_cmd_v_o(dcache_cce_lce_cmd_v_li)
    ,.lce_cmd_ready_i(dcache_cce_lce_cmd_ready_lo)

    ,.lce_data_cmd_o(dcache_cce_lce_data_cmd_li)
    ,.lce_data_cmd_v_o(dcache_cce_lce_data_cmd_v_li)
    ,.lce_data_cmd_ready_i(dcache_cce_lce_data_cmd_ready_lo)

    ,.lce_req_i(dcache_lce_cce_req_lo)
    ,.lce_req_v_i(dcache_lce_cce_req_v_lo)
    ,.lce_req_ready_o(dcache_lce_cce_req_ready_li)

    ,.lce_resp_i(dcache_lce_cce_resp_lo)
    ,.lce_resp_v_i(dcache_lce_cce_resp_v_lo)
    ,.lce_resp_ready_o(dcache_lce_cce_resp_ready_li)

    ,.lce_data_resp_i(dcache_lce_cce_data_resp_lo)
    ,.lce_data_resp_v_i(dcache_lce_cce_data_resp_v_lo)
    ,.lce_data_resp_ready_o(dcache_lce_cce_data_resp_ready_li)

    ,.lce_tr_resp_i(dcache_lce_lce_tr_resp_lo)
    ,.lce_tr_resp_v_i(dcache_lce_lce_tr_resp_v_lo)
    ,.lce_tr_resp_ready_o(dcache_lce_lce_tr_resp_ready_li)

    ,.lce_tr_resp_o(dcache_lce_lce_tr_resp_li)
    ,.lce_tr_resp_v_o(dcache_lce_lce_tr_resp_v_li)
    ,.lce_tr_resp_ready_i(dcache_lce_lce_tr_resp_ready_lo)
  );

endmodule
