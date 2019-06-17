/**
 *
 * Name:
 *   bp_cce_nonsysnth_cfg_loader.v
 *
 * Description:
 *
 */

module bp_cce_nonsynth_cfg_loader
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter inst_width_p            = "inv"
    , parameter inst_ram_addr_width_p = "inv"
    , parameter cfg_link_addr_width_p = bp_cfg_link_addr_width_gp
    , parameter cfg_link_data_width_p = bp_cfg_link_data_width_gp
    , parameter inst_ram_els_p        = "inv"
    , parameter skip_ram_init_p       = 0
    , parameter cce_ucode_filename_p = "cce_ucode.mem"
    , localparam cfg_writes_lp = (2*inst_ram_els_p)
    , localparam data_hi_width_lp = (inst_width_p-cfg_link_data_width_p)
    , localparam data_hi_pad_lp = (cfg_link_data_width_p-data_hi_width_lp)
  )
  (input                                             clk_i
   , input                                           reset_i
   , output logic                                    freeze_o

   // Config channel
   , output logic [cfg_link_addr_width_p-2:0]        config_addr_o
   , output logic [cfg_link_data_width_p-1:0]        config_data_o
   , output logic                                    config_v_o
   , output logic                                    config_w_o
   , input                                           config_ready_i

   , input [cfg_link_data_width_p-1:0]               config_data_i
   , input                                           config_v_i
   , output logic                                    config_ready_o

  );


  logic [`bp_cce_inst_width-1:0] cce_inst_boot_rom [0:inst_ram_els_p-1];
  logic [inst_ram_addr_width_p-1:0] cce_inst_boot_rom_addr;
  logic [`bp_cce_inst_width-1:0] cce_inst_boot_rom_data;

  initial $readmemb(cce_ucode_filename_p, cce_inst_boot_rom);

  assign cce_inst_boot_rom_data = cce_inst_boot_rom[cce_inst_boot_rom_addr];

  // TODO: reads if we want
  wire unused1;
  assign unused1 = config_v_i;
  wire [cfg_link_data_width_p-1:0] unused2;
  assign unused2 = config_data_i;

  typedef enum logic [2:0] {
    RESET
    ,PAUSE
    ,SEND_RAM
    ,SEND_CFG_NORMAL
    ,SEND_LCE_CFG_NORMAL
    ,DONE
  } cfg_state_e;

  cfg_state_e state, state_n;

  logic [cfg_link_addr_width_p-2:0] cfg_addr_r, cfg_addr_n;
  logic freeze_r, freeze_n;
  assign freeze_o = freeze_r;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state <= RESET;
      cfg_addr_r <= {2'b11, (cfg_link_addr_width_p-3)'('0)};
      freeze_r <= 1'b1;
    end else begin
      state <= state_n;
      cfg_addr_r <= cfg_addr_n;
      freeze_r <= freeze_n;
    end
  end

  logic cfg_hi;
  assign cfg_hi = cfg_addr_r[0];
  assign cce_inst_boot_rom_addr = cfg_addr_r[1+:inst_ram_addr_width_p];

  always_comb begin
    if (reset_i) begin
      freeze_n = 1'b1;
      cfg_addr_n = {2'b11, (cfg_link_addr_width_p-3)'('0)};
      state_n = RESET;
      config_v_o = '0;
      config_w_o = '0;
      config_addr_o = '0;
      config_data_o = '0;
      config_ready_o = '0;

    end else begin
      freeze_n = 1'b1;
      cfg_addr_n = cfg_addr_r;
      state_n = state;
      config_v_o = '0;
      config_w_o = '0;
      config_addr_o = '0;
      config_data_o = '0;
      config_ready_o = '0;

      case (state)
        RESET: begin
          state_n = (reset_i) ? RESET : PAUSE;
        end
        PAUSE: begin
          state_n = (skip_ram_init_p) ? DONE : SEND_RAM;
        end
        SEND_RAM: begin
          config_v_o = 1'b1;
          config_w_o = 1'b1;
          config_addr_o = cfg_addr_r;
          config_data_o = (cfg_hi)
            ? {(data_hi_pad_lp)'('0),cce_inst_boot_rom_data[cfg_link_data_width_p+:data_hi_width_lp]}
            : cce_inst_boot_rom_data[0+:cfg_link_data_width_p];
          if (config_ready_i) begin
            cfg_addr_n = (cfg_addr_r[0+:(inst_ram_addr_width_p+1)] == (cfg_writes_lp-1))
                         ? {1'b1, (cfg_link_addr_width_p-2)'('0)} // set address to write mode reg
                         : cfg_addr_r + 'd1;
            state_n = (cfg_addr_r[0+:(inst_ram_addr_width_p+1)] == (cfg_writes_lp-1))
                      ? SEND_CFG_NORMAL : SEND_RAM;
          end else begin
            state_n = SEND_RAM;
          end
        end
        SEND_CFG_NORMAL: begin
          config_v_o = 1'b1;
          config_w_o = 1'b1;
          config_addr_o = cfg_addr_r;
          config_data_o = {(cfg_link_data_width_p-`bp_cce_mode_bits)'('0), e_cce_mode_normal};
          state_n = config_ready_i ? SEND_LCE_CFG_NORMAL : SEND_CFG_NORMAL;
          // address of D$ config register is 15'h1
          cfg_addr_n = config_ready_i ? 15'h1 : cfg_addr_r;
        end
        SEND_LCE_CFG_NORMAL: begin
          config_v_o = 1'b1;
          config_w_o = 1'b1;
          config_addr_o = cfg_addr_r;
          config_data_o = {(cfg_link_data_width_p-`bp_be_dcache_lce_mode_bits)'('0), e_dcache_lce_mode_normal};
          state_n = DONE;
        end
        DONE: begin
          freeze_n = '0;
          state_n = DONE;
        end
        default: begin
          state_n = RESET;
        end
      endcase
    end
  end

endmodule
