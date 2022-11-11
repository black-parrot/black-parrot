/**
 *
 * Name:
 *   bp_me_nonsynth_cce_pending_tracer.sv
 *
 * Description:
 *   CCE pending bit tracer
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cce_pending_tracer
  import bp_common_pkg::*;
  #(parameter `BSG_INV_PARAM(num_way_groups_p)
    , parameter `BSG_INV_PARAM(cce_id_width_p)
    , parameter `BSG_INV_PARAM(paddr_width_p)

    // Default parameters
    , parameter width_p = 3  // pending bit counter width

    , parameter cce_pending_trace_file_p = "cce_pending"

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)
  )
  (input                                                          clk_i
   , input                                                        reset_i
   , input [cce_id_width_p-1:0]                                   cce_id_i
   , input [num_way_groups_p-1:0][width_p-1:0]                    pending_bits_i
   , input                                                        w_v_i
   , input [lg_num_way_groups_lp-1:0]                             w_wg_i
   , input [paddr_width_p-1:0]                                    w_addr_i
   , input                                                        pending_i
   , input                                                        clear_i
  );

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", cce_pending_trace_file_p, cce_id_i);
    file      = $fopen(file_name, "w");
  end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (w_v_i) begin
        if (clear_i) begin
          $fdisplay(file, "%12t |: CCE[%0d] addr[%H] wg[%d] clear"
                    , $time, cce_id_i, w_addr_i, w_wg_i
                    );
        end
        else if (pending_i) begin
          $fdisplay(file, "%12t |: CCE[%0d] addr[%H] wg[%d] incr := %0d"
                    , $time, cce_id_i, w_addr_i, w_wg_i, pending_bits_i[w_wg_i] + 'd1
                    );
        end
        else if (~pending_i) begin
          $fdisplay(file, "%12t |: CCE[%0d] addr[%H] wg[%d] decr := %0d"
                    , $time, cce_id_i, w_addr_i, w_wg_i, pending_bits_i[w_wg_i] - 'd1
                    );
        end
      end
    end // reset
  end // always_ff

endmodule
