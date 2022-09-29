//`include "bp_common_defines.svh"
//`include "bp_top_defines.svh"
//`include "bp_fe_defines.svh"
//
///*
//Tracer which emits a log of every program counter/fetch address output by the pc_gen module. Every
//cycle has an associated log output line. Each line shows the simulation time and cycle count, along
//with:
//
//  - The PC currently in the IF2 stage. If it is enclosed in parentheses, this entry was
//    invalidated and won't be issued.
//  - The reason the above PC was fetched:
//    - undefined: the simulation just started and nothing has propagated to IF2 yet 
//    - redirect: either a BE->FE command or resuming after a stall
//    - override_ntaken: a misaligned instruction required a second fetch for the same PC
//    - override_ras: the RAS was used to predict a JALR (IF2)
//    - override_branch: a jump instruction was discovered late (IF2) and caused a bubble
//    - btb_taken_branch: the BTB and BHT predict a taken jump (IF1)
//    - last_fetch_plus_four: no special control flow, defaulted to a linear fetch
//  - The PC and partial instruction stored in the realigner (for misaligned and compressed instructions)
//  - The running count of "ntaken" overrides, i.e. predicted-taken jumps which were overridden to be not-taken
//  - Frontend state: either "run" or "stall". Note that, even when stalled, log entries are
//    emitted and PCs progress through the frontend. They will not be issued.
//  - Events: external status which may impact the next fetch. Faults, I$ and ITLB misses, and "queue"
//    misses (FE queue full) are indicated here.
//
//Although "stall" entries are generally uninteresting, a change in behavior while stalled may
//indicate a logic bug. This has been useful in the past.
//
//This tracer can be used to inspect the branch prediction flow for specific points in execution, or to
//textually diff the output before and after a change to identify its effects. This can be extremely
//valuable for tracking down regressions.
//
//Exmple trace ("cuts" introduced for brevity):
//
//        time |   cycle,       IF2 PC,           IF2 PC src, state, events
//    [============================ cut ===========================]
//    76356000 | 0022607, (0080000998), last_fetch_plus_four,   run, 
//    76357000 | 0022608,  0080000954 ,             redirect,   run, 
//    76358000 | 0022609, (0080000958), last_fetch_plus_four,   run, 
//    76359000 | 0022610,  00800007f8 ,      override_branch,   run, 
//    76360000 | 0022611,  00800007fc , last_fetch_plus_four,   run, 
//    76361000 | 0022612,  0080000800 , last_fetch_plus_four,   run, 
//    76362000 | 0022613,  0080000804 , last_fetch_plus_four,   run, 
//    76363000 | 0022614,  0080000808 , last_fetch_plus_four,   run, 
//    76364000 | 0022615,  008000080c , last_fetch_plus_four,   run, 
//    76365000 | 0022616,  0080000810 , last_fetch_plus_four,   run, 
//    76366000 | 0022617,  0080000814 , last_fetch_plus_four,   run, 
//    76367000 | 0022618,  0080000818 , last_fetch_plus_four,   run, 
//    76368000 | 0022619, (008000081c), last_fetch_plus_four,   run, 
//    76369000 | 0022620,  0080000710 ,      override_branch,   run, queue miss; i$ miss; 
//    76370000 | 0022621, (0080000714), last_fetch_plus_four, stall, 
//    76371000 | 0022622, (0080000718), last_fetch_plus_four, stall, 
//    [============================ cut ===========================]
//    76383000 | 0022634, (0080000748), last_fetch_plus_four, stall, 
//    76384000 | 0022635, (008000074c), last_fetch_plus_four, stall, 
//    76385000 | 0022636, (0080000750), last_fetch_plus_four,   run, 
//    76386000 | 0022637,  0080000710 ,             redirect,   run, 
//    76387000 | 0022638,  0080000714 , last_fetch_plus_four,   run, 
//    76388000 | 0022639,  0080000718 , last_fetch_plus_four,   run, 
//    76389000 | 0022640,  008000071c , last_fetch_plus_four,   run, 
//*/
//
//typedef enum logic [2:0]
//{
//  e_pc_src_undefined = 3'd0
//  ,e_pc_src_redirect
//  ,e_pc_src_override_ntaken
//  ,e_pc_src_override_ras
//  ,e_pc_src_override_branch
//  ,e_pc_src_btb_taken_branch
//  ,e_pc_src_last_fetch_plus_four
//} bp_fe_pc_gen_src_e;
//
//module bp_fe_nonsynth_pc_gen_tracer
//  import bp_common_pkg::*;
//  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
//    `declare_bp_proc_params(bp_params_p)
//
//    , parameter fe_trace_file_p = "pc_gen_trace"
//
//    , localparam pc_src_enum_name_prefix_length_lp = 9 // length of "e_pc_src_"
//    , localparam max_ovr_ntaken_count_nonsynth_lp = (2**30)-1
//    )
//   (input clk_i
//    , input reset_i
//    , input freeze_i 
//
//    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i
//
//   // FE state
//   , input state_resume_i
//   , input state_wait_i
//
//   // FE state causes
//<<<<<<< HEAD
//   , input queue_miss_i
//   , input icache_miss_i
//   , input icache_req_i
//=======
//   , input icache_spec_i
//>>>>>>> Changes made, should break up and clean
//   , input access_fault_i
//   , input page_fault_i
//   , input itlb_miss_i
//
//   // IF0
//   , input src_redirect_i
//   , input src_override_ntaken_i
//   , input src_override_ras_i
//   , input src_override_branch_i
//   , input src_btb_taken_branch_i
//
//    // IF2
//<<<<<<< HEAD
//   , input                     if2_top_v_i
//   , input [vaddr_width_p-1:0] if2_pc_i
//   , input                     realigner_v_i
//   , input [vaddr_width_p-1:0] realigner_pc_i
//   , input [instr_half_width_gp-1:0] realigner_instr_i
//=======
//   , input                     fetch_v_i
//   , input [vaddr_width_p-1:0] fetch_pc_i
//>>>>>>> Changes made, should break up and clean
//
//   // TODO: indicate output to FE queue
//    );
//
//  // Cycle counter
//  logic [29:0] cycle_cnt;
//  bsg_counter_clear_up
//   #(.max_val_p(2**30-1), .init_val_p(0))
//   cycle_counter
//    (.clk_i(clk_i)
//     ,.reset_i(reset_i | freeze_i)
//
//     ,.clear_i(1'b0)
//     ,.up_i(1'b1)
//     ,.count_o(cycle_cnt)
//     );
//
//  bp_fe_pc_gen_src_e pc_src_next, pc_src_fetch;
//  logic [$bits(bp_fe_pc_gen_src_e)-1:0] pc_src_fetch_r;
//  bsg_dff_chain
//   #(.width_p($bits(bp_fe_pc_gen_src_e)), .num_stages_p(2))
//   pc_src_reg
//    (.clk_i(clk_i)
//
//     ,.data_i(pc_src_next)
//     ,.data_o(pc_src_fetch_r)
//    );
//  assign pc_src_fetch = bp_fe_pc_gen_src_e'(pc_src_fetch_r);
//
//  logic [`BSG_SAFE_CLOG2(max_ovr_ntaken_count_nonsynth_lp+1)-1:0] ovr_ntaken_count;
//  bsg_counter_clear_up
//    #(.max_val_p(max_ovr_ntaken_count_nonsynth_lp), .init_val_p(0))
//    ovr_ntaken_counter
//      (.clk_i(clk_i)
//      ,.reset_i(reset_i)
//
//      ,.clear_i(reset_i)
//      ,.up_i(pc_src_if2_n == e_pc_src_override_ntaken)
//      ,.count_o(ovr_ntaken_count)
//      );
//
//  always_comb
//    begin
//      // TODO: deduplicate "if" chain from bp_fe_pc_gen.sv
//      if (src_redirect_i)
//<<<<<<< HEAD
//        pc_src_if1_n = e_pc_src_redirect;
//      else if (src_override_ntaken_i)
//        pc_src_if1_n = e_pc_src_override_ntaken;
//=======
//        pc_src_next = e_pc_src_redirect;
//>>>>>>> Changes made, should break up and clean
//      else if (src_override_ras_i)
//        pc_src_next = e_pc_src_override_ras;
//      else if (src_override_branch_i)
//        pc_src_next = e_pc_src_override_branch;
//      else if (src_btb_taken_branch_i)
//        pc_src_next = e_pc_src_btb_taken_branch;
//      else
//        pc_src_next = e_pc_src_last_fetch_plus_four;
//    end
//
//  function string render_addr_with_validity(logic [vaddr_width_p-1:0] addr, logic valid);
//    if (valid)
//      return $sformatf(" %x ", addr);
//    else
//      return $sformatf("(%x)", addr);
//  endfunction
//
//  function string render_half_instr_with_validity(logic [instr_half_width_gp-1:0] instr, logic valid);
//    if (valid)
//      return $sformatf("     %x ", instr);
//    else
//      return $sformatf("    (%x)", instr);
//  endfunction
//
//  integer file;
//  string file_name;
//  wire reset_li = reset_i | freeze_i;
//  always_ff @(negedge reset_li)
//    begin
//      file_name = $sformatf("%s_%x.trace", fe_trace_file_p, mhartid_i);
//      file      = $fopen(file_name, "w");
//      $fwrite(
//        file,
//        "%12s | %7s, %12s, %20s, %12s, %12s, %8s, %5s, %s\n",
//        "time", "cycle", "IF2 PC", "IF2 PC src", "partial PC", "partial insn", "# ntaken", "state", "events"
//      );
//    end
//
//  string trimmed_pc_src_fetch_name;
//  always_ff @(negedge clk_i)
//    if (!reset_i && !freeze_i)
//    begin
//      trimmed_pc_src_fetch_name = pc_src_fetch.name().substr(pc_src_enum_name_prefix_length_lp, pc_src_fetch.name().len()-1);
//
//      $fwrite
//        (file
//        ,"%12t | %07d, %12s, %20s, %12s, %12s, %8d, %5s, "
//        ,$time
//        ,cycle_cnt
//<<<<<<< HEAD
//        ,render_addr_with_validity(if2_pc_i, if2_top_v_i)
//        ,trimmed_pc_src_if2_name
//        ,render_addr_with_validity(realigner_pc_i, realigner_v_i)
//        ,render_half_instr_with_validity(realigner_instr_i, realigner_v_i)
//        ,ovr_ntaken_count
//        ,state_stall_i ? "stall" : (state_wait_i ? "wait" : "run"));
//=======
//        ,render_addr_with_validity(fetch_pc_i, fetch_v_i)
//        ,trimmed_pc_src_fetch_name
//        ,state_resume_i ? "resume" : (state_wait_i ? "wait" : "run"));
//>>>>>>> Changes made, should break up and clean
//
//      if (icache_spec_i & fetch_v_i)
//        $fwrite(file, "i$ miss; ");
//<<<<<<< HEAD
//      if (icache_req_i)
//        $fwrite(file, "outgoing i$ req; ");
//      if (access_fault_i)
//=======
//      if (access_fault_i & fetch_v_i)
//>>>>>>> Changes made, should break up and clean
//        $fwrite(file, "access fault; ");
//      if (page_fault_i & fetch_v_i)
//        $fwrite(file, "page fault; ");
//      if (itlb_miss_i & fetch_v_i)
//        $fwrite(file, "itlb miss; ");
//
//      $fwrite(file, "\n");
//    end
//
//endmodule
