/*
 * Name:
 *   mc_rand_walk.c
 *
 * Description:
 *   This program has each core do a random walk through a grid.
 *
 *   For now, each core does the prescribed number of steps per epoch, for all epochs,
 *   and all cores synchronize at the end of each epoch.
 *
 *   TODO:
 *   If a core ends up in the same position as another core, it dies and removes itself
 *   from the set of active cores.
 *
 *   The simulation ends when all cores "die" or the maximum number of iterations is reached.
 *
 */

#include <stdint.h>
#include "bp_utils.h"
#include "mc_util.h"

#ifndef NUM_CORES
#define NUM_CORES 2
#endif

// maximum number of simulation epochs
#ifndef MAX_EPOCHS
#define MAX_EPOCHS 10
#endif

// number of steps player takes per epoch
#ifndef WALK_STEPS
#define WALK_STEPS 10
#endif

// define grid size [0..N-1]
// grid is square
#define GRID_SIZE 20

typedef struct {
  int x;
  int y;
} pos_s;

// written by core 0, read by all
volatile uint64_t __attribute__((aligned(64))) start_barrier_mem = 0;
volatile uint64_t __attribute__((aligned(64))) epoch_barrier_mem = 0;

// lock for shared globals
volatile uint64_t __attribute__((aligned(64))) global_lock = 0;
volatile uint64_t __attribute__((aligned(64))) epoch_count_mem = 0;
volatile uint64_t __attribute__((aligned(64))) end_barrier_mem = 0;

void player_init(pos_s *pos) {
  pos->x = GRID_SIZE >> 1; // (GRID_SIZE / 2)
  pos->y = GRID_SIZE >> 1;
}

void player_walk(pos_s *pos, int steps) {
  for (int i = 0; i < steps; i++) {
    uint32_t x, y;
    x = mc_rand_bit(); // right or left
    y = mc_rand_bit(); // up or down
    if (x && (pos->x < GRID_SIZE-1)) { // walk right
      pos->x = pos->x + 1;
    } else if (!x && (pos->x > 0)) { // walk left
      pos->x = pos->x - 1;
    }
    if (y && (pos->y < GRID_SIZE-1)) { // walk up
      pos->y = pos->y + 1;
    } else if (!y && (pos->y > 0)) {  // walk down
      pos->y = pos->y - 1;
    }
  }
}

void player_sync(uint64_t core_id, uint64_t cur_epoch) {
  // all players increment the epoch_count when they are done with epoch
  lock(&global_lock);
  epoch_count_mem += 1;
  unlock(&global_lock);
  // player 0 waits for epoch_count to equal number of cores
  // resets it to 0, then increments the epoch barrier
  if (core_id == 0) {
    while (epoch_count_mem != NUM_CORES) { }
    lock(&global_lock);
    epoch_count_mem = 0;
    epoch_barrier_mem += 1;
    unlock(&global_lock);
  }
  // all other players wait for core 0 to start the new epoch
  else {
    while (epoch_barrier_mem != (cur_epoch+1)) { }
  }
}

uint64_t thread_main() {
  uint64_t core_id;
  __asm__ volatile("csrr %0, mhartid": "=r"(core_id): :);

  uint64_t epoch = 0;
  pos_s pos;
  player_init(&pos);
  while (epoch < MAX_EPOCHS) {
    player_walk(&pos, WALK_STEPS);
    bp_hprint(core_id);
    player_sync(core_id, epoch);
    epoch = epoch + 1;
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

