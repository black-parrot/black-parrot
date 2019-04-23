/**
 *  testbench.v
 */

`include "bp_be_dcache_pkt.vh"

module testbench
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
    `declare_bp_proc_params(cfg_p)

    , localparam num_mem_p = 1
    , localparam mem_els_p = 2*lce_sets_p*lce_assoc_p

    , localparam instr_count = `NUM_INSTR_P

    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
    , localparam tr_rom_addr_width_p = 20

		, parameter cce_trace_p = `CCE_TRACE_P
		, parameter axe_trace_p = `AXE_TRACE_P

`declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  )
  ();

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
  logic [num_lce_p-1:0][tr_ring_width_lp-1:0] tr_data_li;
  logic [num_lce_p-1:0] tr_ready_lo;

  logic [num_lce_p-1:0] tr_v_lo;
  logic [num_lce_p-1:0][tr_ring_width_lp-1:0] tr_data_lo;
  logic [num_lce_p-1:0] tr_yumi_li;


  bp_me_mock_lce_me #(
    .cfg_p(cfg_p)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_els_p(mem_els_p)
		,.cce_trace_p(cce_trace_p)
		,.axe_trace_p(axe_trace_p)
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
      ,.ring_width_p(tr_ring_width_lp)
      ,.rom_addr_width_p(tr_rom_addr_width_p)
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

  always_ff @(posedge clk)
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
