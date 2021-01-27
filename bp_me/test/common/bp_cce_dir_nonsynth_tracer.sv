/**
 *
 * Name:
 *   bp_cce_dir_nonsynth_tracer.v
 *
 * Description:
 *   TODO: implement directory tracer
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_dir_nonsynth_tracer
  import bp_common_pkg::*;
  #(parameter cce_id_width_p            = "inv"
    , localparam cce_dir_trace_file_p   = "cce_dir"
  )
  (input                                                          clk_i
   , input                                                        reset_i
   , input                                                        freeze_i

   , input [cce_id_width_p-1:0]                                   cce_id_i
  );

  integer file;
  string file_name;

  logic freeze_r;
  always_ff @(posedge clk_i) begin
    freeze_r <= freeze_i;
  end


  always_ff @(negedge clk_i)
    if (freeze_r & ~freeze_i)
      begin
        file_name = $sformatf("%s_%x.trace", cce_dir_trace_file_p, cce_id_i);
        file      = $fopen(file_name, "w");
      end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
    end // reset
  end // always_ff

endmodule
