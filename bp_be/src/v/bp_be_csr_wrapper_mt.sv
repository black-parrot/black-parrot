/**
 * bp_be_csr_wrapper_mt.sv
 *
 * Multi-thread CSR Wrapper — Phase 2A
 *
 * Instantiates one bp_be_csr per thread (num_threads_p copies).
 * Presents the same external interface as a single bp_be_csr so it can be
 * used as a drop-in replacement in bp_be_pipe_sys.
 *
 * Gating rules:
 *   retire_pkt, fflags_acc, frf_w_v, csr_r_v  → only active thread
 *   IRQ signals (debug/timer/software/external) → all threads (keeps mip current)
 *
 * Output muxing: all outputs come from current_thread_id_i's instance.
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_csr_wrapper_mt
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cfg_bus_width_lp-1:0]            cfg_bus_i

   // CSR check interface
   , input                                   csr_r_v_i
   , input [rv64_csr_addr_width_gp-1:0]      csr_r_addr_i
   , output logic [dword_width_gp-1:0]       csr_r_data_o
   , output logic                            csr_r_illegal_o

   // Misc interface
   , input [retire_pkt_width_lp-1:0]         retire_pkt_i
   , input rv64_fflags_s                     fflags_acc_i
   , input                                   frf_w_v_i

   // Interrupts — broadcast to all threads so mip stays current
   , input                                   debug_irq_i
   , input                                   timer_irq_i
   , input                                   software_irq_i
   , input                                   m_external_irq_i
   , input                                   s_external_irq_i
   , output logic                            irq_pending_o
   , output logic                            irq_waiting_o

   // The final commit packet
   , output logic [commit_pkt_width_lp-1:0]  commit_pkt_o

   // Slow signals
   , output logic [decode_info_width_lp-1:0] decode_info_o
   , output logic [trans_info_width_lp-1:0]  trans_info_o
   , output rv64_frm_e                       frm_dyn_o

   // Context switching control (Phase 1.4)
   , input [thread_id_width_p-1:0]           current_thread_id_i
   , output logic                            csr_ctxt_write_v_o
   , output logic [thread_id_width_p-1:0]    csr_ctxt_write_data_o

   // Bootstrap: write target NPC for a thread (CSR 0x082)
   , output logic                            ctx_npc_write_v_o
   , output logic [thread_id_width_p-1:0]    ctx_npc_write_tid_o
   , output logic [vaddr_width_p-1:0]        ctx_npc_write_npc_o

   // rpush: write arbitrary register of a disabled thread (CSR 0x083)
   , output logic                            ctx_rpush_v_o
   , output logic                            ctx_rpush_fp_v_o
   , output logic [thread_id_width_p-1:0]    ctx_rpush_tid_o
   , output logic [reg_addr_width_gp-1:0]    ctx_rpush_reg_o
   , output logic [dpath_width_gp-1:0]       ctx_rpush_data_o
   );

  // Per-thread output arrays
  logic [num_threads_p-1:0][dword_width_gp-1:0]       csr_r_data_co;
  logic [num_threads_p-1:0]                            csr_r_illegal_co;
  logic [num_threads_p-1:0][commit_pkt_width_lp-1:0]  commit_pkt_co;
  logic [num_threads_p-1:0][decode_info_width_lp-1:0] decode_info_co;
  logic [num_threads_p-1:0][trans_info_width_lp-1:0]  trans_info_co;
  rv64_frm_e [num_threads_p-1:0]                      frm_dyn_co;
  logic [num_threads_p-1:0]                            irq_pending_co;
  logic [num_threads_p-1:0]                            irq_waiting_co;
  logic [num_threads_p-1:0]                            csr_ctxt_write_v_co;
  logic [num_threads_p-1:0][thread_id_width_p-1:0]    csr_ctxt_write_data_co;
  logic [num_threads_p-1:0]                            ctx_npc_write_v_co;
  logic [num_threads_p-1:0][thread_id_width_p-1:0]    ctx_npc_write_tid_co;
  logic [num_threads_p-1:0][vaddr_width_p-1:0]        ctx_npc_write_npc_co;
  logic [num_threads_p-1:0]                            ctx_rpush_v_co;
  logic [num_threads_p-1:0]                            ctx_rpush_fp_v_co;
  logic [num_threads_p-1:0][thread_id_width_p-1:0]    ctx_rpush_tid_co;
  logic [num_threads_p-1:0][reg_addr_width_gp-1:0]    ctx_rpush_reg_co;
  logic [num_threads_p-1:0][dpath_width_gp-1:0]       ctx_rpush_data_co;

  // Per-thread gated inputs
  logic [num_threads_p-1:0]                          csr_r_v_gated;
  logic [num_threads_p-1:0]                          frf_w_v_gated;
  logic [num_threads_p-1:0][retire_pkt_width_lp-1:0] retire_pkt_gated;
  rv64_fflags_s [num_threads_p-1:0]                  fflags_acc_gated;

  for (genvar i = 0; i < num_threads_p; i++) begin : gen_gate
    wire active = (current_thread_id_i == thread_id_width_p'(i));
    assign csr_r_v_gated[i]     = csr_r_v_i & active;
    assign frf_w_v_gated[i]     = frf_w_v_i & active;
    assign retire_pkt_gated[i]  = active ? retire_pkt_i : '0;
    assign fflags_acc_gated[i]  = active ? fflags_acc_i : rv64_fflags_s'('0);
  end

  for (genvar i = 0; i < num_threads_p; i++) begin : gen_csr
    bp_be_csr
     #(.bp_params_p(bp_params_p))
     csr_inst
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.cfg_bus_i(cfg_bus_i)

       ,.csr_r_v_i(csr_r_v_gated[i])
       ,.csr_r_addr_i(csr_r_addr_i)
       ,.csr_r_data_o(csr_r_data_co[i])
       ,.csr_r_illegal_o(csr_r_illegal_co[i])

       ,.retire_pkt_i(retire_pkt_gated[i])
       ,.fflags_acc_i(fflags_acc_gated[i])
       ,.frf_w_v_i(frf_w_v_gated[i])

       ,.debug_irq_i(debug_irq_i)
       ,.timer_irq_i(timer_irq_i)
       ,.software_irq_i(software_irq_i)
       ,.m_external_irq_i(m_external_irq_i)
       ,.s_external_irq_i(s_external_irq_i)
       ,.irq_pending_o(irq_pending_co[i])
       ,.irq_waiting_o(irq_waiting_co[i])

       ,.commit_pkt_o(commit_pkt_co[i])
       ,.decode_info_o(decode_info_co[i])
       ,.trans_info_o(trans_info_co[i])
       ,.frm_dyn_o(frm_dyn_co[i])

       ,.current_thread_id_i(current_thread_id_i)
       ,.csr_ctxt_write_v_o(csr_ctxt_write_v_co[i])
       ,.csr_ctxt_write_data_o(csr_ctxt_write_data_co[i])

       ,.ctx_npc_write_v_o(ctx_npc_write_v_co[i])
       ,.ctx_npc_write_tid_o(ctx_npc_write_tid_co[i])
       ,.ctx_npc_write_npc_o(ctx_npc_write_npc_co[i])

       ,.ctx_rpush_v_o(ctx_rpush_v_co[i])
       ,.ctx_rpush_fp_v_o(ctx_rpush_fp_v_co[i])
       ,.ctx_rpush_tid_o(ctx_rpush_tid_co[i])
       ,.ctx_rpush_reg_o(ctx_rpush_reg_co[i])
       ,.ctx_rpush_data_o(ctx_rpush_data_co[i])
       );
  end

  // ── Debug: trace mscratch (0x340) reads and writes per-instance ──
  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);
  bp_be_retire_pkt_s dbg_retire;
  assign dbg_retire = retire_pkt_i;

  // Print which instances see a mscratch write and whether they are gated
  always_ff @(posedge clk_i) begin
    if (!reset_i && dbg_retire.special.csrw && (dbg_retire.instr.t.itype.imm12 == 12'h340)) begin
      $display("[CSR_DBG @%0t] MSCRATCH WRITE: tid=%0d data=0x%0x",
               $time, current_thread_id_i, dbg_retire.data);
      for (int k = 0; k < num_threads_p; k++) begin
        $display("  inst[%0d]: active=%0b  csr_r_data_co=0x%0x",
                 k, (current_thread_id_i == thread_id_width_p'(k)),
                 csr_r_data_co[k]);
      end
    end
  end

  // Print mscratch reads: which instance is selected and what value is returned
  always_ff @(posedge clk_i) begin
    if (!reset_i && csr_r_v_i && (csr_r_addr_i == 12'h340)) begin
      $display("[CSR_DBG @%0t] MSCRATCH READ:  tid=%0d  ret=0x%0x  (per-inst: %0p)",
               $time, current_thread_id_i, csr_r_data_o, csr_r_data_co);
    end
  end
  // ── End debug ──

  // Mux all outputs from the active thread
  assign csr_r_data_o          = csr_r_data_co[current_thread_id_i];
  assign csr_r_illegal_o       = csr_r_illegal_co[current_thread_id_i];
  assign commit_pkt_o          = commit_pkt_co[current_thread_id_i];
  assign decode_info_o         = decode_info_co[current_thread_id_i];
  assign trans_info_o          = trans_info_co[current_thread_id_i];
  assign frm_dyn_o             = frm_dyn_co[current_thread_id_i];
  assign irq_pending_o         = irq_pending_co[current_thread_id_i];
  assign irq_waiting_o         = irq_waiting_co[current_thread_id_i];
  assign csr_ctxt_write_v_o    = csr_ctxt_write_v_co[current_thread_id_i];
  assign csr_ctxt_write_data_o = csr_ctxt_write_data_co[current_thread_id_i];
  assign ctx_npc_write_v_o     = ctx_npc_write_v_co[current_thread_id_i];
  assign ctx_npc_write_tid_o   = ctx_npc_write_tid_co[current_thread_id_i];
  assign ctx_npc_write_npc_o   = ctx_npc_write_npc_co[current_thread_id_i];
  assign ctx_rpush_v_o         = ctx_rpush_v_co[current_thread_id_i];
  assign ctx_rpush_fp_v_o      = ctx_rpush_fp_v_co[current_thread_id_i];
  assign ctx_rpush_tid_o       = ctx_rpush_tid_co[current_thread_id_i];
  assign ctx_rpush_reg_o       = ctx_rpush_reg_co[current_thread_id_i];
  assign ctx_rpush_data_o      = ctx_rpush_data_co[current_thread_id_i];

endmodule

`BSG_ABSTRACT_MODULE(bp_be_csr_wrapper_mt)
