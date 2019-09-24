/**
 *
 * Name:
 *   bp_cce_msg.v
 *
 * Description:
 *   This module handles sending and receiving of all messages in normal operation mode.
 *
 *   Processing of a Memory Data Response takes priority over processing of any other memory
 *   messages being sent or received. This arbitration is handled by the instruction decoder.
 *
 */

module bp_cce_msg
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter num_lce_p                    = "inv"
    , parameter num_cce_p                  = "inv"
    , parameter paddr_width_p              = "inv"
    , parameter lce_assoc_p                = "inv"
    , parameter lce_sets_p                 = "inv"
    , parameter block_size_in_bytes_p      = "inv"
    , parameter lce_req_data_width_p       = "inv"
    , parameter num_way_groups_p           = "inv"
    , parameter cce_block_width_p          = "inv"
    , parameter dword_width_p              = "inv"

    // Derived parameters
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam block_size_in_bits_lp     = (block_size_in_bytes_p*8)
    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp)
    `declare_bp_me_if_widths(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)

    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam way_group_offset_high_lp  = (lg_block_size_in_bytes_lp+lg_lce_sets_lp)
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
   , input [mem_cce_resp_width_lp-1:0]                 mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , output logic [cce_mem_cmd_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

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
  );

  wire unused = &{clk_i, reset_i};

  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr;
  assign mshr = mshr_i;

  // Interfaces
  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp);

  // structures for casting
  bp_lce_cmd_s lce_cmd;
  bp_lce_cmd_cmd_s lce_cmd_cmd;
  bp_lce_cce_resp_s lce_resp;

  bp_mem_cce_resp_s mem_resp;
  bp_cce_mem_cmd_s mem_cmd;

  // cast output queue messages from structure variables
  assign lce_cmd_o = lce_cmd;
  assign mem_cmd_o = mem_cmd;

  // cast input queue messages to structure variables
  assign mem_resp = mem_resp_i;
  assign lce_resp = lce_resp_i;

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

  always_comb begin
    // defaults
    mem_cmd_v_o = '0;
    mem_cmd = '0;

    lce_cmd_v_o = '0;
    lce_cmd = '0;
    lce_cmd_cmd = '0;

    lce_req_yumi_o = '0;
    lce_resp_yumi_o = '0;
    mem_resp_yumi_o = '0;

    pending_w_v_o = '0;
    pending_w_way_group_o = '0;
    pending_o = '0;

    pending_w_busy_o = '0;
    lce_cmd_busy_o = '0;


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

      // Memory Response with data (cache block or uncached load)
      if ((mem_resp.msg_type == e_cce_mem_rd) | (mem_resp.msg_type == e_cce_mem_wr)
          | (mem_resp.msg_type == e_cce_mem_uc_rd)) begin

        // handshaking
        lce_cmd_v_o = mem_resp_v_i;
        mem_resp_yumi_o = lce_cmd_ready_i;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy_o = 1'b1;

        // output command message

        lce_cmd.dst_id = mem_resp.payload.lce_id;

        // Data is copied directly from the Mem Data Response
        // For uncached responses, only the least significant 64-bits will be valid
        if (mem_resp.msg_type == e_cce_mem_uc_rd) begin
          lce_cmd.msg_type = e_lce_cmd_uc_data;
          lce_cmd.way_id = '0;
          lce_cmd.msg.dt_cmd.data[0+:dword_width_p] = mem_resp.data[0+:dword_width_p];
          lce_cmd.msg.dt_cmd.addr = mem_resp.addr;
        end else begin
          lce_cmd.msg_type = e_lce_cmd_data;
          lce_cmd.way_id = mem_resp.payload.way_id;
          lce_cmd.msg.dt_cmd.data = mem_resp.data;
          lce_cmd.msg.dt_cmd.addr = mem_resp.addr;
          lce_cmd.msg.dt_cmd.state = mem_resp.payload.state;
        end

        // Clear the pending bit in the cycle that the LCE Command ready_i goes high
        // Pending bit only cleared if this is a cached request response
        if (lce_cmd_ready_i & ~(mem_resp.msg_type == e_cce_mem_uc_rd)) begin
          pending_w_v_o = lce_cmd_ready_i;
          pending_w_way_group_o =
            mem_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
          pending_o = 1'b0;
          // TODO: only blocking on cycle that message sends because Mem Cmd are sent to a full width buffer, so it only
          // takes a single cycle to send Mem Cmd.
          // If mem_cmd is sent directly to a wormhole router (i.e., the output buffers are removed, the arbitration logic
          // for pending bits needs to be reworked. Would it be safe to have one or more cycle gap between flits in a WH routed
          // message?
          pending_w_busy_o = 1'b1;
        end
      end

      // Writeback response - clears the pending bit
      else if (mem_resp.msg_type == e_cce_mem_wb) begin
        mem_resp_yumi_o = 1'b1;
        pending_w_v_o = 1'b1;
        pending_w_way_group_o =
          mem_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        pending_o = 1'b0;
        pending_w_busy_o = 1'b1;
      end

      // Uncached store response - send uncached store done command on LCE Command
      // This transaction does not modify the pending bits
      else if (mem_resp_v_i & (mem_resp.msg_type == e_cce_mem_uc_wr)) begin
        // after store response is received, need to send uncached store done command to LCE
        lce_cmd_v_o = 1'b1;

        // inform ucode decode that this unit is using the LCE Command network
        lce_cmd_busy_o = 1'b1;

        lce_cmd.dst_id = mem_resp.payload.lce_id;
        lce_cmd.msg_type = e_lce_cmd_uc_st_done;
        lce_cmd.way_id = '0;

        lce_cmd_cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
        lce_cmd_cmd.addr = mem_resp.addr;

        lce_cmd.msg.cmd = lce_cmd_cmd;

        // dequeue the mem data response if outbound lce data cmd is accepted
        mem_resp_yumi_o = lce_cmd_ready_i;

      end

      // TODO: does e_mem_cce_inv command (could arrive on mem_resp network) need to be handled here?
      // TODO: determine if we have both _i/_o for mem_cmd and mem_resp networks, or if mem_resp can carry a command to CCE

    end


    /*
     * Microcode message send/receive
     *
     */

    case (decoded_inst_i.mem_cmd_addr_sel)
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
      e_lce_cmd_lce_req_lce: lce_cmd_lce = mshr.lce_id;
      e_lce_cmd_lce_tr_lce: lce_cmd_lce = mshr.tr_lce_id;
      e_lce_cmd_lce_0: lce_cmd_lce = '0;
      default: lce_cmd_lce = '0;
    endcase

    case (decoded_inst_i.lce_cmd_addr_sel)
      // When using a GPR to source the LCE Command Address field, the GPR is setting only the
      // "set index" bits of the address. The GPR holds the way-group number relative to this CCE,
      // which is then translated into the proper set index in the LCE (sets in the LCEs are
      // striped across the CCEs in the system).
      // Thus, set index bits = (way_group * num_cce_p) + cce_id_i
      // NOTE: num_cce_p must be a power of two
      e_lce_cmd_addr_r0: begin
        gpr_set = gpr_i[e_gpr_r0][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_r1: begin
        gpr_set = gpr_i[e_gpr_r1][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_r2: begin
        gpr_set = gpr_i[e_gpr_r2][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_r3: begin
        gpr_set = gpr_i[e_gpr_r3][lg_lce_sets_lp-1:0];
        lce_cmd_addr = (({lce_cmd_addr_0,gpr_set} << gpr_shift_lp) + paddr_width_p'(cce_id_i))
                       << lg_block_size_in_bytes_lp;
      end
      e_lce_cmd_addr_req_addr: begin
        lce_cmd_addr = mshr.paddr;
      end
      e_lce_cmd_addr_lru_way_addr: begin
        lce_cmd_addr = mshr.lru_paddr;
      end
      e_lce_cmd_addr_0: begin
        lce_cmd_addr = '0;
      end
      default: begin
        lce_cmd_addr = '0;
      end
    endcase

    case (decoded_inst_i.lce_cmd_way_sel)
      e_lce_cmd_way_req_addr_way: begin
        lce_cmd_way = mshr.way_id;
      end
      e_lce_cmd_way_tr_addr_way: begin
        lce_cmd_way = mshr.tr_way_id;
      end
      e_lce_cmd_way_sh_list_r0: begin
        lce_cmd_way = sharers_ways_i[gpr_i[e_gpr_r0][lg_num_lce_lp-1:0]];
      end
      e_lce_cmd_way_lru_addr_way: begin
        lce_cmd_way = mshr.lru_way_id;
      end
      e_lce_cmd_way_0: begin
        lce_cmd_way = '0;
      end
      default: begin
        lce_cmd_way = '0;
      end
    endcase

    // Mem Command
    if (decoded_inst_i.mem_cmd_v) begin

      // set some defaults - cached load/store miss request
      mem_cmd.msg_type = (mshr.flags[e_flag_sel_rqf]) ? e_cce_mem_wr : e_cce_mem_rd;
      mem_cmd.addr = mem_cmd_addr;
      mem_cmd.size = e_mem_size_64;
      mem_cmd.payload.lce_id = mshr.lce_id;
      mem_cmd.payload.way_id = mshr.lru_way_id;
      mem_cmd.payload.state = mshr.next_coh_state;
      mem_cmd.data = '0;

      // Uncached command - no need to block on pending_w_busy_o because uncached access does not use pending bits
      if (mshr.flags[e_flag_sel_ucf]) begin
        mem_cmd_v_o = 1'b1;
        // load or store
        if (mshr.flags[e_flag_sel_rqf]) begin
          mem_cmd.msg_type = e_cce_mem_uc_wr;
          mem_cmd.data = {(cce_block_width_p-dword_width_p)'('0),nc_data_i};
        end else begin
          mem_cmd.msg_type = e_cce_mem_uc_rd;
        end

        mem_cmd.size =
          (mshr.uc_req_size == e_lce_uc_req_1)
          ? e_mem_size_1
          : (mshr.uc_req_size == e_lce_uc_req_2)
            ? e_mem_size_2
            : (mshr.uc_req_size == e_lce_uc_req_4)
              ? e_mem_size_4
              : e_mem_size_8
          ;

      end

      // Cached request - only send if this module isn't already writing the pending bits
      else if (~pending_w_busy_o) begin
        mem_cmd_v_o = 1'b1;

        // Writeback command - override default command fields as needed
        if (decoded_inst_i.mem_cmd == e_cce_mem_wb) begin
          mem_cmd.msg_type = e_cce_mem_wb;
          mem_cmd.data = lce_resp.msg.data;
          mem_cmd.payload.lce_id = lce_resp.src_id;
          mem_cmd.payload.way_id = '0;
        end

        // Load or store miss request uses defaults defined above

        // write pending bit
        pending_w_v_o = mem_cmd_ready_i;
        pending_w_way_group_o =
          mem_cmd_addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        pending_o = 1'b1;

      end

    end
    // LCE Command
    else if (decoded_inst_i.lce_cmd_v & ~lce_cmd_busy_o) begin
      lce_cmd_v_o = 1'b1;

      lce_cmd.dst_id = lce_cmd_lce;
      lce_cmd.msg_type = decoded_inst_i.lce_cmd;
      lce_cmd.way_id = lce_cmd_way;

      lce_cmd_cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
      lce_cmd_cmd.addr = lce_cmd_addr;

      lce_cmd_cmd.state = '0;
      lce_cmd_cmd.target = '0;
      lce_cmd_cmd.target_way_id = '0;

      if ((decoded_inst_i.lce_cmd == e_lce_cmd_set_tag)
          | (decoded_inst_i.lce_cmd == e_lce_cmd_set_tag_wakeup)) begin
        lce_cmd_cmd.state = mshr.next_coh_state;
      end
      else if (decoded_inst_i.lce_cmd == e_lce_cmd_transfer) begin
        lce_cmd_cmd.state = mshr.next_coh_state;
        lce_cmd_cmd.target = mshr.lce_id;
        lce_cmd_cmd.target_way_id = mshr.lru_way_id;
      end
      lce_cmd.msg.cmd = lce_cmd_cmd;
    end
    // LCE Request
    else if (decoded_inst_i.lce_req_yumi) begin
      lce_req_yumi_o = decoded_inst_i.lce_req_yumi;
    end
    // LCE Response
    else if (decoded_inst_i.lce_resp_yumi) begin
      lce_resp_yumi_o = decoded_inst_i.lce_resp_yumi;
    end

  end

endmodule
