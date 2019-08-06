/**
 *
 * Name:
 *   bp_be_scheduler.v
 * 
 * Description:
 *   Schedules instruction issue from the FE queue to the Calculator.
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *   
 *   fe_queue_i                  - Instruction / PC pair (or exception) from the Front End
 *   fe_queue_v_i                - "valid-then-ready"
 *   fe_queue_ready_o              - 
 *
 * Outputs:
 *
 *   issue_pkt_o                 - Issuing instruction with pre-decode information
 *   issue_pkt_v_o               - "ready-then-valid"
 *   issue_pkt_ready_i             -
 *   
 * Keywords:
 *   checker, schedule, issue
 * 
 * Notes:
 *   It might make sense to use an enum for RISC-V opcodes rather than `defines.
 *   Floating point instruction decoding is not implemented, so we do not predecode.
 *   It might makes sense to split fe_queue_in into a separate module
 */

module bp_be_scheduler
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   // Generated parameters
   , localparam fe_queue_width_lp  = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   // From BP BE defines
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                             clk_i
   , input                           reset_i

   // Fetch interface
   , input [fe_queue_width_lp-1:0]   fe_queue_i
   , input                           fe_queue_v_i
   , output                          fe_queue_ready_o

   // Issue interface
   , output [issue_pkt_width_lp-1:0] issue_pkt_o
   , output                          issue_pkt_v_o
   , input                           issue_pkt_ready_i
   );

// Declare parameterizable structures
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_fe_queue_s     fe_queue;
bp_be_issue_pkt_s issue_pkt;

assign fe_queue    = fe_queue_i;
assign issue_pkt_o = issue_pkt;

bp_fe_fetch_s      fe_fetch;
rv64_instr_s       fe_fetch_instr;
bp_fe_exception_s  fe_exception;

assign fe_fetch           = fe_queue.msg.fetch;
assign fe_fetch_instr     = fe_fetch.instr;
assign fe_exception       = fe_queue.msg.exception;

// Interface handshakes
assign fe_queue_ready_o = fe_queue_v_i & issue_pkt_ready_i;
assign issue_pkt_v_o    = fe_queue_v_i & issue_pkt_ready_i;

// Module instantiations
always_comb 
  begin 
    // Default value
    issue_pkt = '0;

    if (fe_queue_v_i)
      case(fe_queue.msg_type)
        // Populate the issue packet with a valid pc/instruction pair.
        e_fe_fetch : 
          begin
            issue_pkt.pc = fe_fetch.pc;
            issue_pkt.branch_metadata_fwd = fe_fetch.branch_metadata_fwd;
            issue_pkt.instr = fe_fetch.instr;

            // Decide whether to read from integer regfile (saves power)
            casez(fe_fetch_instr.opcode)
              `RV64_LUI_OP, `RV64_AUIPC_OP, `RV64_JAL_OP : 
                begin 
                  issue_pkt.irs1_v = '0; 
                  issue_pkt.irs2_v = '0;
                end
              `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_SYSTEM_OP :
                begin 
                  issue_pkt.irs1_v = '1; 
                  issue_pkt.irs2_v = '0;
                end
              `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP, `RV64_AMO_OP: 
                begin 
                  issue_pkt.irs1_v = '1; 
                  issue_pkt.irs2_v = '1; 
                end
              default : 
                begin
                  // Should not reach
                  issue_pkt.irs1_v = '0;
                  issue_pkt.irs2_v = '0;
                end
            endcase

            // Decide whether to read from floating point regfile (saves power)
            issue_pkt.frs1_v = '0;
            issue_pkt.frs2_v = '0;

            issue_pkt.fence_v = (fe_fetch_instr.opcode == `RV64_MISC_MEM_OP);
            
            casez(fe_fetch_instr.opcode)
              `RV64_STORE_OP, `RV64_LOAD_OP, `RV64_AMO_OP: 
                       issue_pkt.mem_v = 1'b1;
              default: issue_pkt.mem_v = 1'b0;
            endcase
                      
            // Immediate extraction
            casez(fe_fetch_instr.opcode)
              `RV64_LUI_OP, `RV64_AUIPC_OP : issue_pkt.imm = `rv64_signext_u_imm(fe_fetch_instr);
              `RV64_JAL_OP                 : issue_pkt.imm = `rv64_signext_j_imm(fe_fetch_instr);
              `RV64_BRANCH_OP              : issue_pkt.imm = `rv64_signext_b_imm(fe_fetch_instr);
              `RV64_STORE_OP               : issue_pkt.imm = `rv64_signext_s_imm(fe_fetch_instr);
              `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP 
                                           : issue_pkt.imm = `rv64_signext_i_imm(fe_fetch_instr);
                                           
              // Should not reach
              default : issue_pkt.imm = '0;
            endcase
          end

        // FE exceptions only have an exception address, code and flag. 
        e_fe_exception : 
          begin
            issue_pkt.pc = fe_exception.vaddr;
            issue_pkt.fe_exception_not_instr = 1'b1;
            issue_pkt.fe_exception_code = fe_exception.exception_code;
          end

        // Should not reach
        default : begin end
      endcase
  end

endmodule : bp_be_scheduler

