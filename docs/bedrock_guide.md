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
provides a brief overview of BP-Bedrock.

### BP-BedRock Network Interface Specifications

The BlackParrot BedRock Interfaces are defined in the following files:
- [bp\_common\_bedrock\_if.svh](../bp_common/src/include/bp_common_bedrock_if.svh)
- [bp\_common\_bedrock\_pkgdef.svh](../bp_common/src/include/bp_common_bedrock_pkgdef.svh)
- [bp\_common\_bedrock\_wormhole_defines.svh](../bp_common/src/include/bp_common_bedrock_wormhole_defines.svh)

BP-BedRock defines a common message format with a unified header and parameterizable payload.
The header includes message type, operation sub-type, address, and size fields, as well as
the parameterizable payload. The payload is network-specific and carries metadata required to
process messages on the selected network. The current implementation defines message formats
for the four BedRock coherence protocol networks and a memory command/response network
(discussed in the [interface\_specification](interface_specification.md).

The files above are the authoritative definitions for the BP-BedRock interface implementation.
In the event that the code differs from any documentation on or referenced by this page, the code
shall be considered as the current and authoritative specification.

### BP-BedRock Coherence Interface

The BP-BedRock coherence interface (also called the LCE-CCE interface) carries messages between the
BlackParrot LCEs (cache controllers) and CCEs (coherence directories). This interface implements
the four BedRock coherence networks: Request, Command, Fill, and Response. Each network utilizes
the BedRock message formats. For brevity, we outline the fields that differ for each network below.
Fields not listed (e.g., message size, address) have common meanings across all message types.

The Request network has the following message types and payload fields:
- Message type
  - Read miss
  - Write miss
  - Uncached read/load (1, 2, 4, or 8 bytes)
  - Uncached write/store (1, 2, 4, or 8 bytes)
  - Uncached Atomic
- Payload
  - Destination CCE
  - Requesting LCE
  - Requesting Way ID
  - Non-exclusive request hint (request block in read-only state without write permissions)

The Command network has the following message types and payload fields:
- Message type
  - Sync
  - Invalidate
  - Set State
  - Data (cache block data, tag, and state)
  - Set State and Wakeup (cache block permission upgrade, no data)
  - Writeback
  - Set State and Writeback
  - Transfer
  - Set State and Transfer
  - Set State, Transfer, and Writeback
  - Uncached Data (uncached load request data from memory)
  - Uncached Store Done (uncached store request has been completed to memory)
- Payload
  - Destination LCE
  - CCE sending command
  - Cache Way ID
  - Coherence State
  - Target cache, state, and way ID for cache to cache transfer

The Fill network has the following message types and payload fields:
- Message type
  - Data (cache to cache block transfer)
- Payload
  - Destination LCE
  - CCE managing block
  - Cache Way ID
  - Coherence State

The Response network has the following message types and payload fields:
- Message type
  - Sync Ack
  - Invalidation Ack
  - Coherence Transaction Ack
  - Writeback
  - Null Writeback
- Payload
 - Destination CCE
 - Responding LCE

All LCE-CCE network messages use the same address and data alignment constraints. These constraints
are consistent with the BlackParrot Memory Interface. Uncached accesses are naturally aligned to
the size of the request, and behavior of a misaligned request is undefined. Cacheable accesses and
operations are block-based and operate on the data of the single cache block specified by the
address. Critical word first behavior is supported and cache block data is transferred beginning
with the byte at the requested address, continuing to the last byte of the block, then wrapping
around at the cache block boundary and continuing with the first byte of the block up to the byte
preceding the requested address byte. In other words, the cache block data is rotated left to
place the requested address at the least significant position of the message data field. This
behavior naturally supports networks that serialize the cache block data and send the block in
multiple data beats, as well as conversion between different serialization widths without requiring
re-alignment of message data.

### BP-BedRock Local Cache Engine (LCE) Microarchitecture

Coming Soon!

### BP-BedRock Cache Coherence Engine (CCE) Microarchitecture

Refer to the [BedRock Microarchitecture Guide](bedrock_uarch_guide.md) for an overview of the cache
coherence directory designs employed in BlackParrot.


