
#ifndef BP_CCE_VERILATOR_H
#define BP_CCE_VERILATOR_H

#define TRACE_LEVELS 10
#define TRACE_ITERS 50
#define CLK_TIME 10
#define HALF_CLK_TIME (CLK_TIME/2)
#define RST_TIME 100

#define CCE_INIT_CLKS 1000

#include <iomanip>
#include <sstream>
#include <string>

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

template<typename T>
std::string toHex(T in)
{
  std::stringstream ss;
  ss << std::setfill('0') << std::setw(sizeof(T)*2) << std::hex << in;
  return ss.str();
}

template<typename T>
std::string toString(T in, int bits)
{
  std::stringstream ss;
  for (int i = bits; i > 0; i--) {
    if (((in >> (i-1)) & 0x1) == 1) {
      ss << "1";
    } else {
      ss << "0";
    }
  }
  return ss.str();
}


#endif
