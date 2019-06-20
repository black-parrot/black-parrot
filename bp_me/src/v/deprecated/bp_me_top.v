/**
 *
 * Name:
 *   bp_me_top.v
 *
 * Description:
 *   This is the top level module for the Memory End of BlackParrot
 *
 */ 

module bp_me_top
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    // Config channel
    , parameter cfg_link_addr_width_p = cfg_addr_width_p
    , parameter cfg_link_data_width_p = cfg_data_width_p

    // Default parameters
    , parameter cce_trace_p           = 0

    // Derived parameters
    , localparam block_size_in_bytes_lp = (cce_block_width_p/8)
    , localparam lg_num_cce_lp          = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  )
  (input                                                            clk_i
   , input                                                          reset_i
   , input [num_cce_p-1:0]                                          freeze_i

   // Config channel
   , input [num_cce_p-1:0][cfg_link_addr_width_p-2:0]               config_addr_i
   , input [num_cce_p-1:0][cfg_link_data_width_p-1:0]               config_data_i
   , input [num_cce_p-1:0]                                          config_v_i
   , input [num_cce_p-1:0]                                          config_w_i
   , output logic [num_cce_p-1:0]                                   config_ready_o

   , output logic [num_cce_p-1:0][cfg_link_data_width_p-1:0]        config_data_o
   , output logic [num_cce_p-1:0]                                   config_v_o
   , input [num_cce_p-1:0]                                          config_ready_i

   // LCE <-> Coherence Network Interface
   // inbound: ready->valid, helpful consumer
   , input [num_lce_p-1:0][lce_cce_req_width_lp-1:0]                lce_req_i
   , input [num_lce_p-1:0]                                          lce_req_v_i
   , output logic [num_lce_p-1:0]                                   lce_req_ready_o

   , input [num_lce_p-1:0][lce_cce_resp_width_lp-1:0]               lce_resp_i
   , input [num_lce_p-1:0]                                          lce_resp_v_i
   , output logic [num_lce_p-1:0]                                   lce_resp_ready_o

   , input [num_lce_p-1:0][lce_cce_data_resp_width_lp-1:0]          lce_data_resp_i
   , input [num_lce_p-1:0]                                          lce_data_resp_v_i
   , output logic [num_lce_p-1:0]                                   lce_data_resp_ready_o

   // outbound: ready->valid, demanding producer
   , output logic [num_lce_p-1:0][cce_lce_cmd_width_lp-1:0]         lce_cmd_o
   , output logic [num_lce_p-1:0]                                   lce_cmd_v_o
   , input [num_lce_p-1:0]                                          lce_cmd_ready_i

   , output logic [num_lce_p-1:0][lce_data_cmd_width_lp-1:0]        lce_data_cmd_o
   , output logic [num_lce_p-1:0]                                   lce_data_cmd_v_o
   , input [num_lce_p-1:0]                                          lce_data_cmd_ready_i

   , input [num_lce_p-1:0][lce_data_cmd_width_lp-1:0]               lce_data_cmd_i
   , input [num_lce_p-1:0]                                          lce_data_cmd_v_i
   , output logic [num_lce_p-1:0]                                   lce_data_cmd_ready_o

  // cce inst boot rom
   , output logic [num_cce_p-1:0][inst_ram_addr_width_lp-1:0]       cce_inst_boot_rom_addr_o
   , input [num_cce_p-1:0][`bp_cce_inst_width-1:0]                  cce_inst_boot_rom_data_i

  // CCE-MEM Interface
   , input [num_cce_p-1:0][mem_cce_resp_width_lp-1:0]               mem_resp_i
   , input [num_cce_p-1:0]                                          mem_resp_v_i
   , output logic [num_cce_p-1:0]                                   mem_resp_ready_o

   , input [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0]          mem_data_resp_i
   , input [num_cce_p-1:0]                                          mem_data_resp_v_i
   , output logic [num_cce_p-1:0]                                   mem_data_resp_ready_o

   , output logic [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0]         mem_cmd_o
   , output logic [num_cce_p-1:0]                                   mem_cmd_v_o
   , input [num_cce_p-1:0]                                          mem_cmd_yumi_i

   , output logic [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output logic [num_cce_p-1:0]                                   mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                          mem_data_cmd_yumi_i
  );

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


  // Coherence Network
  bp_me_network
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.data_width_p(dword_width_p)
      ,.data_cmd_max_num_flit_p(bp_data_cmd_num_flit_gp)
      ,.data_resp_max_num_flit_p(bp_data_resp_num_flit_gp)
      )
    network
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      // CCE Command Network - (CCE->network->LCE)
      // (LCE side)
      ,.lce_cmd_o(lce_cmd_o)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      // (CCE side)
      ,.lce_cmd_i(lce_cmd_o_from_cce)
      ,.lce_cmd_v_i(lce_cmd_v_o_from_cce)
      ,.lce_cmd_ready_o(lce_cmd_ready_i_to_cce)

      // CCE Data Command Network - (CCE->network->LCE)
      // (LCE side)
      ,.lce_data_cmd_o(lce_data_cmd_o)
      ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

      ,.cce_lce_data_cmd_i(lce_data_cmd_o_from_cce)
      ,.cce_lce_data_cmd_v_i(lce_data_cmd_v_o_from_cce)
      ,.cce_lce_data_cmd_ready_o(lce_data_cmd_ready_i_to_cce)

      ,.lce_lce_data_cmd_i(lce_data_cmd_i)
      ,.lce_lce_data_cmd_v_i(lce_data_cmd_v_i)
      ,.lce_lce_data_cmd_ready_o(lce_data_cmd_ready_o)
      

      // LCE Request Network - (LCE->network->CCE)
      // (LCE side)
      ,.lce_req_i(lce_req_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_ready_o(lce_req_ready_o)
      // (CCE side)
      ,.lce_req_o(lce_req_i_to_cce)
      ,.lce_req_v_o(lce_req_v_i_to_cce)
      ,.lce_req_ready_i(lce_req_ready_o_from_cce)

      // LCE Response Network - (LCE->network->CCE)
	    // (LCE side)
      ,.lce_resp_i(lce_resp_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_ready_o(lce_resp_ready_o)
      // (CCE side)
      ,.lce_resp_o(lce_resp_i_to_cce)
      ,.lce_resp_v_o(lce_resp_v_i_to_cce)
      ,.lce_resp_ready_i(lce_resp_ready_o_from_cce)

      // LCE Data Response Network - (LCE->network->CCE)
      // (LCE side)
      ,.lce_data_resp_i(lce_data_resp_i)
      ,.lce_data_resp_v_i(lce_data_resp_v_i)
      ,.lce_data_resp_ready_o(lce_data_resp_ready_o)
      // (CCE side)
      ,.lce_data_resp_o(lce_data_resp_i_to_cce)
      ,.lce_data_resp_v_o(lce_data_resp_v_i_to_cce)
      ,.lce_data_resp_ready_i(lce_data_resp_ready_o_from_cce)
      );


  for (genvar i = 0; i < num_cce_p; i++) begin
    bp_cce_top
      #(.cfg_p(cfg_p)
        ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
        ,.cfg_link_data_width_p(cfg_link_data_width_p)
        ,.cce_trace_p(cce_trace_p)
        )
      bp_cce_top
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.freeze_i(freeze_i[i])

        ,.cce_id_i((lg_num_cce_lp)'(i))

        ,.config_addr_i(config_addr_i[i])
        ,.config_data_i(config_data_i[i])
        ,.config_v_i(config_v_i[i])
        ,.config_w_i(config_w_i[i])
        ,.config_ready_o(config_ready_o[i])

        ,.config_data_o(config_data_o[i])
        ,.config_v_o(config_v_o[i])
        ,.config_ready_i(config_ready_i[i])

        ,.boot_rom_addr_o(cce_inst_boot_rom_addr_o[i])
        ,.boot_rom_data_i(cce_inst_boot_rom_data_i[i])

        // To CCE
        ,.lce_req_i(lce_req_i_to_cce[i])
        ,.lce_req_v_i(lce_req_v_i_to_cce[i])
        ,.lce_req_ready_o(lce_req_ready_o_from_cce[i])
        ,.lce_resp_i(lce_resp_i_to_cce[i])
        ,.lce_resp_v_i(lce_resp_v_i_to_cce[i])
        ,.lce_resp_ready_o(lce_resp_ready_o_from_cce[i])
        ,.lce_data_resp_i(lce_data_resp_i_to_cce[i])
        ,.lce_data_resp_v_i(lce_data_resp_v_i_to_cce[i])
        ,.lce_data_resp_ready_o(lce_data_resp_ready_o_from_cce[i])

        // From CCE
        ,.lce_cmd_o(lce_cmd_o_from_cce[i])
        ,.lce_cmd_v_o(lce_cmd_v_o_from_cce[i])
        ,.lce_cmd_ready_i(lce_cmd_ready_i_to_cce[i])
        ,.lce_data_cmd_o(lce_data_cmd_o_from_cce[i])
        ,.lce_data_cmd_v_o(lce_data_cmd_v_o_from_cce[i])
        ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i_to_cce[i])

        // To CCE
        ,.mem_resp_i(mem_resp_i[i])
        ,.mem_resp_v_i(mem_resp_v_i[i])
        ,.mem_resp_ready_o(mem_resp_ready_o[i])
        ,.mem_data_resp_i(mem_data_resp_i[i])
        ,.mem_data_resp_v_i(mem_data_resp_v_i[i])
        ,.mem_data_resp_ready_o(mem_data_resp_ready_o[i])

        // From CCE
        ,.mem_cmd_o(mem_cmd_o[i])
        ,.mem_cmd_v_o(mem_cmd_v_o[i])
        ,.mem_cmd_yumi_i(mem_cmd_yumi_i[i])
        ,.mem_data_cmd_o(mem_data_cmd_o[i])
        ,.mem_data_cmd_v_o(mem_data_cmd_v_o[i])
        ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i[i])
        );
  end

endmodule
