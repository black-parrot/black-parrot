/**
 *
 * wrapper.v
 *
 */

module wrapper
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Used to enable trace replay outputs for testbench
   , parameter trace_p = 1
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // This will go away with the manycore bridge
   , output logic [num_cce_p-1:0][`BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)-1:0] cce_inst_boot_rom_addr_o
   , input logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]                        cce_inst_boot_rom_data_i

   , input [num_cce_p-1:0][mem_cce_resp_width_lp-1:0]         mem_resp_i
   , input [num_cce_p-1:0]                                    mem_resp_v_i
   , output [num_cce_p-1:0]                                   mem_resp_ready_o

   , input [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0]    mem_data_resp_i
   , input [num_cce_p-1:0]                                    mem_data_resp_v_i
   , output [num_cce_p-1:0]                                   mem_data_resp_ready_o

   , output [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0]         mem_cmd_o
   , output [num_cce_p-1:0]                                   mem_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_cmd_yumi_i

   , output [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output [num_cce_p-1:0]                                   mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_data_cmd_yumi_i

   , input                                                    external_int_i

   // Commit tracer for trace replay
   , output [num_core_p-1:0]                                  cmt_rd_w_v_o
   , output [num_core_p-1:0][rv64_reg_addr_width_gp-1:0]      cmt_rd_addr_o
   , output [num_core_p-1:0]                                  cmt_mem_w_v_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_mem_addr_o
   , output [num_core_p-1:0][`bp_be_fu_op_width-1:0]          cmt_mem_op_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_data_o
  );

  bp_top
   #(.cfg_p(cfg_p)
     ,.trace_p(trace_p)
     )
   dut
    (.*);

endmodule : wrapper

