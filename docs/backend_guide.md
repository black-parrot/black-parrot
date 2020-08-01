# CAD Backend Guide
## Implementations
BlackParrot has been silicon-validated. The design has been tested on a variety of process nodes including:
* GlobalFoundries 12nm (Tape-out)
* TSMC 40nm
* FreePDK 45nm
* SAED 90nm

BlackParrot has also been FPGA-validated, with multicore test programs able to run on:
* Kintex-7
* Ultrascale+

## ASIC Tips and Tricks
### Hierarchical Flow
For multicore tapeouts, we find it essential to use a hierarchical CAD flow to reduce runtimes. A
hierachical flow basically decomposes a large top level design into MIMs (Multiply Instantiated
Modules), which are exactly the same, down to placement and routing of standard cells. The advantage
of this is that reuse reduces runtime signficantly, as well as converges timing quicker. The
disadvantage is that there may be optimization left on the table if the MIMs are in substantially
different environments.

We use the following hierarchical scheme for BlackParrot tapeouts:
* Top - bsg_chip
* Mid -
* Bot - bp_tile_node bp_io_tile_node

bsg_chip is an test chip skeleon which uses an open-source BaseJump STL padring, bsg_tag bootstrapping and low-speed configuration, as well as hardened clock generators.
bp_tile_node is a BlackParrot tile that has CDC, routers, and link adapters so that it can connect to other tiles in a regularized 2D mesh.

### Hardened Memories
To achieve good QoR (Quality of Results), ASIC designers must "harden" large memories in their chip. Unlike in traditional FPGA flows, RAMs are not often inferred but must be explicitly specified by the designer. Usually this process involves first invoking a vendor-provided SRAM compiler, then substituting this black-box macro for the RTL memory variant, using the vendor-provided Verilog model for simulation instead.

For BlackParrot, we find the following memories to be worth hardening for good QoR:
* BTB memory
* I$ data
* I$ tags
* I$ stat
* Integer register file
* FP register file
* D$ data
* D$ tags
* D$ stat
* CCE directory tags
* CCE Instruction RAM
* L2 slice data
* L2 slice tags
* L2 slice stat

### Retiming
To achieve reasonable timing closure, the following blocks MUST be retimed. We find that adaptive retiming is typically insufficent and manual register retiming should be used to guide the tools:
* AUX pipeline
* FMA pipeline

## FPGA Tips and Tricks
### Hardened Memories
For the Ultrascale+, it is important to signify in your RAM model that you wish to use distributed BRAM for bitmasked memory. Otherwise, the tool will not infer a BRAM, even for a large bitmasked array. In BaseJump STL, using the hardened flow this looks like: [Distributed BRAM](https://github.com/bespoke-silicon-group/basejump_stl/blob/master/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v#L36)

