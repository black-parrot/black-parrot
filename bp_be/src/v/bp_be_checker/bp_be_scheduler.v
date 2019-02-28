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
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   // Generated parameters
   , localparam fe_queue_width_lp  = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(branch_metadata_fwd_width_p)
   // From BP BE defines
   , localparam itag_width_lp     = bp_be_itag_width_gp
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
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports 
bp_fe_queue_s     fe_queue;
bp_be_issue_pkt_s issue_pkt;

assign fe_queue    = fe_queue_i;
assign issue_pkt_o = issue_pkt;

bp_fe_fetch_s      fe_fetch;
bp_be_instr_s      fe_fetch_instr;
bp_fe_exception_s  fe_exception;

assign fe_fetch           = fe_queue.msg.fetch;
assign fe_fetch_instr     = fe_fetch.instr;
assign fe_exception       = fe_queue.msg.exception;

// Declare intermediate signals
bp_be_instr_metadata_s           fe_instr_metadata;
bp_fe_cmd_pc_redirect_operands_s fe_cmd_pc_redirect_operands;
logic [itag_width_lp-1:0]        itag_n, itag_r;
logic [reg_data_width_lp-1:0]    exception_eaddr;

assign exception_eaddr = rv64_reg_data_width_gp'($signed(fe_exception.vaddr));

// Interface handshakes
assign fe_queue_ready_o = fe_queue_v_i & issue_pkt_ready_i;
assign issue_pkt_v_o    = fe_queue_v_i & issue_pkt_ready_i;

// Module instantiations
// Each issued instruction should get a new itag
assign itag_n = itag_r + itag_width_lp'(1);
bsg_dff_reset_en 
 #(.width_p(itag_width_lp)
   )
 itag_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i((issue_pkt_ready_i & issue_pkt_v_o))

   ,.data_i(itag_n)
   ,.data_o(itag_r)
   );


assign issue_pkt.instr_metadata = fe_instr_metadata;
assign issue_pkt.instr          = fe_fetch_instr;
always_comb 
  begin : fe_queue_extract

    // Default value
    fe_instr_metadata = '0;

    case(fe_queue.msg_type)
      // Populate the issue packet with a valid pc/instruction pair.
      e_fe_fetch : 
        begin
          fe_instr_metadata.itag                   = itag_r;
          fe_instr_metadata.pc                     = fe_fetch.pc;
          fe_instr_metadata.fe_exception_not_instr = 1'b0;
          fe_instr_metadata.branch_metadata_fwd    = fe_fetch.branch_metadata_fwd;

          // Decide whether to read from integer regfile (saves power)
          casez(fe_fetch_instr.opcode)
            `RV64_LUI_OP, `RV64_AUIPC_OP, `RV64_JAL_OP : 
              begin 
                issue_pkt.irs1_v = '0; 
                issue_pkt.irs2_v = '0;
              end
            `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP : 
              begin 
                issue_pkt.irs1_v = '1; 
                issue_pkt.irs2_v = '0;
              end
            `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP : 
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

          // Register addresses are always in the same place in the instruction
          issue_pkt.rs1_addr = fe_fetch_instr.rs1_addr;
          issue_pkt.rs2_addr = fe_fetch_instr.rs2_addr;

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

      // FE exceptions only have an exception address, code and flag. All of these fields 
      //   are in instr_metadata field of the issue packet.
      e_fe_exception : 
        begin
          fe_instr_metadata.pc                     = exception_eaddr;
          fe_instr_metadata.fe_exception_not_instr = 1'b1;
          fe_instr_metadata.fe_exception_code      = fe_exception.exception_code;
          // branch_metadata is meaningless for a FE exception
          fe_instr_metadata.branch_metadata_fwd    = '0; 
        end

      // Should not reach
      default : begin end
    endcase
  end

endmodule : bp_be_scheduler

