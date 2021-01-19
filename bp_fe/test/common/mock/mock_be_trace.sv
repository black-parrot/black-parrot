
module mock_be_trace
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_first_pc_p="inv"
   , parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter eaddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter btb_tag_width_p="inv"
   , parameter btb_idx_width_p="inv"
   , parameter bht_idx_width_p="inv"
   , parameter ras_idx_width_p="inv"
   , parameter branch_metadata_fwd_width_p
   , parameter num_cce_p="inv"
   , parameter num_lce_p="inv"
   , parameter num_mem_p="inv"
   , parameter lce_assoc_p="inv"
   , parameter lce_sets_p="inv"
   , parameter num_core_p="inv"
   , parameter cce_block_size_in_bytes_p="inv"
   , localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
   , localparam bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p)
   , localparam  bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
   //trace_rom params
   , parameter trace_ring_width_p="inv"

   , localparam reg_data_width_lp = rv64_reg_data_width_gp

   , localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                           , num_lce_p
                                                           , paddr_width_p
                                                           , lce_assoc_p
                                                           , reg_data_width_lp
                                                           )
   , localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                             , num_lce_p
                                                             , paddr_width_p
                                                             )
   , localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                       , num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       )
   , localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                           , num_lce_p
                                                           , paddr_width_p
                                                           , lce_assoc_p
                                                           )
   , localparam lce_data_cmd_width_lp=`bp_lce_data_cmd_width(num_lce_p
                                                             , cce_block_size_in_bits_lp
                                                             , lce_assoc_p
                                                             )
   , localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                   , paddr_width_p
                                                                   , cce_block_size_in_bits_lp
                                                                   , lce_assoc_p
                                                                   )
   )
 (input logic clk_i
  , input logic reset_i

  , output logic [bp_fe_cmd_width_lp-1:0]                 bp_fe_cmd_o
  , output logic                                          bp_fe_cmd_v_o
  , input  logic                                          bp_fe_cmd_ready_i

  , input  logic [bp_fe_queue_width_lp-1:0]               bp_fe_queue_i
  , input  logic                                          bp_fe_queue_v_i
  , output logic                                          bp_fe_queue_ready_o

  , output logic                                          bp_fe_queue_clr_o

  // PC / instr validation information
  , output logic [trace_ring_width_p-1:0]                 trace_data_o
  , output logic                                          trace_v_o
  , input  logic                                          trace_ready_i

  // Branch redirection information
  , input  logic [trace_ring_width_p-1:0]                 trace_data_i
  , input  logic                                          trace_v_i
  , output logic                                          trace_yumi_o
);


`declare_bp_be_mem_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_common_cfg_bus_s(num_core_p, num_lce_p)

// the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p);
// fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(vaddr_width_p,branch_metadata_fwd_width_p);

bp_fe_queue_s                    bp_fe_queue;
bp_fe_cmd_s                      bp_fe_cmd;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
bp_fe_cmd_itlb_map_s             fe_cmd_itlb_map;

assign bp_fe_queue = bp_fe_queue_i;
assign bp_fe_cmd_o = bp_fe_cmd;

bp_cfg_bus_s cfg_bus;

logic chk_psn_ex;
logic prev_trace_v;

logic prev_tlb_miss;

logic [reg_data_width_lp-1:0] next_btarget_r, next_btarget_n;

logic redirect_pending_r;

logic tlb_miss;

assign tlb_miss = (bp_fe_queue.msg_type == e_fe_exception) & bp_fe_queue.msg.exception.exception_code == e_itlb_miss;

enum logic [1:0] {e_reset, e_boot, e_run} state_n, state_r;
always_comb begin : be_cmd_gen
  if (state_r == e_boot)
    begin
      bp_fe_cmd_v_o = 1'b1;

      bp_fe_cmd.opcode = e_op_state_reset;
      bp_fe_cmd.operands.reset_operands.pc = bp_first_pc_p;
    end
  else
    begin
      bp_fe_cmd_v_o  = bp_fe_queue_v_i & trace_ready_i & (bp_fe_queue.msg.fetch.pc != next_btarget_r) | (~prev_tlb_miss & tlb_miss);
      bp_fe_queue_clr_o = bp_fe_cmd_v_o;
      bp_fe_cmd.opcode                                 = (tlb_miss | prev_tlb_miss) ? e_op_itlb_fill_response : e_op_pc_redirection;
      fe_cmd_pc_redirect_operands.pc                   = next_btarget_r;
      fe_cmd_pc_redirect_operands.subopcode            = e_subop_branch_mispredict;
      fe_cmd_pc_redirect_operands.branch_metadata_fwd  = bp_fe_queue.msg.fetch.branch_metadata_fwd;
      fe_cmd_pc_redirect_operands.misprediction_reason = e_incorrect_prediction;

      fe_cmd_itlb_map.vaddr = bp_fe_queue.msg.exception.vaddr;
      fe_cmd_itlb_map.pte_entry_leaf.ptag = bp_fe_queue.msg.exception.vaddr[38:12];

      if(~tlb_miss | ~prev_tlb_miss)
        bp_fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;
      else
        bp_fe_cmd.operands.itlb_fill_response   = fe_cmd_itlb_map;
    end
end

assign trace_yumi_o = trace_v_i;
always_ff @(posedge clk_i) begin
  if (reset_i) begin
    next_btarget_r <= '0;
    redirect_pending_r <= '0;
    prev_tlb_miss <= 0;
    state_r <= e_reset;
  end else begin
    state_r <= (state_r == e_reset) ? e_boot : e_run;
    prev_tlb_miss  <= tlb_miss;
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
                        & (bp_fe_queue.msg_type == e_fe_fetch)
                        & trace_ready_i
                        & (bp_fe_queue.msg.fetch.pc == next_btarget_r);
  bp_fe_queue_ready_o = bp_fe_queue_v_i;
end

logic do_fetch;
assign do_fetch = bp_fe_queue_ready_o ;

endmodule

