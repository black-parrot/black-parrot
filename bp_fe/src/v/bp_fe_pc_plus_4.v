
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

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

module branch_prediction
#(

    parameter eaddr_width_p="inv"
    ,parameter btb_indx_width_p="inv"
    ,parameter bht_indx_width_p="inv"
    ,parameter ras_addr_width_p="inv"
    ,parameter branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p

)(
    input logic clk_i
    ,input logic reset_i

    ,input logic                                          attaboy
    ,input logic                                          bp_r_i
    ,input logic                                          bp_w_i
    ,input logic [eaddr_width_p-1:0]                      pc_queue_i
    ,input logic [eaddr_width_p-1:0]                      pc_cmd_i
    ,input logic [eaddr_width_p-1:0]                      pc_fwd_i
    ,input logic  [branch_metadata_fwd_width_lp-1:0]      branch_metadata_fwd_i

    ,output logic                                         predict_o
    ,output logic [eaddr_width_p-1:0]                     pc_o
    ,output logic [branch_metadata_fwd_width_lp-1:0]      branch_metadata_fwd_o

);
    logic                                                 predict;
    logic                                                 read_valid;

    `declare_bp_fe_branch_metadata_fwd_s(btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);

    bp_fe_branch_metadata_fwd_s                           branch_metadata_i;
    bp_fe_branch_metadata_fwd_s                           branch_metadata_o;

    assign branch_metadata_i                              = branch_metadata_fwd_i;
    assign branch_metadata_fwd_o                          = branch_metadata_o;

    assign branch_metadata_o                              = {pc_fwd_i[btb_indx_width_p-1:0], 
                                                             pc_fwd_i[bht_indx_width_p-1:0], 
                                                             ras_addr_width_p'(0)};
    assign predict_o                                      = 1'b0;
    assign pc_o                                           = pc_queue_i + 'd4;

endmodule
