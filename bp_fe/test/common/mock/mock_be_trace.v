
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
    ,parameter trace_addr_width_p="inv"
    ,parameter trace_data_width_p="inv"

    ,localparam total_trace_instr_count_p=512

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
    ,output logic                                          bp_fe_queue_ready_o

    ,output logic [trace_addr_width_p-1:0]                 trace_addr_o
    ,input  logic [trace_data_width_p-1:0]                 trace_data_i

   // LCE-CCE interface
    , output [lce_cce_req_width_lp-1:0]                    lce_cce_req_o
    , output                                               lce_cce_req_v_o
    , input                                                lce_cce_req_rdy_i

    , output [lce_cce_resp_width_lp-1:0]                   lce_cce_resp_o
    , output                                               lce_cce_resp_v_o
    , input                                                lce_cce_resp_rdy_i                                 

    , output [lce_cce_data_resp_width_lp-1:0]              lce_cce_data_resp_o
    , output                                               lce_cce_data_resp_v_o
    , input                                                lce_cce_data_resp_rdy_i

    , input [cce_lce_cmd_width_lp-1:0]                     cce_lce_cmd_i
    , input                                                cce_lce_cmd_v_i
    , output                                               cce_lce_cmd_rdy_o

    , input [cce_lce_data_cmd_width_lp-1:0]                cce_lce_data_cmd_i
    , input                                                cce_lce_data_cmd_v_i
    , output                                               cce_lce_data_cmd_rdy_o

    , input [lce_lce_tr_resp_width_lp-1:0]                 lce_lce_tr_resp_i
    , input                                                lce_lce_tr_resp_v_i
    , output                                               lce_lce_tr_resp_rdy_o

    , output [lce_lce_tr_resp_width_lp-1:0]                lce_lce_tr_resp_o
    , output                                               lce_lce_tr_resp_v_o
    , input                                                lce_lce_tr_resp_rdy_i

);

logic [total_trace_instr_count_p-1:0] instr_count;
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

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_mmu_resp_s mmu_resp;
logic mmu_resp_v, mmu_resp_rdy;

logic chk_psn_ex;

// cmd block
always_ff @(posedge clk_i) begin : be_cmd_gen
    bp_fe_cmd_v_o       = '0;
    //
    if (reset_i) 
        instr_count <= '0;
    else
        instr_count <= instr_count + '1;
end;
// queue block
always_comb begin : be_queue_gen
    //bp_fe_queue_ready_o     = bp_fe_queue_v_i;
    bp_fe_queue_ready_o     = '1;
end;


bp_be_mmu_top
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   )
 be_mmu
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mmu_cmd_i(mmu_cmd)
    ,.mmu_cmd_v_i(mmu_cmd_v)
    ,.mmu_cmd_ready_o(mmu_cmd_rdy)

    ,.chk_psn_ex_i(chk_psn_ex)

    ,.mmu_resp_o(mmu_resp)
    ,.mmu_resp_v_o(mmu_resp_v)
    ,.mmu_resp_ready_i(mmu_resp_rdy)      

    ,.lce_req_o(lce_cce_req_o)
    ,.lce_req_v_o(lce_cce_req_v_o)
    ,.lce_req_ready_i(lce_cce_req_rdy_i)

    ,.lce_resp_o(lce_cce_resp_o)
    ,.lce_resp_v_o(lce_cce_resp_v_o)
    ,.lce_resp_ready_i(lce_cce_resp_rdy_i)        

    ,.lce_data_resp_o(lce_cce_data_resp_o)
    ,.lce_data_resp_v_o(lce_cce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_cce_data_resp_rdy_i)

    ,.lce_cmd_i(cce_lce_cmd_i)
    ,.lce_cmd_v_i(cce_lce_cmd_v_i)
    ,.lce_cmd_ready_o(cce_lce_cmd_rdy_o)

    ,.lce_data_cmd_i(cce_lce_data_cmd_i)
    ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(cce_lce_data_cmd_rdy_o)

    ,.lce_tr_resp_i(lce_lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_lce_tr_resp_rdy_o)

    ,.lce_tr_resp_o(lce_lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_lce_tr_resp_rdy_i)

    ,.dcache_id_i(proc_cfg.dcache_id)
    );


endmodule
