// Copyright (c) 2022, University of Washington
// Copyright and related rights are licensed under the BSD 3-Clause
// License (the “License”); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
// https://github.com/black-parrot/black-parrot/LICENSE.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed
// on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language
// governing permissions and limitations under the License.

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

    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_header_v_i
   , input                                          lce_req_header_ready_and_i
   , input [bedrock_data_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_data_v_i
   , input                                          lce_req_data_ready_and_i

   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input                                          lce_resp_header_v_i
   , input                                          lce_resp_header_ready_and_i
   , input [bedrock_data_width_p-1:0]               lce_resp_data_i
   , input                                          lce_resp_data_v_i
   , input                                          lce_resp_data_ready_and_i

   , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
   , input                                          lce_cmd_header_v_i
   , input                                          lce_cmd_header_ready_and_i
   , input [bedrock_data_width_p-1:0]               lce_cmd_data_i
   , input                                          lce_cmd_data_v_i
   , input                                          lce_cmd_data_ready_and_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [mem_header_width_lp-1:0]                mem_resp_header_i
   , input [bedrock_data_width_p-1:0]               mem_resp_data_i
   , input                                          mem_resp_v_i
   , input                                          mem_resp_ready_and_i
   , input                                          mem_resp_last_i

   , input [mem_header_width_lp-1:0]                mem_cmd_header_i
   , input [bedrock_data_width_p-1:0]               mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , input                                          mem_cmd_ready_and_i
   , input                                          mem_cmd_last_i

   , input [cce_id_width_p-1:0]                     cce_id_i
  );

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);

  // LCE-CCE Interface structs
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_i(bp_bedrock_lce_resp_header_s, lce_resp_header);

  // CCE-MEM Interface structs
  `bp_cast_i(bp_bedrock_mem_header_s, mem_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, mem_resp_header);

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
        if (lce_req_header_cast_i.msg_type.req == e_bedrock_req_rd_miss
            | lce_req_header_cast_i.msg_type.req == e_bedrock_req_wr_miss) begin
        $fdisplay(file, "%12t |: CCE[%0d] REQ LCE[%0d] addr[%H] wg[%0d] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d]"
                 , $time, lce_req_header_cast_i.payload.dst_id, lce_req_header_cast_i.payload.src_id
                 , lce_req_header_cast_i.addr
                 , lce_req_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , (lce_req_header_cast_i.msg_type.req == e_bedrock_req_wr_miss)
                 , lce_req_header_cast_i.payload.non_exclusive
                 , 1'b0
                 , lce_req_header_cast_i.payload.lru_way_id
                 );
        end
        if (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_rd) begin
        $fdisplay(file, "%12t |: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                 , $time, lce_req_header_cast_i.payload.dst_id, lce_req_header_cast_i.payload.src_id
                 , lce_req_header_cast_i.addr, (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_wr)
                 , 1'b0
                 , 1'b1
                 , '0, '0
                 );
        end
        if (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_wr) begin
        $fdisplay(file, "%12t |: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                 , $time, lce_req_header_cast_i.payload.dst_id, lce_req_header_cast_i.payload.src_id
                 , lce_req_header_cast_i.addr, (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_wr)
                 , 1'b0
                 , 1'b1
                 , '0, '0
                 );
        end
      end
      if (lce_req_data_v_i & lce_req_data_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE REQ DATA %H"
                  , $time, lce_req_data_i
                  );
      end
      if (lce_resp_header_v_i & lce_resp_header_ready_and_i) begin
        if ((lce_resp_header_cast_i.msg_type.resp == e_bedrock_resp_sync_ack)
            | (lce_resp_header_cast_i.msg_type.resp == e_bedrock_resp_inv_ack)
            | (lce_resp_header_cast_i.msg_type.resp == e_bedrock_resp_coh_ack)) begin
        $fdisplay(file, "%12t |: CCE[%0d] RESP LCE[%0d] addr[%H] wg[%0d] ack[%4b]"
                 , $time, lce_resp_header_cast_i.payload.dst_id, lce_resp_header_cast_i.payload.src_id
                 , lce_resp_header_cast_i.addr
                 , lce_resp_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_resp_header_cast_i.msg_type.resp
                 );
        end
        if ((lce_resp_header_cast_i.msg_type.resp == e_bedrock_resp_wb)
            | (lce_resp_header_cast_i.msg_type.resp == e_bedrock_resp_null_wb)) begin
        $fdisplay(file, "%12t |: CCE[%0d] DATA RESP LCE[%0d] addr[%H] wg[%0d] null_wb[%0b]"
                 , $time, lce_resp_header_cast_i.payload.dst_id, lce_resp_header_cast_i.payload.src_id
                 , lce_resp_header_cast_i.addr
                 , lce_resp_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , (lce_resp_header_cast_i.msg_type.resp == e_bedrock_resp_null_wb)
                 );
        end
      end
      if (lce_resp_data_v_i & lce_resp_data_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE RESP DATA %H"
                  , $time, lce_resp_data_i
                  );
      end
      if (mem_resp_v_i & mem_resp_ready_and_i) begin
        if (mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_wr
            | mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_uc_wr) begin
        $fdisplay(file, "%12t |: CCE[%0d] MEM RESP wb[%0b] uc[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d]"
                 , $time, cce_id_i, (mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_wr)
                 , (mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_uc_wr)
                 , mem_resp_header_cast_i.addr
                 , mem_resp_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_resp_header_cast_i.payload.lce_id, mem_resp_header_cast_i.payload.way_id
                 );
        end
        if (mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_rd
            | mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_uc_rd) begin
        $fdisplay(file, "%12t |: CCE[%0d] MEM DATA RESP addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] spec[%0b] uc[%0b] last[%0b] %H"
                 , $time, cce_id_i, mem_resp_header_cast_i.addr
                 , mem_resp_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_resp_header_cast_i.payload.lce_id, mem_resp_header_cast_i.payload.way_id
                 , mem_resp_header_cast_i.payload.state
                 , mem_resp_header_cast_i.payload.speculative
                 , (mem_resp_header_cast_i.msg_type.mem == e_bedrock_mem_uc_rd)
                 , mem_resp_last_i
                 , mem_resp_data_i
                 );
        end
      end
      // outbound messages
      if (lce_cmd_header_v_i & lce_cmd_header_ready_and_i) begin
        $fdisplay(file, "%12t |: CCE[%0d] CMD LCE[%0d] addr[%H] wg[%0d] cmd[%4b] way[%0d] state[%3b] tgt[%0d] tgtWay[%0d] tgtSt[%3b]"
                 , $time, lce_cmd_header_cast_i.payload.src_id, lce_cmd_header_cast_i.payload.dst_id
                 , lce_cmd_header_cast_i.addr
                 , lce_cmd_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd_header_cast_i.msg_type.cmd, lce_cmd_header_cast_i.payload.way_id
                 , lce_cmd_header_cast_i.payload.state, lce_cmd_header_cast_i.payload.target
                 , lce_cmd_header_cast_i.payload.target_way_id
                 , lce_cmd_header_cast_i.payload.target_state
                 );
      end
      if (lce_cmd_data_v_i & lce_cmd_data_ready_and_i) begin
        $fdisplay(file, "%12t |: LCE CMD DATA %H"
                  , $time, lce_cmd_data_i
                  );
      end
      if (mem_cmd_v_i & mem_cmd_ready_and_i) begin
        if (mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_rd
            | mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_uc_rd) begin
        $fdisplay(file, "%12t |: CCE[%0d] MEM CMD addr[%H] wg[%0d] lce[%0d] way[%0d] spec[%0b] uc[%0b]"
                 , $time, cce_id_i, mem_cmd_header_cast_i.addr
                 , mem_cmd_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_cmd_header_cast_i.payload.lce_id
                 , mem_cmd_header_cast_i.payload.way_id, mem_cmd_header_cast_i.payload.speculative
                 , (mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_uc_rd)
                 );
        end
        if (mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_uc_wr
            | mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_wr) begin
        $fdisplay(file, "%12t |: CCE[%0d] MEM DATA CMD wb[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] uc[%0b] last[%0b] %H"
                 , $time, cce_id_i, (mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_wr)
                 , mem_cmd_header_cast_i.addr
                 , mem_cmd_header_cast_i.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_cmd_header_cast_i.payload.lce_id, mem_cmd_header_cast_i.payload.way_id
                 , mem_cmd_header_cast_i.payload.state
                 , (mem_cmd_header_cast_i.msg_type.mem == e_bedrock_mem_uc_wr)
                 , mem_cmd_last_i
                 , mem_cmd_data_i
                 );
        end
      end
    end // reset & trace
  end // always_ff

endmodule
