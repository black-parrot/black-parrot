
module bp_be_nonsynth_npc_tracer
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   , parameter npc_trace_file_p = "npc"

   , localparam trap_pkt_width_lp = `bp_be_trap_pkt_width(vaddr_width_p)
   , localparam hartid_width_lp = `BSG_SAFE_CLOG2(num_core_p)
   )
  (input                         clk_i
   , input                       reset_i
   , input                       freeze_i

   , input [hartid_width_lp-1:0] mhartid_i

   , input                       npc_w_v
   , input [vaddr_width_p-1:0]   npc_n
   , input [vaddr_width_p-1:0]   npc_r
   , input [vaddr_width_p-1:0]   expected_npc_o

   , input [fe_cmd_width_lp-1:0] fe_cmd_i
   , input                       fe_cmd_v

   , input [trap_pkt_width_lp-1:0] trap_pkt_i
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
bp_fe_cmd_s fe_cmd;
bp_be_trap_pkt_s trap_pkt;
assign fe_cmd = fe_cmd_i;
assign trap_pkt = trap_pkt_i;

integer file;
string file_name;

wire delay_li = reset_i | freeze_i;
always_ff @(negedge delay_li)
  begin
    file_name = $sformatf("%s_%x.trace", npc_trace_file_p, mhartid_i);
    file      = $fopen(file_name, "w");
  end

always_ff @(negedge clk_i)
  begin
    if (npc_w_v)
      $fwrite(file, "[%t] %x\n", $time, npc_r);
    if (fe_cmd_v & (fe_cmd.opcode == e_op_pc_redirection))
      $fwrite(file, "\tRedirect to %x\n", expected_npc_o);
    if (trap_pkt.rollback)
      $fwrite(file, "\tRollback to %x\n", npc_n);
  end

endmodule

