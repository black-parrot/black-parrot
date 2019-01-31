/**
 *  testbench.v
 */

`include "bp_dcache_pkt.vh"
`include "bp_common_me_if.vh"

module testbench;

  // parameters
  //
  localparam data_width_p = 64;
  localparam sets_p = 64;
  localparam ways_p = 8;
  localparam tag_width_p = 10;
  localparam num_cce_p = 1;
  localparam num_lce_p = 1;

  localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p);
  localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p);
  localparam data_mask_width_lp=(data_width_p>>3);
  localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp);
  localparam vaddr_width_lp=lg_ways_lp+lg_sets_lp+lg_data_mask_width_lp;
  localparam lce_addr_width_lp=vaddr_width_lp+tag_width_p;
  localparam lce_data_width_lp=ways_p*data_width_p;

  localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_lp, ways_p);
  localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_lp);
  localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_lp, lce_data_width_lp);
  localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_lp, ways_p, 4);
  localparam cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_lp, lce_data_width_lp, ways_p);
  localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_lp, lce_data_width_lp, ways_p);

  localparam ring_width_p = data_width_p+vaddr_width_lp+tag_width_p+4;
  localparam rom_addr_width_p = 20;

  logic dcache_ready_lo;

  // clock gen
  //
  logic clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(100)
  ) clk_gen (
    .o(clk)
  );

  // reset gen
  //
  logic reset;
  bsg_nonsynth_reset_gen #(
    .num_clocks_p(1)
    ,.reset_cycles_lo_p(4)
    ,.reset_cycles_hi_p(4)
  ) reset_gen (
    .clk_i(clk)
    ,.async_reset_o(reset)
  );

  // trace replay
  //
  logic tr_v_li;
  logic tr_ready_lo;
  logic [ring_width_p-1:0] tr_data_li;

  logic tr_v_lo;
  logic tr_yumi_li;
  logic [ring_width_p-1:0] tr_data_lo;

  logic [rom_addr_width_p-1:0] rom_addr_lo;
  logic [ring_width_p+4-1:0] rom_data_li;

  logic tr_done_lo;
  logic cce_done_lo;

  bsg_fsb_node_trace_replay #(
    .ring_width_p(ring_width_p)
    ,.rom_addr_width_p(rom_addr_width_p)
  ) trace_replay (
    .clk_i(clk)
    ,.reset_i(reset)
    ,.en_i(cce_done_lo)
    
    ,.v_i(tr_v_li)
    ,.data_i(tr_data_li)
    ,.ready_o(tr_ready_lo)

    ,.v_o(tr_v_lo)
    ,.data_o(tr_data_lo)
    ,.yumi_i(tr_v_lo & dcache_ready_lo)

    ,.rom_addr_o(rom_addr_lo)
    ,.rom_data_i(rom_data_li)
  
    ,.done_o(tr_done_lo)
    ,.error_o()
  );

  bsg_trace_rom_0 #(
    .width_p(ring_width_p+4)
    ,.addr_width_p(rom_addr_width_p)
  ) trace_rom_0 (
    .addr_i(rom_addr_lo)
    ,.data_o(rom_data_li)
  );

  // trace output
  //
  logic [tag_width_p-1:0] tr_tag;
  logic [3:0] tr_opcode;
  logic [vaddr_width_lp-1:0] tr_vaddr;
  logic [data_width_p-1:0] tr_data;
  assign tr_data = tr_data_lo[data_width_p-1:0];
  assign tr_vaddr = tr_data_lo[data_width_p+:vaddr_width_lp];
  assign tr_tag = tr_data_lo[data_width_p+vaddr_width_lp+:tag_width_p];
  assign tr_opcode = tr_data_lo[data_width_p+vaddr_width_lp+tag_width_p+:4];

  `declare_bp_dcache_pkt_s(vaddr_width_lp, data_width_p);
  bp_dcache_pkt_s bp_dcache_pkt;
  assign bp_dcache_pkt.opcode = bp_dcache_opcode_e'(tr_opcode);
  assign bp_dcache_pkt.vaddr = tr_vaddr;
  assign bp_dcache_pkt.data = tr_data;

  // mock tlb
  //
  logic [tag_width_p-1:0] tag_lo;
  logic tlb_miss_lo;

  mock_tlb #(
    .tag_width_p(tag_width_p)
  ) tlb (
    .clk_i(clk)
    ,.v_i(tr_v_lo & dcache_ready_lo)
    ,.tag_i(tr_tag)
    ,.tag_o(tag_lo)
    ,.tlb_miss_o(tlb_miss_lo)
  );
 
  //  dcache
  //
  logic [data_width_p-1:0] dcache_data_lo;
  logic dcache_v_lo;
  logic cache_miss_lo;
 
  logic [lce_cce_req_width_lp-1:0] lce_cce_req_lo;
  logic lce_cce_req_v_lo;
  logic lce_cce_req_ready_li;

  logic [lce_cce_resp_width_lp-1:0] lce_cce_resp_lo;
  logic lce_cce_resp_v_lo;
  logic lce_cce_resp_ready_li;

  logic [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_lo;
  logic lce_cce_data_resp_v_lo;
  logic lce_cce_data_resp_ready_li;

  logic [cce_lce_cmd_width_lp-1:0] cce_lce_cmd_li;
  logic cce_lce_cmd_v_li;
  logic cce_lce_cmd_ready_lo;

  logic [cce_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_li;
  logic cce_lce_data_cmd_v_li;
  logic cce_lce_data_cmd_ready_lo;

  bp_dcache #(
    .id_p(0)
    ,.data_width_p(data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.tag_width_p(tag_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
  ) dcache (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.dcache_pkt_i(bp_dcache_pkt)
    ,.v_i(tr_v_lo)
    ,.ready_o(dcache_ready_lo)
    
    ,.data_o(dcache_data_lo)
    ,.v_o(dcache_v_lo)

    ,.tlb_miss_i(tlb_miss_lo)
    ,.paddr_i(tag_lo)

    ,.cache_miss_o(cache_miss_lo)    
    ,.poison_i(cache_miss_lo)

    ,.lce_cce_req_o(lce_cce_req_lo)
    ,.lce_cce_req_v_o(lce_cce_req_v_lo)
    ,.lce_cce_req_ready_i(lce_cce_req_ready_li)

    ,.lce_cce_resp_o(lce_cce_resp_lo)
    ,.lce_cce_resp_v_o(lce_cce_resp_v_lo)
    ,.lce_cce_resp_ready_i(lce_cce_resp_ready_li)

    ,.lce_cce_data_resp_o(lce_cce_data_resp_lo)
    ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v_lo)
    ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_ready_li)

    ,.cce_lce_cmd_i(cce_lce_cmd_li)
    ,.cce_lce_cmd_v_i(cce_lce_cmd_v_li)
    ,.cce_lce_cmd_ready_o(cce_lce_cmd_ready_lo)

    ,.cce_lce_data_cmd_i(cce_lce_data_cmd_li)
    ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v_li)
    ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_ready_lo)

    ,.lce_lce_tr_resp_i('0)
    ,.lce_lce_tr_resp_v_i(1'b0)
    ,.lce_lce_tr_resp_ready_o()
  
    ,.lce_lce_tr_resp_o()
    ,.lce_lce_tr_resp_v_o()
    ,.lce_lce_tr_resp_ready_i(1'b0)
  );


  // mock cce
  //
  logic lce_cce_resp_fifo_v_lo;
  logic lce_cce_resp_fifo_yumi_li;
  logic [lce_cce_resp_width_lp-1:0] lce_cce_resp_fifo_data_lo;
  bsg_two_fifo #(
    .width_p(lce_cce_resp_width_lp)
  ) lce_cce_resp_fifo (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.v_i(lce_cce_resp_v_lo)
    ,.ready_o(lce_cce_resp_ready_li)
    ,.data_i(lce_cce_resp_lo)

    ,.v_o(lce_cce_resp_fifo_v_lo)
    ,.yumi_i(lce_cce_resp_fifo_yumi_li & lce_cce_resp_fifo_v_lo)
    ,.data_o(lce_cce_resp_fifo_data_lo)
  );
  

  mock_cce #(
    .data_width_p(data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.tag_width_p(tag_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
  ) cce (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.lce_req_i(lce_cce_req_lo)
    ,.lce_req_v_i(lce_cce_req_v_lo)
    ,.lce_req_ready_o(lce_cce_req_ready_li)

    ,.lce_resp_i(lce_cce_resp_fifo_data_lo)
    ,.lce_resp_v_i(lce_cce_resp_fifo_v_lo)
    ,.lce_resp_ready_o(lce_cce_resp_fifo_yumi_li)
   
    ,.lce_data_resp_i(lce_cce_data_resp_lo)
    ,.lce_data_resp_v_i(lce_cce_data_resp_v_lo)
    ,.lce_data_resp_ready_o(lce_cce_data_resp_ready_li)
    
    ,.lce_cmd_o(cce_lce_cmd_li)
    ,.lce_cmd_v_o(cce_lce_cmd_v_li)
    ,.lce_cmd_yumi_i(cce_lce_cmd_ready_lo)

    ,.lce_data_cmd_o(cce_lce_data_cmd_li)
    ,.lce_data_cmd_v_o(cce_lce_data_cmd_v_li)
    ,.lce_data_cmd_yumi_i(cce_lce_data_cmd_ready_lo) 

    ,.done_o(cce_done_lo)
  );

  // output fifo
  //
  logic [data_width_p-1:0] fifo_data_lo;
  bsg_fifo_1r1w_large #(
    .width_p(data_width_p)
    ,.els_p(2**12)
  ) output_fifo (
    .clk_i(clk)
    ,.reset_i(reset)
    
    ,.data_i(dcache_data_lo)
    ,.v_i(dcache_v_lo)
    ,.ready_o()

    ,.v_o(tr_v_li)
    ,.data_o(fifo_data_lo)
    ,.yumi_i(tr_v_li & tr_ready_lo)
  );
  
  assign tr_data_li = {{(ring_width_p-data_width_p){1'b0}}, fifo_data_lo};

  initial begin
    wait(tr_done_lo);
    $finish;
  end

endmodule
