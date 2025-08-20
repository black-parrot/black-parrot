// This module dumps a trace in various formats. Because of the differences
//   between simulator capabilities and commands, as well as hierarchical bindings
//   requiring hardcoded paths we use tick defines instead parameters, which are
//   generally preferred.

//`define BSG_NONSYNTH_WAVEFORM_TRACER_ENABLE
//`define BSG_NONSYNTH_WAVEFORM_TRACER_HIER
//`define BSG_NONSYNTH_WAVEFORM_TRACER_STR
//`define BSG_NONSYNTH_WAVEFORM_TRACER_DEPTH
//`define BSG_NONSYNTH_WAVEFORM_TRACER_VPD
//`define BSG_NONSYNTH_WAVEFORM_TRACER_FST
//`define BSG_NONSYNTH_WAVEFORM_TRACER_FSDB

`include "bsg_defines.sv"

module bsg_nonsynth_waveform_tracer
 #(parameter string trace_str_p="bsg_trace")
  (input                clk_i
   , input              reset_i
   , input              en_i
   );

`ifdef BSG_NONSYNTH_WAVEFORM_TRACER_ENABLE
  // Save to local variables to reference in other routines
  `define __BNWT_TRACEFILE   trace_file
  `define __BNWT_HIER        $root.`BSG_NONSYNTH_WAVEFORM_TRACER_HIER
  `define __BNWT_DEPTH       `BSG_NONSYNTH_WAVEFORM_TRACER_DEPTH
  `define __BNWT_TRACE_STR   "%s=`BSG_NONSYNTH_WAVEFORM_TRACER_STR"

  // workaround: xcelium 21.09 cannot handle dynamic naming for trace file name
  //   or dumping in parallel modules
  // instead, use this tcl script (or similar):
  //   database -open dump -shm
  //   probe -create testbench.DUT -depth all -all -shm -database dump
  //   run
  `ifdef BSG_NONSYNTH_WAVEFORM_TRACER_SHM
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPINIT
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPOFF
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPON
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPFINI
  `elsif BSG_NONSYNTH_WAVEFORM_TRACER_FSDB
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPINIT \
      $fsdbDumpfile(`__BNWT_TRACEFILE); \
      $fsdbDumpvars(`__BNWT_DEPTH, `__BNWT_HIER)
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPOFF
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPON
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPFINI
  `elsif BSG_NONSYNTH_WAVEFORM_TRACER_VPD
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPINIT \
      $display("DUMPINIT"); \
      $vcdplusfile(`__BNWT_TRACEFILE); \
      $vcdpluson(`__BNWT_DEPTH, `__BNWT_HIER); \
      $vcdplusflush; \
      $vcdplusoff
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPOFF $vcdplusoff
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPON $vcdpluson(`__BNWT_DEPTH, `__BNWT_HIER)
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPFINI $vcdplusclose(`__BNWT_TRACEFILE)
  `else
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPINIT \
      $dumpfile(`__BNWT_TRACEFILE); \
      $dumpvars(`__BNWT_DEPTH, `__BNWT_HIER); \
      $dumpoff
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPOFF $dumpoff
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPON $dumpon
    `define BSG_NONSYNTH_WAVEFORM_TRACER_DUMPFINI
  `endif

  string trace_file = "";
  initial
    if ($value$plusargs({trace_str_p,"=%s"}, trace_file))
      begin
        $display("BSG-INFO: %m trace enable: %s, intially off...", trace_file);
        `BSG_NONSYNTH_WAVEFORM_TRACER_DUMPINIT;
        `BSG_NONSYNTH_WAVEFORM_TRACER_DUMPON;
      end
    else
      begin
        $display("BSG-WARN: trace enable but +%s not specified", trace_str_p);
      end

  final
    if ($value$plusargs({trace_str_p,"=%s"}, trace_file))
      begin
        $display("BSG-INFO: %m flushing trace: %s", trace_file);
        `BSG_NONSYNTH_WAVEFORM_TRACER_DUMPFINI;
      end

  logic tracing;
  always_ff @(posedge clk_i)
    if (reset_i)
      tracing <= 1'b0;
    else if (en_i & !tracing)
      begin
        $display("BSG-INFO: %m trace begin at time %t", $time);
        `BSG_NONSYNTH_WAVEFORM_TRACER_DUMPON;
        tracing <= 1'b1;
      end
    else if (tracing & !en_i)
      begin
        $display("BSG-INFO: %m trace pause at time %t", $time);
        `BSG_NONSYNTH_WAVEFORM_TRACER_DUMPOFF;
        tracing <= 1'b0;
      end
`else
  // segfault in 5.036
  `ifndef VERILATOR
  initial
    begin
      $display("BSG-INFO: %m instantiated, but BSG_NONSYNTH_WAVEFORM_TRACER_ENABLE=0");
    end
  `endif
`endif

endmodule

