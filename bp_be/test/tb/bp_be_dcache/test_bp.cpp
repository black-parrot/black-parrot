#include <stdlib.h>
#include <systemc.h>
#include <verilated_vcd_sc.h>
#include <verilated_cov.h>

#include "Vtestbench.h"
#include "Vtestbench__Dpi.h"

int sc_main(int argc, char **argv)
{
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(VM_TRACE);
  Verilated::assertOn(false);

  Vtestbench *tb = new Vtestbench("test_bp");

  svScope g_scope = svGetScopeFromName("test_bp.testbench");
  svSetScope(g_scope);

  int sim_period = get_sim_period();
  int dram_period = get_dram_period();
  // Use me to find the correct scope of your DPI functions
  //Verilated::scopesDump();

  sc_clock clock("clk", sc_time(sim_period, SC_PS));
  sc_clock dram_clock("clk", sc_time(dram_period, SC_PS));
  sc_signal <bool> reset("reset");

  tb->clk_i(clock);
  tb->reset_i(reset);
  tb->dram_clk_i(dram_clock);
  tb->dram_reset_i(reset);

#if VM_TRACE
  std::cout << "Opening dump file" << std::endl;
  VerilatedVcdSc* wf = new VerilatedVcdSc;
  tb->trace(wf, 10);
  wf->open("dump.vcd");
#endif

  reset = 1;

  std::cout << "Raising reset" << std::endl;
  for (int i = 0; i < 20; i++) {
    sc_start(std::max(sim_period, dram_period), SC_PS);
  }
  std::cout << "Lowering reset" << std::endl;

  reset = 0;
  Verilated::assertOn(true);

  while (!Verilated::gotFinish()) {
    sc_start(sim_period, SC_PS);
  }
  std::cout << "Finishing test" << std::endl;

#if VM_COVERAGE
  std::cout << "Writing coverage" << std::endl;
  VerilatedCov::write("coverage.dat");
#endif

  std::cout << "Exiting" << std::endl;
  exit(EXIT_SUCCESS);
}
