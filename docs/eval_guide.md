# Evaluation Guide (Full)
## Build the simulation libraries
    # Clone the latest repo (if necessary)
    git clone https://github.com/black-parrot/black-parrot.git
    cd black-parrot
    # make libs is a target which will build DRAMSim simulation library
    make libs

The *master* branch contains most recent stable version. This is the recommended branch for someone wishing to try out BlackParrot.

The *dev* branch contains the most recent development version, being tested internally. This branch may have bugfixes or improvements not yet propagated to master.

Other branches are used for internal development and are not recommended for casual usage.

## Running Tests
The main testbenches are at the FE, BE, ME and TOP levels. The general syntax for running a testbench is:

    cd bp_<end>/syn
    make <ACTION>.<TOOL> [TB=] [CFG=] [SUITE=] [PROG=] [COSIM_P=] [<TRACER>_P=]

### Testbench structure
The bp_tethered testbench in bp_top/test/tb is the primary testbench for BlackParrot. It can instantiate a full BlackParrot cache-coherent multicore or a minimal BlackParrot unicore, as well as the host infrastructure to bootstrap the core and manage DRAM requests.

Additionally, each of bp_fe, bp_be and bp_me has a set of more targeted testbenches. These testbenches are more prone to breakage due to their tighter coupling to implementation, but they are intended to serve as a set of compliance tests for external contributors.

NOTE: pardon our dust as we update our testbenches. The main testbench bp_tethered testbench is well supported.

### Supported CFGs
All configurations can be found in bp\_common/src/include/bp_common_aviary_pkgdef.svh. A description
of the parameters in the structure can be found at
bp\_common/src/include/bp_common_aviary_defines.svh.
A configuration is selected by passing one of the enums found in bp_params_e. These correspond to the struct of parameters in all_cfgs_gp.

In the future, BlackParrot core parameters will be separated from SoC parameters.

### Supported ACTIONs
Each testbench supports a set of actions which act upon that specific testbench. Not all testbenches
support all targets, however. These targets include:
- lint (lints the DUT of a single testbench)
- build (builds a single testbench)
  - build_dump (builds with waveform dump enabled)
  - build_cov (builds with line+toggle coverage enabled)
- sim (runs a single test)
  - sim_dump (dumps a waveform)
  - sim_sample (creates and runs a single checkpoint from a test)
- blood (generates bloodgraph based on stall information; you must build and run with CORE_PROFILE_P=1)
- wave (opens a waveform viewer for the dump file, either GTKWave or Synopsys DVE)
- check_design (checks for DC elaborability, which is a proxy for synthesizability)
- check_loops (Same as check_design, but also checks for timing loops in the design)
- run_testlist (runs a suite of tests. This target may behave differently on different testbenches)
- run_psample (runs a single long test in parallel cosimulation)
  - SAMPLE_INSTR_P  = number instructions per sample
  - SAMPLE_WARMUP_P = number of instructions before performance recording starts
- report (prints a summary of reports and erroring actions)
- convert.bsg_sv2v (Creates a "pickled" verilog-2005 file out of the top level blackparrot)
  - NOTE: this target requires Synopsys Design Compiler to be installed. A fully open-source version of
    sv2v is in progress at https://github.com/zachjs/sv2v
- parse.surelog (Builds a UHDM model of BlackParrot for evaluation and integration with other tools)

### Supported TOOLs
BlackParrot supports these tools for simulation and design checking. We welcome contributions for additional tool support, especially for open-source tools.
- Verilator (.sc suffix)
- Synopsys VCS (.v suffix)
- Synopsys DC (.syn suffix)
- Vivado (.vivado suffix)
- BSG SV2V (.bsg_sv2v suffix)
- SureLog (.surelog suffix)

NOTE: Verilator is the free, open-source tool used to evaluate BlackParrot.  VCS, DC, and Vivado are used for simulation and synthesis. If you wish to use these tools, set up the appropriate environment variables in Makefile.common

### Supported Programs
More details about BlackParrot software can be found in the [Software Developer Guide](software_guide.md).
Notably, BlackParrot has been tested with:
- riscv-tests (a set of unit tests for RISC-V functionality)
- BEEBS (Embedded core test suite)
- Coremark (Standard benchmark for core performance)
- bp-tests (one-off tests which are used to test various aspects of the system)
- bp-demos (demo programs showing off special features of BlackParrot firmware)
- spec2000, requires a copy of the proprietary spec2000 benchmark suite
- spec2006, requires a copy of the proprietary spec2006 benchmark suite
- spec2017, requires a copy of the proprietary spec2017 benchmark suite
- Linux (A finite test of RISC-V Linux+BusyBox boot)

Each program belongs to a test suite. The list of supported programs for each suite can be found in
bp_top/test/tb/bp_tethered/Makefile.testlist. `make prog` builds the bp-tests, riscv-tests, beebs, and coremark suites alongside the lipperch firmware.

### Other flags
- COSIM\_P: Run with Dromajo-based cosimulation
- *\_TRACE\_P: Enable a specific tracer (tracer list can be found in the [SW Developer Guide](software_guide.md))

### Example Commands
    make build_dump.v sim_dump.v SUITE=bp-tests PROG=hello_world  # Run hello_world in VCS with dumping
    make build_dump.sc sim_dump.sc SUITE=bp-tests PROG=hello_world  # Run hello_world in Verilator with dumping
    make wave.v SUITE=bp-tests PROG=hello_world              # Open hello_world waveform in dve
    make build_cov.sc sim.sc SUITE=riscv-tests PROG=rsort    # Run hello_world in Verilator with coverage

    make run_testlist.sc -j 10 TESTLIST=BEEBS_TESTLIST    # Run beebs suite in Verilator with 10 threads
    make run_testlist.v -j 5   TESTLIST=RISCV_TESTLIST    # Run riscv-tests suite in VCS with 5 threads

## Examining Results
Running a test will generate a ton of subdirectories in bp_\<end\>/syn/

        bp_<end>/syn/results/<tool>/<tb>.<cfg>.build/sim{v,sc}
        bp_<end>/syn/results/<tool>/<tb>.<cfg>.sim.<prog>/(symlink to sim{v,sc})
        bp_<end>/syn/results/<tool>/<tb>.<cfg>.sim.<prog>/dump.vcd
        bp_<end>/syn/results/<tool>/<tb>.<cfg>.sim.<prog>/testbench.v
        bp_<end>/syn/results/<tool>/<tb>.<cfg>.sim.<prog>/etc.
        bp_<end>/syn/results/<tool>/<tb>.<cfg>.cov/*.dat

        bp_<end>/syn/logs/<tool>/<tb>.<cfg>.build.log
        bp_<end>/syn/logs/<tool>/<tb>.<cfg>.sim.<prog>.log
        bp_<end>/syn/logs/<tool>/<tb>.<cfg>.cov.log

        bp_<end>/syn/reports/<tool>/<tb>.<cfg>.build.{rpt,err}
        bp_<end>/syn/reports/<tool>/<tb>.<cfg>.sim.<prog>.{rpt,err}
        bp_<end>/syn/reports/<tool>/<tb>.<cfg>.cov.<prog>.{rpt,err}

### Results
The results directory contains the run directory for a given tool. All output artifacts are generated in this directory. For instance, simv files, pickled netlists, flists, tracer files and other outputs of tools. These subdirectories is useful because each tool run is self contained. To rerun a simulation, simply enter the results directory and execute the simv. Everything needed for the simulation is contained in the directory.

### Logs
The logs directory contains the full output of tool runs, tee-d from console output. This is where you should go if you want to examine everything that happened during a tool run, for instance, if there was an unexpected error.

### Reports
The reports directory contains very brief summaries of tool runs. For example, whether tests pass or fail and some high level performance statistics. It will also contain error summary reports, where the main reason for a failure is described.

# BlackParrot Repository Overview
- **bp_fe/** contains the front-end (FE) of BlackParrot, responsible for speculative fetching of instructions.
- **bp_be/** contains the back-end (BE) of BlackParrot, responsible for atomically executing instructions, as well as logically controlling the FE.
- **bp_me/** contains the memory-end (ME) of BlackParrot, responsible for servicing memory/IO requests as well as maintaining cache coherence between BlackParrot cores.
- **bp_top/** contains configurations of FE, BE, and ME components. For instance, tile components and NOC assemblies.
- **bp_common/** contains the interface components which connect FE, BE and ME. FE, BE, ME may depend on bp\_common, but not each other.
- **ci/** contains scripts used to run Continuous Integration jobs, mostly using the same Makefile commands but with additional data collection.
- **docs/** contains documentation, images, guides and links to document Blackparrot.
- **external/** contains submodules corresponding to tooling that BlackParrot depends upon, such as the Verilator.

