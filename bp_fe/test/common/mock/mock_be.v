
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
//import pc_gen_pkg::*;

module mock_be
#(
    parameter vaddr_width_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter eaddr_width_p="inv"
    ,parameter btb_idx_width_p="inv"
    ,parameter bht_idx_width_p="inv"
    ,parameter ras_idx_width_p="inv"
    ,parameter asid_width_p="inv"
    ,parameter instr_width_p="inv"
    ,parameter branch_metadata_fwd_width_lp=btb_idx_width_p+bht_idx_width_p+ras_idx_width_p
    ,parameter bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
    ,parameter bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp)
)(

    input logic clk_i
    ,input logic reset_i

    ,output logic [bp_fe_cmd_width_lp-1:0]                 bp_fe_cmd_o
    ,output logic                                          bp_fe_cmd_v_o
    ,input  logic                                          bp_fe_cmd_ready_i

    ,input  logic [bp_fe_queue_width_lp-1:0]               bp_fe_queue_i
    ,input  logic                                          bp_fe_queue_v_i
    ,output logic                                          bp_fe_queue_ready_o

);

// be fe interface udpate (not sure if this is needed)
  localparam branch_metadata_fwd_width_p = branch_metadata_fwd_width_lp; 
   `declare_bp_fe_be_if(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
    `declare_bp_fe_branch_metadata_fwd_s(btb_idx_width_p,bht_idx_width_p,ras_idx_width_p);
   bp_fe_branch_metadata_fwd_s                           branch_metadata_fwd;

// fe to be
bp_fe_queue_s                                         bp_fe_queue;
// be to fe
bp_fe_cmd_s                                           bp_fe_cmd;

// queue_s
bp_fe_queue_type_e                                    msg_type;
// fetch
// instruction from bp_fe_queue.fetch
logic [instr_width_p-1:0]                            instr;
logic [eaddr_width_p-1:0]                             pc;
// exception
// vaddr from bp_fe_queue.exception
logic [vaddr_width_p-1:0]                             vaddr;


// cmd_s
logic [eaddr_width_p-1:0]                             cmd_pc;

bp_fe_command_queue_opcodes_e                         bp_fe_cmd_opcode;
assign bp_fe_cmd_opcode                               = bp_fe_cmd.opcode;
assign cmd_pc                                         = bp_fe_cmd.operands.pc_redirect_operands.pc;

assign bp_fe_cmd_o                                    = bp_fe_cmd;
assign bp_fe_queue                                    = bp_fe_queue_i;

task pc_redirect_hit;
    bp_fe_cmd.opcode <= e_op_pc_redirection;
    bp_fe_cmd.operands.pc_redirect_operands.pc <= 64'h0000000c; 
    bp_fe_cmd.operands.pc_redirect_operands.subopcode <= e_subop_branch_mispredict;
    bp_fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd <= branch_metadata_fwd;
    bp_fe_cmd.operands.pc_redirect_operands.misprediction_reason <= e_incorrect_prediction;
    bp_fe_cmd.operands.pc_redirect_operands.translation_enabled <=  0;
endtask

task pc_redirect_miss;
    bp_fe_cmd.opcode <= e_op_pc_redirection;
    bp_fe_cmd.operands.pc_redirect_operands.pc <= 64'h10000050; 
    bp_fe_cmd.operands.pc_redirect_operands.subopcode <= e_subop_branch_mispredict;
    bp_fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd <= branch_metadata_fwd;
    bp_fe_cmd.operands.pc_redirect_operands.misprediction_reason <= e_incorrect_prediction;
    bp_fe_cmd.operands.pc_redirect_operands.translation_enabled <=  0;
endtask

task attaboy;
    bp_fe_cmd.opcode <= e_op_attaboy;
    bp_fe_cmd.operands.attaboy.pc <= 64'h0000000c;
    bp_fe_cmd.operands.attaboy.branch_metadata_fwd <= branch_metadata_fwd;
    bp_fe_cmd.operands.attaboy.padding <= '0;
endtask

task icache_fence;
    bp_fe_cmd.opcode <= e_op_icache_fence;
endtask

task state_reset;
    bp_fe_cmd.opcode <= e_op_state_reset;
endtask

task interrupt;
    bp_fe_cmd.opcode <= e_op_interrupt;
    bp_fe_cmd.operands.pc_redirect_operands.pc <= 64'h10000200; 
    bp_fe_cmd.operands.pc_redirect_operands.subopcode <= e_subop_interrupt;
    bp_fe_cmd.operands.pc_redirect_operands.branch_metadata_fwd <= branch_metadata_fwd;
    bp_fe_cmd.operands.pc_redirect_operands.translation_enabled <=  0;
endtask

logic           first_predict;

always_ff @(posedge clk_i) begin : be_cmd_gen

    if (reset_i) 
        first_predict = 1'b1;

    if (bp_fe_cmd_ready_i) begin
        if (pc == 'h00000020) begin
             bp_fe_cmd_v_o           = 1'b1;
             if (first_predict) begin
                 pc_redirect_hit();
                 first_predict = 1'b0;
             end else
                 attaboy();
             //pc_redirect_miss();
             //interrupt();
        end else begin
             bp_fe_cmd_v_o           = 1'b0;
             attaboy();
        end
    end

end;

always_comb begin : be_queue_gen
    //if (pc == 'h0000001c) 
    //    bp_fe_queue_ready_o     = 1'b0;
    //else
    bp_fe_queue_ready_o     = bp_fe_queue_v_i;

    msg_type                = bp_fe_queue.msg_type;
    
    if (bp_fe_queue_v_i) begin
         case (bp_fe_queue.msg_type) 
              e_fe_fetch: begin 
                                instr = bp_fe_queue.msg.fetch.instr;
                                pc    = bp_fe_queue.msg.fetch.pc;
                                branch_metadata_fwd = bp_fe_queue.msg.fetch.branch_metadata_fwd;
                          end
              e_fe_exception:   vaddr = bp_fe_queue.msg.exception.vaddr;
         endcase
    end
end;

endmodule
