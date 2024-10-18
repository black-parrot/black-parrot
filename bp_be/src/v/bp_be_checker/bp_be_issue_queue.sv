
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_issue_queue
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)

   , localparam entry_cinstr_gp = 2**fetch_sel_p
   , localparam op_ptr_width_lp = `BSG_WIDTH(entry_cinstr_gp)
   )
  (input                                       clk_i
   , input                                     reset_i

   , input                                     en_i
   , input                                     clr_i
   , input                                     roll_i
   , input                                     read_i
   , input [op_ptr_width_lp-1:0]               read_cnt_i
   , input [op_ptr_width_lp-1:0]               read_size_i
   , input                                     cmt_i
   , input [op_ptr_width_lp-1:0]               cmt_cnt_i
   , input [op_ptr_width_lp-1:0]               cmt_size_i

   , input [fe_queue_width_lp-1:0]             fe_queue_i
   , input                                     fe_queue_v_i
   , output logic                              fe_queue_ready_and_o

   , input [decode_info_width_lp-1:0]          decode_info_i
   , output logic [preissue_pkt_width_lp-1:0]  preissue_pkt_o
   , output logic [issue_pkt_width_lp-1:0]     issue_pkt_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);
  `bp_cast_i(bp_fe_queue_s, fe_queue);
  `bp_cast_o(bp_be_preissue_pkt_s, preissue_pkt);
  `bp_cast_o(bp_be_issue_pkt_s, issue_pkt);

  localparam entry_ptr_width_lp = fetch_sel_p;
  localparam mem_ptr_width_lp = `BSG_SAFE_CLOG2(fe_queue_fifo_els_p);
  localparam ptr_width_lp = mem_ptr_width_lp+entry_ptr_width_lp+1;

  localparam ptr_wrap_bit_lp = ptr_width_lp-1;
  localparam ptr_base_bit_lp = entry_ptr_width_lp;
  localparam ptr_slots_lp = 1 << ptr_width_lp;

  // One read pointer, one write pointer, one checkpoint pointer
  struct packed
  {
    logic                          wrap;
    logic [mem_ptr_width_lp-1:0]   mem;
    logic [entry_ptr_width_lp-1:0] entry;
  } wptr_n, wptr_r, rptr_n, rptr_r, cptr_n, cptr_r;

  // Status
  wire ack     = (fe_queue_ready_and_o & fe_queue_v_i);
  wire empty   = (rptr_r == wptr_r);
  wire empty_n = (rptr_n == wptr_n);
  wire full    = (cptr_r.mem == wptr_r.mem) && (cptr_r.wrap != wptr_r.wrap);
  wire full_n  = (cptr_n.mem == wptr_n.mem) && (cptr_n.wrap != wptr_n.wrap);

  // Operations
  logic [op_ptr_width_lp-1:0] enq, deq, read;
  wire enq_catchup  = 1'b1; // Enqueue always allocates a new queue entry
  wire read_catchup = (rptr_r.entry + read_size_i >= read_cnt_i);
  wire deq_catchup  = (cptr_r.entry + cmt_size_i  >= cmt_cnt_i );

  assign enq  = ack    ? enq_catchup  ? (entry_cinstr_gp - wptr_r.entry) : '0          : '0;
  assign read = read_i ? read_catchup ? (entry_cinstr_gp - rptr_r.entry) : read_size_i : '0;
  assign deq  = cmt_i  ? deq_catchup  ? (entry_cinstr_gp - cptr_r.entry) : cmt_size_i  : '0;

  // Calculate next pointer jump
  logic [ptr_width_lp-1:0] wptr_jmp, rptr_jmp, cptr_jmp;
  assign rptr_jmp = clr_i ? -rptr_r : roll_i ? (cptr_r - rptr_r + deq) : read;
  assign wptr_jmp = clr_i ? -wptr_r : enq;
  assign cptr_jmp = clr_i ? -cptr_r : deq;

  bsg_circular_ptr
   #(.slots_p(ptr_slots_lp), .max_add_p(ptr_slots_lp-1))
   cptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(cptr_jmp)
     ,.o(cptr_r)
     ,.n_o(cptr_n)
     );

  bsg_circular_ptr
   #(.slots_p(ptr_slots_lp), .max_add_p(ptr_slots_lp-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o(wptr_n)
     );

  bsg_circular_ptr
   #(.slots_p(ptr_slots_lp), .max_add_p(ptr_slots_lp-1))
   rptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(rptr_jmp)
     ,.o(rptr_r)
     ,.n_o(rptr_n)
     );

  logic [fetch_width_p-1:0] queue_instr, queue_instr_n;
  assign queue_instr = fe_queue_cast_i.instr;
  wire preissue_v = (|read & ~empty_n) | roll_i | (|enq & empty);
  wire bypass_preissue = (wptr_r == rptr_n);
  bsg_mem_1r1w
   #(.width_p(fetch_width_p), .els_p(fe_queue_fifo_els_p))
   preissue_fifo_mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(|enq)
     ,.w_addr_i(wptr_r.mem)
     ,.w_data_i(queue_instr)
     ,.r_v_i(~bypass_preissue)
     ,.r_addr_i(rptr_n.mem)
     ,.r_data_o(queue_instr_n)
     );

  wire [entry_ptr_width_lp-1:0] preissue_entry_sel = bypass_preissue ? wptr_r.entry : rptr_n.entry;
  logic [fetch_cinstr_p:0][cinstr_width_gp-1:0] queue_instr_raw;
  assign queue_instr_raw[0+:fetch_cinstr_p] = bypass_preissue ? queue_instr : queue_instr_n;
  assign queue_instr_raw[fetch_cinstr_p] = '0;

  rv64_instr_s [fetch_cinstr_p-1:0] preissue_instr;
  logic [fetch_cinstr_p-1:0][fetch_ptr_p-1:0] preissue_size;
  for (genvar i = 0; i < fetch_cinstr_p; i++)
    begin : e
      logic [instr_width_gp-1:0] instr;
      wire [cinstr_width_gp-1:0] cinstr = queue_instr_raw[i];
      bp_be_expander
       expander
        (.cinstr_i(cinstr)
         ,.instr_o(instr)
         );
      assign preissue_size[i] = ~&cinstr[0+:2] ? 2'b01 : 2'b10;
      assign preissue_instr[i] = (preissue_size[i] == 2'b01) ? instr : queue_instr_raw[i+:2];
    end

  // Pre-decode
  always_comb
    begin
      preissue_pkt_cast_o = '0;
      preissue_pkt_cast_o.size = preissue_size[preissue_entry_sel];
      preissue_pkt_cast_o.instr = preissue_instr[preissue_entry_sel];

      // Decide whether to read from regfile
      casez (preissue_instr[preissue_entry_sel].t.fmatype.opcode)
        `RV64_JALR_OP, `RV64_LOAD_OP, `RV64_OP_IMM_OP, `RV64_OP_IMM_32_OP, `RV64_SYSTEM_OP :
          begin
            preissue_pkt_cast_o.irs1_v = preissue_v;
          end
        `RV64_BRANCH_OP, `RV64_STORE_OP, `RV64_OP_OP, `RV64_OP_32_OP, `RV64_AMO_OP:
          begin
            preissue_pkt_cast_o.irs1_v = preissue_v;
            preissue_pkt_cast_o.irs2_v = preissue_v;
          end
        `RV64_MISC_MEM_OP:
          casez (preissue_pkt_cast_o.instr)
            `RV64_CBO_ZERO
            ,`RV64_CBO_CLEAN
            ,`RV64_CBO_INVAL
            ,`RV64_CBO_FLUSH:
               begin
                 preissue_pkt_cast_o.irs1_v = preissue_v;
                 preissue_pkt_cast_o.irs2_v = preissue_v;
               end
          endcase
        `RV64_FLOAD_OP:
          begin
            preissue_pkt_cast_o.irs1_v = preissue_v;
          end
        `RV64_FSTORE_OP:
          begin
            preissue_pkt_cast_o.irs1_v = preissue_v;
            preissue_pkt_cast_o.frs2_v = preissue_v;
          end
        `RV64_FP_OP:
          casez (preissue_pkt_cast_o.instr)
            `RV64_FCVT_WS, `RV64_FCVT_WUS, `RV64_FCVT_LS, `RV64_FCVT_LUS
            ,`RV64_FCVT_WD, `RV64_FCVT_WUD, `RV64_FCVT_LD, `RV64_FCVT_LUD
            ,`RV64_FCVT_SD, `RV64_FCVT_DS
            ,`RV64_FMV_XW, `RV64_FMV_XD
            ,`RV64_FCLASS_S, `RV64_FCLASS_D:
              begin
                preissue_pkt_cast_o.frs1_v = preissue_v;
              end
            `RV64_FCVT_SW, `RV64_FCVT_SWU, `RV64_FCVT_SL, `RV64_FCVT_SLU
            ,`RV64_FCVT_DW, `RV64_FCVT_DWU, `RV64_FCVT_DL, `RV64_FCVT_DLU
            ,`RV64_FMV_WX, `RV64_FMV_DX:
              begin
                preissue_pkt_cast_o.irs1_v = preissue_v;
              end
            default:
              begin
                preissue_pkt_cast_o.frs1_v = preissue_v;
                preissue_pkt_cast_o.frs2_v = preissue_v;
              end
          endcase
        `RV64_FMADD_OP, `RV64_FMSUB_OP, `RV64_FNMSUB_OP, `RV64_FNMADD_OP:
          begin
            preissue_pkt_cast_o.frs1_v = preissue_v;
            preissue_pkt_cast_o.frs2_v = preissue_v;
            preissue_pkt_cast_o.frs3_v = preissue_v;
          end
        default: begin end
      endcase
    end

  bp_be_preissue_pkt_s preissue_pkt_r;
  bsg_dff_reset_en
   #(.width_p($bits(bp_be_preissue_pkt_s)))
   issue_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(preissue_v)
     ,.data_i(preissue_pkt_cast_o)
     ,.data_o(preissue_pkt_r)
     );

  bp_fe_queue_s fe_queue_lo;
  wire bypass_issue = (wptr_r.mem == rptr_r.mem);
  bsg_mem_1r1w
   #(.width_p(fe_queue_width_lp), .els_p(fe_queue_fifo_els_p))
   queue_fifo_mem
    (.w_clk_i(clk_i)
     ,.w_reset_i(reset_i)
     ,.w_v_i(|enq)
     ,.w_addr_i(wptr_r.mem)
     ,.w_data_i(fe_queue_cast_i)
     ,.r_v_i(~bypass_issue)
     ,.r_addr_i(rptr_r.mem)
     ,.r_data_o(fe_queue_lo)
     );
  assign fe_queue_ready_and_o = ~full;

  wire [vaddr_width_p-1:0] issue_pc = fe_queue_lo.pc + (rptr_r.entry << 1'b1);
  wire [instr_width_gp-1:0] issue_instr = preissue_pkt_r.instr;
  wire [fetch_ptr_p-1:0] issue_size = issue_pkt_cast_o.fetch ? preissue_pkt_r.size : entry_ptr_width_lp;
  wire [fetch_ptr_p-1:0] issue_count = fe_queue_lo.count;

  // Decode the dispatched instruction
  bp_be_decode_s decoded_instr_lo;
  logic [dword_width_gp-1:0] decoded_imm_lo;
  logic illegal_instr_lo;
  logic ecall_m_lo, ecall_s_lo, ecall_u_lo;
  logic ebreak_lo, dbreak_lo;
  logic dret_lo, mret_lo, sret_lo;
  logic wfi_lo, sfence_vma_lo, fencei_lo, csrw_lo;
  bp_be_instr_decoder
   #(.bp_params_p(bp_params_p))
   instr_decoder
    (.preissue_pkt_i(preissue_pkt_r)
     ,.decode_info_i(decode_info_i)

     ,.decode_o(decoded_instr_lo)
     ,.imm_o(decoded_imm_lo)

     ,.illegal_instr_o(illegal_instr_lo)
     ,.ecall_m_o(ecall_m_lo)
     ,.ecall_s_o(ecall_s_lo)
     ,.ecall_u_o(ecall_u_lo)
     ,.ebreak_o(ebreak_lo)
     ,.dbreak_o(dbreak_lo)
     ,.dret_o(dret_lo)
     ,.mret_o(mret_lo)
     ,.sret_o(sret_lo)
     ,.wfi_o(wfi_lo)
     ,.sfence_vma_o(sfence_vma_lo)
     ,.fencei_o(fencei_lo)
     ,.csrw_o(csrw_lo)
     );

  always_comb
    begin
      issue_pkt_cast_o = '0;

      issue_pkt_cast_o.v                    = en_i & ~empty;
      issue_pkt_cast_o.fetch                = (fe_queue_lo.msg_type == e_instr_fetch) & !illegal_instr_lo;
      issue_pkt_cast_o.itlb_miss            = (fe_queue_lo.msg_type == e_itlb_miss);
      issue_pkt_cast_o.instr_access_fault   = (fe_queue_lo.msg_type == e_instr_access_fault);
      issue_pkt_cast_o.instr_page_fault     = (fe_queue_lo.msg_type == e_instr_page_fault);
      issue_pkt_cast_o.icache_miss          = (fe_queue_lo.msg_type == e_icache_miss);
      issue_pkt_cast_o.illegal_instr        = (fe_queue_lo.msg_type == e_instr_fetch) &  illegal_instr_lo;
      issue_pkt_cast_o.ecall_m              = ecall_m_lo;
      issue_pkt_cast_o.ecall_s              = ecall_s_lo;
      issue_pkt_cast_o.ecall_u              = ecall_u_lo;
      issue_pkt_cast_o.ebreak               = ebreak_lo;
      issue_pkt_cast_o.dbreak               = dbreak_lo;
      issue_pkt_cast_o.dret                 = dret_lo;
      issue_pkt_cast_o.mret                 = mret_lo;
      issue_pkt_cast_o.sret                 = sret_lo;
      issue_pkt_cast_o.wfi                  = wfi_lo;
      issue_pkt_cast_o.sfence_vma           = sfence_vma_lo;
      issue_pkt_cast_o.fencei               = fencei_lo;
      issue_pkt_cast_o.csrw                 = csrw_lo;

      issue_pkt_cast_o.pc                   = issue_pc;
      issue_pkt_cast_o.instr                = issue_instr;
      issue_pkt_cast_o.size                 = issue_size;
      issue_pkt_cast_o.count                = issue_count;
      issue_pkt_cast_o.decode               = decoded_instr_lo;
      issue_pkt_cast_o.imm                  = decoded_imm_lo;
      issue_pkt_cast_o.branch_metadata_fwd  = fe_queue_lo.branch_metadata_fwd;
    end

endmodule

