/**
 * bp_me_nonsynth_lce_tracer.v
 *
 */

`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_lce_tracer
 import bp_common_pkg::*;
 import bp_me_nonsynth_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter string trace_str_p = ""

   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   )
  (input                     clk_i
   , input                   reset_i
   , input                   en_i
   );


  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  localparam lg_sets_lp = `BSG_SAFE_CLOG2(sets_p);
  localparam block_size_in_bytes_lp=(block_width_p/8);
  localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp);
  localparam tag_width_lp = paddr_width_p-lg_sets_lp-block_offset_bits_lp;

  `define REQ  bp_lce.request.req_pump_out
  `define CMD  bp_lce.command.cmd_pump_in
  `define FILL bp_lce.command.fill_pump_out
  `define RESP bp_lce.command.resp_pump_out

  // snoop
  wire bp_bedrock_lce_req_header_s lce_req_header = `REQ.fsm_header_i;
  wire bp_bedrock_lce_cmd_header_s lce_cmd_header = `CMD.fsm_header_o;
  wire bp_bedrock_lce_fill_header_s lce_fill_header = `FILL.fsm_header_i;
  wire bp_bedrock_lce_resp_header_s lce_resp_header = `RESP.fsm_header_i;

  wire [fill_width_p-1:0] lce_req_data = `REQ.fsm_data_i;
  wire [fill_width_p-1:0] lce_cmd_data = `CMD.fsm_data_o;
  wire [fill_width_p-1:0] lce_fill_data = `FILL.fsm_data_i;
  wire [fill_width_p-1:0] lce_resp_data = `RESP.fsm_data_i;

  wire lce_req_ack = `REQ.fsm_ready_then_o & `REQ.fsm_v_i;
  wire lce_cmd_ack = `CMD.fsm_yumi_i & `CMD.fsm_v_o;
  wire lce_fill_ack = `FILL.fsm_ready_then_o & `FILL.fsm_v_i;
  wire lce_resp_ack = `RESP.fsm_ready_then_o & `RESP.fsm_v_i;

  wire lce_req_first = `REQ.fsm_new_o;
  wire lce_cmd_first = `CMD.fsm_new_o;
  wire lce_fill_first = `FILL.fsm_new_o;
  wire lce_resp_first = `RESP.fsm_new_o;

  wire lce_req_has_data = lce_req_stream_mask_gp[lce_req_header.msg_type];
  wire lce_cmd_has_data = lce_cmd_stream_mask_gp[lce_cmd_header.msg_type];
  wire lce_fill_has_data = lce_fill_stream_mask_gp[lce_fill_header.msg_type];
  wire lce_resp_has_data = lce_resp_stream_mask_gp[lce_resp_header.msg_type];

  wire cache_req_init = bp_lce.cache_req_yumi_o;
  wire cache_req_fini = bp_lce.cache_req_last_o;

  wire [lce_id_width_p-1:0] lce_id = bp_lce.lce_id_i;
  wire bp_lce_mode_e lce_mode = bp_lce.lce_mode_i;

  `undef REQ
  `undef CMD
  `undef FILL
  `undef RESP

  // process
  wire uc_req = lce_req_header.msg_type inside {e_bedrock_req_uc_rd, e_bedrock_req_uc_wr};

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, lce_id);

  int latency_cnt;
  int req_pending, cmd_pending, fill_pending, resp_pending;
  always_ff @(posedge clk_i)
    if (is_go)
      begin
        if (lce_req_ack & lce_req_first)
          $fdisplay(file, "%12t |: LCE[%0d] REQ addr[%H] cce[%0d] msg[%b] uc[%b] tag[%H] set[%0d] ne[%b] lru[%0d] size[%b]"
                    , $time, lce_req_header.payload.src_id, lce_req_header.addr, lce_req_header.payload.dst_id, lce_req_header.msg_type
                    , uc_req
                    , lce_req_header.addr[block_offset_bits_lp+lg_sets_lp+:tag_width_lp]
                    , lce_req_header.addr[block_offset_bits_lp+:lg_sets_lp]
                    , lce_req_header.payload.non_exclusive, lce_req_header.payload.lru_way_id
                    , lce_req_header.size
                    );
        if (lce_req_ack & lce_req_has_data)
          $fdisplay(file, "%12t |: LCE[%0d] REQ DATA %H", $time, lce_id, lce_req_data);

        if (lce_cmd_ack & lce_cmd_first)
          $fdisplay(file, "%12t |: LCE[%0d] CMD IN addr[%H] cce[%0d] msg[%b] set[%0d] way[%0d] state[%b] tgt[%0d] tgt_way[%0d] tgt_state[%b] size[%b]"
                    , $time, lce_cmd_header.payload.dst_id, lce_cmd_header.addr, lce_cmd_header.payload.src_id, lce_cmd_header.msg_type.cmd
                    , lce_cmd_header.addr[block_offset_bits_lp+:lg_sets_lp], lce_cmd_header.payload.way_id, lce_cmd_header.payload.state, lce_cmd_header.payload.target
                    , lce_cmd_header.payload.target_way_id
                    , lce_cmd_header.payload.target_state
                    , lce_cmd_header.size
                    );
        if (lce_cmd_ack & lce_cmd_has_data)
          $fdisplay(file, "%12t |: LCE[%0d] CMD DATA %H"
                    , $time, lce_id
                    , lce_cmd_data
                    );

        if (lce_fill_ack & lce_fill_first)
          $fdisplay(file, "%12t |: LCE[%0d] FILL OUT dst[%0d] addr[%H] CCE[%0d] msg[%b] set[%0d] way[%0d] state[%b] size[%b]"
                    , $time, lce_id, lce_fill_header.payload.dst_id, lce_fill_header.addr
                    , lce_fill_header.payload.src_id, lce_fill_header.msg_type.fill
                    , lce_fill_header.addr[block_offset_bits_lp+:lg_sets_lp]
                    , lce_fill_header.payload.way_id, lce_fill_header.payload.state
                    , lce_fill_header.size
                    );
        if (lce_fill_ack & lce_fill_has_data)
          $fdisplay(file, "%12t |: LCE[%0d] FILL OUT DATA %H", $time, lce_id, lce_fill_data);

        if (lce_resp_ack & lce_resp_first)
          $fdisplay(file, "%12t |: LCE[%0d] RESP addr[%H] cce[%0d] msg[%b] set[%0d] size[%b]"
                    , $time, lce_resp_header.payload.src_id, lce_resp_header.addr, lce_resp_header.payload.dst_id, lce_resp_header.msg_type.resp
                    , lce_resp_header.addr[block_offset_bits_lp+:lg_sets_lp]
                    , lce_resp_header.size
                    );
        if (lce_resp_ack & lce_resp_has_data)
          $fdisplay(file, "%12t |: LCE[%0d] RESP DATA %H", $time, lce_id, lce_resp_data);

        if (cache_req_init)
          latency_cnt <= 0;
        else
          latency_cnt <= latency_cnt + 1;

        if (cache_req_fini)
          $fdisplay(file, "%12t |: LCE[%0d] ReqLat: %d", $time, lce_id, latency_cnt);
      end

endmodule
