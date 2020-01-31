# Black Parrot Memory End

The Memory End (ME) comprises the Cache Coherence Engines (CCEs), Coherence Network, and L2 Memory
in a BlackParrot multicore processor. It can be configured to support one or more CCEs that connect
via the Coherence Network to one or more Local Cache Engines (LCEs), which are the L1 entities
that participate in coherence.

Refer to the Interface Specification document in *repo/docs* for more information.

## Cache Coherence Engine (CCE)

The Cache Coherence Engine (CCE) is the coherence controller for BlackParrot systems. It
implements a directory-based coherence protocol. The file *bp\_cce.v* defines the Cache
Coherence Engine.

## References

1. [BaseJump STL](http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf)

[1]: http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf
