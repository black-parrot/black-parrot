/**
 *
 * Name:
 *   bp_me_nonsynth_cfg_loader.sv
 *
 * Description:
 *   This is a nonsynth config bus initializer. It issues IO commands to setup the cfg bus.
 *
 *   The skip_init_p parameter controls whether or not most of initialization is skipped, and
 *   leaves the LCEs and CCEs in uncached only mode.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cfg_loader
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

    , parameter `BSG_INV_PARAM(inst_width_p)
    , parameter `BSG_INV_PARAM(inst_ram_addr_width_p)
    , parameter `BSG_INV_PARAM(inst_ram_els_p)
    , parameter cce_ucode_filename_p  = "cce_ucode.mem"
    , parameter skip_init_p           = 0
    , parameter clear_freeze_p        = 0
    // Change the last 8 bits of the data below to indicate the hios
    // to be enabled.
    , parameter hio_mask_p         = 64'h0000_0000_0000_0001

    , localparam bp_pc_entry_point_gp=39'h10_3000
    )
  (input                                             clk_i
   , input                                           reset_i

   , input [lce_id_width_p-1:0]                      lce_id_i

   // BedRock Stream
   // TODO: convert yumi_i to ready_and_i
   , output logic [mem_header_width_lp-1:0]          io_cmd_header_o
   , output logic [dword_width_gp-1:0]               io_cmd_data_o
   , output logic                                    io_cmd_v_o
   , input                                           io_cmd_yumi_i
   , output logic                                    io_cmd_last_o

   // BedRock Stream
   , input [mem_header_width_lp-1:0]                 io_resp_header_i
   , input [dword_width_gp-1:0]                      io_resp_data_i
   , input                                           io_resp_v_i
   , output logic                                    io_resp_ready_and_o
   , input                                           io_resp_last_i

   , output logic                                    done_o
   );

  wire unused0 = &{io_resp_header_i, io_resp_data_i, io_resp_last_i};
  assign io_resp_ready_and_o = 1'b1;

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  bp_bedrock_mem_header_s io_cmd_cast_o;
  bp_bedrock_mem_header_s io_resp_cast_i;
  bp_bedrock_mem_payload_s io_cmd_payload;

  assign io_cmd_header_o = io_cmd_cast_o;
  assign io_resp_cast_i = io_resp_header_i;

  logic [dword_width_gp-1:0]    cce_inst_boot_rom [0:inst_ram_els_p-1];
  logic [inst_ram_addr_width_p-1:0] cce_inst_boot_rom_addr;
  // To prevent x-prop
  bit [dword_width_gp-1:0]    cce_inst_boot_rom_data;

  initial $readmemb(cce_ucode_filename_p, cce_inst_boot_rom);

  logic                        cfg_w_v_lo, cfg_r_v_lo;
  bp_local_addr_s              local_addr_lo;
  logic [dev_addr_width_gp-1:0] cfg_addr_lo;
  logic [dword_width_gp-1:0] cfg_data_lo;

  assign cce_inst_boot_rom_addr = cfg_addr_lo[3+:inst_ram_addr_width_p];
  assign cce_inst_boot_rom_data = cce_inst_boot_rom[cce_inst_boot_rom_addr];

  enum logic [5:0] {
    RESET
    ,BP_FREEZE_SET
    ,SEND_RAM
    ,SEND_ICACHE_NORMAL
    ,SEND_DCACHE_NORMAL
    ,SEND_CCE_NORMAL
    ,WAIT_FOR_SYNC
    ,SEND_DOMAIN_ACTIVATION
    ,SEND_SAC_ACTIVATION
    ,BP_FREEZE_CLR
    ,WAIT_FOR_CREDITS
    ,DONE
  } state_n, state_r;

  logic [`BSG_WIDTH(io_noc_max_credits_p)-1:0] credit_count_lo;
  bsg_flow_counter
   #(.els_p(io_noc_max_credits_p))
   cfg_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(io_cmd_yumi_i)
     ,.ready_i(1'b1)

     ,.yumi_i(io_resp_v_i)
     ,.count_o(credit_count_lo)
     );
  wire credits_full_lo = (credit_count_lo == io_noc_max_credits_p);
  wire credits_empty_lo = (credit_count_lo == '0);

  logic [dev_addr_width_gp-1:0] sync_cnt_r;
  logic sync_cnt_clr, sync_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**dev_addr_width_gp-1)
     ,.init_val_p(0)
     )
   sync_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(sync_cnt_clr)
     ,.up_i(sync_cnt_inc)

     ,.count_o(sync_cnt_r)
     );

  logic [dev_addr_width_gp-1:0] ucode_cnt_r;
  logic ucode_cnt_clr, ucode_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**dev_addr_width_gp-1)
     ,.init_val_p(0)
     )
   ucode_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(ucode_cnt_clr & io_cmd_yumi_i)
     ,.up_i(ucode_cnt_inc & io_cmd_yumi_i)

     ,.count_o(ucode_cnt_r)
     );

  logic [dev_addr_width_gp-1:0] core_cnt_r;
  logic core_cnt_clr, core_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**dev_addr_width_gp-1)
     ,.init_val_p(0)
     )
   core_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(core_cnt_clr & io_cmd_yumi_i)
     ,.up_i(core_cnt_inc & io_cmd_yumi_i)

     ,.count_o(core_cnt_r)
     );

  wire sync_done = (sync_cnt_r == dev_addr_width_gp'(256));
  wire ucode_prog_done = (ucode_cnt_r == dev_addr_width_gp'(inst_ram_els_p-1));
  wire core_prog_done  = (core_cnt_r == dev_addr_width_gp'(num_core_p-1));

  assign done_o = (state_r == DONE)? 1'b1 : 1'b0;

  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        state_r <= RESET;
      else if (io_cmd_yumi_i || (state_r == RESET) || (state_r == WAIT_FOR_SYNC) || (state_r == WAIT_FOR_CREDITS))
        state_r <= state_n;
    end

  always_comb
    begin
      io_cmd_v_o = (cfg_w_v_lo | cfg_r_v_lo) & ~credits_full_lo;

      // uncached store
      io_cmd_cast_o.msg_type             = cfg_w_v_lo ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      io_cmd_cast_o.subop                = e_bedrock_store;
      io_cmd_cast_o.addr                 = local_addr_lo;
      io_cmd_payload                     = '0;
      io_cmd_payload.lce_id              = lce_id_i;
      io_cmd_cast_o.size                 = e_bedrock_msg_size_8;
      io_cmd_data_o                      = cfg_data_lo;
      io_cmd_last_o                      = 1'b1;
      io_cmd_cast_o.payload              = io_cmd_payload;
    end

  always_comb
    begin
      local_addr_lo.nonlocal = '0;
      local_addr_lo.tile = core_cnt_r;
      local_addr_lo.dev  = cfg_dev_gp;
      local_addr_lo.addr = cfg_addr_lo;
    end

  always_comb
    begin
      sync_cnt_clr = 1'b0;
      sync_cnt_inc = 1'b0;

      ucode_cnt_clr = 1'b0;
      ucode_cnt_inc = 1'b0;

      core_cnt_clr = 1'b0;
      core_cnt_inc = 1'b0;

      cfg_w_v_lo = '0;
      cfg_r_v_lo = '0;
      cfg_addr_lo = '0;
      cfg_data_lo = '0;

      case (state_r)
        RESET: begin
          state_n = BP_FREEZE_SET;

          sync_cnt_clr = 1'b1;
          ucode_cnt_clr = 1'b1;
          core_cnt_clr = 1'b1;
        end
        BP_FREEZE_SET: begin
          state_n = core_prog_done
                    ? skip_init_p
                      ? BP_FREEZE_CLR
                      : SEND_RAM
                    : BP_FREEZE_SET;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_reg_freeze_gp;
          cfg_data_lo = dword_width_gp'(1);
        end
        SEND_RAM: begin
          state_n = (core_prog_done & ucode_prog_done) ? SEND_ICACHE_NORMAL : SEND_RAM;

          core_cnt_inc = ucode_prog_done & ~core_prog_done;
          core_cnt_clr = ucode_prog_done &  core_prog_done;
          ucode_cnt_inc = ~ucode_prog_done;
          ucode_cnt_clr = ucode_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = dev_addr_width_gp'(cfg_mem_cce_ucode_base_gp) + (ucode_cnt_r << 3);
          cfg_data_lo = cce_inst_boot_rom_data;
        end
        SEND_ICACHE_NORMAL: begin
          state_n = core_prog_done ? SEND_DCACHE_NORMAL : SEND_ICACHE_NORMAL;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = dev_addr_width_gp'(cfg_reg_icache_mode_gp);
          cfg_data_lo = dword_width_gp'(e_lce_mode_normal);
        end
        SEND_DCACHE_NORMAL: begin
          state_n = core_prog_done ? SEND_CCE_NORMAL : SEND_DCACHE_NORMAL;

          core_cnt_inc  = ~core_prog_done;
          core_cnt_clr  = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = dev_addr_width_gp'(cfg_reg_dcache_mode_gp);
          cfg_data_lo = dword_width_gp'(e_lce_mode_normal);
        end
        SEND_CCE_NORMAL: begin
          state_n = core_prog_done ? WAIT_FOR_SYNC : SEND_CCE_NORMAL;

          core_cnt_inc = ~core_prog_done & credits_empty_lo;
          core_cnt_clr = core_prog_done & credits_empty_lo;

          cfg_w_v_lo = credits_empty_lo;
          cfg_addr_lo = cfg_reg_cce_mode_gp;
          cfg_data_lo = dword_width_gp'(e_cce_mode_normal);
        end
        WAIT_FOR_SYNC: begin
          state_n = sync_done ? SEND_DOMAIN_ACTIVATION : WAIT_FOR_SYNC;

          sync_cnt_inc = ~sync_done;
          sync_cnt_clr = sync_done;

          cfg_w_v_lo = 1'b0;
          cfg_addr_lo = '0;
          cfg_data_lo = '0;
        end
        SEND_DOMAIN_ACTIVATION: begin
          state_n = core_prog_done ? (clear_freeze_p ? BP_FREEZE_CLR : WAIT_FOR_CREDITS) : SEND_DOMAIN_ACTIVATION;

          core_cnt_inc = ~core_prog_done & credits_empty_lo;
          core_cnt_clr = core_prog_done & credits_empty_lo;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_reg_hio_mask_gp;
          cfg_data_lo = hio_mask_p;
        end
        BP_FREEZE_CLR: begin
          state_n = core_prog_done ? WAIT_FOR_CREDITS : BP_FREEZE_CLR;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = dev_addr_width_gp'(cfg_reg_freeze_gp);
          cfg_data_lo = dword_width_gp'(0);
        end
        WAIT_FOR_CREDITS: begin
          state_n = credits_empty_lo ? DONE : WAIT_FOR_CREDITS;
        end
        DONE: begin
          state_n = DONE;
        end
        default: begin
          state_n = RESET;
        end
      endcase
    end

endmodule
