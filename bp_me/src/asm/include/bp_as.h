/*
 * bp_as.h
 *
 * @author markw
 *
 */

#ifndef BP_AS_H
#define BP_AS_H

#include <cstdlib>
#include <cstdio>
#include <cstdint>
#include <cstring>

#include <string>
#include <map>
#include <vector>
#include <sstream>

#include "bp_cce_inst.h"

#define MAX_LINE_LENGTH 2048
#define MAX_TOKENS  20

using namespace std;

enum {
  output_format_ascii_binary = 1,
  output_format_dbg,
};

typedef struct {
  bp_cce_inst_type_e encoding;
  bp_cce_inst_s      inst;
} parsed_inst_s;

typedef struct pushq_args {
  bp_cce_inst_dst_q_sel_e        dst_q;

  bp_lce_cmd_type_e              lce_cmd;
  bp_mem_msg_e                   mem_cmd;

  bp_cce_inst_mux_sel_addr_e     addr_sel;
  bp_cce_inst_mux_sel_lce_e      lce_sel;
  bp_cce_inst_mux_sel_way_e      way_sel;
  bp_cce_inst_opd_e              src;

  uint16_t                       wp;
  uint16_t                       spec;
  uint16_t                       custom;

  pushq_args() {
    dst_q = e_dst_q_sel_lce_cmd;
    lce_cmd = e_lce_cmd_sync;
    mem_cmd = e_mem_msg_rd;
    addr_sel = e_mux_sel_addr_r0;
    lce_sel = e_mux_sel_lce_r0;
    way_sel = e_mux_sel_way_r0;
    src = e_opd_r0;
    wp = 0;
    spec = 0;
    custom = 0;
  };

} pushq_args;

typedef struct dir_args {

  bp_cce_inst_mux_sel_addr_e       addr_sel;
  bp_cce_inst_mux_sel_lce_e        lce_sel;
  bp_cce_inst_mux_sel_way_e        way_sel;
  bp_cce_inst_mux_sel_coh_state_e  state_sel;

  bp_cce_inst_opd_e                src;
  bp_cce_inst_opd_e                dst;

  uint16_t                         pending;
  bp_coh_states_e                  state;

  dir_args() {
  };

} dir_args;

class Assembler
{
protected:
  FILE *infp;
  FILE *outfp;
  int  output_format;
  bool debug_mode;

  uint16_t line_number;
  char input_line[MAX_LINE_LENGTH];
  char input_line_tokens[MAX_TOKENS][MAX_LINE_LENGTH];

  vector<string> lines;
  vector<vector<string>*> tokens;
  vector<int> num_tokens;

  // Map of labels from assembly code to instruction addresses
  map<string, uint16_t> labels_to_addr;

  // Utility Functions
  bool _iscommentstart(char ch);
  bool _iswhitespace(char ch);
  bool _ishardnewline(char ch);
  bool _isnewline(char ch);
  char _lowercase(char ch);

  int readLine(char *s, int maxLineLen, FILE *infp);
  int tokenizeLine(char* input_line, char tokens[MAX_TOKENS][MAX_LINE_LENGTH]);
  int parseLabels(char tokens[MAX_TOKENS][MAX_LINE_LENGTH], int n, uint16_t addr);

  // Output Utility / Print Functions
  void printField(uint32_t b, int bits, stringstream &ss);
  void printPad(int bits, stringstream &ss);

  // Microcode Assembler Helper Functions
  bp_cce_inst_op_e getOp(string &s);
  uint8_t getMinorOp(string &s);
  bp_cce_inst_opd_e parseOpd(string &s);

  uint16_t parseImm(string &s);
  //uint16_t parseCohStImm(string &s);
  uint16_t parseTarget(string &s, bool &found);
  uint16_t getBranchTarget(string &target_str);
  uint8_t parseBranchPrediction(string &prediction);
  uint8_t parseWritePending(string &s);
  void parsePushQueueArgs(vector<string> *tokens, int n, pushq_args *args);
  void parseDirArgs(vector<string> *tokens, int n, dir_args *args);

  bp_cce_inst_flag_onehot_e parseFlagOneHot(string &s, bool &error);

  bp_cce_inst_mux_sel_addr_e parseAddrSel(string &s);
  bp_cce_inst_mux_sel_lce_e parseLceSel(string &s);
  bp_cce_inst_mux_sel_way_e parseWaySel(string &s);
  bp_cce_inst_mux_sel_coh_state_e parseCohStateSel(string &s);

  bp_cce_inst_spec_op_e parseSpecCmd(string &s);

  bp_cce_inst_src_q_sel_e parseSrcQueue(string &s);
  bp_cce_inst_src_q_e parseSrcQueueOneHot(string &s);
  bp_cce_inst_dst_q_sel_e parseDstQueue(string &s);
  bp_cce_inst_dst_q_e parseDstQueueOneHot(string &s);

  // Microcode Parsing Functions
  void parseALU(vector<string> *tokens, int n, parsed_inst_s *inst);
  void parseBranch(vector<string> *tokens, int n, parsed_inst_s *inst);
  void parseRegData(vector<string> *tokens, int n, parsed_inst_s *inst);
  //void parseMem(vector<string> *tokens, int n, parsed_inst_s *inst);
  void parseFlag(vector<string> *tokens, int n, parsed_inst_s *inst);
  void parseDir(vector<string> *tokens, int n, parsed_inst_s *inst);
  void parseQueue(vector<string> *tokens, int n, parsed_inst_s *inst);

  void parseTokens(vector<string> *tokens, int n, parsed_inst_s *parsed_inst);

  // Output Function
  void writeInstToOutput(parsed_inst_s *inst, uint16_t line_number, string &s);

public:
  // Public Functions
  Assembler();
  //Assembler(int output_format);
  ~Assembler();

  void parseArgs(int argc, char *argv[]);
  void tokenizeAndLabel();
  void assemble();

};

#endif
