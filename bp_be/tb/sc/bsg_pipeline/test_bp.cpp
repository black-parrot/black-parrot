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

#include "Vbsg_pipeline.h"

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
    sc_init("bsg_pipeline", argc, argv);

    sc_clock             clk("clk", 10, SC_NS);
    sc_signal <bool>     data_v_i("data_v_i");
    sc_signal <uint32_t> data_i("input_data");
    sc_signal <uint32_t> data_o("output_data");
    
    int stage0, stage1, stage2, stage3;
    int expected_dly_1, expected_dly_2, expected_dly_3, expected_dly_4;

    Vbsg_pipeline DUT("DUT");
    DUT.clk_i(clk);
    DUT.data_v_i(data_v_i);
    DUT.data_i(data_i);
    DUT.data_o(data_o);

    VerilatedVcdSc* wf = new VerilatedVcdSc;
    DUT.trace(wf, 10);
    wf->open("dump.vcd");

    sc_start(0, SC_NS);
    for(int i = 0; i < 10; i++)
    {
        data_v_i.write(rand()%2);
        //data_i.write(rand()%256);
        data_i.write(i);
        sc_start(10, SC_NS);

        stage0 = (data_o.read() & 0x000000FF) >> 0;
        stage1 = (data_o.read() & 0x0000FF00) >> 8;
        stage2 = (data_o.read() & 0x00FF0000) >> 16;
        stage3 = (data_o.read() & 0xFF000000) >> 24;

        cout << "@" << sc_time_stamp() << " Data in: " << data_i << " V: " << data_v_i << endl;
        cout << "\t" << "Data out: " << stage0 << " " << stage1 << " ";
        cout << stage2 << " " << stage3 << endl; 

        if((i >= 4)
        && ((expected_dly_4 != stage3) || (expected_dly_3 != stage2)
            || (expected_dly_2 != stage1) || (expected_dly_1 != stage0)))
        {
            cout << "@" << sc_time_stamp() << " TEST FAILED " << endl;
            return -1;
        }
        expected_dly_4 = expected_dly_3;
        expected_dly_3 = expected_dly_2;
        expected_dly_2 = expected_dly_1;
        expected_dly_1 = data_v_i ? data_i : 0;
    }

    cout << "TEST PASSED!" << endl;

    wf->close();

    return 0;
}
