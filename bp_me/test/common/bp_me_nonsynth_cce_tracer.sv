/**
 *
 * Name:
 *   bp_me_nonsynth_cce_tracer.v
 *
 * Description:
 *
 */

`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cce_tracer
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter string trace_str_p = ""
   )
  (input                                            clk_i
   , input                                          reset_i
   , input                                          en_i
   );

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  localparam block_size_in_bytes_lp    = bedrock_block_width_p>>3;
  localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp);
  localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p);
  localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp);
  localparam lg_cce_way_groups_lp      = `BSG_SAFE_CLOG2(cce_way_groups_p);

  `define REQ  bp_cce_wrapper.t.cce.req_pump_in
  `define CMD  bp_cce_wrapper.t.cce.cmd_pump_out
  `define RESP bp_cce_wrapper.t.cce.resp_pump_in
  `define FWD  bp_cce_wrapper.t.cce.fwd_pump_out
  `define REV  bp_cce_wrapper.t.cce.rev_pump_in

  // snoop
  wire bp_bedrock_lce_req_header_s lce_req_header = `REQ.fsm_header_o;
  wire bp_bedrock_lce_cmd_header_s lce_cmd_header = `CMD.fsm_header_i;
  wire bp_bedrock_lce_resp_header_s lce_resp_header = `RESP.fsm_header_o;
  wire bp_bedrock_mem_fwd_header_s mem_fwd_header = `FWD.fsm_header_i;
  wire bp_bedrock_mem_rev_header_s mem_rev_header = `REV.fsm_header_o;

  wire [bedrock_fill_width_p-1:0] lce_req_data = `REQ.fsm_data_o;
  wire [bedrock_fill_width_p-1:0] lce_cmd_data = `CMD.fsm_data_i;
  wire [bedrock_fill_width_p-1:0] lce_resp_data = `RESP.fsm_data_o;
  wire [bedrock_fill_width_p-1:0] mem_fwd_data = `FWD.fsm_data_i;
  wire [bedrock_fill_width_p-1:0] mem_rev_data = `REV.fsm_data_o;

  wire lce_req_ack = `REQ.fsm_yumi_i & `REQ.fsm_v_o;
  wire lce_cmd_ack = `CMD.fsm_ready_then_o & `CMD.fsm_v_i;
  wire lce_resp_ack = `REQ.fsm_yumi_i & `REQ.fsm_v_o;
  wire mem_fwd_ack = `FWD.fsm_ready_then_o & `FWD.fsm_v_i;
  wire mem_rev_ack = `REV.fsm_yumi_i & `REV.fsm_v_o;

  wire lce_req_first = `REQ.fsm_new_o;
  wire lce_cmd_first = `CMD.fsm_new_o;
  wire lce_resp_first = `REQ.fsm_new_o;
  wire mem_fwd_first = `FWD.fsm_new_o;
  wire mem_rev_first = `REV.fsm_new_o;

  wire bp_cfg_bus_s cfg_bus = bp_cce_wrapper.cfg_bus_i;
  wire [cce_id_width_p-1:0] cce_id = cfg_bus.cce_id;
  wire bp_cce_mode_e cce_mode = cfg_bus.cce_mode;

  `undef REQ
  `undef CMD
  `undef RESP
  `undef FWD
  `undef REV

  // process
  wire lce_req_miss = lce_req_header.msg_type inside {e_bedrock_req_rd_miss, e_bedrock_req_wr_miss};
  wire lce_req_uc_rd = lce_req_header.msg_type inside {e_bedrock_req_uc_rd};
  wire lce_req_uc_wr = lce_req_header.msg_type inside {e_bedrock_req_uc_wr};

  wire lce_resp_rsp = lce_resp_header.msg_type inside {e_bedrock_resp_sync_ack, e_bedrock_resp_inv_ack, e_bedrock_resp_coh_ack};
  wire lce_resp_wb = lce_resp_header.msg_type inside {e_bedrock_resp_wb, e_bedrock_resp_null_wb};

  wire mem_fwd_rd = mem_fwd_header.msg_type inside {e_bedrock_mem_rd};
  wire mem_fwd_wr = mem_fwd_header.msg_type inside {e_bedrock_mem_wr};
  wire mem_rev_rd = mem_rev_header.msg_type inside {e_bedrock_mem_rd};
  wire mem_rev_wr = mem_rev_header.msg_type inside {e_bedrock_mem_wr};

  wire lce_req_has_data = lce_req_stream_mask_gp[lce_req_header.msg_type];
  wire lce_resp_has_data = lce_resp_stream_mask_gp[lce_resp_header.msg_type];
  wire lce_cmd_has_data = lce_cmd_stream_mask_gp[lce_cmd_header.msg_type];
  wire mem_fwd_has_data = mem_fwd_stream_mask_gp[mem_fwd_header.msg_type];
  wire mem_rev_has_data = mem_rev_stream_mask_gp[mem_rev_header.msg_type];

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, cce_id);

  always_ff @(posedge clk_i)
    if (is_go)
      begin
        if (lce_req_ack & lce_req_first & lce_req_miss)
          $fdisplay(file, "%12t |: CCE[%0d] REQ LCE[%0d] addr[%H] wg[%0d] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d]"
                    , $time, lce_req_header.payload.dst_id, lce_req_header.payload.src_id
                    , lce_req_header.addr
                    , lce_req_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , (lce_req_header.msg_type.req == e_bedrock_req_wr_miss)
                    , lce_req_header.payload.non_exclusive
                    , 1'b0
                    , lce_req_header.payload.lru_way_id
                    );
        if (lce_req_ack & lce_req_first & lce_req_uc_rd)
          $fdisplay(file, "%12t |: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                    , $time, lce_req_header.payload.dst_id, lce_req_header.payload.src_id
                    , lce_req_header.addr, (lce_req_header.msg_type.req == e_bedrock_req_uc_wr)
                    , 1'b0
                    , 1'b1
                    , '0, '0
                    );
        if (lce_req_ack & lce_req_first & lce_req_uc_wr)
          $fdisplay(file, "%12t |: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                    , $time, lce_req_header.payload.dst_id, lce_req_header.payload.src_id
                    , lce_req_header.addr, (lce_req_header.msg_type.req == e_bedrock_req_uc_wr)
                    , 1'b0
                    , 1'b1
                    , '0, '0
                    );
        if (lce_req_ack & lce_req_has_data)
          $fdisplay(file, "%12t |: LCE REQ DATA %H", $time, lce_req_data);

        if (mem_fwd_ack & mem_fwd_first & mem_fwd_rd)
          $fdisplay(file, "%12t |: CCE[%0d] MEM FWD addr[%H] wg[%0d] lce[%0d] way[%0d] spec[%0b]"
                    , $time, cce_id, mem_fwd_header.addr
                    , mem_fwd_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , mem_fwd_header.payload.lce_id
                    , mem_fwd_header.payload.way_id, mem_fwd_header.payload.speculative
                    );
        if (mem_fwd_ack & mem_fwd_first & mem_fwd_wr)
          $fdisplay(file, "%12t |: CCE[%0d] MEM DATA FWD wb[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b]"
                    , $time, cce_id, 1
                    , mem_fwd_header.addr
                    , mem_fwd_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , mem_fwd_header.payload.lce_id, mem_fwd_header.payload.way_id
                    , mem_fwd_header.payload.state
                    );
        if (mem_fwd_ack & mem_fwd_has_data)
          $fdisplay(file, "%12t |: MEM FWD DATA %H", $time, mem_fwd_data);

        if (mem_rev_ack & mem_rev_first & mem_rev_rd)
          $fdisplay(file, "%12t |: CCE[%0d] MEM DATA RESP addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] spec[%0b]"
                    , $time, cce_id, mem_rev_header.addr
                    , mem_rev_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , mem_rev_header.payload.lce_id, mem_rev_header.payload.way_id
                    , mem_rev_header.payload.state
                    , mem_rev_header.payload.speculative
                    );
        if (mem_rev_ack & mem_fwd_first & mem_fwd_wr)
          $fdisplay(file, "%12t |: CCE[%0d] MEM REV wb[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d]"
                    , $time, cce_id, 1
                    , mem_rev_header.addr
                    , mem_rev_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , mem_rev_header.payload.lce_id, mem_rev_header.payload.way_id
                    );
        if (mem_rev_ack & mem_rev_has_data)
          $fdisplay(file, "%12t |: MEM REV DATA %H", $time, mem_rev_data);

        if (lce_cmd_ack & lce_cmd_first)
          $fdisplay(file, "%12t |: CCE[%0d] CMD LCE[%0d] addr[%H] wg[%0d] cmd[%4b] way[%0d] state[%3b] tgt[%0d] tgtWay[%0d] tgtSt[%3b]"
                    , $time, lce_cmd_header.payload.src_id, lce_cmd_header.payload.dst_id
                    , lce_cmd_header.addr
                    , lce_cmd_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , lce_cmd_header.msg_type.cmd, lce_cmd_header.payload.way_id
                    , lce_cmd_header.payload.state, lce_cmd_header.payload.target
                    , lce_cmd_header.payload.target_way_id
                    , lce_cmd_header.payload.target_state
                    );
        if (lce_cmd_ack & lce_cmd_has_data)
          $fdisplay(file, "%12t |: LCE CMD DATA %H", $time, lce_cmd_data);


        if (lce_resp_ack & lce_resp_first & lce_resp_rsp)
          $fdisplay(file, "%12t |: CCE[%0d] RESP LCE[%0d] addr[%H] wg[%0d] ack[%4b]"
                    , $time, lce_resp_header.payload.dst_id, lce_resp_header.payload.src_id
                    , lce_resp_header.addr
                    , lce_resp_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , lce_resp_header.msg_type.resp
                    );
        if (lce_resp_ack & lce_resp_first & lce_resp_wb)
          $fdisplay(file, "%12t |: CCE[%0d] RESP LCE[%0d] addr[%H] wg[%0d] ack[%4b]"
                    , $time, lce_resp_header.payload.dst_id, lce_resp_header.payload.src_id
                    , lce_resp_header.addr
                    , lce_resp_header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                    , lce_resp_header.msg_type.resp
                    );
        if (lce_resp_ack & lce_resp_has_data)
          $fdisplay(file, "%12t |: LCE RESP DATA %H", $time, lce_resp_data);
      end

endmodule
