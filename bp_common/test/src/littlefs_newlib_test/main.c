#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bp_utils.h"

int main() {
    // Initialize LFS
    dramfs_init();

    // Read from a file
    FILE *hello = fopen("hello.txt", "r");
    if(hello == NULL)
      return -1;

    char c;
    while((c = fgetc(hello)) != '\n') {
      bp_cprint(c);
    }
    bp_cprint('\n');

    fclose(hello);
    bp_finish(0);
    return 0;
}
