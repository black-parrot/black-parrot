/**
 *  testbench.v
 *
 */


module testbench();
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;

  localparam bp_cfg_e cfg_lp = e_bp_half_core_cfg;
  localparam bp_proc_param_s proc_param_lp = all_cfgs_gp[cfg_lp];
  localparam dword_width_lp = proc_param_lp.dword_width;
  localparam paddr_width_lp = proc_param_lp.paddr_width;
  localparam ptag_width_lp = (paddr_width_lp-bp_page_offset_width_gp);

  localparam ring_width_lp = dword_width_lp+paddr_width_lp+4;
  localparam rom_addr_width_lp = 20;

  logic bp_clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(1000)
  ) bp_clock_gen (
    .o(bp_clk)
  );

  logic manycore_clk;
  bsg_nonsynth_clock_gen #(
    .cycle_time_p(777)
  ) manycore_clock_gen (
    .o(manycore_clk)
  );

  logic reset;
  bsg_nonsynth_reset_gen #(
    .num_clocks_p(2)
    ,.reset_cycles_lo_p(0)
    ,.reset_cycles_hi_p(8)
  ) reset_gen (
    .clk_i({bp_clk, manycore_clk})
    ,.async_reset_o(reset)
  );

  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_lp);
  bp_be_dcache_pkt_s dcache_pkt;
  logic dcache_pkt_v_li;
  logic dcache_pkt_ready_lo;
  logic [ptag_width_lp-1:0] ptag_li;

  logic dcache_v_lo;
  logic [dword_width_lp-1:0] dcache_data_lo;
 
  bp_rolly_lce_me_manycore #(
    .cfg_p(e_bp_half_core_cfg)
  ) dut (
    .bp_clk_i(bp_clk)
    ,.manycore_clk_i(manycore_clk)
    ,.reset_i(reset)

    ,.dcache_pkt_i(dcache_pkt)
    ,.dcache_pkt_v_i(dcache_pkt_v_li)
    ,.dcache_pkt_ready_o(dcache_pkt_ready_lo)
    ,.ptag_i(ptag_li)

    ,.v_o(dcache_v_lo)
    ,.data_o(dcache_data_lo)
  ); 

  // output fifo
  //
  logic fifo_v_lo;
  logic fifo_yumi_li;
  logic [dword_width_lp-1:0] fifo_data_lo;

  bsg_fifo_1r1w_small #(
    .width_p(dword_width_lp)
    ,.els_p(2**12)
  ) output_fifo (
    .clk_i(bp_clk)
    ,.reset_i(reset)

    ,.v_i(dcache_v_lo)
    ,.ready_o()
    ,.data_i(dcache_data_lo)

    ,.v_o(fifo_v_lo)
    ,.yumi_i(fifo_yumi_li)
    ,.data_o(fifo_data_lo)
  );

  // trace replay
  //
  logic tr_v_li;
  logic tr_ready_lo;
  logic [ring_width_lp-1:0] tr_data_li;  

  logic tr_v_lo;
  logic tr_yumi_li;
  logic [ring_width_lp-1:0] tr_data_lo;

  logic tr_done;

  bsg_trace_node_master #(
    .id_p(0)
    ,.ring_width_p(ring_width_lp)
    ,.rom_addr_width_p(rom_addr_width_lp)
  ) trace_node (
    .clk_i(bp_clk)
    ,.reset_i(reset)
    ,.en_i(1'b1)

    ,.v_i(tr_v_li)
    ,.ready_o(tr_ready_lo)
    ,.data_i(tr_data_li)

    ,.v_o(tr_v_lo)
    ,.yumi_i(tr_yumi_li)
    ,.data_o(tr_data_lo)

    ,.done_o(tr_done)
  );

  assign tr_v_li = fifo_v_lo; 
  assign fifo_yumi_li = fifo_v_lo & tr_ready_lo;
  assign tr_data_li = {{(ring_width_lp-dword_width_lp){1'b0}}, fifo_data_lo};

  assign dcache_pkt_v_li = tr_v_lo;
  assign tr_yumi_li = tr_v_lo & dcache_pkt_ready_lo;
  assign {dcache_pkt.opcode, ptag_li, dcache_pkt.page_offset, dcache_pkt.data} =
    tr_data_lo;


  initial begin
    wait(tr_done);
    /*
    for (integer i = 0; i < 100000; i++) begin
      @(posedge bp_clk);
    end
    */
    $finish;
  end
  
endmodule
