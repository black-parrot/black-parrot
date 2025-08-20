
/**
 * bp_nonsynth_dram.v
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_nonsynth_dram
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter `BSG_INV_PARAM(num_dma_p)
   , parameter `BSG_INV_PARAM(dma_addr_width_p)
   , parameter `BSG_INV_PARAM(dma_data_width_p)
   , parameter `BSG_INV_PARAM(dma_burst_len_p)
   , parameter `BSG_INV_PARAM(dma_mask_width_p)
   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(dma_addr_width_p, dma_mask_width_p)

   , parameter mem_str_p = "init_mem"
   )
  (input                                                    clk_i
   , input                                                  reset_i

   , input [num_dma_p-1:0][dma_pkt_width_lp-1:0]            dma_pkt_i
   , input [num_dma_p-1:0]                                  dma_pkt_v_i
   , output logic [num_dma_p-1:0]                           dma_pkt_yumi_o

   , output logic [num_dma_p-1:0][dma_data_width_p-1:0]     dma_data_o
   , output logic [num_dma_p-1:0]                           dma_data_v_o
   , input [num_dma_p-1:0]                                  dma_data_ready_and_i

   , input [num_dma_p-1:0][dma_data_width_p-1:0]            dma_data_i
   , input [num_dma_p-1:0]                                  dma_data_v_i
   , output logic [num_dma_p-1:0]                           dma_data_yumi_o
   );

  localparam tag_width_lp = `BSG_SAFE_CLOG2(num_dma_p);
  localparam word_offset_lp = `BSG_SAFE_CLOG2(dma_data_width_p>>3);
  localparam count_width_lp = `BSG_SAFE_CLOG2(dma_burst_len_p);

  `declare_bsg_cache_dma_pkt_s(dma_addr_width_p, dma_mask_width_p);

  bsg_cache_dma_pkt_s rr_pkt_lo;
  logic [tag_width_lp-1:0] rr_tag_lo;
  logic rr_v_lo, rr_ready_and_li;
  bsg_round_robin_n_to_1
   #(.width_p(dma_pkt_width_lp)
     ,.num_in_p(num_dma_p)
     ,.strict_p(0)
     )
   rr
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(dma_pkt_i)
    ,.v_i(dma_pkt_v_i)
    ,.yumi_o(dma_pkt_yumi_o)

    ,.v_o(rr_v_lo)
    ,.data_o(rr_pkt_lo)
    ,.tag_o(rr_tag_lo)
    ,.yumi_i(rr_ready_and_li & rr_v_lo)
    );

  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic [tag_width_lp-1:0] dma_pkt_tag_lo;
  logic dma_pkt_v_lo, dma_pkt_yumi_li;
  bsg_two_fifo
   #(.width_p(dma_pkt_width_lp+tag_width_lp))
   two_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({rr_pkt_lo, rr_tag_lo})
     ,.v_i(rr_v_lo)
     ,.ready_param_o(rr_ready_and_li)

     ,.data_o({dma_pkt_lo, dma_pkt_tag_lo})
     ,.v_o(dma_pkt_v_lo)
     ,.yumi_i(dma_pkt_yumi_li)
     );

  logic clear_li, up_li;
  logic [count_width_lp-1:0] count_lo;
  bsg_counter_clear_up
   #(.max_val_p(dma_burst_len_p-1), .init_val_p(0), .disable_overflow_warning_p(1))
   counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(clear_li)
     ,.up_i(up_li)
     ,.count_o(count_lo)
     );

  localparam mem_size_p = 2**25;
  logic [7:0] mem [int];
  logic [(dma_data_width_p>>3)-1:0][7:0] mem_wdata, mem_rdata;
  logic [`BSG_SAFE_CLOG2(mem_size_p)-1:0] mem_raddr, mem_waddr;
  logic mem_write, mem_read;
  wire [dma_addr_width_p-1:0] base_addr = {
      dma_pkt_lo.addr[dma_addr_width_p-1:word_offset_lp+count_width_lp],
      {dma_burst_len_p>1{count_lo}},
      {word_offset_lp{1'b0}}
      };

  string mem_file;
  initial
    if ($value$plusargs({mem_str_p,"=%s"}, mem_file))
      begin
        $display("BSG-INFO: Initalizing mem with mem_str_p=%s", mem_file);
        $readmemh(mem_file, mem);
      end

  always_ff @(posedge clk_i)
    for (int i = 0; i < dma_data_width_p/8; i++)
        if (mem_write) mem[mem_waddr+i] <= mem_wdata[i];

  always_ff @(posedge clk_i)
    for (int i = 0; i < dma_data_width_p/8; i++)
        if (mem_read) mem_rdata[i] <= mem.exists(mem_raddr+i) ? mem[mem_raddr+i] : '0;

  enum logic [1:0] { e_ready, e_read, e_write } state_n, state_r;
  wire is_ready = (state_r == e_ready);
  wire is_read = (state_r == e_read);
  wire is_write = (state_r == e_write);

  always_comb
    begin
      state_n = state_r;

      clear_li = '0;
      up_li = '0;
      dma_pkt_yumi_li = '0;

      dma_data_o = '0;
      dma_data_v_o = '0;
      dma_data_yumi_o = '0;

      mem_raddr = '0;
      mem_waddr = '0;
      mem_read = '0;
      mem_write = '0;
      mem_wdata = '0;

      case (state_r)
        e_ready:
          begin
            mem_read = dma_pkt_v_lo & !dma_pkt_lo.write_not_read;
            mem_raddr = base_addr;

            state_n = dma_pkt_v_lo ? mem_read ? e_read : e_write : state_r;
          end
        e_read:
          begin
            dma_data_o[dma_pkt_tag_lo] = mem_rdata;
            dma_data_v_o[dma_pkt_tag_lo] = 1'b1;

            up_li = dma_data_ready_and_i[dma_pkt_tag_lo] & dma_data_v_o[dma_pkt_tag_lo];
            dma_pkt_yumi_li = up_li & (count_lo == dma_burst_len_p-1);

            mem_read = up_li & (count_lo != dma_burst_len_p-1);
            mem_raddr = base_addr + (1'b1 << word_offset_lp);

            state_n = dma_pkt_yumi_li ? e_ready : state_r;
          end
        e_write:
          begin
            dma_data_yumi_o[dma_pkt_tag_lo] = dma_data_v_i[dma_pkt_tag_lo];

            up_li = dma_data_yumi_o[dma_pkt_tag_lo];
            dma_pkt_yumi_li = up_li & (count_lo == dma_burst_len_p-1);

            mem_write = up_li;
            mem_waddr = base_addr;
            mem_wdata = dma_data_i[dma_pkt_tag_lo];

            state_n = dma_pkt_yumi_li ? e_ready : state_r;
          end
        default: begin end
      endcase
    end

  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

endmodule

