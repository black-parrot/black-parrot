/*
 * Name:
 *   mc_work_share_sort.c
 *
 * Description:
 *   This program utilizes many cores to cooperatively sort a collection of arrays.
 *
 */

#include <stdint.h>
#include <stddef.h>
#include "bp_utils.h"
#include "mc_util.h"
#include "mc_data.h"

#ifndef NUM_CORES
#define NUM_CORES 2
#endif

// DATA_LEN define from "mc_data.h" gives total number of elements in DATA array

// Length of each array
// This should be set such that an array evenly fills one or more 64-byte cache blocks
// There are 16 32-bit values in each 512-bit cache block
#ifndef ARR_LEN
#define ARR_LEN 32
#endif

// Number of arrays
// This should be equal to or less than DATA_LEN/ARR_LEN
// e.g., 65536/64 = 1024 64-element arrays
#ifndef N
#define N 32
#endif


// global variables written only by core 0
volatile uint64_t __attribute__((aligned(64))) start_barrier_mem = 0;
volatile uint64_t __attribute__((aligned(64))) end_barrier_mem = 0;

// global lock for shared global variables
volatile uint64_t __attribute__((aligned(64))) global_lock = 0;

volatile uint64_t __attribute__((aligned(64))) read_count = 0;
volatile uint64_t __attribute__((aligned(64))) read_index = 0;

void swap(uint32_t *x, uint32_t * y) {
  uint32_t t = *x;
  *x = *y;
  *y = t;
}

void sortArray(uint32_t *array) {
  // bubble sort because we want the core to do work :)
  for (int i = 0; i < ARR_LEN-1; i++) {
    for (int j = 0; j < ARR_LEN-i-1; j++) {
      if (array[j] > array[j+1]) {
        swap(&array[j], &array[j+1]);
      }
    }
  }
}

uint32_t getNextArray(uint32_t **array) {
  uint64_t local_read_count;
  lock(&global_lock);
  if (read_count < N) {
    local_read_count = read_count;
    *array = &DATA[read_index];
    // ARRAYS is a one-dimensional array, which we treat as a two-dimensional array
    // increment the read_index by the length of each sub-array
    read_index += ARR_LEN;
    read_count += 1;
    unlock(&global_lock);
    return local_read_count;
  }
  unlock(&global_lock);
  *array = NULL;
  return 0;
}

uint64_t thread_main() {
  uint64_t core_id;
  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

  while (1) {
    uint32_t *array = NULL;
    uint32_t arr_index = getNextArray(&array);
    if (array) {
      sortArray(array);
      bp_hprint(arr_index);
    } else {
      break;
    }
  }

  // synchronize at end of computation by incrementing the end barrier
  lock(&global_lock);
  end_barrier_mem += 1;
  unlock(&global_lock);

}

uint64_t main(uint64_t argc, char * argv[]) {
  uint64_t core_id;
  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

  // only core 0 intializes data structures
  if (core_id == 0) {
    global_lock = 0;
    read_index = 0;
    read_count = 0;
    end_barrier_mem = 0;

    // signal done with initialization
    start_barrier_mem = 0xdeadbeef;
  }
  else {
    while (start_barrier_mem != 0xdeadbeef) { }
  }

  // all threads execute
  thread_main();

  // core 0 waits for all threads to finish
  if (core_id == 0) {
    // wait for all threads to finish
    while (end_barrier_mem != NUM_CORES) { }
    bp_finish(0);
  } else {
    bp_finish(0);
  }

  return 0;
}

