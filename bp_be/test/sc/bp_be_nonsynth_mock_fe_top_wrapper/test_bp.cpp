/**
 *
 * test_bp.v
 *
 */

#include <cstdlib>
#include <iomanip>
#include <map>
#include <string>
#include <unistd.h>

#include "systemc.h"
#include "verilated_vcd_sc.h"

#include "Vbp_be_nonsynth_mock_fe_top_wrapper.h"

void print_header(std::string dut, std::map<std::string, std::string>& arg_map)
{
    cout << "DUT is " << dut << endl;
    cout << "Params: " << endl;
    std::map<std::string, std::string>::iterator it;
    for(it = arg_map.begin(); it != arg_map.end(); ++it)
    {
        cout << it->first << ": " << it->second << endl;
    }
    cout << " Starting simulation" << endl;
}

void parse_args(int argc, char **argv, std::map<std::string, std::string>& arg_map)
{
    for(int i = 1; i < argc; i++)
    {
        char *param = strtok(argv[i], "=");
        char *value = strtok(NULL, "=");
        arg_map.insert(std::pair<std::string, std::string>(param, value));   
    }
}

void sc_init(std::string dut, int argc, char **argv)
{
    const char* seed = "12345";
    int seed_int = atoi(seed);
    std::map<std::string, std::string> arg_map;
    srand(seed_int);
    parse_args(argc, argv, arg_map);
    arg_map.insert(std::pair<std::string, std::string>("-pvalue+seed", seed));
    print_header(dut, arg_map);

    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);  
    Verilated::randReset(2);
}

int sc_main(int argc, char **argv) 
{
    sc_init("bp_be_nonsynth_mock_fe_top_wrapper", argc, argv);

    sc_clock             clk("clk", 10, SC_NS);
    sc_signal <bool>     reset("reset");

    Vbp_be_nonsynth_mock_fe_top_wrapper DUT("DUT");
    DUT.clk_i(clk);
    DUT.reset_i(reset);

    VerilatedVcdSc* wf = new VerilatedVcdSc;
    DUT.trace(wf, 10);
    wf->open("dump.vcd");

    sc_start(0, SC_NS);
    reset.write(1);
    sc_start(10, SC_NS);
    reset.write(0);

    for(int i = 0; i < 100000; i++)
    {
        sc_start(10, SC_NS);
        if(Verilated::gotFinish()) return 0;
    }

    cout << "TEST TIMEOUT!" << endl;

    wf->close();

    return 0;
}
