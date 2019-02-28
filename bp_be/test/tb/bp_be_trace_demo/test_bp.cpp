#include <stdlib.h>
#include <systemc.h>
#include <verilated_vcd_sc.h>


#include "Vtestbench.h"

#define CLK_TIME 10

int sc_main(int argc, char **argv)
{
  Verilated::traceEverOn(true);
  Vtestbench *tb = new Vtestbench("tb");

  sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));
  sc_signal <bool>     reset("reset");

  tb->clk_i(clock);
  tb->reset_i(reset);


  VerilatedVcdSc* wf = new VerilatedVcdSc;
  tb->trace(wf, 10);
  wf->open("vcdplus.vpd");

  reset = 1;

  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);
  sc_start(CLK_TIME, SC_NS);

  reset = 0;

  while (!Verilated::gotFinish()) {
    sc_start(CLK_TIME, SC_NS);
  }

  exit(EXIT_SUCCESS);
}
