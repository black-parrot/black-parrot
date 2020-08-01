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
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam wb_pkt_width_lp     = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

  , output [isd_status_width_lp-1:0]   isd_status_o
  , input [vaddr_width_p-1:0]          expected_npc_i
  , input                              poison_iss_i
  , input                              poison_isd_i
  , input                              dispatch_v_i
  , input                              cache_miss_v_i
  , input                              cmt_v_i
  , input                              suppress_iss_i
  , input                              fpu_en_i

  // Fetch interface
  , input [fe_queue_width_lp-1:0]      fe_queue_i
  , input                              fe_queue_v_i
  , output                             fe_queue_yumi_o
  , output                             fe_queue_clr_o
  , output                             fe_queue_roll_o
  , output                             fe_queue_deq_o

  // Dispatch interface
  , output [dispatch_pkt_width_lp-1:0] dispatch_pkt_o

  , input [wb_pkt_width_lp-1:0]        iwb_pkt_i
  , input [wb_pkt_width_lp-1:0]        fwb_pkt_i
  );

  wire unused = &{clk_i, reset_i};

  // Declare parameterizable structures
  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // Cast input and output ports
  bp_be_isd_status_s  isd_status;
  bp_fe_queue_s     fe_queue_cast_i;
  bp_be_issue_pkt_s issue_pkt;
  rv64_instr_s      instr;
  bp_be_wb_pkt_s    iwb_pkt, fwb_pkt;

  assign isd_status_o    = isd_status;
  assign fe_queue_cast_i = fe_queue_i;
  assign instr           = fe_queue_cast_i.msg.fetch.instr;
  assign iwb_pkt         = iwb_pkt_i;
  assign fwb_pkt         = fwb_pkt_i;

  wire issue_v = fe_queue_yumi_o;

  bp_be_issue_pkt_s issue_pkt_r;
  logic issue_pkt_v_r, poison_iss_r;
  bsg_dff_reset_en
   #(.width_p(1+$bits(bp_be_issue_pkt_s)))
   issue_pkt_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i | cache_miss_v_i)
     ,.en_i(issue_v | dispatch_v_i)

     ,.data_i({issue_v, issue_pkt})
     ,.data_o({issue_pkt_v_r, issue_pkt_r})
     );

  bsg_dff_reset_en
   #(.width_p(1))
   issue_status_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(issue_v | dispatch_v_i | poison_iss_i | poison_isd_i)

     ,.data_i(poison_iss_i | poison_isd_i)
     ,.data_o(poison_iss_r)
     );

  always_comb
    begin
      if (fe_queue_cast_i.msg_type == e_fe_fetch)
        begin
          // Populate the issue packet with a valid pc/instruction pair.
          issue_pkt = '0;

          issue_pkt.fe_exception_not_instr = 1'b0;

          issue_pkt.pc                     = fe_queue_cast_i.msg.fetch.pc;
          issue_pkt.branch_metadata_fwd    = fe_queue_cast_i.msg.fetch.branch_metadata_fwd;
          issue_pkt.instr                  = fe_queue_cast_i.msg.fetch.instr;

          // Pre-decode
          casez (instr.t.rtype.opcode)
            `RV64_LOAD_OP, `RV64_STORE_OP, `RV64_AMO_OP: issue_pkt.mem_v = 1'b1;
          endcase

          casez (instr.t.rtype.opcode)
            `RV64_SYSTEM_OP: issue_pkt.csr_v = 1'b1;
          endcase

          casez (instr)
            `RV64_FENCE     : issue_pkt.fence_v  = 1'b1;
            `RV64_FENCE_I   : issue_pkt.fence_v  = 1'b1;
            `RV64_SFENCE_VMA: issue_pkt.fence_v  = 1'b1;
          endcase

          casez (instr)
            `RV64_DIV, `RV64_DIVU, `RV64_DIVW, `RV64_DIVUW
            ,`RV64_REM, `RV64_REMU, `RV64_REMW, `RV64_REMUW
            ,`RV64_FDIV_S, `RV64_FDIV_D, `RV64_FSQRT_S, `RV64_FSQRT_D:
              issue_pkt.long_v = 1'b1;
          endcase

          // Decide whether to read from integer regfile (saves power)
          casez (instr.t.rtype.opcode)
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

        casez (instr.t.rtype.opcode)
          `RV64_FLOAD_OP:
            begin
              issue_pkt.irs1_v = 1'b1;
            end
          `RV64_FSTORE_OP:
            begin
              issue_pkt.irs1_v = 1'b1;
              issue_pkt.frs2_v = 1'b1;
            end
          `RV64_FP_OP:
            casez (instr)
              `RV64_FCVT_WS, `RV64_FCVT_WUS, `RV64_FCVT_LS, `RV64_FCVT_LUS
              ,`RV64_FCVT_WD, `RV64_FCVT_WUD, `RV64_FCVT_LD, `RV64_FCVT_LUD:
                begin
                  issue_pkt.frs1_v = 1'b1;
                end
              `RV64_FCVT_SW, `RV64_FCVT_SWU, `RV64_FCVT_SL, `RV64_FCVT_SLU
              ,`RV64_FCVT_DW, `RV64_FCVT_DWU, `RV64_FCVT_DL, `RV64_FCVT_DLU:
                begin
                  issue_pkt.irs1_v = 1'b1;
                end
              `RV64_FCVT_SD, `RV64_FCVT_DS:
                begin
                  issue_pkt.frs1_v = 1'b1;
                end
              `RV64_FMV_WX, `RV64_FMV_DX:
                begin
                  issue_pkt.irs1_v = 1'b1;
                end
              `RV64_FMV_XW, `RV64_FMV_XD:
                begin
                  issue_pkt.frs1_v = 1'b1;
                end
              `RV64_FCLASS_S, `RV64_FCLASS_D:
                begin
                  issue_pkt.frs1_v = 1'b1;
                end
              default:
                begin
                  issue_pkt.frs1_v = 1'b1;
                  issue_pkt.frs2_v = 1'b1;
                end
            endcase
          `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
            begin
              issue_pkt.frs1_v = 1'b1;
              issue_pkt.frs2_v = 1'b1;
              issue_pkt.frs3_v = 1'b1;
            end
          default: begin end
        endcase
        end
      else
        // FE exceptions only have an exception address, code and flag.
        begin
          issue_pkt = '0;

          issue_pkt.fe_exception_not_instr = 1'b1;
          issue_pkt.fe_exception_code      = fe_queue_cast_i.msg.exception.exception_code;
          issue_pkt.pc                     = fe_queue_cast_i.msg.exception.vaddr;
        end
    end

  // Interface handshakes
  assign fe_queue_yumi_o = ~suppress_iss_i & fe_queue_v_i & (dispatch_v_i | ~issue_pkt_v_r);

  // Queue control signals
  assign fe_queue_clr_o  = suppress_iss_i;
  assign fe_queue_roll_o = cache_miss_v_i;
  assign fe_queue_deq_o  = ~cache_miss_v_i & cmt_v_i;

  logic [dword_width_p-1:0] irf_rs1, irf_rs2;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(2), .data_width_p(dword_width_p))
   int_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(iwb_pkt.rd_w_v)
     ,.rd_addr_i(iwb_pkt.rd_addr)
     ,.rd_data_i(iwb_pkt.rd_data[0+:dword_width_p])

     ,.rs_r_v_i({issue_v & issue_pkt.irs2_v
                 ,issue_v & issue_pkt.irs1_v
                 })
     ,.rs_addr_i({issue_pkt.instr.t.rtype.rs2_addr
                  ,issue_pkt.instr.t.rtype.rs1_addr
                  })
     ,.rs_data_o({irf_rs2, irf_rs1})
     );

  logic [dpath_width_p-1:0] frf_rs1, frf_rs2, frf_rs3;
  bp_be_regfile
  #(.bp_params_p(bp_params_p), .read_ports_p(3), .data_width_p(dpath_width_p))
   fp_regfile
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.rd_w_v_i(fwb_pkt.rd_w_v)
     ,.rd_addr_i(fwb_pkt.rd_addr)
     ,.rd_data_i(fwb_pkt.rd_data)

     ,.rs_r_v_i({issue_v & issue_pkt.frs3_v
                 ,issue_v & issue_pkt.frs2_v
                 ,issue_v & issue_pkt.frs1_v
                 })
     ,.rs_addr_i({issue_pkt.instr.t.fmatype.rs3_addr
                  ,issue_pkt.instr.t.fmatype.rs2_addr
                  ,issue_pkt.instr.t.fmatype.rs1_addr
                  })
     ,.rs_data_o({frf_rs3, frf_rs2, frf_rs1})
     );

  // Decode the dispatched instruction
  bp_be_decode_s            decoded;
  logic [dword_width_p-1:0] decoded_imm_lo;
  bp_be_instr_decoder
   #(.bp_params_p(bp_params_p))
   instr_decoder
     (.fe_exc_not_instr_i(issue_pkt_r.fe_exception_not_instr)
     ,.fe_exc_i(issue_pkt_r.fe_exception_code)
     ,.instr_i(issue_pkt_r.instr)

     ,.decode_o(decoded)
     ,.imm_o(decoded_imm_lo)

     ,.fpu_en_i(fpu_en_i)
     );

  bp_be_dispatch_pkt_s dispatch_pkt;
  always_comb
    begin
      // Calculator status ISD stage
      isd_status.isd_v        = (issue_pkt_v_r & dispatch_v_i)
                                & ~(poison_iss_r | poison_iss_i);
      isd_status.isd_pc       = issue_pkt_r.pc;
      isd_status.isd_branch_metadata_fwd = issue_pkt_r.branch_metadata_fwd;
      isd_status.isd_fence_v  = issue_pkt_v_r & issue_pkt_r.fence_v;
      isd_status.isd_csr_v    = issue_pkt_v_r & issue_pkt_r.csr_v;
      isd_status.isd_mem_v    = issue_pkt_v_r & issue_pkt_r.mem_v;
      isd_status.isd_long_v   = issue_pkt_v_r & issue_pkt_r.long_v;
      isd_status.isd_irs1_v   = issue_pkt_v_r & issue_pkt_r.irs1_v;
      isd_status.isd_frs1_v   = issue_pkt_v_r & issue_pkt_r.frs1_v;
      isd_status.isd_rs1_addr = issue_pkt_r.instr.t.rtype.rs1_addr;
      isd_status.isd_irs2_v   = issue_pkt_v_r & issue_pkt_r.irs2_v;
      isd_status.isd_frs2_v   = issue_pkt_v_r & issue_pkt_r.frs2_v;
      isd_status.isd_rs2_addr = issue_pkt_r.instr.t.rtype.rs2_addr;
      isd_status.isd_frs3_v   = issue_pkt_v_r & issue_pkt_r.frs3_v;
      isd_status.isd_rs3_addr = issue_pkt_r.instr.t.fmatype.rs3_addr;

      // Form dispatch packet
      dispatch_pkt.v      = issue_pkt_v_r & dispatch_v_i;
      dispatch_pkt.poison = (poison_iss_r | poison_isd_i | ~dispatch_pkt.v);
      dispatch_pkt.pc     = expected_npc_i;
      dispatch_pkt.instr  = issue_pkt_r.instr;
      dispatch_pkt.rs1_fp_v = issue_pkt_r.frs1_v;
      dispatch_pkt.rs1    = issue_pkt_r.frs1_v ? frf_rs1 : irf_rs1;
      dispatch_pkt.rs2_fp_v = issue_pkt_r.frs2_v;
      dispatch_pkt.rs2    = issue_pkt_r.frs2_v ? frf_rs2 : irf_rs2;
      dispatch_pkt.rs3_fp_v = issue_pkt_r.frs3_v;
      dispatch_pkt.imm    = issue_pkt_r.frs3_v ? frf_rs3 : decoded_imm_lo;
      dispatch_pkt.decode = decoded;
    end
  assign dispatch_pkt_o = dispatch_pkt;

endmodule

