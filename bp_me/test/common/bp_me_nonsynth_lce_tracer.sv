/**
 * bp_me_nonsynth_lce_tracer.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_lce_tracer
  import bp_common_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_unicore_half_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter sets_p = "inv"
    , parameter assoc_p = "inv"
    , parameter block_width_p = "inv"

    , localparam lce_trace_file_p = "lce"

    , localparam block_size_in_bytes_lp=(block_width_p / 8)

    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam lg_assoc_lp=`BSG_SAFE_CLOG2(assoc_p)

    , localparam ptag_width_lp=(paddr_width_p-lg_sets_lp-block_offset_bits_lp)

    , localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    , localparam lce_req_data_width_lp = dword_width_gp

    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
  )
  (
    input                                                   clk_i
    ,input                                                  reset_i

    ,input [lce_id_width_p-1:0]                             lce_id_i

    // LCE-CCE Interface
    ,input [lce_req_msg_width_lp-1:0]                       lce_req_i
    ,input                                                  lce_req_v_i
    ,input                                                  lce_req_ready_i

    ,input [lce_resp_msg_width_lp-1:0]                      lce_resp_i
    ,input                                                  lce_resp_v_i
    ,input                                                  lce_resp_ready_i

    ,input [lce_cmd_msg_width_lp-1:0]                       lce_cmd_i
    ,input                                                  lce_cmd_v_i
    ,input                                                  lce_cmd_yumi_i

    ,input [lce_cmd_msg_width_lp-1:0]                       lce_cmd_o_i
    ,input                                                  lce_cmd_o_v_i
    ,input                                                  lce_cmd_o_ready_i
  );

  // LCE-CCE interface structs
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);

  // Structs for output messages
  bp_bedrock_lce_req_msg_s  lce_req;
  bp_bedrock_lce_resp_msg_s lce_resp;
  bp_bedrock_lce_cmd_msg_s  lce_cmd, lce_cmd_lo;
  bp_bedrock_lce_req_payload_s  lce_req_payload;
  bp_bedrock_lce_resp_payload_s lce_resp_payload;
  bp_bedrock_lce_cmd_payload_s  lce_cmd_payload, lce_cmd_lo_payload;

  assign lce_req = lce_req_i;
  assign lce_resp = lce_resp_i;
  assign lce_cmd = lce_cmd_i;
  assign lce_cmd_lo = lce_cmd_o_i;
  assign lce_req_payload = lce_req.header.payload;
  assign lce_resp_payload = lce_resp.header.payload;
  assign lce_cmd_payload = lce_cmd.header.payload;
  assign lce_cmd_lo_payload = lce_cmd_lo.header.payload;

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", lce_trace_file_p, lce_id_i);
    file      = $fopen(file_name, "w");
  end

  always_ff @(posedge clk_i) begin
    if (~reset_i) begin

      // LCE-CCE Interface

      // request to CCE
      if (lce_req_v_i & lce_req_ready_i) begin
        assert(lce_req_payload.src_id == lce_id_i) else $error("Bad LCE Request - source mismatch");
        $fdisplay(file, "[%t]: LCE[%0d] REQ addr[%H] cce[%0d] msg[%b] ne[%b] lru[%0d] size[%b] %H"
                  , $time, lce_req_payload.src_id, lce_req.header.addr, lce_req_payload.dst_id, lce_req.header.msg_type
                  , lce_req_payload.non_exclusive, lce_req_payload.lru_way_id
                  , lce_req.header.size, lce_req.data
                  );
      end

      // response to CCE
      if (lce_resp_v_i & lce_resp_ready_i) begin
        assert(lce_resp_payload.src_id == lce_id_i) else $error("Bad LCE Response - source mismatch");
        $fdisplay(file, "[%t]: LCE[%0d] RESP addr[%H] cce[%0d] msg[%b] len[%b] %H"
                  , $time, lce_resp_payload.src_id, lce_resp.header.addr, lce_resp_payload.dst_id, lce_resp.header.msg_type
                  , lce_resp.header.size, lce_resp.data
                  );
      end

      // command to LCE
      if (lce_cmd_v_i & lce_cmd_yumi_i) begin
        assert(lce_cmd_payload.dst_id == lce_id_i) else $error("Bad LCE Command - destination mismatch");
        $fdisplay(file, "[%t]: LCE[%0d] CMD IN addr[%H] cce[%0d] msg[%b] set[%0d] way[%0d] state[%b] tgt[%0d] tgt_way[%0d] len[%b] %H"
                  , $time, lce_cmd_payload.dst_id, lce_cmd.header.addr, lce_cmd_payload.src_id, lce_cmd.header.msg_type
                  , lce_cmd.header.addr[block_offset_bits_lp+:lg_sets_lp], lce_cmd_payload.way_id, lce_cmd_payload.state, lce_cmd_payload.target
                  , lce_cmd_payload.target_way_id, lce_cmd.header.size, lce_cmd.data
                  );
      end

      // command from LCE
      if (lce_cmd_o_v_i & lce_cmd_o_ready_i) begin
        $fdisplay(file, "[%t]: LCE[%0d] CMD OUT dst[%0d] addr[%H] CCE[%0d] msg[%b] way[%0d] state[%b] tgt[%0d] tgt_way[%0d] len[%b] %H"
                  , $time, lce_id_i, lce_cmd_lo_payload.dst_id, lce_cmd_lo.header.addr, lce_cmd_lo_payload.src_id, lce_cmd_lo.header.msg_type
                  , lce_cmd_lo_payload.way_id, lce_cmd_lo_payload.state, lce_cmd_lo_payload.target, lce_cmd_lo_payload.target_way_id
                  , lce_cmd_lo.header.size, lce_cmd_lo.data
                  );
      end

    end // ~reset_i
  end // always_ff

endmodule
