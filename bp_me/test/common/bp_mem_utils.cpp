
#include "svdpi.h"

#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <cstdint>
#include <string>
#include <cstdlib>
#include <map>
#include <queue>

extern "C" char *rebase_hexfile(char *memfile_name, uint64_t dram_base)
{
  std::string hexfile_name = std::string(memfile_name);

  hexfile_name.append(".rebase");

  std::string line, tok;
  char delimiter = ' ';
  std::ifstream memfile(memfile_name);
  std::ofstream hexfile(hexfile_name);

  uint64_t current_addr;
  if (memfile.is_open() && hexfile.is_open()) {
    while (getline(memfile, line)) {
      if (line.find("@") != std::string::npos) {
        current_addr = std::stoull(line.substr(1), nullptr, 16);
        hexfile << "@" << std::hex << current_addr - dram_base << std::endl;
      } else {
        hexfile << line << std::endl;
      }
    }
  }

  char *hexfile_string = new char[100];
  strcpy(hexfile_string, hexfile_name.c_str());

  return hexfile_string;
}

