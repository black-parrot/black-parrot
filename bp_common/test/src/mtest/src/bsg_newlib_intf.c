#include <stdlib.h>
#include <machine/bsg_newlib_fs.h>

void bsg_newlib_init(void) {

    // Init file system
    if(bsg_newlib_fs_init() < 0) {
      exit(-1);
    }
}

void bsg_newlib_exit(int exit_status) {
  //EXIT_SUCCESS is 0 
  if(exit_status == EXIT_SUCCESS) {
    exit(0);
  } else {
    exit(-1);
  }
}

void bsg_newlib_sendchar(char ch) {
  char* ch_ptr;
  ch_ptr = (char*)0x8FFFEFFF;
  *ch_ptr = ch;
}
