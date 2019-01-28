/**
 *
 * bp_fe_itlb.v 
 *  
 */

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

import itlb_pkg::*;

module itlb
  #(parameter vaddr_width_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter eaddr_width_p="inv"
    ,parameter btb_indx_width_p="inv"
    ,parameter bht_indx_width_p="inv"
    ,parameter ras_addr_width_p="inv"
    ,parameter asid_width_p="inv"
    ,parameter ppn_start_bit_p="inv"
    ,parameter ppn_width_lp=44
    ,parameter bp_fe_ppn_width_lp=ppn_width_lp
    ,parameter branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
    ,parameter bp_fe_itlb_cmd_width_lp=`bp_fe_itlb_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
    ,parameter bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p)
    ,parameter bp_fe_itlb_queue_width_lp=`bp_fe_itlb_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp)
  )
  (
    input logic clk_i
    ,input logic reset_i

    ,input logic [bp_fe_itlb_cmd_width_lp-1:0]                  fe_itlb_i
    ,input logic                                                fe_itlb_v_i
    ,output logic                                               fe_itlb_ready_o
   
    ,input logic [bp_fe_pc_gen_itlb_width_lp-1:0]               pc_gen_itlb_i
    ,input logic                                                pc_gen_itlb_v_i
    ,output logic                                               pc_gen_itlb_ready_o

    ,output logic [bp_fe_ppn_width_lp-1:0]                      itlb_icache_o
    ,output logic                                               itlb_icache_data_resp_v_o
    ,input logic                                                itlb_icache_data_resp_ready_i

    ,output logic [bp_fe_itlb_queue_width_lp-1:0]               itlb_fe_o
    ,output logic                                               itlb_fe_v_o
    ,input logic                                                itlb_fe_ready_i
   
  );

  // struct declaration
  // be interfaces
  localparam branch_metadata_fwd_width_p=branch_metadata_fwd_width_lp;
  `declare_bp_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
  `declare_bp_fe_itlb_icache_data_resp_s(ppn_width_lp);
  `declare_bp_fe_itlb_cmd_s;
  `declare_bp_fe_itlb_queue_s;
  `declare_bp_fe_pc_gen_itlb_s(eaddr_width_p);

  // structure definition
  bp_fe_itlb_icache_data_resp_s    itlb_icache;
  bp_fe_itlb_cmd_s                 fe_itlb_cmd;
  bp_fe_itlb_queue_s               fe_itlb_queue;
  bp_fe_pc_gen_itlb_s              pc_gen_itlb;

  assign itlb_icache_o             = itlb_icache;
  assign fe_itlb_cmd               = fe_itlb_i;
  assign itlb_fe_o                 = fe_itlb_queue;
  assign pc_gen_itlb               = pc_gen_itlb_i;
  
  logic [bp_fe_ppn_width_lp-1:0]   ppn;

  // pass through 
  assign itlb_icache.ppn           = ppn;
  always @(posedge clk_i) begin
      ppn                          <= pc_gen_itlb.virt_addr[ppn_start_bit_p+bp_fe_ppn_width_lp-1:ppn_start_bit_p];
  end

  assign itlb_icache_data_resp_v_o = 1'b1;
  assign pc_gen_itlb_ready_o       = 1'b1;
//  assign pc_gen_itlb_ready_o       = itlb_icache_data_resp_ready_i ;
  
endmodule
