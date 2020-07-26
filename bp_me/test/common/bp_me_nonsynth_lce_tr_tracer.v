/**
 * bp_me_nonsynth_lce_tr_tracer.v
 *
 */

module bp_me_nonsynth_lce_tr_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_unicore_half_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter sets_p = "inv"
    , parameter block_width_p = "inv"

    , localparam lce_trace_file_p = "lce_tr"

    , localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
    , localparam block_size_in_bytes_lp=(block_width_p / 8)
    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam lce_opcode_width_lp=$bits(bp_me_nonsynth_lce_opcode_e)
    , localparam tr_ring_width_lp=`bp_me_nonsynth_lce_tr_pkt_width(paddr_width_p, dword_width_p)

  )
  (
    input                                                   clk_i
    ,input                                                  reset_i
    ,input                                                  freeze_i

    ,input [lce_id_width_p-1:0]                             lce_id_i

    ,input [tr_ring_width_lp-1:0]                           tr_pkt_i
    ,input                                                  tr_pkt_v_i
    ,input                                                  tr_pkt_yumi_i

    ,input [tr_ring_width_lp-1:0]                           tr_pkt_o_i
    ,input                                                  tr_pkt_v_o_i
    ,input                                                  tr_pkt_ready_i
  );

  // Trace Replay Interface
  `declare_bp_me_nonsynth_lce_tr_pkt_s(paddr_width_p, dword_width_p);
  bp_me_nonsynth_lce_tr_pkt_s tr_cmd, tr_resp;
  assign tr_cmd = tr_pkt_i;
  assign tr_resp = tr_pkt_o_i;

  integer file;
  string file_name;

  logic freeze_r;
  always_ff @(posedge clk_i) begin
    freeze_r <= freeze_i;
  end

  always_ff @(negedge clk_i) begin
    if (freeze_r & ~freeze_i) begin
      file_name = $sformatf("%s_%x.trace", lce_trace_file_p, lce_id_i);
      file      = $fopen(file_name, "w");
    end
  end

  time tr_start_t;

  always_ff @(negedge clk_i) begin
    if (reset_i) begin
      tr_start_t <= '0;
    end else begin // ~reset_i
      tr_start_t <= tr_start_t;

      // Trace Replay
      if (tr_pkt_v_i & tr_pkt_yumi_i) begin
        tr_start_t <= $time;
        $fdisplay(file, "[%t]: LCE[%0d] TR cmd op[%b] uc[%b] addr[%H] set[%d] %H"
                  , $time, lce_id_i, tr_cmd.cmd, tr_cmd.uncached, tr_cmd.paddr
                  , tr_cmd.paddr[block_offset_bits_lp +: lg_sets_lp], tr_cmd.data
                  );
      end

      if (tr_pkt_v_o_i & tr_pkt_ready_i) begin
        $fdisplay(file, "[%t]: LCE[%0d] TR resp cmd[%b] uc[%b] addr[%H] set[%d] %H time[%0t]"
                  , $time, lce_id_i, tr_resp.cmd, tr_resp.uncached, tr_resp.paddr
                  , tr_resp.paddr[block_offset_bits_lp +: lg_sets_lp]
                  , tr_resp.data, $time-tr_start_t
                  );

      end

    end // ~reset_i
  end // always_ff

endmodule
