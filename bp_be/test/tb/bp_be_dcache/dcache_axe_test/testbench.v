/**
 *  testbench.v
 */

`include "bp_be_dcache_pkt.vh"

module testbench();
  import bp_common_pkg::*;
  import bp_be_dcache_pkg::*;

  // parameters
  //
  localparam data_width_p = 64;
  localparam sets_p = 16;
  localparam ways_p = 8;
  localparam paddr_width_p = bp_sv39_paddr_width_gp;
  localparam num_cce_p = 1;
  localparam num_lce_p = `NUM_LCE_P;
  localparam mem_els_p = sets_p*ways_p*ways_p;
  localparam instr_count = `NUM_INSTR_P;
  localparam num_cce_inst_ram_els_p = 256;

  localparam data_mask_width_lp=(data_width_p>>3);
  localparam block_size_in_words_lp=ways_p;
  localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp);
  localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp);
  localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p);
  localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp);

  localparam lce_data_width_lp=(ways_p*data_width_p);

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
  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, data_width_p);
  bp_be_dcache_pkt_s [num_lce_p-1:0] dcache_pkt;
  logic [num_lce_p-1:0] dcache_pkt_v_li;
  logic [num_lce_p-1:0] dcache_pkt_ready_lo;
  logic [num_lce_p-1:0][ptag_width_lp-1:0] ptag_li;

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
    assign dcache_pkt[i].opcode = bp_be_dcache_opcode_e'(tr_data_lo[i][data_width_p+paddr_width_p+:4]);
    assign ptag_li[i] = tr_data_lo[i][data_width_p+bp_page_offset_width_gp+:ptag_width_lp];
    assign dcache_pkt[i].page_offset = tr_data_lo[i][data_width_p+:bp_page_offset_width_gp];
    assign dcache_pkt[i].data = tr_data_lo[i][0+:data_width_p];
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

  initial begin
    wait(&dcache_done);
    $finish;
  end

endmodule
