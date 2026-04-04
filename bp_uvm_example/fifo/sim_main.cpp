#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vtop* top = new Vtop{contextp};

    // Enable tracing
    Verilated::traceEverOn(true);

    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);   // depth
    tfp->open("waveform.vcd");

    while (!contextp->gotFinish()) {
        top->eval();
        tfp->dump(contextp->time());   // dump wave
        contextp->timeInc(1);
    }

    tfp->close();

    top->final();
    delete top;
    delete contextp;
    return 0;
}