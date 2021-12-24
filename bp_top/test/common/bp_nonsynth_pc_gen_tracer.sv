`include "bp_common_defines.svh"
`include "bp_top_defines.svh"
`include "bp_fe_defines.svh"

typedef enum logic [2:0]
{
  e_pc_src_undefined = 3'd0
  ,e_pc_src_redirect
  ,e_pc_src_override_ras
  ,e_pc_src_override_branch
  ,e_pc_src_btb_taken_branch
  ,e_pc_src_last_fetch_plus_four
} bp_pc_src_e;

module bp_nonsynth_pc_gen_tracer
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter fe_trace_file_p = "pc_gen_trace"

    , localparam pc_src_enum_name_prefix_length_lp = 9 // length of "e_pc_src_"
    , localparam pc_src_enum_max_length_lp = 29 // length of longest enum variant name, "e_pc_src_last_fetch_plus_four"
    )
   (input clk_i
    , input reset_i
    , input freeze_i 

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

   // FE state
   , input state_stall_i
   , input state_wait_i

   // FE state causes
   , input queue_miss_i
   , input icache_miss_i
   , input access_fault_i
   , input page_fault_i
   , input itlb_miss_i

   // TODO: I$ rollback, fence

   // IF0
   , input src_redirect_i
   , input src_override_ras_i
   , input src_override_branch_i
   , input src_btb_taken_branch_i

   // IF1
   , input                     if1_top_v_i
   , input [vaddr_width_p-1:0] if1_pc_i

    // IF2
   , input                     if2_top_v_i
   , input [vaddr_width_p-1:0] if2_pc_i

   // TODO: indicate output to FE queue
    );

  // Cycle counter
  logic [29:0] cycle_cnt;
  bsg_counter_clear_up
   #(.max_val_p(2**30-1), .init_val_p(0))
   cycle_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i | freeze_i)

     ,.clear_i(1'b0)
     ,.up_i(1'b1)
     ,.count_o(cycle_cnt)
     );

  bp_pc_src_e pc_src_if1_n, pc_src_if1_r;
  always_ff @(posedge clk_i)
    if (reset_i | freeze_i)
      pc_src_if1_r <= e_pc_src_undefined;
    else
      pc_src_if1_r <= pc_src_if1_n;

  always_comb
    begin
      if (src_redirect_i)
        pc_src_if1_n = e_pc_src_redirect;
      else if (src_override_ras_i)
        pc_src_if1_n = e_pc_src_override_ras;
      else if (src_override_branch_i)
        pc_src_if1_n = e_pc_src_override_branch;
      else if (src_btb_taken_branch_i)
        pc_src_if1_n = e_pc_src_btb_taken_branch;
      else
        pc_src_if1_n = e_pc_src_last_fetch_plus_four;
    end

  function string render_addr_with_validity(logic [vaddr_width_p-1:0] addr, logic valid);
    if (valid)
      return $sformatf(" %x ", addr);
    else
      return $sformatf("(%x)", addr);
  endfunction

  integer file;
  string file_name;
  wire reset_li = reset_i | freeze_i;
  always_ff @(negedge reset_li)
    begin
      file_name = $sformatf("%s_%x.trace", fe_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
      $fwrite(file, "%s,%s,%s,%s,%s,%s,\n", "cycle", "IF1 PC", "IF2 PC", "IF1 PC src", "state", "events");
    end

  string padded_pc_src_if1_name;
  always_ff @(negedge clk_i)
    if (!reset_i && !freeze_i)
    begin
      // Name of the current source, to output to the log file, but with spaces appended for easy uniform-width substrings
      padded_pc_src_if1_name = ({pc_src_if1_r.name(), {20{" "}}});

      $fwrite
        (file
        ,"%0d,%s,%s,%s,%s,"
        ,cycle_cnt
        ,render_addr_with_validity(if1_pc_i,         if1_top_v_i)
        ,render_addr_with_validity(if2_pc_i,         if2_top_v_i)
        ,padded_pc_src_if1_name.substr(pc_src_enum_name_prefix_length_lp, pc_src_enum_max_length_lp-1)
        ,state_stall_i ? "stall" : (state_wait_i ? "wait" : "run"));

      if (queue_miss_i)
        $fwrite(file, "queue miss; ");
      if (icache_miss_i)
        $fwrite(file, "i$ miss; ");
      if (access_fault_i)
        $fwrite(file, "access fault; ");
      if (page_fault_i)
        $fwrite(file, "page fault; ");
      if (itlb_miss_i)
        $fwrite(file, "itlb miss; ");

      $fwrite(file, "\n");
    end

endmodule
