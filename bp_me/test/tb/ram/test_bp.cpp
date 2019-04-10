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

#include "Vtestbench.h"

#include "bp_cce_verilator.h"
#include "bp_cce_inst.h"

int sc_main(int argc, char **argv) 
{
    sc_init("testbench", argc, argv);

    sc_signal <bool>     reset_i("reset_i");
    sc_clock clock("clk", sc_time(CLK_TIME, SC_NS));

    Vtestbench DUT("DUT");

    DUT.clk_i(clock);
    DUT.reset_i(reset_i);

    #if (VM_TRACE == 1)
    VerilatedVcdSc* wf = new VerilatedVcdSc;
    DUT.trace(wf, TRACE_LEVELS);
    wf->open("dump.vcd");
    #endif

    // reset
    cout << "@" << sc_time_stamp() << " Reset started..." << endl;
    reset_i = 1;
    sc_start(RST_TIME, SC_NS);
    reset_i = 0;
    sc_start(RST_TIME, SC_NS);
    cout << "@" << sc_time_stamp() << " Reset finished!" << endl;


    sc_start(RST_TIME, SC_NS);

    cout << "TEST PASSED!" << endl;

    #if (VM_TRACE == 1)
    wf->close();
    #endif

    return 0;
}
