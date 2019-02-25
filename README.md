# coming-soon
Black Parrot is coming soon.

To setup the repo:
```
  source setup_env.sh init
```

'init' will pull external submodule dependencies as well as make all test roms and trace roms. This may take a while, especially to build riscv-gnu-toolchain if needed. But you only have to run this once.

To set environment variables needed for BlackParrot (everytime you restart your terminal):
```
  source setup_env.sh 
```

Each module has a synthesizable trace-replay-based testbench found in bp\_\*/test/tb/
```
make TEST_ROM=<rom from test/rom/v/> TEST_ROM=<trace rom from test/rom/v/> <wrapper>.run.v
```

For instance, 

```
make TEST_ROM=median\_rom.v TRACE_ROM=median\_rom.tr.v bp\_single\_trace\_demo.run.v
make TEST_ROM=median\_rom.v TRACE_ROM=median\_rom.tr.v bp\_fe\_trace_demo.run.v
make TEST_ROM=median\_rom.v TRACE_ROM=median\_rom.tr.v bp\_be\_trace_demo.run.v
make TEST_ROM=median\_rom.v TRACE_ROM=median\_rom.tr.v bp\_me\_trace_demo.run.v
```

Each test will print "PASS" if it passed.

We also provide a regression in each module (and a wrapper running all modules at the top level) run by 
```
./regress.sh
```
which will show you each test and whether or not it passed.

Additionally, ME has a random load / store tracer designed to stress test the system (README in the tb directory has more information on extra parameters.
```
cd $BP_ME_DIR/test/tb/bp_me_random_demo
make 
```

Other tests may or may not run based on this command structure.  In those cases, running 'make' in the test directory should run the test. Many tests are deprecated. Cleaning old testbenches and monitoring the rest with CI is high on our priority list.

For pull requests, please follow BlackParrot coding guidelines at:
https://docs.google.com/document/d/1GOSp6NVQUzGAAk_ahleAsANaQK2XJ0MUOZFPC9DLbLQ/edit?usp=sharing

The preliminary BlackParrot microarchitecture spec is available at:
https://docs.google.com/document/d/1UDGMtXfCCgmO62fothY-9x9TLF5AyTLUEURk-fDVeLM/edit

NOTE: Currently, BlackParrot requires a VCS license.  Work in is progress to adapt the project to Verilator (https://www.veripool.org/wiki/verilator), an open-source simulator.  At the moment, for the purpose of this pre-alpha release, please contact petrisko@cs.washington.edu for help massaging your own VCS setup into this build flow (or pull-request a working Verilator build =))
