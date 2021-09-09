# BedRock Cache Coherence Protocol

BlackParrot's BedRock-based cache coherence system comprises three major components: a Cache
Coherence Engine (CCE) that contains and manages the coherence directory, a Local Cache Engine
(LCE) that manages entities such as data and instruction caches participating in coherence, and the
three LCE-CCE networks that carry the coherence protocol messages. BedRock currently has two CCE
implementations, which are described below.

The current implementation of BlackParrot uses point-to-point ordered networks for the
coherence networks, however the coherence protocol is designed and verified correct
for unordered or ordered networks.

![BedRock System diagram](bedrock.png)

## Coherence Networks

BedRock sends and receives messages on three networks, called Request, Command, and Response.
The message formats of these three BedRock channels are fully defined in the
[BedRock Interface](../bp_common/src/include/bp_common_bedrock_if.svh) file.
The specific message type, coherence states, and message size enums are defined in the
[BedRock Package Defines](../bp_common/src/include/bp_common_bedrock_pkgdef.svh).
The [BedRock Network Specification](bedrock_guide.md) provides an overview of the generic
BedRock message format and supported communication protocols. The three coherence networks
are implemented using the standard BedRock message format and differ only in the payload
fields within the messages.

The Request network carries coherence requests from the cache controllers (LCE) to the directory
(CCE). A request may be a Read or Write request. Requests may be cached or uncached, and
atomic operation (AMO) requests are supported.

The Command network carries coherence commands to the cache controllers (LCE). Most commands are
issued by the directory (CCE), except for cache to cache transfers that occur when a CCE commands
an LCE to send a cache block to another LCE.

The Response network carries coherence responses from the cache controllers (LCE) to the coherence
directory (CCE). Common responses include cache block data writebacks, invalidation acknowledgements,
and coherence transaction acknowledgements.

### Network Priorities

The three coherence networks are related by a priority ordering scheme. The Response network is the
highest priority, followed by the Command network, and lastly the Request network with the lowest
priority. Processing a message on a lower priority network may cause a message to be sent on a
higher priority network, but not the other way around. For example, a Request message can cause
a Command message to be sent, or a Command message can cause a Response message to be sent, but
a Response message can not cause any message to be sent since it is the highest priority network.
It is also possible for a Command network message to cause a single extra message to be sent on the
Command network, when performing a cache to cache data transfer. Preserving the priority ordering
of the networks helps prevent deadlock-free protocol operation and prevent the presence of
message cycles across the three networks.

## Coherence Protocol

The BedRock cache coherence protocol supports the MOESIF family of protocols using a directory-based
coherence system. The coherence directory, managed by the CCE, is effectively a duplicate tags or
shadow tags directory design. The key difference between BedRock and a canonical shadow tags
directory is that in BedRock it is the directory (CCE), not the local caches (LCE), that maintains
and manages the golden copy of the tags. The local caches (LCEs) hold shadow tags and are only
allowed to modify their coherence state when instructed to do so by the directory (CCE). The
directory full controls all coherence state changes and cache block replacements in all of the
LCEs. This design decision eliminates a number of races from the coherence protocol, greatly
simplifying the implementation of the LCEs and CCE. Cache requests for the same block from
different LCEs may race to the directory, but are serialized by the network and are processed
in the order they arrive by the CCE. No other races exist in the protocol due to the CCE fully
controlling all coherence state changes and cache block replacements.

At the LCE, every cache block has a small amount of associated metadata comprising the coherence
state of the block and a dirty bit. The LCE or cache also tracks, per cache set, any replacement
information required to implement the desired replacement algorithm (e.g., LRU way tracking). The
collection of cache tag, coherence state, and dirty bit for each block in a cache set plus the
LRU/replacement information per cache set is called a Tag Set.

The coherence directory collects one or more tag sets into a Way Group. A Way Group adds a pending
bit to the collection of Tag Set information. The pending bit is used to effectively lock the Tag
Sets of the Way Group, allowing only a single coherence transaction per Way Group at a time. The
mapping from address to Tag Set and Way Group is such that all addresses (cache blocks) that map
to the same Tag Set (i.e., cache set in normal cache indexing and lookup) map to the same
Way Group.

### Requests

Request Message Types:
* Read miss - cache miss on a load / read operation
* Write miss - cache miss on a store / write operation
* Uncached Read - uncached load from memory
* Uncached Write - uncached store to memory
* Atomic - AMO operations

A Request message has the following payload fields:
* Destination ID - destination CCE ID
* Source ID - requesting LCE ID
* Subop - store or atomic subop type
* Non-Exclusive Request Bit - 1 if LCE does not want Exclusive rights to cache block
* LRU Way ID - cache way within cache set that LCE wants miss filled to

Uncached store and atomic requests contain data while all other request are header-only messages.

### Commands

Command Message Types:
* Sync - synchronization command during system initialization
* Set Clear - clear entire cache set (invalidate all blocks in set)
* Invalidate - invalidate specified cache block
* Set State - set coherence state for specified cache block
* Data and Tag - fill data, tag, and coherence state for specified cache block
* Set Tag and Wakeup - set tag and coherence state for specified block and wake up LCE (miss resolved)
* Writeback - command LCE to writeback a (potentially) dirty cache block
* Transfer - command LCE to send cache block and tag to another LCE
* Set State & Writeback - set coherence state then writeback cache block
* Set State & Transfer - set coherence state then transfer cache block to specified target LCE
* Set State & Transfer & Writeback - set coherence state, transfer cache block to target LCE, and writeback cache block
* Uncached Data - send uncached load data to an LCE
* Uncached Store Done - inform LCE that an uncached store was completed by memory

A Command message has the following payload fields:
* Destination ID - destination LCE ID
* Source ID - sending CCE ID
* Way ID - cache way within LCE's cache set (given by address) to operate on
* State - coherence state
* Target LCE - LCE ID that receiving LCE will send cache block data and tag to for Transfer Command
* Target Way ID - cache way within target LCE's cache set (determined by address) to fill data in
* Target State - coherence state for target (to be implemented in future)

Cache fill commands (Data and Tag) and Uncached Data commands contain data. All other commands
are header-only messages.

### Responses

Response Message Types:
* Sync Ack - synchronization acknowledgement during system initialization
* Inv Ack - invalidation ack to acknowledge invalidation command has been processed
* Coh Ack - coherence ack to acknowledge end of coherence transaction
* Resp WB - cache block writeback response, with cache block data
* Resp Null WB - cache block writeback response, without cache block data

A Response message has the following payload fields:
* Destination ID - destination CCE ID
* Source ID - sending LCE ID

## Coherence Protocol

The BedRock coherence system supports variants of the standard MOESIF coherence protocol family.
BlackParrot's current implementation of the instruction and data caches and LCE support the full
set of MOESIF states. The specific protocol implemented in a system is determined by the CCE.
The FSM-based CCE implements a MESI protocol while the microcoded CCE can be programmed for
EI, MSI, MESI, or MOESIF protocols.

This section provides an overview of the coherence protocol operation. Please view
the following documents for detailed descriptions of the coherence protocol operation
and to view the protocol tables:
* [BedRock Protocol](bedrock_coherence_deep_dive.pdf)
* [LCE Protocol Table](bedrock_coherence_protocol_lce_table.pdf)
* [CCE Protocol Table](bedrock_coherence_protocol_cce_table.pdf)

### Request Processing

Each request is processed by a single CCE, and requests are processed in the order they arrive at
the CCE. When a new request arrives, the CCE performs a sequence of operations including checking
the associated pending bit, reading the coherence directory, invalidating or downgrading other LCEs
if required, and sourcing the cache block from memory/LLC or another LCE. A cache request may also
trigger a replacement in the requesting LCE if the target cache set has no free entries to fill
the request to.

In order to preserve correctness of the coherence protocol, the CCE must perform certain operations
before others. Primarily, this includes checking the pending bit first, performing replacement
in the requesting LCE if required to make room for the request fill, and then invalidating any
copy of the block from other LCEs prior to granting permissions to the requesting LCE.

At a high level, a coherence request is processed as described by the following list of steps. Each step
may include multiple substeps, and it may be possible to overlap actions of certain steps. The
amount of concurrency between independent requests is dependent on the complexity of the CCE
implementation. In the simplest form, all requests to a single CCE are processed in the order
received. In a complex implementation, it is only necessary to serialize requests to each way group,
while requests to independent way groups may be processed concurrently.

1. Check Pending Bit for way group associated with request address. If the bit is cleared,
   the request can be processed, otherwise stall this request.

2. Read coherence directory to determine which LCEs have block cached and in which states and to
   determine the new coherence state for the block in the requesting LCE.

3. Invalidate block from other LCEs, if required.

4. Perform a writeback of the LRU block from requesting LCE, if required.

5. Determine how request will be satisfied, which may be an Upgrade, LCE to LCE Transfer,
   or read from next level of memory (e.g., L2 cache).

6. If an LCE to LCE Transfer is used, optionally write back the cache block if it was dirty in the
   sending LCE's cache. This writeback may be deferred until the block is evicted from the last LCE.

7. Receive coherence acknowledgement to close transaction.

## BedRock Fixed-Function CCE

The BedRock Fixed-Function CCE (FSM CCE) is a hardware implementation of the cache coherence engine
that relies on fixed-function FSM logic to implement the MESI coherence protocol. It is designed
to be performant and efficient, but lacks programmability or flexibility. BlackParrot users
interested in a cache coherent system, but without the need to modify the coherence protocol or
exploit programmability in the CCE should use the FSM CCE.

## BedRock Programmable CCE

The BedRock Programmable CCE (ucode CCE) is a hardware implementationm of the cache coherence engine
employing a microcode programmed coherence engine for coherence protocol processing. The ucode CCE
executes a custom microcode ISA and is a two-stage fetch-execute machine. Programmability allows the
ucode CCE to easily switch between variants of the MOESIF protocol (MSI, MESI, MOSI, etc.) and
allows system designers to incorporate custom logic into the protocol processing routines. The ucode
CCE is under constant development and is actively used as a research platform. We encourage those
interested in the ucode CCE to read the [BedRock CCE Microarchitecture](bedrock_uarch_guide.md)
document to learn more about its design and programming.

