/**
 * bp_me_nonsynth_lce_tracer.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_lce_tracer
  import bp_common_pkg::*;
  import bp_me_nonsynth_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter `BSG_INV_PARAM(sets_p)
    , parameter `BSG_INV_PARAM(assoc_p)
    , parameter `BSG_INV_PARAM(block_width_p)
    , parameter `BSG_INV_PARAM(fill_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)

    , localparam lce_trace_file_p = "lce"

    , localparam block_size_in_bytes_lp=(block_width_p / 8)

    , localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam lg_sets_lp=`BSG_SAFE_CLOG2(sets_p)
    , localparam lg_assoc_lp=`BSG_SAFE_CLOG2(assoc_p)

    , localparam ptag_width_lp=(paddr_width_p-lg_sets_lp-block_offset_bits_lp)

    , localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p)

    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

    , localparam integer cnt_max_lp = 1<<31
    , localparam cnt_ptr_width_lp = `BSG_SAFE_CLOG2(cnt_max_lp+1)
  )
  (
    input                                                   clk_i
    ,input                                                  reset_i

    ,input [lce_id_width_p-1:0]                             lce_id_i

    // LCE-CCE Interface
    ,input [lce_req_header_width_lp-1:0]                    lce_req_header_i
    ,input [bedrock_fill_width_p-1:0]                       lce_req_data_i
    ,input                                                  lce_req_v_i
    ,input                                                  lce_req_ready_and_i

    ,input [lce_cmd_header_width_lp-1:0]                    lce_cmd_header_i
    ,input [bedrock_fill_width_p-1:0]                       lce_cmd_data_i
    ,input                                                  lce_cmd_v_i
    ,input                                                  lce_cmd_ready_and_i

    ,input [lce_fill_header_width_lp-1:0]                   lce_fill_header_i
    ,input [bedrock_fill_width_p-1:0]                       lce_fill_data_i
    ,input                                                  lce_fill_v_i
    ,input                                                  lce_fill_ready_and_i

    ,input [lce_fill_header_width_lp-1:0]                   lce_fill_o_header_i
    ,input [bedrock_fill_width_p-1:0]                       lce_fill_o_data_i
    ,input                                                  lce_fill_o_v_i
    ,input                                                  lce_fill_o_ready_and_i

    ,input [lce_resp_header_width_lp-1:0]                   lce_resp_header_i
    ,input [bedrock_fill_width_p-1:0]                       lce_resp_data_i
    ,input                                                  lce_resp_v_i
    ,input                                                  lce_resp_ready_and_i

    ,input                                                  cache_req_last_i
  );

  // LCE-CCE interface structs
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_i(bp_bedrock_lce_resp_header_s, lce_resp_header);
  `bp_cast_i(bp_bedrock_lce_fill_header_s, lce_fill_header);
  `bp_cast_i(bp_bedrock_lce_fill_header_s, lce_fill_o_header);

  // Structs for output messages

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", lce_trace_file_p, lce_id_i);
    file      = $fopen(file_name, "w");
  end

  logic cnt_up;
  wire req_cnt_clr = lce_req_v_i & lce_req_ready_and_i;
  logic [cnt_ptr_width_lp-1:0] req_cnt;
  bsg_counter_clear_up
    #(.max_val_p(cnt_max_lp)
      ,.init_val_p('0)
      )
  req_latency_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(req_cnt_clr)
     ,.up_i(cnt_up)
     ,.count_o(req_cnt)
     );

  wire uc_req = lce_req_header_cast_i.msg_type.req inside {e_bedrock_req_uc_rd, e_bedrock_req_uc_wr};

  always_ff @(negedge clk_i) begin
    if (reset_i) begin
      cnt_up <= 1'b0;
    end else begin

      // LCE-CCE Interface

      // request to CCE
      if (lce_req_v_i & lce_req_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] REQ addr[%H] cce[%0d] msg[%b] uc[%b] tag[%H] set[%0d] ne[%b] lru[%0d] size[%b]"
                  , $time, lce_req_header_cast_i.payload.src_id, lce_req_header_cast_i.addr, lce_req_header_cast_i.payload.dst_id, lce_req_header_cast_i.msg_type
                  , uc_req
                  , lce_req_header_cast_i.addr[paddr_width_p-1:(lg_sets_lp+block_offset_bits_lp)]
                  , lce_req_header_cast_i.addr[block_offset_bits_lp+:lg_sets_lp]
                  , lce_req_header_cast_i.payload.non_exclusive, lce_req_header_cast_i.payload.lru_way_id
                  , lce_req_header_cast_i.size
                  );
        cnt_up <= 1'b1;
      end
      if (lce_req_v_i & lce_req_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] REQ DATA %H"
                  , $time, lce_id_i
                  , lce_req_data_i
                  );
      end

      // response to CCE
      if (lce_resp_v_i & lce_resp_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] RESP addr[%H] cce[%0d] msg[%b] set[%0d] size[%b]"
                  , $time, lce_resp_header_cast_i.payload.src_id, lce_resp_header_cast_i.addr, lce_resp_header_cast_i.payload.dst_id, lce_resp_header_cast_i.msg_type.resp
                  , lce_resp_header_cast_i.addr[block_offset_bits_lp+:lg_sets_lp]
                  , lce_resp_header_cast_i.size
                  );
      end
      if (lce_resp_v_i & lce_resp_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] RESP DATA %H"
                  , $time, lce_id_i
                  , lce_resp_data_i
                  );
      end

      // command to LCE
      if (lce_cmd_v_i & lce_cmd_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] CMD IN addr[%H] cce[%0d] msg[%b] set[%0d] way[%0d] state[%b] tgt[%0d] tgt_way[%0d] tgt_state[%b] size[%b]"
                  , $time, lce_cmd_header_cast_i.payload.dst_id, lce_cmd_header_cast_i.addr, lce_cmd_header_cast_i.payload.src_id, lce_cmd_header_cast_i.msg_type.cmd
                  , lce_cmd_header_cast_i.addr[block_offset_bits_lp+:lg_sets_lp], lce_cmd_header_cast_i.payload.way_id, lce_cmd_header_cast_i.payload.state, lce_cmd_header_cast_i.payload.target
                  , lce_cmd_header_cast_i.payload.target_way_id
                  , lce_cmd_header_cast_i.payload.target_state
                  , lce_cmd_header_cast_i.size
                  );
      end
      if (lce_cmd_v_i & lce_cmd_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] CMD DATA %H"
                  , $time, lce_id_i
                  , lce_cmd_data_i
                  );
      end

      // Fill to LCE
      if (lce_fill_v_i & lce_fill_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] FILL IN addr[%H] cce[%0d] msg[%b] set[%0d] way[%0d] state[%b] size[%b]"
                  , $time, lce_fill_header_cast_i.payload.dst_id, lce_fill_header_cast_i.addr
                  , lce_fill_header_cast_i.payload.src_id, lce_fill_header_cast_i.msg_type.fill
                  , lce_fill_header_cast_i.addr[block_offset_bits_lp+:lg_sets_lp]
                  , lce_fill_header_cast_i.payload.way_id, lce_fill_header_cast_i.payload.state
                  , lce_fill_header_cast_i.size
                  );
      end
      if (lce_fill_v_i & lce_fill_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] FILL DATA %H"
                  , $time, lce_id_i
                  , lce_fill_data_i
                  );
      end

      // Fill from LCE
      if (lce_fill_o_v_i & lce_fill_o_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] FILL OUT dst[%0d] addr[%H] CCE[%0d] msg[%b] set[%0d] way[%0d] state[%b] size[%b]"
                  , $time, lce_id_i, lce_fill_o_header_cast_i.payload.dst_id, lce_fill_o_header_cast_i.addr
                  , lce_fill_o_header_cast_i.payload.src_id, lce_fill_o_header_cast_i.msg_type.fill
                  , lce_fill_o_header_cast_i.addr[block_offset_bits_lp+:lg_sets_lp]
                  , lce_fill_o_header_cast_i.payload.way_id, lce_fill_o_header_cast_i.payload.state
                  , lce_fill_o_header_cast_i.size
                  );
      end
      if (lce_fill_o_v_i & lce_fill_o_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE[%0d] FILL OUT DATA %H"
                  , $time, lce_id_i
                  , lce_fill_o_data_i
                  );
      end


      if (cache_req_last_i) begin
        cnt_up <= 1'b0;
        $fdisplay(file, "%12t |: LCE[%0d] ReqLat: %d", $time, lce_id_i, req_cnt);
      end

    end // ~reset_i
  end // always_ff

endmodule
