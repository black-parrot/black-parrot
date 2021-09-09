/**
 *
 * Name:
 *   bp_me_nonsynth_cce_tracer.v
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cce_tracer
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam cce_trace_file_p = "cce"

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam lg_cce_way_groups_lp      = `BSG_SAFE_CLOG2(cce_way_groups_p)

    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_msg_header_width_lp-1:0]        lce_req_header_i
   , input                                          lce_req_header_v_i
   , input                                          lce_req_header_ready_and_i
   , input [dword_width_gp-1:0]                     lce_req_data_i
   , input                                          lce_req_data_v_i
   , input                                          lce_req_data_ready_and_i

   , input [lce_resp_msg_header_width_lp-1:0]       lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , input                                          lce_resp_header_ready_and_i
   , input [dword_width_gp-1:0]                     lce_resp_data_i
   , input                                          lce_resp_data_v_i
   , input                                          lce_resp_data_ready_and_i

   , input [lce_cmd_msg_header_width_lp-1:0]        lce_cmd_header_i
   , input                                          lce_cmd_header_v_i
   , input                                          lce_cmd_header_ready_and_i
   , input [dword_width_gp-1:0]                     lce_cmd_data_i
   , input                                          lce_cmd_data_v_i
   , input                                          lce_cmd_data_ready_and_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [cce_mem_msg_header_width_lp-1:0]        mem_resp_header_i
   , input [dword_width_gp-1:0]                     mem_resp_data_i
   , input                                          mem_resp_v_i
   , input                                          mem_resp_ready_and_i
   , input                                          mem_resp_last_i

   , input [cce_mem_msg_header_width_lp-1:0]        mem_cmd_header_i
   , input [dword_width_gp-1:0]                     mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , input                                          mem_cmd_ready_and_i
   , input                                          mem_cmd_last_i

   , input [cce_id_width_p-1:0]                     cce_id_i
  );

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  // LCE-CCE Interface structs
  bp_bedrock_lce_req_msg_header_s  lce_req;
  bp_bedrock_lce_resp_msg_header_s lce_resp;
  bp_bedrock_lce_cmd_msg_header_s  lce_cmd;
  bp_bedrock_lce_req_payload_s     lce_req_payload;
  bp_bedrock_lce_cmd_payload_s     lce_cmd_payload;
  bp_bedrock_lce_resp_payload_s    lce_resp_payload;

  // CCE-MEM Interface structs
  bp_bedrock_cce_mem_msg_header_s  mem_cmd, mem_resp;
  bp_bedrock_cce_mem_payload_s     mem_cmd_payload, mem_resp_payload;

  assign lce_req             = lce_req_header_i;
  assign lce_resp            = lce_resp_header_i;
  assign lce_cmd             = lce_cmd_header_i;
  assign mem_cmd             = mem_cmd_header_i;
  assign mem_resp            = mem_resp_header_i;

  assign lce_req_payload = lce_req.payload;
  assign lce_resp_payload = lce_resp.payload;
  assign lce_cmd_payload = lce_cmd.payload;
  assign mem_resp_payload = mem_resp.payload;
  assign mem_cmd_payload = mem_cmd.payload;

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", cce_trace_file_p, cce_id_i);
    file      = $fopen(file_name, "w");
  end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      // inbound messages
      if (lce_req_header_v_i & lce_req_header_ready_and_i) begin
        if (lce_req.msg_type.req == e_bedrock_req_rd_miss | lce_req.msg_type.req == e_bedrock_req_wr_miss) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wg[%0d] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d]"
                 , $time, lce_req_payload.dst_id, lce_req_payload.src_id, lce_req.addr
                 , lce_req.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , (lce_req.msg_type.req == e_bedrock_req_wr_miss)
                 , lce_req_payload.non_exclusive
                 , 1'b0
                 , lce_req_payload.lru_way_id
                 );
        end
        if (lce_req.msg_type.req == e_bedrock_req_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                 , $time, lce_req_payload.dst_id, lce_req_payload.src_id, lce_req.addr, (lce_req.msg_type.req == e_bedrock_req_uc_wr)
                 , 1'b0
                 , 1'b1
                 , '0, '0
                 );
        end
        if (lce_req.msg_type.req == e_bedrock_req_uc_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                 , $time, lce_req_payload.dst_id, lce_req_payload.src_id, lce_req.addr, (lce_req.msg_type.req == e_bedrock_req_uc_wr)
                 , 1'b0
                 , 1'b1
                 , '0, '0
                 );
        end
      end
      if (lce_req_data_v_i & lce_req_data_ready_and_i) begin
        $fdisplay(file, "[%t]: LCE REQ DATA %H"
                  , $time, lce_req_data_i
                  );
      end
      if (lce_resp_header_v_i & lce_resp_header_ready_and_i) begin
        if ((lce_resp.msg_type.resp == e_bedrock_resp_sync_ack)
            | (lce_resp.msg_type.resp == e_bedrock_resp_inv_ack)
            | (lce_resp.msg_type.resp == e_bedrock_resp_coh_ack)) begin
        $fdisplay(file, "[%t]: CCE[%0d] RESP LCE[%0d] addr[%H] wg[%0d] ack[%4b]"
                 , $time, lce_resp_payload.dst_id, lce_resp_payload.src_id, lce_resp.addr
                 , lce_resp.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_resp.msg_type.resp
                 );
        end
        if ((lce_resp.msg_type.resp == e_bedrock_resp_wb)
            | (lce_resp.msg_type.resp == e_bedrock_resp_null_wb)) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA RESP LCE[%0d] addr[%H] wg[%0d] null_wb[%0b]"
                 , $time, lce_resp_payload.dst_id, lce_resp_payload.src_id, lce_resp.addr
                 , lce_resp.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , (lce_resp.msg_type.resp == e_bedrock_resp_null_wb)
                 );
        end
      end
      if (lce_resp_data_v_i & lce_resp_data_ready_and_i) begin
        $fdisplay(file, "[%t]: LCE RESP DATA %H"
                  , $time, lce_resp_data_i
                  );
      end
      if (mem_resp_v_i & mem_resp_ready_and_i) begin
        if (mem_resp.msg_type.mem == e_bedrock_mem_wr | mem_resp.msg_type.mem == e_bedrock_mem_uc_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM RESP wb[%0b] uc[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d]"
                 , $time, cce_id_i, (mem_resp.msg_type.mem == e_bedrock_mem_wr)
                 , (mem_resp.msg_type.mem == e_bedrock_mem_uc_wr)
                 , mem_resp.addr
                 , mem_resp.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_resp_payload.lce_id, mem_resp_payload.way_id
                 );
        end
        if (mem_resp.msg_type.mem == e_bedrock_mem_rd | mem_resp.msg_type.mem == e_bedrock_mem_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM DATA RESP addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] spec[%0b] uc[%0b] last[%0b] %H"
                 , $time, cce_id_i, mem_resp.addr
                 , mem_resp.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_resp_payload.lce_id, mem_resp_payload.way_id, mem_resp_payload.state
                 , mem_resp_payload.speculative
                 , (mem_resp.msg_type.mem == e_bedrock_mem_uc_rd)
                 , mem_resp_last_i
                 , mem_resp_data_i
                 );
        end
      end
      // outbound messages
      if (lce_cmd_header_v_i & lce_cmd_header_ready_and_i) begin
        if (lce_cmd.msg_type.cmd == e_bedrock_cmd_data) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA CMD LCE[%0d] cmd[%4b] addr[%H] wg[%0d] st[%3b] way[%0d]"
                 , $time, lce_cmd_payload.src_id, lce_cmd_payload.dst_id, lce_cmd.msg_type.cmd, lce_cmd.addr
                 , lce_cmd.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd_payload.state, lce_cmd_payload.way_id
                 );
        end
        else if (lce_cmd.msg_type.cmd == e_bedrock_cmd_uc_data) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA CMD LCE[%0d] cmd[%4b] addr[%H] wg[%0d] st[%3b] way[%0d]"
                 , $time, lce_cmd_payload.src_id, lce_cmd_payload.dst_id, lce_cmd.msg_type.cmd, lce_cmd.addr
                 , lce_cmd.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd_payload.state, lce_cmd_payload.way_id
                 );
        end
        else begin
        $fdisplay(file, "[%t]: CCE[%0d] CMD LCE[%0d] addr[%H] wg[%0d] cmd[%4b] way[%0d] st[%3b] tgt[%0d] tgtWay[%0d] tgtSt[%3b]"
                 , $time, lce_cmd_payload.src_id, lce_cmd_payload.dst_id, lce_cmd.addr
                 , lce_cmd.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd.msg_type.cmd, lce_cmd_payload.way_id
                 , lce_cmd_payload.state, lce_cmd_payload.target, lce_cmd_payload.target_way_id
                 , lce_cmd_payload.target_state
                 );
        end
      end
      if (lce_cmd_data_v_i & lce_cmd_data_ready_and_i) begin
        $fdisplay(file, "[%t]: LCE CMD DATA %H"
                  , $time, lce_cmd_data_i
                  );
      end
      if (mem_cmd_v_i & mem_cmd_ready_and_i) begin
        if (mem_cmd.msg_type.mem == e_bedrock_mem_rd | mem_cmd.msg_type.mem == e_bedrock_mem_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM CMD addr[%H] wg[%0d] lce[%0d] way[%0d] spec[%0b] uc[%0b]"
                 , $time, cce_id_i, mem_cmd.addr
                 , mem_cmd.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_cmd_payload.lce_id
                 , mem_cmd_payload.way_id, mem_cmd_payload.speculative
                 , (mem_cmd.msg_type.mem == e_bedrock_mem_uc_rd)
                 );
        end
        if (mem_cmd.msg_type.mem == e_bedrock_mem_uc_wr | mem_cmd.msg_type.mem == e_bedrock_mem_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM DATA CMD wb[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] uc[%0b] last[%0b] %H"
                 , $time, cce_id_i, (mem_cmd.msg_type.mem == e_bedrock_mem_wr), mem_cmd.addr
                 , mem_cmd.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_cmd_payload.lce_id, mem_cmd_payload.way_id, mem_cmd_payload.state
                 , (mem_cmd.msg_type.mem == e_bedrock_mem_uc_wr)
                 , mem_cmd_last_i
                 , mem_cmd_data_i
                 );
        end
      end
    end // reset & trace
  end // always_ff

endmodule
