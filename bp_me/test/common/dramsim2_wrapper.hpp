
#include "svdpi.h"
#include "svdpi_src.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <cstdint>
#include <string>
#include <cstdlib>
#include <map>

#include "DRAMSim.h"

class bp_dram
{
  public:
    std::map<uint64_t, uint8_t> mem;

    SV_BIT_PACKED_ARRAY(512, result_data);
    bool result_pending;


  public:
    void read_hex(char *);

    void read_complete(unsigned, uint64_t, uint64_t);
    void write_complete(unsigned, uint64_t, uint64_t);
};

