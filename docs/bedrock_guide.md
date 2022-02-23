# BedRock Cache Coherence and Memory System Guide

BedRock encompasses both the cache coherence and memory systems used in BlackParrot. The principle
component of BedRock is the specification of a cache coherence protocol and its required networks,
which are collectively named BedRock. The BlackParrot implementation of BedRock, called BP-BedRock
specifies the network message formats and implements the required coherence system components.
BP-BedRock further defines a memory interface and system that is compatible with and complementary
to the coherence system and network interfaces.

## BedRock Cache Coherence Protocol

BedRock defines a family of directory-based invalidate cache coherence protocols based on the standard
MOESIF coherence states. Protocol variants are defined for the MI, MSI, MESI, MOSI, MOESI, MESIF,
and MOESIF subsets of states. The protocol relies on a duplicate tag, fully inclusive, standalone
coherence directory to precisely track the coherence state of every block cached within the
coherence system. A full description of the BedRock cache coherence protocol and system is available
[here](bedrock_protocol_specification.pdf). This description is system-agnostic, however its design
has been influenced by its implementation within BlackParrot.

## BlackParrot BedRock Cache Coherence and Memory Systems

BlackParrot implements BedRock to provide cache coherence between the processor cores and
coherent accelerators in a multicore BlackParrot system. This system is called BlackParrot Bedrock
(BP-BedRock). BP-BedRock also defines a BedRock compatible memory interface. The text below
provides a brief overview of BP-Bedrock. A more complete description is available
[here](blackparrot_bedrock_specification.pdf).

### BP-BedRock Network Interface Specifications

The BlackParrot BedRock Interfaces are defined in the following files:
- [bp\_common\_bedrock\_if.svh](../bp_common/src/include/bp_common_bedrock_if.svh)
- [bp\_common\_bedrock\_pkgdef.svh](../bp_common/src/include/bp_common_bedrock_pkgdef.svh)
- [bp\_common\_bedrock\_wormhole_defines.svh](../bp_common/src/include/bp_common_bedrock_wormhole_defines.svh)

BP-BedRock defines a common message format with a unified header and parameterizable payload.
The header includes message type, operation sub-type, address, and size fields, as well as
the parameterizable payload. The payload is network-specific and carries metadata required to
process messages on the selected network. The current implementation defines message formats
for the four BedRock coherence protocol networks and a memory command/response network.

The files above are the authoritative definitions for the BP-BedRock interface implementation.
In the event that the code differs from any documentation on or referenced by this page, the code
shall be considered as the current and authoritative specification.

### BP-BedRock Coherence Interface

The BP-BedRock coherence interface (also called the LCE-CCE interface) carries messages between the
BlackParrot LCEs (cache controllers) and CCEs (coherence directories). This interface implements
the four BedRock coherence networks: Request, Command, Fill, and Response.

### BP-BedRock Memory Interface

The BP-BedRock memory interface (also called the CCE-Mem interface) is a simple command and response
interface used to communicate with memory or I/O devices. The interace can be easily transduced
to standard protocols such as AXI, AXI-Lite, WishBone, or DMA engines. The interface supports
cacheable, uncacheable, and atomic operations. Uncached accesses must be naturally aligned with
the request size. Cached accesses are block-based and return the cache block containing the
requested address. Cached accesses return the critical data word first (at LSB of data) and wrap
around the requested block as follows:

Request: 0x00, size=32B [D C B A]
Request: 0x10, size=32B [B A D C]

### BP-BedRock Microarchitecture

Refer to the [BedRock Microarchitecture Guide](bedrock_uarch_guide.md) for an overview of the cache
coherence directory designs employed in BlackParrot.


