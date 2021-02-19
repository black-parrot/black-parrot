
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_issue_queue
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_multicore_1_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   , localparam issue_pkt_width_lp = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam ptr_width_lp = `BSG_SAFE_CLOG2(fe_queue_fifo_els_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input                                  clr_v_i
   , input                                  deq_v_i
   , input                                  roll_v_i

   , input [fe_queue_width_lp-1:0]          fe_queue_i
   , input                                  fe_queue_v_i
   , output logic                           fe_queue_ready_o

   , output logic [fe_queue_width_lp-1:0]   fe_queue_o
   , output logic                           fe_queue_v_o
   , input                                  fe_queue_yumi_i

   , output logic [issue_pkt_width_lp-1:0]  preissue_pkt_o
   , output logic [issue_pkt_width_lp-1:0]  issue_pkt_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `bp_cast_i(bp_fe_queue_s, fe_queue);
  `bp_cast_o(bp_fe_queue_s, fe_queue);

  // One read pointer, one write pointer, one checkpoint pointer
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] wptr_n, rptr_n, cptr_n;
  logic [ptr_width_lp:0] wptr_r, rptr_r, cptr_r;

  // Used to catch up on roll and clear
  logic [ptr_width_lp:0] wptr_jmp, rptr_jmp;
  logic cptr_jmp;

  // Operations
  wire enq  = fe_queue_ready_o & fe_queue_v_i;
  wire deq  = deq_v_i;
  wire read = fe_queue_yumi_i;
  wire clr  = clr_v_i;
  wire roll = roll_v_i;

  assign rptr_jmp = roll
                    ? (cptr_r - rptr_r + (ptr_width_lp+1)'(deq))
                    : read
                       ? ((ptr_width_lp+1)'(1))
                       : ((ptr_width_lp+1)'(0));
  assign wptr_jmp = clr
                    ? (rptr_r - wptr_r + (ptr_width_lp+1)'(read))
                    : enq
                       ? ((ptr_width_lp+1)'(1))
                       : ((ptr_width_lp+1)'(0));
  assign cptr_jmp = deq_v_i;

  wire empty = (rptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
               & (rptr_r[ptr_width_lp] == wptr_r[ptr_width_lp]);
  wire empty_n = (rptr_n[0+:ptr_width_lp] == wptr_n[0+:ptr_width_lp])
                 & (rptr_n[ptr_width_lp] == wptr_n[ptr_width_lp]);
  wire full  = (cptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
               & (cptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);
  wire full_n = (cptr_n[0+:ptr_width_lp] == wptr_n[0+:ptr_width_lp])
                & (cptr_n[ptr_width_lp] != wptr_n[ptr_width_lp]);

  bsg_circular_ptr
   #(.slots_p(2*fe_queue_fifo_els_p), .max_add_p(1))
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
    ,.r_data_o(fe_queue_cast_o)
    );
  assign fe_queue_v_o     = ~roll & ~empty;
  assign fe_queue_ready_o = ~clr & ~full;

  rv64_instr_fmatype_s instr;
  assign instr = fe_queue_cast_i.msg.fetch.instr;

  bp_be_issue_pkt_s issue_pkt_li, issue_pkt_lo;
  wire issue_v = (fe_queue_yumi_i & ~empty_n) | roll_v_i | (fe_queue_v_i & empty);
  wire bypass_reg = (wptr_r == rptr_n);
  bsg_mem_1r1w
  #(.width_p($bits(bp_be_issue_pkt_s)), .els_p(fe_queue_fifo_els_p), .read_write_same_addr_p(1))
  reg_fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i(issue_pkt_li)
    ,.r_v_i(issue_v)
    ,.r_addr_i(rptr_n[0+:ptr_width_lp])
    ,.r_data_o(issue_pkt_lo)
    );
  assign preissue_pkt_o = bypass_reg ? issue_pkt_li : issue_v ? issue_pkt_lo : '0;

  bsg_dff_reset_en
   #(.width_p($bits(bp_be_issue_pkt_s)))
   issue_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(issue_v)
     ,.data_i(preissue_pkt_o)
     ,.data_o(issue_pkt_o)
     );

  always_comb
    begin
      issue_pkt_li = '0;

      // Pre-decode
      issue_pkt_li.csr_w_v = (instr inside {`RV64_CSRRW, `RV64_CSRRWI})
        || (instr.opcode inside {`RV64_SYSTEM_OP} && (instr.rs1_addr != '0));
      issue_pkt_li.mem_v = instr.opcode inside {`RV64_FLOAD_OP, `RV64_FSTORE_OP
                                                ,`RV64_LOAD_OP, `RV64_STORE_OP
                                                ,`RV64_AMO_OP, `RV64_SYSTEM_OP
                                                };
      issue_pkt_li.fence_v = instr inside {`RV64_FENCE, `RV64_FENCE_I, `RV64_SFENCE_VMA};
      issue_pkt_li.long_v = instr inside {`RV64_DIV, `RV64_DIVU, `RV64_DIVW, `RV64_DIVUW
                                          ,`RV64_REM, `RV64_REMU, `RV64_REMW, `RV64_REMUW
                                          ,`RV64_FDIV_S, `RV64_FDIV_D, `RV64_FSQRT_S, `RV64_FSQRT_D
                                          };

      // Decide whether to read from integer regfile (saves power)
      casez (instr.opcode)
        `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_SYSTEM_OP :
          begin
            issue_pkt_li.irs1_v = '1;
          end
        `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP, `RV64_AMO_OP:
          begin
            issue_pkt_li.irs1_v = '1;
            issue_pkt_li.irs2_v = '1;
          end
        `RV64_FLOAD_OP:
          begin
            issue_pkt_li.irs1_v = 1'b1;
          end
        `RV64_FSTORE_OP:
          begin
            issue_pkt_li.irs1_v = 1'b1;
            issue_pkt_li.frs2_v = 1'b1;
          end
        `RV64_FP_OP:
          casez (instr)
            `RV64_FCVT_WS, `RV64_FCVT_WUS, `RV64_FCVT_LS, `RV64_FCVT_LUS
            ,`RV64_FCVT_WD, `RV64_FCVT_WUD, `RV64_FCVT_LD, `RV64_FCVT_LUD
            ,`RV64_FCVT_SD, `RV64_FCVT_DS
            ,`RV64_FMV_XW, `RV64_FMV_XD
            ,`RV64_FCLASS_S, `RV64_FCLASS_D:
              begin
                issue_pkt_li.frs1_v = 1'b1;
              end
            `RV64_FCVT_SW, `RV64_FCVT_SWU, `RV64_FCVT_SL, `RV64_FCVT_SLU
            ,`RV64_FCVT_DW, `RV64_FCVT_DWU, `RV64_FCVT_DL, `RV64_FCVT_DLU
            ,`RV64_FMV_WX, `RV64_FMV_DX:
              begin
                issue_pkt_li.irs1_v = 1'b1;
              end
            default:
              begin
                issue_pkt_li.frs1_v = 1'b1;
                issue_pkt_li.frs2_v = 1'b1;
              end
          endcase
        `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
          begin
            issue_pkt_li.frs1_v = 1'b1;
            issue_pkt_li.frs2_v = 1'b1;
            issue_pkt_li.frs3_v = 1'b1;
          end
        default: begin end
      endcase

      issue_pkt_li.rs1_addr = instr.rs1_addr;
      issue_pkt_li.rs2_addr = instr.rs2_addr;
      issue_pkt_li.rs3_addr = instr.rs3_addr;
    end
endmodule

