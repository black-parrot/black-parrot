
#include "svdpi.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <cstdint>
#include <string>
#include <cstdlib>
#include <map>
#include <queue>

#include "DRAMSim.h"

class bp_dram
{
  public:
    std::map<string, bool> result_pending;
    std::map<uint64_t, std::queue<string>> addr_tracker;

  public:
    void read_complete(unsigned, uint64_t, uint64_t);
    void write_complete(unsigned, uint64_t, uint64_t);
};

