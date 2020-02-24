# BlackParrot Microarchitecture Guide
## Introduction
**Note: BlackParrot ultimately targets the RV64IMAFDC with M,S,U privilege modes and SV39 virtual memory. This guide attempts to describes the current state of the project.**

BlackParrot is a 64-bit processor implementing the RV64IA specification of the RISC-V ISA. The core of the processor is in-order single issue, comprising a Front End (FE), a Back End (BE), and a Memory End (ME). The BlackParrot core supports virtual memory (SV39), and has private coherent L1 instruction and data caches. There are two major configurations for the BlackParrot Memory End. For single core systems, the Memory End is a lightweight state machine which manages requests between the L1 caches and either the LLC or DRAM. For multicore systems, the Memory End supports a novel, race-free MESI cache coherence protocol backed by a shared, distributed L2 cache. Both flavors of the Memory End support cache and uncached requests, along with simple request/response-based I/O.

This guide focuses on the core microarchitecture of a BlackParrot system. For information about the BlackParrot SoC architecture, refer to [SoC Guide](platform_guide.md).

## BlackParrot Core Overview
Communication between BlackParrot components is performed over a set of narrow interfaces. The interfaces are designed to allow the implementations of the Front End, Back End and Memory End to change independently of one another. For more information about these interfaces, refer to the [Interface Specification](interface_specification.md).

## Front End
The FE is responsible for speculatively fetching instructions from the Memory End and providing the BE with stream of speculative PC-instruction pairs. To this end, FE consists of 2 major components: pc-generation and instruction memory. Note that the FE does not modify any architectural state and the BE logically controls the FE through PC redirect or flush commands.

### PC Generation

### Instruction Memory
#### Instruction Cache

#### ITLB

## Back End
### Checker

#### Detector

#### Director

#### Scheduler

### Calculator

### Data Memory
#### Data Cache

#### DTLB

#### Page Table Walker

## Memory End
### LCE

### CCE

### UCE

### L2
