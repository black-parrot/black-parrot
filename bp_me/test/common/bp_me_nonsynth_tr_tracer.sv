/**
 * bp_me_nonsynth_tr_tracer.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_tr_tracer
  import bp_common_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_test_multicore_half_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter `BSG_INV_PARAM(sets_p)
    , parameter `BSG_INV_PARAM(block_width_p)

    , localparam trace_file_p = "cache_tr"

    , localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p)
    , localparam block_size_in_bytes_lp=(block_width_p / 8)
    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam tag_offset_lp = (sets_p > 1) ? (block_offset_bits_lp+lg_sets_lp) : block_offset_bits_lp

    , localparam tr_pkt_width_lp=`bp_me_nonsynth_tr_pkt_width(paddr_width_p, dword_width_gp)
    , localparam max_cnt_p = 2**16
  )
  (
    input                                                   clk_i
    ,input                                                  reset_i

    ,input [lce_id_width_p-1:0]                             id_i

    ,input [tr_pkt_width_lp-1:0]                            tr_pkt_i
    ,input                                                  tr_pkt_v_i
    ,input                                                  tr_pkt_yumi_i

    ,input [tr_pkt_width_lp-1:0]                            tr_pkt_o_i
    ,input                                                  tr_pkt_v_o_i
    ,input                                                  tr_pkt_ready_then_i
  );

  // Trace Replay Interface
  `declare_bp_me_nonsynth_tr_pkt_s(paddr_width_p, dword_width_gp);
  bp_me_nonsynth_tr_pkt_s tr_cmd, tr_resp;
  assign tr_cmd = tr_pkt_i;
  assign tr_resp = tr_pkt_o_i;

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", trace_file_p, id_i);
    file      = $fopen(file_name, "w");
  end

  logic tr_v;
  bsg_dff_reset_set_clear
    #(.width_p(1))
    tr_valid_reg
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.set_i(tr_pkt_yumi_i)
      ,.clear_i(tr_pkt_v_o_i & tr_pkt_ready_then_i)
      ,.data_o(tr_v)
      );

  logic [`BSG_SAFE_CLOG2(max_cnt_p+1)-1:0] tr_latency;
  bsg_counter_clear_up
    #(.max_val_p(max_cnt_p)
      ,.init_val_p(0)
      )
    latency_counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(tr_pkt_yumi_i)
      ,.up_i(tr_v)
      ,.count_o(tr_latency)
      );

  always_ff @(negedge clk_i) begin
    if (~reset_i) begin // ~reset_i

      // Trace Replay
      if (tr_pkt_v_i & tr_pkt_yumi_i) begin
        $fdisplay(file, "%12t |: TR[%0d] CMD %s op[%b] uc[%b] addr[%H] tag[%H] set[%0d] offset[%0d] %H"
                  , $time, id_i, tr_cmd.cmd.name(), tr_cmd.cmd, tr_cmd.uncached, tr_cmd.paddr
                  , tr_cmd.paddr[paddr_width_p-1:tag_offset_lp]
                  , (sets_p > 1) ? tr_cmd.paddr[block_offset_bits_lp +: lg_sets_lp] : 0
                  , tr_cmd.paddr[0 +: block_offset_bits_lp], tr_cmd.data
                  );
      end

      if (tr_pkt_v_o_i & tr_pkt_ready_then_i) begin
        $fdisplay(file, "%12t |: TR[%0d] RESP %s op[%b] uc[%b] addr[%H] tag[%H] set[%0d] offset[%0d] %H latency[%0d]"
                  , $time, id_i, tr_resp.cmd.name(), tr_resp.cmd, tr_resp.uncached, tr_resp.paddr
                  , tr_resp.paddr[paddr_width_p-1:tag_offset_lp]
                  , (sets_p > 1) ? tr_resp.paddr[block_offset_bits_lp +: lg_sets_lp] : 0
                  , tr_resp.paddr[0 +: block_offset_bits_lp]
                  , tr_resp.data, tr_latency+1
                  );

      end

    end // ~reset_i
  end // always_ff

endmodule
