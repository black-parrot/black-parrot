/**
 *
 * Name:
 *   bp_me_nonsynth_cce_inst_tracer.v
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_cce_inst_tracer
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , localparam cce_inst_trace_file_p = "cce_inst"

    `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
  )
  (input                        clk_i
   , input                      reset_i
   , input [cce_id_width_p-1:0] cce_id_i
   , input [cce_pc_width_p-1:0] pc_i
   , input                      instruction_v_i
   , input bp_cce_inst_s        instruction_i
   , input                      stall_i
  );

  integer file;
  string file_name;

  always_ff @(negedge reset_i) begin
    file_name = $sformatf("%s_%x.trace", cce_inst_trace_file_p, cce_id_i);
    file      = $fopen(file_name, "w");
    $fwrite(file, "CCE Instruction Trace for CCE[%x]\n", cce_id_i);
    $fwrite(file, "Time,PC,Valid,Op,MinorOp,InstructionBits,Assembly\n");
  end

  always_ff @(negedge clk_i) begin
    if (~reset_i & instruction_v_i & ~stall_i) begin
      $fwrite(file, "%0t,%H,%b,%b,%b,%b,", $time, pc_i, instruction_v_i
              , instruction_i.op, instruction_i.minor_op_u, instruction_i.type_u);
      case(instruction_i.op)
        e_op_alu: begin
          case(instruction_i.minor_op_u)
            e_add_op: begin
              $fwrite(file, "add");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_sub_op: begin
              $fwrite(file, "sub");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_lsh_op: begin
              $fwrite(file, "lsh");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_rsh_op: begin
              $fwrite(file, "rsh");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_and_op: begin
              $fwrite(file, "and");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_or_op: begin
              $fwrite(file, "or");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_xor_op: begin
              $fwrite(file, "xor");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_neg_op: begin
              $fwrite(file, "neg");
              $fwrite(file, " r%0d r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_addi_op: begin
              $fwrite(file, "addi");
              $fwrite(file, " r%0d 0x%X r%0d", instruction_i.type_u.itype.src_a, instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_subi_op: begin
              $fwrite(file, "subi");
              $fwrite(file, " r%0d 0x%X r%0d", instruction_i.type_u.itype.src_a, instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_lshi_op: begin
              $fwrite(file, "lshi");
              $fwrite(file, " r%0d 0x%X r%0d", instruction_i.type_u.itype.src_a, instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_rshi_op: begin
              $fwrite(file, "rshi");
              $fwrite(file, " r%0d 0x%X r%0d", instruction_i.type_u.itype.src_a, instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_not_op: begin
              $fwrite(file, "not");
              $fwrite(file, " r%0d", instruction_i.type_u.rtype.dst);
            end
            default: $fwrite(file, "invalid op");
          endcase
        end
        e_op_branch:  begin
          case(instruction_i.minor_op_u)
            e_beq_op: begin
              $fwrite(file, "beq");
              $fwrite(file, " r%0d r%0d 0x%X", instruction_i.type_u.btype.src_a, instruction_i.type_u.btype.src_b, instruction_i.type_u.btype.target); //btype
            end
            e_bne_op: begin
              $fwrite(file, "bne");
              $fwrite(file, " r%0d r%0d 0x%X", instruction_i.type_u.btype.src_a, instruction_i.type_u.btype.src_b, instruction_i.type_u.btype.target); //btype
            end
            e_blt_op: begin
              $fwrite(file, "blt");
              $fwrite(file, " r%0d r%0d 0x%X", instruction_i.type_u.btype.src_a, instruction_i.type_u.btype.src_b, instruction_i.type_u.btype.target); //btype
            end
            e_ble_op: begin
              $fwrite(file, "ble");
              $fwrite(file, " r%0d r%0d 0x%X", instruction_i.type_u.btype.src_a, instruction_i.type_u.btype.src_b, instruction_i.type_u.btype.target); //btype
            end
            e_bs_op: begin
              $fwrite(file, "bs");
              $fwrite(file, " rs%0d r%0d 0x%X", instruction_i.type_u.btype.src_a, instruction_i.type_u.btype.src_b, instruction_i.type_u.btype.target); //btype
            end
            e_bss_op: begin
              $fwrite(file, "bss");
              $fwrite(file, " rs%0d rs%0d 0x%X", instruction_i.type_u.btype.src_a, instruction_i.type_u.btype.src_b, instruction_i.type_u.btype.target); //btype
            end
            e_beqi_op: begin
              $fwrite(file, "beqi");
              $fwrite(file, " r%0d 0x%X 0x%X", instruction_i.type_u.bitype.src_a, instruction_i.type_u.bitype.imm, instruction_i.type_u.bitype.target); //bitype
            end
            e_bneqi_op: begin
              $fwrite(file, "bneqi");
              $fwrite(file, " r%0d 0x%X 0x%X", instruction_i.type_u.bitype.src_a, instruction_i.type_u.bitype.imm, instruction_i.type_u.bitype.target); //bitype
            end
            e_bsi_op: begin
              $fwrite(file, "bsi");
              $fwrite(file, " rs%0d 0x%X 0x%X", instruction_i.type_u.bitype.src_a, instruction_i.type_u.bitype.imm, instruction_i.type_u.bitype.target); //bitype
            end
            default: $fwrite(file, "invalid op");
          endcase
        end
        e_op_reg_data: begin
          case(instruction_i.minor_op_u)
            e_mov_op: begin
              $fwrite(file, "mov");
              $fwrite(file, " r%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movsg_op: begin
              $fwrite(file, "movsg");
              $fwrite(file, " rs%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movgs_op: begin
              $fwrite(file, "movgs");
              $fwrite(file, " r%0d rs%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movfg_op: begin
              $fwrite(file, "movfg");
              $fwrite(file, " f%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movgf_op: begin
              $fwrite(file, "movgf");
              $fwrite(file, " r%0d f%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movpg_op: begin
              $fwrite(file, "movpg");
              $fwrite(file, " p%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movgp_op: begin
              $fwrite(file, "movgp");
              $fwrite(file, " r%0d p%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_movi_op: begin
              $fwrite(file, "movi");
              $fwrite(file, " 0x%X r%0d",instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_movis_op: begin
              $fwrite(file, "movis");
              $fwrite(file, " 0x%X rs%0d",instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_movip_op: begin
              $fwrite(file, "movip");
              $fwrite(file, " 0x%X r%0d",instruction_i.type_u.itype.imm, instruction_i.type_u.itype.dst); //itype
            end
            e_clm_op: begin
              $fwrite(file, "clm");
              //no arguments
            end
            default: $fwrite(file, "invalid op");
          endcase
        end
        e_op_flag: begin
          case(instruction_i.minor_op_u)
            e_sf_op: begin
              $fwrite(file, "sf");
              $fwrite(file, " f%X",instruction_i.type_u.itype.imm); //itype
            end
            e_andf_op: begin
              $fwrite(file, "andf");
              $fwrite(file, " f%0d f%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_orf_op: begin
              $fwrite(file, "orf");
              $fwrite(file, " f%0d f%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_nandf_op: begin
              $fwrite(file, "nandf");
              $fwrite(file, " f%0d f%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_norf_op: begin
              $fwrite(file, "norf");
              $fwrite(file, " f%0d f%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.src_b, instruction_i.type_u.rtype.dst); //rtype
            end
            e_notf_op: begin
              $fwrite(file, "notf");
              $fwrite(file, " f%0d r%0d", instruction_i.type_u.rtype.src_a, instruction_i.type_u.rtype.dst); //rtype
            end
            e_bf_op: begin
              $fwrite(file, "bf");
              $fwrite(file, " 0x%X f%0d", instruction_i.type_u.bftype.target, instruction_i.type_u.bftype.imm); //bftype
            end
            e_bfz_op: begin
              $fwrite(file, "bfz");
              $fwrite(file, " 0x%X f%0d", instruction_i.type_u.bftype.target, instruction_i.type_u.bftype.imm); //bftype
            end
            e_bfnz_op: begin
              $fwrite(file, "bfnz");
              $fwrite(file, " 0x%X f%0d", instruction_i.type_u.bftype.target, instruction_i.type_u.bftype.imm); //bftype
            end
            e_bfnot_op: begin
              $fwrite(file, "bfnot");
              $fwrite(file, " 0x%X f%0d", instruction_i.type_u.bftype.target, instruction_i.type_u.bftype.imm); //bftype
            end
            default: $fwrite(file, "invalid op");
          endcase
        end
        e_op_dir: begin
          case(instruction_i.minor_op_u)
            e_rdp_op: begin
              $fwrite(file, "rdp");
              $fwrite(file, " addr=%0d", instruction_i.type_u.dptype.addr_sel); //dptype
            end
            e_rdw_op: begin
              $fwrite(file, "rdw");
              $fwrite(file, " addr=%0d lce=%0d lru_way=%0d dst=%0d", instruction_i.type_u.drtype.addr_sel, instruction_i.type_u.drtype.lce_sel, instruction_i.type_u.drtype.lru_way_sel, instruction_i.type_u.drtype.dst); //drtype
            end
            e_rde_op: begin
              $fwrite(file, "rde");
              $fwrite(file, " addr=%0d lce=%0d way=%0d dst=%0d", instruction_i.type_u.drtype.addr_sel, instruction_i.type_u.drtype.lce_sel, instruction_i.type_u.drtype.way_sel, instruction_i.type_u.drtype.dst); //drtype
            end
            e_wdp_op: begin
              $fwrite(file, "wdp");
              $fwrite(file, " addr=%0d p=%0d", instruction_i.type_u.dptype.addr_sel, instruction_i.type_u.dptype.pending); //dptype
            end
            e_clp_op: begin
              $fwrite(file, "clp");
              $fwrite(file, " addr=%0d", instruction_i.type_u.dptype.addr_sel); //dptype
            end
            e_clr_op: begin
              $fwrite(file, "clr");
              $fwrite(file, " addr=%0d lce=%0d", instruction_i.type_u.drtype.addr_sel, instruction_i.type_u.drtype.lce_sel); //drtype
            end
            e_wde_op: begin
              $fwrite(file, "wde");
              $fwrite(file, " addr=%0d lce=%0d way=%0d state=%0d", instruction_i.type_u.dwtype.addr_sel, instruction_i.type_u.dwtype.lce_sel, instruction_i.type_u.dwtype.way_sel, instruction_i.type_u.dwtype.state); //dwtype
            end
            e_wds_op: begin
              $fwrite(file, "wds");
              $fwrite(file, " addr=%0d lce=%0d way=%0d state=%0d", instruction_i.type_u.dwtype.addr_sel, instruction_i.type_u.dwtype.lce_sel, instruction_i.type_u.dwtype.way_sel, instruction_i.type_u.dwtype.state); //dwtype
            end
            e_gad_op: begin
              $fwrite(file, "gad");
              //no arguments
            end
            default: $fwrite(file, "invalid op");
          endcase
        end
        e_op_queue: begin
          case(instruction_i.minor_op_u)
            e_wfq_op: begin
              $fwrite(file, "wfq");
              $fwrite(file, " q%0d", instruction_i.type_u.itype.imm); //itype
            end
            e_pushq_op: begin
              $fwrite(file, "pushq");
              $fwrite(file, " q%0d cmd addr=%0d lce=%0d way=%0d wp=%0d spec=%0d", instruction_i.type_u.pushq.dst_q, instruction_i.type_u.pushq.addr_sel, instruction_i.type_u.pushq.lce_sel, instruction_i.type_u.pushq.way_or_size.way_sel, instruction_i.type_u.pushq.write_pending, instruction_i.type_u.pushq.spec); //pushq
            end
            e_popq_op: begin
              $fwrite(file, "popq");
              $fwrite(file, " q%0d", instruction_i.type_u.popq.src_q); //popq
            end
            e_poph_op: begin
              $fwrite(file, "poph");
              $fwrite(file, " q%0d r%0d", instruction_i.type_u.popq.src_q, instruction_i.type_u.popq.dst); //popq
            end
            e_popd_op: begin
              $fwrite(file, "popd");
              $fwrite(file, " q%0d r%0d", instruction_i.type_u.popq.src_q, instruction_i.type_u.popq.dst); //popq
            end
            e_specq_op: begin
              $fwrite(file, "specq ");
              case(instruction_i.type_u.stype.cmd)
                e_spec_set: $fwrite(file, "spec_set");
                e_spec_unset: $fwrite(file, "spec_unset");
                e_spec_squash: $fwrite(file, "spec_squash");
                e_spec_fwd_mod: $fwrite(file, "spec_fwd_mod");
                e_spec_rd_spec: $fwrite(file, "spec_rd_spec");
                default: $fwrite(file, "invalid command");
              endcase
              $fwrite(file, " %0d", instruction_i.type_u.stype.addr_sel);
            end
            e_inv_op: begin
              $fwrite(file, "inv");
              //no arguments
            end
            default: $fwrite(file, "invalid op");
          endcase
        end
        default: $fwrite(file, "invalid op");
      endcase
      $fwrite(file, "\n");
    end // ~reset_i
  end //always_ff

endmodule
