#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "benchmarks.h"

#define PGSIZE 4 << 10
#define TEST_PGNUM 32

extern void lock(void);
extern void unlock(void);
extern void bsg_newlib_init(void);
volatile uint64_t start_barrier = 0;
uint8_t* roots[NC];
uint64_t rets[NC];

int scheduler(int hartid) {
  
  if(hartid == 0) {
    
    printf("FS init start\n");
    bsg_newlib_init();
    printf("FS init done\n");
    
    for(int i = 0; i < NC; i++) {
      roots[i] = (uint8_t*)malloc(TEST_PGNUM * PGSIZE);
      printf("%s: %x\n", benchmarks[i], roots[i]);
      
      int file = open(benchmarks[i], O_RDONLY);
      if(file == -1) {
        printf("Cannot open file: %d\n", i);
        return -1;
      }
      
      uint64_t flen = lseek(file, 0, SEEK_END);
      lseek(file, 0, SEEK_SET);
      
      uint64_t read_ret = read(file, roots[i], flen);
      if(read_ret == -1) {
        printf("Cannot read file: %d\n", i);
        return -1;
      }
      close(file); 
    }
    start_barrier = 1;
  }
  else {
    while(start_barrier != 1) {}
  }
    
  printf("start %s\n", benchmarks[hartid]);
  __asm__ volatile("jalr ra, %0": : "r"(roots[hartid]) :);
//  __asm__ volatile("mv %0, a0": "=r"(rets[hartid]): :);
//  printf("test %d: %d", hartid, rets[hartid]);
  
  return 0;
}