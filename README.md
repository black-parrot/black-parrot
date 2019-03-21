# coming-soon
Black Parrot is coming soon.

To setup the repo:
```
  make tools roms
```

This will pull external submodule dependencies as well as make all test roms and trace roms. This may take a while, especially to build riscv-gnu-toolchain if needed. But you only have to run this once.

Each module has a synthesizable trace-replay-based testbench found in bp\_\*/test/tb/. These testbenches can either be run with VCS or Verilator. Tests will produce results in module/syn/reports and logs in module/syn/logs
```
make ROM_NAME=<rom from test/rom/v/> run.<tool>
```

For instance, 

```
make TEST_ROM=median_rom.v bp_single_trace_demo.run.v
make TEST_ROM=median_rom.v bp_fe_trace_demo.run.v
make TEST_ROM=median_rom.v bp_be_trace_demo.run.sc
make TEST_ROM=median_rom.v bp_me_trace_demo.run.sc
```

Will run the TOP and FE testbenches with VCS and BE and ME testbenches with Verilator.

Each test will print "PASS" if it passed.

We also provide a regression in each module. This will run the VCS testbench with each RV64I ISA test and 4 benchmarks. Additionally, it will run DC check\_synth which provides a quick way to test if your design will synthesize (not necessary that it will successfully run in post\_synth!). In each End, the makefile can additionally specify any tests that you would like to be run along with the normal regression for that End. You can run regression with:
```
make regress
```

Once this finishes (~20-30 minutes), you should check the reports directory. In particular, check reports/dc/\*check\_synth.rpt for synthesizability, reports/vcs/regress\_stats.regress\_stats.err for failing tests, reports/vcs/regress\_stats.rpt for performance regressions, and reports/vcs/\*\_lint.log + reports/verilator/\*\_lint.log for an increase in linter errors. Do not commit code to dev without passing regression for both the End that you are working on and Top. In the future, we will run this regression as a pre-commit hook. In addition, please try to eliminate linter warnings as they often manifest in post-synth errors and bizarre parameterization bugs.

Other tests may or may not run based on this command structure.  In those cases, running 'make' in the test directory should run the test. Many tests are deprecated. Cleaning old testbenches and monitoring the rest with CI is high on our priority list.

For pull requests, please follow BlackParrot coding guidelines at:
https://docs.google.com/document/d/1GOSp6NVQUzGAAk\_ahleAsANaQK2XJ0MUOZFPC9DLbLQ/edit?usp=sharing

The preliminary BlackParrot microarchitecture spec is available at:
https://docs.google.com/document/d/1UDGMtXfCCgmO62fothY-9x9TLF5AyTLUEURk-fDVeLM/edit

