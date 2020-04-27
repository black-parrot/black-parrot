#include <stdlib.h>
#include <systemc.h>
#include <verilated_vcd_sc.h>
#include <verilated_cov.h>

#include "Vtestbench.h"
#include "Vtestbench__Dpi.h"

#ifndef BP_SIM_CLK_PERIOD
#define BP_SIM_CLK_PERIOD 10
#endif

int sc_main(int argc, char **argv)
{
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(VM_TRACE);
  Verilated::assertOn(false);

  Vtestbench *tb = new Vtestbench("test_bp");

  // Use me to find the correct scope of your DPI functions
  //Verilated::scopesDump();

  sc_clock clock("clk", sc_time(BP_SIM_CLK_PERIOD, SC_NS));
  sc_signal <bool> reset("reset");

  tb->clk_i(clock);
  tb->reset_i(reset);

#if VM_TRACE
  std::cout << "Opening dump file" << std::endl;
  VerilatedVcdSc* wf = new VerilatedVcdSc;
  tb->trace(wf, 10);
  wf->open("dump.vcd");
#endif

  reset = 1;

  std::cout << "Raising reset" << std::endl;
  for (int i = 0; i < 20; i++) {
    sc_start(BP_SIM_CLK_PERIOD, SC_NS);
  }
  std::cout << "Lowering reset" << std::endl;

  reset = 0;
  Verilated::assertOn(true);

  while (!Verilated::gotFinish()) {
    sc_start(BP_SIM_CLK_PERIOD, SC_NS);
  }
  std::cout << "Finishing test" << std::endl;

#if VM_COVERAGE
  std::cout << "Writing coverage" << std::endl;
  VerilatedCov::write("coverage.dat");
#endif

  std::cout << "Exiting" << std::endl;
  exit(EXIT_SUCCESS);
}
