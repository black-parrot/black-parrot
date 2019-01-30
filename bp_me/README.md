# Black Parrot Memory End

The Memory End (ME) comprises the Cache Coherence Engines (CCEs), Coherence Network, and L2 Memory
in a BlackParrot multicore processor. It can be configured to support one or more CCEs that connect
via the Coherence Network to one or more Local Cache Engines (LCEs), which are the L1 entities
that participate in coherence.

Diagrams for the ME blocks can be found [here][2]

## Memory End (ME)

The file *bp\_me\_top.v* defines the top level Memory End module. This module is instantiated once
per BlackParrot multicore processor. This module instantiates the Coherence Network, CCEs, and
L2 memory.

### Parameters

* __num\_lce\_p__ \- number of LCEs in the system
* __num\_cce\_p__ \- number of CCEs in the system
* __num\_mem\_p__ \- number of memory units per CCE in the system
* __addr\_width\_p__ \- physical address width
* __lce\_assoc\_p__ \- Associativity of the LCEs
* __lce\_sets\_p__ \- number of Sets in each LCE
* __block\_size\_in\_bytes\_p__ \- number of bytes per cache block in the LCEs
* __num\_inst\_ram\_els\_p__ \- size of CCE microcode instruction RAM in number of instructions
* __mem\_els\_p__ \- number of cache block sized memory elements in the simulated memory
* __boot\_rom\_els\_p__ \- number of boot ROM words that will be used to initialize simulated memory
* __boot\_rom\_width\_p__ \- width of each boot ROM entry

### Interfaces

The Memory End instantiates the Coherence Network, which sends messages to and from the LCEs and
CCEs in the processor. Inbound messages are routed to the Coherence Network, which then delivers
them to either a CCE or another LCE, depending on the type of message. Outbound messages are
delivered to the LCEs and may come from either the CCE or another LCE.

* __LCE to CCE__ \- ready->valid (ME is helpful consumer)
* __CCE to LCE__ \- ready->valid (ME is demanding producer)
* __LCE to LCE (inbound)__ \- ready->valid (ME is helpful consumer)
* __LCE to LCE (outbound)__ \- ready->valid (ME is demanding producer)

Note: we use the terminology defined in the [BaseJump STL][1] paper.

## Cache Coherence Engine (CCE)

The Cache Coherence Engine (CCE) is the coherence controller for BlackParrot systems. It
implements a directory-based coherence protocol. The file *bp\_cce\_top.v* defines the Cache
Coherence Engine and instantiates the CCE and exposes a well-defined handshaking interface.

### Parameters

* __cce\_id\_p__ \- ID of this CCE in the system
* __num\_lce\_p__ \- number of LCEs in the system
* __num\_cce\_p__ \- number of CCEs in the system
* __num\_mem\_p__ \- number of memory units attached to this CCE (only 1 supported currently)
* __addr\_width\_p__ \- physical address width
* __lce\_assoc\_p__ \- Associativity of the LCEs
* __lce\_sets\_p__ \- number of Sets in each LCE
* __block\_size\_in\_bytes\_p__ \- number of bytes per cache block in the LCEs
* __num\_inst\_ram\_els\_p__ \- size of CCE microcode instruction RAM in number of instructions

### Interfaces

* __LCE to CCE__ \- ready->valid (CCE is helpful consumer)
* __CCE to LCE__ \- ready->valid (CCE is demanding producer)
* __L2 Mem to CCE__ \- ready->valid (CCE is helpful consumer)
* __CCE to L2 Mem__ \- valid->yumi (CCE is helpful producer)
  * This interface is also known as valid->ready

## References

1. [BaseJump STL](http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf)


[1]: http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor_DAC_BaseJump_STL_2018.pdf
[2]: http://docs.google.com/presentation/d/1yfb3akbj7ajXSX3sYYmxcPwYRE8H5mElJf3b8Vi6mbo/edit 
