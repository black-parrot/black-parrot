
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
//`include "bp_fe_pc_gen.vh"
`endif

`ifndef BP_FE_ITLB_VH
`define BP_FE_ITLB_VH
//`include "bp_fe_itlb.vh"
`endif

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH
//`include "bp_fe_icache.vh"
`endif

//import bp_common_pkg::*;
//import itlb_pkg::*;
//import pc_gen_pkg::*;

module mock_be_trace
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
#(
    parameter vaddr_width_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter eaddr_width_p="inv"
    ,parameter asid_width_p="inv"
    ,parameter branch_metadata_fwd_width_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter num_mem_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter lce_sets_p="inv"
   , parameter core_els_p="inv"
    ,parameter cce_block_size_in_bytes_p="inv"
    ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
    ,parameter bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p)
    ,parameter bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
    //trace_rom params
    ,parameter trace_ring_width_p="inv"

   , localparam lce_cce_req_width_lp       = `bp_lce_cce_req_width(num_cce_p
                                                            , num_lce_p
                                                            , paddr_width_p
                                                            , lce_assoc_p
                                                            )
   , localparam lce_cce_resp_width_lp      = `bp_lce_cce_resp_width(num_cce_p
                                                              , num_lce_p
                                                              , paddr_width_p
                                                              )
   , localparam lce_cce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , cce_block_size_in_bits_lp
                                                                        )
   , localparam cce_lce_cmd_width_lp       = `bp_cce_lce_cmd_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam cce_lce_data_cmd_width_lp  = `bp_cce_lce_data_cmd_width(num_cce_p
                                                                       , num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )
   , localparam lce_lce_tr_resp_width_lp   = `bp_lce_lce_tr_resp_width(num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )                                                               

)(

    input logic clk_i
    ,input logic reset_i

    ,output logic [bp_fe_cmd_width_lp-1:0]                 bp_fe_cmd_o
    ,output logic                                          bp_fe_cmd_v_o
    ,input  logic                                          bp_fe_cmd_ready_i

    ,input  logic [bp_fe_queue_width_lp-1:0]               bp_fe_queue_i
    ,input  logic                                          bp_fe_queue_v_i
    ,output logic                                          bp_fe_queue_yumi_o

    // PC / instr validation information
    ,output logic [trace_ring_width_p-1:0]                 trace_data_o
    ,output logic                                          trace_v_o
    ,input  logic                                          trace_ready_i

    // Branch redirection information
    ,input  logic [trace_ring_width_p-1:0]                 trace_data_i
    ,input  logic                                          trace_v_i
    ,output logic                                          trace_yumi_o
);

`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)

// the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p);   
// fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(branch_metadata_fwd_width_p);

// fe to be
bp_fe_queue_s                 bp_fe_queue;
// be to fe
bp_fe_cmd_s                   bp_fe_cmd;

bp_proc_cfg_s proc_cfg;

logic chk_psn_ex;

logic[reg_data_width_lp-1:0] next_btarget;

// cmd block
always_comb begin : be_cmd_gen
    bp_fe_cmd_v_o       = '0;
end

assign trace_yumi_o = trace_v_i;
always_ff @(clk_i) begin
  if (trace_v_i) begin
    next_btarget <= trace_data_i[0+:64];
  end
end

// queue block
always_comb begin : be_queue_gen
  if (bp_fe_queue_v_i) begin
    
  end
end

endmodule

