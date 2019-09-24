/**
 *
 * Name:
 *   bp_be_scheduler.v
 * 
 * Description:
 *   Schedules instruction issue from the FE queue to the Calculator.
 *
 * Notes:
 *   It might make sense to use an enum for RISC-V opcodes rather than `defines.
 *   Floating point instruction decoding is not implemented, so we do not predecode.
 */

module bp_be_scheduler
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   // Generated parameters
   , localparam fe_queue_width_lp  = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   )
  (input                             clk_i
   , input                           reset_i

   , input                           cache_miss_v_i
   , input                           cmt_v_i

   // Fetch interface
   , output                          fe_queue_roll_o
   , output                          fe_queue_deq_o

   , input [fe_queue_width_lp-1:0]   fe_queue_i
   , input                           fe_queue_v_i
   , output                          fe_queue_yumi_o

   // Issue interface
   , output [issue_pkt_width_lp-1:0] issue_pkt_o
   , output                          issue_pkt_v_o
   , input                           issue_pkt_ready_i
   );

wire unused = &{clk_i, reset_i};

// Declare parameterizable structures
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_fe_queue_s     fe_queue_cast_i;
bp_be_issue_pkt_s issue_pkt_cast_o;
rv64_instr_s      fetch_instr;

assign fe_queue_cast_i = fe_queue_i;
assign issue_pkt_o     = issue_pkt_cast_o;
assign fetch_instr     = fe_queue_cast_i.msg.fetch.instr;

always_comb
  case (fe_queue_cast_i.msg_type)
    // Populate the issue packet with a valid pc/instruction pair.
    e_fe_fetch: 
      begin
        issue_pkt_cast_o = '0;

        issue_pkt_cast_o.fe_exception_not_instr = 1'b0;
        issue_pkt_cast_o.pc                     = fe_queue_cast_i.msg.fetch.pc;
        issue_pkt_cast_o.branch_metadata_fwd    = fe_queue_cast_i.msg.fetch.branch_metadata_fwd;
        issue_pkt_cast_o.instr                  = fe_queue_cast_i.msg.fetch.instr;

        // Decide whether to read from integer regfile (saves power)
        casez (fetch_instr.opcode)
          `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_SYSTEM_OP :
            begin 
              issue_pkt_cast_o.irs1_v = '1; 
              issue_pkt_cast_o.irs2_v = '0;
            end
          `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP, `RV64_AMO_OP: 
            begin 
              issue_pkt_cast_o.irs1_v = '1; 
              issue_pkt_cast_o.irs2_v = '1; 
            end
          default: begin end
        endcase

        // Decide whether to read from floating point regfile (saves power)
        issue_pkt_cast_o.frs1_v = '0;
        issue_pkt_cast_o.frs2_v = '0;

        // Pre-decode
        issue_pkt_cast_o.fence_v = (fetch_instr.opcode == `RV64_MISC_MEM_OP);
        
        // Immediate extraction
        unique casez (fetch_instr.opcode)
          `RV64_LUI_OP, `RV64_AUIPC_OP: 
            issue_pkt_cast_o.imm = `rv64_signext_u_imm(fetch_instr);
          `RV64_JAL_OP: 
            issue_pkt_cast_o.imm = `rv64_signext_j_imm(fetch_instr);
          `RV64_BRANCH_OP: 
            issue_pkt_cast_o.imm = `rv64_signext_b_imm(fetch_instr);
          `RV64_STORE_OP: 
            issue_pkt_cast_o.imm = `rv64_signext_s_imm(fetch_instr);
          `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP: 
            issue_pkt_cast_o.imm = `rv64_signext_i_imm(fetch_instr);
          `RV64_SYSTEM_OP:
            issue_pkt_cast_o.imm = `rv64_signext_c_imm(fetch_instr);
          default: begin end
        endcase
      end

    // FE exceptions only have an exception address, code and flag. 
    e_fe_exception: 
      begin
        issue_pkt_cast_o = '0;

        issue_pkt_cast_o.fe_exception_not_instr = 1'b1;
        issue_pkt_cast_o.fe_exception_code      = fe_queue_cast_i.msg.exception.exception_code;
        issue_pkt_cast_o.pc                     = fe_queue_cast_i.msg.exception.vaddr;
      end
    default: begin end
  endcase

// Interface handshakes
assign fe_queue_yumi_o = fe_queue_v_i & issue_pkt_ready_i;
assign issue_pkt_v_o   = fe_queue_yumi_o;

// Queue control signals
assign fe_queue_roll_o = cache_miss_v_i;
assign fe_queue_deq_o  = ~cache_miss_v_i & cmt_v_i;

endmodule

