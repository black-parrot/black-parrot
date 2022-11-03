
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_issue_queue
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   , localparam preissue_pkt_width_lp = `bp_be_preissue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   )
  (input                                       clk_i
   , input                                     reset_i

   , input                                     clr_v_i
   , input                                     deq_v_i
   , input                                     roll_v_i
   , input                                     inject_v_i
   , input                                     read_v_i

   , input [fe_queue_width_lp-1:0]             fe_queue_i
   , input                                     fe_queue_v_i
   , output logic                              fe_queue_ready_and_o

   , output logic [preissue_pkt_width_lp-1:0]  preissue_pkt_o
   , output logic [issue_pkt_width_lp-1:0]     issue_pkt_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `bp_cast_i(bp_fe_queue_s, fe_queue);
  `bp_cast_o(bp_be_preissue_pkt_s, preissue_pkt);
  `bp_cast_o(bp_be_issue_pkt_s, issue_pkt);

  localparam ptr_width_lp = `BSG_SAFE_CLOG2(fe_queue_fifo_els_p);

  // One read pointer, one write pointer, one checkpoint pointer
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] wptr_n, rptr_n, cptr_n;
  logic [ptr_width_lp:0] wptr_r, rptr_r, cptr_r;

  // Used to catch up on roll and clear
  logic [ptr_width_lp:0] wptr_jmp, rptr_jmp;
  logic [1:0] cptr_jmp;

  // Operations
  wire enq    = fe_queue_ready_and_o & fe_queue_v_i;
  wire deq    = deq_v_i;
  wire clr    = clr_v_i;
  wire roll   = roll_v_i;
  wire read   = read_v_i;
  wire inject = inject_v_i;

  assign rptr_jmp = roll ? (cptr_r - rptr_r + deq)  : read;
  assign wptr_jmp = clr  ? (rptr_r - wptr_r + read) : enq;
  assign cptr_jmp = deq;

  wire empty   = (rptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
                 & (rptr_r[ptr_width_lp] == wptr_r[ptr_width_lp]);
  wire empty_n = (rptr_n[0+:ptr_width_lp] == wptr_n[0+:ptr_width_lp])
                 & (rptr_n[ptr_width_lp] == wptr_n[ptr_width_lp]);
  wire full    = (cptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
                 & (cptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);
  wire full_n  = (cptr_n[0+:ptr_width_lp] == wptr_n[0+:ptr_width_lp])
                 & (cptr_n[ptr_width_lp] != wptr_n[ptr_width_lp]);

  rv64_instr_fmatype_s preissue_instr;
  assign preissue_instr = fe_queue_cast_i.instr;

  rv64_instr_fmatype_s issue_instr;
  assign issue_instr = issue_pkt_cast_o.instr;

  bsg_circular_ptr
   #(.slots_p(2*fe_queue_fifo_els_p), .max_add_p(2))
   cptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(cptr_jmp)
     ,.o(cptr_r)
     ,.n_o(cptr_n)
     );

  bsg_circular_ptr
   #(.slots_p(2*fe_queue_fifo_els_p),.max_add_p(2*fe_queue_fifo_els_p-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o(wptr_n)
     );

  bsg_circular_ptr
   #(.slots_p(2*fe_queue_fifo_els_p), .max_add_p(2*fe_queue_fifo_els_p-1))
   rptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(rptr_jmp)
     ,.o(rptr_r)
     ,.n_o(rptr_n)
     );

  bp_fe_queue_s fe_queue_lo;
  bsg_mem_1r1w
   #(.width_p(fe_queue_width_lp), .els_p(fe_queue_fifo_els_p))
   queue_fifo_mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(enq)
     ,.w_addr_i(wptr_r[0+:ptr_width_lp])
     ,.w_data_i(fe_queue_cast_i)
     ,.r_v_i(read & ~empty)
     ,.r_addr_i(rptr_r[0+:ptr_width_lp])
     ,.r_data_o(fe_queue_lo)
     );
  assign fe_queue_ready_and_o = ~full;

  bp_be_preissue_pkt_s preissue_pkt_li, preissue_pkt_lo;
  wire issue_v = (read_v_i & ~empty_n) | roll | (enq & empty);
  wire bypass_reg = (wptr_r == rptr_n);
  bsg_mem_1r1w
   #(.width_p($bits(bp_be_preissue_pkt_s)), .els_p(fe_queue_fifo_els_p), .read_write_same_addr_p(1))
   reg_fifo_mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(enq)
     ,.w_addr_i(wptr_r[0+:ptr_width_lp])
     ,.w_data_i(preissue_pkt_li)
     ,.r_v_i(issue_v)
     ,.r_addr_i(rptr_n[0+:ptr_width_lp])
     ,.r_data_o(preissue_pkt_lo)
     );
  assign preissue_pkt_cast_o = bypass_reg ? preissue_pkt_li : issue_v ? preissue_pkt_lo : '0;

  bp_be_preissue_pkt_s preissue_pkt_r;
  bsg_dff_reset_en
   #(.width_p($bits(bp_be_preissue_pkt_s)))
   issue_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(issue_v)
     ,.data_i(preissue_pkt_o)
     ,.data_o(preissue_pkt_r)
     );

  // Pre-decode
  always_comb
    begin
      preissue_pkt_li = '0;
      preissue_pkt_li.csr_v = preissue_instr.opcode inside {`RV64_SYSTEM_OP};
      preissue_pkt_li.mem_v = preissue_instr.opcode inside {`RV64_FLOAD_OP, `RV64_FSTORE_OP
                                                            ,`RV64_LOAD_OP, `RV64_STORE_OP
                                                            ,`RV64_AMO_OP, `RV64_SYSTEM_OP
                                                            };
      preissue_pkt_li.fence_v = preissue_instr inside {`RV64_FENCE, `RV64_FENCE_I, `RV64_SFENCE_VMA};
      preissue_pkt_li.long_v = preissue_instr inside {`RV64_DIV, `RV64_DIVU, `RV64_DIVW, `RV64_DIVUW
                                                      ,`RV64_REM, `RV64_REMU, `RV64_REMW, `RV64_REMUW
                                                      ,`RV64_FDIV_S, `RV64_FDIV_D, `RV64_FSQRT_S, `RV64_FSQRT_D
                                                      ,`RV64_MULH, `RV64_MULHU, `RV64_MULHSU
                                                      };

      // Decide whether to read from integer regfile (saves power)
      casez (preissue_instr.opcode)
        `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_SYSTEM_OP :
          begin
            preissue_pkt_li.irs1_v = 1'b1;
          end
        `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP, `RV64_AMO_OP:
          begin
            preissue_pkt_li.irs1_v = 1'b1;
            preissue_pkt_li.irs2_v = 1'b1;
          end
        `RV64_FLOAD_OP:
          begin
            preissue_pkt_li.irs1_v = 1'b1;
          end
        `RV64_FSTORE_OP:
          begin
            preissue_pkt_li.irs1_v = 1'b1;
            preissue_pkt_li.frs2_v = 1'b1;
          end
        `RV64_FP_OP:
          casez (preissue_instr)
            `RV64_FCVT_WS, `RV64_FCVT_WUS, `RV64_FCVT_LS, `RV64_FCVT_LUS
            ,`RV64_FCVT_WD, `RV64_FCVT_WUD, `RV64_FCVT_LD, `RV64_FCVT_LUD
            ,`RV64_FCVT_SD, `RV64_FCVT_DS
            ,`RV64_FMV_XW, `RV64_FMV_XD
            ,`RV64_FCLASS_S, `RV64_FCLASS_D:
              begin
                preissue_pkt_li.frs1_v = 1'b1;
              end
            `RV64_FCVT_SW, `RV64_FCVT_SWU, `RV64_FCVT_SL, `RV64_FCVT_SLU
            ,`RV64_FCVT_DW, `RV64_FCVT_DWU, `RV64_FCVT_DL, `RV64_FCVT_DLU
            ,`RV64_FMV_WX, `RV64_FMV_DX:
              begin
                preissue_pkt_li.irs1_v = 1'b1;
              end
            default:
              begin
                preissue_pkt_li.frs1_v = 1'b1;
                preissue_pkt_li.frs2_v = 1'b1;
              end
          endcase
        `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
          begin
            preissue_pkt_li.frs1_v = 1'b1;
            preissue_pkt_li.frs2_v = 1'b1;
            preissue_pkt_li.frs3_v = 1'b1;
          end
        default: begin end
      endcase

      preissue_pkt_li.rs1_addr = preissue_instr.rs1_addr;
      preissue_pkt_li.rs2_addr = preissue_instr.rs2_addr;
      preissue_pkt_li.rs3_addr = preissue_instr.rs3_addr;
    end

  wire issue_pkt_v = ~roll & ~empty & ~clr & ~inject;
  always_comb
    begin
      issue_pkt_cast_o = '0;

      issue_pkt_cast_o.v                    = issue_pkt_v;
      issue_pkt_cast_o.instr_v              = issue_pkt_v & (fe_queue_lo.msg_type == e_instr_fetch);
      issue_pkt_cast_o.itlb_miss_v          = issue_pkt_v & (fe_queue_lo.msg_type == e_itlb_miss);
      issue_pkt_cast_o.instr_access_fault_v = issue_pkt_v & (fe_queue_lo.msg_type == e_instr_access_fault);
      issue_pkt_cast_o.instr_page_fault_v   = issue_pkt_v & (fe_queue_lo.msg_type == e_instr_page_fault);
      issue_pkt_cast_o.icache_miss_v        = issue_pkt_v & (fe_queue_lo.msg_type == e_icache_miss);

      issue_pkt_cast_o.pc                   = fe_queue_lo.pc;
      issue_pkt_cast_o.instr                = fe_queue_lo.instr;
      issue_pkt_cast_o.branch_metadata_fwd  = fe_queue_lo.branch_metadata_fwd;
      // Needs to be adjusted for 2x compressed vs 1x compressed
      issue_pkt_cast_o.partial_v            = fe_queue_lo.partial;
      issue_pkt_cast_o.csr_v                = issue_pkt_cast_o.instr_v & preissue_pkt_r.csr_v;
      issue_pkt_cast_o.mem_v                = issue_pkt_cast_o.instr_v & preissue_pkt_r.mem_v;
      issue_pkt_cast_o.fence_v              = issue_pkt_cast_o.instr_v & preissue_pkt_r.fence_v;
      issue_pkt_cast_o.long_v               = issue_pkt_cast_o.instr_v & preissue_pkt_r.long_v;
      issue_pkt_cast_o.irs1_v               = issue_pkt_cast_o.instr_v & preissue_pkt_r.irs1_v;
      issue_pkt_cast_o.irs2_v               = issue_pkt_cast_o.instr_v & preissue_pkt_r.irs2_v;
      issue_pkt_cast_o.frs1_v               = issue_pkt_cast_o.instr_v & preissue_pkt_r.frs1_v;
      issue_pkt_cast_o.frs2_v               = issue_pkt_cast_o.instr_v & preissue_pkt_r.frs2_v;
      issue_pkt_cast_o.frs3_v               = issue_pkt_cast_o.instr_v & preissue_pkt_r.frs3_v;

      // Decide whether to write to regfile (used for stalls)
      unique casez (issue_instr.opcode)
        `RV64_LUI_OP, `RV64_AUIPC_OP, `RV64_JAL_OP, `RV64_JALR_OP
        ,`RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_OP, `RV64_SYSTEM_OP
        ,`RV64_OP_IMM_32_OP, `RV64_OP_32_OP, `RV64_AMO_OP:
          begin
            issue_pkt_cast_o.iwb_v = (issue_instr.rd_addr != '0);
          end

        `RV64_FLOAD_OP, `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
          begin
            issue_pkt_cast_o.fwb_v = 1'b1;
          end

        `RV64_FP_OP:
          unique casez (issue_instr)
            `RV64_FCVT_WS, `RV64_FCVT_LS, `RV64_FCVT_WUS, `RV64_FCVT_LUS,
            `RV64_FCVT_WD, `RV64_FCVT_LD, `RV64_FCVT_WUD, `RV64_FCVT_LUD,
            `RV64_FMV_XW, `RV64_FMV_XD, `RV64_FLT_S, `RV64_FLT_D,
            `RV64_FLE_S, `RV64_FLE_D, `RV64_FCLASS_S, `RV64_FCLASS_D:
              begin
                issue_pkt_cast_o.iwb_v = (issue_instr.rd_addr != '0);
              end
            default: issue_pkt_cast_o.fwb_v = 1'b1;
          endcase
        default: begin end
      endcase
    end

endmodule

