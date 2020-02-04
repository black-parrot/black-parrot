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
  import bp_me_pkg::*;
  #(parameter inst_width_p        = "inv"
    , parameter inst_addr_width_p = "inv"
  )
  (input                                         clk_i
   , input                                       reset_i

   // Instruction from bp_cce_pc
   , input [inst_width_p-1:0]                    inst_i
   , input                                       inst_v_i

   // Pending bit write busy from bp_cce_msg
   , input                                       pending_w_busy_i
   // LCE Command busy from bp_cce_msg
   , input                                       lce_cmd_busy_i

   // input queue valid signals
   , input                                       lce_req_v_i
   , input                                       lce_resp_v_i
   , input bp_lce_cce_resp_type_e                lce_resp_type_i
   , input                                       mem_resp_v_i
   , input                                       pending_v_i

   // ready_i signals for output queues
   , input                                       lce_cmd_ready_i
   , input                                       mem_cmd_ready_i

   // fence zero
   , input                                       fence_zero_i

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
  bp_cce_inst_dir_op_s         dir_op_s;
  bp_cce_inst_misc_op_s        misc_op_s;
  bp_cce_inst_queue_op_s       queue_op_s;

  logic pushq_op, popq_op, poph_op;
  bp_cce_inst_dst_q_sel_e pushq_qsel;
  bp_cce_inst_src_q_sel_e popq_qsel;

  logic [`bp_cce_num_src_q-1:0] wfq_v_vec;
  logic [`bp_cce_num_src_q-1:0] wfq_mask;
  logic wfq_op;
  logic wfq_q_ready;
  logic stall_op;
  logic gpr_w_v;
  logic wdp_op;
  logic fence_op;

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
    flag_op_s = op_type_u.flag_op_s;
    dir_op_s = op_type_u.dir_op_s;
    misc_op_s = op_type_u.misc_op_s;
    queue_op_s = op_type_u.queue_op_s;

    // Defaults for outputs
    decoded_inst_v_o = '0;
    decoded_inst_o = '0;
    pc_stall_o = '0;
    pc_branch_target_o = '0;

    // Pushq and Popq operation details - used for decoding and fetch control
    pushq_op = (op == e_op_queue) & (minor_op_u == e_pushq_op);
    popq_op = (op == e_op_queue) & (minor_op_u == e_popq_op);
    poph_op = (op == e_op_queue) & (minor_op_u == e_poph_op);
    pushq_qsel = queue_op_s.op.pushq.dst_q;
    popq_qsel = queue_op_s.op.popq.src_q;

    if (reset_i | ~inst_v_i) begin
      decoded_inst_v_o = '0;
    end else begin
      decoded_inst_v_o = inst_v_i;
      decoded_inst_o.op = op;
      decoded_inst_o.minor_op_u = minor_op_u;

      case (op)
        e_op_alu: begin
          decoded_inst_o.alu_v = 1'b1;
          // All ALU arithmetic operations write a GPR destination
          decoded_inst_o.alu_dst_w_v = 1'b1;
          decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = alu_op_s.imm;
          // Dst and Src fields are GPRs or immediate (src only)
          decoded_inst_o.dst.gpr = alu_op_s.dst;
          decoded_inst_o.src_a.gpr = alu_op_s.src_a;
          decoded_inst_o.src_b.gpr = alu_op_s.src_b;

          decoded_inst_o.dst_sel = e_dst_sel_gpr;
          decoded_inst_o.src_a_sel = e_src_sel_gpr;
          decoded_inst_o.src_b_sel = e_src_sel_gpr;

        end
        e_op_branch: begin

          decoded_inst_o.branch_v = 1'b1;
          // Next PC computation
          decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = branch_op_s.imm;
          pc_branch_target_o = branch_op_s.target[0+:inst_addr_width_p];

          // Default to GPR sources
          decoded_inst_o.src_a.gpr = branch_op_s.src_a.gpr;
          decoded_inst_o.src_b.gpr = branch_op_s.src_b.gpr;
          decoded_inst_o.src_a_sel = e_src_sel_gpr;
          decoded_inst_o.src_b_sel = e_src_sel_gpr;

          // Flag ops use flag as source A, immediate of 1 or 0 as source B
          if (minor_op_u.branch_minor_op == e_bf_op) begin
            decoded_inst_o.src_a.flag = branch_op_s.src_a.flag;
            decoded_inst_o.src_a_sel = e_src_sel_flag;

            if (branch_op_s.src_a.flag == e_src_flag_and
                | branch_op_s.src_a.flag == e_src_flag_nand
                | branch_op_s.src_a.flag == e_src_flag_or
                | branch_op_s.src_a.flag == e_src_flag_nor) begin
              decoded_inst_o.src_b.special = branch_op_s.src_b.special;
              decoded_inst_o.src_b_sel = e_src_sel_special;
            end

          // Branch if queue.ready set, source B is immediate set to 1
          end else if (minor_op_u.branch_minor_op == e_bqv_op) begin
            decoded_inst_o.src_a.special = branch_op_s.src_a.special;
            decoded_inst_o.src_a_sel = e_src_sel_special;

          // Branch if special register equal to GPR/imm encoded src_b
          end else if (minor_op_u.branch_minor_op == e_bs_op) begin
            decoded_inst_o.src_a.special = branch_op_s.src_a.special;
            decoded_inst_o.src_a_sel = e_src_sel_special;

          end

        end
        e_op_move: begin
          decoded_inst_o.mov_dst_w_v = 1'b1;

          if (minor_op_u.mov_minor_op == e_movi_op) begin
            decoded_inst_o.dst.gpr = mov_op_s.dst.gpr;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.src_a.gpr = e_src_gpr_imm;
            decoded_inst_o.src_a_sel = e_src_sel_gpr;
            decoded_inst_o.imm[0+:`bp_cce_inst_imm32_width] = mov_op_s.op.movi.imm;

          end else if (minor_op_u.mov_minor_op == e_movis_op) begin
            decoded_inst_o.dst.special = mov_op_s.dst.special;
            decoded_inst_o.dst_sel = e_dst_sel_special;
            decoded_inst_o.src_a.gpr = e_src_gpr_imm;
            decoded_inst_o.src_a_sel = e_src_sel_gpr;
            decoded_inst_o.imm[0+:`bp_cce_inst_imm32_width] = mov_op_s.op.movi.imm;

          end else if (minor_op_u.mov_minor_op == e_mov_op) begin
            // Dst and Src fields are GPRs
            decoded_inst_o.dst.gpr = mov_op_s.dst.gpr;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.src_a.gpr = mov_op_s.op.mov.src.gpr;
            decoded_inst_o.src_a_sel = e_src_sel_gpr;

          end else if (minor_op_u.mov_minor_op == e_movf_op) begin
            // move flag to gpr - src_a is a flag
            decoded_inst_o.dst.gpr = mov_op_s.dst.gpr;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.src_a.flag = mov_op_s.op.mov.src.flag;
            decoded_inst_o.src_a_sel = e_src_sel_flag;

          end else if (minor_op_u.mov_minor_op == e_movsg_op) begin
            decoded_inst_o.dst.gpr = mov_op_s.dst.gpr;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.src_a.special = mov_op_s.op.mov.src.special;
            decoded_inst_o.src_a_sel = e_src_sel_special;

          end else if (minor_op_u.mov_minor_op == e_movgs_op) begin
            decoded_inst_o.dst.special = mov_op_s.dst.special;
            decoded_inst_o.dst_sel = e_dst_sel_special;
            decoded_inst_o.src_a.gpr = mov_op_s.op.mov.src.gpr;
            decoded_inst_o.src_a_sel = e_src_sel_gpr;

          end else begin
            decoded_inst_o.mov_dst_w_v = 1'b0;
          end

        end
        e_op_flag: begin

          // Flag ops always use flag for src_a and src_b
          decoded_inst_o.src_a.flag = flag_op_s.src_a;
          decoded_inst_o.src_a_sel = e_src_sel_flag;

          decoded_inst_o.src_b.flag = flag_op_s.src_b;
          decoded_inst_o.src_b_sel = e_src_sel_flag;

          // immediate bit 0 always from instruction immediate
          decoded_inst_o.imm[0] = flag_op_s.val;

          // destination - by default, destination is a flag register
          decoded_inst_o.dst.flag = flag_op_s.dst.flag;
          decoded_inst_o.dst_sel = e_dst_sel_flag;

          if (minor_op_u.flag_minor_op == e_andf_op) begin
            decoded_inst_o.minor_op_u.alu_minor_op = e_and_op;
            decoded_inst_o.dst.gpr = flag_op_s.dst.gpr;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.alu_v = 1'b1;
            decoded_inst_o.alu_dst_w_v = 1'b1;
          end else if (minor_op_u.flag_minor_op == e_orf_op) begin
            decoded_inst_o.minor_op_u.alu_minor_op = e_or_op;
            decoded_inst_o.dst.gpr = flag_op_s.dst.gpr;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.alu_v = 1'b1;
            decoded_inst_o.alu_dst_w_v = 1'b1;
          end else begin
            if (flag_op_s.dst == e_dst_rqf) begin
              decoded_inst_o.rqf_sel = e_rqf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_rqf;
            end else if (flag_op_s.dst == e_dst_ucf) begin
              decoded_inst_o.rqf_sel = e_rqf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_ucf;
            end else if (flag_op_s.dst == e_dst_nerf) begin
              decoded_inst_o.nerf_sel = e_nerf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_nerf;
            end else if (flag_op_s.dst == e_dst_ldf) begin
              decoded_inst_o.ldf_sel = e_ldf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_ldf;
            end else if (flag_op_s.dst == e_dst_nwbf) begin
              decoded_inst_o.nwbf_sel = e_nwbf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_nwbf;
            end else if (flag_op_s.dst == e_dst_tf) begin
              decoded_inst_o.tf_sel = e_tf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_tf;
            end else if (flag_op_s.dst == e_dst_rf) begin
              decoded_inst_o.rf_sel = e_rf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_rf;
            end else if (flag_op_s.dst == e_dst_pf) begin
              decoded_inst_o.pf_sel = e_pf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_pf;
            end else if (flag_op_s.dst == e_dst_uf) begin
              decoded_inst_o.uf_sel = e_uf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_uf;
            end else if (flag_op_s.dst == e_dst_if) begin
              decoded_inst_o.if_sel = e_if_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_if;
            end else if (flag_op_s.dst == e_dst_cf) begin
              decoded_inst_o.cf_sel = e_cf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_cf;
            end else if (flag_op_s.dst == e_dst_cef) begin
              decoded_inst_o.cef_sel = e_cef_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_cef;
            end else if (flag_op_s.dst == e_dst_cof) begin
              decoded_inst_o.cof_sel = e_cof_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_cof;
            end else if (flag_op_s.dst == e_dst_cdf) begin
              decoded_inst_o.cdf_sel = e_cdf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_cdf;
            end else if (flag_op_s.dst == e_dst_ucf) begin
              decoded_inst_o.ucf_sel = e_ucf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_ucf;
            end else if (flag_op_s.dst == e_dst_sf) begin
              decoded_inst_o.sf_sel = e_sf_imm0;
              decoded_inst_o.flag_mask_w_v = e_flag_sf;
            end
          end

        end
        e_op_dir: begin
          // Directory input mux selects
          decoded_inst_o.dir_way_group_sel = dir_op_s.dir_way_group_sel;
          decoded_inst_o.dir_lce_sel = dir_op_s.dir_lce_sel;
          decoded_inst_o.dir_way_sel = dir_op_s.dir_way_sel;
          decoded_inst_o.dir_coh_state_sel = dir_op_s.dir_coh_state_sel;
          decoded_inst_o.dir_tag_sel = dir_op_s.dir_tag_sel;

          if (minor_op_u.dir_minor_op == e_rdp_op) begin
            decoded_inst_o.pending_r_v = 1'b1;
            decoded_inst_o.flag_mask_w_v = e_flag_pf;
            decoded_inst_o.dir_op = minor_op_u.dir_minor_op;
          end
          if (minor_op_u.dir_minor_op == e_rdw_op) begin
            decoded_inst_o.dir_r_v = 1'b1;
            decoded_inst_o.dir_op = minor_op_u.dir_minor_op;
          end
          if (minor_op_u.dir_minor_op == e_rde_op) begin
            decoded_inst_o.dir_r_v = 1'b1;
            decoded_inst_o.dst.gpr = dir_op_s.dst;
            decoded_inst_o.dst_sel = e_dst_sel_gpr;
            decoded_inst_o.rde_w_v = 1'b1;
            decoded_inst_o.dir_op = minor_op_u.dir_minor_op;
          end
          if (minor_op_u.dir_minor_op == e_wdp_op) begin
            decoded_inst_o.dir_w_v = 1'b1;
            decoded_inst_o.pending_w_v = 1'b1;
            decoded_inst_o.imm[0] = dir_op_s.pending;
            decoded_inst_o.dir_op = minor_op_u.dir_minor_op;
          end
          if (minor_op_u.dir_minor_op == e_wde_op) begin
            decoded_inst_o.dir_w_v = 1'b1;
            decoded_inst_o.imm[0+:`bp_coh_bits] = dir_op_s.state;
            decoded_inst_o.dir_op = minor_op_u.dir_minor_op;
          end
          if (minor_op_u.dir_minor_op == e_wds_op) begin
            decoded_inst_o.dir_w_v = 1'b1;
            decoded_inst_o.imm[0+:`bp_coh_bits] = dir_op_s.state;
            decoded_inst_o.dir_op = minor_op_u.dir_minor_op;
          end
          if (minor_op_u.dir_minor_op == e_gad_op) begin
            decoded_inst_o.gad_v = 1'b1;
            decoded_inst_o.transfer_lce_w_v = 1'b1; // transfer_lce, transfer_lce_way
            decoded_inst_o.req_addr_way_w_v = 1'b1; // req_addr_way
            decoded_inst_o.transfer_lce_w_v = 1'b1; // transfer_lce, transfer_lce_way
            decoded_inst_o.tf_sel = e_tf_logic;
            decoded_inst_o.rf_sel = e_rf_logic;
            decoded_inst_o.uf_sel = e_uf_logic;
            decoded_inst_o.if_sel = e_if_logic;
            decoded_inst_o.cf_sel = e_cf_logic;
            decoded_inst_o.cef_sel = e_cef_logic;
            decoded_inst_o.cof_sel = e_cof_logic;
            decoded_inst_o.cdf_sel = e_cdf_logic;
            decoded_inst_o.flag_mask_w_v =
              (e_flag_tf | e_flag_rf | e_flag_uf | e_flag_if | e_flag_cf | e_flag_cef
               | e_flag_cof | e_flag_cdf);
          end

        end
        e_op_misc: begin
          if (minor_op_u.misc_minor_op == e_clm_op) begin
            decoded_inst_o.mshr_clear = 1'b1;
          end
          else if (minor_op_u.misc_minor_op == e_fence_op) begin
            // do nothing
          end
          else if (minor_op_u.misc_minor_op == e_stall_op) begin
            // do nothing
          end
        end
        e_op_queue: begin
          if (minor_op_u.queue_minor_op == e_specq_op) begin
            decoded_inst_o.spec_cmd = queue_op_s.op.specq.cmd;
            decoded_inst_o.spec_w_v = 1'b1;
            case (queue_op_s.op.specq.cmd)
              e_spec_cmd_set: begin
                decoded_inst_o.spec_bits.spec = 1'b1;
                decoded_inst_o.spec_bits.squash = 1'b0;
                decoded_inst_o.spec_bits.fwd_mod = 1'b0;
                decoded_inst_o.spec_bits.state = '0;
              end
              e_spec_cmd_unset: begin
                decoded_inst_o.spec_bits.spec = 1'b0;
                decoded_inst_o.spec_bits.squash = 1'b0;
                decoded_inst_o.spec_bits.fwd_mod = 1'b0;
                decoded_inst_o.spec_bits.state = '0;
              end
              e_spec_cmd_squash: begin
                decoded_inst_o.spec_bits.spec = 1'b0;
                decoded_inst_o.spec_bits.squash = 1'b1;
                decoded_inst_o.spec_bits.fwd_mod = 1'b0;
                decoded_inst_o.spec_bits.state = '0;
              end
              e_spec_cmd_fwd_mod: begin
                decoded_inst_o.spec_bits.spec = 1'b0;
                decoded_inst_o.spec_bits.squash = 1'b0;
                decoded_inst_o.spec_bits.fwd_mod = 1'b1;
                decoded_inst_o.spec_bits.state = queue_op_s.op.specq.state;
              end
              e_spec_cmd_clear: begin
                // set all fields to 0
                decoded_inst_o.spec_bits.spec = 1'b0;
                decoded_inst_o.spec_bits.squash = 1'b0;
                decoded_inst_o.spec_bits.fwd_mod = 1'b0;
                decoded_inst_o.spec_bits.state = '0;
              end
              default: begin
                // shouldn't reach here unless bad instruction
                // be safe and make it a nop
                decoded_inst_o.spec_w_v = 1'b0;
              end
            endcase
          end
          if (minor_op_u.queue_minor_op == e_pushq_op) begin
            // lce cmd
            decoded_inst_o.lce_cmd = queue_op_s.op.pushq.cmd.lce_cmd;
            // cce_lce_cmd_queue inputs
            decoded_inst_o.lce_cmd_lce_sel = queue_op_s.op.pushq.lce_cmd_lce_sel;
            decoded_inst_o.lce_cmd_addr_sel = queue_op_s.op.pushq.lce_cmd_addr_sel;
            decoded_inst_o.lce_cmd_way_sel = queue_op_s.op.pushq.lce_cmd_way_sel;
            // mem cmd
            decoded_inst_o.mem_cmd = queue_op_s.op.pushq.cmd.mem_cmd;
            // mem_cmd_queue inputs
            decoded_inst_o.mem_cmd_addr_sel = queue_op_s.op.pushq.mem_cmd_addr_sel;
            // mem_resp
            decoded_inst_o.mem_resp = queue_op_s.op.pushq.cmd.mem_resp;

            // Output queue data valid signals
            // Output to LCE (ready&valid)
            decoded_inst_o.lce_cmd_v = (pushq_qsel == e_dst_q_lce_cmd);
            // Output to Mem (ready&valid), connects to FIFO buffer
            decoded_inst_o.mem_cmd_v = (pushq_qsel == e_dst_q_mem_cmd);

            if ((pushq_qsel == e_dst_q_mem_cmd) & queue_op_s.op.pushq.speculative) begin
              decoded_inst_o.spec_w_v = 1'b1;
              decoded_inst_o.spec_cmd = e_spec_cmd_clear;
              decoded_inst_o.spec_bits.spec = 1'b1;
              // rest of spec_bits = 0
              // write speculative flag
              decoded_inst_o.flag_mask_w_v = e_flag_sf;
              decoded_inst_o.sf_sel = e_sf_logic;
            end

          end
          if (minor_op_u.queue_minor_op == e_inv_op) begin
            decoded_inst_o.inv_cmd_v = 1'b1;

            // invalidation op performs a write directory state operation
            // WG = request address
            // LCE = from INV unit
            // WAY = from INV unit
            // Coherence State = Invalid (immediate)

            decoded_inst_o.dir_op = e_wds_op;

            // Directory input mux selects
            decoded_inst_o.dir_way_group_sel = e_dir_wg_sel_req_addr;
            decoded_inst_o.dir_lce_sel = e_dir_lce_sel_inv;
            decoded_inst_o.dir_way_sel = e_dir_way_sel_inv;
            decoded_inst_o.dir_coh_state_sel = e_dir_coh_sel_inst_imm;
            decoded_inst_o.imm[0+:`bp_coh_bits] = e_COH_I;

            decoded_inst_o.lce_cmd = e_lce_cmd_invalidate_tag;
            decoded_inst_o.lce_cmd_addr_sel = e_lce_cmd_addr_req_addr;

          end
          if ((minor_op_u.queue_minor_op == e_popq_op)
              | (minor_op_u.queue_minor_op == e_poph_op)) begin

            // only dequeue if actually a POPQ op, not a POPH op
            if (minor_op_u.queue_minor_op == e_popq_op) begin
              // Input queue yumi signals (to FIFOs)
              // Input messages are buffered by FIFOs, and dequeueing uses valid->yumi protocol
              // Input from LCE (valid->yumi)
              decoded_inst_o.lce_req_yumi = lce_req_v_i & (popq_qsel == e_src_q_sel_lce_req);
              decoded_inst_o.lce_resp_yumi = lce_resp_v_i & (popq_qsel == e_src_q_sel_lce_resp);
              // Input from Mem (valid->yumi)
              decoded_inst_o.mem_resp_yumi = mem_resp_v_i & (popq_qsel == e_src_q_sel_mem_resp);
            end

            if (queue_op_s.op.popq.src_q == e_src_q_sel_lce_resp) begin
              decoded_inst_o.nwbf_sel = e_nwbf_lce_resp;
              decoded_inst_o.flag_mask_w_v = e_flag_nwbf;
              decoded_inst_o.dst.gpr = queue_op_s.op.popq.dst;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.resp_type_w_v = 1'b1;

            end else if (queue_op_s.op.popq.src_q == e_src_q_sel_mem_resp) begin
              // pop the response type into a GPR
              decoded_inst_o.dst.gpr = queue_op_s.op.popq.dst;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.mem_resp_type_w_v = 1'b1;

            end else if (queue_op_s.op.popq.src_q == e_src_q_sel_lce_req) begin
              decoded_inst_o.req_sel = e_req_sel_lce_req;
              decoded_inst_o.lru_way_sel = e_lru_way_sel_lce_req;
              decoded_inst_o.req_w_v = 1'b1; // req_lce, req_addr
              decoded_inst_o.lru_way_w_v = 1'b1;
              decoded_inst_o.nerf_sel = e_nerf_lce_req;
              decoded_inst_o.ldf_sel = e_ldf_lce_req;
              decoded_inst_o.rqf_sel = e_rqf_lce_req;
              decoded_inst_o.ucf_sel = e_ucf_lce_req;
              decoded_inst_o.nc_req_size_w_v = 1'b1;
              decoded_inst_o.flag_mask_w_v = (e_flag_rqf | e_flag_nerf | e_flag_ldf | e_flag_ucf);
            end
          end
        end
        default: begin
        end
      endcase

      // Write enables

      // GPR writes occur for mov op, alu op, and LCE Response type pop - only if dst_sel is GPR
      gpr_w_v = (decoded_inst_o.mov_dst_w_v | decoded_inst_o.alu_dst_w_v
                 | decoded_inst_o.resp_type_w_v | decoded_inst_o.rde_w_v
                 | decoded_inst_o.mem_resp_type_w_v)
                & (decoded_inst_o.dst_sel == e_dst_sel_gpr);
      decoded_inst_o.gpr_w_mask =
        {
        (decoded_inst_o.dst.gpr == e_dst_r7) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r6) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r5) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r4) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r3) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r2) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r1) & (gpr_w_v)
        ,(decoded_inst_o.dst.gpr == e_dst_r0) & (gpr_w_v)
        };

      // Uncached data
      decoded_inst_o.nc_data_w_v = (popq_op) & (popq_qsel == e_src_q_sel_lce_req);

    end

    // Control for fetch
    wfq_op = (op == e_op_queue) & (minor_op_u.queue_minor_op == e_wfq_op);
    stall_op = (op == e_op_misc) & (minor_op_u.misc_minor_op == e_stall_op);
    wdp_op = (op == e_op_dir) & (minor_op_u.dir_minor_op == e_wdp_op);
    fence_op = (op == e_op_misc) & (minor_op_u.misc_minor_op == e_fence_op);

    // vector of input queue valid signals
    wfq_v_vec = {lce_req_v_i, lce_resp_v_i, mem_resp_v_i, pending_v_i};
    // WFQ mask from instruction immediate
    wfq_mask = queue_op_s.op.wfq.qmask;

    // wfq_q_ready is high if any of the selected queues in the mask are ready
    // wfq_q_ready is low if none of the selected queues in the mask are ready
    wfq_q_ready = |(wfq_mask & wfq_v_vec);

    // stall PC if WFQ instruction and none of the target queues are ready
    // stall outputs a valid instruction, but does not advance the PC
    // also stall if fence op and fence count is not zero
    pc_stall_o = stall_op | (wfq_op & ~wfq_q_ready)
                 | (fence_op & ~fence_zero_i);

    // stall PC if PUSHQ instruction and target output queue is not ready for data
    if (pushq_op) begin
    case (pushq_qsel)
      e_dst_q_lce_cmd: pc_stall_o |= ~lce_cmd_ready_i;
      e_dst_q_mem_cmd: pc_stall_o |= ~mem_cmd_ready_i;
      default: pc_stall_o = pc_stall_o;
    endcase
    end

    // stall PC if POPQ or POPH instruction and target queue has no valid data on its output
    if (popq_op | poph_op) begin
    case (popq_qsel)
      e_src_q_sel_lce_req: pc_stall_o |= ~lce_req_v_i;
      e_src_q_sel_mem_resp: pc_stall_o |= ~mem_resp_v_i;
      e_src_q_sel_lce_resp: pc_stall_o |= ~lce_resp_v_i;
      default: pc_stall_o = pc_stall_o;
    endcase
    end

    // stall if trying to push mem_cmd but bp_cce_msg is using the pending bit
    pc_stall_o |= (pushq_op & (pushq_qsel == e_dst_q_mem_cmd) & pending_w_busy_i);

    // stall if trying to pop mem_resp but bp_cce_msg is using the pending bit
    pc_stall_o |= (popq_op & (popq_qsel == e_src_q_sel_mem_resp) & pending_w_busy_i);

    // stall if trying to pop lce_resp but bp_cce_msg is using the pending bit
    pc_stall_o |= (popq_op & (popq_qsel == e_src_q_sel_lce_resp) & pending_w_busy_i);

    // stall if trying to pop lce_req but bp_cce_msg is using the pending bit
    pc_stall_o |= (popq_op & (popq_qsel == e_src_q_sel_lce_req) & pending_w_busy_i);

    // stall if trying to push lce_cmd but bp_cce_msg is sending an lce_cmd
    pc_stall_o |= (pushq_op & (pushq_qsel == e_dst_q_lce_cmd) & lce_cmd_busy_i);

    // stall if current op is WDP but bp_cce_msg is writing the pending bits
    pc_stall_o |= (wdp_op & pending_w_busy_i);

  end

endmodule
