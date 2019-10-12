/**
 * bp_me_nonsynth_lce_tracer.v
 *
 */

module bp_me_nonsynth_lce_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_be_dcache_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_half_core_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter perf_trace_p = 0

    , localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)

`declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
    , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)
  )
  (
    input                                                   clk_i
    ,input                                                  reset_i
    ,input                                                  freeze_i

    ,input [lg_num_lce_lp-1:0]                              lce_id_i

    // Trace Replay Interface
    ,input [tr_ring_width_lp-1:0]                           tr_pkt_i
    ,input                                                  tr_pkt_v_i
    ,input                                                  tr_pkt_yumi_i

    ,input                                                  tr_pkt_v_o_i
    ,input                                                  tr_pkt_ready_i

    // LCE-CCE Interface
    // inbound: valid->ready (a.k.a. valid->yumi), demanding
    // outbound: ready->valid, demanding
    ,input [lce_cce_req_width_lp-1:0]                       lce_req_i
    ,input                                                  lce_req_v_i
    ,input                                                  lce_req_ready_i

    ,input [lce_cmd_width_lp-1:0]                           lce_cmd_i
    ,input                                                  lce_cmd_v_i
    ,input                                                  lce_cmd_ready_i
  );

  // LCE-CCE interface structs
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  // Structs for messages
  bp_lce_cce_req_s lce_req;
  bp_lce_cmd_s     lce_cmd;

  assign lce_req = lce_req_i;
  assign lce_cmd = lce_cmd_i;

  typedef struct packed {
    logic [dcache_opcode_width_lp-1:0] cmd;
    logic [paddr_width_p-1:0]          paddr;
    logic [dword_width_p-1:0]          data;
  } tr_cmd_s;
  tr_cmd_s tr_cmd_pkt;
  assign tr_cmd_pkt = tr_pkt_i;

  logic data_received, tag_received;
  logic [paddr_width_p-1:0] paddr;
  time start_t;
  time tr_start_t;

  always_ff @(negedge clk_i) begin
    if (reset_i) begin
      tag_received <= 1'b0;
      data_received <= 1'b0;
      paddr <= '0;
      start_t <= '0;
      tr_start_t <= '0;
    end else

    // LCE Performance Tracing
    if (perf_trace_p) begin

      // Trace Replay
      if (tr_pkt_v_i & tr_pkt_yumi_i) begin
        tr_start_t <= $time;
        $display("#LCEPERF %0d %0T addr[%H] TR req", lce_id_i, $time, tr_cmd_pkt.paddr);
      end

      if (tr_pkt_v_o_i & tr_pkt_ready_i) begin
        $display("#LCEPERF %0d %0T %0T TR resp", lce_id_i, $time, $time-tr_start_t);
      end

      // LCE-CCE Interface
      if (lce_req_v_i & lce_req_ready_i) begin
        tag_received <= 1'b0;
        data_received <= 1'b0;
        paddr <= lce_req.addr;
        start_t <= $time;
        $display("#LCEPERF %0d %0T addr[%H] LCE req", lce_id_i, $time, lce_req.addr);
      end

      if (lce_cmd_v_i & lce_cmd_ready_i & (lce_cmd.msg_type == e_lce_cmd_set_tag_wakeup)) begin
        $display("#LCEPERF %0d %0T %0T addr[%H] LCE wakeup", lce_id_i, $time, $time-start_t, paddr);
        tag_received <= 1'b0;
        data_received <= 1'b0;
        paddr <= '0;
        start_t <= '0;
      end

      if (lce_cmd_v_i & lce_cmd_ready_i & (lce_cmd.msg_type == e_lce_cmd_set_tag)) begin
        tag_received <= 1'b1;
        if (data_received) begin
          $display("#LCEPERF %0d %0T %0T addr[%H] LCE wakeup", lce_id_i, $time, $time-start_t, paddr);
          tag_received <= 1'b0;
          data_received <= 1'b0;
          paddr <= '0;
          start_t <= '0;
        end
      end

      if (lce_cmd_v_i & lce_cmd_ready_i & (lce_cmd.msg_type == e_lce_cmd_data)) begin
        data_received <= 1'b1;
        if (tag_received) begin
          $display("#LCEPERF %0d %0T %0T addr[%H] LCE wakeup", lce_id_i, $time, $time-start_t, paddr);
          tag_received <= 1'b0;
          data_received <= 1'b0;
          paddr <= '0;
          start_t <= '0;
        end
      end

    end // perf_trace_p

  end // always_ff

endmodule
