
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_pc_profiler
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter pc_trace_file_p = "pc"

    , localparam commit_pkt_width_lp = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
    )
   (input clk_i
    , input reset_i
    , input freeze_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i

    // Commit packet
    , input [commit_pkt_width_lp-1:0] commit_pkt
    );

  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  bp_be_commit_pkt_s commit_pkt_cast_i;
  assign commit_pkt_cast_i = commit_pkt;

  integer histogram [longint];

  integer file;
  string file_name;
  wire reset_li = reset_i | freeze_i;
  always_ff @(negedge reset_li)
    begin
      file_name = $sformatf("%s_%x.histogram", pc_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
    end

  logic [dword_width_gp-1:0] count;
  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        count <= '0;
      else
        count <= count + 1'b1;

      if (commit_pkt_cast_i.instret)
        if (histogram.exists(commit_pkt_cast_i.pc))
          histogram[commit_pkt_cast_i.pc] <= histogram[commit_pkt_cast_i.pc] + 1'b1;
        else
          histogram[commit_pkt_cast_i.pc] <= 1'b1;
    end

  final
   foreach (histogram[key])
     $fwrite(file, "[%x] %x\n", key, histogram[key]);

endmodule

