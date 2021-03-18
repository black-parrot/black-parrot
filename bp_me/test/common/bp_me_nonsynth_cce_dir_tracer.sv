/**
 *
 * Name:
 *   bp_me_nonsynth_cce_dir_tracer
 *
 * Description:
 *   Simple directory read/write tracer
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cce_dir_tracer
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam cce_dir_trace_file_p   = "cce_dir"

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam lg_cce_way_groups_lp      = `BSG_SAFE_CLOG2(cce_way_groups_p)

  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input [paddr_width_p-1:0]                                    addr_i
   , input                                                        addr_bypass_i

   , input [lce_id_width_p-1:0]                                   lce_i
   , input [lce_assoc_width_p-1:0]                                way_i
   , input [lce_assoc_width_p-1:0]                                lru_way_i
   , input bp_coh_states_e                                        coh_state_i
   , input bp_cce_inst_opd_gpr_e                                  addr_dst_gpr_i

   , input bp_cce_inst_minor_dir_op_e                             cmd_i
   , input                                                        r_v_i
   , input                                                        w_v_i

   , input                                                        busy_i

   , input                                                        sharers_v_i
   , input [num_lce_p-1:0]                                        sharers_hits_i
   , input [num_lce_p-1:0][lce_assoc_width_p-1:0]                 sharers_ways_i
   , input bp_coh_states_e [num_lce_p-1:0]                        sharers_coh_states_i

   , input                                                        lru_v_i
   , input bp_coh_states_e                                        lru_coh_state_i
   , input [paddr_width_p-1:0]                                    lru_addr_i

   , input                                                        addr_v_i
   , input [paddr_width_p-1:0]                                    addr_o_i
   , input bp_cce_inst_opd_gpr_e                                  addr_dst_gpr_o_i

   , input [cce_id_width_p-1:0]                                   cce_id_i
  );

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", cce_dir_trace_file_p, cce_id_i);
    file      = $fopen(file_name, "w");
  end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      if (r_v_i) begin
        if (cmd_i == e_rdw_op) begin
          $fdisplay(file, "[%t]: CCE[%0d] RDW addr[%H] LCE[%0d] lruWay[%0d]"
                   ,  $time, cce_id_i, addr_i, lce_i, lru_way_i
                   );
        end
        if (cmd_i == e_rde_op) begin
          $fdisplay(file, "[%t]: CCE[%0d] RDE addr[%H] LCE[%0d] way[%0d]"
                   ,  $time, cce_id_i, addr_i, lce_i, way_i
                   );
        end
      end
      if (w_v_i) begin
        if (cmd_i == e_wde_op) begin
          $fdisplay(file, "[%t]: CCE[%0d] WDE addr[%H] LCE[%0d] way[%0d] state[%3b]"
                   ,  $time, cce_id_i, addr_i, lce_i, way_i, coh_state_i
                   );
        end
        if (cmd_i == e_wds_op) begin
          $fdisplay(file, "[%t]: CCE[%0d] WDS addr[%H] LCE[%0d] way[%0d] state[%3b]"
                   ,  $time, cce_id_i, addr_i, lce_i, way_i, coh_state_i
                   );
        end
      end
      if (r_v_i & w_v_i) begin
        $fdisplay(file, "[%t]: CCE[%0d] ERROR: concurrent read and write"
                 ,  $time, cce_id_i
                 );
      end
    end // reset
  end // always_ff

endmodule
