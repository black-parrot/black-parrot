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

class Assembler
{
protected:
  FILE *infp;
  FILE *outfp;
  int  output_format;

  uint16_t line_number;
  char input_line[MAX_LINE_LENGTH];
  char input_line_tokens[MAX_TOKENS][MAX_LINE_LENGTH];

  vector<string> lines;
  vector<vector<string>*> tokens;
  vector<int> num_tokens;

  // Map of labels from assembly code to instruction addresses
  map<string, uint16_t> labels_to_addr;

  // Input Parsing Helpers
  bool _iscommentstart(char ch);
  bool _iswhitespace(char ch);
  bool _ishardnewline(char ch);
  bool _isnewline(char ch);
  char _lowercase(char ch);

  // Assembler Helper Functions
  bp_cce_inst_op_e getOp(const char* op);
  uint8_t getMinorOp(const char* op);

  bp_cce_inst_src_e parseSrcOpd(string &s);
  bp_cce_inst_dst_e parseDstOpd(string &s);

  uint32_t parseImm(string &s, int immSize);
  uint32_t parseCohStImm(string &s);
  uint16_t getBranchTarget(string &target_str);
  bp_cce_inst_flag_e parseFlagSel(string &s);
  bp_cce_inst_dir_way_group_sel_e parseDirWgSel(string &s);
  bp_cce_inst_dir_lce_sel_e parseDirLceSel(string &s);
  bp_cce_inst_dir_way_sel_e parseDirWaySel(string &s);
  bp_cce_inst_dir_tag_sel_e parseDirTagSel(string &s);
  bp_cce_inst_dir_coh_state_sel_e parseDirCohStSel(string &s);
  bp_cce_inst_src_q_sel_e parseSrcQueue(string &s);
  bp_cce_inst_dst_q_sel_e parseDstQueue(string &s);
  bp_cce_inst_lce_cmd_lce_sel_e parseLceCmdLceSel(string &s);
  bp_cce_inst_lce_cmd_addr_sel_e parseLceCmdAddrSel(string &s);
  bp_cce_inst_lce_cmd_way_sel_e parseLceCmdWaySel(string &s);
  bp_cce_inst_mem_cmd_addr_sel_e parseMemCmdAddrSel(string &s);

  int readLine(char *s, int maxLineLen, FILE *infp);
  int tokenizeLine(char* input_line, char tokens[MAX_TOKENS][MAX_LINE_LENGTH]);
  int parseLabels(char tokens[MAX_TOKENS][MAX_LINE_LENGTH], int n, uint16_t addr);
  void parseTokens(vector<string> *tokens, int n, bp_cce_inst_s *inst);

  void printShortField(uint8_t b, int bits, stringstream &ss);
  void printLongField(uint16_t b, int bits, stringstream &ss);
  void printField(uint32_t b, int bits, stringstream &ss);
  void printPad(int bits, stringstream &ss);
  void writeInstToOutput(bp_cce_inst_s *inst, uint16_t line_number, string &s);

  void parseALU(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseBranch(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseMove(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseFlag(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseReadDir(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseWriteDir(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseMisc(vector<string> *tokens, int n, bp_cce_inst_s *inst);
  void parseQueue(vector<string> *tokens, int n, bp_cce_inst_s *inst);

  uint16_t parseTarget(string &s, bool &found);

public:
  // Public Functions
  Assembler();
  Assembler(int output_format);
  ~Assembler();

  void parseArgs(int argc, char *argv[]);
  void tokenizeAndLabel();
  void assemble();

};

#endif
