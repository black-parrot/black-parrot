/**
 *
 * bp_be_fe_adapter.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_rv_defines.vh"
`include "bp_be_internal_if.vh"

module bp_be_fe_adapter
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"

   , localparam fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
   , localparam fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p,paddr_width_p
                                               ,branch_metadata_fwd_width_p,asid_width_p)
   , localparam chk_npc_status_lp=`bp_be_chk_npc_status_width(branch_metadata_fwd_width_p)
   , localparam fe_adapter_issue_width_lp=`bp_be_fe_adapter_issue_width(branch_metadata_fwd_width_p)

   , localparam itag_width_lp=bp_be_itag_width_gp
   )
  (input logic clk_i
   , input logic reset_i

   , input logic [fe_queue_width_lp-1:0]          fe_queue_i
   , input logic                                  fe_queue_v_i
   , output logic                                 fe_queue_rdy_o

   , output logic                                 fe_queue_clr_o
   , output logic                                 fe_queue_ckpt_inc_o
   , output logic                                 fe_queue_rollback_o

    /* TODO: Fix */
   , output logic [109-1:0]                       fe_cmd_o
   , output logic                                 fe_cmd_v_o
   , input logic                                  fe_cmd_rdy_i

   , input logic [chk_npc_status_lp-1:0]          chk_npc_status_i
   , input logic                                  chk_issue_v_i
   , input logic                                  chk_instr_ckpt_v_i
   , input logic                                  chk_roll_i

   , output logic [fe_adapter_issue_width_lp-1:0] fe_adapter_issue_o
   , output logic                                 fe_adapter_issue_v_o
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports 
bp_fe_queue_s            fe_queue;
bp_fe_cmd_s              fe_cmd;
bp_be_chk_npc_status_s   chk_npc_status;
bp_be_fe_adapter_issue_s fe_adapter_issue;

assign fe_queue           = fe_queue_i;
assign fe_cmd_o           = fe_cmd;
assign chk_npc_status     = chk_npc_status_i;
assign fe_adapter_issue_o = fe_adapter_issue;

// Suppress unused signal warnings
wire unused2 = fe_cmd_rdy_i;   // TODO: Can the fe_cmd queue fill up?

// Internal signals
bp_be_instr_metadata_s           fe_instr_metadata;
bp_fe_fetch_s                    fe_fetch;
bp_be_instr_s                    fe_fetch_instr;
bp_fe_exception_s                fe_exception;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
logic [itag_width_lp-1:0]        itag_n, itag_r;

assign fe_fetch           = fe_queue.msg.fetch;
assign fe_fetch_instr     = fe_fetch.instr;
assign fe_exception       = fe_queue.msg.exception;

// Module instantiations
assign itag_n = itag_r + itag_width_lp'(1);
bsg_dff_reset_en #(.width_p(itag_width_lp)
                   )
          itag_reg(.clk_i(clk_i)
                   ,.reset_i(reset_i)
                   ,.en_i(chk_issue_v_i)

                   ,.data_i(itag_n)
                   ,.data_o(itag_r)
                   );

always_comb begin : fe_queue_adapter
    fe_queue_rdy_o = chk_issue_v_i & ~fe_queue_rollback_o & ~fe_queue_clr_o;

    case(fe_queue.msg_type)
        e_fe_fetch: begin
            fe_instr_metadata.itag                   = itag_r;
            fe_instr_metadata.pc                     = fe_fetch.pc;
            fe_instr_metadata.fe_exception_not_instr = '0;
            // VCS doesn't like don't care for enums.
            fe_instr_metadata.fe_exception_code      = e_illegal_instruction; 
            fe_instr_metadata.branch_metadata_fwd    = fe_fetch.branch_metadata_fwd;

            fe_adapter_issue.instr_metadata = fe_instr_metadata;
            fe_adapter_issue.instr          = fe_fetch_instr;
            casez(fe_fetch_instr.opcode)
                `RV64_LUI_OP, `RV64_AUIPC_OP, `RV64_JAL_OP : begin 
                    fe_adapter_issue.irs1_v = '0; 
                    fe_adapter_issue.irs2_v = '0;
                end
                `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP : begin 
                    fe_adapter_issue.irs1_v = '1; 
                    fe_adapter_issue.irs2_v = '0;
                end
                `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP : begin 
                    fe_adapter_issue.irs1_v = '1; 
                    fe_adapter_issue.irs2_v = '1; 
                end
                default: begin
                    fe_adapter_issue.irs1_v = 'X;
                    fe_adapter_issue.irs2_v = 'X;
                end
            endcase
            fe_adapter_issue.frs1_v         = '0;
            fe_adapter_issue.frs2_v         = '0;
            fe_adapter_issue.rs1_addr       = fe_fetch_instr.rs1_addr;
            fe_adapter_issue.rs2_addr       = fe_fetch_instr.rs2_addr;
            casez(fe_fetch_instr.opcode)
                `RV64_LUI_OP, `RV64_AUIPC_OP
                                  : fe_adapter_issue.imm = `RV64_signext_Uimm(fe_fetch_instr);
                `RV64_JAL_OP      : fe_adapter_issue.imm = `RV64_signext_Jimm(fe_fetch_instr);
                `RV64_BRANCH_OP   : fe_adapter_issue.imm = `RV64_signext_Bimm(fe_fetch_instr);
                `RV64_STORE_OP    : fe_adapter_issue.imm = `RV64_signext_Simm(fe_fetch_instr);
                `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP
                                  : fe_adapter_issue.imm = `RV64_signext_Iimm(fe_fetch_instr);
                default           : fe_adapter_issue.imm = 'X;
            endcase

            fe_adapter_issue_v_o            = fe_queue_v_i & fe_queue_rdy_o;
        end

        e_fe_exception: begin
            fe_instr_metadata.pc = {{(RV64_reg_data_width_gp-vaddr_width_p){1'b1}}
                                     ,fe_exception.vaddr}; 
            fe_instr_metadata.fe_exception_not_instr = '1;
            fe_instr_metadata.fe_exception_code      = fe_exception.exception_code;
            fe_instr_metadata.branch_metadata_fwd    = 'X;

            fe_adapter_issue = 'X;
            fe_adapter_issue.instr_metadata = fe_instr_metadata;
            fe_adapter_issue.irs1_v         = '0;
            fe_adapter_issue.irs2_v         = '0;
            fe_adapter_issue.frs1_v         = '0;
            fe_adapter_issue.frs2_v         = '0;

            fe_adapter_issue_v_o            = fe_queue_v_i & fe_queue_rdy_o;
        end

        default : begin 
            fe_adapter_issue = 'X;
            fe_adapter_issue_v_o = 'X;
        end
    endcase
end

always_comb begin : fe_queue_aux
    fe_queue_clr_o      = fe_cmd_v_o & (fe_cmd.opcode == e_op_pc_redirection);
    fe_queue_ckpt_inc_o = chk_instr_ckpt_v_i;
    fe_queue_rollback_o = chk_roll_i;
end

always_comb begin : fe_cmd_adapter
    fe_cmd = 'b0;
    fe_cmd_v_o = 1'b0;

    if(chk_npc_status.isd_v & chk_npc_status.incorrect_npc) begin : pc_redirect
        fe_cmd_pc_redirect_operands.pc                  = chk_npc_status.npc_expected;
        fe_cmd_pc_redirect_operands.subopcode           = e_subop_branch_mispredict;
        fe_cmd_pc_redirect_operands.branch_metadata_fwd = chk_npc_status.branch_metadata_fwd;

        if(chk_npc_status.br_or_jmp_v) begin
            fe_cmd_pc_redirect_operands.misprediction_reason = e_incorrect_prediction;
        end else begin
            fe_cmd_pc_redirect_operands.misprediction_reason = e_not_a_branch;
        end

        fe_cmd.opcode                        = e_op_pc_redirection;
        fe_cmd.operands.pc_redirect_operands = fe_cmd_pc_redirect_operands;
        fe_cmd_v_o = 1'b1;
    end
end

endmodule : bp_be_fe_adapter

