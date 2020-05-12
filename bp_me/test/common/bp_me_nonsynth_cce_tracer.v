/**
 *
 * Name:
 *   bp_me_nonsynth_cce_tracer.v
 *
 * Description:
 *
 */

module bp_me_nonsynth_cce_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam cce_trace_file_p = "cce"

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam lg_cce_way_groups_lp      = `BSG_SAFE_CLOG2(cce_way_groups_p)

    `declare_bp_lce_cce_if_header_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  )
  (input                                        clk_i
   , input                                      reset_i
   , input                                      freeze_i

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)

   // inbound: valid->yumi (to CCE)
   , input [lce_cce_req_width_lp-1:0]           lce_req_i
   , input                                      lce_req_v_i
   , input                                      lce_req_yumi_i

   , input [lce_cce_resp_width_lp-1:0]          lce_resp_i
   , input                                      lce_resp_v_i
   , input                                      lce_resp_yumi_i

   // outbound: ready&valid (from CCE)
   , input [lce_cmd_width_lp-1:0]               lce_cmd_i
   , input                                      lce_cmd_v_i
   , input                                      lce_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)

   // inbound: valid->yumi (to CCE)
   , input [cce_mem_msg_width_lp-1:0]           mem_resp_i
   , input                                      mem_resp_v_i
   , input                                      mem_resp_yumi_i

   // outbound: ready&valid (from CCE)
   , input [cce_mem_msg_width_lp-1:0]           mem_cmd_i
   , input                                      mem_cmd_v_i
   , input                                      mem_cmd_ready_i

   , input [cce_id_width_p-1:0]                 cce_id_i
  );

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s           lce_req;
  bp_lce_cce_resp_s          lce_resp;
  bp_lce_cmd_s               lce_cmd;

  bp_cce_mem_msg_s           mem_cmd, mem_resp;

  assign lce_req             = lce_req_i;
  assign lce_resp            = lce_resp_i;
  assign lce_cmd             = lce_cmd_i;
  assign mem_cmd             = mem_cmd_i;
  assign mem_resp            = mem_resp_i;

  integer file;
  string file_name;

  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
    begin
      file_name = $sformatf("%s_%x.trace", cce_trace_file_p, cce_id_i);
      file      = $fopen(file_name, "w");
    end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      // inbound messages
      if (lce_req_v_i & lce_req_yumi_i) begin
        if (lce_req.header.msg_type == e_lce_req_type_rd | lce_req.header.msg_type == e_lce_req_type_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wg[%0d] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d]"
                 , $time, cce_id_i, lce_req.header.src_id, lce_req.header.addr
                 , lce_req.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , (lce_req.header.msg_type == e_lce_req_type_wr)
                 , lce_req.header.non_exclusive
                 , 1'b0
                 , lce_req.header.lru_way_id
                 );
        end
        if (lce_req.header.msg_type == e_lce_req_type_uc_rd | lce_req.header.msg_type == e_lce_req_type_uc_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b]"
                 , $time, cce_id_i, lce_req.header.src_id, lce_req.header.addr, (lce_req.header.msg_type == e_lce_req_type_uc_wr)
                 , 1'b0
                 , 1'b1
                 , '0, '0
                 );
        end
      end
      if (lce_resp_v_i & lce_resp_yumi_i) begin
        if ((lce_resp.header.msg_type == e_lce_cce_sync_ack)
            | (lce_resp.header.msg_type == e_lce_cce_inv_ack)
            | (lce_resp.header.msg_type == e_lce_cce_coh_ack)) begin
        $fdisplay(file, "[%t]: CCE[%0d] RESP LCE[%0d] addr[%H] wg[%0d] ack[%4b]"
                 , $time, cce_id_i, lce_resp.header.src_id, lce_resp.header.addr
                 , lce_resp.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_resp.header.msg_type);
        end
        if ((lce_resp.header.msg_type == e_lce_cce_resp_wb)
            | (lce_resp.header.msg_type == e_lce_cce_resp_null_wb)) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA RESP LCE[%0d] addr[%H] wg[%0d] null_wb[%0b] %H"
                 , $time, cce_id_i, lce_resp.header.src_id, lce_resp.header.addr
                 , lce_resp.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , (lce_resp.header.msg_type == e_lce_cce_resp_null_wb)
                 , lce_resp.data);
        end
      end
      if (mem_resp_v_i & mem_resp_yumi_i) begin
        if (mem_resp.header.msg_type == e_cce_mem_wr | mem_resp.header.msg_type == e_cce_mem_uc_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM RESP wb[%0b] uc[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d]"
                 , $time, cce_id_i, (mem_resp.header.msg_type == e_cce_mem_wr)
                 , (mem_resp.header.msg_type == e_cce_mem_uc_wr)
                 , mem_resp.header.addr
                 , mem_resp.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_resp.header.payload.lce_id, mem_resp.header.payload.way_id);
        end
        if (mem_resp.header.msg_type == e_cce_mem_rd | mem_resp.header.msg_type == e_cce_mem_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM DATA RESP addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] spec[%0b] uc[%0b] %H"
                 , $time, cce_id_i, mem_resp.header.addr
                 , mem_resp.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_resp.header.payload.lce_id, mem_resp.header.payload.way_id, mem_resp.header.payload.state
                 , mem_resp.header.payload.speculative
                 , (mem_resp.header.msg_type == e_cce_mem_uc_rd), mem_resp.data);
        end
      end
      // outbound messages
      if (lce_cmd_v_i & lce_cmd_ready_i) begin
        if (lce_cmd.header.msg_type == e_lce_cmd_data) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA CMD LCE[%0d] cmd[%4b] addr[%H] wg[%0d] st[%3b] way[%0d] %H"
                 , $time, cce_id_i, lce_cmd.header.dst_id, lce_cmd.header.msg_type, lce_cmd.header.addr
                 , lce_cmd.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd.header.state, lce_cmd.header.way_id
                 , lce_cmd.data
                 );
        end
        else if (lce_cmd.header.msg_type == e_lce_cmd_uc_data) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA CMD LCE[%0d] cmd[%4b] addr[%H] wg[%0d] st[%3b] way[%0d] %H"
                 , $time, cce_id_i, lce_cmd.header.dst_id, lce_cmd.header.msg_type, lce_cmd.header.addr
                 , lce_cmd.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd.header.state, lce_cmd.header.way_id
                 , lce_cmd.data
                 );
        end

        else begin
        $fdisplay(file, "[%t]: CCE[%0d] CMD LCE[%0d] addr[%H] wg[%0d] cmd[%4b] way[%0d] st[%3b] tgt[%0d] tgtWay[%0d]"
                 , $time, cce_id_i, lce_cmd.header.dst_id, lce_cmd.header.addr
                 , lce_cmd.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , lce_cmd.header.msg_type, lce_cmd.header.way_id
                 , lce_cmd.header.state, lce_cmd.header.target, lce_cmd.header.target_way_id
                 );
        end
      end
      if (mem_cmd_v_i & mem_cmd_ready_i) begin
        if (mem_cmd.header.msg_type == e_cce_mem_rd | mem_cmd.header.msg_type == e_cce_mem_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM CMD addr[%H] wg[%0d] lce[%0d] way[%0d] spec[%0b] uc[%0b]"
                 , $time, cce_id_i, mem_cmd.header.addr
                 , mem_cmd.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_cmd.header.payload.lce_id
                 , mem_cmd.header.payload.way_id, mem_cmd.header.payload.speculative
                 , (mem_cmd.header.msg_type == e_cce_mem_uc_rd));
        end
        if (mem_cmd.header.msg_type == e_cce_mem_uc_wr | mem_cmd.header.msg_type == e_cce_mem_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM DATA CMD wb[%0b] addr[%H] wg[%0d] lce[%0d] way[%0d] state[%3b] uc[%0b] %H"
                 , $time, cce_id_i, (mem_cmd.header.msg_type == e_cce_mem_wr), mem_cmd.header.addr
                 , mem_cmd.header.addr[lg_block_size_in_bytes_lp +: lg_cce_way_groups_lp]
                 , mem_cmd.header.payload.lce_id, mem_cmd.header.payload.way_id, mem_cmd.header.payload.state
                 , (mem_cmd.header.msg_type == e_cce_mem_uc_wr), mem_cmd.data);
        end
      end
    end // reset & trace
  end // always_ff

endmodule
