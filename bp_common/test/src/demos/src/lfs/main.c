#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bp_utils.h"

char buffer[256];

int main() {
    // Read from a file
    FILE *fp = fopen("hello.txt", "r");
    if(fp == NULL)
      return -1;

    while (fgets(buffer, 256, fp)) {
        printf("%s\n", buffer);
    }

/*
    char c;
    while((c = fgetc(hello)) != '\n') {
      bp_cprint(c);
    }
    bp_cprint('\n');
*/

    fclose(fp);
    return 0;
}
