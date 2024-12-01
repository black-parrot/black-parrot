/**
 *
 * Name:
 *   bp_cce_hybrid_src_sel.sv
 *
 * Description:
 *   Source select module for inputs to ALU, Branch unit, directory, GAD, messages, etc.
 *   This module encapsulates common selection/mux logic so it isn't scattered
 *   about the top level CCE module.
 *
 *   It generates src_a, src_b, addr, lce, way, lru_way, and state signals.
 *
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_src_sel
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)

    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

  )
  (// Select signals for src_a and src_b - from decoded instruction
   input bp_cce_inst_src_sel_e                   src_a_sel_i
   , input bp_cce_inst_src_u                     src_a_i
   , input bp_cce_inst_src_sel_e                 src_b_sel_i
   , input bp_cce_inst_src_u                     src_b_i

   // Data sources - from registered data and functional units
   , input [cfg_bus_width_lp-1:0]                                   cfg_bus_i
   , input [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_i
   , input [`bp_cce_inst_gpr_width-1:0]                             imm_i
   , input                                                          lce_req_v_i
   , input [lce_req_header_width_lp-1:0]                            lce_req_header_i

   // Source A and B outputs
   , output logic [`bp_cce_inst_gpr_width-1:0]   src_a_o
   , output logic [`bp_cce_inst_gpr_width-1:0]   src_b_o
  );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  bp_cfg_bus_s cfg_bus_cast;
  assign cfg_bus_cast = cfg_bus_i;

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  // Message casting
  bp_bedrock_lce_req_header_s  lce_req_header_li;
  assign lce_req_header_li   = lce_req_header_i;

  always_comb begin
    src_a_o = '0;
    unique case (src_a_sel_i)
      e_src_sel_gpr: begin
        unique case (src_a_i.gpr)
          e_opd_r0: src_a_o = gpr_i[e_opd_r0];
          e_opd_r1: src_a_o = gpr_i[e_opd_r1];
          e_opd_r2: src_a_o = gpr_i[e_opd_r2];
          e_opd_r3: src_a_o = gpr_i[e_opd_r3];
          e_opd_r4: src_a_o = gpr_i[e_opd_r4];
          e_opd_r5: src_a_o = gpr_i[e_opd_r5];
          e_opd_r6: src_a_o = gpr_i[e_opd_r6];
          e_opd_r7: src_a_o = gpr_i[e_opd_r7];
          default:  src_a_o = '0;
        endcase
      end
      e_src_sel_param: begin
        unique case (src_a_i.param)
          e_opd_cce_id:            src_a_o[0+:cce_id_width_p] = cfg_bus_cast.cce_id;
          e_opd_num_lce:           src_a_o[0+:lce_id_width_p] = num_lce_p[0+:lce_id_width_p+1];
          e_opd_num_cce:           src_a_o[0+:cce_id_width_p] = num_cce_p[0+:cce_id_width_p+1];
          e_opd_num_wg:            src_a_o[0+:lg_num_way_groups_lp] = num_way_groups_lp[0+:lg_num_way_groups_lp];
          default:                 src_a_o = '0;
        endcase
      end
      e_src_sel_queue: begin
        unique case (src_a_i.q)
          e_opd_lce_req_v:     src_a_o[0] = lce_req_v_i;
          default:             src_a_o = '0;
        endcase
      end
      e_src_sel_imm: begin
        src_a_o = imm_i;
      end
      e_src_sel_zero: begin
        src_a_o = '0;
      end
      default: begin
        src_a_o = '0;
      end
    endcase // src_a

    src_b_o = '0;
    unique case (src_b_sel_i)
      e_src_sel_gpr: begin
        unique case (src_b_i.gpr)
          e_opd_r0: src_b_o = gpr_i[e_opd_r0];
          e_opd_r1: src_b_o = gpr_i[e_opd_r1];
          e_opd_r2: src_b_o = gpr_i[e_opd_r2];
          e_opd_r3: src_b_o = gpr_i[e_opd_r3];
          e_opd_r4: src_b_o = gpr_i[e_opd_r4];
          e_opd_r5: src_b_o = gpr_i[e_opd_r5];
          e_opd_r6: src_b_o = gpr_i[e_opd_r6];
          e_opd_r7: src_b_o = gpr_i[e_opd_r7];
          default:  src_b_o = '0;
        endcase
      end
      e_src_sel_param: begin
        unique case (src_b_i.param)
          e_opd_cce_id:            src_b_o[0+:cce_id_width_p] = cfg_bus_cast.cce_id;
          e_opd_num_lce:           src_b_o[0+:lce_id_width_p] = num_lce_p[0+:lce_id_width_p+1];
          e_opd_num_cce:           src_b_o[0+:cce_id_width_p] = num_cce_p[0+:cce_id_width_p+1];
          e_opd_num_wg:            src_b_o[0+:lg_num_way_groups_lp] = num_way_groups_lp[0+:lg_num_way_groups_lp];
          default:                 src_b_o = '0;
        endcase
      end
      e_src_sel_queue: begin
        unique case (src_b_i.q)
          e_opd_lce_req_v:     src_b_o[0] = lce_req_v_i;
          default:             src_b_o = '0;
        endcase
      end
      e_src_sel_imm: begin
        src_b_o = imm_i;
      end
      e_src_sel_zero: begin
        src_b_o = '0;
      end
      default: src_b_o = '0;
    endcase //src_b
  end // always_comb

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_hybrid_src_sel)
