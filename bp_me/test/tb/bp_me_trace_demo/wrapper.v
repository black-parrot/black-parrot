

module wrapper
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
    `declare_bp_proc_params(cfg_p)
    `declare_bp_me_if_widths(paddr_width_p, dword_width_p, num_lce_p, lce_assoc_p)
    `declare_bp_lce_cce_if_widths(num_cce_p
                                  ,num_lce_p
                                  ,paddr_width_p
                                  ,lce_assoc_p
                                  ,dword_width_p
                                  ,cce_block_width_p
                                  )

    // Config link parameters
    , parameter cfg_link_addr_width_p = "inv"
    , parameter cfg_link_data_width_p = "inv"

    // Derived parameters
    , localparam lg_num_cce_lp         = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)
  )
  (input                                                         clk_i
   , input                                                       reset_i
   , input                                                       freeze_i

   // Config channel
   , input [cfg_link_addr_width_p-2:0]                           config_addr_i
   , input [cfg_link_data_width_p-1:0]                           config_data_i
   , input                                                       config_v_i
   , input                                                       config_w_i
   , output logic                                                config_ready_o

   , output logic [cfg_link_data_width_p-1:0]                    config_data_o
   , output logic                                                config_v_o
   , input                                                       config_ready_i

   // LCE <-> Coherence Network Interface
   // inbound: ready->valid, helpful consumer
   , input [num_lce_p-1:0][lce_cce_req_width_lp-1:0]             lce_req_i
   , input [num_lce_p-1:0]                                       lce_req_v_i
   , output logic [num_lce_p-1:0]                                lce_req_ready_o

   , input [num_lce_p-1:0][lce_cce_resp_width_lp-1:0]            lce_resp_i
   , input [num_lce_p-1:0]                                       lce_resp_v_i
   , output logic [num_lce_p-1:0]                                lce_resp_ready_o

   , input [num_lce_p-1:0][lce_cce_data_resp_width_lp-1:0]       lce_data_resp_i
   , input [num_lce_p-1:0]                                       lce_data_resp_v_i
   , output logic [num_lce_p-1:0]                                lce_data_resp_ready_o

   // outbound: ready->valid, demanding producer
   , output logic [num_lce_p-1:0][cce_lce_cmd_width_lp-1:0]      lce_cmd_o
   , output logic [num_lce_p-1:0]                                lce_cmd_v_o
   , input [num_lce_p-1:0]                                       lce_cmd_ready_i

   , output logic [num_lce_p-1:0][lce_data_cmd_width_lp-1:0]     lce_data_cmd_o
   , output logic [num_lce_p-1:0]                                lce_data_cmd_v_o
   , input [num_lce_p-1:0]                                       lce_data_cmd_ready_i

   , input [num_lce_p-1:0][lce_data_cmd_width_lp-1:0]            lce_data_cmd_i
   , input [num_lce_p-1:0]                                       lce_data_cmd_v_i
   , output logic [num_lce_p-1:0]                                lce_data_cmd_ready_o

  // cce inst boot rom
   , output logic [num_cce_p-1:0][inst_ram_addr_width_lp-1:0]    cce_inst_boot_rom_addr_o
   , input [num_cce_p-1:0][`bp_cce_inst_width-1:0]               cce_inst_boot_rom_data_i

  // CCE-MEM Interface
   , input [num_cce_p-1:0][mem_cce_resp_width_lp-1:0]            mem_resp_i
   , input [num_cce_p-1:0]                                       mem_resp_v_i
   , output logic [num_cce_p-1:0]                                mem_resp_ready_o

   , input [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0]       mem_data_resp_i
   , input [num_cce_p-1:0]                                       mem_data_resp_v_i
   , output logic [num_cce_p-1:0]                                mem_data_resp_ready_o

   , output logic [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0]      mem_cmd_o
   , output logic [num_cce_p-1:0]                                mem_cmd_v_o
   , input [num_cce_p-1:0]                                       mem_cmd_yumi_i

   , output logic [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_o
   , output logic [num_cce_p-1:0]                                mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                       mem_data_cmd_yumi_i
  );

  /*
  // Coherence Network <-> CCE
  // To CCE
  logic [num_cce_p-1:0][lce_cce_req_width_lp-1:0]            lce_req_i_to_cce;
  logic [num_cce_p-1:0]                                      lce_req_v_i_to_cce;
  logic [num_cce_p-1:0]                                      lce_req_ready_o_from_cce;

  logic [num_cce_p-1:0][lce_cce_resp_width_lp-1:0]           lce_resp_i_to_cce;
  logic [num_cce_p-1:0]                                      lce_resp_v_i_to_cce;
  logic [num_cce_p-1:0]                                      lce_resp_ready_o_from_cce;

  logic [num_cce_p-1:0][lce_cce_data_resp_width_lp-1:0]      lce_data_resp_i_to_cce;
  logic [num_cce_p-1:0]                                      lce_data_resp_v_i_to_cce;
  logic [num_cce_p-1:0]                                      lce_data_resp_ready_o_from_cce;

  // From CCE;
  logic [num_cce_p-1:0][cce_lce_cmd_width_lp-1:0]            lce_cmd_o_from_cce;
  logic [num_cce_p-1:0]                                      lce_cmd_v_o_from_cce;
  logic [num_cce_p-1:0]                                      lce_cmd_ready_i_to_cce;

  logic [num_cce_p-1:0][lce_data_cmd_width_lp-1:0]           lce_data_cmd_o_from_cce;
  logic [num_cce_p-1:0]                                      lce_data_cmd_v_o_from_cce;
  logic [num_cce_p-1:0]                                      lce_data_cmd_ready_i_to_cce;
  */

  bp_me_top 
   #(.cfg_p(cfg_p)
     ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
     ,.cfg_link_data_width_p(cfg_link_data_width_p)
    )
   dut
    (.*);

endmodule

