/**
 *
 * Name:
 *   bp_cce_nonsysnth_cfg_loader.v
 *
 * Description:
 *
 */

module bp_cce_nonsynth_cfg_loader
  import bsg_tag_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_cfg_link_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

    , parameter inst_width_p          = "inv"
    , parameter inst_ram_addr_width_p = "inv"
    , parameter cfg_link_addr_width_p = bp_cfg_link_addr_width_gp
    , parameter cfg_link_data_width_p = bp_cfg_link_data_width_gp
    , parameter inst_ram_els_p        = "inv"
    , parameter skip_ram_init_p       = 0
    )
  (input                                             clk_i
   , input                                           reset_i

   , output logic [inst_ram_addr_width_p-1:0]        boot_rom_addr_o
   , input [inst_width_p-1:0]                        boot_rom_data_i

   // Config channel
   , output logic [cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output logic                                    mem_data_cmd_v_o
   , input                                           mem_data_cmd_yumi_i
   );

 `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

  bp_cce_mem_data_cmd_s mem_data_cmd_cast_o;

  assign mem_data_cmd_o = mem_data_cmd_cast_o;

  enum logic [3:0] {
    RESET
    ,BP_RESET_SET
    ,BP_FREEZE_SET
    ,BP_RESET_CLR
    ,SEND_RAM_LO
    ,SEND_RAM_HI
    ,SEND_CFG_NORMAL
    ,SEND_PC_LO
    ,SEND_PC_HI
    ,BP_FREEZE_CLR
    ,DONE
  } state_n, state_r;

  logic [cfg_link_addr_width_p:0] ucode_cnt_r;
  logic ucode_cnt_clr, ucode_cnt_inc;
  bsg_counter_clear_up
   #(.max_val_p(2**cfg_link_addr_width_p)
     ,.init_val_p(0)
     )
   ucode_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(ucode_cnt_clr)
     ,.up_i(ucode_cnt_inc)

     ,.count_o(ucode_cnt_r)
     );

  wire ucode_prog_done = (ucode_cnt_r == inst_ram_els_p);

  always_ff @(posedge clk_i) 
    begin
      if (reset_i)
        state_r <= RESET;
      else if (mem_data_cmd_yumi_i)
        state_r <= state_n;
    end

  assign boot_rom_addr_o = (cfg_addr_lo >> 1);

  logic [bp_cfg_link_addr_width_gp-1:0] cfg_addr_lo;
  logic [bp_cfg_link_data_width_gp-1:0] cfg_data_lo;

  always_comb
    begin
      mem_data_cmd_v_o = cfg_v_lo;

      mem_data_cmd_cast_o.msg_type      = e_lce_req_type_wr;
      mem_data_cmd_cast_o.addr          = cfg_addr_lo;
      mem_data_cmd_cast_o.payload       = '0;
      mem_data_cmd_cast_o.non_cacheable = 1'b0;
      mem_data_cmd_cast_o.nc_size       = e_lce_req_non_cacheable;
      mem_data_cmd_cast_o.data          = cfg_data_lo;
    end

  always_comb 
    begin
      ucode_cnt_clr = 1'b0;
      ucode_cnt_inc = 1'b0;

      cfg_v_lo = '0;
      cfg_addr_lo = '0;
      cfg_data_lo = '0;

      case (state_r)
        RESET: begin
          state_n = skip_ram_init_p ? DONE: BP_RESET_SET;

          ucode_cnt_clr = 1'b1;
        end
        BP_RESET_SET: begin
          state_n = BP_FREEZE_SET;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_reset_gp;
          cfg_data_lo = 1'b1;
        end
        BP_FREEZE_SET: begin
          state_n = BP_RESET_CLR;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_freeze_gp;
          cfg_data_lo = 1'b1;
        end
        BP_RESET_CLR: begin
          state_n = SEND_RAM_LO;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_reset_gp;
          cfg_data_lo = 1'b0;
        end
        SEND_RAM_LO: begin
          state_n = SEND_RAM_HI;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_mem_base_cce_ucode_gp + (ucode_cnt_r << 1);
          cfg_data_lo = boot_rom_data_i[0+:cfg_link_data_width_p];
        end
        SEND_RAM_HI: begin
          state_n = ucode_prog_done ? SEND_CFG_NORMAL : SEND_RAM_LO;

          ucode_cnt_inc = 1'b1;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_mem_base_cce_ucode_gp + (ucode_cnt_r << 1) + 1'b1;
          cfg_data_lo = boot_rom_data_i[cfg_link_data_width_p+:cfg_link_data_width_p];
        end
        SEND_CFG_NORMAL: begin
          state_n = SEND_PC_LO;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_cce_mode_gp;
          cfg_data_lo = cfg_link_data_width_p'(e_cce_mode_normal);
        end
        SEND_PC_LO: begin
          state_n = SEND_PC_HI;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_start_pc_lo_gp;
          cfg_data_lo = bp_pc_entry_point_gp[0+:cfg_link_data_width_p];
        end
        SEND_PC_HI: begin
          state_n = BP_FREEZE_CLR;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_start_pc_hi_gp;
          cfg_data_lo = bp_pc_entry_point_gp[cfg_link_data_width_p+:cfg_link_data_width_p];
        end
        BP_FREEZE_CLR: begin
          state_n = DONE;

          cfg_v_lo = 1'b1;
          cfg_addr_lo = bp_cfg_reg_freeze_gp;
          cfg_data_lo = 1'b0;
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
