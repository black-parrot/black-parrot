# BlackParrot Software Developer Guide

## Overview
This document is intended to provide software and firmware developers with platform level specifications necessary to develop for BlackParrot. It is a work in progress. Following the full Getting Started guide in the main BlackParrot is the best way to prepare for BlackParrot software development.

## Architectural Details
Currently implemented in BlackParrot is:
* RV64IA_Zfencei (Integer, Atomics and Fence.i) User-mode ISA v2.00
* MSU (Machine, Supervisor and User) privilege levels conforming to Privileged Architecture v1.11
* SV39 virtual memory with 40 bit physical address

## Building a Test
BlackParrot test sources live in `bp_common/test/src` and are compiled with `make -C bp_common/test <test target>.` Test lists are defined in `bp_common/test/Makefrag`. When a test is compiled, it creates a set of files in `bp_common/test/mem` based on a set of targets defined in `bp_common/test/Makefile`. Most programs only require the .riscv target be redefined and can reuse the generic targets for everything else. The filesets generated include:
* .riscv (the elf file)
* .dump (a disassembly of the test)
* .spike (a spike commit log showing a run of the test)
* .mem (a Verilog hex format file, used to load memories in a simulation)
* .nbf (network boot file format, used to dma a program into BlackParrot memories, for example in FPGA)
  * The file format is (size(in 2^N bytes)_address(40 bit)_data(size bits)
    * 03_0080000000_ffd1011b00090137 = 8 bytes, address 0x8000_0000, data ffd1011b00090137

## Test Libraries
### libperch
libperch is the BlackParrot firmware library. It includes sample linker scripts for supported SoC platforms, start code for running bare-metal tests, emulation code for missing instructions and firmware routines for printing, serial input and output and program termination.

libperch is automatically compiled as part of the toplevel `make progs` target. In order to manually compile libperch, execute `make -C bp_common/test perch`. When compiled in this way, libperch.a is installed to `bp_common/test/lib`. Users should link this library when compiling a new program for BlackParrot.
  
### PanicRoom (aka bsg_newlib)
PanicRoom is a port of newlib which packages a DRAM-based filesystem (LittleFS) along with a minimal C library. By only implementing a few platform level operations, PanicRoom provides an operational filesystem, eliminating the need for a complex host interface, It is automatically included with the standard toolchain build, allowing benchmarks such as SPEC to run with minimal host overhead. For an example of how to use PanicRoom, see bp_common/test/src/spec/README.

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
* CALC_TRACE_P - prints the state of the pipeline every cycle
* CCE_TRACE_P - prints each coherence transaction
* CMT_TRACE_P - prints each committed instruction along with register modifications
* DRAM_TRACE_P - prints each dram access
* NPC_TRACE_P - prints each (speculative) PC executed by the BE
* DCACHE_TRACE_P - prints each load/store
* VM_TRACE_P - prints each TLB fill

