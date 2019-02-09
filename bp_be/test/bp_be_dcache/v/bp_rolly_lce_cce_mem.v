/**
 *  bp_rolly_lce_cce_mem.v
 */ 

`include "bp_be_dcache_pkt.vh"

module bp_rolly_lce_cce_mem
  import bp_be_dcache_pkg::*;
  #(parameter data_width_p="inv"
    ,parameter sets_p="inv"
    ,parameter ways_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_mem_p="inv"
    
    ,parameter data_mask_width_lp=(data_width_p>>3)
    ,parameter lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp)
    ,parameter lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    ,parameter lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
    ,parameter vaddr_width_lp=(lg_sets_lp+lg_ways_lp+lg_data_mask_width_lp)
    ,parameter addr_width_lp=(vaddr_width_lp+tag_width_p)
    ,parameter lce_data_width_lp=(ways_p*data_width_p)
      
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
  
    ,input [bp_be_dcache_pkt_width_lp-1:0] dcache_pkt_i
    ,input [tag_width_p-1:0] paddr_i
    ,input dcache_pkt_v_i
    ,output logic dcache_pkt_ready_o

    ,output logic v_o
    ,output logic [data_width_p-1:0] data_o    
  );

  // casting structs
  //
  `declare_bp_be_dcache_pkt_s(vaddr_width_lp, data_width_p);

  // rolly fifo
  //
  logic rollback_li;
  logic [tag_width_p-1:0] rolly_paddr_lo;
  logic [bp_be_dcache_pkt_width_lp-1:0] rolly_dcache_pkt_lo;
  logic rolly_v_lo;
  logic rolly_yumi_li;

  bsg_fifo_1r1w_rolly #(
    .width_p(bp_be_dcache_pkt_width_lp+tag_width_p)
    ,.els_p(8)
  ) rolly (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.rollback_v_i(rollback_li)
    ,.clear_i(1'b0)
    
    ,.ckpt_inc_v_i(v_o)
    ,.ckpt_inc_ready_o()

    ,.data_i({paddr_i, dcache_pkt_i})
    ,.v_i(dcache_pkt_v_i & dcache_pkt_ready_o)
    ,.ready_o(dcache_pkt_ready_o)
  
    ,.data_o({rolly_paddr_lo, rolly_dcache_pkt_lo})
    ,.v_o(rolly_v_lo)
    ,.yumi_i(rolly_yumi_li)
  );

  // dcache
  //
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, addr_width_lp, ways_p);
  `declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, addr_width_lp);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp);
  `declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, addr_width_lp, ways_p, 4);
  `declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, ways_p);
  //`declare_bp_lce_lce_tr_resp_s(num_lce_p, addr_width_lp, lce_data_width_lp, ways_p);

  bp_lce_cce_req_s dcache_lce_cce_req_lo;
  logic dcache_lce_cce_req_v_lo;
  logic dcache_lce_cce_req_ready_li;

  bp_lce_cce_resp_s dcache_lce_cce_resp_lo;
  logic dcache_lce_cce_resp_v_lo;
  logic dcache_lce_cce_resp_ready_li;

  bp_lce_cce_data_resp_s dcache_lce_cce_data_resp_lo;
  logic dcache_lce_cce_data_resp_v_lo;
  logic dcache_lce_cce_data_resp_ready_li;

  bp_cce_lce_cmd_s dcache_cce_lce_cmd_li;
  logic dcache_cce_lce_cmd_v_li;
  logic dcache_cce_lce_cmd_yumi_lo;

  bp_cce_lce_data_cmd_s dcache_cce_lce_data_cmd_li;
  logic dcache_cce_lce_data_cmd_v_li;
  logic dcache_cce_lce_data_cmd_yumi_lo;

  //bp_lce_lce_tr_resp_s dcache_lce_lce_tr_resp_li;
  //logic dcache_lce_lce_tr_resp_v_li;
  //logic dcache_lce_lce_tr_resp_yumi_lo;

  //bp_lce_lce_tr_resp_s dcache_lce_lce_tr_resp_lo;
  //logic dcache_lce_lce_resp_v_lo;
  //logic dcache_lce_lce_tr_resp_ready_li;
  
  logic dcache_tlb_miss_li;
  logic [tag_width_p-1:0] dcache_paddr_li;
  logic cache_miss_lo;
  logic dcache_ready_lo;

  bp_be_dcache #(
    .id_p(0)
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
 
    ,.dcache_pkt_i(rolly_dcache_pkt_lo)
    ,.v_i(rolly_v_lo)
    ,.ready_o(dcache_ready_lo)

    ,.v_o(v_o)
    ,.data_o(data_o)

    ,.tlb_miss_i(dcache_tlb_miss_li)
    ,.paddr_i(dcache_paddr_li)

    // ctrl
    ,.cache_miss_o(cache_miss_lo)
    ,.poison_i(cache_miss_lo)

    // LCE-CCE interface
    ,.lce_cce_req_o(dcache_lce_cce_req_lo)
    ,.lce_cce_req_v_o(dcache_lce_cce_req_v_lo)
    ,.lce_cce_req_ready_i(dcache_lce_cce_req_ready_li)

    ,.lce_cce_resp_o(dcache_lce_cce_resp_lo)
    ,.lce_cce_resp_v_o(dcache_lce_cce_resp_v_lo)
    ,.lce_cce_resp_ready_i(dcache_lce_cce_resp_ready_li)

    ,.lce_cce_data_resp_o(dcache_lce_cce_data_resp_lo)
    ,.lce_cce_data_resp_v_o(dcache_lce_cce_data_resp_v_lo)
    ,.lce_cce_data_resp_ready_i(dcache_lce_cce_resp_ready_li)

    // CCE-LCE interface
    ,.cce_lce_cmd_i(dcache_cce_lce_cmd_li)
    ,.cce_lce_cmd_v_i(dcache_cce_lce_cmd_v_li)
    ,.cce_lce_cmd_yumi_o(dcache_cce_lce_cmd_yumi_lo)

    ,.cce_lce_data_cmd_i(dcache_cce_lce_data_cmd_li)
    ,.cce_lce_data_cmd_v_i(dcache_cce_lce_data_cmd_v_li)
    ,.cce_lce_data_cmd_yumi_o(dcache_cce_lce_data_cmd_yumi_lo)

    // LCE-LCE interface
    ,.lce_lce_tr_resp_i('0)
    ,.lce_lce_tr_resp_v_i(1'b0)
    ,.lce_lce_tr_resp_yumi_o()

    ,.lce_lce_tr_resp_o()
    ,.lce_lce_tr_resp_v_o()
    ,.lce_lce_tr_resp_ready_i(1'b0)
  );

  assign rollback_li = cache_miss_lo;
  assign rolly_yumi_li = rolly_v_lo & dcache_ready_lo;


  // mock tlb
  //
  mock_tlb #(
    .tag_width_p(tag_width_p)
  ) tlb (
    .clk_i(clk_i)

    ,.v_i(rolly_yumi_li)
    ,.tag_i(rolly_paddr_lo)

    ,.tag_o(dcache_paddr_li)
    ,.tlb_miss_o(dcache_tlb_miss_li)
  );
    
  // CCE
  //
  bp_cce_test #(
    .num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.num_mem_p(num_mem_p)
    ,.addr_width_p(addr_width_lp)
    ,.lce_assoc_p(ways_p)
    ,.lce_sets_p(sets_p)
    ,.block_size_in_bytes_p(64)
    ,.num_inst_ram_els_p(256)
  ) cce_mem_test (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.lce_req_i(dcache_lce_cce_req_lo)
    ,.lce_req_v_i(dcache_lce_cce_req_v_lo)
    ,.lce_req_ready_o(dcache_lce_cce_req_ready_li)

    ,.lce_resp_i(dcache_lce_cce_resp_lo)
    ,.lce_resp_v_i(dcache_lce_cce_resp_v_lo)
    ,.lce_resp_ready_o(dcache_lce_cce_resp_ready_li)
  
    ,.lce_data_resp_i(dcache_lce_cce_data_resp_lo)
    ,.lce_data_resp_v_i(dcache_lce_cce_data_resp_v_lo)
    ,.lce_data_resp_ready_o(dcache_lce_cce_data_resp_ready_li)

    ,.lce_cmd_o(dcache_cce_lce_cmd_li)
    ,.lce_cmd_v_o(dcache_cce_lce_cmd_v_li)
    ,.lce_cmd_yumi_i(dcache_cce_lce_cmd_yumi_lo)

    ,.lce_data_cmd_o(dcache_cce_lce_data_cmd_li)
    ,.lce_data_cmd_v_o(dcache_cce_lce_data_cmd_v_li)
    ,.lce_data_cmd_yumi_i(dcache_cce_lce_data_cmd_yumi_lo)
  );

endmodule
