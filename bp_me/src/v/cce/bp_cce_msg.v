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
    `declare_bp_me_if_widths(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p, mshr_width_lp)

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

   , input [lce_cce_data_resp_width_lp-1:0]            lce_data_resp_i
   , input                                             lce_data_resp_v_i
   , output logic                                      lce_data_resp_yumi_o

   , output logic [cce_lce_cmd_width_lp-1:0]           lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   , output logic [lce_data_cmd_width_lp-1:0]          lce_data_cmd_o
   , output logic                                      lce_data_cmd_v_o
   , input                                             lce_data_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)
   , input [mem_cce_resp_width_lp-1:0]                 mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , input [mem_cce_data_resp_width_lp-1:0]            mem_data_resp_i
   , input                                             mem_data_resp_v_i
   , output logic                                      mem_data_resp_yumi_o

   , output logic [cce_mem_cmd_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , output logic [cce_mem_data_cmd_width_lp-1:0]      mem_data_cmd_o
   , output logic                                      mem_data_cmd_v_o
   , input                                             mem_data_cmd_ready_i

   // MSHR
   , input [mshr_width_lp-1:0]                         mshr_i

   // Decoded Instruction
   , input bp_cce_inst_decoded_s                       decoded_inst_i

   // Pending bit write
   , output logic                                      pending_w_v_o
   , output logic [lg_num_way_groups_lp-1:0]           pending_w_way_group_o
   , output logic                                      pending_o

   , input [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_i

   , input [num_lce_p-1:0][lg_lce_assoc_lp-1:0]        sharers_ways_i

   , input [dword_width_p-1:0]                         nc_data_i
  );

  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr;
  assign mshr = mshr_i;

  // Interfaces
  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p, mshr_width_lp);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p, block_size_in_bits_lp);

  // structures for casting
  bp_lce_cce_data_resp_s lce_data_resp;
  bp_cce_lce_cmd_s lce_cmd;
  bp_lce_data_cmd_s lce_data_cmd;

  bp_mem_cce_resp_s mem_resp;
  bp_cce_mshr_s mem_resp_payload;
  bp_mem_cce_data_resp_s mem_data_resp;
  bp_cce_mem_cmd_s mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;

  // cast output queue messages from structure variables
  assign lce_cmd_o = lce_cmd;
  assign lce_data_cmd_o = lce_data_cmd;
  assign mem_cmd_o = mem_cmd;
  assign mem_data_cmd_o = mem_data_cmd;

  // cast input queue messages to structure variables
  assign lce_data_resp = lce_data_resp_i;
  assign mem_resp = mem_resp_i;
  assign mem_resp_payload = mem_resp.payload;
  assign mem_data_resp = mem_data_resp_i;

  // signals for setting fields in outbound messages
  logic [paddr_width_p-1:0] mem_data_cmd_addr;
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
    mem_data_cmd_v_o = '0;
    mem_data_cmd = '0;

    lce_cmd_v_o = '0;
    lce_cmd = '0;
    lce_data_cmd_v_o = '0;
    lce_data_cmd = '0;

    lce_req_yumi_o = '0;
    lce_resp_yumi_o = '0;
    lce_data_resp_yumi_o = '0;
    mem_resp_yumi_o = '0;
    mem_data_resp_yumi_o = '0;

    pending_w_v_o = '0;
    pending_w_way_group_o = '0;
    pending_o = '0;

    case (decoded_inst_i.mem_data_cmd_addr_sel)
      e_mem_data_cmd_addr_lru_way_addr: mem_data_cmd_addr = mshr.lru_paddr;
      e_mem_data_cmd_addr_req_addr: mem_data_cmd_addr = mshr.paddr;
      default mem_data_cmd_addr = '0;
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

    // Mem Resp
    if (decoded_inst_i.mem_resp_yumi) begin
      mem_resp_yumi_o = decoded_inst_i.mem_resp_yumi;

      // clear the pending bit
      // yumi is only set in decoded instruction if the mem_resp is valid, so it is safe to write
      // this cycle
      pending_w_v_o = 1'b1;
      pending_w_way_group_o =
        mem_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
      pending_o = 1'b0;
    end
    // Mem Command
    else if (decoded_inst_i.mem_cmd_v) begin
      mem_cmd_v_o = decoded_inst_i.mem_cmd_v;
      mem_cmd.msg_type = bp_lce_cce_req_type_e'(mshr.flags[e_flag_sel_rqf]);
      mem_cmd.payload.lce_id = mshr.lce_id;
      mem_cmd.payload.way_id = mshr.lru_way_id;
      mem_cmd.addr = mshr.paddr;
      mem_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr.flags[e_flag_sel_ucf]);
      mem_cmd.nc_size = bp_lce_cce_nc_req_size_e'(mshr.nc_req_size);

      // set pending bit -- only if mem_cmd is accepted
      pending_w_v_o = mem_cmd_ready_i;
      pending_w_way_group_o =
        mshr.paddr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
      pending_o = 1'b1;
    end
    // Mem Data Command
    else if (decoded_inst_i.mem_data_cmd_v) begin
      mem_data_cmd_v_o = decoded_inst_i.mem_data_cmd_v;
      mem_data_cmd.msg_type = bp_lce_cce_req_type_e'(mshr.flags[e_flag_sel_rqf]);
      mem_data_cmd.addr = mem_data_cmd_addr;
      if (mshr.flags[e_flag_sel_ucf]) begin
        mem_data_cmd.data = {(cce_block_width_p-dword_width_p)'('0),nc_data_i};
      end else begin
        mem_data_cmd.data = lce_data_resp.data;
      end
      mem_data_cmd.non_cacheable = bp_lce_cce_req_non_cacheable_e'(mshr.flags[e_flag_sel_ucf]);
      mem_data_cmd.nc_size = bp_lce_cce_nc_req_size_e'(mshr.nc_req_size);
      // Request data for return
      mem_data_cmd.payload = mshr;

      // set pending bit -- only if mem_data_cmd is accepted
      pending_w_v_o = mem_data_cmd_ready_i;
      pending_w_way_group_o =
        mem_data_cmd_addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
      pending_o = 1'b1;

    end
    // LCE Command
    else if (decoded_inst_i.lce_cmd_v) begin
      lce_cmd_v_o = decoded_inst_i.lce_cmd_v;
      lce_cmd.dst_id = lce_cmd_lce;
      lce_cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
      lce_cmd.msg_type = decoded_inst_i.lce_cmd_cmd;
      lce_cmd.addr = lce_cmd_addr;
      lce_cmd.way_id = lce_cmd_way;
      if ((decoded_inst_i.lce_cmd_cmd == e_lce_cmd_set_tag)
          | (decoded_inst_i.lce_cmd_cmd == e_lce_cmd_set_tag_wakeup)) begin
        lce_cmd.state = mshr.next_coh_state;
      end else begin
        lce_cmd.state = '0;
      end
      if (decoded_inst_i.lce_cmd_cmd == e_lce_cmd_transfer) begin
        lce_cmd.target = mshr.lce_id;
        lce_cmd.target_way_id = mshr.lru_way_id;
      end else begin
        lce_cmd.target = '0;
        lce_cmd.target_way_id = '0;
      end
    end
    // LCE Request
    else if (decoded_inst_i.lce_req_yumi) begin
      lce_req_yumi_o = decoded_inst_i.lce_req_yumi;
    end
    // LCE Response
    else if (decoded_inst_i.lce_resp_yumi) begin
      lce_resp_yumi_o = decoded_inst_i.lce_resp_yumi;
    end
    // LCE Data Response
    else if (decoded_inst_i.lce_data_resp_yumi) begin
      lce_data_resp_yumi_o = decoded_inst_i.lce_data_resp_yumi;
    end

    // Mem Data Resp and LCE Data Cmd

    // LCE Data Cmd feeds a wormhole router, so v_o must be held high for a number of cycles.
    // It is possible that in the middle of sending a message, a  mem_cmd or mem_data_cmd could also
    // try to send via the microcode, or a mem_resp could arrive and the CCE would try to process it.
    // If this happens, the CCE needs to stall the microcode operation until the lce_data_cmd finishes
    // sending and the mem_data_resp is consumed. This avoids contention on the pending bit write port.

    // Sending the LCE Data Cmd has priority over any action regarding memory messages that the CCE
    // microcode may take. Arbitration is handled by the microcode instruction decoder.

    // connect Mem Data Resp to LCE Data Cmd
    if (mem_data_resp_v_i) begin
      lce_data_cmd_v_o = mem_data_resp_v_i;
      mem_data_resp_yumi_o = lce_data_cmd_ready_i;
      // clear the pending bit in the cycle that the lce data cmd finishes sending
      // This is the only cycle that this module will block the microcode from writing the pending
      // bit, which causes the microcode engine to stall the current instruction and try to execute
      // it again in the next cycle
      if (lce_data_cmd_ready_i) begin
        pending_w_v_o = lce_data_cmd_ready_i;
        pending_w_way_group_o =
          mem_data_resp.addr[(way_group_offset_high_lp-1) -: lg_num_way_groups_lp];
        pending_o = 1'b0;
      end
      lce_data_cmd.dst_id = mem_data_resp.payload.lce_id;
      // Data is copied directly from MemDataResp
      // For uncached responses, only the least significant 64-bits will be valid
      lce_data_cmd.data = mem_data_resp.data;
      if (mshr.flags[e_flag_sel_ucf] == e_lce_req_non_cacheable) begin
        lce_data_cmd.msg_type = e_lce_data_cmd_non_cacheable;
        lce_data_cmd.way_id = '0;
      end else begin
        lce_data_cmd.msg_type = e_lce_data_cmd_cce;
        lce_data_cmd.way_id = mem_data_resp.payload.way_id;
      end
    end

  end

endmodule
