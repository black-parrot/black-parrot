
#include <stdint.h>
#include "bp_utils.h"

#ifndef N 
#define N 100
#endif

long long test_gshare() {
    long long x = 0;

    for (long long j = 0; j < 100; j++) {
      for (long long i = 0; i < 2; i++) {
         x = 1;
         x = 2;
         x = 3;
      }
      for (long long i = 0; i < 2; i++) {
         x = 1;
         x = 2;
         x = 3;
      }
      for (long long i = 0; i < 2; i++) {
         x = 1;
         x = 2;
         x = 3;
      }
    }

    return x;
}

// 3 mispredicts, end up weakly taken for loops, strongly not taken for branch
int test_loop() {
    int x = 0;

    for (int j = 0; j < 3; j++) {
        for (int i = 0; i < 3; i++) {
            if (i < 100) {
                x++;
            }
        }
    }

    return x;
}

// 0 mispredicts
int test_branch_taken() {
    int a = 0;
    int x = 0;

    if (a < 0) {
      x++;
    }

    if (a < 0) {
      x++;
    }

    if (a < 0) {
      x++;
    }

    return x;
}

// 3 mispredicts
int test_branch_ntaken() {
    int a = 0;
    int x = 0;

    if (a == 0) {
      x++;
    }

    if (a == 0) {
      x++;
    }

    if (a == 0) {
      x++;
    }

    return x;
}

int test_branch_mixed() {
    int a = 0;
    int x = 0;

    // Not taken
    if (a == 0) {
        x++;
    }

    // Taken
    if (a != 0) {
        x++;
    }

    // Not taken
    if (a == 0) {
        x++;
    }

    // Taken
    if (a != 0) {
        x++;
    }

    // Not taken
    if (a == 0) {
        x++;
    }

    // Taken
    if (a == 0) {
        x++;
    }

    return x;
}

int test_memcpy(uint8_t *dest, uint8_t *src, int len) {
    for (int i = 0; i < len; i++) {
        dest[i] = src[i];
    }

    return 0;
}

int test_strlen(uint8_t *str) {
    int i = 0;

    while(str[i++]);

    return i;
}

int main(int argc, char** argv) {

    uint64_t core_id = bp_get_hart();
    uint64_t *base_addr = (uint64_t *)(0x80100000 + (core_id << 14));

    int x = 0;

    //x += test_loop();
    //x += test_branch_taken();
    //x += test_branch_ntaken();
    //x += test_branch_mixed();
    //x += test_memcpy(base_addr, base_addr+2048, 128);
    //x += test_strlen("deadbeefdeadbeef");
    x += test_gshare();

    bp_finish(0);

    return 0;
}
