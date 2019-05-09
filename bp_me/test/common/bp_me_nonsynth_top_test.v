/**
 *  bp_me_nonsynth_top_test.v
 */

`include "bp_be_dcache_pkt.vh"

module bp_me_nonsynth_top_test
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
    , parameter mem_els_p="inv"
    , parameter boot_rom_els_p="inv"
    , parameter cce_trace_p = 0
    , parameter axe_trace_p = 0

    , localparam block_size_in_bytes_lp=(cce_block_width_p / 8)

    , localparam lce_id_width_lp=`BSG_SAFE_CLOG2(num_lce_p)

    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)

    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_lce_p-1:0][tr_ring_width_lp-1:0] tr_pkt_i
    , input [num_lce_p-1:0] tr_pkt_v_i
    , output logic [num_lce_p-1:0] tr_pkt_yumi_o

    , input [num_lce_p-1:0] tr_pkt_ready_i
    , output logic [num_lce_p-1:0] tr_pkt_v_o
    , output logic [num_lce_p-1:0][tr_ring_width_lp-1:0] tr_pkt_o
  );

  // Memory End
  //
  `declare_bp_me_if(paddr_width_p,cce_block_width_p,num_lce_p,lce_assoc_p);

  logic [num_cce_p-1:0][inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;
  logic [num_cce_p-1:0][`bp_cce_inst_width-1:0] cce_inst_boot_rom_data;

  bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp;
  logic [num_cce_p-1:0] mem_resp_v;
  logic [num_cce_p-1:0] mem_resp_ready;

  bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp;
  logic [num_cce_p-1:0] mem_data_resp_v;
  logic [num_cce_p-1:0] mem_data_resp_ready;

  bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd;
  logic [num_cce_p-1:0] mem_cmd_v;
  logic [num_cce_p-1:0] mem_cmd_yumi;

  bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd;
  logic [num_cce_p-1:0] mem_data_cmd_v;
  logic [num_cce_p-1:0] mem_data_cmd_yumi;

  bp_me_nonsynth_top #(
    .cfg_p(cfg_p)
    ,.trace_p(0)
    ,.calc_debug_p(0)
    ,.cce_trace_p(cce_trace_p)
    ,.axe_trace_p(axe_trace_p)
  ) me_top (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr)
    ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data)

    ,.tr_pkt_i(tr_pkt_i)
    ,.tr_pkt_v_i(tr_pkt_v_i)
    ,.tr_pkt_yumi_o(tr_pkt_yumi_o)

    ,.tr_pkt_v_o(tr_pkt_v_o)
    ,.tr_pkt_o(tr_pkt_o)
    ,.tr_pkt_ready_i(tr_pkt_ready_i)

    ,.mem_resp_i(mem_resp)
    ,.mem_resp_v_i(mem_resp_v)
    ,.mem_resp_ready_o(mem_resp_ready)

    ,.mem_data_resp_i(mem_data_resp)
    ,.mem_data_resp_v_i(mem_data_resp_v)
    ,.mem_data_resp_ready_o(mem_data_resp_ready)

    ,.mem_cmd_o(mem_cmd)
    ,.mem_cmd_v_o(mem_cmd_v)
    ,.mem_cmd_yumi_i(mem_cmd_yumi)

    ,.mem_data_cmd_o(mem_data_cmd)
    ,.mem_data_cmd_v_o(mem_data_cmd_v)
    ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi)
  );

  for (genvar i = 0; i < num_cce_p; i++) begin
    bp_mem
      #(.num_lce_p(num_lce_p)
        ,.num_cce_p(num_cce_p)
        ,.paddr_width_p(paddr_width_p)
        ,.lce_assoc_p(lce_assoc_p)
        ,.block_size_in_bytes_p(block_size_in_bytes_lp)
        ,.lce_sets_p(lce_sets_p)
        ,.mem_els_p(mem_els_p)
        ,.lce_req_data_width_p(dword_width_p)
        ,.boot_rom_width_p(cce_block_width_p)
        ,.boot_rom_els_p(boot_rom_els_p)
        )
      bp_mem
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.mem_cmd_i(mem_cmd[i])
        ,.mem_cmd_v_i(mem_cmd_v[i])
        ,.mem_cmd_yumi_o(mem_cmd_yumi[i])

        ,.mem_data_cmd_i(mem_data_cmd[i])
        ,.mem_data_cmd_v_i(mem_data_cmd_v[i])
        ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi[i])

        ,.mem_resp_o(mem_resp[i])
        ,.mem_resp_v_o(mem_resp_v[i])
        ,.mem_resp_ready_i(mem_resp_ready[i])

        ,.mem_data_resp_o(mem_data_resp[i])
        ,.mem_data_resp_v_o(mem_data_resp_v[i])
        ,.mem_data_resp_ready_i(mem_data_resp_ready[i])

        ,.boot_rom_addr_o()
        ,.boot_rom_data_i('0)
        );

      bp_cce_inst_rom
        #(.width_p(`bp_cce_inst_width)
          ,.addr_width_p(inst_ram_addr_width_lp)
        ) cce_inst_rom (
          .addr_i(cce_inst_boot_rom_addr[i])
          ,.data_o(cce_inst_boot_rom_data[i])
        );

  end

endmodule
