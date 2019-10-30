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
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
   , localparam fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam wb_pkt_width_lp     = `bp_be_wb_pkt_width(vaddr_width_p)

   , localparam fp_en_p = 0
   )
  (input                               clk_i
   , input                             reset_i

  // Slow inputs   
  , input [cfg_bus_width_lp-1:0]       cfg_bus_i
  , output [dword_width_p-1:0]         cfg_irf_data_o

  , input                              accept_irq_i
  , output [isd_status_width_lp-1:0]   isd_status_o
  , input [vaddr_width_p-1:0]          expected_npc_i
  , input                              poison_iss_i
  , input                              dispatch_v_i
  , input                              cache_miss_v_i
  , input                              cmt_v_i

  // Fetch interface
  , output                             fe_queue_roll_o
  , output                             fe_queue_deq_o

  , input [fe_queue_width_lp-1:0]      fe_queue_i
  , input                              fe_queue_v_i
  , output                             fe_queue_yumi_o

  // Dispatch interface
  , output [dispatch_pkt_width_lp-1:0] dispatch_pkt_o

  , input [wb_pkt_width_lp-1:0]        wb_pkt_i
  );

wire unused = &{clk_i, reset_i};

// Declare parameterizable structures
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

// Cast input and output ports 
bp_be_isd_status_s  isd_status;
bp_fe_queue_s     fe_queue_cast_i;
bp_be_issue_pkt_s issue_pkt;
rv64_instr_s      fetch_instr;
bp_be_wb_pkt_s    wb_pkt;

assign isd_status_o = isd_status;
assign fe_queue_cast_i = fe_queue_i;
assign fetch_instr     = fe_queue_cast_i.msg.fetch.instr;
assign wb_pkt = wb_pkt_i;

logic issue_pkt_v_r, poison_iss_r;
wire npc_mismatch = issue_pkt_v_r & (expected_npc_i != issue_pkt_r.pc);
bsg_dff_reset_en
 #(.width_p(1))
 issue_status_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(fe_queue_yumi_o | dispatch_v_i | poison_iss_i)

   ,.data_i(poison_iss_i)
   ,.data_o(poison_iss_r)
   );

bp_be_issue_pkt_s issue_pkt_r;
bsg_dff_reset_en
 #(.width_p(1+$bits(bp_be_issue_pkt_s)))
 issue_pkt_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i | cache_miss_v_i)
   ,.en_i(fe_queue_yumi_o | dispatch_v_i)
   
   ,.data_i({fe_queue_yumi_o, issue_pkt})
   ,.data_o({issue_pkt_v_r, issue_pkt_r})
   );

always_comb
  begin
    case (fe_queue_cast_i.msg_type)
      // Populate the issue packet with a valid pc/instruction pair.
      e_fe_fetch: 
        begin
          issue_pkt = '0;

          /* TODO: retain value on ~dispatch */
          issue_pkt.fe_exception_not_instr = 1'b0;
          issue_pkt.pc                     = fe_queue_cast_i.msg.fetch.pc;
          issue_pkt.branch_metadata_fwd    = fe_queue_cast_i.msg.fetch.branch_metadata_fwd;
          issue_pkt.instr                  = fe_queue_cast_i.msg.fetch.instr;

          // Decide whether to read from integer regfile (saves power)
          casez (fetch_instr.opcode)
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
            default: begin end
          endcase

          // Decide whether to read from floating point regfile (saves power)
          issue_pkt.frs1_v = '0;
          issue_pkt.frs2_v = '0;

          // Pre-decode
          issue_pkt.fence_v = (fetch_instr.opcode == `RV64_MISC_MEM_OP);
          
          // Immediate extraction
          unique casez (fetch_instr.opcode)
            `RV64_LUI_OP, `RV64_AUIPC_OP: 
              issue_pkt.imm = `rv64_signext_u_imm(fetch_instr);
            `RV64_JAL_OP: 
              issue_pkt.imm = `rv64_signext_j_imm(fetch_instr);
            `RV64_BRANCH_OP: 
              issue_pkt.imm = `rv64_signext_b_imm(fetch_instr);
            `RV64_STORE_OP: 
              issue_pkt.imm = `rv64_signext_s_imm(fetch_instr);
            `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP: 
              issue_pkt.imm = `rv64_signext_i_imm(fetch_instr);
            `RV64_SYSTEM_OP:
              issue_pkt.imm = `rv64_signext_c_imm(fetch_instr);
            default: begin end
          endcase
        end

      // FE exceptions only have an exception address, code and flag. 
      e_fe_exception: 
        begin
          issue_pkt = '0;

          issue_pkt.fe_exception_not_instr = 1'b1;
          issue_pkt.fe_exception_code      = fe_queue_cast_i.msg.exception.exception_code;
          issue_pkt.pc                     = fe_queue_cast_i.msg.exception.vaddr;
        end
      default: begin end
    endcase
  end

// Interface handshakes
assign fe_queue_yumi_o = fe_queue_v_i & (dispatch_v_i | ~issue_pkt_v_r);

// Queue control signals
assign fe_queue_roll_o = cache_miss_v_i;
assign fe_queue_deq_o  = ~cache_miss_v_i & cmt_v_i;

logic [dword_width_p-1:0] irf_rs1;
logic [dword_width_p-1:0] irf_rs2;
bp_be_regfile
#(.bp_params_p(bp_params_p))
 int_regfile
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_i)
   ,.cfg_data_o(cfg_irf_data_o)

   ,.rd_w_v_i(wb_pkt.rd_w_v)
   ,.rd_addr_i(wb_pkt.rd_addr)
   ,.rd_data_i(wb_pkt.rd_data)

   ,.rs1_r_v_i(fe_queue_yumi_o & issue_pkt.irs1_v)
   ,.rs1_addr_i(issue_pkt.instr.fields.rtype.rs1_addr)
   ,.rs1_data_o(irf_rs1)

   ,.rs2_r_v_i(fe_queue_yumi_o & issue_pkt.irs2_v)
   ,.rs2_addr_i(issue_pkt.instr.fields.rtype.rs2_addr)
   ,.rs2_data_o(irf_rs2)
   );

// Decode the dispatched instruction
logic                  fe_exc_not_instr_isd;
bp_fe_exception_code_e fe_exc_isd;
// Decode the dispatched instruction
bp_be_decode_s          decoded;
bp_be_instr_decoder
 instr_decoder
  (.interrupt_v_i(accept_irq_i)
   ,.fe_exc_not_instr_i(issue_pkt_r.fe_exception_not_instr)
   ,.fe_exc_i(issue_pkt_r.fe_exception_code)
   ,.instr_i(issue_pkt_r.instr)

   ,.decode_o(decoded)
   );

bp_be_dispatch_pkt_s dispatch_pkt;
always_comb
  begin
    // Calculator status ISD stage
    isd_status.isd_v        = issue_pkt_v_r & ~poison_iss_r & ~poison_iss_i;
    isd_status.isd_pc       = issue_pkt_r.pc;
    isd_status.isd_branch_metadata_fwd = issue_pkt_r.branch_metadata_fwd;
    isd_status.isd_fence_v  = issue_pkt_v_r & issue_pkt_r.fence_v;
    isd_status.isd_mem_v    = issue_pkt_v_r & issue_pkt_r.mem_v;
    isd_status.isd_irs1_v   = issue_pkt_v_r & issue_pkt_r.irs1_v;
    isd_status.isd_frs1_v   = issue_pkt_v_r & issue_pkt_r.frs1_v;
    isd_status.isd_rs1_addr = issue_pkt_r.instr.fields.rtype.rs1_addr;
    isd_status.isd_irs2_v   = issue_pkt_v_r & issue_pkt_r.irs2_v;
    isd_status.isd_frs2_v   = issue_pkt_v_r & issue_pkt_r.frs2_v;
    isd_status.isd_rs2_addr = issue_pkt_r.instr.fields.rtype.rs2_addr;

    // Form dispatch packet
    dispatch_pkt.v      = issue_pkt_v_r & dispatch_v_i;
    dispatch_pkt.poison = poison_iss_r | npc_mismatch;
    dispatch_pkt.pc     = expected_npc_i;
    dispatch_pkt.instr  = issue_pkt_r.instr;
    dispatch_pkt.rs1    = irf_rs1; // TODO: Add float forwarding
    dispatch_pkt.rs2    = irf_rs2;
    dispatch_pkt.imm    = issue_pkt_r.imm;
    dispatch_pkt.decode = decoded;
  end
assign dispatch_pkt_o = dispatch_pkt;

endmodule

