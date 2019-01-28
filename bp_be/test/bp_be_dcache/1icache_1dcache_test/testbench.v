/**
 *  testbench.v
 */

`include "bp_dcache_pkt.vh"
`include "bp_common_me_if.vh"

module testbench;

  // parameters
  //
  localparam data_width_p = 64;
  localparam inst_width_p = 32;
  localparam sets_p = 64;
  localparam ways_p = 8;
  localparam tag_width_p = 10;
  localparam num_core_p = 1;
  localparam num_cce_p = 1;
  localparam num_lce_p = num_core_p*2;
  localparam num_mem_p = 1;
  localparam boot_rom_els_p = 512;

  localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p);
  localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p);
  localparam data_mask_width_lp=(data_width_p>>3);
  localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp);
  localparam vaddr_width_lp=lg_ways_lp+lg_sets_lp+lg_data_mask_width_lp;
  localparam lce_addr_width_lp=vaddr_width_lp+tag_width_p;
  localparam lce_data_width_lp=ways_p*data_width_p;
  localparam bp_dcache_pkt_width_lp=`bp_dcache_pkt_width(vaddr_width_lp, data_width_p);

  localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, lce_addr_width_lp, ways_p);
  localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, lce_addr_width_lp);
  localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, lce_addr_width_lp, lce_data_width_lp);
  localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, lce_addr_width_lp, ways_p, 4);
  localparam cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, lce_addr_width_lp, lce_data_width_lp, ways_p);
  localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, lce_addr_width_lp, lce_data_width_lp, ways_p);

  localparam ring_width_p = data_width_p+vaddr_width_lp+tag_width_p+4;
  localparam rom_addr_width_p = 20;

  localparam output_fifo_els_p = 2**14;

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

  // declare structs 
  //
  `declare_bp_dcache_pkt_s(vaddr_width_lp, data_width_p);

  // mem subsystem under test
  //
  logic [num_core_p-1:0][lce_addr_width_lp-1:0] icache_addr_li;
  logic [num_core_p-1:0] icache_addr_v_li;
  logic [num_core_p-1:0] icache_addr_ready_lo;

  logic [num_core_p-1:0] icache_v_lo;
  logic [num_core_p-1:0][inst_width_p-1:0] icache_data_lo;

  bp_dcache_pkt_s [num_core_p-1:0] dcache_pkt_li;
  logic [num_core_p-1:0] dcache_pkt_v_li;
  logic [num_core_p-1:0] dcache_pkt_ready_lo;
  logic [num_core_p-1:0][tag_width_p-1:0] dcache_paddr_li;

  logic [num_core_p-1:0] dcache_v_lo;
  logic [num_core_p-1:0][data_width_p-1:0] dcache_data_lo;

  logic all_cache_ready_lo;

  bp_icache_dcache #(
    .data_width_p(data_width_p)
    ,.sets_p(sets_p)
    ,.ways_p(ways_p)
    ,.tag_width_p(tag_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_mem_p(num_mem_p)
    ,.num_core_p(num_core_p)
    ,.inst_width_p(inst_width_p)
    ,.boot_rom_els_p(boot_rom_els_p)
  ) icache_dcache (
    .clk_i(clk)
    ,.reset_i(reset)
 
    ,.icache_addr_i(icache_addr_li)
    ,.icache_addr_v_i(icache_addr_v_li)
    ,.icache_addr_ready_o(icache_addr_ready_lo)
    
    ,.icache_v_o(icache_v_lo)
    ,.icache_data_o(icache_data_lo)

    ,.dcache_pkt_i(dcache_pkt_li)
    ,.dcache_paddr_i(dcache_paddr_li)
    ,.dcache_pkt_v_i(dcache_pkt_v_li)
    ,.dcache_pkt_ready_o(dcache_pkt_ready_lo)

    ,.dcache_v_o(dcache_v_lo)
    ,.dcache_data_o(dcache_data_lo)

    ,.all_cache_ready_o(all_cache_ready_lo)
  );

  // trace node master
  //
  logic [num_lce_p-1:0] tr_v_li;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_li;
  logic [num_lce_p-1:0] tr_ready_lo;

  logic [num_lce_p-1:0] tr_v_lo;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_lo;
  logic [num_lce_p-1:0] tr_yumi_li;

  logic [num_lce_p-1:0] tr_done_lo;
  
  for (genvar i = 0; i < num_lce_p; i++) begin
    if (i % 2 == 0) begin
      bsg_trace_node_master #(
        .id_p(i)
        ,.ring_width_p(ring_width_p)
        ,.rom_addr_width_p(rom_addr_width_p)
      ) icache_trace_node_master (
        .clk_i(clk)
        ,.reset_i(reset)
        ,.en_i(all_cache_ready_lo)

        ,.v_i(tr_v_li[i])
        ,.data_i(tr_data_li[i])
        ,.ready_o(tr_ready_lo[i])

        ,.v_o(tr_v_lo[i])
        ,.yumi_i(tr_yumi_li[i])
        ,.data_o(tr_data_lo[i])

        ,.done_o(tr_done_lo[i])
      );

      assign tr_yumi_li[i] = tr_v_lo[i] & icache_addr_ready_lo[i/2];
      assign icache_addr_li[i/2] = tr_data_lo[i][data_width_p+:lce_addr_width_lp];
      assign icache_addr_v_li[i] = tr_v_lo[i];

    end
    else begin
      bsg_trace_node_master #(
        .id_p(i)
        ,.ring_width_p(ring_width_p)
        ,.rom_addr_width_p(rom_addr_width_p)
      ) dcache_trace_node_master (
        .clk_i(clk)
        ,.reset_i(reset)
        ,.en_i(all_cache_ready_lo)

        ,.v_i(tr_v_li[i])
        ,.data_i(tr_data_li[i])
        ,.ready_o(tr_ready_lo[i])

        ,.v_o(tr_v_lo[i])
        ,.yumi_i(tr_yumi_li[i])
        ,.data_o(tr_data_lo[i])

        ,.done_o(tr_done_lo[i])
      );
    
      assign tr_yumi_li[i] = tr_v_lo[i] & dcache_pkt_ready_lo[i/2];
      assign dcache_paddr_li[i/2] = tr_data_lo[i][data_width_p+vaddr_width_lp+:tag_width_p];
      assign dcache_pkt_li[i/2].opcode = bp_dcache_opcode_e'(tr_data_lo[i][data_width_p+vaddr_width_lp+tag_width_p+:4]);
      assign dcache_pkt_li[i/2].vaddr = tr_data_lo[i][data_width_p+:vaddr_width_lp];
      assign dcache_pkt_li[i/2].data = tr_data_lo[i][0+:data_width_p];
      assign dcache_pkt_v_li[i/2] = tr_v_lo[i];
    end

  end




  // output fifo
  //
  logic [num_lce_p-1:0] output_fifo_v_lo;
  logic [num_core_p-1:0][inst_width_p-1:0] icache_output_fifo_data_lo;
  logic [num_core_p-1:0][data_width_p-1:0] dcache_output_fifo_data_lo;
  logic [num_lce_p-1:0] output_fifo_yumi_li;

  for (genvar i = 0; i < num_lce_p; i++) begin
    if (i % 2 == 0) begin
      bsg_fifo_1r1w_large #(
        .width_p(inst_width_p)
        ,.els_p(output_fifo_els_p)
      ) icache_output_fifo (
        .clk_i(clk)
        ,.reset_i(reset)

        ,.v_i(icache_v_lo[i/2])
        ,.ready_o()
        ,.data_i(icache_data_lo[i/2])

        ,.v_o(tr_v_li[i])
        ,.data_o(tr_data_li[i][inst_width_p-1:0])
        ,.yumi_i(output_fifo_yumi_li[i])
      );

      assign tr_data_li[i][ring_width_p-1:inst_width_p] = '0;
      assign output_fifo_yumi_li[i] = tr_v_li[i] & tr_ready_lo[i];
    end
    else begin
      bsg_fifo_1r1w_large #(
        .width_p(data_width_p)
        ,.els_p(output_fifo_els_p)
      ) dcache_output_fifo (
        .clk_i(clk)
        ,.reset_i(reset)

        ,.v_i(dcache_v_lo[i/2])
        ,.ready_o()
        ,.data_i(dcache_data_lo[i/2])

        ,.v_o(tr_v_li[i])
        ,.data_o(tr_data_li[i][data_width_p-1:0])
        ,.yumi_i(output_fifo_yumi_li[i])
      );
      
      assign tr_data_li[i][ring_width_p-1:data_width_p] = '0;
      assign output_fifo_yumi_li[i] = tr_v_li[i] & tr_ready_lo[i];
    end
  end

  initial begin
    wait(&tr_done_lo);
//    for (integer i =0; i < 10000; i++) begin
//      @(posedge clk);
//    end
    $finish;
  end

endmodule
