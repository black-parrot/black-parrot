
/**
 * bp_mem_nonsynth_tracer.v
 */

module bp_mem_nonsynth_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , parameter trace_file_p = "prog.dram"
   )
  (input                                 clk_i
   , input                               reset_i

   // BP side
   , input [cce_mem_msg_width_lp-1:0]    mem_cmd_i
   , input                               mem_cmd_v_i
   , input                               mem_cmd_yumi_i

   , input [cce_mem_msg_width_lp-1:0]    mem_resp_i
   , input                               mem_resp_v_i
   , input                               mem_resp_ready_i
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

wire unused = &{mem_cmd_v_i, mem_resp_ready_i};

integer file;
always_ff @(negedge reset_i) begin
  file = $fopen(trace_file_p, "w");
end

bp_cce_mem_msg_s mem_cmd_cast_i;
bp_cce_mem_msg_s mem_resp_cast_i;

assign mem_cmd_cast_i = mem_cmd_i;
assign mem_resp_cast_i = mem_resp_i;

always_ff @(posedge clk_i) begin
  if (mem_cmd_yumi_i)
    case (mem_cmd_cast_i.msg_type)
      e_cce_mem_rd: 
        $fwrite(file, "[%t] CMD RD: (%x) %b\n", $time, mem_cmd_cast_i.addr, mem_cmd_cast_i.size);
      e_cce_mem_wr:
        $fwrite(file, "[%t] CMD WR: (%x) %b\n", $time, mem_cmd_cast_i.addr, mem_cmd_cast_i.size);
      e_cce_mem_uc_rd:
        $fwrite(file, "[%t] CMD UCRD: (%x) %b\n", $time, mem_cmd_cast_i.addr, mem_cmd_cast_i.size);
      e_cce_mem_uc_wr:
        $fwrite(file, "[%t] CMD UCWR: (%x) %b %x\n", $time, mem_cmd_cast_i.addr, mem_cmd_cast_i.size, mem_cmd_cast_i.data);
      e_cce_mem_wb:
        $fwrite(file, "[%t] CMD WB: (%x) %b %x\n", $time, mem_cmd_cast_i.addr, mem_cmd_cast_i.size, mem_cmd_cast_i.data);
      e_mem_cce_inv:
        $fwrite(file, "[%t] CMD INV: (%x)\n", $time, mem_resp_cast_i.addr);
      default: 
        $fwrite(file, "[%t] CMD ERROR: unknown cmd_type %x received!", $time, mem_resp_cast_i.msg_type);
    endcase

  if (mem_resp_v_i)
    case (mem_resp_cast_i.msg_type)
      e_cce_mem_rd:
        $fwrite(file, "[%t] RESP RD: (%x) %b %x\n", $time, mem_resp_cast_i.addr, mem_resp_cast_i.size, mem_resp_cast_i.data);
      e_cce_mem_wr:
        $fwrite(file, "[%t] RESP WR: (%x) %b %x\n", $time, mem_resp_cast_i.addr, mem_resp_cast_i.size, mem_resp_cast_i.data);
      e_cce_mem_uc_rd:
        $fwrite(file, "[%t] RESP UCRD: (%x) %b %x\n", $time, mem_resp_cast_i.addr, mem_resp_cast_i.size, mem_resp_cast_i.data);
      e_cce_mem_uc_wr:
        $fwrite(file, "[%t] RESP UCWR: (%x) %b\n", $time, mem_resp_cast_i.addr, mem_resp_cast_i.size);
      e_cce_mem_wb:
        $fwrite(file, "[%t] RESP WB: (%x) %b\n", $time, mem_resp_cast_i.addr, mem_resp_cast_i.size);
      e_mem_cce_inv:
        $fwrite(file, "[%t] RESP INV: (%x)\n", $time, mem_resp_cast_i.addr);
      default: 
        $fwrite(file, "[%t] ERROR: unknown resp_type %x received!", $time, mem_resp_cast_i.msg_type);
    endcase
end

endmodule

