#include <stdlib.h>
#include <verilated_fst_c.h>
#include <verilated_cov.h>

#include "Vtestbench.h"
#include "Vtestbench__Dpi.h"
#include "bsg_nonsynth_dpi_clock_gen.hpp"
using namespace bsg_nonsynth_dpi;

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(VM_TRACE_FST);
  Verilated::assertOn(false);

  Vtestbench *tb = new Vtestbench("test_bp");

  svScope g_scope = svGetScopeFromName("test_bp.testbench");
  svSetScope(g_scope);

  // Let clock generators register themselves.
  tb->eval();

  // Use me to find the correct scope of your DPI functions
  //Verilated::scopesDump();

#if VM_TRACE_FST
  std::cout << "Opening dump file" << std::endl;
  VerilatedFstC* wf = new VerilatedFstC;
  tb->trace(wf, 10);
  wf->open("dump.fst");
#endif

  std::cout << "Raising reset" << std::endl;
  for (int i = 0; i < 20; i++) {
    bsg_timekeeper::next();
    tb->eval();
  }
  std::cout << "Lowering reset" << std::endl;

  Verilated::assertOn(true);

  while (!Verilated::gotFinish()) {
    bsg_timekeeper::next();
    tb->eval();
  }
  std::cout << "Finishing test" << std::endl;

#if VM_COVERAGE
  std::cout << "Writing coverage" << std::endl;
  VerilatedCov::write("coverage.dat");
#endif

  std::cout << "Executing final" << std::endl;
  tb->final();

  std::cout << "Exiting" << std::endl;
  exit(EXIT_SUCCESS);
}

