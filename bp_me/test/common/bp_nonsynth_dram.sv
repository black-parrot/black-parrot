
/**
 * bp_nonsynth_dram.v
 */

`define dram_pkg bsg_dramsim3_lpddr3_8gb_x32_1600_pkg

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_nonsynth_dram
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_axi_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , parameter num_dma_p = 0
   , parameter preload_mem_p = 0
   , parameter mem_bytes_p = 0
   , parameter dram_type_p = ""
   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p, l2_block_size_in_words_p)
   )
  (input                                                    clk_i
   , input                                                  reset_i

   , input [num_dma_p-1:0][dma_pkt_width_lp-1:0]            dma_pkt_i
   , input [num_dma_p-1:0]                                  dma_pkt_v_i
   , output logic [num_dma_p-1:0]                           dma_pkt_yumi_o

   , output logic [num_dma_p-1:0][l2_fill_width_p-1:0]      dma_data_o
   , output logic [num_dma_p-1:0]                           dma_data_v_o
   , input [num_dma_p-1:0]                                  dma_data_ready_and_i

   , input [num_dma_p-1:0][l2_fill_width_p-1:0]             dma_data_i
   , input [num_dma_p-1:0]                                  dma_data_v_i
   , output logic [num_dma_p-1:0]                           dma_data_yumi_o

   , input                                                  dram_clk_i
   , input                                                  dram_reset_i
   );

  if (dram_type_p == "dmc")
    begin : ddr
      bp_ddr
       #(.bp_params_p(bp_params_p), .num_dma_p(num_dma_p))
       ddr
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dma_pkt_i(dma_pkt_i)
         ,.dma_pkt_v_i(dma_pkt_v_i)
         ,.dma_pkt_yumi_o(dma_pkt_yumi_o)

         ,.dma_data_o(dma_data_o)
         ,.dma_data_v_o(dma_data_v_o)
         ,.dma_data_ready_i(dma_data_ready_and_i)

         ,.dma_data_i(dma_data_i)
         ,.dma_data_v_i(dma_data_v_i)
         ,.dma_data_yumi_o(dma_data_yumi_o)
         );

      if (preload_mem_p)
        begin : preload
          $error("Preloading is not supported for DDR");
        end
    end
  else if (dram_type_p == "dramsim3")
    begin : dramsim3
      `dram_pkg::dram_ch_addr_s dram_read_done_ch_addr_lo;

       logic [`dram_pkg::channel_addr_width_p-1:0] dram_ch_addr_li;
       logic dram_write_not_read_li, dram_v_li, dram_yumi_lo;
       logic [`dram_pkg::data_width_p-1:0] dram_data_li;
       logic [(`dram_pkg::data_width_p>>3)-1:0] dram_mask_li;

       logic dram_data_v_li, dram_data_yumi_lo;
       logic [`dram_pkg::data_width_p-1:0] dram_data_lo;
       logic dram_data_v_lo;

       if (num_dma_p & (num_dma_p-1) != 0)
         begin : npot
           $error("bsg_cache_to_test_dram doesn't support NPOT number of caches. Use AXI mem instead");
         end

       // TODO: May need to use actual hash function
       localparam cache_bank_addr_width_lp = `dram_pkg::channel_addr_width_p - `BSG_SAFE_CLOG2(num_dma_p);
       bsg_cache_to_test_dram
        #(.num_cache_p(num_dma_p)
          ,.addr_width_p(daddr_width_p)
          ,.data_width_p(l2_data_width_p)
          ,.block_size_in_words_p(l2_block_size_in_words_p)
          ,.cache_bank_addr_width_p(cache_bank_addr_width_lp)
          ,.dma_data_width_p(l2_fill_width_p)

          ,.dram_channel_addr_width_p(`dram_pkg::channel_addr_width_p)
          ,.dram_data_width_p(`dram_pkg::data_width_p)
          )
        cache_to_tram
        (.core_clk_i(clk_i)
         ,.core_reset_i(reset_i)

         ,.dma_pkt_i(dma_pkt_i)
         ,.dma_pkt_v_i(dma_pkt_v_i)
         ,.dma_pkt_yumi_o(dma_pkt_yumi_o)

         ,.dma_data_o(dma_data_o)
         ,.dma_data_v_o(dma_data_v_o)
         ,.dma_data_ready_and_i(dma_data_ready_and_i)

         ,.dma_data_i(dma_data_i)
         ,.dma_data_v_i(dma_data_v_i)
         ,.dma_data_yumi_o(dma_data_yumi_o)

         ,.dram_clk_i(dram_clk_i)
         ,.dram_reset_i(dram_reset_i)

         ,.dram_req_v_o(dram_v_li)
         ,.dram_write_not_read_o(dram_write_not_read_li)
         ,.dram_ch_addr_o(dram_ch_addr_li)
         ,.dram_req_yumi_i(dram_yumi_lo)
         ,.dram_data_v_o(dram_data_v_li)
         ,.dram_data_o(dram_data_li)
         ,.dram_mask_o(dram_mask_li)
         ,.dram_data_yumi_i(dram_data_yumi_lo)

         ,.dram_data_v_i(dram_data_v_lo)
         ,.dram_data_i(dram_data_lo)
         ,.dram_ch_addr_i(dram_read_done_ch_addr_lo)
         );

       bsg_nonsynth_dramsim3
        #(.channel_addr_width_p(`dram_pkg::channel_addr_width_p)
          ,.data_width_p(`dram_pkg::data_width_p)
          ,.num_channels_p(`dram_pkg::num_channels_p)
          ,.num_columns_p(`dram_pkg::num_columns_p)
          ,.num_rows_p(`dram_pkg::num_rows_p)
          ,.num_ba_p(`dram_pkg::num_ba_p)
          ,.num_bg_p(`dram_pkg::num_bg_p)
          ,.num_ranks_p(`dram_pkg::num_ranks_p)
          ,.address_mapping_p(`dram_pkg::address_mapping_p)
          ,.size_in_bits_p(`dram_pkg::size_in_bits_p)
          ,.config_p(`dram_pkg::config_p)
          ,.masked_p(l2_features_p[e_cfg_word_tracking])
          ,.init_mem_p(1)
          ,.base_id_p(0)
          )
        dram
         (.clk_i(dram_clk_i)
          ,.reset_i(dram_reset_i)

          ,.v_i(dram_v_li)
          ,.write_not_read_i(dram_write_not_read_li)
          ,.ch_addr_i(dram_ch_addr_li)
          ,.mask_i(dram_mask_li)
          ,.yumi_o(dram_yumi_lo)

          ,.data_v_i(dram_data_v_li)
          ,.data_i(dram_data_li)
          ,.data_yumi_o(dram_data_yumi_lo)

          ,.data_v_o(dram_data_v_lo)
          ,.data_o(dram_data_lo)
          ,.read_done_ch_addr_o(dram_read_done_ch_addr_lo)

          ,.write_done_o()
          ,.write_done_ch_addr_o()
          ,.print_stat_clk_i('0)
          ,.print_stat_reset_i('0)
          ,.print_stat_v_i('0)
          ,.print_stat_tag_i('0)
          );


      // Preloading is not supported in Verilator due to heirarchical reference and clk
      //   delay statement.
      `ifndef VERILATOR
      // This whole segment is unoptimized because it's storing this memory even though it's
      //   only used for initialization. We could read byte-by-byte to avoid this
      logic [7:0] preload_mem [*];
      initial
        begin
          automatic integer h = $fopen("prog.mem", "r");
          if (h)
            begin
              $readmemh("prog.mem", preload_mem);
              @(posedge clk_i)
              for (integer i = 0; i < preload_mem.num(); i++)
                if (preload_mem_p)
                  dram.channels[0].channel.bsg_mem_dma_set(dram.channels[0].channel.memory, i, preload_mem[i]);
              preload_mem.delete();
              $fclose(h);
            end
        end
      `else
        if (preload_mem_p)
          begin : preload
            $error("Preloading is not supported in Verilator");
          end
      `endif
    end
  else if (dram_type_p == "axi")
    begin : axi
      localparam axi_id_width_p = 6;
      localparam axi_addr_width_p = 64;
      localparam axi_data_width_p = l2_fill_width_p;
      localparam axi_strb_width_p = axi_data_width_p >> 3;
      localparam axi_burst_len_p = l2_block_width_p / l2_fill_width_p;

      localparam mem_els_lp = mem_bytes_p/(axi_data_width_p/8);

      logic [axi_id_width_p-1:0] axi_awid;
      logic [caddr_width_p-1:0] axi_awaddr_addr;
      logic axi_awaddr_addr_unused;
      logic [`BSG_SAFE_CLOG2(num_dma_p)-1:0] axi_awaddr_cache_id;
      logic [7:0] axi_awlen;
      logic [2:0] axi_awsize;
      logic [1:0] axi_awburst;
      logic [3:0] axi_awcache;
      logic [2:0] axi_awprot;
      logic axi_awlock, axi_awvalid, axi_awready;

      logic [axi_data_width_p-1:0] axi_wdata;
      logic [axi_strb_width_p-1:0] axi_wstrb;
      logic axi_wlast, axi_wvalid, axi_wready;

      logic [axi_id_width_p-1:0] axi_bid;
      logic [1:0] axi_bresp;
      logic axi_bvalid, axi_bready;

      logic [axi_id_width_p-1:0] axi_arid;
      logic [caddr_width_p-1:0] axi_araddr_addr;
      logic axi_araddr_addr_unused;
      logic [`BSG_SAFE_CLOG2(num_dma_p)-1:0] axi_araddr_cache_id;
      logic [7:0] axi_arlen;
      logic [2:0] axi_arsize;
      logic [1:0] axi_arburst;
      logic [3:0] axi_arcache;
      logic [2:0] axi_arprot;
      logic axi_arlock, axi_arvalid, axi_arready;

      logic [axi_id_width_p-1:0] axi_rid;
      logic [axi_data_width_p-1:0] axi_rdata;
      logic [1:0] axi_rresp;
      logic axi_rlast, axi_rvalid, axi_rready;

      bsg_cache_to_axi
       #(.addr_width_p(daddr_width_p)
         ,.data_width_p(l2_fill_width_p)
         ,.mask_width_p(l2_block_size_in_words_p)
         ,.block_size_in_words_p(l2_block_size_in_fill_p)
         ,.num_cache_p(num_dma_p)
         ,.axi_id_width_p(axi_id_width_p)
         ,.axi_data_width_p(axi_data_width_p)
         ,.axi_burst_len_p(axi_burst_len_p)
         ,.axi_burst_type_p(e_axi_burst_wrap)
         ,.ordering_en_p(1)
         )
      cache2axi
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dma_pkt_i(dma_pkt_i)
         ,.dma_pkt_v_i(dma_pkt_v_i)
         ,.dma_pkt_yumi_o(dma_pkt_yumi_o)

         ,.dma_data_o(dma_data_o)
         ,.dma_data_v_o(dma_data_v_o)
         ,.dma_data_ready_and_i(dma_data_ready_and_i)

         ,.dma_data_i(dma_data_i)
         ,.dma_data_v_i(dma_data_v_i)
         ,.dma_data_yumi_o(dma_data_yumi_o)

         ,.axi_awid_o(axi_awid)
         ,.axi_awaddr_addr_o({axi_awaddr_addr_unused, axi_awaddr_addr})
         ,.axi_awaddr_cache_id_o(axi_awaddr_cache_id)
         ,.axi_awlen_o(axi_awlen)
         ,.axi_awsize_o(axi_awsize)
         ,.axi_awburst_o(axi_awburst)
         ,.axi_awcache_o(axi_awcache)
         ,.axi_awprot_o(axi_awprot)
         ,.axi_awlock_o(axi_awlock)
         ,.axi_awvalid_o(axi_awvalid)
         ,.axi_awready_i(axi_awready)

         ,.axi_wdata_o(axi_wdata)
         ,.axi_wstrb_o(axi_wstrb)
         ,.axi_wlast_o(axi_wlast)
         ,.axi_wvalid_o(axi_wvalid)
         ,.axi_wready_i(axi_wready)

         ,.axi_bid_i(axi_bid)
         ,.axi_bresp_i(axi_bresp)
         ,.axi_bvalid_i(axi_bvalid)
         ,.axi_bready_o(axi_bready)
         ,.axi_arid_o(axi_arid)
         ,.axi_araddr_addr_o({axi_araddr_addr_unused, axi_araddr_addr})
         ,.axi_araddr_cache_id_o(axi_araddr_cache_id)
         ,.axi_arlen_o(axi_arlen)
         ,.axi_arsize_o(axi_arsize)
         ,.axi_arburst_o(axi_arburst)
         ,.axi_arcache_o(axi_arcache)
         ,.axi_arprot_o(axi_arprot)
         ,.axi_arlock_o(axi_arlock)
         ,.axi_arvalid_o(axi_arvalid)
         ,.axi_arready_i(axi_arready)

         ,.axi_rid_i(axi_rid)
         ,.axi_rdata_i(axi_rdata)
         ,.axi_rresp_i(axi_rresp)
         ,.axi_rlast_i(axi_rlast)
         ,.axi_rvalid_i(axi_rvalid)
         ,.axi_rready_o(axi_rready)
         );

      wire [axi_addr_width_p-1:0] axi_araddr = {axi_araddr_cache_id, (axi_araddr_addr-dram_base_addr_gp)};
      wire [axi_addr_width_p-1:0] axi_awaddr = {axi_awaddr_cache_id, (axi_awaddr_addr-dram_base_addr_gp)};

      bsg_nonsynth_axi_mem
       #(.axi_id_width_p(axi_id_width_p)
         ,.axi_addr_width_p(axi_addr_width_p)
         ,.axi_data_width_p(axi_data_width_p)
         ,.axi_len_width_p(8)
         ,.mem_els_p(mem_els_lp)
         ,.init_data_p(32'hdeadbeef)
         )
       axi_mem
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.axi_awid_i(axi_awid)
         ,.axi_awaddr_i(axi_awaddr)
         ,.axi_awvalid_i(axi_awvalid)
         ,.axi_awready_o(axi_awready)
         ,.axi_awburst_i(axi_awburst)
         ,.axi_awlen_i(axi_awlen)

         ,.axi_wdata_i(axi_wdata)
         ,.axi_wstrb_i(axi_wstrb)
         ,.axi_wlast_i(axi_wlast)
         ,.axi_wvalid_i(axi_wvalid)
         ,.axi_wready_o(axi_wready)

         ,.axi_bid_o(axi_bid)
         ,.axi_bresp_o(axi_bresp)
         ,.axi_bvalid_o(axi_bvalid)
         ,.axi_bready_i(axi_bready)

         ,.axi_arid_i(axi_arid)
         ,.axi_araddr_i(axi_araddr)
         ,.axi_arvalid_i(axi_arvalid)
         ,.axi_arready_o(axi_arready)
         ,.axi_arburst_i(axi_arburst)
         ,.axi_arlen_i(axi_arlen)

         ,.axi_rid_o(axi_rid)
         ,.axi_rdata_o(axi_rdata)
         ,.axi_rresp_o(axi_rresp)
         ,.axi_rlast_o(axi_rlast)
         ,.axi_rvalid_o(axi_rvalid)
         ,.axi_rready_i(axi_rready)
         );

      if (preload_mem_p)
        begin : preload
          $error("Preloading is not supported for AXI");
        end
    end
  else
    begin : no_mem
      $error("Must select dram_type as either dramsim3, dmc, or axi");
    end

endmodule

