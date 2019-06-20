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

    // parameters
    //
    //, localparam num_lce_p = `NUM_LCE_P
    , localparam mem_els_p = 2*num_lce_p*lce_sets_p*lce_assoc_p
    , localparam instr_count = `NUM_INSTR_P

    , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)

    , localparam ring_width_p = dword_width_p+paddr_width_p+4
    , localparam rom_addr_width_p = 20
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
  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_p);
  bp_be_dcache_pkt_s [num_lce_p-1:0] dcache_pkt;
  logic [num_lce_p-1:0] dcache_pkt_v_li;
  logic [num_lce_p-1:0] dcache_pkt_ready_lo;
  logic [num_lce_p-1:0][ptag_width_lp-1:0] ptag_li;

  logic [num_lce_p-1:0] dcache_v_lo;
  logic [num_lce_p-1:0][dword_width_p-1:0] dcache_data_lo;

  bp_rolly_lce_me #(
    .cfg_p(cfg_p)
    ,.mem_els_p(mem_els_p)
    ,.boot_rom_els_p(mem_els_p)
  ) dcache_cce_mem (
    .clk_i(clk)
    ,.reset_i(reset)
  
    ,.dcache_pkt_i(dcache_pkt)
    ,.dcache_pkt_v_i(dcache_pkt_v_li)
    ,.dcache_pkt_ready_o(dcache_pkt_ready_lo)
    ,.ptag_i(ptag_li)

    ,.v_o(dcache_v_lo)
    ,.data_o(dcache_data_lo)
  );

  // trace node master
  //
  logic [num_lce_p-1:0] tr_v_lo;
  logic [num_lce_p-1:0][ring_width_p-1:0] tr_data_lo;
  logic [num_lce_p-1:0] tr_yumi_li;
  
  for (genvar i = 0; i < num_lce_p; i++) begin

    bsg_trace_node_master #(
      .id_p(i)
      ,.ring_width_p(ring_width_p)
      ,.rom_addr_width_p(rom_addr_width_p)
    ) trace_node_master (
      .clk_i(clk)
      ,.reset_i(reset)
      ,.en_i(1'b1)

      ,.v_i(1'b0)
      ,.data_i('0)
      ,.ready_o()

      ,.v_o(tr_v_lo[i])
      ,.yumi_i(tr_yumi_li[i])
      ,.data_o(tr_data_lo[i])

      ,.done_o()
    );
    
    assign tr_yumi_li[i] = tr_v_lo[i] & dcache_pkt_ready_lo[i];
    assign dcache_pkt[i].opcode = bp_be_dcache_opcode_e'(tr_data_lo[i][dword_width_p+paddr_width_p+:4]);
    assign ptag_li[i] = tr_data_lo[i][dword_width_p+bp_page_offset_width_gp+:ptag_width_lp];
    assign dcache_pkt[i].page_offset = tr_data_lo[i][dword_width_p+:bp_page_offset_width_gp];
    assign dcache_pkt[i].data = tr_data_lo[i][0+:dword_width_p];
    assign dcache_pkt_v_li[i] = tr_v_lo[i];
  end

  logic [num_lce_p-1:0] dcache_done;
  logic [num_lce_p-1:0][31:0] dcache_v_count;
  
  always_ff @ (posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < num_lce_p; i++) begin
        dcache_v_count[i] <= '0;
      end 
    end
    else begin
      for (integer i = 0; i < num_lce_p; i++) begin
        dcache_v_count[i] <= dcache_v_lo[i]
          ? dcache_v_count[i] + 1
          : dcache_v_count[i];
      end
    end 
  end

  always_comb begin
    for (integer i = 0; i < num_lce_p; i++) begin
      dcache_done[i] = (dcache_v_count[i] == instr_count);
    end
  end

  /*
  logic [31:0] counter;
  always_ff @(posedge clk) begin
    if (reset) begin
      counter <= '0;
    end else begin
      counter <= counter + 'd1;
      if (counter == 1000000) begin
        $error("stalled!");
        $finish;
      end
    end
  end
  */

  initial begin
    wait(&dcache_done);
    //for (int i = 0; i < 1000000; i++) begin
    //  @(posedge clk);
    //end
    $finish;
  end

endmodule
