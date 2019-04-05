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
   , input                                       freeze_i

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

  // Instruction Fields
  bp_cce_inst_s                inst;
  bp_cce_inst_op_e             op;
  bp_cce_inst_minor_op_u       minor_op_u;
  bp_cce_inst_type_u           op_type_u;
  // Instruction types
  bp_cce_inst_alu_op_s         alu_op_s;
  bp_cce_inst_branch_op_s      branch_op_s;
  bp_cce_inst_mov_op_s         mov_op_s;
  bp_cce_inst_flag_op_s        flag_op_s;
  bp_cce_inst_read_dir_op_s    read_dir_op_s;
  bp_cce_inst_write_dir_op_s   write_dir_op_s;
  bp_cce_inst_misc_op_s        misc_op_s;
  bp_cce_inst_queue_op_s       queue_op_s;

  logic pushq_op, popq_op;
  bp_cce_inst_dst_q_sel_e pushq_qsel;
  bp_cce_inst_src_q_sel_e popq_qsel;

  logic [`bp_cce_num_src_q-1:0] wfq_v_vec;
  logic [`bp_cce_num_src_q-1:0] wfq_mask;
  logic wfq_op;
  logic wfq_q_ready;
  logic stall_op;
  logic gpr_w_v;

  // Control outputs
  always_comb
  begin
    gpr_w_v = '0;

    // reinterpret wires as instruction struct and fields
    inst = inst_i;
    op = inst.op;
    minor_op_u = inst.minor_op_u;
    op_type_u = inst.type_u;
    alu_op_s = op_type_u.alu_op_s;
    branch_op_s = op_type_u.branch_op_s;
    mov_op_s = op_type_u.mov_op_s;
    read_dir_op_s = op_type_u.read_dir_op_s;
    write_dir_op_s = op_type_u.write_dir_op_s;
    misc_op_s = op_type_u.misc_op_s;
    queue_op_s = op_type_u.queue_op_s;

    // Defaults for outputs
    decoded_inst_o = '0;
    pc_stall_o = '0;
    pc_branch_target_o = '0;

    // Pushq and Popq operation details - used for decoding and fetch control
    pushq_op = (op == e_op_queue) && (minor_op_u == e_pushq_op);
    popq_op = (op == e_op_queue) && (minor_op_u == e_popq_op);
    pushq_qsel = queue_op_s.op.pushq.dst_q;
    popq_qsel = queue_op_s.op.popq.src_q;

    if (reset_i || ~inst_v_i) begin
      decoded_inst_v_o = '0;
    end else begin
      decoded_inst_v_o = inst_v_i;
      decoded_inst_o.minor_op_u = minor_op_u;

      decoded_inst_o.alu_v = (op == e_op_alu) | (op == e_op_branch);
      decoded_inst_o.alu_dst_w_v = (op == e_op_alu);
      decoded_inst_o.mov_dst_w_v = (op == e_op_move);

      case (op)
        e_op_alu: begin
          decoded_inst_o.imm = alu_op_s.imm;
          decoded_inst_o.dst = alu_op_s.dst;
          decoded_inst_o.src_a = alu_op_s.src_a;
          decoded_inst_o.src_b = alu_op_s.src_b;

        end
        e_op_branch: begin
          // Next PC computation
          decoded_inst_o.imm = branch_op_s.target;
          pc_branch_target_o = branch_op_s.target[inst_addr_width_p-1:0];
          decoded_inst_o.src_a = branch_op_s.src_a;
          decoded_inst_o.src_b = branch_op_s.src_b;

        end
        e_op_move: begin
          // destination
          decoded_inst_o.dst = mov_op_s.dst;
          // source
          // move operation
          if (minor_op_u.mov_minor_op == e_mov_op) begin
            decoded_inst_o.src_a = mov_op_s.src;
          end
          // move immediate operation
          if (minor_op_u.mov_minor_op == e_movi_op) begin
            decoded_inst_o.src_a = e_src_imm;
            decoded_inst_o.imm = mov_op_s.imm;
          end

        end
        e_op_flag: begin

          // source - always from immediate bit 0
          decoded_inst_o.src_a = e_src_imm;
          decoded_inst_o.imm = {{(`bp_cce_inst_imm16_width-1){1'b0}}, flag_op_s.val};

          // destination
          decoded_inst_o.dst = flag_op_s.dst;
          if (flag_op_s.dst == e_dst_rqf) begin
            decoded_inst_o.rqf_sel = e_rqf_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_rqf;
          end else if (flag_op_s.dst == e_dst_nerf) begin
            decoded_inst_o.nerldf_sel = e_nerldf_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_nerf;
          end else if (flag_op_s.dst == e_dst_ldf) begin
            decoded_inst_o.nerldf_sel = e_nerldf_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_ldf;
          end else if (flag_op_s.dst == e_dst_nwbf) begin
            decoded_inst_o.nwbf_sel = e_nwbf_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_nwbf;
          end else if (flag_op_s.dst == e_dst_tf) begin
            decoded_inst_o.tf_sel = e_tf_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_tf;
          end else if (flag_op_s.dst == e_dst_rf) begin
            decoded_inst_o.pruief_sel = e_pruief_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_rf;
          end else if (flag_op_s.dst == e_dst_rwbf) begin
            decoded_inst_o.rwbf_sel = e_rwbf_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_rwbf;
          end else if (flag_op_s.dst == e_dst_pf) begin
            decoded_inst_o.pruief_sel = e_pruief_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_pf;
          end else if (flag_op_s.dst == e_dst_uf) begin
            decoded_inst_o.pruief_sel = e_pruief_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_uf;
          end else if (flag_op_s.dst == e_dst_if) begin
            decoded_inst_o.pruief_sel = e_pruief_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_if;
          end else if (flag_op_s.dst == e_dst_ef) begin
            decoded_inst_o.pruief_sel = e_pruief_imm0;
            decoded_inst_o.flag_mask_w_v = e_flag_ef;
          end

        end
        e_op_read_dir: begin
          // Directory input mux selects
          decoded_inst_o.dir_way_group_sel = read_dir_op_s.dir_way_group_sel;
          decoded_inst_o.dir_lce_sel = read_dir_op_s.dir_lce_sel;
          decoded_inst_o.dir_way_sel = read_dir_op_s.dir_way_sel;

          decoded_inst_o.dir_r_cmd = minor_op_u;
          decoded_inst_o.dir_r_v = 1'b1;
          if (minor_op_u.read_dir_minor_op == e_rdp_op) begin
            decoded_inst_o.flag_mask_w_v = e_flag_pf;
          end
          if (minor_op_u.read_dir_minor_op == e_rdw_op) begin
            decoded_inst_o.rdw_op_w_v = 1'b1;
            decoded_inst_o.flag_mask_w_v = e_flag_pf;
          end
          if (minor_op_u.read_dir_minor_op == e_rde_op) begin
            decoded_inst_o.rde_op_w_v = 1'b1;
          end
        end
        e_op_write_dir: begin
          // Directory input mux selects
          decoded_inst_o.dir_way_group_sel = write_dir_op_s.dir_way_group_sel;
          decoded_inst_o.dir_lce_sel = write_dir_op_s.dir_lce_sel;
          decoded_inst_o.dir_way_sel = write_dir_op_s.dir_way_sel;
          decoded_inst_o.dir_coh_state_sel = write_dir_op_s.dir_coh_state_sel;
          decoded_inst_o.dir_tag_sel = write_dir_op_s.dir_tag_sel;

          decoded_inst_o.dir_w_cmd = minor_op_u;
          decoded_inst_o.dir_w_v = 1'b1;
        end
        e_op_misc: begin
          if (minor_op_u.misc_minor_op == e_gad_op) begin
            decoded_inst_o.gad_op_w_v = 1'b1;
            decoded_inst_o.transfer_lce_w_v = 1'b1; // transfer_lce, transfer_lce_way
            decoded_inst_o.transfer_lce_sel = e_tr_lce_sel_logic;
            decoded_inst_o.req_addr_way_sel = e_req_addr_way_sel_logic;
            decoded_inst_o.req_addr_way_w_v = 1'b1; // req_addr_way
            decoded_inst_o.transfer_lce_w_v = 1'b1; // transfer_lce, transfer_lce_way
            decoded_inst_o.tf_sel = e_tf_logic;
            decoded_inst_o.pruief_sel = e_pruief_logic;
            decoded_inst_o.flag_mask_w_v =
              (e_flag_tf | e_flag_rf | e_flag_uf | e_flag_if | e_flag_ef);
          end
        end
        e_op_queue: begin
          if (minor_op_u.queue_minor_op == e_pushq_op) begin
            // lce cmd
            decoded_inst_o.lce_cmd_cmd = queue_op_s.op.pushq.cmd;
            // cce_lce_cmd_queue inputs
            decoded_inst_o.lce_cmd_lce_sel = queue_op_s.op.pushq.lce_cmd_lce_sel;
            decoded_inst_o.lce_cmd_addr_sel = queue_op_s.op.pushq.lce_cmd_addr_sel;
            decoded_inst_o.lce_cmd_way_sel = queue_op_s.op.pushq.lce_cmd_way_sel;
            // mem_data_cmd_queue inputs
            decoded_inst_o.mem_data_cmd_addr_sel = queue_op_s.op.pushq.mem_data_cmd_addr_sel;

            // enqueue signals
            // Ready->Valid protocol
            decoded_inst_o.lce_cmd_v = lce_cmd_ready_i && (pushq_qsel == e_dst_q_lce_cmd);
            //decoded_inst_o.lce_data_cmd_v = lce_data_cmd_ready_i && (pushq_qsel == e_dst_q_lce_data_cmd);
            decoded_inst_o.lce_data_cmd_v = (pushq_qsel == e_dst_q_lce_data_cmd);
            decoded_inst_o.mem_cmd_v = mem_cmd_ready_i && (pushq_qsel == e_dst_q_mem_cmd);
            decoded_inst_o.mem_data_cmd_v = mem_data_cmd_ready_i
                                            && (pushq_qsel == e_dst_q_mem_data_cmd);
      

          end
          if (minor_op_u.queue_minor_op == e_popq_op) begin
            // dequeue signals
            decoded_inst_o.lce_req_ready = popq_op && (popq_qsel == e_src_q_sel_lce_req);
            decoded_inst_o.lce_resp_ready = popq_op && (popq_qsel == e_src_q_sel_lce_resp);
            decoded_inst_o.lce_data_resp_ready =
              popq_op && (popq_qsel == e_src_q_sel_lce_data_resp);
            decoded_inst_o.mem_resp_ready = popq_op && (popq_qsel == e_src_q_sel_mem_resp);
            decoded_inst_o.mem_data_resp_ready =
              popq_op && (popq_qsel == e_src_q_sel_mem_data_resp);

            if (queue_op_s.op.popq.src_q == e_src_q_sel_lce_data_resp) begin
              decoded_inst_o.cache_block_data_w_v = 1'b1;
              decoded_inst_o.cache_block_data_sel = e_data_sel_lce_data_resp;
              decoded_inst_o.nwbf_sel = e_nwbf_lce_data_resp;
              decoded_inst_o.flag_mask_w_v = e_flag_nwbf;

            end else if (queue_op_s.op.popq.src_q == e_src_q_sel_mem_data_resp) begin
              decoded_inst_o.cache_block_data_w_v = 1'b1;
              decoded_inst_o.cache_block_data_sel = e_data_sel_mem_data_resp;
              decoded_inst_o.req_sel = e_req_sel_mem_data_resp;
              decoded_inst_o.lru_way_sel = e_lru_way_sel_mem_data_resp;
              decoded_inst_o.req_addr_way_sel = e_req_addr_way_sel_mem_data_resp;
              decoded_inst_o.req_w_v = 1'b1; // req_lce, req_addr, req_tag
              decoded_inst_o.req_addr_way_w_v = 1'b1; // req_addr_way
              decoded_inst_o.lru_way_w_v = 1'b1;
              decoded_inst_o.rqf_sel = e_rqf_mem_data_resp;
              decoded_inst_o.nc_req_size_w_v = 1'b1;
              decoded_inst_o.flag_mask_w_v = e_flag_rqf;

            end else if (queue_op_s.op.popq.src_q == e_src_q_sel_mem_resp) begin
              decoded_inst_o.req_sel = e_req_sel_mem_resp;
              decoded_inst_o.transfer_lce_sel = e_tr_lce_sel_mem_resp;
              decoded_inst_o.lru_way_sel = e_lru_way_sel_mem_resp;
              decoded_inst_o.req_addr_way_sel = e_req_addr_way_sel_mem_resp;
              decoded_inst_o.req_w_v = 1'b1; // req_lce, req_addr, req_tag
              decoded_inst_o.req_addr_way_w_v = 1'b1; // req_addr_way
              decoded_inst_o.lru_way_w_v = 1'b1;
              decoded_inst_o.transfer_lce_w_v = 1'b1; // transfer_lce, transfer_lce_way
              decoded_inst_o.rwbf_sel = e_rwbf_mem_resp;
              decoded_inst_o.tf_sel = e_tf_mem_resp;
              decoded_inst_o.rqf_sel = e_rqf_mem_resp;
              decoded_inst_o.nc_req_size_w_v = 1'b1;
              decoded_inst_o.flag_mask_w_v = (e_flag_rqf | e_flag_rwbf | e_flag_tf);

            end else if (queue_op_s.op.popq.src_q == e_src_q_sel_lce_resp) begin
              decoded_inst_o.ack_type_w_v = 1'b1;

            end else if (queue_op_s.op.popq.src_q == e_src_q_sel_lce_req) begin
              decoded_inst_o.req_sel = e_req_sel_lce_req;
              decoded_inst_o.lru_way_sel = e_lru_way_sel_lce_req;
              decoded_inst_o.req_w_v = 1'b1; // req_lce, req_addr, req_tag
              decoded_inst_o.lru_way_w_v = 1'b1;
              decoded_inst_o.nerldf_sel = e_nerldf_lce_req;
              decoded_inst_o.rqf_sel = e_rqf_lce_req;
              decoded_inst_o.nc_req_size_w_v = 1'b1;
              decoded_inst_o.flag_mask_w_v = (e_flag_rqf | e_flag_nerf | e_flag_ldf);
            end
          end
        end
        default: begin
        end
      endcase

      // Write enables
      gpr_w_v = decoded_inst_o.mov_dst_w_v | decoded_inst_o.alu_dst_w_v;
      decoded_inst_o.gpr_w_mask =
        {
        (decoded_inst_o.dst == e_dst_r3) & (gpr_w_v)
        ,(decoded_inst_o.dst == e_dst_r2) & (gpr_w_v)
        ,(decoded_inst_o.dst == e_dst_r1) & (gpr_w_v)
        ,(decoded_inst_o.dst == e_dst_r0) & (gpr_w_v)
        };
      decoded_inst_o.gpr_w_v = |decoded_inst_o.gpr_w_mask;

      // Uncached data and request size register writes
      decoded_inst_o.nc_data_lce_req = (popq_op) && (popq_qsel == e_src_q_sel_lce_req);
      decoded_inst_o.nc_data_mem_data_resp = (popq_op) && (popq_qsel == e_src_q_sel_mem_data_resp);
      decoded_inst_o.nc_data_w_v = (popq_op) && ((popq_qsel == e_src_q_sel_lce_req)
                                                 || (popq_qsel == e_src_q_sel_mem_data_resp));

    end

    // Control for fetch
    wfq_op = (op == e_op_queue) && (minor_op_u.queue_minor_op == e_wfq_op);
    stall_op = (op == e_op_misc) && (minor_op_u.misc_minor_op == e_stall_op);

    // vector of input queue valid signals
    wfq_v_vec = {lce_req_v_i, lce_resp_v_i, lce_data_resp_v_i, mem_resp_v_i, mem_data_resp_v_i,
                 pending_v_i};
    // WFQ mask from instruction immediate
    wfq_mask = queue_op_s.op.wfq.qmask;
    //inst.imm[`bp_cce_num_src_q-1:0];

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

  end


endmodule
