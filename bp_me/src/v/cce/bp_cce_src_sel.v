/**
 *
 * Name:
 *   bp_cce_src_sel.v
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

module bp_cce_src_sel
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam mshr_width_lp             = `bp_cce_mshr_width(lce_id_width_p, lce_assoc_p, paddr_width_p)
    // number of way groups managed by this CCE
    , localparam num_way_groups_lp         = `BSG_CDIV(cce_way_groups_p, num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

    `declare_bp_lce_cce_if_header_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  )
  (// Select signals for src_a and src_b - from decoded instruction
   input bp_cce_inst_src_sel_e                   src_a_sel_i
   , input bp_cce_inst_src_u                     src_a_i
   , input bp_cce_inst_src_sel_e                 src_b_sel_i
   , input bp_cce_inst_src_u                     src_b_i

   // Select signals for functional unit inputs (directory, gad, pending, message, etc.)
   , input bp_cce_inst_mux_sel_addr_e            addr_sel_i
   , input bp_cce_inst_mux_sel_lce_e             lce_sel_i
   , input bp_cce_inst_mux_sel_way_e             way_sel_i
   , input bp_cce_inst_mux_sel_way_e             lru_way_sel_i
   , input bp_cce_inst_mux_sel_coh_state_e       coh_state_sel_i

   // Data sources - from registered data and functional units
   , input [cfg_bus_width_lp-1:0]                                   cfg_bus_i
   , input [mshr_width_lp-1:0]                                      mshr_i
   , input [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_i
   , input [`bp_cce_inst_gpr_width-1:0]                             imm_i
   , input                                                          auto_fwd_msg_i
   , input bp_coh_states_e                                          coh_state_default_i
   , input [num_lce_p-1:0]                                          sharers_hits_i
   , input [num_lce_p-1:0][lce_assoc_width_p-1:0]                   sharers_ways_i
   , input bp_coh_states_e [num_lce_p-1:0]                          sharers_coh_states_i
   , input                                                          mem_resp_v_i
   , input                                                          lce_resp_v_i
   , input                                                          lce_req_v_i
   , input [lce_cce_req_width_lp-1:0]                               lce_req_i
   , input [lce_cce_resp_width_lp-1:0]                              lce_resp_i
   , input [cce_mem_msg_width_lp-1:0]                               mem_resp_i

   // Source A and B outputs
   , output logic [`bp_cce_inst_gpr_width-1:0]   src_a_o
   , output logic [`bp_cce_inst_gpr_width-1:0]   src_b_o

   // FU Select Outputs
   , output logic [paddr_width_p-1:0]            addr_o
   , output logic                                addr_bypass_o
   , output logic [lce_id_width_p-1:0]           lce_o
   , output logic [lce_assoc_width_p-1:0]        way_o
   , output logic [lce_assoc_width_p-1:0]        lru_way_o
   , output bp_coh_states_e                      state_o
  );

  //synopsys translate_off
  initial begin
    assert(`bp_cce_inst_gpr_width == dword_width_p)
      else $error("GPR width and dword_width_p must be same in CCE");
  end
  //synopsys translate_on

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast;
  assign cfg_bus_cast = cfg_bus_i;

  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr;
  assign mshr = mshr_i;

  // LCE-CCE and Mem-CCE Interface
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  // Message casting
  bp_lce_cce_req_s  lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_cce_mem_msg_s  mem_resp;
  assign lce_req   = lce_req_i;
  assign lce_resp  = lce_resp_i;
  assign mem_resp  = mem_resp_i;

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
      e_src_sel_flag: begin
        unique case (src_a_i.flag)
          e_opd_rqf:  src_a_o[0] = mshr.flags[e_opd_rqf];
          e_opd_ucf:  src_a_o[0] = mshr.flags[e_opd_ucf];
          e_opd_nerf: src_a_o[0] = mshr.flags[e_opd_nerf];
          e_opd_nwbf: src_a_o[0] = mshr.flags[e_opd_nwbf];
          e_opd_pf:   src_a_o[0] = mshr.flags[e_opd_pf];
          e_opd_sf:   src_a_o[0] = mshr.flags[e_opd_sf];
          e_opd_csf:  src_a_o[0] = mshr.flags[e_opd_csf];
          e_opd_cef:  src_a_o[0] = mshr.flags[e_opd_cef];
          e_opd_cmf:  src_a_o[0] = mshr.flags[e_opd_cmf];
          e_opd_cof:  src_a_o[0] = mshr.flags[e_opd_cof];
          e_opd_cff:  src_a_o[0] = mshr.flags[e_opd_cff];
          e_opd_rf:   src_a_o[0] = mshr.flags[e_opd_rf];
          e_opd_uf:   src_a_o[0] = mshr.flags[e_opd_uf];
          default:    src_a_o    = '0;
        endcase
      end
      e_src_sel_special: begin
        unique case (src_a_i.special)
          e_opd_req_lce:        src_a_o[0+:lce_id_width_p] = mshr.lce_id;
          e_opd_req_addr:       src_a_o[0+:paddr_width_p] = mshr.paddr;
          e_opd_req_way:        src_a_o[0+:lce_assoc_width_p] = mshr.way_id;
          e_opd_lru_addr:       src_a_o[0+:paddr_width_p] = mshr.lru_paddr;
          e_opd_lru_way:        src_a_o[0+:lce_assoc_width_p] = mshr.lru_way_id;
          e_opd_owner_lce:      src_a_o[0+:lce_id_width_p] = mshr.owner_lce_id;
          e_opd_owner_way:      src_a_o[0+:lce_assoc_width_p] = mshr.owner_way_id;
          e_opd_next_coh_state: src_a_o[0+:$bits(bp_coh_states_e)] = mshr.next_coh_state;
          e_opd_flags:          src_a_o[0+:`bp_cce_inst_num_flags] = mshr.flags;
          e_opd_msg_size:       src_a_o[0+:$bits(bp_mem_msg_size_e)] = mshr.msg_size;
          e_opd_lru_coh_state:  src_a_o[0+:$bits(bp_coh_states_e)] = mshr.lru_coh_state;
          e_opd_flags_and_mask: src_a_o[0+:`bp_cce_inst_num_flags] = mshr.flags & imm_i[0+:`bp_cce_inst_num_flags];
          e_opd_sharers_hit:    src_a_o[0] = sharers_hits_i[gpr_i[src_b_i.gpr[0+:`bp_cce_inst_gpr_sel_width]]];
          e_opd_sharers_way:    src_a_o[0+:lce_assoc_width_p] = sharers_ways_i[gpr_i[src_b_i.gpr[0+:`bp_cce_inst_gpr_sel_width]]];
          e_opd_sharers_state:  src_a_o[0+:$bits(bp_coh_states_e)] = sharers_coh_states_i[gpr_i[src_b_i.gpr[0+:`bp_cce_inst_gpr_sel_width]]];
          default:              src_a_o = '0;
        endcase
      end
      e_src_sel_param: begin
        unique case (src_a_i.param)
          e_opd_cce_id:            src_a_o[0+:cce_id_width_p] = cfg_bus_cast.cce_id;
          e_opd_num_lce:           src_a_o[0+:lce_id_width_p] = num_lce_p[0+:lce_id_width_p+1];
          e_opd_num_cce:           src_a_o[0+:cce_id_width_p] = num_cce_p[0+:cce_id_width_p+1];
          e_opd_num_wg:            src_a_o[0+:lg_num_way_groups_lp] = num_way_groups_lp[0+:lg_num_way_groups_lp];
          e_opd_auto_fwd_msg:      src_a_o[0] = auto_fwd_msg_i;
          e_opd_coh_state_default: src_a_o[0+:$bits(bp_coh_states_e)] = coh_state_default_i;
          default:                 src_a_o = '0;
        endcase
      end
      e_src_sel_queue: begin
        unique case (src_a_i.q)
          e_opd_mem_resp_v:    src_a_o[0] = mem_resp_v_i;
          e_opd_lce_resp_v:    src_a_o[0] = lce_resp_v_i;
          e_opd_pending_v:     src_a_o = '0;
          e_opd_lce_req_v:     src_a_o[0] = lce_req_v_i;
          e_opd_lce_resp_type: src_a_o[0+:$bits(bp_lce_cce_resp_type_e)] = lce_resp.header.msg_type;
          e_opd_mem_resp_type: src_a_o[0+:$bits(bp_cce_mem_cmd_type_e)] = mem_resp.header.msg_type;
          e_opd_lce_resp_data: src_a_o = lce_resp.data[0+:dword_width_p];
          e_opd_mem_resp_data: src_a_o = mem_resp.data[0+:dword_width_p];
          e_opd_lce_req_data:  src_a_o = lce_req.data[0+:dword_width_p];
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
      e_src_sel_flag: begin
        unique case (src_b_i.flag)
          e_opd_rqf:  src_b_o[0] = mshr.flags[e_opd_rqf];
          e_opd_ucf:  src_b_o[0] = mshr.flags[e_opd_ucf];
          e_opd_nerf: src_b_o[0] = mshr.flags[e_opd_nerf];
          e_opd_nwbf: src_b_o[0] = mshr.flags[e_opd_nwbf];
          e_opd_pf:   src_b_o[0] = mshr.flags[e_opd_pf];
          e_opd_sf:   src_b_o[0] = mshr.flags[e_opd_sf];
          e_opd_csf:  src_b_o[0] = mshr.flags[e_opd_csf];
          e_opd_cef:  src_b_o[0] = mshr.flags[e_opd_cef];
          e_opd_cmf:  src_b_o[0] = mshr.flags[e_opd_cmf];
          e_opd_cof:  src_b_o[0] = mshr.flags[e_opd_cof];
          e_opd_cff:  src_b_o[0] = mshr.flags[e_opd_cff];
          e_opd_rf:   src_b_o[0] = mshr.flags[e_opd_rf];
          e_opd_uf:   src_b_o[0] = mshr.flags[e_opd_uf];
          default:    src_b_o    = '0;
        endcase
      end
      e_src_sel_special: begin
        unique case (src_b_i.special)
          e_opd_req_lce:        src_b_o[0+:lce_id_width_p] = mshr.lce_id;
          e_opd_req_addr:       src_b_o[0+:paddr_width_p] = mshr.paddr;
          e_opd_req_way:        src_b_o[0+:lce_assoc_width_p] = mshr.way_id;
          e_opd_lru_addr:       src_b_o[0+:paddr_width_p] = mshr.lru_paddr;
          e_opd_lru_way:        src_b_o[0+:lce_assoc_width_p] = mshr.lru_way_id;
          e_opd_owner_lce:      src_b_o[0+:lce_id_width_p] = mshr.owner_lce_id;
          e_opd_owner_way:      src_b_o[0+:lce_assoc_width_p] = mshr.owner_way_id;
          e_opd_next_coh_state: src_b_o[0+:$bits(bp_coh_states_e)] = mshr.next_coh_state;
          e_opd_flags:          src_b_o[0+:`bp_cce_inst_num_flags] = mshr.flags;
          e_opd_msg_size:       src_b_o[0+:$bits(bp_mem_msg_size_e)] = mshr.msg_size;
          e_opd_lru_coh_state:  src_b_o[0+:$bits(bp_coh_states_e)] = mshr.lru_coh_state;
          e_opd_flags_and_mask: src_b_o[0+:`bp_cce_inst_num_flags] = mshr.flags & imm_i[0+:`bp_cce_inst_num_flags];
          // Sharers vectors as source b is not supported
          //e_opd_sharers_hit:
          //e_opd_sharers_way:
          //e_opd_sharers_state:
          default:              src_b_o = '0;
        endcase
      end
      e_src_sel_param: begin
        unique case (src_b_i.param)
          e_opd_cce_id:            src_b_o[0+:cce_id_width_p] = cfg_bus_cast.cce_id;
          e_opd_num_lce:           src_b_o[0+:lce_id_width_p] = num_lce_p[0+:lce_id_width_p+1];
          e_opd_num_cce:           src_b_o[0+:cce_id_width_p] = num_cce_p[0+:cce_id_width_p+1];
          e_opd_num_wg:            src_b_o[0+:lg_num_way_groups_lp] = num_way_groups_lp[0+:lg_num_way_groups_lp];
          e_opd_auto_fwd_msg:      src_b_o[0] = auto_fwd_msg_i;
          e_opd_coh_state_default: src_b_o[0+:$bits(bp_coh_states_e)] = coh_state_default_i;
          default:                 src_b_o = '0;
        endcase
      end
      e_src_sel_queue: begin
        unique case (src_b_i.q)
          e_opd_mem_resp_v:    src_b_o[0] = mem_resp_v_i;
          e_opd_lce_resp_v:    src_b_o[0] = lce_resp_v_i;
          e_opd_pending_v:     src_b_o = '0;
          e_opd_lce_req_v:     src_b_o[0] = lce_req_v_i;
          e_opd_lce_resp_type: src_b_o[0+:$bits(bp_lce_cce_resp_type_e)] = lce_resp.header.msg_type;
          e_opd_mem_resp_type: src_b_o[0+:$bits(bp_cce_mem_cmd_type_e)] = mem_resp.header.msg_type;
          e_opd_lce_resp_data: src_b_o = lce_resp.data[0+:dword_width_p];
          e_opd_mem_resp_data: src_b_o = mem_resp.data[0+:dword_width_p];
          e_opd_lce_req_data:  src_b_o = lce_req.data[0+:dword_width_p];
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

    // addr_sel
    unique case (addr_sel_i)
      e_mux_sel_addr_r0:       addr_o = gpr_i[e_opd_r0][0+:paddr_width_p];
      e_mux_sel_addr_r1:       addr_o = gpr_i[e_opd_r1][0+:paddr_width_p];
      e_mux_sel_addr_r2:       addr_o = gpr_i[e_opd_r2][0+:paddr_width_p];
      e_mux_sel_addr_r3:       addr_o = gpr_i[e_opd_r3][0+:paddr_width_p];
      e_mux_sel_addr_r4:       addr_o = gpr_i[e_opd_r4][0+:paddr_width_p];
      e_mux_sel_addr_r5:       addr_o = gpr_i[e_opd_r5][0+:paddr_width_p];
      e_mux_sel_addr_r6:       addr_o = gpr_i[e_opd_r6][0+:paddr_width_p];
      e_mux_sel_addr_r7:       addr_o = gpr_i[e_opd_r7][0+:paddr_width_p];
      e_mux_sel_addr_mshr_req: addr_o = mshr.paddr;
      e_mux_sel_addr_mshr_lru: addr_o = mshr.lru_paddr;
      e_mux_sel_addr_lce_req:  addr_o = lce_req.header.addr;
      e_mux_sel_addr_lce_resp: addr_o = lce_resp.header.addr;
      e_mux_sel_addr_mem_resp: addr_o = mem_resp.header.addr;
      e_mux_sel_addr_pending:  addr_o = '0;
      e_mux_sel_addr_0:        addr_o = '0;
      default:                 addr_o = '0;
    endcase

    // address bypass - only for GPR or constant 0 as source
    unique case (addr_sel_i)
      e_mux_sel_addr_r0, e_mux_sel_addr_r1, e_mux_sel_addr_r2, e_mux_sel_addr_r3
      ,e_mux_sel_addr_r4, e_mux_sel_addr_r5, e_mux_sel_addr_r6, e_mux_sel_addr_r7
      , e_mux_sel_addr_0:  addr_bypass_o = 1'b1;
      default:             addr_bypass_o = 1'b0;
    endcase

    // lce_sel
    unique case (lce_sel_i)
      e_mux_sel_lce_r0:         lce_o = gpr_i[e_opd_r0][0+:lce_id_width_p];
      e_mux_sel_lce_r1:         lce_o = gpr_i[e_opd_r1][0+:lce_id_width_p];
      e_mux_sel_lce_r2:         lce_o = gpr_i[e_opd_r2][0+:lce_id_width_p];
      e_mux_sel_lce_r3:         lce_o = gpr_i[e_opd_r3][0+:lce_id_width_p];
      e_mux_sel_lce_r4:         lce_o = gpr_i[e_opd_r4][0+:lce_id_width_p];
      e_mux_sel_lce_r5:         lce_o = gpr_i[e_opd_r5][0+:lce_id_width_p];
      e_mux_sel_lce_r6:         lce_o = gpr_i[e_opd_r6][0+:lce_id_width_p];
      e_mux_sel_lce_r7:         lce_o = gpr_i[e_opd_r7][0+:lce_id_width_p];
      e_mux_sel_lce_mshr_req:   lce_o = mshr.lce_id;
      e_mux_sel_lce_mshr_owner: lce_o = mshr.owner_lce_id;
      e_mux_sel_lce_lce_req:    lce_o = lce_req.header.src_id;
      e_mux_sel_lce_lce_resp:   lce_o = lce_resp.header.src_id;
      e_mux_sel_lce_mem_resp:   lce_o = mem_resp.header.payload.lce_id;
      e_mux_sel_lce_pending:    lce_o = '0;
      e_mux_sel_lce_0:          lce_o = '0;
      default:                  lce_o = '0;
    endcase

    // way_sel
    unique case (way_sel_i)
      e_mux_sel_way_r0:         way_o = gpr_i[e_opd_r0][0+:lce_assoc_width_p];
      e_mux_sel_way_r1:         way_o = gpr_i[e_opd_r1][0+:lce_assoc_width_p];
      e_mux_sel_way_r2:         way_o = gpr_i[e_opd_r2][0+:lce_assoc_width_p];
      e_mux_sel_way_r3:         way_o = gpr_i[e_opd_r3][0+:lce_assoc_width_p];
      e_mux_sel_way_r4:         way_o = gpr_i[e_opd_r4][0+:lce_assoc_width_p];
      e_mux_sel_way_r5:         way_o = gpr_i[e_opd_r5][0+:lce_assoc_width_p];
      e_mux_sel_way_r6:         way_o = gpr_i[e_opd_r6][0+:lce_assoc_width_p];
      e_mux_sel_way_r7:         way_o = gpr_i[e_opd_r7][0+:lce_assoc_width_p];
      e_mux_sel_way_mshr_req:   way_o = mshr.way_id;
      e_mux_sel_way_mshr_owner: way_o = mshr.owner_way_id;
      e_mux_sel_way_mshr_lru:   way_o = mshr.lru_way_id;
      e_mux_sel_way_sh_way:     way_o = sharers_ways_i[gpr_i[src_a_i.gpr[0+:`bp_cce_inst_gpr_sel_width]]];
      e_mux_sel_way_0:          way_o = '0;
      default:                  way_o = '0;
    endcase

    // lru_way_sel
    unique case (lru_way_sel_i)
      e_mux_sel_way_r0:         lru_way_o = gpr_i[e_opd_r0][0+:lce_assoc_width_p];
      e_mux_sel_way_r1:         lru_way_o = gpr_i[e_opd_r1][0+:lce_assoc_width_p];
      e_mux_sel_way_r2:         lru_way_o = gpr_i[e_opd_r2][0+:lce_assoc_width_p];
      e_mux_sel_way_r3:         lru_way_o = gpr_i[e_opd_r3][0+:lce_assoc_width_p];
      e_mux_sel_way_r4:         lru_way_o = gpr_i[e_opd_r4][0+:lce_assoc_width_p];
      e_mux_sel_way_r5:         lru_way_o = gpr_i[e_opd_r5][0+:lce_assoc_width_p];
      e_mux_sel_way_r6:         lru_way_o = gpr_i[e_opd_r6][0+:lce_assoc_width_p];
      e_mux_sel_way_r7:         lru_way_o = gpr_i[e_opd_r7][0+:lce_assoc_width_p];
      e_mux_sel_way_mshr_req:   lru_way_o = mshr.way_id;
      e_mux_sel_way_mshr_owner: lru_way_o = mshr.owner_way_id;
      e_mux_sel_way_mshr_lru:   lru_way_o = mshr.lru_way_id;
      e_mux_sel_way_sh_way:     lru_way_o = sharers_ways_i[gpr_i[src_a_i.gpr[0+:`bp_cce_inst_gpr_sel_width]]];
      e_mux_sel_way_0:          lru_way_o = '0;
      default:                  lru_way_o = '0;
    endcase

    // coh_state_sel
    unique case (coh_state_sel_i)
      e_mux_sel_coh_r0:             state_o = bp_coh_states_e'(gpr_i[e_opd_r0][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r1:             state_o = bp_coh_states_e'(gpr_i[e_opd_r1][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r2:             state_o = bp_coh_states_e'(gpr_i[e_opd_r2][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r3:             state_o = bp_coh_states_e'(gpr_i[e_opd_r3][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r4:             state_o = bp_coh_states_e'(gpr_i[e_opd_r4][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r5:             state_o = bp_coh_states_e'(gpr_i[e_opd_r5][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r6:             state_o = bp_coh_states_e'(gpr_i[e_opd_r6][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_r7:             state_o = bp_coh_states_e'(gpr_i[e_opd_r7][0+:$bits(bp_coh_states_e)]);
      e_mux_sel_coh_next_coh_state: state_o = mshr.next_coh_state;
      e_mux_sel_coh_lru_coh_state:  state_o = mshr.lru_coh_state;
      e_mux_sel_sharer_state:       state_o = sharers_coh_states_i[gpr_i[src_a_i.gpr[0+:$bits(bp_coh_states_e)]]];
      e_mux_sel_coh_inst_imm:       state_o = bp_coh_states_e'(imm_i[0+:$bits(bp_coh_states_e)]);
      default:                      state_o = e_COH_I;
    endcase

  end // always_comb

endmodule
