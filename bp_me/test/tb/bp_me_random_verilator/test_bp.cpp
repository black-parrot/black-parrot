/**
 *
 * test_bp.v
 *
 */

#include <map>
#include <iomanip>
#include <string>
#include <unistd.h>

#include "systemc.h"
#include "verilated_vcd_sc.h"

#include "Vbp_me_random_demo_top.h"

#include "bp_cce_verilator.h"
#include "bp_cce.h"
#include "bp_common_me_if.h"
#include "bp_cce_lce_msg_util.h"

#define STALL_MAX (CLK_TIME*1000)

int sc_main(int argc, char **argv) 
{
  sc_init("bp_me_random_demo", argc, argv);

  sc_signal <bool>     reset_i("reset_i");
  sc_signal <bool>     done_o("done_o");

  sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));

  Vbp_me_random_demo_top DUT("DUT");

  DUT.clk_i(clock);
  DUT.reset_i(reset_i);
  DUT.done_o(done_o);

  #if (DUMP == 1)
  VerilatedVcdSc* wf = new VerilatedVcdSc;
  DUT.trace(wf, TRACE_LEVELS);
  wf->open("dump.vcd");
  #endif

  // reset
  cout << "@" << sc_time_stamp() << " Reset started..." << endl;
  reset_i = 1;
  sc_start(RST_TIME, SC_NS);
  reset_i = 0;
  cout << "@" << sc_time_stamp() << " Reset finished!" << endl;

  uint64_t MAX_CYCLES = UINT64_MAX;
  uint64_t cnt = 0;
  while (!done_o) {
    if (cnt == MAX_CYCLES) {
      cout << "@" << sc_time_stamp() << " TEST FAILED" << endl;
      #if (DUMP == 1)
      wf->close();
      #endif
      exit(-1);
    }
    cnt++;
  }

  cout << "@" << sc_time_stamp() << " TEST PASSED!" << endl;

  #if (DUMP == 1)
  wf->close();
  #endif

  return 0;
}
