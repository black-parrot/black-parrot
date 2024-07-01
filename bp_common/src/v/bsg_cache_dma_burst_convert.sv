
`include "bsg_defines.sv"
`include "bsg_cache.svh"

module bsg_cache_dma_burst_convert
 #(parameter `BSG_INV_PARAM(in_addr_width_p)
   , parameter `BSG_INV_PARAM(in_data_width_p)
   , parameter `BSG_INV_PARAM(in_burst_len_p)
   , parameter `BSG_INV_PARAM(out_addr_width_p)
   , parameter `BSG_INV_PARAM(out_data_width_p)
   , parameter `BSG_INV_PARAM(out_burst_len_p)
   , localparam in_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(in_addr_width_p, in_burst_len_p)
   , localparam out_dma_pkt_width_lp = `bsg_cache_dma_pkt_width(out_addr_width_p, out_burst_len_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [in_dma_pkt_width_lp-1:0]         in_dma_pkt_i
   , input                                   in_dma_pkt_v_i
   , output logic                            in_dma_pkt_yumi_o

   , input [in_data_width_p-1:0]             in_dma_data_i
   , input                                   in_dma_data_v_i
   , output logic                            in_dma_data_yumi_o

   , output logic [in_data_width_p-1:0]      in_dma_data_o
   , output logic                            in_dma_data_v_o
   , input                                   in_dma_data_ready_and_i

   , output logic [out_dma_pkt_width_lp-1:0] out_dma_pkt_o
   , output logic                            out_dma_pkt_v_o
   , input                                   out_dma_pkt_yumi_i

   , output logic [out_data_width_p-1:0]     out_dma_data_o
   , output logic                            out_dma_data_v_o
   , input                                   out_dma_data_yumi_i

   , input [out_data_width_p-1:0]            out_dma_data_i
   , input                                   out_dma_data_v_i
   , output logic                            out_dma_data_ready_and_o
   );

  // We would love to have two of these, but there's a name collision
  //`declare_bsg_cache_dma_pkt_s(addr_width_p, vcache_block_size_in_words_p);
  logic in_dma_data_ready_and_lo;
  bsg_parallel_in_serial_out
   #(.width_p(out_data_width_p), .els_p(in_data_width_p/out_data_width_p))
   piso
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(in_dma_data_i)
     ,.valid_i(in_dma_data_v_i)
     ,.ready_and_o(in_dma_data_ready_and_lo)

     ,.data_o(out_dma_data_o)
     ,.valid_o(out_dma_data_v_o)
     ,.yumi_i(out_dma_data_yumi_i)
     );
  assign in_dma_data_yumi_o = in_dma_data_ready_and_lo & in_dma_data_v_i;

  bsg_serial_in_parallel_out_full
   #(.width_p(out_data_width_p), .els_p(in_data_width_p/out_data_width_p))
   sipo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(out_dma_data_i)
     ,.v_i(out_dma_data_v_i)
     ,.ready_o(out_dma_data_ready_and_o)

     ,.data_o(in_dma_data_o)
     ,.v_o(in_dma_data_v_o)
     ,.yumi_i(in_dma_data_ready_and_i & in_dma_data_v_o)
     );

  localparam burst_ratio_lp = (in_data_width_p*in_burst_len_p)/(out_data_width_p*out_burst_len_p);
  logic [`BSG_WIDTH(burst_ratio_lp)-1:0] burst_cnt;
  logic burst_last;
  bsg_counter_clear_up
   #(.max_val_p(burst_ratio_lp), .init_val_p(0), .disable_overflow_warning_p(1))
   pkt_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(in_dma_pkt_yumi_o)
     ,.up_i(out_dma_pkt_yumi_i & ~burst_last)
     ,.count_o(burst_cnt)
     );
  assign burst_last = (burst_cnt == burst_ratio_lp-1);
  assign in_dma_pkt_yumi_o = burst_last & out_dma_pkt_yumi_i;

  localparam in_burst_offset_lp = `BSG_SAFE_CLOG2(in_data_width_p*in_burst_len_p/8);
  localparam out_burst_offset_lp = `BSG_SAFE_CLOG2(out_data_width_p*out_burst_len_p/8);
  always_comb
    begin
      out_dma_pkt_v_o = in_dma_pkt_v_i;
      out_dma_pkt_o = in_dma_pkt_i;
      out_dma_pkt_o[0+:out_addr_width_p] = {in_dma_pkt_i[in_addr_width_p-1:in_burst_offset_lp], {burst_ratio_lp>1{burst_cnt}}, out_burst_offset_lp'('0)};
    end

  if (in_data_width_p < out_data_width_p)
    $error("Module doesn't currently support upsizing data");

  if (!`BSG_IS_POW2(burst_ratio_lp))
    $error("Module currently supports pow2 burst ratios");

endmodule

