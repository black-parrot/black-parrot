/**
 *
 * Name:
 *   bp_cce_msg_cached.v
 *
 * Description:
 *   This module handles sending and receiving of all messages in normal operation mode.
 *
 *   Processing of a Memory Data Response takes priority over processing of any other memory
 *   messages being sent or received. This arbitration is handled by the instruction decoder.
 *
 */

module bp_cce_msg_cached
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_p                  = "inv"
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam num_way_groups_lp         = (lce_sets_p/num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam way_group_offset_high_lp  = (lg_block_size_in_bytes_lp+lg_lce_sets_lp)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  )
  (input                                               clk_i
   , input                                             reset_i

   , input [lg_num_cce_lp-1:0]                         cce_id_i
   , input bp_cce_mode_e                               cce_mode_i

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)
   , input [lce_cce_req_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [lce_cce_resp_width_lp-1:0]                 lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   , output logic [lce_cmd_width_lp-1:0]               lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , input [cce_mem_msg_width_lp-1:0]                  mem_cmd_i
   , input                                             mem_cmd_v_i
   , output logic                                      mem_cmd_yumi_o

   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , output logic [cce_mem_msg_width_lp-1:0]           mem_resp_o
   , output logic                                      mem_resp_v_o
   , input                                             mem_resp_ready_i

   // MSHR
   , input [mshr_width_lp-1:0]                         mshr_i

   // Decoded Instruction
   , input bp_cce_inst_decoded_s                       decoded_inst_i

   // Pending bit write
   , output logic                                      pending_w_v_o
   , output logic [lg_num_way_groups_lp-1:0]           pending_w_way_group_o
   , output logic                                      pending_o

   // arbitration signals to instruction decode
   , output logic                                      pending_w_busy_o
   , output logic                                      lce_cmd_busy_o

   , input [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_i

   , input [num_lce_p-1:0][lg_lce_assoc_lp-1:0]        sharers_ways_i

   , input [dword_width_p-1:0]                         nc_data_i

   , output logic                                      fence_zero_o
  );

  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr;
  assign mshr = mshr_i;

  // Interfaces
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  // structures for casting
  bp_lce_cce_req_s lce_req_li;
  bp_lce_cmd_s lce_cmd;
  bp_lce_cce_resp_s lce_resp;

  bp_cce_mem_msg_s mem_resp_li, mem_resp_lo, mem_cmd_lo, mem_cmd_li;

  // cast output queue messages from structure variables
  assign lce_cmd_o = lce_cmd;
  assign mem_cmd_o = mem_cmd_lo;
  assign mem_resp_o = mem_resp_lo;

  // cast input queue messages to structure variables
  assign mem_resp_li = mem_resp_i;
  assign mem_cmd_li = mem_cmd_i;
  assign lce_resp = lce_resp_i;
  assign lce_req_li = lce_req_i;

  // signals for setting fields in outbound messages
  logic [paddr_width_p-1:0] mem_cmd_addr;
  logic [lg_num_lce_lp-1:0] lce_cmd_lce;
  logic [paddr_width_p-1:0] lce_cmd_addr;
  logic [lg_lce_assoc_lp-1:0] lce_cmd_way;

  // NOTE: num_cce_p must be a power of two
  localparam gpr_shift_lp = (num_cce_p == 1) ? 0 : lg_num_cce_lp;
  localparam [paddr_width_p-lg_lce_sets_lp-1:0] lce_cmd_addr_0 =
    (paddr_width_p-lg_lce_sets_lp)'('0);

  logic [lg_lce_sets_lp-1:0] gpr_set;

  // CCE fence counter
  logic fence_inc, fence_dec;
  logic [`BSG_WIDTH(2*num_way_groups_lp)-1:0] fence_cnt;
  assign fence_zero_o = (fence_cnt == '0);
  bsg_counter_up_down
    #(.max_val_p(2*num_way_groups_lp)
      ,.init_val_p('0)
      ,.max_step_p(1)
      )
    fence_counter
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.up_i(fence_inc)
       ,.down_i(fence_dec)
       ,.count_o(fence_cnt)
       );

  // Speculative memory access management
  logic spec_bits_v_lo;
  bp_cce_spec_s spec_bits_lo;

  // Note: currently, all spec commands write the spec bit
  wire spec_v_li = decoded_inst_i.spec_w_v;

  wire squash_v_li = (decoded_inst_i.spec_cmd == e_spec_cmd_squash)
                     || (decoded_inst_i.spec_cmd == e_spec_cmd_clear);
  wire fwd_mod_v_li = (decoded_inst_i.spec_cmd == e_spec_cmd_fwd_mod)
                      || (decoded_inst_i.spec_cmd == e_spec_cmd_clear);
  wire state_v_li = (decoded_inst_i.spec_cmd == e_spec_cmd_fwd_mod)
                    || (decoded_inst_i.spec_cmd == e_spec_cmd_clear);

  bp_cce_spec
    #(.num_way_groups_p(num_way_groups_lp))
    spec_bits
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       // write-port
       ,.w_v_i(decoded_inst_i.spec_w_v)
       ,.w_way_group_i(mshr.paddr[way_group_offset_high_lp-1 -: lg_num_way_groups_lp])
       ,.spec_v_i(spec_v_li)
       ,.spec_i(decoded_inst_i.spec_bits.spec)
       ,.squash_v_i(squash_v_li)
       ,.squash_i(decoded_inst_i.spec_bits.squash)
       ,.fwd_mod_v_i(fwd_mod_v_li)
       ,.fwd_mod_i(decoded_inst_i.spec_bits.fwd_mod)
       ,.state_v_i(state_v_li)
       ,.state_i(decoded_inst_i.spec_bits.state)

       // read-port
       ,.r_v_i(mem_resp_v_i & mem_resp_li.payload.speculative)
       ,.r_way_group_i(mem_resp_li.addr[way_group_offset_high_lp-1 -: lg_num_way_groups_lp])
       ,.data_o(spec_bits_lo)
       ,.v_o(spec_bits_v_lo)
       );


  // Combination logic
  always_comb begin
    // defaults
    mem_cmd_v_o = '0;
    mem_cmd_lo = '0;
    mem_resp_v_o = '0;
    mem_resp_lo = '0;

    lce_cmd_v_o = '0;
    lce_cmd = '0;

    lce_req_yumi_o = '0;
    lce_resp_yumi_o = '0;
    mem_resp_yumi_o = '0;
    mem_cmd_yumi_o = '0;

    pending_w_v_o = '0;
    pending_w_way_group_o = '0;
    pending_o = '0;

    pending_w_busy_o = '0;
    lce_cmd_busy_o = '0;

    fence_inc = '0;
    fence_dec = '0;

    /*
     * Memory Responses
     *
     * Most memory responses are dequeued automatically, without the ucode engine explicitly processing them.
     *
     * LCE Command network feeds to a wormhole router, so command must be held valid until ready_i signal goes high.
     * The pending bit is written in the cycle that ready_i goes high. If the ucode engine tries to write the pending
     * bits in the same cycle, the ucode engine will stall for one cycle.
     */

    if (mem_resp_v_i) begin
      // Speculative access response
      // Note: speculative access is only supported for cached requests
      if (mem_resp_li.payload.speculative) begin
        // TODO: remove assertion
        assert(spec_bits_v_lo) else $error("speculative memory response but spec_bits invalid output");

        if (spec_bits_lo.spec) begin // speculation not resolved yet
          // do nothing, wait for speculation to be resolved
          // Note: this blocks memory responses behind the speculative response from being
          // forwarded. However, the CCE will not move on to a new LCE request until it
          // resolves the speculation for the current request.
        end
        else if (spec_bits_lo.squash) begin // speculation resolved, squash
          // dequeue the command and do nothing with it
          mem_resp_yumi_o = 1'b1;
        end
        else if (spec_bits_lo.fwd_mod) begin // speculation resolved, forward with modified state
          // handshaking
          lce_cmd_v_o = mem_resp_v_i;
          mem_resp_yumi_o = lce_cmd_ready_i;

          // inform ucode decode that this unit is using the LCE Command network
          lce_cmd_busy_o = 1'b1;

          // output command message
          lce_cmd.dst_id = mem_resp_li.payload.lce_id;

          // Data is copied directly from the Mem Data Response
          lce_cmd.msg_type = e_lce_cmd_data;
          lce_cmd.way_id = mem_resp_li.payload.way_id;
          lce_cmd.msg.dt_cmd.data = mem_resp_li.data;
          lce_cmd.msg.dt_cmd.addr = mem_resp_li.addr;
          // modify the coherence state
          lce_cmd.msg.dt_cmd.state = spec_bits_lo.state;

        end
        else begin // speculation resolved, forward unmodified
          // handshaking
          lce_cmd_v_o = mem_resp_v_i;
          mem_resp_yumi_o = lce_cmd_ready_i;

          // inform ucode decode that this unit is using the LCE Command network
          lce_cmd_busy_o = 1'b1;

          // output command message
          lce_cmd.dst_id = mem_resp_li.payload.lce_id;

          // Data is copied directly from the Mem Data Response
          lce_cmd.msg_type = e_lce_cmd_data;
          lce_cmd.way_id = mem_resp_li.payload.way_id;
          lce_cmd.msg.dt_cmd.data = mem_resp_li.data;
          lce_cmd.msg.dt_cmd.addr = mem_resp_li.addr;
          lce_cmd.msg.dt_cmd.state = mem_resp_li.payload.state;

        end

        // Clear the pending bit in the cycle that the message is dequeued from mem_resp,
        // which is same cycle that the LCE command is sent
        // Pending bit only cleared if this is a cached request response
        if (mem_resp_yumi_o) begin
          pending_w_v_o = 1'b1;
          pending_w_way_group_o =
            mem_resp_li.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
          pending_o = 1'b0;
          // TODO: only blocking on cycle that message sends because Mem Cmd are sent to a full width buffer, so it only
          // takes a single cycle to send Mem Cmd.
          // If mem_cmd is sent directly to a wormhole router (i.e., the output buffers are removed, the arbitration logic
          // for pending bits needs to be reworked. Would it be safe to have one or more cycle gap between flits in a WH routed
          // message?
          pending_w_busy_o = 1'b1;
        end

      end // speculative response

      // Memory Response with cached data
      else if ((mem_resp_li.msg_type.cce_mem_cmd == e_cce_mem_rd)
               | (mem_resp_li.msg_type.cce_mem_cmd == e_cce_mem_wr)) begin

        // handshaking
        lce_cmd_v_o = mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy_o = 1'b1;

        // output command message
        lce_cmd.dst_id = mem_resp_li.payload.lce_id;

        // Data is copied directly from the Mem Data Response
        lce_cmd.msg_type = e_lce_cmd_data;
        lce_cmd.way_id = mem_resp_li.payload.way_id;
        lce_cmd.msg.dt_cmd.data = mem_resp_li.data;
        lce_cmd.msg.dt_cmd.addr = mem_resp_li.addr;
        lce_cmd.msg.dt_cmd.state = mem_resp_li.payload.state;

        // Clear the pending bit in the cycle that the LCE Command ready_i goes high
        // Pending bit only cleared if this is a cached request response
        if (lce_cmd_ready_i) begin
          pending_w_v_o = 1'b1;
          pending_w_way_group_o =
            mem_resp_li.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
          pending_o = 1'b0;
          // TODO: only blocking on cycle that message sends because Mem Cmd are sent to a full width buffer, so it only
          // takes a single cycle to send Mem Cmd.
          // If mem_cmd is sent directly to a wormhole router (i.e., the output buffers are removed, the arbitration logic
          // for pending bits needs to be reworked. Would it be safe to have one or more cycle gap between flits in a WH routed
          // message?
          pending_w_busy_o = 1'b1;
        end

      end // cached block fetch (read- or write-miss)

      // Uncached load response - forward data to LCE
      // This transaction does not modify the pending bits
      else if (mem_resp_li.msg_type.cce_mem_cmd == e_cce_mem_uc_rd) begin

        // handshaking
        lce_cmd_v_o = mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy_o = 1'b1;

        // output command message

        lce_cmd.dst_id = mem_resp_li.payload.lce_id;

        // Data is copied directly from the Mem Data Response
        // For uncached responses, only the least significant 64-bits will be valid
        lce_cmd.msg_type = e_lce_cmd_uc_data;
        lce_cmd.way_id = '0;
        lce_cmd.msg.dt_cmd.data[0+:dword_width_p] = mem_resp_li.data[0+:dword_width_p];
        lce_cmd.msg.dt_cmd.addr = mem_resp_li.addr;

      end // uncached read response

      // Writeback response - clears the pending bit
      else if (mem_resp_li.msg_type.cce_mem_cmd == e_cce_mem_wb) begin

        mem_resp_yumi_o = 1'b1;
        pending_w_v_o = 1'b1;
        pending_w_way_group_o =
          mem_resp_li.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        pending_o = 1'b0;
        pending_w_busy_o = 1'b1;

      end // writeback

      // Uncached store response - send uncached store done command on LCE Command
      // This transaction does not modify the pending bits
      else if (mem_resp_li.msg_type.cce_mem_cmd == e_cce_mem_uc_wr) begin

        // handshaking
        lce_cmd_v_o = mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy_o = 1'b1;

        // after store response is received, need to send uncached store done command to LCE
        lce_cmd.dst_id = mem_resp_li.payload.lce_id;
        lce_cmd.msg_type = e_lce_cmd_uc_st_done;
        lce_cmd.way_id = '0;

        lce_cmd.msg.cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
        lce_cmd.msg.cmd.addr = mem_resp_li.addr;

      end // uncached store response

      // decrement the fence counter when dequeueing a memory response
      fence_dec = mem_resp_yumi_o;

    end // mem_resp auto-forward

    // automatically dequeue coherence ack and decrement pending bit
    // memory response has priority for using the pending bit write port and will stall
    // the LCE Response if the port is busy
    if (lce_resp_v_i & (lce_resp.msg_type == e_lce_cce_coh_ack) & ~pending_w_busy_o) begin
      lce_resp_yumi_o = 1'b1;
      pending_w_busy_o = 1'b1;
      // clear pending bit
      pending_w_v_o = 1'b1;
      pending_w_way_group_o =
        lce_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
      pending_o = 1'b0;
    end


    /*
     * Microcode message send/receive
     *
     */

    case (decoded_inst_i.mem_cmd_addr_sel)
      e_mem_cmd_addr_r0: mem_cmd_addr = gpr_i[e_gpr_r0][0+:paddr_width_p];
      e_mem_cmd_addr_r1: mem_cmd_addr = gpr_i[e_gpr_r1][0+:paddr_width_p];
      e_mem_cmd_addr_r2: mem_cmd_addr = gpr_i[e_gpr_r2][0+:paddr_width_p];
      e_mem_cmd_addr_r3: mem_cmd_addr = gpr_i[e_gpr_r3][0+:paddr_width_p];
      e_mem_cmd_addr_r4: mem_cmd_addr = gpr_i[e_gpr_r4][0+:paddr_width_p];
      e_mem_cmd_addr_r5: mem_cmd_addr = gpr_i[e_gpr_r5][0+:paddr_width_p];
      e_mem_cmd_addr_r6: mem_cmd_addr = gpr_i[e_gpr_r6][0+:paddr_width_p];
      e_mem_cmd_addr_r7: mem_cmd_addr = gpr_i[e_gpr_r7][0+:paddr_width_p];
      e_mem_cmd_addr_lru_way_addr: mem_cmd_addr = mshr.lru_paddr;
      e_mem_cmd_addr_req_addr: mem_cmd_addr = mshr.paddr;
      default mem_cmd_addr = '0;
    endcase

    gpr_set = '0;
    case (decoded_inst_i.lce_cmd_lce_sel)
      e_lce_cmd_lce_r0: lce_cmd_lce = gpr_i[e_gpr_r0][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r1: lce_cmd_lce = gpr_i[e_gpr_r1][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r2: lce_cmd_lce = gpr_i[e_gpr_r2][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r3: lce_cmd_lce = gpr_i[e_gpr_r3][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r4: lce_cmd_lce = gpr_i[e_gpr_r4][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r5: lce_cmd_lce = gpr_i[e_gpr_r5][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r6: lce_cmd_lce = gpr_i[e_gpr_r6][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_r7: lce_cmd_lce = gpr_i[e_gpr_r7][lg_num_lce_lp-1:0];
      e_lce_cmd_lce_req_lce: lce_cmd_lce = mshr.lce_id;
      e_lce_cmd_lce_tr_lce: lce_cmd_lce = mshr.tr_lce_id;
      e_lce_cmd_lce_0: lce_cmd_lce = '0;
      default: lce_cmd_lce = '0;
    endcase

    case (decoded_inst_i.lce_cmd_addr_sel)
      e_lce_cmd_addr_r0: lce_cmd_addr = gpr_i[e_gpr_r0][0+:paddr_width_p];
      e_lce_cmd_addr_r1: lce_cmd_addr = gpr_i[e_gpr_r1][0+:paddr_width_p];
      e_lce_cmd_addr_r2: lce_cmd_addr = gpr_i[e_gpr_r2][0+:paddr_width_p];
      e_lce_cmd_addr_r3: lce_cmd_addr = gpr_i[e_gpr_r3][0+:paddr_width_p];
      e_lce_cmd_addr_r4: lce_cmd_addr = gpr_i[e_gpr_r4][0+:paddr_width_p];
      e_lce_cmd_addr_r5: lce_cmd_addr = gpr_i[e_gpr_r5][0+:paddr_width_p];
      e_lce_cmd_addr_r6: lce_cmd_addr = gpr_i[e_gpr_r6][0+:paddr_width_p];
      e_lce_cmd_addr_r7: lce_cmd_addr = gpr_i[e_gpr_r7][0+:paddr_width_p];
      e_lce_cmd_addr_req_addr: lce_cmd_addr = mshr.paddr;
      e_lce_cmd_addr_lru_way_addr: lce_cmd_addr = mshr.lru_paddr;
      e_lce_cmd_addr_0: lce_cmd_addr = '0;
      default: lce_cmd_addr = '0;
    endcase

    case (decoded_inst_i.lce_cmd_way_sel)
      e_lce_cmd_way_r0: lce_cmd_way = gpr_i[e_gpr_r0][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r1: lce_cmd_way = gpr_i[e_gpr_r1][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r2: lce_cmd_way = gpr_i[e_gpr_r2][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r3: lce_cmd_way = gpr_i[e_gpr_r3][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r4: lce_cmd_way = gpr_i[e_gpr_r4][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r5: lce_cmd_way = gpr_i[e_gpr_r5][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r6: lce_cmd_way = gpr_i[e_gpr_r6][lg_num_lce_lp-1:0];
      e_lce_cmd_way_r7: lce_cmd_way = gpr_i[e_gpr_r7][lg_num_lce_lp-1:0];
      e_lce_cmd_way_req_addr_way: lce_cmd_way = mshr.way_id;
      e_lce_cmd_way_tr_addr_way: lce_cmd_way = mshr.tr_way_id;
      e_lce_cmd_way_sh_list_r0: lce_cmd_way = sharers_ways_i[gpr_i[e_gpr_r0][lg_num_lce_lp-1:0]];
      e_lce_cmd_way_lru_addr_way: lce_cmd_way = mshr.lru_way_id;
      e_lce_cmd_way_0: lce_cmd_way = '0;
      default: lce_cmd_way = '0;
    endcase

    // Outbound Messages - pushq

    // Mem Command
    // All memory commands arbitrate with use of the pending bits, even though uncached commands
    // don't require use of the bits. This makes arbitration logic a little simpler in the ucode
    // instruction decoder.
    if (decoded_inst_i.mem_cmd_v & ~pending_w_busy_o) begin

      // set some defaults - cached load/store miss request
      mem_cmd_lo.msg_type.cce_mem_cmd = (mshr.flags[e_flag_sel_rqf]) ? e_cce_mem_wr : e_cce_mem_rd;
      mem_cmd_lo.addr = mem_cmd_addr;
      mem_cmd_lo.size = e_mem_size_64;
      mem_cmd_lo.payload.lce_id = mshr.lce_id;
      mem_cmd_lo.payload.way_id = mshr.lru_way_id;
      mem_cmd_lo.payload.state = mshr.next_coh_state;
      mem_cmd_lo.data = '0;

      // set speculative bit if needed
      if (decoded_inst_i.spec_w_v & decoded_inst_i.spec_bits.spec) begin
        mem_cmd_lo.payload.speculative = 1'b1;
      end

      // Uncached request
      if (mshr.flags[e_flag_sel_ucf]) begin
        mem_cmd_v_o = 1'b1;
        // load or store
        if (mshr.flags[e_flag_sel_rqf]) begin
          mem_cmd_lo.msg_type.cce_mem_cmd = e_cce_mem_uc_wr;
          mem_cmd_lo.data = {(cce_block_width_p-dword_width_p)'('0),nc_data_i};
        end else begin
          mem_cmd_lo.msg_type.cce_mem_cmd = e_cce_mem_uc_rd;
        end

        mem_cmd_lo.size =
          (mshr.uc_req_size == e_lce_uc_req_1)
          ? e_mem_size_1
          : (mshr.uc_req_size == e_lce_uc_req_2)
            ? e_mem_size_2
            : (mshr.uc_req_size == e_lce_uc_req_4)
              ? e_mem_size_4
              : e_mem_size_8
          ;

      end // uncached mem_cmd

      // Cached request
      else begin
        mem_cmd_v_o = 1'b1;

        // Writeback command - override default command fields as needed
        if (decoded_inst_i.mem_cmd == e_cce_mem_wb) begin
          mem_cmd_lo.msg_type.cce_mem_cmd = e_cce_mem_wb;
          mem_cmd_lo.data = lce_resp.data;
          mem_cmd_lo.payload.lce_id = lce_resp.src_id;
          mem_cmd_lo.payload.way_id = '0;
        end

        // align mem_cmd address to cache block boundary, since all cached requests are for full
        // blocks
        mem_cmd_lo.addr = (mem_cmd_addr >> lg_block_size_in_bytes_lp) << lg_block_size_in_bytes_lp;

        // write pending bit
        pending_w_v_o = mem_cmd_ready_i;
        pending_w_way_group_o =
          mem_cmd_addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        pending_o = 1'b1;

      end // cached mem_cmd

      // Increment memory fence counter when message sends
      fence_inc = mem_cmd_v_o & mem_cmd_ready_i;

    end // mem_cmd

    // Memory Response
    else if (decoded_inst_i.mem_resp_v) begin
      // TODO: implement pushq memResp with more flexibility
      mem_resp_v_o = 1'b1;
      mem_resp_lo.msg_type = decoded_inst_i.mem_resp;
      // mem_cmd_li stores addr into mshr. This assumes it is still valid.
      mem_resp_lo.addr = mshr.paddr;

    end // mem_resp

    // LCE Command
    else if (decoded_inst_i.lce_cmd_v & ~lce_cmd_busy_o) begin
      lce_cmd_v_o = 1'b1;

      lce_cmd.dst_id = lce_cmd_lce;
      lce_cmd.msg_type = decoded_inst_i.lce_cmd;
      lce_cmd.way_id = lce_cmd_way;

      lce_cmd.msg.cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
      lce_cmd.msg.cmd.addr = lce_cmd_addr;

      lce_cmd.msg.cmd.state = '0;
      lce_cmd.msg.cmd.target = '0;
      lce_cmd.msg.cmd.target_way_id = '0;

      if ((decoded_inst_i.lce_cmd == e_lce_cmd_set_tag)
          | (decoded_inst_i.lce_cmd == e_lce_cmd_set_tag_wakeup)) begin
        lce_cmd.msg.cmd.state = mshr.next_coh_state;
      end
      else if (decoded_inst_i.lce_cmd == e_lce_cmd_transfer) begin
        lce_cmd.msg.cmd.state = mshr.next_coh_state;
        lce_cmd.msg.cmd.target = mshr.lce_id;
        lce_cmd.msg.cmd.target_way_id = mshr.lru_way_id;
      end

    end // lce_cmd

    // Inbound Messages - popq

    // LCE Request
    else if (decoded_inst_i.lce_req_yumi) begin
      if (~pending_w_busy_o) begin
        lce_req_yumi_o = decoded_inst_i.lce_req_yumi;
        // set pending bit if cached request
        if (~(lce_req_li.msg_type == e_lce_req_type_uc_rd
              | lce_req_li.msg_type == e_lce_req_type_uc_wr)) begin
          pending_w_v_o = 1'b1;
          pending_w_way_group_o =
            lce_req_li.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
          pending_o = 1'b1;
        end
      end
    end
    // LCE Response
    else if (decoded_inst_i.lce_resp_yumi) begin
      if (~pending_w_busy_o) begin
        lce_resp_yumi_o = decoded_inst_i.lce_resp_yumi;
      end
    end
    // Mem Response
    else if (decoded_inst_i.mem_resp_yumi) begin
      if (~pending_w_busy_o) begin
        mem_resp_yumi_o = decoded_inst_i.mem_resp_yumi;
        // decrement the fence counter when dequeueing the memory response
        fence_dec = mem_resp_v_i & mem_resp_yumi_o;
      end
    end
    // Mem Command
    else if (decoded_inst_i.mem_cmd_yumi) begin
      mem_cmd_yumi_o = decoded_inst_i.mem_cmd_yumi;
    end

  end

endmodule
