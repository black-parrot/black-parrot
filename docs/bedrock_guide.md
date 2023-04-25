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

The Fill network is a special network which comprises a subset of the Command network messages.
Fills can be casted safely to Cmds.
- Message type
  - Data (cache to cache block transfer)
- Payload
  - Destination LCE
  - CCE sending command
  - Cache Way ID
  - Coherence State
  - Target cache, state, and way ID for cache to cache transfer

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

#### Address and Data Alignment

All four LCE-CCE networks have the same address and data alignment properties. Uncached accesses are
naturally aligned to the size of the request, and behavior of a misaligned request is undefined.
Cacheable accesses are block-based and support critical word first behavior as defined by the
BedRock Burst protocol. The 64-bit data word that includes the request address is returned in the
critical\_data field of the response header while the entire cache block is returned over the data
channel in one or more transfers with the critical data word found in the first data transfer.

The BlackParrot LCEs and CCEs expect that cacheable requests are issued aligned to the BedRock
network data channel width (which is currently the same as the cache fill width) at the LCE.

### BP-BedRock Local Cache Engine (LCE) Microarchitecture

Coming Soon!

### BP-BedRock Cache Coherence Engine (CCE) Microarchitecture

Refer to the [BedRock Microarchitecture Guide](bedrock_uarch_guide.md) for an overview of the cache
coherence directory designs employed in BlackParrot.


