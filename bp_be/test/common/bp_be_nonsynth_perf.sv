
`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_nonsynth_perf
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_common_if_widths(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)

   , parameter string trace_str_p = ""
   )
  (input clk_i
   , input reset_i
   , input en_i

   // we pass these as input instead of parameter because of verilator limitation
   // %Error: testbench.sv:201:58: Parameter-resolved constants must not use
   //   dotted references: 'max_instr_p'
   , input [31:0] warmup_instr_pi
   , input [31:0] max_instr_pi
   , input [31:0] max_cycle_pi
   );

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);

  // snoop
  wire [core_id_width_p-1:0] mhartid = bp_be_csr.mhartid_lo;
  wire is_debug_mode = bp_be_csr.is_debug_mode;
  wire instret = bp_be_csr.commit_pkt_cast_o.instret;

  // process

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, mhartid);

  int cycle_cnt;
  int instr_cnt;
  int warm = !warmup_instr_pi;
  always_ff @(posedge clk_i)
    if (is_go)
      begin
        if (!warm && instr_cnt == warmup_instr_pi)
          begin
            $display("[BSG-INFO]: %m warmed up (%0d)", warmup_instr_pi);
            warm <= 1;
            instr_cnt <= 0;
          end

        if (warm && instr_cnt == max_instr_pi)
          begin
            $display("[BSG-INFO]: max instructions reached (%0d), terminating...", max_instr_pi);
            $finish;
          end

        if (warm && cycle_cnt == max_cycle_pi)
          begin
            $display("[BSG-INFO]: max cycles reached (%0d), terminating...", max_cycle_pi);
            $finish;
          end

        cycle_cnt <= cycle_cnt + warm;
        instr_cnt <= instr_cnt + instret;
      end

  final
    begin
      $fdisplay(file, "[BSG-STAT][4]:");
      $fdisplay(file, "[CORE%0x]:", mhartid);
      $fdisplay(file, "\tclk   : %d", cycle_cnt);
      $fdisplay(file, "\tinstr : %d", instr_cnt);
      $fdisplay(file, "\tmIPC  : %d", instr_cnt * 1000 / cycle_cnt);
    end

endmodule

