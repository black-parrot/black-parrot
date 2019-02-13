/**
 * bp_cce_test.v
 *
 */

`include "bp_common_me_if.vh"

module bp_cce_test
  #(parameter num_lce_p=1
    ,parameter num_cce_p=1
    ,parameter addr_width_p=22 // 10 tag + 6 idx + 6 offset
    ,parameter lce_assoc_p=8
    ,parameter lce_sets_p=64
    ,parameter block_size_in_bytes_p=64
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
    ,parameter num_inst_ram_els_p=256

    ,parameter mem_els_p=512
    ,parameter boot_rom_width_p=512
    ,parameter boot_rom_els_p=512
    ,parameter lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)

    ,parameter bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
    ,parameter bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_p)
    ,parameter bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp)
    ,parameter bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_p, lce_assoc_p)
    ,parameter bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_p, block_size_in_bits_lp, lce_assoc_p)

    ,parameter bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(addr_width_p, num_lce_p, lce_assoc_p)
    ,parameter bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(addr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
    ,parameter bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(addr_width_p, num_lce_p, lce_assoc_p)
    ,parameter bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(addr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)

  )
  (
    input                                                  clk_i
   ,input                                                  reset_i

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

  bp_cce_top
    #(.cce_id_p(0)
      ,.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.addr_width_p(addr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_p)
      ,.num_inst_ram_els_p(num_inst_ram_els_p)
     )
     bp_cce_top
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

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
      ,.addr_width_p(addr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_p)
      ,.lce_sets_p(lce_sets_p)
      ,.mem_els_p(mem_els_p)
      ,.boot_rom_width_p(boot_rom_width_p)
      ,.boot_rom_els_p(boot_rom_els_p)
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
