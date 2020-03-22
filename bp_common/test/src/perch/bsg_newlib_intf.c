#include "bp_utils.h"

void dramfs_init(void) {

    // Init file system
    if(dramfs_fs_init() < 0) {
      exit(-1);
    }
}

void dramfs_exit(int exit_status) {
  bp_finish(exit_status);
}

void dramfs_sendchar(char ch) {
  bp_cprint(ch);
}
