
/**
 * bp_mem_nonsynth_tracer.v
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_mem_nonsynth_tracer
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)

   , parameter data_width_p = l2_fill_width_p
   , parameter trace_file_p = "dram.trace"
   )
  (input                                        clk_i
   , input                                      reset_i

   // BP side
   , input [cce_mem_header_width_lp-1:0]        mem_cmd_header_i
   , input [data_width_p-1:0]                   mem_cmd_data_i
   , input                                      mem_cmd_v_i
   , input                                      mem_cmd_ready_and_i
   , input                                      mem_cmd_last_i

   , input [cce_mem_header_width_lp-1:0]        mem_resp_header_i
   , input [data_width_p-1:0]                   mem_resp_data_i
   , input                                      mem_resp_v_i
   , input                                      mem_resp_ready_and_i
   , input                                      mem_resp_last_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);
  `bp_cast_i(bp_bedrock_cce_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_cce_mem_header_s, mem_resp_header);

  integer file;
  always_ff @(negedge reset_i)
    file = $fopen(trace_file_p, "w");

  always_ff @(posedge clk_i) begin
    if (mem_cmd_v_i & mem_cmd_ready_and_i)
      case (mem_cmd_header_cast_i.msg_type.mem)
        e_bedrock_mem_rd:
          $fwrite(file, "%12t | CMD  RD  : (%x) %b\n", $time, mem_cmd_header_cast_i.addr, mem_cmd_header_cast_i.size);
        e_bedrock_mem_wr:
          $fwrite(file, "%12t | CMD  WR  : (%x) %b %x\n", $time, mem_cmd_header_cast_i.addr, mem_cmd_header_cast_i.size, mem_cmd_data_i);
        e_bedrock_mem_uc_rd:
          $fwrite(file, "%12t | CMD  UCRD: (%x) %b\n", $time, mem_cmd_header_cast_i.addr, mem_cmd_header_cast_i.size);
        e_bedrock_mem_uc_wr:
          $fwrite(file, "%12t | CMD  UCWR: (%x) %b %x\n", $time, mem_cmd_header_cast_i.addr, mem_cmd_header_cast_i.size, mem_cmd_data_i);
        default:
          $fwrite(file, "%12t | CMD  ERROR: unknown cmd_type %x received!", $time, mem_resp_header_cast_i.msg_type.mem);
      endcase
  
    if (mem_resp_v_i & mem_resp_ready_and_i)
      case (mem_resp_header_cast_i.msg_type.mem)
        e_bedrock_mem_rd:
          $fwrite(file, "%12t | RESP RD  : (%x) %b %x\n", $time, mem_resp_header_cast_i.addr, mem_resp_header_cast_i.size, mem_resp_data_i);
        e_bedrock_mem_wr:
          $fwrite(file, "%12t | RESP WR  : (%x) %b\n", $time, mem_resp_header_cast_i.addr, mem_resp_header_cast_i.size);
        e_bedrock_mem_uc_rd:
          $fwrite(file, "%12t | RESP UCRD: (%x) %b %x\n", $time, mem_resp_header_cast_i.addr, mem_resp_header_cast_i.size, mem_resp_data_i);
        e_bedrock_mem_uc_wr:
          $fwrite(file, "%12t | RESP UCWR: (%x) %b\n", $time, mem_resp_header_cast_i.addr, mem_resp_header_cast_i.size);
        default:
          $fwrite(file, "%12t | ERROR: unknown resp_type %x received!", $time, mem_resp_header_cast_i.msg_type.mem);
      endcase
  end

endmodule

