

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

`ifndef BP_COMMON_FE_BE_IF_VH
`define BP_COMMON_FE_BE_IF_VH
`include "bp_common_fe_be_if.vh"
`endif

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH
`include "bp_fe_pc_gen.vh"
`endif

`ifndef BP_FE_ITLB_VH
`define BP_FE_ITLB_VH
`include "bp_fe_itlb.vh"
`endif

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH
`include "bp_fe_icache.vh"
`endif

//import bp_common_pkg::*;
//import itlb_pkg::*;
import pc_gen_pkg::*;

module mock_be_tb;

localparam btb_idx_width_lp=9;
localparam bht_idx_width_lp=5;
localparam ras_idx_width_lp=bp_vaddr_width_gp;
localparam asid_width_lp=10;
localparam instr_width_lp=32;
localparam branch_metadata_fwd_width_lp=btb_idx_width_lp+bht_idx_width_lp+ras_idx_width_lp;
localparam bp_fe_cmd_width_lp=`bp_fe_cmd_width(bp_vaddr_width_gp,bp_paddr_width_gp,asid_width_lp,branch_metadata_fwd_width_lp);
localparam bp_fe_queue_width_lp=`bp_fe_queue_width(bp_vaddr_width_gp,branch_metadata_fwd_width_lp);

logic clk_i;
logic reset_i;
logic [bp_fe_cmd_width_lp-1:0]                  bp_fe_cmd_o;
logic                                           bp_fe_cmd_v_o;
logic                                           bp_fe_cmd_ready_i;
logic  [bp_fe_queue_width_lp-1:0]               bp_fe_queue_i;
logic                                           bp_fe_queue_v_i;
logic                                           bp_fe_queue_ready_o;

mock_be
#(
.btb_idx_width_lp(btb_idx_width_lp)
,.bht_idx_width_lp(bht_idx_width_lp)
,.ras_idx_width_lp(ras_idx_width_lp)
,.asid_width_lp(asid_width_lp)
,.instr_width_lp(instr_width_lp)
) mock_be_1
(.*);

initial begin
    $display("%s start from here.", __DEBUG__MSG__);
end

endmodule
