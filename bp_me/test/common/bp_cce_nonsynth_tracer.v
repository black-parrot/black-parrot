/**
 *
 * Name:
 *   bp_cce_nonsynth_tracer.v
 *
 * Description:
 *
 */

module bp_cce_nonsynth_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam cce_trace_file_p = "cce"

    // Derived parameters
    , localparam block_size_in_bytes_lp      = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp              = (paddr_width_p-lg_lce_sets_lp
                                              -lg_block_size_in_bytes_lp)
    , localparam entry_width_lp            = (tag_width_lp+`bp_coh_bits)
    , localparam tag_set_width_lp          = (entry_width_lp*lce_assoc_p)
    , localparam way_group_width_lp        = (tag_set_width_lp*num_lce_p)
    , localparam way_group_offset_high_lp  = (lg_block_size_in_bytes_lp+lg_lce_sets_lp)
    , localparam num_way_groups_lp         = (lce_sets_p/num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)

`declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
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

   , input [lg_num_cce_lp-1:0]                  cce_id_i
  );

  // Define structure variables for output queues

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s           lce_req;
  bp_lce_cce_req_req_s       lce_req_req;
  bp_lce_cce_req_uc_req_s    lce_req_uc_req;
  bp_lce_cce_resp_s          lce_resp;
  bp_lce_cmd_s               lce_cmd;
  bp_lce_cmd_cmd_s           lce_cmd_cmd;

  bp_cce_mem_msg_s           mem_cmd_lo, mem_resp_li;

  assign lce_req             = lce_req_i;
  assign lce_req_req         = lce_req.msg.req;
  assign lce_req_uc_req      = lce_req.msg.uc_req;
  assign lce_resp            = lce_resp_i;
  assign lce_cmd             = lce_cmd_i;
  assign lce_cmd_cmd         = lce_cmd.msg.cmd;
  assign mem_cmd_lo          = mem_cmd_i;
  assign mem_resp_li         = mem_resp_i;

  integer file;
  string file_name;
 
  logic freeze_r;
  always_ff @(posedge clk_i)
    freeze_r <= freeze_i;

  always_ff @(negedge clk_i)
    if (freeze_r & ~freeze_i)
      begin
        file_name = $sformatf("%s_%x.trace", cce_trace_file_p, cce_id_i);
        file      = $fopen(file_name, "w");
      end

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      // inbound messages
      if (lce_req_v_i & lce_req_yumi_i) begin
        if (lce_req.msg_type == e_lce_req_type_rd | lce_req.msg_type == e_lce_req_type_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b] tag[%H] set[%0d]"
                 , $time, cce_id_i, lce_req.src_id, lce_req.addr, (lce_req.msg_type == e_lce_req_type_wr)
                 , lce_req_req.non_exclusive
                 , 1'b0
                 , lce_req_req.lru_way_id, lce_req_req.lru_dirty
                 , lce_req.addr[(paddr_width_p-1)-:tag_width_lp]
                 , lce_req.addr[lg_block_size_in_bytes_lp+:lg_lce_sets_lp]);
        end
        if (lce_req.msg_type == e_lce_req_type_uc_rd | lce_req.msg_type == e_lce_req_type_uc_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] uc[%0b] lruWay[%0d] lruDirty[%0b] tag[%H] set[%0d]"
                 , $time, cce_id_i, lce_req.src_id, lce_req.addr, (lce_req.msg_type == e_lce_req_type_uc_wr)
                 , 1'b0
                 , 1'b1
                 , '0, '0
                 , lce_req.addr[(paddr_width_p-1)-:tag_width_lp]
                 , lce_req.addr[lg_block_size_in_bytes_lp+:lg_lce_sets_lp]);
        end
      end
      if (lce_resp_v_i & lce_resp_yumi_i) begin
        if ((lce_resp.msg_type == e_lce_cce_sync_ack)
            | (lce_resp.msg_type == e_lce_cce_inv_ack)
            | (lce_resp.msg_type == e_lce_cce_coh_ack)) begin
        $fdisplay(file, "[%t]: CCE[%0d] RESP LCE[%0d] addr[%H] ack[%4b]"
                 , $time, cce_id_i, lce_resp.src_id, lce_resp.addr, lce_resp.msg_type);
        end
        if ((lce_resp.msg_type == e_lce_cce_resp_wb)
            | (lce_resp.msg_type == e_lce_cce_resp_null_wb)) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA RESP LCE[%0d] addr[%H] null_wb[%0b] %H"
                 , $time, cce_id_i, lce_resp.src_id, lce_resp.addr
                 , (lce_resp.msg_type == e_lce_cce_resp_null_wb)
                 , lce_resp.data);
        end
      end
      if (mem_resp_v_i & mem_resp_yumi_i) begin
        if (mem_resp_li.msg_type == e_cce_mem_wb | mem_resp_li.msg_type == e_cce_mem_uc_wr) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM RESP wb[%0b] uc[%0b] addr[%H] lce[%0d] way[%0d]"
                 , $time, cce_id_i, (mem_resp_li.msg_type == e_cce_mem_wb)
                 , (mem_resp_li.msg_type == e_cce_mem_uc_wr)
                 , mem_resp_li.addr
                 , mem_resp_li.payload.lce_id, mem_resp_li.payload.way_id);
        end
        if (mem_resp_li.msg_type == e_cce_mem_rd | mem_resp_li.msg_type == e_cce_mem_wr
            | mem_resp_li.msg_type == e_cce_mem_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM DATA RESP wr[%0b] addr[%H] lce[%0d] way[%0d] state[%3b] spec[%0b] uc[%0b] %H"
                 , $time, cce_id_i, (mem_resp_li.msg_type == e_cce_mem_wr), mem_resp_li.addr
                 , mem_resp_li.payload.lce_id, mem_resp_li.payload.way_id, mem_resp_li.payload.state
                 , mem_resp_li.payload.speculative
                 , (mem_resp_li.msg_type == e_cce_mem_uc_rd), mem_resp_li.data);
        end
      end
      // outbound messages
      if (lce_cmd_v_i & lce_cmd_ready_i) begin
        if (lce_cmd.msg_type == e_lce_cmd_data) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA CMD LCE[%0d] cmd[%4b] addr[%H] st[%3b] way[%0d] %H"
                 , $time, cce_id_i, lce_cmd.dst_id, lce_cmd.msg_type, lce_cmd.msg.dt_cmd.addr
                 , lce_cmd.msg.dt_cmd.state, lce_cmd.way_id
                 , lce_cmd.msg.dt_cmd.data);
        end
        else if (lce_cmd.msg_type == e_lce_cmd_uc_data) begin
        $fdisplay(file, "[%t]: CCE[%0d] DATA CMD LCE[%0d] cmd[%4b] addr[%H] st[%3b] way[%0d] %H"
                 , $time, cce_id_i, lce_cmd.dst_id, lce_cmd.msg_type, lce_cmd.msg.dt_cmd.addr
                 , lce_cmd.msg.dt_cmd.state, lce_cmd.way_id
                 , lce_cmd.msg.dt_cmd.data);
        end

        else begin
        $fdisplay(file, "[%t]: CCE[%0d] CMD LCE[%0d] addr[%H] cmd[%4b] way[%0d] st[%3b] tgt[%0d] tgtWay[%0d]"
                 , $time, cce_id_i, lce_cmd.dst_id, lce_cmd_cmd.addr, lce_cmd.msg_type, lce_cmd.way_id
                 , lce_cmd_cmd.state, lce_cmd_cmd.target, lce_cmd_cmd.target_way_id);
        end
      end
      if (mem_cmd_v_i & mem_cmd_ready_i) begin
        if (mem_cmd_lo.msg_type == e_cce_mem_rd | mem_cmd_lo.msg_type == e_cce_mem_wr
            | mem_cmd_lo.msg_type == e_cce_mem_uc_rd) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM CMD wr[%0b] addr[%H] lce[%0d] way[%0d] spec[%0b] uc[%0b]"
                 , $time, cce_id_i, mem_cmd_lo.msg_type, mem_cmd_lo.addr, mem_cmd_lo.payload.lce_id
                 , mem_cmd_lo.payload.way_id, mem_cmd_lo.payload.speculative
                 , (mem_cmd_lo.msg_type == e_cce_mem_uc_rd));
        end
        if (mem_cmd_lo.msg_type == e_cce_mem_uc_wr | mem_cmd_lo.msg_type == e_cce_mem_wb) begin
        $fdisplay(file, "[%t]: CCE[%0d] MEM DATA CMD wb[%0b] addr[%H] lce[%0d] way[%0d] state[%3b] uc[%0b] %H"
                 , $time, cce_id_i, (mem_cmd_lo.msg_type == e_cce_mem_wb), mem_cmd_lo.addr
                 , mem_cmd_lo.payload.lce_id, mem_cmd_lo.payload.way_id, mem_cmd_lo.payload.state
                 , (mem_cmd_lo.msg_type == e_cce_mem_uc_wr), mem_cmd_lo.data);
        end
      end
    end // reset & trace
  end // always_ff

endmodule
