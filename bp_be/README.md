# Black Parrot Back End

The Back End (BE) comprises the execution engine for RISC-V instructions in a BlackParrot multicore processor. It contains the true architectural state for the processor and logically controls the FE's speculative execution.

Diagrams for the BE blocks can be found [here][2]. (Diagrams are WIP as of 1/30/2019)

## Back End (BE)

The file *bp\_be\_top.v* defines the top level Back End module. This module is instantiated once
per core in a BlackParrot multicore processor. This module consists of three major components: the Calculator and the Checker and the MMU. The Calculator is responsible for performing RISC-V instructions as well as detecting exception conditions. The Checker is reponsible for scheduling instruction execution by interfacing with the FE, preventing hazards from affecting correctness by determining the true next PC, gating incorrect PCs from entering the pipeline, as well as monitoring dependency information from the Calculator. The MMU handles virtual address translation and L1 caching, as well as interface with the ME.

## References

1. [BaseJump STL](http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf)


[1]: http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf
[2]: https://docs.google.com/presentation/d/16HrBHGGUogTr1JY9CLFul4xn7O2GStC7VL0z1ktHCjk/edit
