/**
 *  testbench.v
 */

`include "bp_be_dcache_pkt.vh"

module bp_me_random_demo_top
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;
  #()
  (input clk_i
   ,input reset_i
   ,output logic done_o
   );
  // parameters
  //
  localparam data_width_p = 64;
  localparam sets_p = 16;
  localparam ways_p = 8;
  localparam paddr_width_p = 56;
  localparam num_cce_p = 1;
  localparam num_lce_p = 1;
  localparam num_mem_p = 1;
  localparam mem_els_p = 2*num_lce_p*sets_p*ways_p;
  localparam instr_count = `NUM_INSTR_P;
  localparam num_cce_inst_ram_els_p = 256;

  localparam word_offset_width_lp=`BSG_SAFE_CLOG2(ways_p);
  localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p);
  localparam data_mask_width_lp=(data_width_p>>3);
  localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp);
  localparam page_offset_width_lp=bp_page_offset_width_gp;
  localparam ptag_width_lp=paddr_width_p-page_offset_width_lp;

  localparam lce_data_width_lp=ways_p*data_width_p;
  localparam bp_be_dcache_pkt_width_lp=`bp_be_dcache_pkt_width(page_offset_width_lp, data_width_p);

  localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, ways_p, data_width_p);
  localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p);
  localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_lp);
  localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, ways_p);
  localparam lce_data_cmd_width_lp=`bp_lce_data_cmd_width(num_lce_p, lce_data_width_lp, ways_p);
  localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, paddr_width_p, lce_data_width_lp, ways_p);

  localparam ring_width_p = data_width_p+paddr_width_p+4;
  localparam rom_addr_width_p = 20;

  /*
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
  */
 
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
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_els_p(mem_els_p)
    ,.num_cce_inst_ram_els_p(num_cce_inst_ram_els_p)
  ) dcache_cce_mem (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
  
    ,.dcache_pkt_i(dcache_pkt)
    ,.dcache_pkt_v_i(dcache_pkt_v_li)
    ,.dcache_pkt_ready_o(dcache_pkt_ready_lo)
    ,.ptag_i(paddr_li)

    ,.v_o(dcache_v_lo)
    ,.data_o(dcache_data_lo)
  );

  // trace node master
  //
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_li;

  logic [num_lce_p-1:0] tr_v_lo;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_lo;
  logic [num_lce_p-1:0] tr_yumi_li;

  logic [num_lce_p-1:0] tr_done_lo;

  assign done_o = &tr_done_lo;
  
  for (genvar i = 0; i < num_lce_p; i++) begin

    bsg_trace_node_master #(
      .id_p(i)
      ,.ring_width_p(ring_width_p)
      ,.rom_addr_width_p(rom_addr_width_p)
    ) trace_node_master (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(1'b1)

      ,.v_i(dcache_v_lo[i])
      ,.data_i(tr_data_li[i])
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

    assign tr_data_li[i][data_width_p-1:0] = dcache_data_lo[i];
    assign tr_data_li[i][ring_width_p-1:data_width_p] = '0;
  end

  logic booted;

  localparam max_clock_cnt_lp    = 2**30-1;
  localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
  logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_clock_cnt_lp)
     ,.init_val_p(0)
     )
   clock_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(~booted)
     ,.up_i(1'b1)

     ,.count_o(clock_cnt)
     );

  always_ff @(posedge clk_i)
    begin
      if (reset_i)
          booted <= 1'b0;
      else
        begin
          booted <= booted | (|dcache_pkt_ready_lo); // Booted when dcaches are ready
        end
    end

  always_ff @(posedge clk_i)
    begin
      if (&tr_done_lo)
        begin
        $display("Bytes: %d Clocks: %d mBPC: %d "
                 , instr_count*64
                 , clock_cnt
                 , (instr_count*64*1000) / clock_cnt
                 );
        $finish(0);
        end
    end

endmodule
