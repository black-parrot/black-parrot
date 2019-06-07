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
  import bp_cce_pkg::*;
  #(parameter num_lce_p                    = "inv"
    , parameter num_cce_p                  = "inv"
    , parameter paddr_width_p              = "inv"
    , parameter lce_assoc_p                = "inv"
    , parameter lce_sets_p                 = "inv"
    , parameter block_size_in_bytes_p      = "inv"
    , parameter lce_req_data_width_p       = "inv"

    // Derived parameters
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam block_size_in_bits_lp     = (block_size_in_bytes_p*8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp              = (paddr_width_p-lg_lce_sets_lp
                                              -lg_block_size_in_bytes_lp)
    , localparam entry_width_lp            = (tag_width_lp+`bp_cce_coh_bits)
    , localparam tag_set_width_lp          = (entry_width_lp*lce_assoc_p)
    , localparam way_group_width_lp        = (tag_set_width_lp*num_lce_p)
    , localparam way_group_offset_high_lp  = (lg_block_size_in_bytes_lp+lg_lce_sets_lp)
    , localparam num_way_groups_lp         = (lce_sets_p/num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam mshr_width_lp=`bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

`declare_bp_me_if_widths(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p, mshr_width_lp)
`declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp)
  )
  (input                                        clk_i
   , input                                      reset_i

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

   , input [lce_cce_data_resp_width_lp-1:0]     lce_data_resp_i
   , input                                      lce_data_resp_v_i
   , input                                      lce_data_resp_yumi_i

   // outbound: ready&valid (from CCE)
   , input [cce_lce_cmd_width_lp-1:0]           lce_cmd_i
   , input                                      lce_cmd_v_i
   , input                                      lce_cmd_ready_i

   , input [lce_data_cmd_width_lp-1:0]          lce_data_cmd_i
   , input                                      lce_data_cmd_v_i
   , input                                      lce_data_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)

   // inbound: valid->yumi (to CCE)
   , input [mem_cce_resp_width_lp-1:0]          mem_resp_i
   , input                                      mem_resp_v_i
   , input                                      mem_resp_yumi_i

   , input [mem_cce_data_resp_width_lp-1:0]     mem_data_resp_i
   , input                                      mem_data_resp_v_i
   , input                                      mem_data_resp_yumi_i

   // outbound: ready&valid (from CCE)
   , input [cce_mem_cmd_width_lp-1:0]           mem_cmd_i
   , input                                      mem_cmd_v_i
   , input                                      mem_cmd_ready_i

   , input [cce_mem_data_cmd_width_lp-1:0]      mem_data_cmd_i
   , input                                      mem_data_cmd_v_i
   , input                                      mem_data_cmd_ready_i

   , input [lg_num_cce_lp-1:0]                  cce_id_i
  );

  // Define structure variables for output queues

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p, mshr_width_lp);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp);

  bp_lce_cce_req_s           lce_req;
  bp_lce_cce_resp_s          lce_resp;
  bp_lce_cce_data_resp_s     lce_data_resp;
  bp_cce_lce_cmd_s           lce_cmd;
  bp_lce_data_cmd_s          lce_data_cmd;

  bp_cce_mem_cmd_s           mem_cmd;
  bp_cce_mem_data_cmd_s      mem_data_cmd;
  bp_mem_cce_resp_s          mem_resp;
  bp_mem_cce_data_resp_s     mem_data_resp;

  assign lce_req             = lce_req_i;
  assign lce_resp            = lce_resp_i;
  assign lce_data_resp       = lce_data_resp_i;
  assign lce_cmd             = lce_cmd_i;
  assign lce_data_cmd        = lce_data_cmd_i;
  assign mem_cmd             = mem_cmd_i;
  assign mem_data_cmd        = mem_data_cmd_i;
  assign mem_resp            = mem_resp_i;
  assign mem_data_resp       = mem_data_resp_i;

  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mem_resp_payload, mem_data_cmd_payload;
  assign mem_resp_payload = mem_resp.payload;
  assign mem_data_cmd_payload = mem_data_cmd.payload;

  // Tracer
  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      // inbound messages
      if (lce_req_v_i & lce_req_yumi_i) begin
        $display("%0T: CCE[%0d] REQ LCE[%0d] addr[%H] wr[%0b] ne[%0b] nc[%0b] lruWay[%0d] lruDirty[%0b] tag[%H] set[%0d]"
                 , $time, cce_id_i, lce_req.src_id, lce_req.addr, lce_req.msg_type, lce_req.non_exclusive
                 , lce_req.non_cacheable, lce_req.lru_way_id, lce_req.lru_dirty
                 , lce_req.addr[(paddr_width_p-1)-:tag_width_lp], lce_req.addr[lg_block_size_in_bytes_lp+:lg_lce_sets_lp]);
      end
      if (lce_resp_v_i & lce_resp_yumi_i) begin
        $display("%0T: CCE[%0d] RESP LCE[%0d] addr[%H] ack[%2b]"
                 , $time, cce_id_i, lce_resp.src_id, lce_resp.addr, lce_resp.msg_type);
      end
      if (lce_data_resp_v_i & lce_data_resp_yumi_i) begin
        $display("%0T: CCE[%0d] DATA RESP LCE[%0d] addr[%H] null_wb[%0b]\n%H"
                 , $time, cce_id_i, lce_data_resp.src_id, lce_data_resp.addr, lce_data_resp.msg_type
                 , lce_data_resp.data);
      end
      if (mem_resp_v_i & mem_resp_yumi_i) begin
        $display("%0T: CCE[%0d] MEM RESP wr[%0b] addr[%H] lce[%0d] way[%0d] req_addr[%H] nc[%0b]"
                 , $time, cce_id_i, mem_resp.msg_type, mem_resp.addr
                 , mem_resp_payload.lce_id, mem_resp_payload.way_id
                 , mem_resp_payload.paddr, mem_resp.non_cacheable);
      end
      if (mem_data_resp_v_i & mem_data_resp_yumi_i) begin
        $display("%0T: CCE[%0d] MEM DATA RESP wr[%0b] addr[%H] lce[%0d] way[%0d] nc[%0b]\n%H"
                 , $time, cce_id_i, mem_data_resp.msg_type, mem_data_resp.addr
                 , mem_data_resp.payload.lce_id, mem_data_resp.payload.way_id
                 , mem_data_resp.non_cacheable, mem_data_resp.data);
      end
      // outbound messages
      if (lce_cmd_v_i & lce_cmd_ready_i) begin
        $display("%0T: CCE[%0d] CMD LCE[%0d] addr[%H] cmd[%3b] way[%0d] st[%2b] tgt[%0d] tgtWay[%0d]"
                 , $time, cce_id_i, lce_cmd.dst_id, lce_cmd.addr, lce_cmd.msg_type, lce_cmd.way_id
                 , lce_cmd.state, lce_cmd.target, lce_cmd.target_way_id);
      end
      if (lce_data_cmd_v_i & lce_data_cmd_ready_i) begin
        $display("%0T: CCE[%0d] DATA CMD LCE[%0d] cmd[%3b] way[%0d]"
                 , $time, cce_id_i, lce_data_cmd.dst_id, lce_data_cmd.msg_type, lce_data_cmd.way_id);
      end
      if (mem_cmd_v_i & mem_cmd_ready_i) begin
        $display("%0T: CCE[%0d] MEM CMD wr[%0b] addr[%H] lce[%0d] way[%0d] nc[%0b]"
                 , $time, cce_id_i, mem_cmd.msg_type, mem_cmd.addr, mem_cmd.payload.lce_id
                 , mem_cmd.payload.way_id, mem_cmd.non_cacheable);
      end
      if (mem_data_cmd_v_i & mem_data_cmd_ready_i) begin
        $display("%0T: CCE[%0d] MEM DATA CMD wr[%0b] addr[%H] lce[%0d] way[%0d] req_addr[%H] nc[%0b]\n%H"
                 , $time, cce_id_i, mem_data_cmd.msg_type, mem_data_cmd.addr
                 , mem_data_cmd_payload.lce_id, mem_data_cmd_payload.way_id
                 , mem_data_cmd_payload.paddr, mem_data_cmd.non_cacheable, mem_data_cmd.data);
      end
    end
  end

endmodule
