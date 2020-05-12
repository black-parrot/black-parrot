
#include <stdint.h>
#include "bp_utils.h"

// This test requires manual verification to see if the cache is actually flushing
// Additionally, this will cause problems in cosim since there is no l2 cache model

int main(int argc, char** argv) {
    uint64_t l2s_sets = 128;
    uint64_t l2s_assoc = 8;
    uint64_t l2s_blocksize = 64;

    uint64_t paddr_bits = 40;

    uint64_t offset_bits = 6;
    uint64_t index_bits = 7;
    uint64_t tag_bits = 27;

    uint64_t tag_offset = index_bits + offset_bits;

    uint64_t core_id = bp_get_hart();
    uint64_t *base_addr; 

    base_addr = (uint64_t *)(0x80100000 + (core_id << 14));
    for (int i = 0; i < l2s_sets; i++) {
        for (int j = 0; j < l2s_assoc; j++) {
            uint64_t *addr = base_addr + (i << index_bits) + (j << tag_offset);
            uint64_t data = (uint64_t) addr | 0x0fff;

            *addr = data;
        }
    }

    base_addr = (uint64_t *)(0x00400000);
    for (int i = 0; i < l2s_sets; i++) {
        for (int j = 0; j < l2s_assoc; j++) {
            uint64_t *addr = base_addr;
            uint64_t data = (j << tag_offset) + (i << offset_bits);

            *addr = data;
        }
    }

    base_addr = (uint64_t *)(0x80100000 + (core_id << 14));
    for (int i = 0; i < l2s_sets; i++) {
        for (int j = 0; j < l2s_assoc; j++) {
            uint64_t *addr = base_addr + (i << index_bits) + (j << tag_offset);
            uint64_t expected = (uint64_t) addr | 0x0fff;
            uint64_t actual = *addr;

            if (expected != actual) {
               bp_finish(-1);
            }
        }
    }

    bp_finish(0);

    return 0;
}
