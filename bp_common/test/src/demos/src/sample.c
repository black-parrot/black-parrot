
#include <stdint.h>
#include "bp_utils.h"

int main(int arc, char** argv) {
  uint64_t core_id = bp_get_hart();

  bp_cprint('H');
  bp_cprint('e');
  bp_cprint('l');
  bp_cprint('l');
  bp_cprint('o');
  bp_cprint(' ');
  bp_cprint('f');
  bp_cprint('r');
  bp_cprint('o');
  bp_cprint('m');
  bp_cprint(' ');
  bp_cprint('c');
  bp_cprint('o');
  bp_cprint('r');
  bp_cprint('e');
  bp_cprint(' ');
  bp_cprint(' ' + core_id);

  bp_finish(core_id);
  return 0;
}
