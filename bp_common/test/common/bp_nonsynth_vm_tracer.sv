
`include "bp_common_defines.svh"

module bp_nonsynth_vm_tracer
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter string trace_str_p = ""
   )
  (input                             clk_i
   , input                           reset_i
   , input                           en_i
   );

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // snoop
  wire bp_cfg_bus_s cfg_bus = bp_mmu.cfg_bus_i;
  wire bp_pte_leaf_s tlb_w_entry = bp_mmu.w_entry_i;
  wire clear_v = bp_mmu.fence_i;
  wire req_v = bp_mmu.r_v_i;
  wire fill_v = bp_mmu.w_v_i;
  wire [ptag_width_p-1:0] ptag = tlb_w_entry.ptag;
  wire [vtag_width_p-1:0] vtag = bp_mmu.tlb_vtag_li;
  wire [core_id_width_p-1:0] mhartid = cfg_bus.core_id;
  wire [ptag_width_p-1:0] read_ptag = bp_mmu.r_ptag_o;
  wire read_hit_v = bp_mmu.r_v_o;
  wire read_fault_v = bp_mmu.any_fault_v;
  wire read_miss_v = bp_mmu.r_instr_miss_o | bp_mmu.r_load_miss_o | bp_mmu.r_store_miss_o;
  wire passthrough = !bp_mmu.trans_r;

  wire tlb_read_v = bp_mmu.tlb.v_i & ~bp_mmu.tlb.w_i;

  // process
  int read_cnt; always_ff @(posedge clk_i) read_cnt <= read_cnt + tlb_read_v;
  logic [vtag_width_p-1:0] vtag_r; always_ff @(posedge clk_i) if (req_v) vtag_r <= vtag;

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, mhartid);

  always_ff @(posedge clk_i)
    if (do_init)
      begin
        $fdisplay(file,"==============================================");
        $fdisplay(file, "MMU features:");
        $fdisplay(file, "\tlatch_last_read: %b", bp_mmu.latch_last_read_p);
        $fdisplay(file,"==============================================");
      end
    else if (is_go)
      begin
        if (clear_v)
          $fdisplay(file, "%8t | clear", $time);
        if (fill_v)
          $fdisplay(file, "%8t | map %x -> %x [R:%b W:%b X:%b M:%b G:%b]"
              ,$time
              ,vtag
              ,ptag
              ,tlb_w_entry.r
              ,tlb_w_entry.w
              ,tlb_w_entry.x
              ,tlb_w_entry.megapage
              ,tlb_w_entry.gigapage
              );
        if (!passthrough && read_hit_v)
          $fdisplay(file, "%8t | read %x -> %x", $time, vtag_r, read_ptag);
        if (!passthrough && read_miss_v)
          $fdisplay(file, "%8t | miss [%x]", $time, vtag_r);
        if (!passthrough && read_fault_v)
          $fdisplay(file, "%8t | fault [%x]", $time, vtag_r);
      end

  final
    begin
      $fdisplay(file,"==============================================");
      $fdisplay(file, "%8t | Total read access count is %0d.", $time, read_cnt);
    end

endmodule

