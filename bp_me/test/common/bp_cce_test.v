/**
 * bp_cce_test.v
 *
 */

module bp_cce_test
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_half_core_cfg
    `declare_bp_proc_params(cfg_p)

    , parameter cce_trace_p=0

    , localparam mem_els_lp=2*lce_assoc_p*lce_sets_p
    , localparam boot_rom_width_lp=cce_block_width_p

    , localparam block_size_in_bytes_lp=(cce_block_width_p/8)
    , localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)
    , localparam inst_ram_addr_width_lp=`BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    // Config channel
    , parameter cfg_link_addr_width_p = bp_cfg_link_addr_width_gp
    , parameter cfg_link_data_width_p = bp_cfg_link_data_width_gp

    , localparam mshr_width_lp=`bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mshr_width_lp)
  )
  (
    input                                                  clk_i
    ,input                                                 reset_i
    , output logic                                         freeze_o

    // LCE-CCE Interface
    // inbound: ready&valid
    // outbound: ready&valid
    ,input [lce_cce_req_width_lp-1:0]                      lce_req_i
    ,input                                                 lce_req_v_i
    ,output logic                                          lce_req_ready_o

    ,input [lce_cce_resp_width_lp-1:0]                     lce_resp_i
    ,input                                                 lce_resp_v_i
    ,output logic                                          lce_resp_ready_o

    ,input [lce_cce_data_resp_width_lp-1:0]                lce_data_resp_i
    ,input                                                 lce_data_resp_v_i
    ,output logic                                          lce_data_resp_ready_o

    ,output logic [cce_lce_cmd_width_lp-1:0]               lce_cmd_o
    ,output logic                                          lce_cmd_v_o
    ,input                                                 lce_cmd_ready_i

    ,output logic [lce_data_cmd_width_lp-1:0]              lce_data_cmd_o
    ,output logic                                          lce_data_cmd_v_o
    ,input                                                 lce_data_cmd_ready_i


  );

  // CCE-MEM Interface
  logic [mem_cce_resp_width_lp-1:0]              mem_resp_i;
  logic                                          mem_resp_v_i;
  logic                                          mem_resp_ready_o;

  logic [mem_cce_data_resp_width_lp-1:0]         mem_data_resp_i;
  logic                                          mem_data_resp_v_i;
  logic                                          mem_data_resp_ready_o;

  logic [cce_mem_cmd_width_lp-1:0]               mem_cmd_o;
  logic                                          mem_cmd_v_o;
  logic                                          mem_cmd_yumi_i;

  logic [cce_mem_data_cmd_width_lp-1:0]          mem_data_cmd_o;
  logic                                          mem_data_cmd_v_o;
  logic                                          mem_data_cmd_yumi_i;

  logic [lg_num_cce_lp-1:0] cce_id;
  localparam cce_id_lp = 0;
  assign cce_id = cce_id_lp;

  logic freeze_lo;
  assign freeze_o = freeze_lo;

  // Config channel
  logic [cfg_addr_width_p-1:0] config_addr_li;
  logic [cfg_data_width_p-1:0] config_data_li;
  logic                        config_v_li;
  logic                        config_w_li;
  logic                        config_ready_lo;

  logic [cfg_data_width_p-1:0] config_data_lo;
  logic                        config_v_lo;
  logic                        config_ready_li;

  // CCE instruction RAM loader
  bp_cce_nonsynth_cfg_loader
    #(.inst_width_p(`bp_cce_inst_width)
      ,.inst_ram_addr_width_p(inst_ram_addr_width_lp)
      ,.inst_ram_els_p(num_cce_instr_ram_els_p)
      ,.cfg_link_addr_width_p(cfg_addr_width_p)
      ,.cfg_link_data_width_p(cfg_data_width_p)
    )
    cce_inst_ram_loader
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.freeze_o(freeze_lo)
     ,.config_addr_o(config_addr_li)
     ,.config_data_o(config_data_li)
     ,.config_v_o(config_v_li)
     ,.config_w_o(config_w_li)
     ,.config_ready_i(config_ready_lo)
     ,.config_data_i(config_data_lo)
     ,.config_v_i(config_v_lo)
     ,.config_ready_o(config_ready_li)
    );

  bp_cce_top
    #(.cfg_p(cfg_p)
      ,.cce_trace_p(cce_trace_p)
     )
     bp_cce_top
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.freeze_i(freeze_lo)

      ,.config_addr_i(config_addr_li)
      ,.config_data_i(config_data_li)
      ,.config_v_i(config_v_li)
      ,.config_w_i(config_w_li)
      ,.config_ready_o(config_ready_lo)
      ,.config_data_o(config_data_lo)
      ,.config_v_o(config_v_lo)
      ,.config_ready_i(config_ready_li)

      ,.cce_id_i(cce_id)

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
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.lce_sets_p(lce_sets_p)
      ,.mem_els_p(mem_els_lp)
      ,.boot_rom_width_p(boot_rom_width_lp)
      ,.boot_rom_els_p(mem_els_lp)
			,.lce_req_data_width_p(dword_width_p)
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

      ,.boot_rom_addr_o()
      ,.boot_rom_data_i('0)
     );

endmodule
