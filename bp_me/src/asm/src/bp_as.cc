/*
 * bp_as.cc
 *
 * BlackParrot CCE Microcode Assembler
 *
 * Microcode Parsing
 *
 */

#include "bp_as.h"

/*
 * Microcode Assembler Helper Functions
 */

// TODO: add memory operations if supported
bp_cce_inst_op_e
Assembler::getOp(string &s) {
  if (!s.compare("add") || !s.compare("sub") || !s.compare("lsh") || !s.compare("rsh")
      || !s.compare("and") || !s.compare("or") || !s.compare("xor") || !s.compare("neg")
      || !s.compare("addi") || !s.compare("nop") || !s.compare("inc") || !s.compare("subi")
      || !s.compare("dec") || !s.compare("lshi") || !s.compare("rshi") || !s.compare("not")) {
    return e_op_alu;
  } else if (!s.compare("beq") || !s.compare("bi") || !s.compare("bne")
             || !s.compare("blt") || !s.compare("bgt") || !s.compare("ble") || !s.compare("bge")
             || !s.compare("bs") || !s.compare("bss")
             || !s.compare("beqi") || !s.compare("bz") || !s.compare("bneqi") || !s.compare("bnz")
             || !s.compare("bsi")) {
    return e_op_branch;
  } else if (!s.compare("mov") || !s.compare("movsg") || !s.compare("movgs") || !s.compare("ldflags")
             || !s.compare("movfg") || !s.compare("movgf")
             || !s.compare("movpg") || !s.compare("movgp")
             || !s.compare("movi") || !s.compare("movis") || !s.compare("movip")
             || !s.compare("ldflagsi") || !s.compare("clf") || !s.compare("clm")) {
    return e_op_reg_data;
  } else if (!s.compare("sf") || !s.compare("sfz") || !s.compare("andf") || !s.compare("orf")
             || !s.compare("nandf") || !s.compare("norf") || !s.compare("notf")
             || !s.compare("bf") || !s.compare("bfz") || !s.compare("bfnz") || !s.compare("bfnot")) {
    return e_op_flag;
  } else if (!s.compare("rdp") || !s.compare("rdw") || !s.compare("rde")
             || !s.compare("wdp") || !s.compare("clp") || !s.compare("clr")
             || !s.compare("wde") || !s.compare("wds") || !s.compare("cls") || !s.compare("gad")) {
    return e_op_dir;
  } else if (!s.compare("wfq") || !s.compare("pushq") || !s.compare("pushqc") || !s.compare("popq")
             || !s.compare("poph") || !s.compare("specq") || !s.compare("inv") || !s.compare("popd")) {
    return e_op_queue;
  } else {
    printf("Bad Op: %s\n", s.c_str());
    exit(-1);
  }
}

uint8_t
Assembler::getMinorOp(string &s) {
  // ALU
  if (!s.compare("add")) {
    return e_add_op;
  } else if (!s.compare("sub")) {
    return e_sub_op;
  } else if (!s.compare("lsh")) {
    return e_lsh_op;
  } else if (!s.compare("rsh")) {
    return e_rsh_op;
  } else if (!s.compare("and")) {
    return e_and_op;
  } else if (!s.compare("or")) {
    return e_or_op;
  } else if (!s.compare("xor")) {
    return e_xor_op;
  } else if (!s.compare("neg")) {
    return e_neg_op;
  } else if (!s.compare("inc") || !s.compare("addi")|| !s.compare("nop")) {
    return e_addi_op;
  } else if (!s.compare("dec") || !s.compare("subi")) {
    return e_subi_op;
  } else if (!s.compare("lshi")) {
    return e_lshi_op;
  } else if (!s.compare("rshi")) {
    return e_rshi_op;
  } else if (!s.compare("not")) {
    return e_not_op;

  // Branch
  } else if (!s.compare("beq") || !s.compare("bi")) {
    return e_beq_op;
  } else if (!s.compare("bne")) {
    return e_bne_op;
  } else if (!s.compare("blt") || !s.compare("bgt")) {
    return e_blt_op;
  } else if (!s.compare("ble") || !s.compare("bge")) {
    return e_ble_op;
  } else if (!s.compare("beqi") || !s.compare("bz")) {
    return e_beqi_op;
  } else if (!s.compare("bneqi") || !s.compare("bnz")) {
    return e_bneqi_op;
  } else if (!s.compare("bsi")) {
    return e_bsi_op;

  // Reg Data / Move
  } else if (!s.compare("mov")) {
    return e_mov_op;
  } else if (!s.compare("movsg")) {
    return e_movsg_op;
  } else if (!s.compare("movgs") || !s.compare("ldflags")) {
    return e_movgs_op;
  } else if (!s.compare("movfg")) {
    return e_movfg_op;
  } else if (!s.compare("movgf")) {
    return e_movgf_op;
  } else if (!s.compare("movpg")) {
    return e_movpg_op;
  } else if (!s.compare("movgp")) {
    return e_movgp_op;
  } else if (!s.compare("movi")) {
    return e_movi_op;
  } else if (!s.compare("movis") || !s.compare("ldflagsi") || !s.compare("clf")) {
    return e_movis_op;
  } else if (!s.compare("movip")) {
    return e_movip_op;
  } else if (!s.compare("clm")) {
    return e_clm_op;

  // Flag
  } else if (!s.compare("sf") || !s.compare("sfz")) {
    return e_sf_op;
  } else if (!s.compare("andf")) {
    return e_andf_op;
  } else if (!s.compare("orf")) {
    return e_orf_op;
  } else if (!s.compare("nandf")) {
    return e_nandf_op;
  } else if (!s.compare("norf")) {
    return e_norf_op;
  } else if (!s.compare("andf")) {
    return e_andf_op;
  } else if (!s.compare("notf")) {
    return e_notf_op;
  } else if (!s.compare("bf")) {
    return e_bf_op;
  } else if (!s.compare("bfz")) {
    return e_bfz_op;
  } else if (!s.compare("bfnz")) {
    return e_bfnz_op;
  } else if (!s.compare("bfnot")) {
    return e_bfnot_op;

  // Directory
  } else if (!s.compare("rdp")) {
    return e_rdp_op;
  } else if (!s.compare("rdw")) {
    return e_rdw_op;
  } else if (!s.compare("rde")) {
    return e_rde_op;
  } else if (!s.compare("wdp")) {
    return e_wdp_op;
  } else if (!s.compare("clp")) {
    return e_clp_op;
  } else if (!s.compare("clr")) {
    return e_clr_op;
  } else if (!s.compare("wde")) {
    return e_wde_op;
  } else if (!s.compare("wds")) {
    return e_wds_op;
  } else if (!s.compare("gad")) {
    return e_gad_op;

  // Queue
  } else if (!s.compare("wfq")) {
    return e_wfq_op;
  } else if (!s.compare("pushq") || !s.compare("pushqc")) {
    return e_pushq_op;
  } else if (!s.compare("popq")) {
    return e_popq_op;
  } else if (!s.compare("poph")) {
    return e_poph_op;
  } else if (!s.compare("popd")) {
    return e_popd_op;
  } else if (!s.compare("specq")) {
    return e_specq_op;
  } else if (!s.compare("inv")) {
    return e_inv_op;
  } else {
    printf("Bad Minor Op: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_opd_e
Assembler::parseOpd(string &s) {
  // GPR
  if (!s.compare("r0")) {
    return e_opd_r0;
  } else if (!s.compare("r1")) {
    return e_opd_r1;
  } else if (!s.compare("r2")) {
    return e_opd_r2;
  } else if (!s.compare("r3")) {
    return e_opd_r3;
  } else if (!s.compare("r4")) {
    return e_opd_r4;
  } else if (!s.compare("r5")) {
    return e_opd_r5;
  } else if (!s.compare("r6")) {
    return e_opd_r6;
  } else if (!s.compare("r7")) {
    return e_opd_r7;

  // Flags
  } else if (!s.compare("rqf")) {
    return e_opd_rqf;
  } else if (!s.compare("ucf")) {
    return e_opd_ucf;
  } else if (!s.compare("nerf")) {
    return e_opd_nerf;
  } else if (!s.compare("nwbf")) {
    return e_opd_nwbf;
  } else if (!s.compare("pf")) {
    return e_opd_pf;
  } else if (!s.compare("sf")) {
    return e_opd_sf;
  } else if (!s.compare("csf")) {
    return e_opd_csf;
  } else if (!s.compare("cef")) {
    return e_opd_cef;
  } else if (!s.compare("cmf")) {
    return e_opd_cmf;
  } else if (!s.compare("cof")) {
    return e_opd_cof;
  } else if (!s.compare("cff")) {
    return e_opd_cff;
  } else if (!s.compare("rf")) {
    return e_opd_rf;
  } else if (!s.compare("uf")) {
    return e_opd_uf;

  // Special
  } else if (!s.compare("reqlce")) {
    return e_opd_req_lce;
  } else if (!s.compare("reqaddr")) {
    return e_opd_req_addr;
  } else if (!s.compare("reqway")) {
    return e_opd_req_way;
  } else if (!s.compare("lruaddr")) {
    return e_opd_lru_addr;
  } else if (!s.compare("lruway")) {
    return e_opd_lru_way;
  } else if (!s.compare("ownerlce")) {
    return e_opd_owner_lce;
  } else if (!s.compare("ownerway")) {
    return e_opd_owner_way;
  } else if (!s.compare("nextcohst")) {
    return e_opd_next_coh_state;
  } else if (!s.compare("flags")) {
    return e_opd_flags;
  } else if (!s.compare("msgsize")) {
    return e_opd_msg_size;
  } else if (!s.compare("lrucohst")) {
    return e_opd_lru_coh_state;

  } else if (!s.compare("flagsandmask")) {
    return e_opd_flags_and_mask;

  } else if (!s.compare("shhit")) {
    return e_opd_sharers_hit;
  } else if (!s.compare("shway")) {
    return e_opd_sharers_way;
  } else if (!s.compare("shstate")) {
    return e_opd_sharers_state;

  // Params
  } else if (!s.compare("cceid")) {
    return e_opd_cce_id;
  } else if (!s.compare("numlce")) {
    return e_opd_num_lce;
  } else if (!s.compare("numcce")) {
    return e_opd_num_cce;
  } else if (!s.compare("numwg")) {
    return e_opd_num_wg;
  } else if (!s.compare("autofwdmsg")) {
    return e_opd_auto_fwd_msg;
  } else if (!s.compare("cohst")) {
    return e_opd_coh_state_default;

  // Queue
  } else if (!s.compare("memresp")) {
    return e_opd_mem_resp_v;
  } else if (!s.compare("lceresp")) {
    return e_opd_lce_resp_v;
  } else if (!s.compare("pending")) {
    return e_opd_pending_v;
  } else if (!s.compare("lcereq")) {
    return e_opd_lce_req_v;
  } else if (!s.compare("lceresptype")) {
    return e_opd_lce_resp_type;
  } else if (!s.compare("memresptype")) {
    return e_opd_mem_resp_type;
  } else if (!s.compare("lcerespdata")) {
    return e_opd_lce_resp_data;
  } else if (!s.compare("memrespdata")) {
    return e_opd_mem_resp_data;
  } else if (!s.compare("lcereqdata")) {
    return e_opd_lce_req_data;

  // Default
  } else {
    printf("Bad Opd: %s\n", s.c_str());
    exit(-1);
    //return (bp_cce_inst_opd_e)0;
  }
}

uint16_t
Assembler::parseImm(string &s) {
  int stoi_res = stoi(s, nullptr, 0);
  return (uint16_t)stoi_res;
}

uint16_t
Assembler::parseTarget(string &s, bool &found) {
  // attempt to lookup branch target using label text
  auto labelIt = labels_to_addr.find(s);
  if (labelIt == labels_to_addr.end()) {
    found = false;
    return 0;
  }
  found = true;
  return labelIt->second;
}

uint16_t
Assembler::getBranchTarget(string &target_str) {
  bool label_found = false;
  // first try to determine branch target using label
  uint16_t target = parseTarget(target_str, label_found);
  if (label_found) {
    return target;
  } else {
    // if no label found, parse as integer immediate (absolute address)
    printf("Label %s not found, treating as absolute address.\n", target_str.c_str());
    return parseImm(target_str);
  }
}

uint8_t
Assembler::parseBranchPrediction(string &prediction) {
  if (!prediction.compare("pt")) {
    return 1;
  }
  return 0;
}

uint8_t
Assembler::parseWritePending(string &s) {
  if (!s.compare("wp")) {
    return 1;
  }
  return 0;
}

bp_cce_inst_flag_onehot_e
Assembler::parseFlagOneHot(string &s, bool &error) {
  error = false;
  if (!s.compare("rqf")) {
    return e_flag_rqf;
  } else if (!s.compare("ucf")) {
    return e_flag_ucf;
  } else if (!s.compare("nerf")) {
    return e_flag_nerf;
  } else if (!s.compare("nwbf")) {
    return e_flag_nwbf;
  } else if (!s.compare("pf")) {
    return e_flag_pf;
  } else if (!s.compare("sf")) {
    return e_flag_sf;
  } else if (!s.compare("csf")) {
    return e_flag_csf;
  } else if (!s.compare("cef")) {
    return e_flag_cef;
  } else if (!s.compare("cmf")) {
    return e_flag_cmf;
  } else if (!s.compare("cof")) {
    return e_flag_cof;
  } else if (!s.compare("cff")) {
    return e_flag_cff;
  } else if (!s.compare("rf")) {
    return e_flag_rf;
  } else if (!s.compare("uf")) {
    return e_flag_uf;
  } else {
    error = true;
    return e_flag_rqf;
  }
}

bp_cce_inst_mux_sel_addr_e
Assembler::parseAddrSel(string &s) {
  if (!s.compare("r0")) {
    return e_mux_sel_addr_r0;
  } else if (!s.compare("r1")) {
    return e_mux_sel_addr_r1;
  } else if (!s.compare("r2")) {
    return e_mux_sel_addr_r2;
  } else if (!s.compare("r3")) {
    return e_mux_sel_addr_r3;
  } else if (!s.compare("r4")) {
    return e_mux_sel_addr_r4;
  } else if (!s.compare("r5")) {
    return e_mux_sel_addr_r5;
  } else if (!s.compare("r6")) {
    return e_mux_sel_addr_r6;
  } else if (!s.compare("r7")) {
    return e_mux_sel_addr_r7;
  } else if (!s.compare("req")) {
    return e_mux_sel_addr_mshr_req;
  } else if (!s.compare("lru")) {
    return e_mux_sel_addr_mshr_lru;
  } else if (!s.compare("lcereq")) {
    return e_mux_sel_addr_lce_req;
  } else if (!s.compare("lceresp")) {
    return e_mux_sel_addr_lce_resp;
  } else if (!s.compare("memresp")) {
    return e_mux_sel_addr_mem_resp;
  } else if (!s.compare("pending")) {
    return e_mux_sel_addr_pending;
  } else if (!s.compare("zero") | !s.compare("0")) {
    return e_mux_sel_addr_0;
  } else {
    printf("Unknown address mux select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_mux_sel_lce_e
Assembler::parseLceSel(string &s) {
  if (!s.compare("r0")) {
    return e_mux_sel_lce_r0;
  } else if (!s.compare("r1")) {
    return e_mux_sel_lce_r1;
  } else if (!s.compare("r2")) {
    return e_mux_sel_lce_r2;
  } else if (!s.compare("r3")) {
    return e_mux_sel_lce_r3;
  } else if (!s.compare("r4")) {
    return e_mux_sel_lce_r4;
  } else if (!s.compare("r5")) {
    return e_mux_sel_lce_r5;
  } else if (!s.compare("r6")) {
    return e_mux_sel_lce_r6;
  } else if (!s.compare("r7")) {
    return e_mux_sel_lce_r7;
  } else if (!s.compare("req")) {
    return e_mux_sel_lce_mshr_req;
  } else if (!s.compare("owner")) {
    return e_mux_sel_lce_mshr_owner;
  } else if (!s.compare("lcereq")) {
    return e_mux_sel_lce_lce_req;
  } else if (!s.compare("lceresp")) {
    return e_mux_sel_lce_lce_resp;
  } else if (!s.compare("memresp")) {
    return e_mux_sel_lce_mem_resp;
  } else if (!s.compare("pending")) {
    return e_mux_sel_lce_pending;
  } else if (!s.compare("zero") | !s.compare("0")) {
    return e_mux_sel_lce_0;
  } else {
    printf("Unknown LCE mux select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_mux_sel_way_e
Assembler::parseWaySel(string &s) {
  if (!s.compare("r0")) {
    return e_mux_sel_way_r0;
  } else if (!s.compare("r1")) {
    return e_mux_sel_way_r1;
  } else if (!s.compare("r2")) {
    return e_mux_sel_way_r2;
  } else if (!s.compare("r3")) {
    return e_mux_sel_way_r3;
  } else if (!s.compare("r4")) {
    return e_mux_sel_way_r4;
  } else if (!s.compare("r5")) {
    return e_mux_sel_way_r5;
  } else if (!s.compare("r6")) {
    return e_mux_sel_way_r6;
  } else if (!s.compare("r7")) {
    return e_mux_sel_way_r7;
  } else if (!s.compare("req")) {
    return e_mux_sel_way_mshr_req;
  } else if (!s.compare("owner")) {
    return e_mux_sel_way_mshr_owner;
  } else if (!s.compare("lru")) {
    return e_mux_sel_way_mshr_lru;
  } else if (!s.compare("shway")) {
    // note: requires source A
    return e_mux_sel_way_sh_way;
  } else if (!s.compare("zero") | !s.compare("0")) {
    return e_mux_sel_way_0;
  } else {
    printf("Unknown way mux select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_mux_sel_coh_state_e
Assembler::parseCohStateSel(string &s) {
  if (!s.compare("r0")) {
    return e_mux_sel_coh_r0;
  } else if (!s.compare("r1")) {
    return e_mux_sel_coh_r1;
  } else if (!s.compare("r2")) {
    return e_mux_sel_coh_r2;
  } else if (!s.compare("r3")) {
    return e_mux_sel_coh_r3;
  } else if (!s.compare("r4")) {
    return e_mux_sel_coh_r4;
  } else if (!s.compare("r5")) {
    return e_mux_sel_coh_r5;
  } else if (!s.compare("r6")) {
    return e_mux_sel_coh_r6;
  } else if (!s.compare("r7")) {
    return e_mux_sel_coh_r7;
  } else if (!s.compare("nextcohst")) {
    return e_mux_sel_coh_next_coh_state;
  } else if (!s.compare("lrucohst")) {
    return e_mux_sel_coh_lru_coh_state;
  } else if (!s.compare("shcoh")) {
    // note: requires source A
    return e_mux_sel_sharer_state;
  } else if (!s.compare("imm")) {
    return e_mux_sel_coh_inst_imm;
  } else {
    // note: if this is returned, reparse the string as immediate
    return e_mux_sel_coh_inst_imm;
  }
}

bp_cce_inst_src_q_sel_e
Assembler::parseSrcQueue(string &s) {
  if (!s.compare("lcereq")) {
    return e_src_q_sel_lce_req;
  } else if (!s.compare("memresp")) {
    return e_src_q_sel_mem_resp;
  } else if (!s.compare("pending")) {
    return e_src_q_sel_pending;
  } else if (!s.compare("lceresp")) {
    return e_src_q_sel_lce_resp;
  } else {
    printf("Unknown src queue select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_src_q_e
Assembler::parseSrcQueueOneHot(string &s) {
  if (!s.compare("lcereq")) {
    return e_src_q_lce_req;
  } else if (!s.compare("memresp")) {
    return e_src_q_mem_resp;
  } else if (!s.compare("pending")) {
    return e_src_q_pending;
  } else if (!s.compare("lceresp")) {
    return e_src_q_lce_resp;
  } else {
    printf("Unknown src queue onehot operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dst_q_sel_e
Assembler::parseDstQueue(string &s) {
  if (!s.compare("lcecmd")) {
    return e_dst_q_sel_lce_cmd;
  } else if (!s.compare("memcmd")) {
    return e_dst_q_sel_mem_cmd;
  } else {
    printf("Unknown dst queue select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dst_q_e
Assembler::parseDstQueueOneHot(string &s) {
  if (!s.compare("lcecmd")) {
    return e_dst_q_lce_cmd;
  } else if (!s.compare("memcmd")) {
    return e_dst_q_mem_cmd;
  } else {
    printf("Unknown dst queue onehot operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_spec_op_e
Assembler::parseSpecCmd(string &s) {
  if (!s.compare("set")) {
   return e_spec_set;
  } else if (!s.compare("unset")) {
   return e_spec_unset;
  } else if (!s.compare("squash")) {
    return e_spec_squash;
  } else if (!s.compare("fwd_mod")) {
    return e_spec_fwd_mod;
  } else if (!s.compare("read")) {
    return e_spec_rd_spec;
  } else {
   printf("Bad Spec Cmd operand\n");
   exit(-1);
  }
}

// Directory operations
// op addr=<addr_sel> lce=<lce_sel> lru_way=<way_sel> way=<way_sel> state=<state_sel> dst=<gpr> [src=gpr] p=[0,1]
void
Assembler::parseDirArgs(vector<string> *tokens, int n, dir_args *args) {
  // args are specified as "arg=value"
  for (uint32_t i = 1; i < tokens->size(); i++) {
    if (debug_mode) {
      printf("parsing: %s\n", tokens->at(i).c_str());
    }

    // trim token at the "=" sign
    size_t pos = tokens->at(i).find("=");
    string token_type = tokens->at(i).substr(0, pos);
    string token = tokens->at(i).substr(pos + 1, tokens->at(i).size() - pos - 1);
    if (debug_mode) {
      printf("token type: %s\n", token_type.c_str());
      printf("token: %s\n", token.c_str());
    }

    if (!token_type.compare("addr")) {
      args->addr_sel = parseAddrSel(token);
    } else if (!token_type.compare("lce")) {
      args->lce_sel = parseLceSel(token);
    } else if (!token_type.compare("way")) {
      args->way_sel = parseWaySel(token);
    } else if (!token_type.compare("lru_way")) {
      args->way_sel = parseWaySel(token);
    } else if (!token_type.compare("state")) {
      args->state_sel = parseCohStateSel(token);
      if (args->state_sel == e_mux_sel_coh_inst_imm) {
        args->state = (bp_coh_states_e)parseImm(tokens->at(i+1));
        i++;
      }
    } else if (!token_type.compare("src")) {
      args->src = parseOpd(token);
    } else if (!token_type.compare("dst")) {
      args->dst = parseOpd(token);
    } else if (!token_type.compare("p")) {
      args->pending = parseImm(token) & 0x1;
    } else {
      printf("Bad dir op argument: %s\n", token_type.c_str());
      exit(-1);
    }
  }
}

// pushq[c] queue cmd addr=<> lce=<> way=<way_sel [src=opd]> spec=[0,1] wp=[0,1]
void
Assembler::parsePushQueueArgs(vector<string> *tokens, int n, pushq_args *args) {
  // all push operations start with:
  // pushq[c] queue command
  if (!(tokens->at(0).compare("pushqc"))) {
    args->custom = 1;
  } else {
    args->custom = 0;
  }
  args->dst_q = parseDstQueue(tokens->at(1));
  if (args->dst_q == e_dst_q_sel_lce_cmd) {
    args->lce_cmd = (bp_lce_cmd_type_e)parseImm(tokens->at(2));
  } else {
    args->mem_cmd = (bp_cce_mem_cmd_type_e)parseImm(tokens->at(2));
  }
  // after the opcode, address, and command, all args are optional and default to 0
  // args are specified as "arg=value"
  for (uint32_t i = 3; i < tokens->size(); i++) {
    if (debug_mode) {
      printf("parsing: %s\n", tokens->at(i).c_str());
    }

    // trim token at the "=" sign
    size_t pos = tokens->at(i).find("=");
    string token_type = tokens->at(i).substr(0, pos);
    string token = tokens->at(i).substr(pos + 1, tokens->at(i).size() - pos - 1);
    if (debug_mode) {
      printf("token type: %s\n", token_type.c_str());
      printf("token: %s\n", token.c_str());
    }

    if (!token_type.compare("addr")) {
      args->addr_sel = parseAddrSel(token);
    } else if (!token_type.compare("lce")) {
      args->lce_sel = parseLceSel(token);
    } else if (!token_type.compare("way")) {
      args->way_sel = parseWaySel(token);
    } else if (!token_type.compare("src")) {
      args->src = parseOpd(token);
    } else if (!token_type.compare("spec")) {
      args->spec = parseImm(token) & 0x1;
    } else if (!token_type.compare("wp")) {
      args->wp = parseImm(token) & 0x1;
    } else {
      printf("Bad pushq[c] argument: %s\n", token_type.c_str());
      exit(-1);
    }
  }
}


/*
 * Microcode Parsing Functions - one per instruction type
 */

void
Assembler::parseALU(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {
  bp_cce_inst_s *inst = &(parsed_inst->inst);
  // ALU is I-type or R-type
  if (tokens->size() == 1) { // nop - translates to addi r0 = r0 + 0
    parsed_inst->encoding = e_itype;
    inst->type_u.itype.dst = e_opd_r0;
    inst->type_u.itype.src_a = e_opd_r0;
    inst->type_u.itype.imm = 0;
  } else if (tokens->size() == 2) { // inc, dec, neg, not - same dst as src
    parsed_inst->encoding = e_itype;
    inst->type_u.itype.dst = parseOpd(tokens->at(1));
    inst->type_u.itype.src_a = inst->type_u.itype.dst;
    if (inst->minor_op == e_inc_op || inst->minor_op == e_dec_op) {
      inst->type_u.itype.imm = 1;
    }
  } else if (tokens->size() == 4) { // all others
    parsed_inst->encoding = e_rtype;
    // dst is always last opd
    inst->type_u.rtype.dst = parseOpd(tokens->at(3));
    // src_a is always first and non-immediate
    inst->type_u.rtype.src_a = parseOpd(tokens->at(1));
    // rtype
    if (inst->minor_op == e_add_op
        || inst->minor_op == e_sub_op
        || inst->minor_op == e_lsh_op
        || inst->minor_op == e_rsh_op
        || inst->minor_op == e_and_op
        || inst->minor_op == e_or_op
        || inst->minor_op == e_xor_op
        ) {
      inst->type_u.rtype.src_b = parseOpd(tokens->at(2));
    }
    // itype
    else {
      parsed_inst->encoding = e_itype;
      inst->type_u.itype.imm = parseImm(tokens->at(2));
    }
  } else {
    printf("Unknown ALU instruction: %s\n", tokens->at(0).c_str());
    exit(-1);
  }
}

void
Assembler::parseBranch(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {
  // strategy: switch based on minor_op
  // each branch instruction may optionally have a "pt" token at the end to predict as taken

  bp_cce_inst_s *inst = &(parsed_inst->inst);
  switch (inst->minor_op) {
    // btype instructions
    case e_beq_op:
    //case e_bi_op:  // SW
    case e_bne_op:
    case e_blt_op:
    //case e_bgt_op: // SW
    case e_ble_op:
    //case e_bge_op: // SW
    case e_bs_op:
    case e_bss_op:
      parsed_inst->encoding = e_btype;
      // BGT and BGE
      if (!(tokens->at(0).compare("bge")) || !(tokens->at(0).compare("bgt"))) {
        inst->type_u.btype.src_a = parseOpd(tokens->at(2));
        inst->type_u.btype.src_b = parseOpd(tokens->at(1));
        inst->type_u.btype.target = getBranchTarget(tokens->at(3));
        if (tokens->size() == 5) {
          inst->predict_taken = parseBranchPrediction(tokens->at(4));
        }
      }
      // BI
      else if (!(tokens->at(0).compare("bi"))) {
        inst->type_u.btype.target = getBranchTarget(tokens->at(1));
        inst->predict_taken = 1;
      }
      else {
        inst->type_u.btype.src_a = parseOpd(tokens->at(1));
        inst->type_u.btype.src_b = parseOpd(tokens->at(2));
        inst->type_u.btype.target = getBranchTarget(tokens->at(3));
        if (tokens->size() == 5) {
          inst->predict_taken = parseBranchPrediction(tokens->at(4));
        }
      }
      break;
    // bitype instructions
    case e_beqi_op:
    //case e_bz_op:    // SW
    case e_bneqi_op:
    //case e_bnz_op:   // SW
    case e_bsi_op:
      parsed_inst->encoding = e_bitype;
      if (!(tokens->at(0).compare("bz")) || !(tokens->at(0).compare("bnz"))) {
        inst->type_u.bitype.src_a = parseOpd(tokens->at(1));
        inst->type_u.bitype.imm = 0;
        inst->type_u.bitype.target = getBranchTarget(tokens->at(2));
        if (tokens->size() == 4) {
          inst->predict_taken = parseBranchPrediction(tokens->at(3));
        }
      }
      else {
        inst->type_u.bitype.src_a = parseOpd(tokens->at(1));
        inst->type_u.bitype.imm = parseImm(tokens->at(2));
        inst->type_u.bitype.target = getBranchTarget(tokens->at(3));
        if (tokens->size() == 5) {
          inst->predict_taken = parseBranchPrediction(tokens->at(4));
        }
      }
      break;
    default:
      printf("Unknown branch instruction: %s\n", tokens->at(0).c_str());
      exit(-1);
  }
}

void
Assembler::parseRegData(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {
  bp_cce_inst_s *inst = &(parsed_inst->inst);
  switch (inst->minor_op) {
    // rtype instructions
    // general form: op src dst
    case e_mov_op:
    case e_movsg_op:
    case e_movgs_op:
    // case e_ld_flags_op: // SW
    case e_movfg_op:
    case e_movgf_op:
    case e_movpg_op:
    case e_movgp_op:
    case e_clm_op:
      parsed_inst->encoding = e_rtype;
      if (!(tokens->at(0).compare("ldflags"))) {
        inst->type_u.rtype.dst = e_opd_flags;
        inst->type_u.rtype.src_a = parseOpd(tokens->at(1));
      }
      else if (!(tokens->at(0).compare("clm"))) {
        // nothing to set
      }
      else {
        inst->type_u.rtype.src_a = parseOpd(tokens->at(1));
        inst->type_u.rtype.dst = parseOpd(tokens->at(2));
      }
      break;
    // itype instructions
    // general form: op src dst
    case e_movi_op:
    case e_movis_op:
    // case e_ld_flags_i_op: // SW
    // case e_clf_op: // SW
    case e_movip_op:
      parsed_inst->encoding = e_itype;
      if (!(tokens->at(0).compare("ldflagsi"))) {
        inst->type_u.itype.dst = e_opd_flags;
      }
      else {
        inst->type_u.itype.imm = parseImm(tokens->at(1));
        inst->type_u.itype.dst = parseOpd(tokens->at(2));
      }
      break;
    default:
      printf("Unknown Reg Data instruction: %s\n", tokens->at(0).c_str());
      exit(-1);
  }
}

void
Assembler::parseFlag(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {
  bp_cce_inst_s *inst = &(parsed_inst->inst);
  bool error = false;
  switch (inst->minor_op) {
    // itype instructions
    case e_sf_op:
    // case e_sfz_op: // SW
      parsed_inst->encoding = e_itype;
      inst->type_u.itype.dst = parseOpd(tokens->at(1));
      if (!(tokens->at(0).compare("sf"))) {
        inst->type_u.itype.imm = 1;
      }
      else {
        inst->type_u.itype.imm = 0;
      }
      break;
    // rtype instructions
    // general form: op src_a src_b dst
    case e_andf_op:
    case e_orf_op:
    case e_nandf_op:
    case e_norf_op:
      parsed_inst->encoding = e_rtype;
      inst->type_u.rtype.src_a = parseOpd(tokens->at(1));
      inst->type_u.rtype.src_a = parseOpd(tokens->at(2));
      inst->type_u.rtype.dst = parseOpd(tokens->at(3));
      break;
    case e_notf_op:
      parsed_inst->encoding = e_rtype;
      inst->type_u.rtype.src_a = parseOpd(tokens->at(1));
      inst->type_u.rtype.dst = parseOpd(tokens->at(2));
      break;
    // bftype instructions
    // form: op tgt [mask list] [pt]
    case e_bf_op:
    case e_bfz_op:
    case e_bfnz_op:
    case e_bfnot_op:
      parsed_inst->encoding = e_bftype;
      inst->branch = 1;
      inst->type_u.bftype.target = getBranchTarget(tokens->at(1));
      // parse all flags listed until the token is unrecognized
      // bad token indicates presence of predict_taken indicator
      for (uint32_t i = 2; i < tokens->size(); i++) {
        uint16_t f = parseFlagOneHot(tokens->at(i), error);
        if (!error) {
          inst->type_u.bftype.imm |= f;
        }
      }
      if (error) {
        inst->predict_taken = parseBranchPrediction(tokens->at(tokens->size()-1));
      }
      break;
    default:
      printf("Unknown Flag instruction: %s\n", tokens->at(0).c_str());
      exit(-1);
  }
}

void
Assembler::parseDir(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {
  bp_cce_inst_s *inst = &(parsed_inst->inst);
  dir_args dirargs;
  parseDirArgs(tokens, n, &dirargs);
  switch (inst->minor_op) {
    case e_rdp_op:
      parsed_inst->encoding = e_dptype;
      inst->type_u.dptype.addr_sel = dirargs.addr_sel;
      break;
    case e_rdw_op:
      parsed_inst->encoding = e_drtype;
      inst->type_u.drtype.addr_sel = dirargs.addr_sel;
      inst->type_u.drtype.lce_sel = dirargs.lce_sel;
      inst->type_u.drtype.lru_way_sel = dirargs.way_sel;
      inst->type_u.drtype.src_a = dirargs.src;
      break;
    case e_rde_op:
      parsed_inst->encoding = e_drtype;
      inst->type_u.drtype.addr_sel = dirargs.addr_sel;
      inst->type_u.drtype.lce_sel = dirargs.lce_sel;
      inst->type_u.drtype.way_sel = dirargs.way_sel;
      inst->type_u.drtype.dst = dirargs.dst;
      inst->type_u.drtype.src_a = dirargs.src;
      break;
    case e_wdp_op:
      parsed_inst->encoding = e_dptype;
      inst->type_u.dptype.addr_sel = dirargs.addr_sel;
      inst->type_u.dptype.pending = dirargs.pending;
      break;
    case e_clp_op:
      parsed_inst->encoding = e_dptype;
      inst->type_u.dptype.addr_sel = dirargs.addr_sel;
      inst->type_u.dptype.pending = 0;
      break;
    case e_clr_op:
      parsed_inst->encoding = e_dwtype;
      inst->type_u.dwtype.addr_sel = dirargs.addr_sel;
      inst->type_u.dwtype.lce_sel = dirargs.lce_sel;
      break;
    case e_wde_op:
    case e_wds_op:
      parsed_inst->encoding = e_dwtype;
      inst->type_u.dwtype.addr_sel = dirargs.addr_sel;
      inst->type_u.dwtype.lce_sel = dirargs.lce_sel;
      inst->type_u.dwtype.way_sel = dirargs.way_sel;
      inst->type_u.dwtype.state_sel = dirargs.state_sel;
      inst->type_u.dwtype.state = dirargs.state;
      inst->type_u.dwtype.src_a = dirargs.src;
      break;
    case e_gad_op:
      parsed_inst->encoding = e_rtype;
      break;
    default:
      printf("Unknown Directory instruction %s\n", tokens->at(0).c_str());
      exit(-1);
  }
}

void
Assembler::parseQueue(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {
  bp_cce_inst_s *inst = &(parsed_inst->inst);
  pushq_args qargs;
  switch (inst->minor_op) {
    case e_wfq_op:
      parsed_inst->encoding = e_itype;
      for (uint32_t i = 1; i < tokens->size(); i++) {
        inst->type_u.itype.imm |= parseSrcQueueOneHot(tokens->at(i));
      }
      break;
    case e_pushq_op:
    //case e_pushqc_op:
      parsed_inst->encoding = e_pushq;
      // parse push queue instruction arguments
      parsePushQueueArgs(tokens, n, &qargs);
      // populate fields of instruction
      // all commands set queue type, LCE/address select, command
      inst->type_u.pushq.dst_q = qargs.dst_q;
      inst->type_u.pushq.lce_sel = qargs.lce_sel;
      inst->type_u.pushq.addr_sel = qargs.addr_sel;
      if (qargs.dst_q == e_dst_q_sel_lce_cmd) {
        inst->type_u.pushq.cmd.lce_cmd = qargs.lce_cmd;
        if (qargs.spec) {
          printf("Error: spec bit set when pushing to LCE command\n");
          exit(-1);
        }
      } else {
        inst->type_u.pushq.cmd.mem_cmd = qargs.mem_cmd;
      }
      inst->type_u.pushq.spec = qargs.spec;
      inst->type_u.pushq.write_pending = qargs.wp;
      inst->type_u.pushq.custom = qargs.custom;
      inst->type_u.pushq.src_a = qargs.src;
      if (qargs.custom) {
        // for now, send 64-bits of data, sourced from src_a
        inst->type_u.pushq.way_or_size.msg_size = e_mem_msg_size_8;
      } else {
        inst->type_u.pushq.way_or_size.way_sel = qargs.way_sel;
      }
      break;
    case e_popq_op:
      parsed_inst->encoding = e_popq;
      inst->type_u.popq.src_q = parseSrcQueue(tokens->at(1));
      if (tokens->size() == 3) {
        inst->type_u.popq.write_pending = parseWritePending(tokens->at(2));
      }
      break;
    case e_poph_op:
      parsed_inst->encoding = e_popq;
      inst->type_u.popq.src_q = parseSrcQueue(tokens->at(1));
      inst->type_u.popq.dst = parseOpd(tokens->at(2));
      break;
    case e_popd_op: // TODO: complete with serdes changes
      parsed_inst->encoding = e_popq;
      inst->type_u.popq.src_q = parseSrcQueue(tokens->at(1));
      inst->type_u.popq.dst = parseOpd(tokens->at(2));
      break;
    case e_specq_op:
      parsed_inst->encoding = e_stype;
      inst->type_u.stype.cmd = parseSpecCmd(tokens->at(1));
      inst->type_u.stype.addr_sel = parseAddrSel(tokens->at(2));
      if (inst->type_u.stype.cmd == e_spec_fwd_mod) {
        inst->type_u.stype.state = (bp_coh_states_e)parseImm(tokens->at(3));
      }
      break;
    case e_inv_op:
      parsed_inst->encoding = e_pushq;
      break;
    /* TODO: general send command to sharers operation
    case e_cmd_op:
      inst->type_u.pushq.addr_sel = parseAddrSel(tokens->at(1));
      inst->type_u.pushq.lce_sel = parseLceSel(tokens->at(2));
      inst->type_u.pushq.way_or_size.way_sel = parseWaySel(tokens->at(3));
      if (tokens->size() == 5) {
        inst->type_u.pushq.src_a = parseOpd(tokens->at(4));
      }
      break;
    */
    default:
      printf("Unknown Queue instruction %s\n", tokens->at(0).c_str());
      exit(-1);
  }
}

void
Assembler::parseTokens(vector<string> *tokens, int n, parsed_inst_s *parsed_inst) {

  bp_cce_inst_s *inst = &(parsed_inst->inst);

  // All instructions
  inst->op = getOp(tokens->at(0));
  inst->minor_op = (bp_cce_inst_minor_op_e)getMinorOp(tokens->at(0));

  switch (inst->op) {
    case e_op_alu:
      parseALU(tokens, n, parsed_inst);
      break;
    case e_op_branch:
      inst->branch = 1;
      parseBranch(tokens, n, parsed_inst);
      break;
    case e_op_reg_data:
      parseRegData(tokens, n, parsed_inst);
      break;
    case e_op_flag:
      parseFlag(tokens, n, parsed_inst);
      break;
    case e_op_dir:
      parseDir(tokens, n, parsed_inst);
      break;
    case e_op_queue:
      parseQueue(tokens, n, parsed_inst);
      break;
    default:
      printf("Error parsing instruction\n");
      exit(-1);
  }
}

/*
 * Assembler Output Function
 *
 * Output printing is done based on instruction encoding.
 *
 */

void
Assembler::writeInstToOutput(parsed_inst_s *parsed_inst, uint16_t line_number, string &s) {

  stringstream ss;

  bp_cce_inst_s *inst = &(parsed_inst->inst);

  printField(inst->predict_taken, 1, ss);
  printField(inst->branch, 1, ss);

  switch (parsed_inst->encoding) {
    case e_rtype:
      printPad(bp_cce_inst_rtype_pad, ss);
      printField(inst->type_u.rtype.src_b, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.rtype.dst, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.rtype.src_a, bp_cce_inst_opd_width, ss);
      break;
    case e_itype:
      printField(inst->type_u.itype.imm, bp_cce_inst_imm16_width, ss);
      printPad(bp_cce_inst_itype_pad, ss);
      printField(inst->type_u.itype.dst, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.itype.src_a, bp_cce_inst_opd_width, ss);
      break;
    case e_btype:
      printField(inst->type_u.btype.target, bp_cce_inst_addr_width, ss);
      printPad(bp_cce_inst_btype_pad, ss);
      printField(inst->type_u.btype.src_b, bp_cce_inst_opd_width, ss);
      printPad(bp_cce_inst_imm4_width, ss);
      printField(inst->type_u.btype.src_a, bp_cce_inst_opd_width, ss);
      break;
    case e_bitype:
      printField(inst->type_u.bitype.target, bp_cce_inst_addr_width, ss);
      printPad(bp_cce_inst_bitype_pad, ss);
      printField(inst->type_u.bitype.imm, bp_cce_inst_imm8_width, ss);
      printField(inst->type_u.bitype.src_a, bp_cce_inst_opd_width, ss);
      break;
    case e_bftype:
      printField(inst->type_u.bftype.target, bp_cce_inst_addr_width, ss);
      printField(inst->type_u.bftype.imm, bp_cce_inst_imm16_width, ss);
      break;
    case e_stype:
      printPad(bp_cce_inst_stype_pad, ss);
      printField(inst->type_u.stype.state, bp_coh_bits, ss);
      printField(inst->type_u.stype.addr_sel, bp_cce_inst_mux_sel_addr_width, ss);
      printField(inst->type_u.stype.dst, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.stype.cmd, bp_cce_inst_spec_op_width, ss);
      break;
    case e_dptype:
      printPad(bp_cce_inst_dptype_pad, ss);
      printField(inst->type_u.dptype.pending, 1, ss);
      printField(inst->type_u.dptype.dst, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.dptype.addr_sel, bp_cce_inst_mux_sel_addr_width, ss);
      break;
    case e_dwtype:
      printPad(bp_cce_inst_dwtype_pad, ss);
      printField(inst->type_u.drtype.src_a, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.dwtype.state, bp_coh_bits, ss);
      printField(inst->type_u.dwtype.way_sel, bp_cce_inst_mux_sel_way_width, ss);
      printField(inst->type_u.dwtype.lce_sel, bp_cce_inst_mux_sel_lce_width, ss);
      printField(inst->type_u.dwtype.state_sel, bp_cce_inst_mux_sel_coh_state_width, ss);
      printField(inst->type_u.dwtype.addr_sel, bp_cce_inst_mux_sel_addr_width, ss);
      break;
    case e_drtype:
      printPad(bp_cce_inst_drtype_pad, ss);
      printField(inst->type_u.drtype.src_a, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.drtype.lru_way_sel, bp_cce_inst_mux_sel_way_width, ss);
      printField(inst->type_u.drtype.way_sel, bp_cce_inst_mux_sel_way_width, ss);
      printField(inst->type_u.drtype.lce_sel, bp_cce_inst_mux_sel_lce_width, ss);
      printField(inst->type_u.drtype.dst, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.drtype.addr_sel, bp_cce_inst_mux_sel_addr_width, ss);
      break;
    case e_popq:
      printField(inst->type_u.popq.write_pending, 1, ss);
      printPad(bp_cce_inst_popq_pad, ss);
      printField(inst->type_u.popq.dst, bp_cce_inst_opd_width, ss);
      printPad(bp_cce_inst_imm2_width, ss);
      printField(inst->type_u.popq.src_q, bp_cce_inst_src_q_sel_width, ss);
      break;
    case e_pushq:
      printField(inst->type_u.pushq.write_pending, 1, ss);
      printField(inst->type_u.pushq.way_or_size.way_sel, bp_cce_inst_mux_sel_way_width, ss);
      printField(inst->type_u.pushq.src_a, bp_cce_inst_opd_width, ss);
      printField(inst->type_u.pushq.lce_sel, bp_cce_inst_mux_sel_lce_width, ss);
      printField(inst->type_u.pushq.addr_sel, bp_cce_inst_mux_sel_addr_width, ss);
      printField(inst->type_u.pushq.cmd.lce_cmd, bp_lce_cmd_type_width, ss);
      printField(inst->type_u.pushq.spec, 1, ss);
      printField(inst->type_u.pushq.custom, 1, ss);
      printField(inst->type_u.pushq.dst_q, bp_cce_inst_dst_q_sel_width, ss);
      break;
    default:
      printf("Error parsing instruction\n");
      printf("line: %d\n", line_number);
      exit(-1);
  }

  printField(inst->minor_op, bp_cce_inst_minor_op_width, ss);
  printField(inst->op, bp_cce_inst_op_width, ss);

  switch (output_format) {
    case  output_format_ascii_binary:
      fprintf(outfp, "%s\n", ss.str().c_str());
      break;
    case  output_format_dbg:
      fprintf(outfp, "(%02X) %5s : %s\n", line_number, s.c_str(), ss.str().c_str());
      break;
  }
}

/*
 * Main Assembler Function
 */

void
Assembler::assemble() {
  // Transform tokenized instructions into instruction struct, then write to output
  parsed_inst_s parsed_inst;
  unsigned int i = 0;
  while (i < tokens.size()) {
    parsed_inst = {};
    if (debug_mode) {
      printf("parsing instruction: %d\n", i);
    }
    parseTokens(tokens.at(i), num_tokens.at(i), &parsed_inst);
    writeInstToOutput(&parsed_inst, (uint16_t)i, tokens.at(i)->at(0));
    i++;
  }
}

