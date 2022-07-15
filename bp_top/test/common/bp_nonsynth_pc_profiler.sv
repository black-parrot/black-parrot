// Copyright (c) 2022, University of Washington
// Copyright and related rights are licensed under the BSD 3-Clause
// License (the “License”); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
// https://github.com/black-parrot/black-parrot/LICENSE.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed
// on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language
// governing permissions and limitations under the License.


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

