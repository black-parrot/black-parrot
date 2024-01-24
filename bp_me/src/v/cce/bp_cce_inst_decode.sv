/**
 *
 * Name:
 *   bp_cce_inst_decode.sv
 *
 * Description:
 *   The decoder holds the decode+execute stage PC, instruction, and valid bit. The decoder also
 *   contains the instruction decode logic and outputs the decoded instruction used to control
 *   all of the other modules in the CCE.
 *
 *   The decoder does not check if the instruction can actually be executed, rather it outputs
 *   the instruction assuming it will be executed. The stall unit and other arbitration logic
 *   in the CCE will nullify the instruction if it cannot be executed this cycle. The decoder
 *   is informed of this through the stall_i signal, which causes the current PC, instruction,
 *   and valid bit to be retained at the end of the cycle. The current instruction is then
 *   replayed next cycle.
 *
 *   A mispredict event detected by the branch unit causes the next instruction to be invalid
 *   since the Fetch stage must re-direct instruction fetch. The instruction being produced
 *   by Fetch when a mispredict is detected becomes invalid and therefore there is a 1 cycle
 *   bubble/penalty for a mispredicted branch.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_inst_decode
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter `BSG_INV_PARAM(cce_pc_width_p)
  )
  (input                                         clk_i
   , input                                       reset_i

   // Instruction, PC, and valid bit from bp_cce_inst_ram
   , input bp_cce_inst_s                         inst_i
   , input [cce_pc_width_p-1:0]                  pc_i
   , input                                       inst_v_i

   // Stall signal from stall detection unit
   , input                                       stall_i

   // Mispredict signal from branch unit
   , input                                       mispredict_i

   // Decoded instruction
   , output bp_cce_inst_decoded_s                decoded_inst_o
   , output logic [cce_pc_width_p-1:0]           pc_o

  );

  // Execute Stage Instruction Register and PC
  bp_cce_inst_s inst_r, inst_n;
  logic [cce_pc_width_p-1:0] ex_pc_r, ex_pc_n;
  logic inst_v_r, inst_v_n;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      inst_r <= '0;
      ex_pc_r <= '0;
      inst_v_r <= '0;
    end else begin
      inst_r <= inst_n;
      ex_pc_r <= ex_pc_n;
      inst_v_r <= inst_v_n;
    end
  end

  // Instruction Fields
  bp_cce_inst_op_e             op;
  bp_cce_inst_minor_op_u       minor_op_u;
  bp_cce_inst_type_u           op_type_u;

  always_comb begin

    // Next instruction determination

    // The next instruction and its PC that will be seen by the Execute stage comes from
    // the output of the instruction RAM and the fetch_pc register in bp_cce_inst_ram.
    inst_n = stall_i ? inst_r : inst_i;
    ex_pc_n = stall_i ? ex_pc_r : pc_i;
    // The next instruction is valid as long as there was not a mispredict detected in the
    // Execute stage. A mispredict squashes the next instruction, by setting the valid bit
    // to 0 for the next cycle, which then gates off the decoder next cycle.
    // If the current instruction stalls (which is detected after decoding due to interactions
    // between the current ucode instruction and resource conflicts with functional units),
    // the stall signal is sent back to the Fetch stage and the current instruction, PC, and
    // valid bit are retained for the next cycle. The stall signal also causes the valid
    // bit to hold its state.
    inst_v_n = stall_i
               ? inst_v_r
               : mispredict_i
                 ? 1'b0
                 : inst_v_i;


    // Current instruction decoding - does not depend on stall or mispredict.

    pc_o = ex_pc_r;

    decoded_inst_o = '0;
    decoded_inst_o.v = inst_v_r;

    op = inst_r.op;
    minor_op_u = inst_r.minor_op_u;
    op_type_u = inst_r.type_u;

    // only finish decoding if current instruction is valid
    if (inst_v_r) begin

      decoded_inst_o.branch = inst_r.branch;
      decoded_inst_o.predict_taken = inst_r.predict_taken;

      decoded_inst_o.op = op;
      decoded_inst_o.minor_op_u = minor_op_u;

      unique case (op)

        // ALU Operations
        e_op_alu: begin

          // Note: decoding ALU ops relies on the dst field being in the same location
          // in both rtype and itype instruction encodings.

          decoded_inst_o.dst_sel = e_dst_sel_gpr;
          decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
          decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;

          decoded_inst_o.src_a_sel = e_src_sel_gpr;
          decoded_inst_o.src_a.gpr = op_type_u.rtype.src_a.gpr;

          unique case (minor_op_u.alu_minor_op)
            e_add_op: begin
              decoded_inst_o.alu_op = e_alu_add;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_sub_op: begin
              decoded_inst_o.alu_op = e_alu_sub;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_lsh_op: begin
              decoded_inst_o.alu_op = e_alu_lsh;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_rsh_op: begin
              decoded_inst_o.alu_op = e_alu_rsh;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_and_op: begin
              decoded_inst_o.alu_op = e_alu_and;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_or_op: begin
              decoded_inst_o.alu_op = e_alu_or;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_xor_op: begin
              decoded_inst_o.alu_op = e_alu_xor;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.rtype.src_b.gpr;
            end
            e_neg_op: begin // only one source operand
              decoded_inst_o.alu_op = e_alu_neg;
            end
            e_addi_op: begin
              decoded_inst_o.alu_op = e_alu_add;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
            end
            e_subi_op: begin
              decoded_inst_o.alu_op = e_alu_sub;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
            end
            e_lshi_op: begin
              decoded_inst_o.alu_op = e_alu_lsh;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
            end
            e_rshi_op: begin
              decoded_inst_o.alu_op = e_alu_rsh;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
            end
            e_not_op: begin // only one source operand
              decoded_inst_o.alu_op = e_alu_not;
            end
            default: begin
            end
          endcase
        end

        // Branch Operations (except branch flag, which are under Flag)
        e_op_branch: begin

          // Note: Decoding branches relies the target field being in the same location
          // for btype, bitype, and bftype instruction encodings.

          decoded_inst_o.branch_target = op_type_u.btype.target;

          unique case (minor_op_u.branch_minor_op)
            e_beq_op: begin
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.btype.src_a.gpr;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.btype.src_b.gpr;
            end
            e_bne_op: begin
              decoded_inst_o.branch_op = e_branch_neq;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.btype.src_a.gpr;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.btype.src_b.gpr;
            end
            e_blt_op: begin
              decoded_inst_o.branch_op = e_branch_lt;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.btype.src_a.gpr;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.btype.src_b.gpr;
            end
            e_ble_op: begin
              decoded_inst_o.branch_op = e_branch_le;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.btype.src_a.gpr;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.btype.src_b.gpr;
            end
            e_bs_op: begin // src_a = special, src_b = gpr
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = op_type_u.btype.src_a.special;
              decoded_inst_o.src_b_sel = e_src_sel_gpr;
              decoded_inst_o.src_b.gpr = op_type_u.btype.src_b.gpr;
            end
            e_bss_op: begin // src_a and src_b = special
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = op_type_u.btype.src_a.special;
              decoded_inst_o.src_b_sel = e_src_sel_special;
              decoded_inst_o.src_b.special = op_type_u.btype.src_b.special;
            end
            e_beqi_op: begin // src_a = gpr, src_b = imm
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.bitype.src_a.gpr;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm8_width] = op_type_u.bitype.imm;
            end
            e_bsi_op: begin // src_a = special, src_b = imm
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = op_type_u.bitype.src_a.special;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm8_width] = op_type_u.bitype.imm;
            end
            default: begin
            end
          endcase
        end

        // Register Data Movement Operations
        e_op_reg_data: begin

          unique case (minor_op_u.reg_data_minor_op)
            e_mov_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.rtype.src_a.gpr;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_movsg_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = op_type_u.rtype.src_a.special;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_movgs_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.rtype.src_a.gpr;
              decoded_inst_o.dst_sel = e_dst_sel_special;
              decoded_inst_o.dst.special = op_type_u.rtype.dst.special;
              // write enable signal set below
            end
            e_movfg_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_flag;
              decoded_inst_o.src_a.flag = op_type_u.rtype.src_a.flag;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_movgf_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.rtype.src_a.gpr;
              decoded_inst_o.dst_sel = e_dst_sel_flag;
              decoded_inst_o.dst.flag = op_type_u.rtype.dst.flag;
              decoded_inst_o.flag_w_v[op_type_u.rtype.dst.flag] = 1'b1;
            end
            e_movpg_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_param;
              decoded_inst_o.src_a.param = op_type_u.rtype.src_a.param;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_movgp_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.rtype.src_a.gpr;
              decoded_inst_o.dst_sel = e_dst_sel_param;
              decoded_inst_o.dst.param = op_type_u.rtype.dst.param;
            end
            e_movi_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.itype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.itype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_movis_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
              decoded_inst_o.dst_sel = e_dst_sel_special;
              decoded_inst_o.dst.special = op_type_u.itype.dst.special;
              // write enable signal set below
            end
            e_movip_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
              decoded_inst_o.dst_sel = e_dst_sel_param;
              decoded_inst_o.dst.param = op_type_u.itype.dst.param;
              // write enable signal set below
            end
            e_clm_op: begin
              decoded_inst_o.mshr_clear = 1'b1;
            end
            default: begin
            end
          endcase

          if ((minor_op_u.reg_data_minor_op == e_movgs_op)
              | (minor_op_u.reg_data_minor_op == e_movis_op)) begin
            if (op_type_u.itype.dst.special == e_opd_req_lce) begin
              decoded_inst_o.lce_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_req_addr) begin
              decoded_inst_o.addr_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_req_way) begin
              decoded_inst_o.way_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_lru_addr) begin
              decoded_inst_o.lru_addr_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_lru_way) begin
              decoded_inst_o.lru_way_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_owner_lce) begin
              decoded_inst_o.owner_lce_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_owner_way) begin
              decoded_inst_o.owner_way_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_next_coh_state) begin
              decoded_inst_o.next_coh_state_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_lru_coh_state) begin
              decoded_inst_o.lru_coh_state_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_owner_coh_state) begin
              decoded_inst_o.owner_coh_state_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.special == e_opd_flags) begin
              decoded_inst_o.flag_w_v = '1;
              decoded_inst_o.imm = '1;
            end
            if (op_type_u.itype.dst.special == e_opd_msg_size) begin
              decoded_inst_o.msg_size_w_v = 1'b1;
            end
          end

          if ((minor_op_u.reg_data_minor_op == e_movgp_op)
              | (minor_op_u.reg_data_minor_op == e_movip_op)) begin
            if (op_type_u.itype.dst.param == e_opd_auto_fwd_msg) begin
              decoded_inst_o.auto_fwd_msg_w_v = 1'b1;
            end
            if (op_type_u.itype.dst.param == e_opd_coh_state_default) begin
              decoded_inst_o.coh_state_w_v = 1'b1;
            end
          end

        end

        // Flag Operations
        e_op_flag: begin

          unique case (minor_op_u.flag_minor_op)
            e_sf_op: begin
              decoded_inst_o.src_a_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.itype.imm;
              decoded_inst_o.dst_sel = e_dst_sel_flag;
              decoded_inst_o.flag_w_v[op_type_u.itype.dst.flag] = 1'b1;
            end
            e_andf_op: begin
              decoded_inst_o.alu_op = e_alu_and;
              decoded_inst_o.src_a_sel = e_src_sel_flag;
              decoded_inst_o.src_a.flag = op_type_u.rtype.src_a.flag;
              decoded_inst_o.src_b_sel = e_src_sel_flag;
              decoded_inst_o.src_b.flag = op_type_u.rtype.src_b.flag;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_orf_op: begin
              decoded_inst_o.alu_op = e_alu_or;
              decoded_inst_o.src_a_sel = e_src_sel_flag;
              decoded_inst_o.src_a.flag = op_type_u.rtype.src_a.flag;
              decoded_inst_o.src_b_sel = e_src_sel_flag;
              decoded_inst_o.src_b.flag = op_type_u.rtype.src_b.flag;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_nandf_op: begin
              decoded_inst_o.alu_op = e_alu_nand;
              decoded_inst_o.src_a_sel = e_src_sel_flag;
              decoded_inst_o.src_a.flag = op_type_u.rtype.src_a.flag;
              decoded_inst_o.src_b_sel = e_src_sel_flag;
              decoded_inst_o.src_b.flag = op_type_u.rtype.src_b.flag;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_norf_op: begin
              decoded_inst_o.alu_op = e_alu_nor;
              decoded_inst_o.src_a_sel = e_src_sel_flag;
              decoded_inst_o.src_a.flag = op_type_u.rtype.src_a.flag;
              decoded_inst_o.src_b_sel = e_src_sel_flag;
              decoded_inst_o.src_b.flag = op_type_u.rtype.src_b.flag;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_notf_op: begin
              decoded_inst_o.alu_op = e_alu_not;
              decoded_inst_o.src_a_sel = e_src_sel_flag;
              decoded_inst_o.src_a.flag = op_type_u.rtype.src_a.flag;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.rtype.dst.gpr;
              decoded_inst_o.gpr_w_v[op_type_u.rtype.dst.gpr[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
            end
            e_bf_op: begin
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.branch_target = op_type_u.bftype.target;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = e_opd_flags;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.bftype.imm;
            end
            e_bfz_op: begin
              decoded_inst_o.branch_op = e_branch_eq;
              decoded_inst_o.branch_target = op_type_u.bftype.target;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = e_opd_flags;
              decoded_inst_o.src_b_sel = e_src_sel_zero;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.bftype.imm;
            end
            e_bfnz_op: begin
              decoded_inst_o.branch_op = e_branch_neq;
              decoded_inst_o.branch_target = op_type_u.bftype.target;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = e_opd_flags;
              decoded_inst_o.src_b_sel = e_src_sel_zero;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.bftype.imm;
            end
            e_bfnot_op: begin
              decoded_inst_o.branch_op = e_branch_neq;
              decoded_inst_o.branch_target = op_type_u.bftype.target;
              decoded_inst_o.src_a_sel = e_src_sel_special;
              decoded_inst_o.src_a.special = e_opd_flags;
              decoded_inst_o.src_b_sel = e_src_sel_imm;
              decoded_inst_o.imm[0+:`bp_cce_inst_imm16_width] = op_type_u.bftype.imm;
            end
            default: begin
            end
          endcase
        end

        // Directory Operations
        e_op_dir: begin

          unique case (minor_op_u.flag_minor_op)
            e_rdp_op: begin
              decoded_inst_o.pending_r_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.dptype.addr_sel;
              decoded_inst_o.flag_w_v[e_opd_pf] = 1'b1;
            end
            e_rdw_op: begin
              decoded_inst_o.dir_r_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.drtype.addr_sel;
              decoded_inst_o.lce_sel = op_type_u.drtype.lce_sel;
              decoded_inst_o.lru_way_sel = op_type_u.drtype.lru_way_sel;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.drtype.src_a;
            end
            e_rde_op: begin
              decoded_inst_o.dir_r_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.drtype.addr_sel;
              decoded_inst_o.lce_sel = op_type_u.drtype.lce_sel;
              decoded_inst_o.way_sel = op_type_u.drtype.way_sel;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.drtype.dst;
              decoded_inst_o.gpr_w_v[op_type_u.drtype.dst[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.drtype.src_a;
            end
            e_wdp_op: begin
              decoded_inst_o.pending_w_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.dptype.addr_sel;
              decoded_inst_o.pending_bit = op_type_u.dptype.pending;
              decoded_inst_o.imm[0] = op_type_u.dptype.pending;
            end
            e_clp_op: begin
              decoded_inst_o.pending_w_v = 1'b1;
              decoded_inst_o.pending_clear = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.dptype.addr_sel;
            end
            e_clr_op: begin
              decoded_inst_o.dir_w_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.drtype.addr_sel;
              decoded_inst_o.lce_sel = op_type_u.drtype.lce_sel;
            end
            e_wde_op: begin
              decoded_inst_o.dir_w_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.dwtype.addr_sel;
              decoded_inst_o.lce_sel = op_type_u.dwtype.lce_sel;
              decoded_inst_o.way_sel = op_type_u.dwtype.way_sel;
              decoded_inst_o.coh_state_sel = op_type_u.dwtype.state_sel;
              decoded_inst_o.imm[0+:$bits(bp_coh_states_e)] = op_type_u.dwtype.state;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.dwtype.src_a;
            end
            e_wds_op: begin
              decoded_inst_o.dir_w_v = 1'b1;
              decoded_inst_o.addr_sel = op_type_u.dwtype.addr_sel;
              decoded_inst_o.lce_sel = op_type_u.dwtype.lce_sel;
              decoded_inst_o.way_sel = op_type_u.dwtype.way_sel;
              decoded_inst_o.coh_state_sel = op_type_u.dwtype.state_sel;
              decoded_inst_o.imm[0+:$bits(bp_coh_states_e)] = op_type_u.dwtype.state;
              decoded_inst_o.src_a_sel = e_src_sel_gpr;
              decoded_inst_o.src_a.gpr = op_type_u.dwtype.src_a;
            end
            e_gad_op: begin
              decoded_inst_o.gad_v = 1'b1;
              decoded_inst_o.way_w_v = 1'b1;
              decoded_inst_o.owner_lce_w_v = 1'b1;
              decoded_inst_o.owner_way_w_v = 1'b1;
              decoded_inst_o.owner_coh_state_w_v = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_rf] = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_uf] = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_csf] = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_cef] = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_cmf] = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_cof] = 1'b1;
              decoded_inst_o.flag_w_v[e_opd_cff] = 1'b1;
            end
            default: begin
            end
          endcase
        end

        // Queue Operations
        e_op_queue: begin

          unique case (minor_op_u.queue_minor_op)
            e_wfq_op: begin
              decoded_inst_o.wfq_v = 1'b1;
              decoded_inst_o.imm[0+:$bits(bp_cce_inst_src_q_e)] = op_type_u.itype.imm[0+:$bits(bp_cce_inst_src_q_e)];
            end
            e_pushq_op: begin
              // pushq and pushqc have same encoding, except pushq uses
              // the way_sel field and pushqc the msg_size field
              decoded_inst_o.pushq = 1'b1;
              decoded_inst_o.pushq_qsel = op_type_u.pushq.dst_q;

              unique case (op_type_u.pushq.dst_q)
                e_dst_q_sel_lce_cmd: begin
                  decoded_inst_o.lce_cmd_v = 1'b1;
                  decoded_inst_o.lce_cmd = op_type_u.pushq.cmd.lce_cmd;
                end
                e_dst_q_sel_mem_fwd: begin
                  decoded_inst_o.mem_fwd_v = 1'b1;
                  decoded_inst_o.mem_fwd = op_type_u.pushq.cmd.mem_fwd;
                end
                default: begin
                end
              endcase

              decoded_inst_o.addr_sel = op_type_u.pushq.addr_sel;
              decoded_inst_o.lce_sel = op_type_u.pushq.lce_sel;
              decoded_inst_o.src_a_sel = e_src_sel_queue;
              decoded_inst_o.src_a.q = op_type_u.pushq.src_a;

              // set spec bit to 1, clear rest of bits
              // Note: spec bit should only be set for mem_fwd
              // It is a microcode/program error if it is set when pusing to lce_cmd,
              // and there is a check in the assembler to help guard against this
              if (op_type_u.pushq.spec) begin
                decoded_inst_o.spec_w_v = 1'b1;
                decoded_inst_o.spec_v = 1'b1;
                decoded_inst_o.spec_squash_v = 1'b1;
                decoded_inst_o.spec_fwd_mod_v = 1'b1;
                decoded_inst_o.spec_state_v = 1'b1;
                decoded_inst_o.spec_bits.spec = 1'b1;
              end

              decoded_inst_o.pushq_custom = op_type_u.pushq.custom;

              // custom push commands use msg_size field
              decoded_inst_o.msg_size = bp_bedrock_msg_size_e'(op_type_u.pushq.way_or_size.msg_size);
              // normal push commands use way_select and coh_state_select
              decoded_inst_o.way_sel = op_type_u.pushq.way_or_size.way_sel;
              // TODO: make coh_state_sel flexible / set by instruction, not
              // fixed to next coherence state in MSHR?
              decoded_inst_o.coh_state_sel = e_mux_sel_coh_next_coh_state;

              // if the write_pending bit is set, the ucode instruction will also increment
              // the pending bit for the selected address
              if (op_type_u.pushq.write_pending) begin
                decoded_inst_o.pending_w_v = 1'b1;
                decoded_inst_o.pending_bit = 1'b1;
              end

            end
            e_popq_op: begin
              decoded_inst_o.popq = 1'b1;
              decoded_inst_o.popq_qsel = op_type_u.popq.src_q;
              unique case (op_type_u.popq.src_q)
                e_src_q_sel_lce_req: begin
                  decoded_inst_o.lce_req_yumi = 1'b1;
                  decoded_inst_o.addr_sel = e_mux_sel_addr_lce_req;
                end
                e_src_q_sel_lce_resp: begin
                  decoded_inst_o.lce_resp_yumi = 1'b1;
                  decoded_inst_o.addr_sel = e_mux_sel_addr_lce_resp;
                end
                e_src_q_sel_mem_rev: begin
                  decoded_inst_o.mem_rev_yumi = 1'b1;
                  decoded_inst_o.addr_sel = e_mux_sel_addr_mem_rev;
                end
                e_src_q_sel_pending: begin
                  decoded_inst_o.pending_yumi = 1'b0;
                  decoded_inst_o.addr_sel = e_mux_sel_addr_pending;
                end
                default: begin
                end
              endcase

              // if the write_pending bit is set, the ucode instruction will also increment or
              // decrement the pending bit for the selected address if the action is a pop
              // or push instruction, respectively.
              if (op_type_u.popq.write_pending) begin
                decoded_inst_o.pending_w_v = 1'b1;
                // increment pending bit on request pop
                if (decoded_inst_o.lce_req_yumi | decoded_inst_o.pending_yumi) begin
                  decoded_inst_o.pending_bit = 1'b1;
                end
                // decrement pending bit on response pop
                else begin
                  decoded_inst_o.pending_bit = 1'b0;
                end
              end

            end
            e_poph_op: begin
              decoded_inst_o.poph = 1'b1;
              decoded_inst_o.popq_qsel = op_type_u.popq.src_q;
              decoded_inst_o.src_a_sel = e_src_sel_queue;
              unique case (op_type_u.popq.src_q)
                e_src_q_sel_lce_resp: begin
                  decoded_inst_o.src_a.q = e_opd_lce_resp_type;
                  decoded_inst_o.dst_sel = e_dst_sel_gpr;
                  decoded_inst_o.dst.gpr = op_type_u.popq.dst;
                  decoded_inst_o.gpr_w_v[op_type_u.popq.dst[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
                  // Note: popping lce response does not write the LCE, address, or data length
                  // fields in the MSHR.
                  decoded_inst_o.flag_w_v = e_flag_nwbf;
                end
                e_src_q_sel_mem_rev: begin
                  decoded_inst_o.src_a.q = e_opd_mem_rev_type;
                  decoded_inst_o.dst_sel = e_dst_sel_gpr;
                  decoded_inst_o.dst.gpr = op_type_u.popq.dst;
                  decoded_inst_o.gpr_w_v[op_type_u.popq.dst[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
                  // Note: popping mem response does not write the LCE, address, or next coherence
                  // state fields in the MSHR.
                  decoded_inst_o.flag_w_v = e_flag_sf;
                end
                e_src_q_sel_lce_req: begin
                  decoded_inst_o.lce_w_v = 1'b1;
                  decoded_inst_o.addr_w_v = 1'b1;
                  decoded_inst_o.lru_way_w_v = 1'b1;
                  decoded_inst_o.msg_size_w_v = 1'b1;
                  decoded_inst_o.flag_w_v = (e_flag_rqf | e_flag_nerf | e_flag_ucf | e_flag_rcf);
                end
                default: begin
                  decoded_inst_o.src_a.q = e_opd_lce_resp_type;
                end
              endcase
            end
            e_popd_op: begin
              // TODO: add full support when removing message deserialization
              // pop 64-bits of data from src_q to a GPR
              decoded_inst_o.popd = 1'b1;
              decoded_inst_o.popq_qsel = op_type_u.popq.src_q;
              decoded_inst_o.src_a_sel = e_src_sel_queue;
              decoded_inst_o.dst_sel = e_dst_sel_gpr;
              decoded_inst_o.dst.gpr = op_type_u.popq.dst;
              decoded_inst_o.gpr_w_v[op_type_u.popq.dst[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
              unique case (op_type_u.popq.src_q)
                e_src_q_sel_lce_resp: begin
                  decoded_inst_o.src_a.q = e_opd_lce_resp_data;
                end
                e_src_q_sel_mem_rev: begin
                  decoded_inst_o.src_a.q = e_opd_mem_rev_data;
                end
                e_src_q_sel_lce_req: begin
                  decoded_inst_o.src_a.q = e_opd_lce_req_data;
                end
                default: begin
                  decoded_inst_o.src_a.q = e_opd_lce_resp_data;
                end
              endcase

            end
            e_specq_op: begin

              decoded_inst_o.addr_sel = op_type_u.stype.addr_sel;

              // specq instructions manipulate all of the spec_bits
              unique case (op_type_u.stype.cmd)
                // set pending bit, clear all others
                e_spec_set: begin
                  decoded_inst_o.spec_w_v = 1'b1;
                  decoded_inst_o.spec_v = 1'b1;
                  decoded_inst_o.spec_squash_v = 1'b1;
                  decoded_inst_o.spec_fwd_mod_v = 1'b1;
                  decoded_inst_o.spec_state_v = 1'b1;
                  decoded_inst_o.spec_bits.spec = 1'b1;
                end
                // clear all bits
                e_spec_unset: begin
                  decoded_inst_o.spec_w_v = 1'b1;
                  decoded_inst_o.spec_v = 1'b1;
                  decoded_inst_o.spec_squash_v = 1'b1;
                  decoded_inst_o.spec_fwd_mod_v = 1'b1;
                  decoded_inst_o.spec_state_v = 1'b1;
                end
                // set squash bit, clear all others
                e_spec_squash: begin
                  decoded_inst_o.spec_w_v = 1'b1;
                  decoded_inst_o.spec_v = 1'b1;
                  decoded_inst_o.spec_squash_v = 1'b1;
                  decoded_inst_o.spec_fwd_mod_v = 1'b1;
                  decoded_inst_o.spec_state_v = 1'b1;
                  decoded_inst_o.spec_bits.squash = 1'b1;
                end
                // set fwd_mod bit and state field, clear spec and squash bits
                e_spec_fwd_mod: begin
                  decoded_inst_o.spec_w_v = 1'b1;
                  decoded_inst_o.spec_v = 1'b1;
                  decoded_inst_o.spec_squash_v = 1'b1;
                  decoded_inst_o.spec_fwd_mod_v = 1'b1;
                  decoded_inst_o.spec_state_v = 1'b1;
                  decoded_inst_o.spec_bits.fwd_mod = 1'b1;
                  decoded_inst_o.spec_bits.state = op_type_u.stype.state;
                end
                // read spec bit to spec flag in MSHR
                // speculative bit from bp_cce_spec_bits is sent to bp_cce_reg and used as source
                // for spec flag
                e_spec_rd_spec: begin
                  decoded_inst_o.spec_r_v = 1'b1;
                  decoded_inst_o.flag_w_v[e_opd_sf] = 1'b1;
                end
                default: begin
                  // shouldn't reach here unless bad instruction
                  decoded_inst_o.spec_w_v = 1'b0;
                end
              endcase
            end
            e_inv_op: begin
              // invalidate op consumes sharers hits and sharers ways
              // message unit is hard-coded to handle invalidate op
              decoded_inst_o.inv_cmd_v = 1'b1;
              decoded_inst_o.addr_sel = e_mux_sel_addr_mshr_req;
            end
            default: begin
            end
          endcase
        end // queue operations

        // Default for operation type - invalid instruction goes here
        default: begin
        end
      endcase // op type
    end // instruction valid
  end // always_comb

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_inst_decode)
