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

## Instruction Latencies
* RV64I arithmetic instructions have 1-cycle latency
* RV64IA memory instructions have 3-cycle latency
* BlackParrot has a load-to-use time of 3 cycles
* BlackParrot has a 2-cycle L1 hit latency
* BlackParrot has a 2-cycle L2 hit latency, plus possible network interaction

BlackParrot has full forwarding for integer instructions

## CSRs
BlackParrot supports the following CSRs:
* U-mode
  * ustatus, cycle, time. instret
* S-mode
  * sstatus, sscratch, sepc, scause, stval, sip, satp
* M-mode
  * mvendorid (0), marchid (13), mimpid (1, incremented on tapeout), mhartid, mstatus
  * misa ({2'b10, 36'b0, 26'h140101}), medeleg, mideleg, mie, mtvec, mtvec, mcounteren
  * mscratch, mepc, mcause, mtval, mip, mcycle, minstret, mcountinhibit
* D-mode (Full debug mode support is a work-in-progress)
  * dcsr
  * dpc

## Memory-mapped Devices
BlackParrot supports having a number of devices in each tile. In a standard BlackParrot tile there is:
* CLINT (Core Local Interrupt Controller)
  * Contains memory-mapped registers used to control interrupts in a tile
  * mtime: 0x30_bff8
  * mtimecmp: 0x30_4000
  * mipi: 0x30_0000
  * mtime increments at a frequency much lower than the clock speed
  * When mtimecmp >= mtime, a timer irq is raised
  * When mipi is set, a software irq is raised
* CFG (Tile Configuration Controller)
  * Contains memory-mapped registers which provide system-level configuration options and debug access
  * Freeze - prevents the processor from executing instructions
  * Core id (read-only) - identifies the core among all cores
  * Domain id (read-only) - 3 bits identifying the ASIC group this core belongs to
  * Coordinate (read-only) - identifies the tile physical location on the NoC
  * Icache id (read-only) - the LCE id of the icache
  * Icache mode - Uncached only, or fully coherent
  * NPC - sets the PC of the next instruction to be executed
  * Dcache id (read-only) - the LCE id of the dcache
  * Dcache mode - Uncached only, or fully coherent
  * Privilege mode - the current privilege mode of the core
  * Integer registers - read / write access to the integer registers
  * CCE id (read-only) - the CCE id of the tile
  * CCE mode - Uncached only, or fully coherent
  * CSRs - read / write access to the CSR regfile
  * CCE ucode - read / write access to the CCE microcode

## Fencing
There are two types of fence instructions defined by RISC-V: FENCE.I (instruction fence) and FENCE
(data fence). BlackParrot NoCs use credit-based flow control, so fences simply wait in the dispatch
stage until all credits have been returned and no memory instructions are in the pipeline. Because
instruction and data caches are fully coherent, FENCE.I is implemented as a normal fence and a full
pipeline flush, restarting instruction fetch at the instruction after the FENCE.I.

## Emulated Instructions
BlackParrot implements the A extension partially in hardware and partially via emulation.
Specifically, LR (Load Reserved) and SC (Store Conditional) are implemented in hardware. For
instance, this is the emulation routine for amo_swap.w

    # AMO_SWAP.W
    # Parameters
    #  a0: 32-bit aligned address
    #  a1: data to store in [a0]
    # Return
    #  Data originally in [a0]
    amo_swapw:
     lr.w t0, (a0)
     sc.w t1, a1, (a0)
     bnez t1, amo_swapw
     mv a0, t0
     jalr x0, ra

A typical execution for an atomic instruction is therefore:
* fetch amo_add
* illegal instruction trap to M-mode
* fetch instruction decode routine
* software decode instruction
* execute emulation routine
* return from M-mode emulation 

## Platform Address Maps
### Global Address Memory Map
* 0x00_0000_0000 - 0x00_7FFF_FFFF
  * Uncached, local memory
  * (See local address map for further breakdown)
* 0x00_8000_0000 - 0x0F_FFFF_FFFF
  * Cached, global memory
  * Striped by cache line
  * DRAM region
* 0x10_0000_0000 - 0x1F_FFFF_FFFF
  * Uncached, global memory
  * Striped by tile
  * Streaming accelerator region
* 0x20_0000_0000 - 0xFF_FFFF_FFFF
  * Uncached, ASIC-global memory
  * Striped by tile
  * Off-chip region

### Local Address Map
* 0x00_0000_0000 - 0x00_0(nnnN)(D)(A_AAAA)
  * nnnN -> 7 bits = 128 max tiles
  * D -> 4 bits = 16 max devices
  * A_AAAA -> 20 bits = 1 MB address space per device
* Examples
  * Devices: Configuration Link, CLINT, scratchpad
  * 0x00_0101_2345 -> tile 1, device 1, address 2345 -> configuration register
  * 0x00_0200_1111 -> tile 0, device 0, address 1111 -> CLINT mtimecmp
  * 0x00_0402_0000 -> tile 2, device 2, address 0000 -> accelerator scratchpad

