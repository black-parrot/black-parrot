/**
 *  testbench.v
 */

`include "bp_be_dcache_pkt.vh"

module testbench();
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;

  // parameters
  //
  localparam bp_cfg_e cfg_p = BP_CFG_FLOWVAR;

  localparam data_width_p = 64;
  localparam sets_p = 16;
  localparam ways_p = 8;
  localparam paddr_width_p = 39;
  localparam num_cce_p = 1;
  localparam num_lce_p = 1;
  localparam num_mem_p = 1;
  localparam mem_els_p = 2*sets_p*ways_p;
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

  localparam ring_width_p = data_width_p+paddr_width_p+4;
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
  logic [num_lce_p-1:0] tr_v_li;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_li;
  logic [num_lce_p-1:0] tr_ready_lo;

  logic [num_lce_p-1:0] tr_v_lo;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_lo;
  logic [num_lce_p-1:0] tr_yumi_li;


  bp_me_mock_lce_me #(
    .cfg_p(cfg_p)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_els_p(mem_els_p)
  ) mock_lce_me (
    .clk_i(clk)
    ,.reset_i(reset)
 
    ,.tr_pkt_i(tr_data_lo)
    ,.tr_pkt_v_i(tr_v_lo)
    ,.tr_pkt_yumi_o(tr_yumi_li)

    ,.tr_pkt_o(tr_data_li)
    ,.tr_pkt_v_o(tr_v_li)
    ,.tr_pkt_ready_i(tr_ready_lo)
  );

  // trace node master
  //
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

      ,.v_i(tr_v_li[i])
      ,.data_i(tr_data_li[i])
      ,.ready_o(tr_ready_lo[i])

      ,.v_o(tr_v_lo[i])
      ,.yumi_i(tr_yumi_li[i])
      ,.data_o(tr_data_lo[i])

      ,.done_o(tr_done_lo[i])
    );
    
  end

  //logic booted;

  localparam max_clock_cnt_lp    = 2**30-1;
  localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);
  logic [lg_max_clock_cnt_lp-1:0] clock_cnt;

  bsg_counter_clear_up
   #(.max_val_p(max_clock_cnt_lp)
     ,.init_val_p(0)
     )
   clock_counter
    (.clk_i(clk)
     ,.reset_i(reset)

     ,.clear_i(reset)
     ,.up_i(1'b1)

     ,.count_o(clock_cnt)
     );
  /*
  always_ff @(posedge clk)
    begin
      if (reset)
          booted <= 1'b0;
      else
        begin
          booted <= booted | (|dcache_pkt_ready_lo); // Booted when dcaches are ready
        end
    end
  */
  always_ff @(posedge clk)
    begin
      if (clock_cnt == 100000) begin
        $finish(0);
      end
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
