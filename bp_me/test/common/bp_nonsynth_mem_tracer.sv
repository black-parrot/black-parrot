
/*
 * Name:
 *   bp_nonsynth_mem_tracer.sv
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_nonsynth_mem_tracer
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , parameter trace_file_p = "dram.trace"
   )
  (input                                        clk_i
   , input                                      reset_i

   // BP side
   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [l2_data_width_p-1:0]                mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , input                                      mem_fwd_ready_and_i
   , input                                      mem_fwd_last_i

   , input [mem_rev_header_width_lp-1:0]        mem_rev_header_i
   , input [l2_data_width_p-1:0]                mem_rev_data_i
   , input                                      mem_rev_v_i
   , input                                      mem_rev_ready_and_i
   , input                                      mem_rev_last_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  integer file;
  always_ff @(negedge reset_i)
    file = $fopen(trace_file_p, "w");

  always_ff @(posedge clk_i) begin
    if (mem_fwd_v_i & mem_fwd_ready_and_i)
      case (mem_fwd_header_cast_i.msg_type.fwd)
        e_bedrock_mem_rd:
          $fwrite(file, "%12t | FWD  RD  : (%x) %b\n", $time, mem_fwd_header_cast_i.addr, mem_fwd_header_cast_i.size);
        e_bedrock_mem_wr:
          $fwrite(file, "%12t | FWD  WR  : (%x) %b %x\n", $time, mem_fwd_header_cast_i.addr, mem_fwd_header_cast_i.size, mem_fwd_data_i);
        e_bedrock_mem_uc_rd:
          $fwrite(file, "%12t | FWD  UCRD: (%x) %b\n", $time, mem_fwd_header_cast_i.addr, mem_fwd_header_cast_i.size);
        e_bedrock_mem_uc_wr:
          $fwrite(file, "%12t | FWD  UCWR: (%x) %b %x\n", $time, mem_fwd_header_cast_i.addr, mem_fwd_header_cast_i.size, mem_fwd_data_i);
        default:
          $fwrite(file, "%12t | FWD  ERROR: unknown cmd_type %x received!", $time, mem_rev_header_cast_i.msg_type.fwd);
      endcase

    if (mem_rev_v_i & mem_rev_ready_and_i)
      case (mem_rev_header_cast_i.msg_type.fwd)
        e_bedrock_mem_rd:
          $fwrite(file, "%12t | REV  RD  : (%x) %b %x\n", $time, mem_rev_header_cast_i.addr, mem_rev_header_cast_i.size, mem_rev_data_i);
        e_bedrock_mem_wr:
          $fwrite(file, "%12t | REV  WR  : (%x) %b\n", $time, mem_rev_header_cast_i.addr, mem_rev_header_cast_i.size);
        e_bedrock_mem_uc_rd:
          $fwrite(file, "%12t | REV  UCRD: (%x) %b %x\n", $time, mem_rev_header_cast_i.addr, mem_rev_header_cast_i.size, mem_rev_data_i);
        e_bedrock_mem_uc_wr:
          $fwrite(file, "%12t | REV  UCWR: (%x) %b\n", $time, mem_rev_header_cast_i.addr, mem_rev_header_cast_i.size);
        default:
          $fwrite(file, "%12t | ERROR: unknown resp_type %x received!", $time, mem_rev_header_cast_i.msg_type.fwd);
      endcase
  end

endmodule

