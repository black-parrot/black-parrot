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
  localparam num_mem_p = 1;

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

  // clock gen
  //
  logic clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(10)
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

 
  // mem subsystem under test
  //
  `declare_bp_dcache_pkt_s(vaddr_width_lp, data_width_p);
  bp_dcache_pkt_s dcache_pkt;
  logic dcache_pkt_v_li;
  logic dcache_pkt_ready_lo;
  logic [tag_width_p-1:0] paddr_li;

  logic dcache_v_lo;
  logic [data_width_p-1:0] dcache_data_lo;

  bp_rolly_lce_cce_mem #(
    .data_width_p(data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.tag_width_p(tag_width_p)
    ,.num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.num_mem_p(num_mem_p)
  ) dcache_cce_mem (
    .clk_i(clk)
    ,.reset_i(reset)
  
    ,.dcache_pkt_i(dcache_pkt)
    ,.dcache_pkt_v_i(dcache_pkt_v_li)
    ,.dcache_pkt_ready_o(dcache_pkt_ready_lo)
    ,.paddr_i(paddr_li)

    ,.v_o(dcache_v_lo)
    ,.data_o(dcache_data_lo)
  );

  // trace rom
  //
  logic [ring_width_p+4-1:0] rom_data_lo;
  logic [rom_addr_width_p-1:0] rom_addr_li;

  bsg_trace_rom_0 #(
    .width_p(ring_width_p+4)
    ,.addr_width_p(rom_addr_width_p)
  ) trace_rom_0 (
    .addr_i(rom_addr_li)
    ,.data_o(rom_data_lo)
  );

  // trace replay
  //
  logic tr_v_li;
  logic [ring_width_p-1:0] tr_data_li;
  logic tr_ready_lo;

  logic tr_v_lo;
  logic [ring_width_p-1:0] tr_data_lo;
  logic tr_yumi_li;

  logic tr_done_lo;

  bsg_fsb_node_trace_replay #(
    .ring_width_p(ring_width_p)
    ,.rom_addr_width_p(rom_addr_width_p)
  ) trace_replay (
    .clk_i(clk)
    ,.reset_i(reset)
  
    ,.en_i(1'b1)
    
    ,.v_i(tr_v_li)
    ,.data_i(tr_data_li)
    ,.ready_o(tr_ready_lo)

    ,.v_o(tr_v_lo)
    ,.data_o(tr_data_lo)
    ,.yumi_i(tr_yumi_li)

    ,.rom_addr_o(rom_addr_li)
    ,.rom_data_i(rom_data_lo)

    ,.done_o(tr_done_lo)
    ,.error_o()
  );

  assign tr_yumi_li = tr_v_lo & dcache_pkt_ready_lo;
  assign dcache_pkt.opcode = bp_dcache_opcode_e'(tr_data_lo[data_width_p+vaddr_width_lp+tag_width_p+:4]);
  assign paddr_li = tr_data_lo[data_width_p+vaddr_width_lp+:tag_width_p];
  assign dcache_pkt.vaddr = tr_data_lo[data_width_p+:vaddr_width_lp];
  assign dcache_pkt.data = tr_data_lo[0+:data_width_p];
  assign tr_data_li[ring_width_p-1:data_width_p] = '0;
  assign dcache_pkt_v_li = tr_v_lo;


  // dcache output fifo
  //
  logic output_fifo_v_lo;
  logic [data_width_p-1:0] output_fifo_data_lo;
  logic output_fifo_yumi_li;

  bsg_fifo_1r1w_large #(
    .width_p(data_width_p)
    ,.els_p(2**14)
  ) output_fifo (
    .clk_i(clk)
    ,.reset_i(reset)

    ,.v_i(dcache_v_lo)
    ,.ready_o()
    ,.data_i(dcache_data_lo)

    ,.v_o(tr_v_li)
    ,.data_o(tr_data_li[data_width_p-1:0])
    ,.yumi_i(output_fifo_yumi_li)
  );

  assign output_fifo_yumi_li = tr_v_li & tr_ready_lo;

  initial begin
    for (integer i = 0; i < 10000; i++) begin
      @(posedge clk);
    end
    $finish;
  end

endmodule
