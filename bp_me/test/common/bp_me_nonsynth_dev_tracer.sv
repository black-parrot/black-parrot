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

/**
 *
 * Name:
 *   bp_me_nonsynth_dev_tracer.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_dev_tracer
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter trace_file_p = "dev"

    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i
   , input                                          freeze_i

   , input [core_id_width_p-1:0]                    id_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [mem_header_width_lp-1:0]                mem_cmd_header_i
   , input [dword_width_gp-1:0]                     mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , input                                          mem_cmd_ready_and_i
   , input                                          mem_cmd_last_i

   , input [mem_header_width_lp-1:0]                mem_resp_header_i
   , input [dword_width_gp-1:0]                     mem_resp_data_i
   , input                                          mem_resp_v_i
   , input                                          mem_resp_ready_and_i
   , input                                          mem_resp_last_i
  );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_resp_header);

  integer file;
  string file_name;

  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
    begin
      file_name = $sformatf("%s_%x.trace", trace_file_p, id_i);
      file      = $fopen(file_name, "w");
    end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (mem_cmd_v_i & mem_cmd_ready_and_i) begin
        $fdisplay(file, "%12t |: MEM CMD addr[%H] msg[%b] size[%b]"
                 , $time
                 , mem_cmd_header_cast_i.addr
                 , mem_cmd_header_cast_i.msg_type.mem
                 , mem_cmd_header_cast_i.size
                 );
        if (mem_cmd_header_cast_i.msg_type.mem inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr}) begin
          $fdisplay(file, "%12t |: MEM CMD DATA last[%0b] %H"
                   , $time
                   , mem_cmd_last_i
                   , mem_cmd_data_i
                   );
        end
      end
      if (mem_resp_v_i & mem_resp_ready_and_i) begin
        $fdisplay(file, "%12t |: MEM RESP addr[%H] msg[%b] size[%b]"
                 , $time
                 , mem_resp_header_cast_i.addr
                 , mem_resp_header_cast_i.msg_type.mem
                 , mem_resp_header_cast_i.size
                 );
        if (mem_resp_header_cast_i.msg_type.mem inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd}) begin
          $fdisplay(file, "%12t |: MEM RESP DATA last[%0b] %H"
                   , $time
                   , mem_resp_last_i
                   , mem_resp_data_i
                   );
        end
      end
    end // reset & trace
  end // always_ff

endmodule
