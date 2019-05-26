#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
    char c;

    // Read from a file
    FILE *hello = fopen("hello.txt", "r");
    if(hello == NULL)
      return -1;

    while((c = fgetc(hello)) != '\n') {
      putchar(c);
    }
    putchar('\n');
    
    fclose(hello);
    return 0;
}
