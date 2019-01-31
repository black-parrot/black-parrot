# Black Parrot Back End

The Back End (BE) comprises the execution engine for RISC-V instructions in a BlackParrot multicore processor. It contains the true architectural state for the processor and logically controls the FE's speculative execution.

Diagrams for the BE blocks can be found [here][2]. (Diagrams are WIP as of 1/30/2019)

## Back End (BE)

The file *bp\_be\_top.v* defines the top level Back End module. This module is instantiated once
per core in a BlackParrot multicore processor. This module consists of three major components: the Calculator and the Checker and the MMU. The Calculator is responsible for performing RISC-V instructions as well as detecting exception conditions. The Checker is reponsible for scheduling instruction execution by interfacing with the FE, preventing hazards from affecting correctness by determining the true next PC, gating incorrect PCs from entering the pipeline, as well as monitoring dependency information from the Calculator. The MMU handles virtual address translation and L1 caching, as well as interface with the ME.

### Parameters

* __vaddr\_width\_p__ \- virtual address width
* __paddr\_width\_p__ \- physical address width
* __branch\_metadata\_fwd\_width\_p__ - branch prediction metadata from the FE. BE does not modify or inspect this data

* __num\_lce\_p__ \- number of LCEs in the system
* __num\_cce\_p__ \- number of CCEs in the system
* __num\_mem\_p__ \- number of memory units per CCE in the system (deprecated)
* __coh\_states\_p__ \- number of coherence states in the system (deprecated)
* __lce\_assoc\_p__ \- associativity of the LCEs
* __lce\_sets\_p__ \- number of sets in each LCE
* __cce\_block\_size\_in\_bytes\_p__ \- number of bytes per cache block in the CCEs

### Interfaces

The Back End instantiates the L1 Data Cache, which sends messages to and from the LCEs and
CCEs in the processor. Outbound messages are routed to the Coherence Network, which then delivers
them to either a CCE or another LCE, depending on the type of message. Inbound messages are
delivered to the LCEs and may come from either the CCE or another LCE.

* __LCE to CCE__ \- ready->valid (ME is helpful consumer)
* __CCE to LCE__ \- ready->valid (ME is demanding producer)
* __LCE to LCE (inbound)__ \- ready->valid (ME is helpful consumer)
* __LCE to LCE (outbound)__ \- ready->valid (ME is demanding producer)

The BE receives instruction / PC pairs (or FE exceptions) from the FE. The BE also logically controls the FE, sending redirection signals on mispredict or reset, for example.

* __FE to BE__ \- valid->ready (BE is a demanding consumer)
* __BE to FE__ \- ready->valid (BE is a demanding producer)

Note: we use the terminology defined in the [BaseJump STL][1] paper.

## References

1. [BaseJump STL](http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf)


[1]: http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf
[2]: https://docs.google.com/presentation/d/16HrBHGGUogTr1JY9CLFul4xn7O2GStC7VL0z1ktHCjk/edit
