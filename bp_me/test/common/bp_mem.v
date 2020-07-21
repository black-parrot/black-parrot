
/**
 * bp_mem.v
 */

`define dram_pkg bsg_dramsim3_hbm2_8gb_x128_pkg

module bp_mem
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  import `dram_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , parameter mem_cap_in_bytes_p = "inv"
   , parameter mem_zero_p         = 0
   , parameter mem_load_p         = 0
   , parameter mem_file_p         = "inv"
   , parameter mem_offset_p       = 0

   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 0
   , parameter use_dramsim2_latency_p = 0

   , parameter max_latency_p = "inv"

   , parameter dram_capacity_p           = "inv"

   , localparam num_block_bytes_lp = cce_block_width_p / 8
   )
  (input                                 clk_i
   , input                               reset_i

   // BP side
   // ready->valid (ready then valid)
   , input [cce_mem_msg_width_lp-1:0]    mem_cmd_i
   , input                               mem_cmd_v_i
   , output                              mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
   , output                              mem_resp_v_o
   , input                               mem_resp_yumi_i
   );

`declare_bsg_cache_dma_pkt_s(paddr_width_p);

logic                     dma_pkt_v_lo, dma_data_v_lo, dma_data_v_li;
logic                     dma_pkt_yumi_li, dma_data_yumi_li, dma_data_ready_lo;
bsg_cache_dma_pkt_s       dma_pkt_lo;
logic [`dram_pkg::data_width_p-1:0] dma_data_lo, dma_data_li;
logic [(`dram_pkg::data_width_p >> 3)-1:0] dma_mask_lo;
logic [paddr_width_p-1:0] dma_addr_li;

logic [`dram_pkg::num_channels_p-1:0] dram_v_li, dram_w_li, dram_data_v_li, dram_data_v_lo;
logic [`dram_pkg::num_channels_p-1:0] dram_yumi_lo, dram_data_yumi_lo;
logic [`dram_pkg::num_channels_p-1:0][`dram_pkg::channel_addr_width_p] dram_ch_addr_li, dram_read_done_ch_addr_lo;
logic [`dram_pkg::num_channels_p-1:0][`dram_pkg::data_width_p-1:0] dram_data_li, dram_data_lo;
logic [`dram_pkg::num_channels_p-1:0][(`dram_pkg::data_width_p >> 3)-1:0] dram_mask_li;

assign dram_v_li[0] = dma_pkt_v_lo;
assign dram_w_li[0] = dma_pkt_lo.write_not_read;
assign dram_data_v_li[0] = dma_data_v_lo;
assign dma_data_v_li = dram_data_v_lo[0];

assign dma_pkt_yumi_li = dram_yumi_lo[0];
assign dma_data_yumi_li = dram_data_yumi_lo[0];

assign dram_ch_addr_li[0] = dma_pkt_lo.addr;
assign dram_data_li[0] = dma_data_lo;
assign dram_mask_li[0] = dma_mask_lo;
assign dma_data_li = dram_data_lo[0];
assign dma_addr_li = paddr_width_p'(dram_read_done_ch_addr_lo[0]);

genvar i;
for (i=1; i<`dram_pkg::num_channels_p; i=i+1) begin
  assign dram_v_li[i] = '0;
  assign dram_w_li[i] = '0;
  assign dram_data_v_li[i] = '0;
end

bp_mem_to_dram
  #(.bp_params_p(bp_params_p)
    ,.data_width_p(`dram_pkg::data_width_p)
    ,.dram_base_p(mem_offset_p)
    ,.fifo_els_p(16)
   )
  cce2dma
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.dma_pkt_o(dma_pkt_lo)
    ,.dma_pkt_v_o(dma_pkt_v_lo)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

    ,.dma_data_o(dma_data_lo)
    ,.dma_mask_o(dma_mask_lo)
    ,.dma_data_v_o(dma_data_v_lo)
    ,.dma_data_yumi_i(dma_data_yumi_li)

    ,.dma_data_i(dma_data_li)
    ,.dma_addr_i(dma_addr_li)
    ,.dma_data_v_i(dma_data_v_li)
    ,.dma_data_ready_o(dma_data_ready_lo)

    ,.mem_cmd_i(mem_cmd_i)
    ,.mem_cmd_v_i(mem_cmd_v_i)
    ,.mem_cmd_ready_o(mem_cmd_ready_o)

    ,.mem_resp_o(mem_resp_o)
    ,.mem_resp_v_o(mem_resp_v_o)
    ,.mem_resp_yumi_i(mem_resp_yumi_i)
    );

bsg_nonsynth_dramsim3
  #(.channel_addr_width_p(`dram_pkg::channel_addr_width_p)
    ,.data_width_p(`dram_pkg::data_width_p)
    ,.num_channels_p(`dram_pkg::num_channels_p)
    ,.num_columns_p(`dram_pkg::num_columns_p)
    ,.address_mapping_p(`dram_pkg::address_mapping_p)
    ,.size_in_bits_p(`dram_pkg::size_in_bits_p)
    ,.config_p(`dram_pkg::config_p)
    ,.masked_p(1)
    ,.debug_p(0)
    ,.init_mem_p(1)
   )
  dram
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.v_i(dram_v_li)
    ,.write_not_read_i(dram_w_li)
    ,.ch_addr_i(dram_ch_addr_li)
    ,.yumi_o(dram_yumi_lo)

    ,.data_v_i(dram_data_v_li)
    ,.data_i(dram_data_li)
    ,.mask_i(dram_mask_li)
    ,.data_yumi_o(dram_data_yumi_lo)

    ,.data_v_o(dram_data_v_lo)
    ,.data_o(dram_data_lo)
    ,.read_done_ch_addr_o(dram_read_done_ch_addr_lo)

    ,.write_done_o()
    ,.write_done_ch_addr_o()
    );

endmodule

