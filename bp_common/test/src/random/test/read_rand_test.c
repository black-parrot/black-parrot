#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bp_utils.h"

#define MAX_SIZE 2048

unsigned char rand_data[MAX_SIZE];

int main() {
	int read_cnt = 0;
    // Initialize LFS
    dramfs_init();

    FILE *fp = fopen("rand_data", "r");
    if(fp == NULL)
      return -1;
	
	read_cnt = fread(rand_data, sizeof(*rand_data), sizeof(rand_data) / sizeof(*rand_data), fp);

	for(int i = 0;i < read_cnt;i++) {
		printf("%u\n", rand_data[i]);
	}

    fclose(fp);
    bp_finish(0);
    return 0;
}
