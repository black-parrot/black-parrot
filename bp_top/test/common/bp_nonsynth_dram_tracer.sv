

`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_nonsynth_dram_tracer
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter `BSG_INV_PARAM(num_dma_p)
   , parameter `BSG_INV_PARAM(dma_addr_width_p)
   , parameter `BSG_INV_PARAM(dma_data_width_p)
   , parameter `BSG_INV_PARAM(dma_burst_len_p)
   , parameter `BSG_INV_PARAM(dma_mask_width_p)

   , parameter string trace_str_p = ""
   )
  (input         clk_i
   , input        reset_i
   , input        en_i
   );

  localparam tag_width_lp = `BSG_SAFE_CLOG2(num_dma_p);

  `declare_bsg_cache_dma_pkt_s(dma_addr_width_p, dma_mask_width_p);

  // snoop
  wire bsg_cache_dma_pkt_s dma_pkt = bp_nonsynth_dram.dma_pkt_lo;
  wire [tag_width_lp-1:0] dma_pkt_tag = bp_nonsynth_dram.dma_pkt_tag_lo;

  wire mem_req = bp_nonsynth_dram.is_ready & bp_nonsynth_dram.dma_pkt_v_lo;
  wire mem_write = bp_nonsynth_dram.mem_write;
  wire mem_read = bp_nonsynth_dram.mem_read;

  wire [dma_data_width_p-1:0] mem_wdata = bp_nonsynth_dram.mem_wdata;
  wire [dma_data_width_p-1:0] mem_rdata = bp_nonsynth_dram.mem_rdata;

  // process
  logic mem_read_r; always_ff @(posedge clk_i) mem_read_r <= mem_read;

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, 1'b0);
  always_ff @(posedge clk_i)
    if (is_go)
      begin
        if (mem_req & dma_pkt.write_not_read)
          $fdisplay(file, "%8t | channel %d write request addr: %x", $time, dma_pkt_tag, dma_pkt.addr);
        if (mem_req & ~dma_pkt.write_not_read)
          $fdisplay(file, "%8t | channel %d read request addr: %x", $time, dma_pkt_tag, dma_pkt.addr);

        if (mem_read_r)
          $fdisplay(file, "\tread data: %x", mem_rdata);
        if (mem_write)
          $fdisplay(file, "\twrite data: %x", mem_wdata);
      end

endmodule

