/*
 * bp_as_main.cc
 *
 * BlackParrot CCE Microcode Assembler Main
 *
 */

/** Main **/

#include "bp_as.h"

int main(int argc, char *argv[]) {

  Assembler as;
  as.parseArgs(argc, argv);
  as.tokenizeAndLabel();
  as.assemble();

  return 0;
}
