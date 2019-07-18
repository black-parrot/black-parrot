#include <stdint.h>

#include "bp_utils.h"

void copy_function(void) {
    uint64_t print_addr = (uint64_t)(0x000000008FFFFFFF);
    uint64_t print_item = 1;

    bp_hprint(print_item);
}

uint64_t main(uint64_t argc, char *argv[]) {
    uint64_t *copy_start = (uint64_t *)(0x00000000800001c4);
    uint64_t *copy_end = (uint64_t *)(0x0000000080000204);
    uint64_t *copy_addr;
    uint64_t *copy_dest = (uint64_t *)(0x0000000080001124); 
    void (*copied_function)() = (void *)copy_dest;
    
    for (copy_addr = copy_start; copy_addr < copy_end; 
            copy_addr += 1, copy_dest += 1) {
        *copy_dest = *copy_addr;
    }

    copied_function();

    return 0;
}
