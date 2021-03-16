# BlackParrot Testbench Guide
## Prerequisites
### Centos

    yum install autoconf automake libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo
patchutils gcc gcc-c++ zlib-devel expat-devel dtc gtkwave vim-common virtualenv

CentOS 7 requires a more modern gcc to build Linux. If you receive an error such as "These critical
programs are missing or too old: make" try

    scl enable devtoolset-8 bash

### Ubuntu

    sudo apt-get install autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk
build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev wget byacc
device-tree-compiler python gtkwave vim-common virtualenv python-yaml

BlackParrot has been tested extensively on CentOS 7. We have many users who have used Ubuntu for
development. If not on a relatively recent version of these OSes, we suggest using a
Docker image.

## Overview
This document is intended to provide software and firmware developers with platform level specifications necessary to develop for BlackParrot. It is a work in progress. Following the full Getting Started guide in the main BlackParrot is the best way to prepare for BlackParrot software development.

## Architectural Details
Currently implemented in BlackParrot is:
* RV64IMAFD_Zfencei (Integer, Multiply/Divide, Single/Double Precision Float, Atomics and Fence.i) User-mode ISA v2.00
* MSU (Machine, Supervisor and User) privilege levels conforming to Privileged Architecture v1.11
* SV39 virtual memory with variable physical address width 

## Building a Test
BlackParrot test suites live in `bp_common/test/src` and are compiled with `make -C bp_common/test <test suite>.`. When a suite is compiled, it creates a set of files in `bp_common/test/mem/<suite>`. There are also a number of potential generate targets that are useful for simulation, but are generally handled automatically by the build system. The targets include:
* .riscv (the elf file)
* .dump (a disassembly of the test)
* .mem (a Verilog hex format file, used to load memories in a simulation)
* .nbf (network boot file format, used to dma a program into BlackParrot memories, for example in FPGA)
  * The file format is (size(in 2^N bytes)_address(40 bit)_data(size bits)
    * 03_0080000000_ffd1011b00090137 = 8 bytes, address 0x8000_0000, data ffd1011b00090137
* among many others

## Building a Checkpoint Test
BlackParrot can use Dromajo to generate checkpoints for certain tests. It runs the test on Dromajo for a certain number of instructions and then generates a memory image and a bootrom image which loads the internal architectural state of the cores(PC, registers, CSRs, privilege mode, ...). We use the `sim_sample` target to create a checkpoint at `SAMPLE_START_P=<n>` for RTL simulation. We have to run it with `NBF_CONFIG_P=1` to load the processor configuration using the nbf loader and also use a bootrom configuration to load the internal state of the cores.

Optionally we can use `PRELOAD_MEM_P=1` to preload the memory image instead of writing it using the nbf loader and `SAMPLE_MEMSIZE=<k in MB>` to specify the size of memory image(default is 128MB).

### Example:
    cd <TOP>/bp_top/syn
    make build.v sim_sample.v PROG=bubblesort_demo CFG=e_bp_unicore_bootrom_cfg NBF_CONFIG_P=1 PRELOAD_MEM_P=1 SAMPLE_START_P=1000

## Cosimulation
BlackParrot also uses Dromajo to verify the correct execution of the program. It is done through comparing the commit information with the ideal C model in Dromajo using DPI calls in RTL in simulation runtime. To enable cosimulation simply run the RTL simulation  with `COSIM_P=1` flag. If the program is a checkpoint also add the `CHECKPOINT_P=1` flag.

The DPI calls which are used in the nonsynth cosim module are listed below. `init_dromajo` initializes a Dromajo model instance with a config file which includes pointers to Dromajo checkpoint files, and is called once at the beginning of the simulation. `dromajo_step` is called whenever we commit an instruction in RTL, and it compares the commit information with Dromajo and prints an error message if they diverge. Finally `dromajo_trap` is used to notify Dromajo about an interrupt event in RTL so the C model can follow the same program flow, because the C model cannot precisely predict interrupts beforehand due to their asynchronous nature.

* void init_dromajo(char* cfg_f_name);
* void dromajo_step(int hart_id, uint64_t pc, uint32_t insn, uint64_t wdata);
* void dromajo_trap(int hart_id, uint64_t cause);

Dromajo can also be used to as a standalone RISC-V simulator using the command: `dromajo --host <path_to_program_elf>`

## Parallel Cosimulation
Tests can be broken into multiple checkpoints to be simulated in parallel in order to reduce their overral cosimulation time using the `run_psample` target. A bootrom configuration should be used to load the internal state of the cores.

### Example:
    cd <TOP>/bp_top/syn
    make -j5 build.v run_psample.v CFG=e_bp_unicore_bootrom_cfg PROG=bubblesort_demo COSIM_P=1 PRELOAD_MEM_P=1 SAMPLE_INSTR_P=5000

## Testbench Helper Modules
BlackParrot provides a minimal MMIO host interface in order to run tests that do require off-chip
I/O. The unit, bp_nonsynth_host is instantiated in the testbench. It provides
* getchar = 0x0010_0000
* putchar = 0x0010_1000
* finish = 0x0010_2000

Additionally, there are tracers provided in the testbench which bind into the module and provide
output logs for use in debugging. Because these reports are sometimes very large, tracing is an
"opt-in" feature. A more streamlined process to enable these tracers and see results is in the works. In order to enable a tracer, simply add the parameter to the make command used to build.  For example make build.v sim.v DRAM_TRACE_P=1 will enable the dram tracer.

Currently, the list of tracing parameters is:
* CCE_TRACE_P - prints each coherence transaction in the CCE
* LCE_TRACE_P - prints each coherence transaction in the LCEs
* CMT_TRACE_P - prints each committed instruction along with register modifications
* DRAM_TRACE_P - prints each dram access
* NPC_TRACE_P - prints each (speculative) PC executed by the BE
* DCACHE_TRACE_P - prints each load/store
* VM_TRACE_P - prints each TLB fill
* PC_PROFILE_P - prints pc information
* BRANCH_PROFILE_P - prints branch information
* CORE_PROFILE_P - prints a cycle-accurate stall trace

