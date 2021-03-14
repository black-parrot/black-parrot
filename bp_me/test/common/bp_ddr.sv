
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_ddr
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  import bsg_tag_pkg::*;
  import bsg_dmc_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter num_dma_p = 1
   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
   )
  (input                                                     clk_i
   , input                                                   reset_i

   , input [num_dma_p-1:0][dma_pkt_width_lp-1:0]            dma_pkt_i
   , input [num_dma_p-1:0]                                  dma_pkt_v_i
   , output logic [num_dma_p-1:0]                           dma_pkt_yumi_o

   , output logic [num_dma_p-1:0][l2_fill_width_p-1:0] dma_data_o
   , output logic [num_dma_p-1:0]                           dma_data_v_o
   , input [num_dma_p-1:0]                                  dma_data_ready_i

   , input [num_dma_p-1:0][l2_fill_width_p-1:0]        dma_data_i
   , input [num_dma_p-1:0]                                  dma_data_v_i
   , output logic [num_dma_p-1:0]                           dma_data_yumi_o
   );

`ifdef VERILATOR
  $fatal("DDR memory model is not currently supported in Verilator.");
`endif

  localparam dmc_addr_width_lp = 28;
  localparam dmc_data_width_lp = 32;
  localparam dmc_mask_width_lp = (dmc_data_width_lp >> 3);
  localparam dmc_cmd_afifo_depth_lp = 4;
  localparam dmc_cmd_sfifo_depth_lp = 4;

  localparam tag_trace_rom_addr_width_lp = 32;
  localparam tag_trace_rom_data_width_lp = 24;

  // BSG Tag
  logic [tag_trace_rom_addr_width_lp-1:0] rom_addr_li;
  logic [tag_trace_rom_data_width_lp-1:0] rom_data_lo;

  logic tag_trace_en_r_lo, tag_trace_data_lo, tag_trace_data_r_lo, tag_trace_valid_lo, tag_trace_valid_r_lo;

  logic dfi_clk_1x_lo;

  bsg_tag_s [22:0] tag_lines_lo;
  logic [12:0][7:0] dmc_cfg_tag_data_lo;

  wire bsg_tag_s        dmc_reset_tag_lines_lo       = tag_lines_lo[0];
  wire bsg_tag_s  [3:0] dmc_dly_tag_lines_lo         = tag_lines_lo[1+:4];
  wire bsg_tag_s  [3:0] dmc_dly_trigger_tag_lines_lo = tag_lines_lo[5+:4];
  wire bsg_tag_s        dmc_ds_tag_lines_lo          = tag_lines_lo[9];
  wire bsg_tag_s [12:0] dmc_cfg_tag_lines_lo         = tag_lines_lo[10+:13];
  wire sys_reset_li                                  = dmc_cfg_tag_data_lo[12][0];

  bsg_tag_boot_rom
    #(.width_p(tag_trace_rom_data_width_lp)
     ,.addr_width_p(tag_trace_rom_addr_width_lp)
     )
    tag_trace_rom
    (.addr_i(rom_addr_li)
    ,.data_o(rom_data_lo)
    );

  always_ff @(posedge clk_i) begin
    tag_trace_valid_r_lo <= tag_trace_valid_lo;
    tag_trace_data_r_lo <= tag_trace_data_lo;
  end

  bsg_tag_trace_replay
    #(.rom_addr_width_p(tag_trace_rom_addr_width_lp)
     ,.rom_data_width_p(tag_trace_rom_data_width_lp)
     ,.num_masters_p(1)
     ,.num_clients_p(23)
     ,.max_payload_width_p(9)
     )
    tag_trace_replay
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(1'b1)

      ,.rom_addr_o(rom_addr_li)
      ,.rom_data_i(rom_data_lo)

      ,.valid_i(1'b0)
      ,.data_i('0)
      ,.ready_o()

      ,.valid_o(tag_trace_valid_lo)
      ,.en_r_o(tag_trace_en_r_lo)
      ,.tag_data_o(tag_trace_data_lo)
      ,.yumi_i(tag_trace_valid_lo)

      ,.done_o()
      ,.error_o()
      );

  bsg_tag_master
    #(.els_p(23)
     ,.lg_width_p(4)
     )
    btm
      (.clk_i      (clk_i)
      ,.data_i     (tag_trace_valid_r_lo & tag_trace_en_r_lo & tag_trace_data_r_lo)
      ,.en_i       (1'b1)
      ,.clients_r_o(tag_lines_lo)
      );

  for(genvar i=0; i<13; i++) begin
    bsg_tag_client #(.width_p(8), .default_p(0))
      btc
        (.bsg_tag_i     (dmc_cfg_tag_lines_lo[i])
        ,.recv_clk_i    (clk_i)
        ,.recv_reset_i  (1'b0)
        ,.recv_new_r_o  ()
        ,.recv_data_r_o (dmc_cfg_tag_data_lo[i])
        );
  end

  // DRAM Timing Parameters
  bsg_dmc_s dmc_p;
  assign dmc_p.trefi        = {dmc_cfg_tag_data_lo[1], dmc_cfg_tag_data_lo[0]};
  assign dmc_p.tmrd         = dmc_cfg_tag_data_lo[2][3:0];
  assign dmc_p.trfc         = dmc_cfg_tag_data_lo[2][7:4];
  assign dmc_p.trc          = dmc_cfg_tag_data_lo[3][3:0];
  assign dmc_p.trp          = dmc_cfg_tag_data_lo[3][7:4];
  assign dmc_p.tras         = dmc_cfg_tag_data_lo[4][3:0];
  assign dmc_p.trrd         = dmc_cfg_tag_data_lo[4][7:4];
  assign dmc_p.trcd         = dmc_cfg_tag_data_lo[5][3:0];
  assign dmc_p.twr          = dmc_cfg_tag_data_lo[5][7:4];
  assign dmc_p.twtr         = dmc_cfg_tag_data_lo[6][3:0];
  assign dmc_p.trtp         = dmc_cfg_tag_data_lo[6][7:4];
  assign dmc_p.tcas         = dmc_cfg_tag_data_lo[7][3:0];
  assign dmc_p.col_width    = dmc_cfg_tag_data_lo[8][3:0];
  assign dmc_p.row_width    = dmc_cfg_tag_data_lo[8][7:4];
  assign dmc_p.bank_width   = dmc_cfg_tag_data_lo[9][1:0];
  assign dmc_p.bank_pos     = dmc_cfg_tag_data_lo[9][7:2];
  assign dmc_p.dqs_sel_cal  = dmc_cfg_tag_data_lo[7][6:4];
  assign dmc_p.init_cycles  = {dmc_cfg_tag_data_lo[11], dmc_cfg_tag_data_lo[10]};

  // DRAM Link
  logic app_en_lo, app_rdy_li, app_wdf_wren_lo, app_wdf_end_lo, app_wdf_rdy_li, app_rd_data_valid_li, app_rd_data_end_li;
  logic [dmc_addr_width_lp-1:0] app_addr_lo;
  logic [l2_fill_width_p-1:0] app_wdf_data_lo, app_rd_data_li;
  logic [(l2_fill_width_p>>3)-1:0] app_wdf_mask_lo;
  app_cmd_e app_cmd_lo;

  // DMC
  logic ui_reset_lo;
  logic ddr_ck_p_lo, ddr_ck_n_lo, ddr_cke_lo, ddr_cs_n_lo, ddr_ras_n_lo, ddr_cas_n_lo, ddr_we_n_lo, ddr_reset_n_lo, ddr_odt_lo;
  logic [2:0] ddr_ba_lo;
  logic [15:0] ddr_addr_lo;
  logic [dmc_mask_width_lp-1:0] ddr_dm_oen_lo, ddr_dm_lo, ddr_dqs_p_oen_lo, ddr_dqs_p_ien_lo, ddr_dqs_p_lo, ddr_dqs_p_li, ddr_dqs_n_oen_lo, ddr_dqs_n_ien_lo, ddr_dqs_n_lo, ddr_dqs_n_li;
  logic [dmc_data_width_lp-1:0] ddr_dq_oen_lo, ddr_dq_lo, ddr_dq_li;
  logic init_calib_complete_lo;

  // DDR IO
  wire [dmc_data_width_lp-1:0] ddr_dq_io;
  wire [dmc_mask_width_lp-1:0] ddr_dqs_p_io, ddr_dqs_n_io;

  for(genvar i=0; i<dmc_data_width_lp; i++) begin
    assign ddr_dq_io[i] = ddr_dq_oen_lo[i] ? 1'bz : ddr_dq_lo[i];
    assign ddr_dq_li[i] = ddr_dq_oen_lo[i] ? ddr_dq_io[i] : 1'bz;
  end

  for(genvar i=0; i<dmc_mask_width_lp; i++) begin
    assign ddr_dqs_p_io[i] = ddr_dqs_p_oen_lo[i] ? 1'bz : ddr_dqs_p_lo[i];
    assign ddr_dqs_p_li[i] = (ddr_dqs_p_oen_lo[i] ? ddr_dqs_p_io[i] : 1'bz) & ~ddr_dqs_p_ien_lo[i];
    assign ddr_dqs_n_io[i] = ddr_dqs_n_oen_lo[i] ? 1'bz : ddr_dqs_n_lo[i];
    assign ddr_dqs_n_li[i] = (ddr_dqs_n_oen_lo[i] ? ddr_dqs_n_io[i] : 1'bz) & ~ddr_dqs_n_ien_lo[i];
  end

  bsg_cache_to_dram_ctrl
   #(.num_cache_p(num_dma_p)
     ,.addr_width_p(caddr_width_p)
     ,.data_width_p(l2_fill_width_p)
     ,.block_size_in_words_p(l2_block_size_in_fill_p)
     ,.dram_ctrl_burst_len_p(l2_block_size_in_fill_p)
     ,.dram_ctrl_addr_width_p(dmc_addr_width_lp)
     )
   cache2dmc
    (.clk_i(clk_i)
     ,.reset_i(reset_i | ui_reset_lo)

     ,.dram_size_i(3'b100) // 4Gb

     ,.dma_pkt_i(dma_pkt_i)
     ,.dma_pkt_v_i(dma_pkt_v_i & init_calib_complete_lo)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_o)

     ,.dma_data_o(dma_data_o)
     ,.dma_data_v_o(dma_data_v_o)
     ,.dma_data_ready_i(dma_data_ready_i)

     ,.dma_data_i(dma_data_i)
     ,.dma_data_v_i(dma_data_v_i)
     ,.dma_data_yumi_o(dma_data_yumi_o)

     ,.app_en_o(app_en_lo)
     ,.app_rdy_i(app_rdy_li)
     ,.app_cmd_o(app_cmd_lo)
     ,.app_addr_o(app_addr_lo)

     ,.app_wdf_wren_o(app_wdf_wren_lo)
     ,.app_wdf_rdy_i(app_wdf_rdy_li)
     ,.app_wdf_data_o(app_wdf_data_lo)
     ,.app_wdf_mask_o(app_wdf_mask_lo)
     ,.app_wdf_end_o(app_wdf_end_lo)

     ,.app_rd_data_valid_i(app_rd_data_valid_li)
     ,.app_rd_data_i(app_rd_data_li)
     ,.app_rd_data_end_i(app_rd_data_end_li)
     );

  wire [dmc_addr_width_lp-1:0] app_addr_li = (app_addr_lo >> 2);
  bsg_dmc
    #(.num_adgs_p ()
      ,.ui_addr_width_p(dmc_addr_width_lp)
      ,.ui_data_width_p(l2_fill_width_p)
      ,.burst_data_width_p(l2_block_width_p)
      ,.dq_data_width_p(dmc_data_width_lp)
      ,.cmd_afifo_depth_p(dmc_cmd_afifo_depth_lp)
      ,.cmd_sfifo_depth_p(dmc_cmd_sfifo_depth_lp)
     )
    dmc
    (.async_reset_tag_i(dmc_reset_tag_lines_lo)
    ,.bsg_dly_tag_i(dmc_dly_tag_lines_lo)
    ,.bsg_dly_trigger_tag_i(dmc_dly_trigger_tag_lines_lo)
    ,.bsg_ds_tag_i(dmc_ds_tag_lines_lo)

    ,.dmc_p_i(dmc_p)

    ,.sys_reset_i(sys_reset_li)

    ,.app_addr_i(app_addr_li)
    ,.app_cmd_i(app_cmd_lo)
    ,.app_en_i(app_en_lo)
    ,.app_rdy_o(app_rdy_li)

    ,.app_wdf_wren_i(app_wdf_wren_lo)
    ,.app_wdf_data_i(app_wdf_data_lo)
    ,.app_wdf_mask_i(app_wdf_mask_lo)
    ,.app_wdf_end_i(app_wdf_end_lo)
    ,.app_wdf_rdy_o(app_wdf_rdy_li)

    ,.app_rd_data_valid_o(app_rd_data_valid_li)
    ,.app_rd_data_o(app_rd_data_li)
    ,.app_rd_data_end_o(app_rd_data_end_li)

    ,.app_ref_req_i(1'b0)
    ,.app_ref_ack_o()
    ,.app_zq_req_i(1'b0)
    ,.app_zq_ack_o()
    ,.app_sr_req_i(1'b0)
    ,.app_sr_active_o()

    ,.init_calib_complete_o (init_calib_complete_lo)

    ,.ddr_ck_p_o            (ddr_ck_p_lo)
    ,.ddr_ck_n_o            (ddr_ck_n_lo)
    ,.ddr_cke_o             (ddr_cke_lo)
    ,.ddr_ba_o              (ddr_ba_lo)
    ,.ddr_addr_o            (ddr_addr_lo)
    ,.ddr_cs_n_o            (ddr_cs_n_lo)
    ,.ddr_ras_n_o           (ddr_ras_n_lo)
    ,.ddr_cas_n_o           (ddr_cas_n_lo)
    ,.ddr_we_n_o            (ddr_we_n_lo)
    ,.ddr_reset_n_o         (ddr_reset_n_lo)
    ,.ddr_odt_o             (ddr_odt_lo)

    ,.ddr_dm_oen_o          (ddr_dm_oen_lo)
    ,.ddr_dm_o              (ddr_dm_lo)
    ,.ddr_dqs_p_oen_o       (ddr_dqs_p_oen_lo)
    ,.ddr_dqs_p_ien_o       (ddr_dqs_p_ien_lo)
    ,.ddr_dqs_p_o           (ddr_dqs_p_lo)
    ,.ddr_dqs_p_i           (ddr_dqs_p_li)
    ,.ddr_dqs_n_oen_o       (ddr_dqs_n_oen_lo)
    ,.ddr_dqs_n_ien_o       (ddr_dqs_n_ien_lo)
    ,.ddr_dqs_n_o           (ddr_dqs_n_lo)
    ,.ddr_dqs_n_i           (ddr_dqs_n_li)
    ,.ddr_dq_oen_o          (ddr_dq_oen_lo)
    ,.ddr_dq_o              (ddr_dq_lo)
    ,.ddr_dq_i              (ddr_dq_li)

    ,.ui_clk_i              (clk_i)
    ,.dfi_clk_2x_i          (clk_i)
    ,.dfi_clk_1x_o          (dfi_clk_1x_lo)

    ,.ui_clk_sync_rst_o     (ui_reset_lo)

    ,.device_temp_o         ()
    );

  mobile_ddr
    ddr0
    (.Clk     (ddr_ck_p_lo)
    ,.Clk_n   (ddr_ck_n_lo)
    ,.Cke     (ddr_cke_lo)
    ,.We_n    (ddr_we_n_lo)
    ,.Cs_n    (ddr_cs_n_lo)
    ,.Ras_n   (ddr_ras_n_lo)
    ,.Cas_n   (ddr_cas_n_lo)
    ,.Addr    (ddr_addr_lo[13:0])
    ,.Ba      (ddr_ba_lo[1:0])
    ,.Dq      (ddr_dq_io[15:0])
    ,.Dqs     (ddr_dqs_p_io[1:0])
    ,.Dm      (~ddr_dm_oen_lo[1:0] & ddr_dm_lo[1:0])
    );

  mobile_ddr
    ddr1
    (.Clk     (ddr_ck_p_lo)
    ,.Clk_n   (ddr_ck_n_lo)
    ,.Cke     (ddr_cke_lo)
    ,.We_n    (ddr_we_n_lo)
    ,.Cs_n    (ddr_cs_n_lo)
    ,.Ras_n   (ddr_ras_n_lo)
    ,.Cas_n   (ddr_cas_n_lo)
    ,.Addr    (ddr_addr_lo[13:0])
    ,.Ba      (ddr_ba_lo[1:0])
    ,.Dq      (ddr_dq_io[31:16])
    ,.Dqs     (ddr_dqs_p_io[3:2])
    ,.Dm      (~ddr_dm_oen_lo[3:2] & ddr_dm_lo[3:2])
    );

endmodule
