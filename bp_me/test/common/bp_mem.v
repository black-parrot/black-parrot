
/**
 * bp_mem.v
 */

module bp_mem
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)

   , parameter mem_offset_p         = "inv"
   , parameter mem_cap_in_bytes_p   = "inv"
   , parameter mem_load_p           = "inv"
   , parameter mem_file_p           = "inv"
   , parameter dram_fixed_latency_p = "inv"
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

   , input                               dram_clk_i
   , input                               dram_reset_i
   );

if(dram_fixed_latency_p) begin: fixed_latency

  localparam latency_width_lp = `BSG_SAFE_CLOG2(dram_fixed_latency_p+1);

  logic [latency_width_lp-1:0] latency_cnt_r;
  logic waiting_for_data;

  logic dram_v_lo, dram_write_not_read_lo, dram_data_v_lo, dram_data_v_li;
  logic dram_yumi_li, dram_data_yumi_li, dram_data_ready_lo;
  logic [paddr_width_p-1:0] dram_ch_addr_lo, dram_ch_addr_li;
  logic [cce_block_width_p-1:0] dram_data_lo, dram_data_li;
  logic [(cce_block_width_p >> 3)-1:0] dram_mask_lo;

  assign dram_yumi_li = dram_v_lo & ~waiting_for_data;
  assign dram_data_yumi_li = dram_data_v_lo & ~waiting_for_data;
  assign dram_data_v_li = waiting_for_data & (latency_cnt_r == dram_fixed_latency_p-1);

  wire read_cmd  = dram_yumi_li & ~dram_write_not_read_lo;

  bsg_dff_reset_en
    #(.width_p(paddr_width_p))
    addr_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(read_cmd)
      ,.data_i(dram_ch_addr_lo)
      ,.data_o(dram_ch_addr_li)
     );

  bsg_dff_reset_set_clear
    #(.width_p(1))
    wait_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(read_cmd)
      ,.clear_i(dram_data_v_li)
      ,.data_o(waiting_for_data)
     );

  bsg_counter_clear_up
    #(.max_val_p(dram_fixed_latency_p)
      ,.init_val_p(0)
     )
    latency_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.clear_i(read_cmd)
      ,.up_i(waiting_for_data)

      ,.count_o(latency_cnt_r)
     );

  bp_mem_to_dram
    #(.bp_params_p(bp_params_p)
      ,.channel_addr_width_p(paddr_width_p)
      ,.data_width_p(cce_block_width_p)
      ,.dram_base_p(mem_offset_p)
      ,.fifo_els_p(16)
     )
    mem2dram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.mem_cmd_i(mem_cmd_i)
      ,.mem_cmd_v_i(mem_cmd_v_i)
      ,.mem_cmd_ready_o(mem_cmd_ready_o)

      ,.mem_resp_o(mem_resp_o)
      ,.mem_resp_v_o(mem_resp_v_o)
      ,.mem_resp_yumi_i(mem_resp_yumi_i)

      ,.dram_clk_i(clk_i)
      ,.dram_reset_i(reset_i)

      ,.dram_ch_addr_o(dram_ch_addr_lo)
      ,.dram_write_not_read_o(dram_write_not_read_lo)
      ,.dram_v_o(dram_v_lo)
      ,.dram_yumi_i(dram_yumi_li)

      ,.dram_data_o(dram_data_lo)
      ,.dram_mask_o(dram_mask_lo)
      ,.dram_data_v_o(dram_data_v_lo)
      ,.dram_data_yumi_i(dram_data_yumi_li)

      ,.dram_data_i(dram_data_li)
      ,.dram_ch_addr_i(dram_ch_addr_li)
      ,.dram_data_v_i(dram_data_v_li)
      ,.dram_data_ready_o(dram_data_ready_lo)
   );

  localparam mem_els_lp = mem_cap_in_bytes_p / (cce_block_width_p/8);
  localparam lg_mem_els_lp = `BSG_SAFE_CLOG2(mem_els_lp);
  localparam block_offset_width_lp = `BSG_SAFE_CLOG2(cce_block_width_p/8);
  bsg_nonsynth_mem_1rw_sync_mask_write_byte_dma
   #(.width_p(cce_block_width_p)
     ,.els_p(mem_els_lp)
     ,.id_p(0)
     ,.init_mem_p(1)
     )
   dram
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(dram_yumi_li)
     ,.w_i(dram_write_not_read_lo)

     ,.addr_i(dram_ch_addr_lo[block_offset_width_lp+:lg_mem_els_lp])
     ,.data_i(dram_data_lo)
     ,.w_mask_i(dram_mask_lo)

     ,.data_o(dram_data_li)
     );
  
  if (mem_load_p)
    begin : preload
      `ifndef VERILATOR
        logic [7:0] mem [0:mem_cap_in_bytes_p];
        always_ff @(negedge reset_i)
          begin
            $readmemh(mem_file_p, mem);
            for (integer i = 0; i < mem_cap_in_bytes_p; i++)
              dram.mem.bsg_mem_dma_set(dram.mem.memory, i, mem[i]);
          end
      `else
         $fatal("Preloading with Verilator is not current supported, due to the dot references");
      `endif
    end

end
else begin: dramsim3

  logic [`dram_pkg::num_channels_p-1:0] dram_v_li, dram_w_li, dram_data_v_li, dram_data_v_lo;
  logic [`dram_pkg::num_channels_p-1:0] dram_yumi_lo, dram_data_yumi_lo;
  logic [`dram_pkg::num_channels_p-1:0][`dram_pkg::channel_addr_width_p-1:0] dram_ch_addr_li, dram_read_done_ch_addr_lo;
  logic [`dram_pkg::num_channels_p-1:0][`dram_pkg::data_width_p-1:0] dram_data_li, dram_data_lo;
  logic [`dram_pkg::num_channels_p-1:0][(`dram_pkg::data_width_p >> 3)-1:0] dram_mask_li;

  genvar i;
  for (i=1; i<`dram_pkg::num_channels_p; i=i+1) begin
    assign dram_v_li[i] = '0;
    assign dram_w_li[i] = '0;
    assign dram_data_v_li[i] = '0;
  end

  bp_mem_to_dram
    #(.bp_params_p(bp_params_p)
      ,.channel_addr_width_p(`dram_pkg::channel_addr_width_p)
      ,.data_width_p(`dram_pkg::data_width_p)
      ,.dram_base_p(mem_offset_p)
      ,.fifo_els_p(16)
     )
    mem2dram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.mem_cmd_i(mem_cmd_i)
      ,.mem_cmd_v_i(mem_cmd_v_i)
      ,.mem_cmd_ready_o(mem_cmd_ready_o)

      ,.mem_resp_o(mem_resp_o)
      ,.mem_resp_v_o(mem_resp_v_o)
      ,.mem_resp_yumi_i(mem_resp_yumi_i)

      ,.dram_clk_i(dram_clk_i)
      ,.dram_reset_i(dram_reset_i)

      ,.dram_ch_addr_o(dram_ch_addr_li[0])
      ,.dram_write_not_read_o(dram_w_li[0])
      ,.dram_v_o(dram_v_li[0])
      ,.dram_yumi_i(dram_yumi_lo[0])

      ,.dram_data_o(dram_data_li[0])
      ,.dram_mask_o(dram_mask_li[0])
      ,.dram_data_v_o(dram_data_v_li[0])
      ,.dram_data_yumi_i(dram_data_yumi_lo[0])

      ,.dram_data_i(dram_data_lo[0])
      ,.dram_ch_addr_i(dram_read_done_ch_addr_lo[0])
      ,.dram_data_v_i(dram_data_v_lo[0])
      ,.dram_data_ready_o()
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
     (.clk_i(dram_clk_i)
      ,.reset_i(dram_reset_i)

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

  localparam mem_els_lp = mem_cap_in_bytes_p / cce_block_width_p;
  localparam lg_mem_els_lp = `BSG_SAFE_CLOG2(mem_els_lp);
  if (mem_load_p)
    begin : preload
      `ifndef VERILATOR
        logic [cce_block_width_p-1:0] mem [0:mem_els_lp];
        always_ff @(negedge reset_i)
          begin
            $readmemh(mem_file_p, mem);
            for (integer i = 0; i < mem_els_lp; i++)
              dram.channels[0].channel.bsg_mem_dma_set(dram.channels[0].channel.memory, i, mem[i]);
          end
      `else
         $fatal("Preloading with Verilator is not current supported, due to the dot references");
      `endif
    end
end

endmodule
