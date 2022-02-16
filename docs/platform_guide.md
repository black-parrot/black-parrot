# BlackParrot Platform Guide
## Tile Taxonomy
![Tile Taxonomy](tile_taxonomy.png)

## Instruction Latencies
* RV64I arithmetic instructions have 1-cycle latency
* RV64IA memory instructions have 2/3-cycle latency
* RV64M instructions have a 3-cycle latency, except for division, which is iterative
* Rv64FD instructions have a 4-cycle latency, exception for fdiv/fsqrt, which are iterative
* BlackParrot has a load-to-use time of 2 cycles for dwords, 3 cycles for words, halfs, and bytes
* BlackParrot has a 2-cycle L1 hit latency for integer loads
* BlackParrot has a 3-cycle L1 hit latency for floating point loads 
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
* CFG (Tile Configuration Controller)
* CLINT (Core Local Interrupt Controller)
* L2S (L2 cache slice)

The map for configuration registers within these devices is shown below.

## Fencing
There are two types of fence instructions defined by RISC-V: FENCE.I (instruction fence) and FENCE
(data fence). BlackParrot NoCs use credit-based flow control, so fences simply wait in the dispatch
stage until all credits have been returned and no memory instructions are in the pipeline. Because
instruction and data caches are fully coherent, FENCE.I is implemented as a normal fence and a full
pipeline flush, restarting instruction fetch at the instruction after the FENCE.I.

For the unicore version of BlackParrot, the caches are not coherent. Therefore, on FENCE.I, the
D$ goes through a flush routine, then the I$ goes through an invalidate routine.

## Emulated Instructions
BlackParrot can implement the A extension instructions in L2, L1 or partially in hardware and partially via emulation.
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

Similarly, BlackParrot emulates MULH, MULHSU, MULHU using hardware supported MUL instructions.

## Platform Address Maps

BlackParrot has a configurable physical address width as well as maximum DRAM size. The below configuration is shown for the default value with a 40-bit physical address with and a 4GB DRAM size.

### Global Address Memory Map
* 0x00_0000_0000 - 0x00_7FFF_FFFF
  * Uncached, local memory
  * (See local address map for further breakdown)
* 0x00_8000_0000 - 0x00_FFFF_FFFF
  * Cached, global memory
  * Striped by cache line
  * Cached DRAM region
* 0x01_0000_0000 - 0x01_FFFF_FFFF
  * Uncached, global memory
  * Striped by cache line
  * Uncached DRAM region
* 0x02_0000_0000 - 0x03_FFFF_FFFF
  * Uncached, global memory
  * Striped by tile
  * Streaming accelerator region
* 0x04_0000_0000 - 0xFF_FFFF_FFFF
  * Uncached, ASIC-global memory
  * Striped by tile
  * Off-chip region

For a BlackParrot Unicore, an "off-chip" address goes out the io_cmd/io_resp ports. An "on-chip"
address goes to a local device if below the DRAM base address, and to the L2 if in DRAM space.

For a BlackParrot Multicore, an "off-chip" device is routed to the I/O complex. The I/O complex will
either send it east or west depending on the destination "domain ID" (upper uncached bits) of the
address compared to the domain ID of the chip itself (set statically at the toplevel). Additionally,
addreses in the host address space are routed to the static host domain ID set at the top level. Absolute
domain IDs are irrelevant, only relative domain IDs determine routing. However, domain ID 0 is
reserved to mean "on this local chip".

The uncached region in this scheme is rather large, fully half of the available DRAM at first
glance. However, this is only the view from BlackParrot. System designers are free to remap those
addresses as they see fit. For instance, aliasing some of the DRAM space between cached and uncached
(and manually handling the coherence issues). Another scheme is to relocate some of the memory such
that both cached and uncached are physically contiguous on the same DRAM.

### Local Address Map
For a BlackParrots in a multicore, the local address space is sliced among all the tiles as shown
below.

* 0x00_0000_0000 - 0x00_0(nnnN)(D)(A_AAAA)
  * nnnN -> 7 bits = 128 max tiles
  * D -> 4 bits = 16 max devices
  * A_AAAA -> 20 bits = 1 MB address space per device
* Examples
  * Devices: Configuration Link, CLINT
  * 0x00_0420_0002 -> tile 2, device 2, address 0008 -> Freeze register
  * 0x00_0030_bff8 -> tile 0, device 3, address bff8 -> CLINT mtime

For a BlackParrot unicore, all addresses outside of N=k in this scheme are considered as I/O. This
local space is useful for address-space constrained systems where this local space can be reused for
accelerators, co-processors, etc.

### Full Listing of BlackParrot Configuration Registers
Following is a list of the memory-mapped registers contained within a BlackParrot Unicore or BlackParrot Multicore Tile.

These addresses are per-tile. To access them on a tile N, prepend N to the address as shown above.

| Device   | Name        | Address         | Description                                                                                                                       |
|----------|-------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------|
| Bootrom* | Bootrom     | 01_0000-01_ffff | The bootrom which bootstraps BlackParrot in bootrom configurations                                                                |
| Host*    | getchar     | 10_0000         | A polling implementation to get a single char from a tethered host                                                                |
|          | putchar     | 10_1000         | Puts a character onto the terminal of a tethered host                                                                             |
|          | finish      | 10_2000-10_2fff | Terminates a multicore BlackParrot simulation, when finish[x] is received for each core x in the system                           |
|          | putch       | 10_3000-10_3fff | putch[x] puts a character into a private terminal for core x. This is useful for debugging multicore simulations                  |
| CFG      | freeze      | 20_0008         | Freezes the core, preventing all fetch operations. Will drain the pipeline if set during runtime.                                 |
|          | core_id     | 20_000c         | Read-only. This tile's core id. This is a local id within the chip                                                                |
|          | did         | 20_0010         | Read-only. This tile's domain id. This is an chip-wide identifier                                                                 |
|          | cord        | 20_0014         | Read-only. This tile's coordinate. In {y,x} format                                                                                |
|          | host_did    | 20_0018         | Host domain id. This identifies which direction to send host packets, relative to our own domain id                               |
|          | hio_mask    | 20_001c         | A mask of the upper uncached bits of an address. If an address width an unset domain bit is loaded, it will cause an access fault |
|          | icache_id   | 20_0200         | Read-only. The I$ Engine ID.                                                                                                      |
|          | icache_mode | 20_0204         | The I$ mode. Either uncached, cached, or nonspec (will not send a speculative miss)                                               |
|          | dcache_id   | 20_0400         | Read-only. The D$ Engine ID.                                                                                                      |
|          | dcache_mode | 20_0404         | The D$ mode. Either uncached or cached. (D$ will never send speculative misses)                                                   |
|          | cce_id      | 20_0600         | Read-only. The CCE Engine ID.                                                                                                     |
|          | cce_mode    | 20_0604         | The CCE mode. Either uncached or cached. Undefined behavior results when sending cached requests to a CCE in uncached mode        |
|          | cce_ucode   | 20_8000-20_8fff | The CCE instruction RAM. Must be written before enabling cached mode in a microcoded CCE                                          |
| CLINT    | mipi        | 30_0000         | mip (software interrupt) bit                                                                                                      |
|          | mtimecmp    | 30_4000         | Timer compare register. When mtime > mtimecmp, a timer irq is raised in the core                                                  |
|          | mtime       | 30_bff8         | A real-time counter. Currently implemented as mcycle/8                                                                            |
|          | plic        | 30_b000         | A fake PLIC implementation. Effectively a redundant implementation of mipi                                                        |

* This lives outside of the unicore/tile, residing in the tethered host. Implementations must map this correctly for full software support
