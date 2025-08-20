
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_nonsynth_watchdog
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter string trace_str_p = ""
    )
   (input                                     clk_i
    , input                                   reset_i
    , input                                   en_i

    , input [31:0]                            stall_cycles_pi
    , input [31:0]                            halt_instr_pi
    , input [31:0]                            heartbeat_instr_pi
    );

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);

  // snoop
  wire waiting = bp_be_top.director.is_wait;
  wire [core_id_width_p-1:0] mhartid = bp_be_top.cfg_bus_cast_i.core_id;
  wire [vaddr_width_p-1:0] apc_r = bp_be_top.calculator.pipe_sys.csr.apc_r;
  wire [vaddr_width_p-1:0] apc_n = bp_be_top.calculator.pipe_sys.csr.apc_n;
  wire instret = bp_be_top.commit_pkt.instret;
  wire wfi = bp_be_top.commit_pkt.wfi;

  // process
  int cycle_cnt;
  int instr_cnt;
  int stall_cnt;
  int halt_cnt;
  int halted;

  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, mhartid);
  always_ff @(posedge clk_i)
    if (is_go)
      begin
        instr_cnt <= instr_cnt + instret;
        cycle_cnt <= cycle_cnt + 1;

        if (apc_n != apc_r)
          begin
            stall_cnt <= 0;
            halt_cnt <= 0;
          end

        if (!halted && apc_n == apc_r)
          begin
            stall_cnt <= stall_cnt + (!instret && !wfi);
            halt_cnt <= halt_cnt + (instret && !wfi);
          end

        if (!halted && halt_cnt == halt_instr_pi)
          begin
            $display("[BSG-INFO]: Core %x halt detected!", mhartid);
            halted <= 1;
          end
        if (!halted && stall_cnt == stall_cycles_pi)
          begin
            $display("[BSG-FAIL]: Core %x stalled for %d cycles!", mhartid, stall_cnt);
            $finish;
          end
         if (!halted && instr_cnt && !(instr_cnt % heartbeat_instr_pi) && instret)
           begin
             instr_cnt <= 0;
             cycle_cnt <= 0;
             $display("[BSG-INFO]: Core %x (%d/%d) instructions completed in %d cycles (mIPC == %d)", mhartid, heartbeat_instr_pi, instr_cnt, cycle_cnt, instr_cnt * 1000 / cycle_cnt);
           end
      end

  always_ff @(negedge clk_i)
    assert (!is_go || apc_r === 'X || apc_n !== 'X) else
      $error("[BSG-ERROR] Core %x PC has become X! is_go: %b apc_r: %x", mhartid, is_go, apc_r);

endmodule

