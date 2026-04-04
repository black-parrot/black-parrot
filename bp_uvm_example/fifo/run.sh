rm -rf obj_dir
rm -rf waveform.vcd

verilator --sv --timing --trace --cc top.sv --exe sim_main.cpp

make -C obj_dir -f Vtop.mk

./obj_dir/Vtop