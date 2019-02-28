/**
 *
 * Name:
 *   bp_cce_inst_decode.v
 *
 * Description:
 *   This module contains combinational logic to decode the current instruction, which
 *   is provided from the bp_cce_pc module.
 *
 */

module bp_cce_inst_decode
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter inst_width_p        = "inv"
    , parameter inst_addr_width_p = "inv"
  )
  (input                                         clk_i
   , input                                       reset_i
   // Instruction from bp_cce_pc
   , input [inst_width_p-1:0]                    inst_i
   , input                                       inst_v_i

   // input queue valid signals
   , input                                       lce_req_v_i
   , input                                       lce_resp_v_i
   , input                                       lce_data_resp_v_i
   , input                                       mem_resp_v_i
   , input                                       mem_data_resp_v_i
   , input                                       pending_v_i

   // ready_i signals for output queues
   , input                                       lce_cmd_ready_i
   , input                                       lce_data_cmd_ready_i
   , input                                       mem_cmd_ready_i
   , input                                       mem_data_cmd_ready_i

   // Decoded instruction
   , output bp_cce_inst_decoded_s                decoded_inst_o
   , output logic                                decoded_inst_v_o

   // Control to bp_cce_pc
   , output logic                                pc_stall_o
   , output logic [inst_addr_width_p-1:0]        pc_branch_target_o
  );

  // Suppress unused signal warning
  wire unused0 = clk_i;

  bp_cce_inst_s inst;

  logic pushq_op, popq_op;
  bp_cce_inst_dst_q_sel_e pushq_qsel;
  bp_cce_inst_src_q_sel_e popq_qsel;

  logic [`bp_cce_num_src_q-1:0] wfq_v_vec;
  logic [`bp_cce_num_src_q-1:0] wfq_mask;
  logic wfq_op;
  logic wfq_q_ready;
  logic stall_op;

  // Control outputs
  always_comb
  begin
    // reinterpret wires as instruction struct
    inst = inst_i;

    pushq_op = (inst.op == e_op_queue) && (inst.minor_op == e_pushq_op);
    popq_op = (inst.op == e_op_queue) && (inst.minor_op == e_popq_op);
    pushq_qsel =
      bp_cce_inst_dst_q_sel_e'(inst.imm[`bp_cce_lce_cmd_type_width+:`bp_cce_inst_dst_q_sel_width]);
    popq_qsel = bp_cce_inst_src_q_sel_e'(inst.imm[`bp_cce_inst_src_q_sel_width-1:0]);

    if (reset_i || ~inst_v_i) begin
      decoded_inst_v_o = '0;
      decoded_inst_o = '0;
    end else begin
      decoded_inst_v_o = inst_v_i;

      decoded_inst_o.minor_op_u = inst.minor_op;
      decoded_inst_o.src_a = inst.src_a;
      decoded_inst_o.src_b = inst.src_b;
      decoded_inst_o.dst = inst.dst;
      decoded_inst_o.imm = inst.imm;

      decoded_inst_o.alu_v = (inst.op == e_op_alu) | (inst.op == e_op_branch);

      // Register source selects
      decoded_inst_o.req_sel = inst.req_sel;
      decoded_inst_o.req_addr_way_sel = inst.req_addr_way_sel;
      decoded_inst_o.lru_way_sel = inst.lru_way_sel;
      decoded_inst_o.transfer_lce_sel = inst.transfer_lce_sel;
      decoded_inst_o.cache_block_data_sel = inst.cache_block_data_sel;

      // Flag source selects
      decoded_inst_o.rqf_sel = inst.rqf_sel;
      decoded_inst_o.nerldf_sel = inst.nerldf_sel;
      decoded_inst_o.nwbf_sel = inst.nwbf_sel;
      decoded_inst_o.tf_sel = inst.tf_sel;
      decoded_inst_o.pruief_sel = inst.pruief_sel;
      decoded_inst_o.rwbf_sel = inst.rwbf_sel;

      // Directory input mux selects from instruction
      decoded_inst_o.dir_way_group_sel = inst.dir_way_group_sel;
      decoded_inst_o.dir_lce_sel = inst.dir_lce_sel;
      decoded_inst_o.dir_way_sel = inst.dir_way_sel;
      decoded_inst_o.dir_coh_state_sel = inst.dir_coh_state_sel;
      decoded_inst_o.dir_tag_sel = inst.dir_tag_sel;
      // Directory read and write commands
      if (inst.op == e_op_read_dir) begin
        decoded_inst_o.dir_r_cmd = inst.minor_op;
        decoded_inst_o.dir_r_v = 1'b1;
      end else begin
        decoded_inst_o.dir_r_cmd = '0;
        decoded_inst_o.dir_r_v = '0;
      end
      if (inst.op == e_op_write_dir) begin
        decoded_inst_o.dir_w_cmd = inst.minor_op;
        decoded_inst_o.dir_w_v = 1'b1;
      end else begin
        decoded_inst_o.dir_w_cmd = '0;
        decoded_inst_o.dir_w_v = '0;
      end

      // cce_lce_cmd_queue inputs
      decoded_inst_o.lce_cmd_lce_sel = inst.lce_cmd_lce_sel;
      decoded_inst_o.lce_cmd_addr_sel = inst.lce_cmd_addr_sel;
      decoded_inst_o.lce_cmd_way_sel = inst.lce_cmd_way_sel;

      // mem_data_cmd_queue inputs
      decoded_inst_o.mem_data_cmd_addr_sel = inst.mem_data_cmd_addr_sel;

      // Write enables
      // set if instruction is a mov op producing a dst
      decoded_inst_o.mov_dst_w_v = (inst.op == e_op_move);
      // set if instruction is an alu op producing a dst
      decoded_inst_o.alu_dst_w_v = (inst.op == e_op_alu);

      decoded_inst_o.gpr_w_mask =
        {
        (inst.dst == e_dst_r3) & (decoded_inst_o.mov_dst_w_v | decoded_inst_o.alu_dst_w_v)
        ,(inst.dst == e_dst_r2) & (decoded_inst_o.mov_dst_w_v | decoded_inst_o.alu_dst_w_v)
        ,(inst.dst == e_dst_r1) & (decoded_inst_o.mov_dst_w_v | decoded_inst_o.alu_dst_w_v)
        ,(inst.dst == e_dst_r0) & (decoded_inst_o.mov_dst_w_v | decoded_inst_o.alu_dst_w_v)
        };
      decoded_inst_o.gpr_w_v = |decoded_inst_o.gpr_w_mask;

      decoded_inst_o.req_w_v = inst.req_w_v; // req_lce, req_addr, req_tag
      decoded_inst_o.req_addr_way_w_v = inst.req_addr_way_w_v; // req_addr_way
      decoded_inst_o.lru_way_w_v = inst.lru_way_w_v;
      decoded_inst_o.transfer_lce_w_v = inst.transfer_lce_w_v; // transfer_lce, transfer_lce_way
      decoded_inst_o.cache_block_data_w_v = inst.cache_block_data_w_v;
      decoded_inst_o.ack_type_w_v = inst.ack_type_w_v;

      decoded_inst_o.gad_op_w_v = (inst.op == e_op_misc) && (inst.minor_op == e_gad_op);
      decoded_inst_o.rdw_op_w_v = (inst.op == e_op_read_dir) && (inst.minor_op == e_rdw_op);
      decoded_inst_o.rde_op_w_v = (inst.op == e_op_read_dir) && (inst.minor_op == e_rde_op);

      // flag writes
      // {ReqType, NonExclReq, LruDirty, NullWb, Transfer, Replace, ReplaceWB, Pending, Upgrade,
      //  Invalidate, Exclusive, PendingCleared}
      decoded_inst_o.flag_mask_w_v = inst.flag_mask_w_v;

      // queue operations
      decoded_inst_o.lce_cmd_cmd = bp_cce_lce_cmd_type_e'(inst.imm[`bp_cce_lce_cmd_type_width-1:0]);

      // dequeue signals
      decoded_inst_o.lce_req_ready = popq_op && (popq_qsel == e_src_q_lce_req);
      decoded_inst_o.lce_resp_ready = popq_op && (popq_qsel == e_src_q_lce_resp);
      decoded_inst_o.lce_data_resp_ready = popq_op && (popq_qsel == e_src_q_lce_data_resp);
      decoded_inst_o.mem_resp_ready = popq_op && (popq_qsel == e_src_q_mem_resp);
      decoded_inst_o.mem_data_resp_ready = popq_op && (popq_qsel == e_src_q_mem_data_resp);

      // enqueue signals
      // Ready->Valid protocol
      decoded_inst_o.lce_cmd_v = lce_cmd_ready_i && pushq_op && (pushq_qsel == e_dst_q_lce_cmd);
      decoded_inst_o.lce_data_cmd_v = lce_data_cmd_ready_i && pushq_op
                                      && (pushq_qsel == e_dst_q_lce_data_cmd);
      decoded_inst_o.mem_cmd_v = mem_cmd_ready_i && pushq_op && (pushq_qsel == e_dst_q_mem_cmd);
      decoded_inst_o.mem_data_cmd_v = mem_data_cmd_ready_i && pushq_op
                                      && (pushq_qsel == e_dst_q_mem_data_cmd);
    end

    // Control for fetch
    wfq_op = (inst.op == e_op_queue) && (inst.minor_op == e_wfq_op);
    stall_op = (inst.op == e_op_misc) && (inst.minor_op == e_stall_op);

    // vector of input queue valid signals
    wfq_v_vec = {lce_req_v_i, lce_resp_v_i, lce_data_resp_v_i, mem_resp_v_i, mem_data_resp_v_i,
                 pending_v_i};
    // WFQ mask from instruction immediate
    wfq_mask = inst.imm[`bp_cce_num_src_q-1:0];

    // wfq_q_ready is high if any of the selected queues in the mask are ready
    // wfq_q_ready is low if none of the selected queues in the mask are ready
    wfq_q_ready = |(wfq_mask & wfq_v_vec);

    // stall PC if WFQ instruction and none of the target queues are ready
    pc_stall_o = stall_op | (wfq_op & ~wfq_q_ready);

    // stall PC if PUSHQ instruction and target output queue is not ready for data
    if (pushq_op) begin
    case (pushq_qsel)
      e_dst_q_lce_cmd: pc_stall_o |= ~lce_cmd_ready_i;
      e_dst_q_lce_data_cmd: pc_stall_o |= ~lce_data_cmd_ready_i;
      e_dst_q_mem_cmd: pc_stall_o |= ~mem_cmd_ready_i;
      e_dst_q_mem_data_cmd: pc_stall_o |= ~mem_data_cmd_ready_i;
      default: pc_stall_o = pc_stall_o;
    endcase
    end

    // Next PC computation
    pc_branch_target_o = inst.imm[inst_addr_width_p-1:0];

    if (reset_i) begin
      pc_stall_o = '0;
      pc_branch_target_o = '0;
    end

  end


endmodule
