/**
 * bp_me_top_test.v
 *
 */

module bp_me_top_test
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_half_core_cfg
    `declare_bp_proc_params(cfg_p)

    // Config channel
    ,parameter cfg_link_addr_width_p = "inv"
    ,parameter cfg_link_data_width_p = "inv"

    ,localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    ,parameter mem_els_p="inv"
    ,parameter boot_rom_width_p="inv"
    ,parameter boot_rom_els_p="inv"
    ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)

    ,localparam lce_req_data_width_lp = 64
    ,localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_lp)
    ,localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    ,localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, cce_block_width_p)
    ,localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p)
    ,localparam bp_cce_lce_data_cmd_width_lp=`bp_lce_data_cmd_width(num_lce_p, cce_block_width_p, lce_assoc_p)

    ,localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

    ,localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
  )
  (input                                                   clk_i
   ,input                                                  reset_i
   ,input                                                  freeze_i

   // Config channel
   , input [cfg_link_addr_width_p-2:0]                     config_addr_i
   , input [cfg_link_data_width_p-1:0]                     config_data_i
   , input                                                 config_v_i
   , input                                                 config_w_i
   , output logic                                          config_ready_o

   , output logic [cfg_link_data_width_p-1:0]              config_data_o
   , output logic                                          config_v_o
   , input                                                 config_ready_i

    // LCE-CCE Interface
    // inbound: ready->valid, helpful
    // outbound: valid->ready (a.k.a., valid-yumi), helpful
    ,input [bp_lce_cce_req_width_lp-1:0]                   lce_req_i
    ,input                                                 lce_req_v_i
    ,output logic                                          lce_req_ready_o

    ,input [bp_lce_cce_resp_width_lp-1:0]                  lce_resp_i
    ,input                                                 lce_resp_v_i
    ,output logic                                          lce_resp_ready_o

    ,input [bp_lce_cce_data_resp_width_lp-1:0]             lce_data_resp_i
    ,input                                                 lce_data_resp_v_i
    ,output logic                                          lce_data_resp_ready_o

    ,output logic [bp_cce_lce_cmd_width_lp-1:0]            lce_cmd_o
    ,output logic                                          lce_cmd_v_o
    ,input                                                 lce_cmd_ready_i

    ,output logic [bp_cce_lce_data_cmd_width_lp-1:0]       lce_data_cmd_o
    ,output logic                                          lce_data_cmd_v_o
    ,input                                                 lce_data_cmd_ready_i

    ,input [bp_cce_lce_data_cmd_width_lp-1:0]              lce_data_cmd_i
    ,input                                                 lce_data_cmd_v_i
    ,output logic                                          lce_data_cmd_ready_o

  );

  // CCE-MEM Interface
  logic [bp_mem_cce_resp_width_lp-1:0]           mem_resp_i;
  logic                                          mem_resp_v_i;
  logic                                          mem_resp_ready_o;

  logic [bp_mem_cce_data_resp_width_lp-1:0]      mem_data_resp_i;
  logic                                          mem_data_resp_v_i;
  logic                                          mem_data_resp_ready_o;

  logic [bp_cce_mem_cmd_width_lp-1:0]            mem_cmd_o;
  logic                                          mem_cmd_v_o;
  logic                                          mem_cmd_yumi_i;

  logic [bp_cce_mem_data_cmd_width_lp-1:0]       mem_data_cmd_o;
  logic                                          mem_data_cmd_v_o;
  logic                                          mem_data_cmd_yumi_i;

  logic [lg_boot_rom_els_lp-1:0]                 boot_rom_addr;
  logic [boot_rom_width_p-1:0]                   boot_rom_data;

  logic [inst_ram_addr_width_lp-1:0]             cce_inst_boot_rom_addr_i;
  logic [`bp_cce_inst_width-1:0]                 cce_inst_boot_rom_data_o;

  // CCE Boot ROM
  bp_cce_inst_rom
    #(.width_p(`bp_cce_inst_width)
      ,.addr_width_p(inst_ram_addr_width_lp)
      )
    cce_inst_rom
     (.addr_i(cce_inst_boot_rom_addr_i)
      ,.data_o(cce_inst_boot_rom_data_o)
      );

  bp_me_top
    #(.cfg_p(cfg_p)
      ,.cfg_link_addr_width_p(16)
      ,.cfg_link_data_width_p(32)
      ,.lce_req_data_width_p(64)
     )
     bp_me_top
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.freeze_i(freeze_i)

      ,.config_addr_i(config_addr_i)
      ,.config_data_i(config_data_i)
      ,.config_v_i(config_v_i)
      ,.config_w_i(config_w_i)
      ,.config_ready_o(config_ready_o)
      ,.config_data_o(config_data_o)
      ,.config_v_o(config_v_o)
      ,.config_ready_i(config_ready_i)

      ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr_i)
      ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data_o)

      // To CCE
      ,.lce_req_i(lce_req_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_ready_o(lce_req_ready_o)
      ,.lce_resp_i(lce_resp_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_ready_o(lce_resp_ready_o)
      ,.lce_data_resp_i(lce_data_resp_i)
      ,.lce_data_resp_v_i(lce_data_resp_v_i)
      ,.lce_data_resp_ready_o(lce_data_resp_ready_o)

      // From CCE
      ,.lce_cmd_o(lce_cmd_o)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      ,.lce_data_cmd_o(lce_data_cmd_o)
      ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

      // Transfer from LCE to LCE
      ,.lce_data_cmd_i(lce_data_cmd_i)
      ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
      ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

      // To CCE
      ,.mem_resp_i(mem_resp_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_ready_o(mem_resp_ready_o)
      ,.mem_data_resp_i(mem_data_resp_i)
      ,.mem_data_resp_v_i(mem_data_resp_v_i)
      ,.mem_data_resp_ready_o(mem_data_resp_ready_o)

      // From CCE
      ,.mem_cmd_o(mem_cmd_o)
      ,.mem_cmd_v_o(mem_cmd_v_o)
      ,.mem_cmd_yumi_i(mem_cmd_yumi_i)
      ,.mem_data_cmd_o(mem_data_cmd_o)
      ,.mem_data_cmd_v_o(mem_data_cmd_v_o)
      ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i)
     );

  bp_mem
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.block_size_in_bytes_p(cce_block_width_p/8)
      ,.lce_sets_p(lce_sets_p)
      ,.mem_els_p(mem_els_p)
      ,.boot_rom_width_p(boot_rom_width_p)
      ,.boot_rom_els_p(boot_rom_els_p)
      ,.lce_req_data_width_p(lce_req_data_width_lp)
     )
     bp_mem
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.mem_cmd_i(mem_cmd_o)
      ,.mem_cmd_v_i(mem_cmd_v_o)
      ,.mem_cmd_yumi_o(mem_cmd_yumi_i)
      ,.mem_data_cmd_i(mem_data_cmd_o)
      ,.mem_data_cmd_v_i(mem_data_cmd_v_o)
      ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_i)
      ,.mem_resp_o(mem_resp_i)
      ,.mem_resp_v_o(mem_resp_v_i)
      ,.mem_resp_ready_i(mem_resp_ready_o)
      ,.mem_data_resp_o(mem_data_resp_i)
      ,.mem_data_resp_v_o(mem_data_resp_v_i)
      ,.mem_data_resp_ready_i(mem_data_resp_ready_o)

      ,.boot_rom_addr_o(boot_rom_addr)
      ,.boot_rom_data_i(boot_rom_data)
     );

  bp_boot_rom #(
    .width_p(boot_rom_width_p)
    ,.addr_width_p(lg_boot_rom_els_lp)
  ) boot_rom (
    .addr_i(boot_rom_addr)
    ,.data_o(boot_rom_data)
  );

endmodule
