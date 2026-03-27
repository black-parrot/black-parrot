# Evaluation Guide
## Tool configuration

Tools flows are defined by makefiles in mk/Makefile<TOOL>.
Currently, [Synopsys VCS](https://www.synopsys.com/verification/simulation/vcs.html) and [Verilator](https://github.com/verilator/verilator) are supported for simulation.
[Synopsys DC] is supported for "pickling", or converting into a single Verilog-2005 file for tool compatibility.

## Simulation testbench description

Each End has testbenches in bp\_<end>/test/tb/, with configuration defined by the contained Makefiles. They can be run in bp\_end/<TOOL> and each create a set of logs, results and reports after a run.
Each testbench supports optional CONFIGS, FLAGS, and PARAMS which should be kept consistent between builds and sims. When in doubt, use ```make clean``` to clean the working directory.

Simulation testbenches support CONFIG:
- CFG: The system configuration to test e.g. e_bp_unicore_cfg
- TAG: TAG: Unique identifier for the evaluation

Simulation testbenches support PARAMS:
- TB_CLOCK_PERIOD_P: clock period for the testbench
- TB_RESET_CYCLES_LO_P: number of initial low reset cycles
- TB_RESET_CYCLES_HI_P: number of initial high reset cycles
- DUT_CLOCK_PERIOD_P: clock period for the dut
- DUT_RESET_CYCLES_LO_P: number of initial low reset cycles
- DUT_RESET_CYCLES_HI_P: number of initial high reset cycles

Simulation testbenches support FLAGS:
- ASSERT: Enable SystemVerilog assertions
- TRACE: Enable waveform dumping

## Running a simulation

Instructions for a bp\_me verilator simulation:


    cd bp_me/verilator
    # make build.verilator; # optional build, will also be done on-demand
    # make lint.verilator; # optional lint
    make sim.verilator; # optional <CONFIG>= <FLAG>= <PARAM>= <PLUSARGS>=


## Running RISC-V regression

The bp_tethered testbench in bp_top is the primary testbench for BlackParrot.
It can instantiate a full BlackParrot cache-coherent multicore or a minimal BlackParrot unicore, as well as the host infrastructure to bootstrap the core and manage DRAM requests. See [BlackParrot SDK](https:/github.com/black-parrot-sdk/black-parrot-sdk) for example programs or to compile your own.

CONFIGS:
- SUITE: Test suite in SDK
- PROG: Test program in SDK
- SIM_PROG: <Optional, full path to RISCV binary, instead of SUITE/PROG methodology>
- COH_PROTO: Bedrock coherence protocol

FLAGS:
- DROMAJO_COSIM: Whether to run [Dromajo](https://github.com/ChipsAlliance/dromajo)-based co-simulation
- SPIKE_COSIM: Whether to run [Spike](https://github.com/riscv-isa-sim/spike)-based co-simulation
- DISASSEMBLE: Create RISCV disassembly (requires RISCV toolchain on PATH)
- COMMITLOG: Create RISCV commitlog during execution
- DROMAJO_TRACE: Creates a dromajo-based golden trace
- SPIKE_TRACE: Creates a spike-based golden trace

PARAMS:
- PERF_ENABLE_P: Enable performance profiler
    - WARMUP_INSTR_P: Number of warmup instructions for performance profiler
    - MAX_INSTR_P: Maximum number of instructions to execute
    - MAX_CYCLE_P: Maximum number of cycles to execute
- WATCHDOG_ENABLE_P: Enable watchdog timer
    - STALL_CYCLES_P: How many cycles before watchdog throws error
    - HALT_INSTR_P: How many instructions before watchdog considers a core halted
    - HEARTBEAT_INSTR_P: Period for heatbeat information

PLUSARGS:
  - +icache_trace: L1 I$ tracer
  - +dcache_trace: L1 D$ tracer
  - +vm_trace: ITLB / DTLB tracers
  - +cce_trace: CCE tracer
  - +lce_trace: LCE tracer
  - +uce_trace: UCE tracer
  - +dev_trace: CLINT / CFG tracers
  - +dram_trace: DRAM tracer
## bp\_top Simulation Examples
**Hello World**
```bash
make -C bp_top/verilator build.verilator sim.verilator
```
- Validates: Basic boot flow, UART output, and core-to-memory communication.
- Expected Output: "Hello World!" appearing in the simulation log.

**RISC-V ISA Simple Test**
```bash
make -C bp_top/verilator build.verilator sim.verilator PROG=rv64ui-p-simple CFG=e_bp_unicore_cfg
```
- Validates: Correctness of basic integer instructions (RV64I).

## Running Memory End regression

The Memory End Regression can be run in vcs or verilator (verilator commands shown):

Supported CONFIG:
- PROG: The specific test to run <random\_test, set\_test, ld\_st, mixed>
- COH\_PROTO: BedRock coherence protocol to use

Supported PARAMS:
- NUM_INSTR_P: number of instructions to run for random tests
- CCE_MODE_P: controls whether the CCE operates in normal or uncached only mode
- LCE_MODE_P: controls whether the LCE issues cached, uncached, or both requests
- ME_TEST_P: which type of test to run:
    - 0 = random loads and stores
    - 1 = single set hammer test
    - 2 = test from trace file input based on PROG

## bp\_me Simulation Examples

**Clean Build with Waveform Support**
```bash
make -C bp_me/verilator clean build.verilator sim.verilator TRACE=1 -j2
```
- Validates: `TRACE=1`  enables `--trace-fst` for high-performance waveform generation.

**Random Coherence Stress**
```bash
make -C bp_me/verilator build.verilator sim.verilator TRACE=1 PROG=random_test NUM_INSTR_P=5000
```
- Validates: LCE/CCE protocol transitions and randomized memory access patterns.

**Set Hammer Test**
```bash
make -C bp_me/verilator build.verilator sim.verilator TRACE=1 PROG=set_test ME_TEST_P=1
```
- Validates: Cache eviction behavior and replacement logic under single-set stress.

**Trace-Based Deterministic Test**
```bash
make -C bp_me/verilator build.verilator sim.verilator TRACE=1 PROG=mixed ME_TEST_P=2
```
- Validates: Trace replay correctness and reproducibility of specific scenarios.


## Synthesis smoke tests

BlackParrot support Verilog-2005 pickling through [bsg_sv2v](https://github.com/bespoke-silicon-group/bsg_sv2v).
Unfortunately, this requires access to [Synopsys DC](https://www.synopsys.com/implementation-and-signoff/rtl-synthesis-test/dc-ultra.html), but we welcome help supporting an open-source alternative.


    cd bp_top/dc
	make check_design.dc; # Lints for a variety of common synthesis issues
	make check_loops.dc;  # Checks for timing loops in addition to lint (requires PDK)
	make sv2v.dc;         # Pickles the design

