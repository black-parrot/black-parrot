/*
 * bp_as.cc
 *
 * @author markw
 *
 * BlackParrot CCE Microcode Assembler
 *
 */

#include "bp_as.h"

bool
Assembler::_iscommentstart(char ch) {
  switch (ch) {
    case  '#':
      return true;
    default:
      return false;
  }
}

bool
Assembler::_iswhitespace(char ch) {
  switch (ch) {
    case  '/':
    case  ',':
    case  ' ':
    case  '\t':
      return true;
    default:
      return false;
  }
}

bool
Assembler::_ishardnewline(char ch) {
  switch (ch) {
    case  '\0':
    case  '\n':
      return true;
    default:
      return false;
  }
}

bool
Assembler::_isnewline(char ch) {
  switch (ch) {
    case  '\0':
    case  '\n':
    case  ';':
      return true;
    default:
      return false;
  }
}

char
Assembler::_lowercase(char ch) {
  if (ch >= 'A' && ch <= 'Z')
    return ch - 'A' + 'a';
  return ch;
}


bp_cce_inst_op_e
Assembler::getOp(const char* op) {
  if (!strcmp("add", op) || !strcmp("inc", op) || !strcmp("sub", op) || !strcmp("dec", op)
      || !strcmp("lsh", op) || !strcmp("rsh", op) || !strcmp("and", op) || !strcmp("or", op)
      || !strcmp("xor", op) || !strcmp("neg", op)) {
    return e_op_alu;
  } else if (!strcmp("bi", op) || !strcmp("beq", op) || !strcmp("bne", op) || !strcmp("bz", op)
             || !strcmp("bnz", op) || !strcmp("bf", op) || !strcmp("bfz", op) || !strcmp("bqr", op)
             || !strcmp("blt", op) || !strcmp("ble", op) || !strcmp("bgt", op) || !strcmp("bge", op)
            ) {
    return e_op_branch;
  } else if (!strcmp("mov", op) || !strcmp("movi", op)) {
    return e_op_move;
  } else if (!strcmp("sf", op) || !strcmp("sfz", op)) {
    return e_op_flag;
  } else if (!strcmp("rdp", op) || !strcmp("rdw", op) || !strcmp("rde", op)) {
    return e_op_read_dir;
  } else if (!strcmp("wdp", op) || !strcmp("wde", op) || !strcmp("wds", op)) {
    return e_op_write_dir;
  } else if (!strcmp("gad", op) || !strcmp("stall", op)) {
    return e_op_misc;
  } else if (!strcmp("wfq", op) || !strcmp("pushq", op) || !strcmp("popq", op)) {
    return e_op_queue;
  } else {
    printf("Bad Op: %s\n", op);
    exit(-1);
  }
}

uint8_t
Assembler::getMinorOp(const char* op) {
  if (!strcmp("add", op) || !strcmp("inc", op)) {
    return e_add;
  } else if (!strcmp("sub", op) || !strcmp("dec", op)) {
    return e_sub;
  } else if (!strcmp("lsh", op)) {
    return e_lsh;
  } else if (!strcmp("rsh", op)) {
    return e_rsh;
  } else if (!strcmp("and", op)) {
    return e_and;
  } else if (!strcmp("or", op)) {
    return e_or;
  } else if (!strcmp("xor", op)) {
    return e_xor;
  } else if (!strcmp("neg", op)) {
    return e_neg;
  } else if (!strcmp("bi", op)) {
    return e_bi;
  } else if (!strcmp("beq", op) || !strcmp("bz", op) || !strcmp("bf", op) || !strcmp("bfz", op)
             || !strcmp("bqr", op)) {
    return e_beq;
  } else if (!strcmp("bne", op) || !strcmp("bnz", op)) {
    return e_bne;
  } else if (!strcmp("blt", op) || !strcmp("bgt", op)) {
    return e_blt;
  } else if (!strcmp("ble", op) || !strcmp("bge", op)) {
    return e_ble;
  } else if (!strcmp("mov", op)) {
    return e_mov;
  } else if (!strcmp("movi", op)) {
    return e_movi;
  } else if (!strcmp("sf", op) || !strcmp("sfz", op)) {
    return e_sf;
  } else if (!strcmp("rdp", op)) {
    return e_rdp;
  } else if (!strcmp("rdw", op)) {
    return e_rdw;
  } else if (!strcmp("rde", op)) {
    return e_rde;
  } else if (!strcmp("wdp", op)) {
    return e_wdp;
  } else if (!strcmp("wde", op)) {
    return e_wde;
  } else if (!strcmp("wds", op)) {
    return e_wds;
  } else if (!strcmp("gad", op)) {
    return e_gad;
  } else if (!strcmp("stall", op)) {
    return e_stall;
  } else if (!strcmp("wfq", op)) {
    return e_wfq;
  } else if (!strcmp("pushq", op)) {
    return e_pushq;
  } else if (!strcmp("popq", op)) {
    return e_popq;
  } else {
    printf("Bad Minor Op: %s\n", op);
    exit(-1);
  }
}

bp_cce_inst_src_e
Assembler::parseSrcOpd(string &s) {
  if (!s.compare("r0")) {
    return e_src_r0;
  } else if (!s.compare("r1")) {
    return e_src_r1;
  } else if (!s.compare("r2")) {
    return e_src_r2;
  } else if (!s.compare("r3")) {
    return e_src_r3;
  } else if (!s.compare("rqf")) {
    return e_src_rqf;
  } else if (!s.compare("nerf")) {
    return e_src_nerf;
  } else if (!s.compare("ldf")) {
    return e_src_ldf;
  } else if (!s.compare("nwbf")) {
    return e_src_nwbf;
  } else if (!s.compare("tf")) {
    return e_src_tf;
  } else if (!s.compare("rf")) {
    return e_src_rf;
  } else if (!s.compare("rwbf")) {
    return e_src_rwbf;
  } else if (!s.compare("pf")) {
    return e_src_pf;
  } else if (!s.compare("uf")) {
    return e_src_uf;
  } else if (!s.compare("if")) {
    return e_src_if;
  } else if (!s.compare("ef")) {
    return e_src_ef;
  } else if (!s.compare("pcf")) {
    return e_src_pcf;
  } else if (!s.compare("ucf")) {
    return e_src_ucf;
  } else if (!s.compare("reqlce")) {
    return e_src_req_lce;
  } else if (!s.compare("acktype")) {
    return e_src_ack_type;
  } else if (!s.compare("shr0")) {
    return e_src_sharers_hit_r0;
  } else if (!s.compare("cce_id")) {
    return e_src_cce_id;
  } else if (!s.compare("lcereq")) {
    return e_src_lce_req_ready;
  } else if (!s.compare("memresp")) {
    return e_src_mem_resp_ready;
  } else if (!s.compare("memdataresp")) {
    return e_src_mem_data_resp_ready;
  } else if (!s.compare("pending")) {
    return e_src_pending_ready;
  } else if (!s.compare("lceresp")) {
    return e_src_lce_resp_ready;
  } else if (!s.compare("lcedataresp")) {
    return e_src_lce_data_resp_ready;
  } else {
    printf("Unknown source operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dst_e
Assembler::parseDstOpd(string &s) {
  if (!s.compare("r0")) {
    return e_dst_r0;
  } else if (!s.compare("r1")) {
    return e_dst_r1;
  } else if (!s.compare("r2")) {
    return e_dst_r2;
  } else if (!s.compare("r3")) {
    return e_dst_r3;
  } else if (!s.compare("rqf")) {
    return e_dst_rqf;
  } else if (!s.compare("nerf")) {
    return e_dst_nerf;
  } else if (!s.compare("ldf")) {
    return e_dst_ldf;
  } else if (!s.compare("nwbf")) {
    return e_dst_nwbf;
  } else if (!s.compare("tf")) {
    return e_dst_tf;
  } else if (!s.compare("rf")) {
    return e_dst_rf;
  } else if (!s.compare("rwbf")) {
    return e_dst_rwbf;
  } else if (!s.compare("pf")) {
    return e_dst_pf;
  } else if (!s.compare("uf")) {
    return e_dst_uf;
  } else if (!s.compare("if")) {
    return e_dst_if;
  } else if (!s.compare("ef")) {
    return e_dst_ef;
  } else if (!s.compare("pcf")) {
    return e_dst_pcf;
  } else if (!s.compare("ucf")) {
    return e_dst_ucf;
  } else if (!s.compare("nextcohst")) {
    return e_dst_next_coh_state;
  } else {
    printf("Unknown destination operand: %s\n", s.c_str());
    exit(-1);
  }
}

uint16_t
Assembler::parseImm(string &s) {
  int stoi_res = stoi(s, nullptr, 0);
  if (stoi_res > UINT16_MAX || stoi_res < 0) {
    printf("Bad immediate: %d\n", stoi_res);
    exit(-1);
  } else {
    return (uint16_t)stoi_res;
  }
}

uint16_t
Assembler::parseCohStImm(string &s) {
  if (!s.compare("m")) {
    return 3;
  } else if (!s.compare("e")) {
    return 2;
  } else if (!s.compare("s")) {
    return 1;
  } else if (!s.compare("i")) {
    return 0;
  }
  int stoi_res = stoi(s, nullptr, 0);
  if (stoi_res > 3 || stoi_res < 0) {
    printf("Bad coh state immediate: %d\n", stoi_res);
    exit(-1);
  } else {
    return (uint16_t)stoi_res;
  }
}

void
Assembler::parseALU(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  if (tokens->size() == 2) { // inc, dec, neg
    inst->type_u.alu_op_s.src_a = parseSrcOpd(tokens->at(1));
    inst->type_u.alu_op_s.dst = parseDstOpd(tokens->at(1));
    if (inst->minor_op == e_inc || inst->minor_op == e_dec) {
      inst->type_u.alu_op_s.src_b = e_src_const_1;
    } else if (inst->minor_op == e_neg) {
      inst->type_u.alu_op_s.src_b = e_src_const_0;
    } else {
      printf("Unknown ALU instruction: %s\n", tokens->at(0).c_str());
      exit(-1);
    }
  } else if (tokens->size() == 3) { // lsh, rsh
    inst->type_u.alu_op_s.src_a = parseSrcOpd(tokens->at(1));
    inst->type_u.alu_op_s.dst = parseDstOpd(tokens->at(1));
    inst->type_u.alu_op_s.src_b = e_src_imm;
  } else if (tokens->size() == 4) { // add, sub, and, or, xor
    inst->type_u.alu_op_s.src_a = parseSrcOpd(tokens->at(1));
    inst->type_u.alu_op_s.src_b = parseSrcOpd(tokens->at(2));
    inst->type_u.alu_op_s.dst = parseDstOpd(tokens->at(3));
  } else {
    printf("Unknown ALU instruction: %s\n", tokens->at(0).c_str());
    exit(-1);
  }
}

uint16_t
Assembler::parseTarget(string &s, bool &found) {
  auto labelIt = labels_to_addr.find(s);
  if (labelIt == labels_to_addr.end()) {
    printf("No address found for label: %s\n", s.c_str());
    found = false;
    return 0;
  }
  found = true;
  return labelIt->second;
}

uint16_t
Assembler::getImm(string &target_str) {
  bool label_found = false;
  uint16_t target = parseTarget(target_str, label_found);
  if (label_found) {
    return target;
  } else {
    return parseImm(target_str);
  }
}

void
Assembler::parseBranch(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  // Branch Immediate
  if (tokens->size() == 2) {
    inst->type_u.branch_op_s.imm = getImm(tokens->at(1));
  // Branch Flag or Branch Queue Ready
  } else if (tokens->size() == 3) {
    inst->type_u.branch_op_s.src_a = parseSrcOpd(tokens->at(1));
    if (!strcmp("bf", tokens->at(0).c_str()) || !strcmp("bqr", tokens->at(0).c_str())) {
      inst->type_u.branch_op_s.src_b = e_src_const_1;
    } else {
      inst->type_u.branch_op_s.src_b = e_src_const_0;
    }
    inst->type_u.branch_op_s.imm = getImm(tokens->at(2));
  // Branch
  } else if (tokens->size() == 4) {
    if (!strcmp("bge", tokens->at(0).c_str()) || !strcmp("bgt", tokens->at(0).c_str())) {
      inst->type_u.branch_op_s.src_a = parseSrcOpd(tokens->at(2));
      inst->type_u.branch_op_s.src_b = parseSrcOpd(tokens->at(1));
    } else {
      inst->type_u.branch_op_s.src_a = parseSrcOpd(tokens->at(1));
      inst->type_u.branch_op_s.src_b = parseSrcOpd(tokens->at(2));
    }
    inst->type_u.branch_op_s.imm = getImm(tokens->at(3));
  } else {
    printf("Unknown Branch instruction: %s\n", tokens->at(0).c_str());
  }
}

bp_cce_inst_flag_e
Assembler::parseFlagSel(string &s) {
  switch (parseDstOpd(s)) {
    case e_dst_rqf:
      return e_flag_rqf;
      break;
    case e_dst_nerf:
      return e_flag_nerf;
      break;
    case e_dst_ldf:
      return e_flag_ldf;
      break;
    case e_dst_nwbf:
      return e_flag_nwbf;
      break;
    case e_dst_tf:
      return e_flag_tf;
      break;
    case e_dst_rf:
      return e_flag_rf;
      break;
    case e_dst_rwbf:
      return e_flag_rwbf;
      break;
    case e_dst_pf:
      return e_flag_pf;
      break;
    case e_dst_uf:
      return e_flag_uf;
      break;
    case e_dst_if:
      return e_flag_if;
      break;
    case e_dst_ef:
      return e_flag_ef;
      break;
    case e_dst_pcf:
      return e_flag_pcf;
      break;
    case e_dst_ucf:
      return e_flag_ucf;
      break;
    default:
      printf("Unknown Flag operand\n");
      exit(-1);
  }
}

void
Assembler::parseMove(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  if (tokens->size() == 3) { // mov or movi
    inst->type_u.mov_op_s.dst = parseDstOpd(tokens->at(2));
    if (inst->minor_op == e_movi) {
      inst->type_u.mov_op_s.src = e_src_imm;
      if (inst->type_u.mov_op_s.dst == e_dst_next_coh_state) {
        inst->type_u.mov_op_s.imm = parseCohStImm(tokens->at(1));
      } else {
        inst->type_u.mov_op_s.imm = parseImm(tokens->at(1));
      }
    } else if (inst->minor_op == e_mov) {
      inst->type_u.mov_op_s.src = parseSrcOpd(tokens->at(1));
    } else {
      printf("Unknown Move instruction: %s\n", tokens->at(0).c_str());
      exit(-1);
    }
  } else if (tokens->size() == 2) { // sf or sfz
    inst->type_u.flag_op_s.dst = parseDstOpd(tokens->at(1));
    /*
    inst->rqf_sel = e_rqf_imm0;
    inst->nerldf_sel = e_nerldf_imm0;
    inst->nwbf_sel = e_nwbf_imm0;
    inst->tf_sel = e_tf_imm0;
    inst->pruief_sel = e_pruief_imm0;
    inst->rwbf_sel = e_rwbf_imm0;
    inst->flag_mask_w_v = parseFlagSel(tokens->at(1));
    */
    if (!strcmp("sf", tokens->at(0).c_str())) {
      inst->type_u.flag_op_s.imm = 1;
    } else if (!strcmp("sfz", tokens->at(0).c_str())) {
      inst->type_u.flag_op_s.imm = 0;
    } else {
      printf("Unknown Flag instruction: %s\n", tokens->at(0).c_str());
      exit(-1);
    }
  } else {
    printf("Unknown Move or Flag instruction: %s\n", tokens->at(0).c_str());
    exit(-1);
  }
}

bp_cce_inst_dir_way_group_sel_e
Assembler::parseDirWgSel(string &s) {
  if (!s.compare("r0")) {
    return e_dir_wg_sel_r0;
  } else if (!s.compare("r1")) {
    return e_dir_wg_sel_r1;
  } else if (!s.compare("r2")) {
    return e_dir_wg_sel_r2;
  } else if (!s.compare("r3")) {
    return e_dir_wg_sel_r3;
  } else if (!s.compare("req")) {
    return e_dir_wg_sel_req_addr;
  } else if (!s.compare("lru")) {
    return e_dir_wg_sel_lru_way_addr;
  } else {
    printf("Unknown directory way-group select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dir_lce_sel_e 
Assembler::parseDirLceSel(string &s) {
  if (!s.compare("r0")) {
    return e_dir_lce_sel_r0;
  } else if (!s.compare("r1")) {
    return e_dir_lce_sel_r1;
  } else if (!s.compare("r2")) {
    return e_dir_lce_sel_r2;
  } else if (!s.compare("r3")) {
    return e_dir_lce_sel_r3;
  } else if (!s.compare("req")) {
    return e_dir_lce_sel_req_lce;
  } else if (!s.compare("tr")) {
    return e_dir_lce_sel_transfer_lce;
  } else {
    printf("Unknown directory lce select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dir_way_sel_e
Assembler::parseDirWaySel(string &s) {
  if (!s.compare("r0")) {
    return e_dir_way_sel_r0;
  } else if (!s.compare("r1")) {
    return e_dir_way_sel_r1;
  } else if (!s.compare("r2")) {
    return e_dir_way_sel_r2;
  } else if (!s.compare("r3")) {
    return e_dir_way_sel_r3;
  } else if (!s.compare("req")) {
    return e_dir_way_sel_req_addr_way;
  } else if (!s.compare("lru")) {
    return e_dir_way_sel_lru_way_addr_way;
  } else if (!s.compare("shwayr0")) {
    return e_dir_way_sel_sh_way_r0;
  } else {
    printf("Unknown directory way select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dir_tag_sel_e
Assembler::parseDirTagSel(string &s) {
  if (!s.compare("req")) {
    return e_dir_tag_sel_req_addr;
  } else if (!s.compare("lru")) {
    return e_dir_tag_sel_lru_way_addr;
  } else if (!s.compare("0")) {
    return e_dir_tag_sel_const_0;
  } else {
    printf("Unknown directory tag select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dir_coh_state_sel_e
Assembler::parseDirCohStSel(string &s) {
  if (!s.compare("nextcohst")) {
    return e_dir_coh_sel_next_coh_st;
  } else {
    return e_dir_coh_sel_inst_imm;
  }
}

void
Assembler::parseReadDir(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  inst->type_u.read_dir_op_s.dir_way_group_sel = parseDirWgSel(tokens->at(1));
  if (inst->minor_op == e_rdp || inst->minor_op == e_rdw) {
    /*
    inst->pruief_sel = e_pruief_logic;
    inst->flag_mask_w_v = e_flag_pf;
    */
  } else if (inst->minor_op == e_rde) {
    inst->type_u.read_dir_op_s.dir_lce_sel = parseDirLceSel(tokens->at(2));
    inst->type_u.read_dir_op_s.dir_way_sel = parseDirWaySel(tokens->at(3));
  } else {
    printf("Unknown Read Directory instruction\n");
    exit(-1);
  }
}

void
Assembler::parseWriteDir(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  inst->type_u.write_dir_op_s.dir_way_group_sel = parseDirWgSel(tokens->at(1));
  if (inst->minor_op == e_wdp) {
    inst->type_u.write_dir_op_s.imm = (uint8_t)(parseImm(tokens->at(2)) & 0x1);
  } else if (inst->minor_op == e_wde || inst->minor_op == e_wds) {
    inst->type_u.write_dir_op_s.dir_lce_sel = parseDirLceSel(tokens->at(2));
    inst->type_u.write_dir_op_s.dir_way_sel = parseDirWaySel(tokens->at(3));
    if (inst->minor_op == e_wde) {
      inst->type_u.write_dir_op_s.dir_tag_sel = parseDirTagSel(tokens->at(4));
      inst->type_u.write_dir_op_s.dir_coh_state_sel = parseDirCohStSel(tokens->at(5));
      if (inst->type_u.write_dir_op_s.dir_coh_state_sel == e_dir_coh_sel_inst_imm) {
        inst->type_u.write_dir_op_s.imm = (uint8_t)(parseCohStImm(tokens->at(5)) & 0x3);
      }
    } else if (inst->minor_op == e_wds) {
      inst->type_u.write_dir_op_s.dir_coh_state_sel = parseDirCohStSel(tokens->at(4));
    } else {
      printf("Unknown Write Directory instruction\n");
      exit(-1);
    }
  } else {
    printf("Unknown Write Directory instruction\n");
    exit(-1);
  }
}

void
Assembler::parseMisc(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  if (inst->minor_op == e_gad) {
    /*
    inst->transfer_lce_sel = e_tr_lce_sel_logic;
    inst->transfer_lce_w_v = 1;
    inst->req_addr_way_sel = e_req_addr_way_sel_logic;
    inst->req_addr_way_w_v = 1;
    inst->tf_sel = e_tf_logic;
    inst->pruief_sel = e_pruief_logic;
    inst->flag_mask_w_v = (e_flag_tf | e_flag_rf | e_flag_uf | e_flag_if | e_flag_ef);
    */
  } else if (inst->minor_op != e_stall) {
    printf("Unknown Misc instruction: %s\n", tokens->at(0).c_str());
    exit(-1);
  }
}

bp_cce_inst_src_q_sel_e
Assembler::parseSrcQueue(string &s) {
  if (!s.compare("lcereq")) {
    return e_src_q_lce_req;
  } else if (!s.compare("memresp")) {
    return e_src_q_mem_resp;
  } else if (!s.compare("memdataresp")) {
    return e_src_q_mem_data_resp;
  } else if (!s.compare("pending")) {
    return e_src_q_pending;
  } else if (!s.compare("lceresp")) {
    return e_src_q_lce_resp;
  } else if (!s.compare("lcedataresp")) {
    return e_src_q_lce_data_resp;
  } else {
    printf("Unknown src queue select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_dst_q_sel_e
Assembler::parseDstQueue(string &s) {
  if (!s.compare("lcecmd")) {
    return e_dst_q_lce_cmd;
  } else if (!s.compare("lcedatacmd")) {
    return e_dst_q_lce_data_cmd;
  } else if (!s.compare("memcmd")) {
    return e_dst_q_mem_cmd;
  } else if (!s.compare("memdatacmd")) {
    return e_dst_q_mem_data_cmd;
  } else {
    printf("Unknown dst queue select operand: %s\n", s.c_str());
    exit(-1);
  }
}

bp_cce_inst_lce_cmd_lce_sel_e
Assembler::parseLceCmdLceSel(string &s) {
  if (!s.compare("req")) {
    return e_lce_cmd_lce_req_lce;
  } else if (!s.compare("tr")) {
    return e_lce_cmd_lce_tr_lce;
  } else if (!s.compare("r0")) {
    return e_lce_cmd_lce_r0;
  } else if (!s.compare("r1")) {
    return e_lce_cmd_lce_r1;
  } else if (!s.compare("r2")) {
    return e_lce_cmd_lce_r2;
  } else if (!s.compare("r3")) {
    return e_lce_cmd_lce_r3;
  } else {
    printf("Bad LCE Cmd LCE select operand\n");
    exit(-1);
  }
}

bp_cce_inst_lce_cmd_addr_sel_e
Assembler::parseLceCmdAddrSel(string &s) {
  if (!s.compare("req")) {
   return e_lce_cmd_addr_req_addr;
  } else if (!s.compare("lru")) {
   return e_lce_cmd_addr_lru_way_addr;
  } else if (!s.compare("r0")) {
    return e_lce_cmd_addr_r0;
  } else if (!s.compare("r1")) {
    return e_lce_cmd_addr_r1;
  } else if (!s.compare("r2")) {
    return e_lce_cmd_addr_r2;
  } else if (!s.compare("r3")) {
    return e_lce_cmd_addr_r3;
  } else {
   printf("Bad LCE Cmd Addr select operand\n");
   exit(-1);
  }
}

bp_cce_inst_lce_cmd_way_sel_e
Assembler::parseLceCmdWaySel(string &s) {
  if (!s.compare("req")) {
   return e_lce_cmd_way_req_addr_way;
  } else if (!s.compare("tr")) {
   return e_lce_cmd_way_tr_addr_way;
  } else if (!s.compare("shwayr0")) {
    return e_lce_cmd_way_sh_list_r0;
  } else if (!s.compare("lru")) {
    return e_lce_cmd_way_lru_addr_way;
  } else {
   printf("Bad LCE Cmd Way select operand\n");
   exit(-1);
  }
}

bp_cce_inst_mem_data_cmd_addr_sel_e
Assembler::parseMemDataCmdAddrSel(string &s) {
  if (!s.compare("req")) {
   return e_mem_data_cmd_addr_req_addr;
  } else if (!s.compare("lru")) {
   return e_mem_data_cmd_addr_lru_way_addr;
  } else {
   printf("Bad Mem Cmd Addr select operand\n");
   exit(-1);
  }
}

void
Assembler::parseQueue(vector<string> *tokens, int n, bp_cce_inst_s *inst) {
  if (inst->minor_op == e_wfq) {
    for (int i = 1; i < n; i++) {
      bp_cce_inst_src_q_sel_e q = parseSrcQueue(tokens->at(i));
      switch (q) {
        case e_src_q_lce_req:
          inst->type_u.queue_op_s.op.wfq.qmask |= (1 << 5);
          break;
        case e_src_q_lce_resp:
          inst->type_u.queue_op_s.op.wfq.qmask |= (1 << 4);
          break;
        case e_src_q_lce_data_resp:
          inst->type_u.queue_op_s.op.wfq.qmask |= (1 << 3);
          break;
        case e_src_q_mem_resp:
          inst->type_u.queue_op_s.op.wfq.qmask |= (1 << 2);
          break;
        case e_src_q_mem_data_resp:
          inst->type_u.queue_op_s.op.wfq.qmask |= (1 << 1);
          break;
        case e_src_q_pending:
          inst->type_u.queue_op_s.op.wfq.qmask |= (1);
          break;
        default:
          printf("Unknown src queue for WFQ\n");
          exit(-1);
      }
    }
  } else if (inst->minor_op == e_popq) {
    bp_cce_inst_src_q_sel_e srcQ = parseSrcQueue(tokens->at(1));
    inst->type_u.queue_op_s.op.popq.src_q = srcQ;
    /*
    switch (srcQ) {
      case e_src_q_lce_req:
        inst->req_sel = e_req_sel_lce_req;
        inst->req_w_v = 1;
        inst->lru_way_sel = e_lru_way_sel_lce_req;
        inst->lru_way_w_v = 1;
        inst->rqf_sel = e_rqf_lce_req;
        inst->nerldf_sel = e_nerldf_lce_req;
        inst->flag_mask_w_v = (e_flag_rqf | e_flag_nerf | e_flag_ldf);
        break;
      case e_src_q_mem_resp:
        inst->req_sel = e_req_sel_mem_resp;
        inst->req_w_v = 1;
        inst->req_addr_way_sel = e_req_addr_way_sel_mem_resp;
        inst->req_addr_way_w_v = 1;
        inst->lru_way_sel = e_lru_way_sel_mem_resp;
        inst->lru_way_w_v = 1;
        inst->transfer_lce_sel = e_tr_lce_sel_mem_resp;
        inst->transfer_lce_w_v = 1;
        inst->rqf_sel = e_rqf_mem_resp;
        inst->rwbf_sel = e_rwbf_mem_resp;
        inst->tf_sel = e_tf_mem_resp;
        inst->flag_mask_w_v = (e_flag_rqf | e_flag_rwbf | e_flag_tf);
        break;
      case e_src_q_mem_data_resp:
        inst->req_sel = e_req_sel_mem_data_resp;
        inst->req_w_v = 1;
        inst->req_addr_way_sel = e_req_addr_way_sel_mem_data_resp;
        inst->req_addr_way_w_v = 1;
        inst->lru_way_sel = e_lru_way_sel_mem_data_resp;
        inst->lru_way_w_v = 1;
        inst->cache_block_data_sel = e_data_sel_mem_data_resp;
        inst->cache_block_data_w_v = 1;
        inst->rqf_sel = e_rqf_mem_data_resp;
        inst->flag_mask_w_v = (e_flag_rqf);
        break;
      case e_src_q_pending:
        inst->req_sel = e_req_sel_pending;
        inst->req_w_v = 1;
        inst->lru_way_sel = e_lru_way_sel_pending;
        inst->lru_way_w_v = 1;
        inst->rqf_sel = e_rqf_pending;
        inst->nerldf_sel = e_nerldf_pending;
        inst->flag_mask_w_v = (e_flag_rqf | e_flag_nerf | e_flag_ldf);
        break;
      case e_src_q_lce_resp:
        inst->ack_type_w_v = 1;
        break;
      case e_src_q_lce_data_resp:
        inst->cache_block_data_sel = e_data_sel_lce_data_resp;
        inst->cache_block_data_w_v = 1;
        inst->nwbf_sel = e_nwbf_lce_data_resp;
        inst->flag_mask_w_v = (e_flag_nwbf);
        break;
      default:
        printf("Unknown queue\n");
        exit(-1);
    }
    */
  } else if (inst->minor_op == e_pushq) {
    bp_cce_inst_dst_q_sel_e dstQ = parseDstQueue(tokens->at(1));
    inst->type_u.queue_op_s.op.pushq.dst_q = dstQ;
    // set lce cmd lce, addr, and way select to the 0 select
    inst->type_u.queue_op_s.op.pushq.lce_cmd_lce_sel = e_lce_cmd_lce_0;
    inst->type_u.queue_op_s.op.pushq.lce_cmd_addr_sel = e_lce_cmd_addr_0;
    inst->type_u.queue_op_s.op.pushq.lce_cmd_way_sel = e_lce_cmd_way_0;
    // parse lce, addr, way, and mem_addr selects
    switch (dstQ) {
      case e_dst_q_lce_cmd:
        inst->type_u.queue_op_s.op.pushq.cmd = (bp_cce_lce_cmd_type_e)(parseImm(tokens->at(2)) & 0x7);
        if (tokens->size() > 3) {
          inst->type_u.queue_op_s.op.pushq.lce_cmd_lce_sel = parseLceCmdLceSel(tokens->at(3));
        }
        if (tokens->size() > 4) {
          inst->type_u.queue_op_s.op.pushq.lce_cmd_addr_sel = parseLceCmdAddrSel(tokens->at(4));
        }
        if (tokens->size() > 5) {
          inst->type_u.queue_op_s.op.pushq.lce_cmd_way_sel = parseLceCmdWaySel(tokens->at(5));
        }
        break;
      case e_dst_q_lce_data_cmd:
        // nothing special to set
        break;
      case e_dst_q_mem_cmd:
        // nothing special to set
        break;
      case e_dst_q_mem_data_cmd:
        inst->type_u.queue_op_s.op.pushq.mem_data_cmd_addr_sel = parseMemDataCmdAddrSel(tokens->at(2));
        break;
      default:
        printf("Unknown queue\n");
        exit(-1);
    }
  } else {
    printf("Unknown Queue instruction: %d\n", tokens->at(0).c_str());
    exit(-1);
  }
}

// parse based on tokens[0]
void
Assembler::parseTokens(vector<string> *tokens, int n, bp_cce_inst_s *inst) {

  // All instructions
  inst->op = getOp(tokens->at(0).c_str());
  inst->minor_op = getMinorOp(tokens->at(0).c_str());

  switch (inst->op) {
    case e_op_alu:
      parseALU(tokens, n, inst);
      break;
    case e_op_branch:
      parseBranch(tokens, n, inst);
      break;
    case e_op_move:
    case e_op_flag:
      parseMove(tokens, n, inst);
      break;
    case e_op_read_dir:
      parseReadDir(tokens, n, inst);
      break;
    case e_op_write_dir:
      parseWriteDir(tokens, n, inst);
      break;
    case e_op_misc:
      parseMisc(tokens, n, inst);
      break;
    case e_op_queue:
      parseQueue(tokens, n, inst);
      break;
    default:
      printf("Error parsing instruction\n");
      exit(-1);
  }
}

Assembler::Assembler() {
  infp = stdin;
  outfp = stdout;
  line_number = 0;

  printf("instruction length: %d\n", bp_cce_inst_s_width);
}

Assembler::~Assembler() {
  if (infp != stdin) {
    fclose(infp);
  }
  if (outfp != stdout) {
    fclose(outfp);
  }
}

void
Assembler::tokenizeAndLabel() {
  // Read all lines, tokenize, and remove labels (while assigning to addresses)
  while (readLine(input_line, MAX_LINE_LENGTH, infp) > 0) {
    uint16_t addr = line_number-1;

    printf("(%d) %s\n", addr, input_line);

    lines.push_back(string(input_line));

    int numTokens = tokenizeLine(input_line, input_line_tokens);

    numTokens = parseLabels(input_line_tokens, numTokens, addr);

    vector<string> *inst_tokens = new vector<string>();
    for (int i = 0; i < numTokens; i++) {
      inst_tokens->push_back(string(input_line_tokens[i]));
    }
    tokens.push_back(inst_tokens);
    num_tokens.push_back(numTokens);
  }
}

void
Assembler::assemble() {
  // Transform tokenized instructions into instruction struct, then write to output
  bp_cce_inst_s inst;
  unsigned int i = 0;
  while (i < tokens.size()) {
    inst = {};
    parseTokens(tokens.at(i), num_tokens.at(i), &inst);
    writeInstToOutput(&inst, (uint16_t)i, tokens.at(i)->at(0));
    i++;
  }
}

void
Assembler::parseArgs(int argc, char *argv[]) {
  int i = 1;

  while (i < argc) {
    if (argv[i][0] == '-') {
      switch(argv[i][1]) {
        case  'i':
        case  'I':
          infp = fopen(argv[i + 1], "r");
          if (!infp) {
            printf("Failure to open input file: %s\n", argv[i + 1]);
            exit(__LINE__);
          }
          i += 2;
          break;
        case  'o':
        case  'O':
          outfp = fopen(argv[i + 1], "w");
          if (!outfp) {
            printf("Failure to create output file: %s\n", argv[i + 1]);
            exit(__LINE__);
          }
          i += 2;
          break;
        case  'b':
        case  'B':
          output_format = output_format_ascii_binary;
          ++i;
          break;
        case  'd':
        case  'D':
          output_format = output_format_dbg;
          ++i;
          break;
        default:
          printf("Usage:\n"
            "\t-i <input>   input file\n"
            "\t-o <output>    output file\n"
            "\t-b       output ascii binary\n"
            "\t-d       output debug\n");
          exit(__LINE__);
      }
    } else {
      printf("Try -- for help\n");
      exit(-__LINE__);
    }
  }
}

void
Assembler::printShortField(uint8_t b, int bits, stringstream &ss) {
  int i = 0;
  uint8_t mask = (1 << (bits-1));
  while (i < bits) {
    if (b & mask) {
      ss << "1";
    } else {
      ss << "0";
    }
    mask = mask >> 1;
    ++i;
  }
}

void
Assembler::printLongField(uint16_t b, int bits, stringstream &ss) {
  int i = 0;
  uint16_t mask = (1 << (bits-1));
  while (i < bits) {
    if (b & mask) {
      ss << "1";
    } else {
      ss << "0";
    }
    mask = mask >> 1;
    ++i;
  }
}

void
Assembler::printField(uint64_t b, int bits, stringstream &ss) {
  int i = 0;
  uint64_t mask = (1 << (bits-1));
  while (i < bits) {
    if (b & mask) {
      ss << "1";
    } else {
      ss << "0";
    }
    mask = mask >> 1;
    ++i;
  }
}

void
Assembler::printPad(int bits, stringstream &ss) {
  for (int i = 0; i < bits; i++) {
    ss << "0";
  }
}

void
Assembler::writeInstToOutput(bp_cce_inst_s *inst, uint16_t line_number, string &s) {

  stringstream ss;

  //ss << "(" << line_number << ") ";

  printShortField(inst->op, bp_cce_inst_op_width, ss);
  printShortField(inst->minor_op, bp_cce_inst_minor_op_width, ss);

  switch (inst->op) {
    case e_op_alu:
      printShortField(inst->type_u.alu_op_s.dst, bp_cce_inst_dst_width, ss);
      printShortField(inst->type_u.alu_op_s.src_a, bp_cce_inst_src_width, ss);
      printShortField(inst->type_u.alu_op_s.src_b, bp_cce_inst_src_width, ss);
      printLongField(inst->type_u.alu_op_s.imm, bp_cce_inst_imm16_width, ss);
      printPad(bp_cce_inst_alu_pad, ss);
      break;
    case e_op_branch:
      printShortField(inst->type_u.branch_op_s.src_a, bp_cce_inst_src_width, ss);
      printShortField(inst->type_u.branch_op_s.src_b, bp_cce_inst_src_width, ss);
      printLongField(inst->type_u.branch_op_s.imm, bp_cce_inst_imm16_width, ss);
      printPad(bp_cce_inst_branch_pad, ss);
      break;
    case e_op_move:
      printShortField(inst->type_u.mov_op_s.dst, bp_cce_inst_dst_width, ss);
      printShortField(inst->type_u.mov_op_s.src, bp_cce_inst_src_width, ss);
      printLongField(inst->type_u.mov_op_s.imm, bp_cce_inst_imm16_width, ss);
      printPad(bp_cce_inst_mov_pad, ss);
      break;
    case e_op_flag:
      printShortField(inst->type_u.flag_op_s.dst, bp_cce_inst_dst_width, ss);
      printShortField(inst->type_u.flag_op_s.imm, 1, ss);
      printPad(bp_cce_inst_flag_pad, ss);
      break;
    case e_op_read_dir:
      printShortField(inst->type_u.read_dir_op_s.dir_way_group_sel, bp_cce_inst_dir_way_group_sel_width, ss);
      printShortField(inst->type_u.read_dir_op_s.dir_lce_sel, bp_cce_inst_dir_lce_sel_width, ss);
      printShortField(inst->type_u.read_dir_op_s.dir_way_sel, bp_cce_inst_dir_way_sel_width, ss);
      printPad(bp_cce_inst_read_dir_pad, ss);
      break;
    case e_op_write_dir:
      printShortField(inst->type_u.write_dir_op_s.dir_way_group_sel, bp_cce_inst_dir_way_group_sel_width, ss);
      printShortField(inst->type_u.write_dir_op_s.dir_lce_sel, bp_cce_inst_dir_lce_sel_width, ss);
      printShortField(inst->type_u.write_dir_op_s.dir_way_sel, bp_cce_inst_dir_way_sel_width, ss);
      printShortField(inst->type_u.write_dir_op_s.dir_coh_state_sel, bp_cce_inst_dir_coh_state_sel_width, ss);
      printShortField(inst->type_u.write_dir_op_s.dir_tag_sel, bp_cce_inst_dir_tag_sel_width, ss);
      printShortField(inst->type_u.write_dir_op_s.imm, bp_cce_coh_bits, ss);
      printPad(bp_cce_inst_write_dir_pad, ss);
      break;
    case e_op_misc:
      printPad(bp_cce_inst_misc_pad, ss);
      break;
    case e_op_queue:
      if (inst->minor_op == e_wfq) {
        printShortField(inst->type_u.queue_op_s.op.wfq.qmask, bp_cce_num_src_q, ss);
        printPad(bp_cce_inst_wfq_pad, ss);
      } else if (inst->minor_op == e_pushq) {
        printShortField(inst->type_u.queue_op_s.op.pushq.dst_q, bp_cce_inst_dst_q_sel_width, ss);
        printShortField(inst->type_u.queue_op_s.op.pushq.cmd, bp_cce_lce_cmd_type_width, ss);
        printShortField(inst->type_u.queue_op_s.op.pushq.lce_cmd_lce_sel, bp_cce_inst_lce_cmd_lce_sel_width, ss);
        printShortField(inst->type_u.queue_op_s.op.pushq.lce_cmd_addr_sel, bp_cce_inst_lce_cmd_addr_sel_width, ss);
        printShortField(inst->type_u.queue_op_s.op.pushq.lce_cmd_way_sel, bp_cce_inst_lce_cmd_way_sel_width, ss);
        printShortField(inst->type_u.queue_op_s.op.pushq.mem_data_cmd_addr_sel, bp_cce_inst_mem_data_cmd_addr_sel_width, ss);
        printPad(bp_cce_inst_pushq_pad, ss);
      } else if (inst->minor_op == e_popq) {
        printShortField(inst->type_u.queue_op_s.op.popq.src_q, bp_cce_inst_src_q_sel_width, ss);
        printPad(bp_cce_inst_popq_pad, ss);
      }
      break;
    default:
      printf("Error parsing instruction\n");
      printf("line: %d\n", line_number);
      exit(-1);
  }

  /* TODO: print out of instructions based on type
  printShortField(inst->src_a, bp_cce_inst_src_width, ss);
  printShortField(inst->src_b, bp_cce_inst_src_width, ss);
  printShortField(inst->dst, bp_cce_inst_dst_width, ss);

  printLongField(inst->imm, bp_cce_inst_gpr_width, ss);

  printShortField(inst->req_sel, bp_cce_inst_req_sel_width, ss);
  printShortField(inst->req_addr_way_sel, bp_cce_inst_req_addr_way_sel_width, ss);
  printShortField(inst->lru_way_sel, bp_cce_inst_lru_way_sel_width, ss);
  printShortField(inst->transfer_lce_sel, bp_cce_inst_transfer_lce_sel_width, ss);
  printShortField(inst->cache_block_data_sel, bp_cce_inst_dat_sel_width, ss);

  printShortField(inst->rqf_sel, bp_cce_inst_rq_flag_sel_width, ss);
  printShortField(inst->nerldf_sel, bp_cce_inst_ner_ld_flag_sel_width, ss);
  printShortField(inst->nwbf_sel, bp_cce_inst_nwb_flag_sel_width, ss);
  printShortField(inst->tf_sel, bp_cce_inst_t_flag_sel_width, ss);
  printShortField(inst->pruief_sel, bp_cce_inst_pruie_flag_sel_width, ss);
  printShortField(inst->rwbf_sel, bp_cce_inst_rwb_flag_sel_width, ss);

  printShortField(inst->dir_way_group_sel, bp_cce_inst_dir_way_group_sel_width, ss);
  printShortField(inst->dir_lce_sel, bp_cce_inst_dir_lce_sel_width, ss);
  printShortField(inst->dir_way_sel, bp_cce_inst_dir_way_sel_width, ss);
  printShortField(inst->dir_coh_state_sel, bp_cce_inst_dir_coh_state_sel_width, ss);
  printShortField(inst->dir_tag_sel, bp_cce_inst_dir_tag_sel_width, ss);

  printShortField(inst->lce_cmd_lce_sel, bp_cce_inst_lce_cmd_lce_sel_width, ss);
  printShortField(inst->lce_cmd_addr_sel, bp_cce_inst_lce_cmd_addr_sel_width, ss);
  printShortField(inst->lce_cmd_way_sel, bp_cce_inst_lce_cmd_way_sel_width, ss);

  printShortField(inst->mem_data_cmd_addr_sel, bp_cce_inst_mem_data_cmd_addr_sel_width, ss);

  printShortField(inst->req_w_v, 1, ss);
  printShortField(inst->req_addr_way_w_v, 1, ss);
  printShortField(inst->lru_way_w_v, 1, ss);
  printShortField(inst->transfer_lce_w_v, 1, ss);
  printShortField(inst->cache_block_data_w_v, 1, ss);
  printShortField(inst->ack_type_w_v, 1, ss);

  printLongField(inst->flag_mask_w_v, bp_cce_inst_num_flags, ss);
  */

  switch (output_format) {
    case  output_format_ascii_binary:
      fprintf(outfp, "%s\n", ss.str().c_str());
      break;
    case  output_format_dbg:
      fprintf(outfp, "(%02X) %5s : %s\n", line_number, s.c_str(), ss.str().c_str());
      break;
  }
}

// read line from input
int
Assembler::readLine(char *s, int maxLineLen, FILE *infp) {
  char ch;
  int n = 0;

  while (n < maxLineLen) {
    // end of file
    if (feof(infp)) {
      if (n > 0)
        return n;
      else
        return -1;
    }

    // read next character
    ch = fgetc(infp);

    // eof character check
    if (feof(infp) && n == 0) {
      return -1;
    }

    // comment character at start of line, discard line
    if (_iscommentstart(ch) && n == 0) {
      //fgetc(infp);  // discard character
      // read through newline or EOF
      fgets(s, maxLineLen, infp);
      continue;
    }

    // Skip white space at the start of a line
    if ((_iswhitespace(ch) || _isnewline(ch)) && n == 0) {
      continue;
    }

    // Update the line number if needed
    if (_ishardnewline(ch)) {
      ++line_number;
    }

    // end of line, return
    if (_isnewline(ch) && n != 0) {
      *s = '\0';
      return n;
    }

    // comment in middle of line, consume rest of line and return
    if (_iscommentstart(ch) && n != 0) {
      *s = '\0';
      // consume rest of line, up to new line
      ch = fgetc(infp);
      while (ch) {
        if (_isnewline(ch)) {
          // newline character found, erase whitespace at end of line
          --s;
          --n;
          while (_iswhitespace(*s)) {
            --s;
            --n;
          }
          ++s;
          *s = '\0';
          return n;
        }
        ch = fgetc(infp);
      }
      printf("returning after while loop\n");
      return n;
    }

    *s = _lowercase(ch);
    ++s;
    ++n;
  }
  printf("Long line on input\n");
  exit(-__LINE__);
}

// tokenize line
int
Assembler::tokenizeLine(char* input_line, char tokens[MAX_TOKENS][MAX_LINE_LENGTH]) {
  // Parse the input line into individual tokens
  // current token
  int token = 0;
  // character position within current token
  int i = 0;
  // character iterator for line
  char *s = input_line;

  // initialize tokens to null strings
  for (token = 0; token < MAX_TOKENS; token++) {
    tokens[token][0] = '\0';
  }

  token = 0;
  while (*s) {
    if (token >= MAX_TOKENS) {
      if (!(*s)) {
        printf("Cannot parse: (%d) %s\n", line_number-1, input_line);
        exit(-__LINE__);
      }
      break;
    }

    // whitespace character, terminate this token
    if (_iswhitespace(*s)) {
      tokens[token][i] = '\0';
      i = 0;
      ++token;
      ++s;
      // consume whitespace
      while (*s && _iswhitespace(*s)) {
        ++s;
      }
    // normal character, add to token
    } else {
      tokens[token][i] = *s;
      ++i;
      ++s;
    }
  }

  // after reading last valid character of the line, terminate the last token
  if (!(*s) && i > 0) {
    tokens[token][i] = '\0';
    ++token;
  }

  return token;
}

int
Assembler::parseLabels(char tokens[MAX_TOKENS][MAX_LINE_LENGTH], int n, uint16_t addr) {
  // parse label if present
  string s (tokens[0]);
  if (s.back() == ':') {
    if (labels_to_addr.find(s) == labels_to_addr.end()) {
      s = s.substr(0, s.size()-1);
      labels_to_addr.insert(pair<string, uint16_t>(s, addr));
      // remove the label from the tokens
      for (int i = 1; i < n; i++) {
        memcpy(tokens[i-1], tokens[i], strlen(tokens[i])+1);
      }
      tokens[n-1][0] = '\0';
      return n-1;
    } else {
      printf("Duplicate label: %s\n", tokens[0]);
      exit(-1);
    }
  }
  return n;
}
