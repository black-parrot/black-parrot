
#include <stdint.h>
#include "bp_utils.h"

#ifndef N 
#define N 100
#endif

int main(int argc, char** argv) {

    uint64_t core_id = bp_get_hart();
    uint64_t *base_addr = (uint64_t *)(0x80100000 + (core_id << 14));

    for (int i = 0; i < 5; i++) {
        *(base_addr + i) = i;
    }

    bp_finish(0);

    return 0;
}
