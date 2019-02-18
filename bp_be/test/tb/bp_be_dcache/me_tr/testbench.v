/**
 *  testbench.v
 */

`include "bp_be_dcache_pkt.vh"

module testbench();
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;

  // parameters
  //

  // Data Cache "word" size, i.e., how many bits per way
  localparam data_width_p = 64;
  localparam sets_p = 16;
  localparam ways_p = 8;

  // Physical address width
  localparam paddr_width_p = 32;

  localparam num_cce_p = 1;
  localparam num_lce_p = `NUM_LCE_P;
  localparam num_mem_p = 1;
  // Number of cache blocks in simulated memory
  localparam mem_els_p = 2*num_lce_p*sets_p*ways_p;

  localparam word_offset_width_lp=`BSG_SAFE_CLOG2(ways_p);
  localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p);
  localparam data_mask_width_lp=(data_width_p>>3);
  localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp);
  localparam page_offset_width_lp=word_offset_width_lp+index_width_lp+byte_offset_width_lp;
  localparam ptag_width_lp=paddr_width_p-page_offset_width_lp;

  // For the D$, cache block size is number of ways multiplied by D$ "word" size
  localparam cache_block_size_in_bytes=ways_p*data_width_p;
  localparam bp_be_dcache_pkt_width_lp=`bp_be_dcache_pkt_width(page_offset_width_lp, data_width_p);

  localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p);
  localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, cache_block_size_in_bytes);
  localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  localparam cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, paddr_width_p, cache_block_size_in_bytes, ways_p);
  localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, paddr_width_p, cache_block_size_in_bytes, ways_p);

  localparam ring_width_p = data_width_p+paddr_width_p+4;

  // addr width for Trace Replay ROM. This limits maximum number of instructions in TR
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
    ,.reset_cycles_lo_p(0)
    ,.reset_cycles_hi_p(4)
  ) reset_gen (
    .clk_i(clk)
    ,.async_reset_o(reset)
  );

 
  // mem subsystem under test
  //
  `declare_bp_be_dcache_pkt_s(page_offset_width_lp, data_width_p);
  bp_be_dcache_pkt_s [num_lce_p-1:0] dcache_pkt;
  logic [num_lce_p-1:0] dcache_pkt_v_li;
  logic [num_lce_p-1:0] dcache_pkt_ready_lo;
  logic [num_lce_p-1:0][ptag_width_lp-1:0] paddr_li;

  logic [num_lce_p-1:0] dcache_v_lo;
  logic [num_lce_p-1:0][data_width_p-1:0] dcache_data_lo;

  bp_rolly_lce_me #(
    .data_width_p(data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.paddr_width_p(paddr_width_p)
    ,.num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.num_mem_p(num_mem_p)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_els_p(mem_els_p)
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

  // trace node master
  //
  logic [num_lce_p-1:0] tr_v_lo;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_lo;
  logic [num_lce_p-1:0] tr_yumi_li;

  logic [num_lce_p-1:0] tr_done_lo;
  
  for (genvar i = 0; i < num_lce_p; i++) begin

    bsg_trace_node_master #(
      .id_p(i)
      ,.ring_width_p(ring_width_p)
      ,.rom_addr_width_p(rom_addr_width_p)
    ) trace_node_master (
      .clk_i(clk)
      ,.reset_i(reset)
      ,.en_i(1'b1)

      ,.v_i(dcache_v_lo[i])
      ,.data_i(dcache_data_lo[i])
      ,.ready_o()

      ,.v_o(tr_v_lo[i])
      ,.yumi_i(tr_yumi_li[i])
      ,.data_o(tr_data_lo[i])

      ,.done_o(tr_done_lo[i])
    );
    
    assign tr_yumi_li[i] = tr_v_lo[i] & dcache_pkt_ready_lo[i];
    assign dcache_pkt[i].opcode = bp_be_dcache_opcode_e'(tr_data_lo[i][data_width_p+paddr_width_p+:4]);
    assign paddr_li[i] = tr_data_lo[i][data_width_p+page_offset_width_lp+:ptag_width_lp];
    assign dcache_pkt[i].page_offset = tr_data_lo[i][data_width_p+:page_offset_width_lp];
    assign dcache_pkt[i].data = tr_data_lo[i][0+:data_width_p];
    assign dcache_pkt_v_li[i] = tr_v_lo[i];
  end

  integer cnt = 0;
  always_ff @(posedge clk) begin
    if (&tr_done_lo) begin
      $display("TEST PASSED");
      $finish;
    end
    cnt = cnt + 1;
  end

endmodule
