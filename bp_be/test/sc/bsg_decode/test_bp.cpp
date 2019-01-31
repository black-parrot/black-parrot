/**
 *
 * test_bp.cpp
 *
 */

#include <map>
#include <iomanip>
#include <string>
#include <unistd.h>

#include "systemc.h"
#include "verilated_vcd_sc.h"

#include "Vbsg_decode.h"

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
    sc_init("bsg_dff", argc, argv);

    sc_signal <uint32_t> data_i("input");
    sc_signal <uint32_t> data_o("decoded_input");

    Vbsg_decode DUT("DUT");
    DUT.i(data_i);
    DUT.o(data_o);

    VerilatedVcdSc* wf = new VerilatedVcdSc;
    DUT.trace(wf, 10);
    wf->open("dump.vcd");

    sc_start(0, SC_NS);
    for(int i = 0; i < 10; i++)
    {
        data_i = rand() % 8;
        sc_start(10, SC_NS);

        cout << "@" << sc_time_stamp() << " Data in: " << data_i;
        cout << " Data out: " << data_o << endl;

        if((data_o != (1 << data_i))) 
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            return -1;
        }
    }

    cout << "TEST PASSED!" << endl;

    wf->close();

    return 0;
}
