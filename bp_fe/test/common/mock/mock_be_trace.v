
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
   , localparam reg_data_width_lp = rv64_reg_data_width_gp

)(

    input logic clk_i
    ,input logic reset_i

    ,output logic [bp_fe_cmd_width_lp-1:0]                 bp_fe_cmd_o
    ,output logic                                          bp_fe_cmd_v_o
    ,input  logic                                          bp_fe_cmd_ready_i

    ,input  logic [bp_fe_queue_width_lp-1:0]               bp_fe_queue_i
    ,input  logic                                          bp_fe_queue_v_i
    ,output logic                                          bp_fe_queue_ready_o

    ,output logic                                          bp_fe_queue_clr_o

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

bp_fe_queue_s                 bp_fe_queue;
bp_fe_cmd_s                   bp_fe_cmd;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;

assign bp_fe_queue = bp_fe_queue_i;
assign bp_fe_cmd_o = bp_fe_cmd;

bp_proc_cfg_s proc_cfg;

logic chk_psn_ex;

logic [reg_data_width_lp-1:0] next_btarget_r, next_btarget_n;

logic redirect_pending_r;

// cmd block
always_comb begin : be_cmd_gen
    bp_fe_cmd_v_o     = bp_fe_queue_ready_o 
                        & trace_ready_i 
                        & (bp_fe_queue.msg.fetch.pc != next_btarget_r) 
                        & ~redirect_pending_r;
    bp_fe_queue_clr_o = bp_fe_cmd_v_o;

    bp_fe_cmd.opcode                                 = e_op_pc_redirection;
    fe_cmd_pc_redirect_operands.pc                   = next_btarget_r;
    fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
    fe_cmd_pc_redirect_operands.branch_metadata_fwd  = bp_fe_queue.msg.fetch.branch_metadata_fwd;
    fe_cmd_pc_redirect_operands.misprediction_reason = e_incorrect_prediction;

    bp_fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;
end


assign trace_yumi_o = trace_v_i;
always_ff @(posedge clk_i) begin
  if (reset_i) begin
    next_btarget_r <= '0;
    redirect_pending_r <= '0;
  end else begin
    next_btarget_r <= next_btarget_n;
    redirect_pending_r <= (bp_fe_cmd_v_o & bp_fe_cmd_ready_i)
                          ? 1'b1
                          : redirect_pending_r 
                            & ~(bp_fe_queue_ready_o & (bp_fe_queue.msg.fetch.pc == next_btarget_r));
  end
end

always_comb begin
  if (trace_v_i) begin
    next_btarget_n = trace_data_i[32+:64];
  end else if(trace_v_o) begin
    next_btarget_n = next_btarget_r + reg_data_width_lp'(4);
  end else begin
    next_btarget_n = next_btarget_r;
  end
end

// queue block
always_comb begin : be_queue_gen
  trace_data_o = {bp_fe_queue.msg.fetch.pc, bp_fe_queue.msg.fetch.instr};

  trace_v_o           = bp_fe_queue_v_i 
                        & trace_ready_i 
                        & (bp_fe_queue.msg.fetch.pc == next_btarget_r);
  bp_fe_queue_ready_o = bp_fe_queue_v_i; 
end

logic do_fetch;
assign do_fetch = bp_fe_queue_ready_o ;

endmodule

