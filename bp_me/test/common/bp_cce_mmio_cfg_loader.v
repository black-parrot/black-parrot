/**
 *
 * Name:
 *   bp_cce_mmio_cfg_loader.v
 *
 * Description:
 *
 */

module bp_cce_mmio_cfg_loader
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

    , parameter inst_width_p          = "inv"
    , parameter inst_ram_addr_width_p = "inv"
    , parameter inst_ram_els_p        = "inv"
    , parameter cce_ucode_filename_p  = "cce_ucode.mem"
    , parameter skip_ram_init_p       = 0
    
    , localparam bp_pc_entry_point_gp=39'h00_8000_0000
    )
  (input                                             clk_i
   , input                                           reset_i

   // Config channel
   , output logic [cce_mem_msg_width_lp-1:0]         mem_cmd_o
   , output logic                                    mem_cmd_v_o
   , input                                           mem_cmd_yumi_i

   // We don't need a response from the cfg network
   , input [cce_mem_msg_width_lp-1:0]                mem_resp_i
   , input                                           mem_resp_v_i
   , output                                          mem_resp_ready_o
   );

  wire unused0 = &{mem_resp_i, mem_resp_v_i};
  assign mem_resp_ready_o = 1'b1;
   
 `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

  bp_cce_mem_msg_s mem_cmd_cast_o;
  bp_cce_mem_msg_s mem_resp_cast_i;

  assign mem_cmd_o = mem_cmd_cast_o;
  assign mem_resp_cast_i = mem_resp_i;

  logic [`bp_cce_inst_width-1:0]    cce_inst_boot_rom [0:inst_ram_els_p-1];
  logic [inst_ram_addr_width_p-1:0] cce_inst_boot_rom_addr;
  logic [`bp_cce_inst_width-1:0]    cce_inst_boot_rom_data;
  
  initial $readmemb(cce_ucode_filename_p, cce_inst_boot_rom);

  logic                        cfg_w_v_lo, cfg_r_v_lo;
  logic [cfg_addr_width_p-1:0] cfg_addr_lo;
  logic [cfg_data_width_p-1:0] cfg_data_lo;

  assign cce_inst_boot_rom_addr = cfg_addr_lo;
  assign cce_inst_boot_rom_data = cce_inst_boot_rom[cce_inst_boot_rom_addr];

  enum logic [4:0] {
    RESET
    ,BP_RESET_SET
    ,BP_FREEZE_SET
    ,BP_RESET_CLR
    ,SEND_CORE_ID
    ,SEND_RAM
    ,SEND_CCE_ID
    ,SEND_CCE_NORMAL
    ,SEND_NUM_LCE
    ,SEND_ICACHE_ID
    ,SEND_ICACHE_NORMAL
    ,SEND_DCACHE_ID
    ,SEND_DCACHE_NORMAL
    ,SEND_PC
    ,SEND_IRF
    ,RECV_IRF
    ,BP_FREEZE_CLR
    ,DONE
  } state_n, state_r;

  logic [cfg_addr_width_p-1:0] ucode_cnt_r;
  logic ucode_cnt_clr, ucode_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**cfg_addr_width_p-1)
     ,.init_val_p(0)
     )
   ucode_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(ucode_cnt_clr & mem_cmd_yumi_i)
     ,.up_i(ucode_cnt_inc & mem_cmd_yumi_i)

     ,.count_o(ucode_cnt_r)
     );

  logic [cfg_addr_width_p-1:0] core_cnt_r;
  logic core_cnt_clr, core_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**cfg_addr_width_p-1)
     ,.init_val_p(0)
     )
   core_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(core_cnt_clr & mem_cmd_yumi_i)
     ,.up_i(core_cnt_inc & mem_cmd_yumi_i)

     ,.count_o(core_cnt_r)
     );

  localparam reg_els_lp = 2**reg_addr_width_p;
  logic [cfg_addr_width_p-1:0] irf_cnt_r;
  logic irf_cnt_clr, irf_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**cfg_addr_width_p-1)
     ,.init_val_p(0)
     )
   irf_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(irf_cnt_clr & mem_cmd_yumi_i)
     ,.up_i(irf_cnt_inc & mem_cmd_yumi_i)

     ,.count_o(irf_cnt_r)
     );

  wire ucode_prog_done = (ucode_cnt_r == cfg_addr_width_p'(inst_ram_els_p-1));
  wire core_prog_done  = (core_cnt_r == cfg_addr_width_p'(num_core_p-1));
  wire irf_done = (irf_cnt_r == cfg_addr_width_p'(reg_els_lp-1));

  always_ff @(posedge clk_i) 
    begin
      if (reset_i)
        state_r <= RESET;
      else if (mem_cmd_yumi_i || (state_r == RESET))
        state_r <= state_n;
    end

  always_comb
    begin
      mem_cmd_v_o = cfg_w_v_lo | cfg_r_v_lo;

      // uncached store
      mem_cmd_cast_o.msg_type      = cfg_w_v_lo ? e_cce_mem_uc_wr : e_cce_mem_uc_rd;
      mem_cmd_cast_o.addr          = bp_cfg_base_addr_gp 
                                     + ((core_cnt_r) << cfg_addr_width_p)
                                     + cfg_addr_lo;
      mem_cmd_cast_o.payload       = '0;
      mem_cmd_cast_o.size          = e_mem_size_8;
      mem_cmd_cast_o.data          = cfg_data_lo;
    end

  always_comb 
    begin
      ucode_cnt_clr = 1'b0;
      ucode_cnt_inc = 1'b0;

      core_cnt_clr = 1'b0;
      core_cnt_inc = 1'b0;

      irf_cnt_clr = 1'b0;
      irf_cnt_inc = 1'b0;

      cfg_w_v_lo = '0;
      cfg_r_v_lo = '0;
      cfg_addr_lo = '0;
      cfg_data_lo = '0;

      case (state_r)
        RESET: begin
          state_n = skip_ram_init_p ? BP_FREEZE_CLR : BP_RESET_SET;
          
          ucode_cnt_clr = 1'b1;
          core_cnt_clr = 1'b1;
          irf_cnt_clr = 1'b1;
        end
        BP_RESET_SET: begin
          state_n = core_prog_done ? BP_FREEZE_SET : BP_RESET_SET;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_reset_gp;
          cfg_data_lo = cfg_data_width_p'(1);
        end
        BP_FREEZE_SET: begin
          state_n = core_prog_done ? BP_RESET_CLR : BP_FREEZE_SET;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_freeze_gp;
          cfg_data_lo = cfg_data_width_p'(1);
        end
        BP_RESET_CLR: begin
          state_n = core_prog_done ? SEND_CORE_ID : BP_RESET_CLR;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_reset_gp;
          cfg_data_lo = cfg_data_width_p'(0);
        end
        SEND_CORE_ID: begin
          state_n = core_prog_done ? SEND_RAM : SEND_CORE_ID;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_core_id_gp;
          cfg_data_lo = core_cnt_r;
        end
        SEND_RAM: begin
          state_n = (core_prog_done & ucode_prog_done) ? SEND_CCE_ID : SEND_RAM;

          core_cnt_inc = ucode_prog_done & ~core_prog_done;
          core_cnt_clr = ucode_prog_done &  core_prog_done;
          ucode_cnt_inc = ~ucode_prog_done;;
          ucode_cnt_clr = ucode_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_mem_base_cce_ucode_gp) + ucode_cnt_r;
          cfg_data_lo = cce_inst_boot_rom_data;
          // TODO: This is nonsynth, won't work on FPGA
          cfg_data_lo = (|cfg_data_lo === 'X) ? '0 : cfg_data_lo;
        end
        SEND_CCE_ID: begin
          state_n = core_prog_done ? SEND_CCE_NORMAL : SEND_CCE_ID;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_cce_id_gp;
          cfg_data_lo = core_cnt_r;
        end
        SEND_CCE_NORMAL: begin
          state_n = core_prog_done ? SEND_NUM_LCE : SEND_CCE_NORMAL;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_cce_mode_gp;
          cfg_data_lo = cfg_data_width_p'(e_cce_mode_normal);
        end
        SEND_NUM_LCE: begin
          state_n = core_prog_done ? SEND_ICACHE_ID : SEND_NUM_LCE;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_num_lce_gp;
          cfg_data_lo = num_lce_p;
        end
        SEND_ICACHE_ID: begin
          state_n = core_prog_done ? SEND_ICACHE_NORMAL : SEND_ICACHE_ID;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_icache_id_gp);
          cfg_data_lo = (core_cnt_r << 1'b1);
        end
        SEND_ICACHE_NORMAL: begin
          state_n = core_prog_done ? SEND_DCACHE_ID : SEND_ICACHE_NORMAL;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_icache_mode_gp);
          cfg_data_lo = cfg_data_width_p'(e_lce_mode_normal); // TODO: tapeout hack, change to icache
        end
        SEND_DCACHE_ID: begin
          state_n = core_prog_done ? SEND_DCACHE_NORMAL : SEND_DCACHE_ID;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_dcache_id_gp);
          cfg_data_lo = (core_cnt_r << 1'b1) + 1'b1;
        end
        SEND_DCACHE_NORMAL: begin
          state_n = core_prog_done ? SEND_PC : SEND_DCACHE_NORMAL;

          core_cnt_inc  = ~core_prog_done;
          core_cnt_clr  = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_dcache_mode_gp);
          cfg_data_lo = cfg_data_width_p'(e_lce_mode_normal);
        end
        SEND_PC: begin
          state_n = core_prog_done ? SEND_IRF : SEND_PC;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_npc_gp);
          cfg_data_lo = bp_pc_entry_point_gp;
        end
        SEND_IRF: begin
          state_n = irf_done ? RECV_IRF : SEND_IRF;

          irf_cnt_inc = ~irf_done;
          irf_cnt_clr = irf_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_irf_x0_gp + irf_cnt_r);
          cfg_data_lo = cfg_data_width_p'(irf_cnt_r);
        end
        RECV_IRF: begin
          state_n = irf_done ? BP_FREEZE_CLR : RECV_IRF;

          irf_cnt_inc = ~irf_done;
          irf_cnt_clr = irf_done;

          cfg_r_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_irf_x0_gp + irf_cnt_r);
          cfg_data_lo = '0;
        end
        BP_FREEZE_CLR: begin
          state_n = core_prog_done ? DONE : BP_FREEZE_CLR;

          core_cnt_inc = ~core_prog_done;
          core_cnt_clr = core_prog_done;

          cfg_w_v_lo = 1'b1;
          cfg_addr_lo = cfg_addr_width_p'(bp_cfg_reg_freeze_gp);
          cfg_data_lo = cfg_data_width_p'(0);
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
