# BlackParrot Interface Specifications

BlackParrot is designed as a set of modular processor building blocks connected by intentionally designed, narrow, flexible interfaces. By standardizing these interfaces at a suitable level of abstraction, designers can easily understand differnt configurations composing a wide variety of implementations, write peripheral components, or even substitute their own optimized version of modules. BlackParrot currently has 6 standardized interfaces which are unlikely to significantly change.
- Front End to Back End (Issue Interface)
- Back End to Front End (Resolution Interface)
- Cache Service (Cache Miss and Management Interface)
- Local Cache Engine to Cache Coherence Engine (BedRock Interface)
- Memory Interface (DRAM and I/O Interfaces)


## FE-BE Interfaces

The Front End and Back End communicate using FIFO queues. There will be an unambiguous and uniform policy for priority between queues. The number of queues is minimized subject to correct functionality, to reduce the complexity of the interface. The Front End Queue sends information from the Front End to the Back End. The Command Queue sends information from the Back End to the Front End. All “true” architectural state lives in the backend, but the front end may have shadow state.

Logically, the BE controls the FE and may command the FE to flush all state, redirect the PC, etc. The FE uses its queue to supply the BE with (possibly speculative) instruction/PC pairs and inform the BE of any exceptions that have occurred within the unit (e.g., misaligned instruction fetch) so the BE may ensure all exceptions are taken precisely. The BE checks the PC in the instruction/PC pairs to make sure that the FE’s predictions correspond to correct architectural execution.  On reset, the FE shall be in a quiescent state; not fetching.

If a queue is full, the unit wishing to send data should stall until a new entry can be enqueued in the appropriate queue to prevent information loss. The handshake shall conform to one of the three [BaseJump STL](http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor\_DAC\_BaseJump\_STL\_2018.pdf) handshakes, most likely valid->ready on the consumer side, and ready->valid on the input. The queues shall be implemented with one of the BaseJump STL queue implementations. Each block is responsible for only issuing operations (e.g., translation requests, cache access, instruction execution, etc.) if it is capable of storing any possible exception information for that operation.

### FE->BE (fe\_queue)
- Description: Front End Queue (FIFO) passes bp\_fe\_queue\_s comprising a message type and the message data:
  - bp\_fe\_fetch\_s
  - bp\_fe\_exception\_s
- Interface:
  - BaseJump STL valid->ready on consumer and ready->valid on producer
  - The FE Queue must support a clear operation (to support mispredicts)
- bp\_fe\_fetch\_s
  - 39-bit PC (virtual address)
  - 32-bit instruction data
    - Invariant; although the PC may be speculative, the value of _instruction_ is correct for that PC. We make similar assertions for the itlb; the itlb mappings made by the FE are not speculative; they are required to be correct at all times.
  - branch prediction metadata bp\_fe\_branch\_metadata\_fwd\_s.
    - This structure is for the branch predictor to update its internal data structures based on feedback from the BE as to whether this particular PC/instruction pair was correct. The BE does not look at the metadata, since this would mean that the BE implementation is tightly coupled to the front end implementation. This would be the opposite of our intended separation of the three components (BE,FE,ME) via a clean interface. The backend knows that the frontend has made a incorrect prediction because it was sent an incorrect PC in the FE queue.
  - Typically this structure includes a pointer back to the original state that made the prediction; for example an index into a branch history table; or a field indicating whether the prediction came from BTB, BHT, or RAS (return address stack). All of these are private to the predictor and forwarded along by the BE.
  - An example two-bit saturating counter branch prediction implementation, where high bit indicates the predicted direction, and the low bit indicates if the prediction is weak:
    - bp\_fe\_branch\_metadata\_fwd\_s (only defined in FE)
    - oldval: 2-bit state bits read from the branch history table (BHT)
    - index: index of entry in branch history table
    - If the FE cmd queue receives an attaboy, then it will perform the following operation :   
    - BHT[index] <= { oldval[1], 1’b0 };
    - We write back the predicted direction, and make it a strong prediction.
    - If the FE cmd queue receives a mispredict, then it will perform the following operation:
    - BHT[index] =  { oldval[1] ^ oldval[0], 1’b1 }
    - We flip the predicted direction if it was a weak prediction last time. Any prediction after a misprediction is a weak prediction. 
    - The branch prediction metadata should be associated with an incorrect PC that has been presented to the front end, rather than the instruction that generated that PC, since these could be arbitrarily separated in microarchitectural time (via icache or TLB) and will increase complexity.
  - Future possible extensions (or non-features for this version.)
    - K-bit HART ID for multithreading. For now, we hold off on this, as we generally don’t want to add interfaces we don’t support. 
    - Process ID, Address Space ID, or thread ID (is this needed?) 
    - If any of these things are actually ISA concepts, seems like the best thing is to just say that the fetch unit must be flushed to prevent co-existence of these items, eliminating the need to disambiguate between them.
- bp\_fe\_exception\_s
  - Exceptions should be serviced inline with instructions. Otherwise we have no way of knowing if this exception is eclipsed by a preceding branch mispredict. Every instruction has a PC so that field can be reused. We can carry a bit-vector along inside bp\_fe\_fetch\_s to indicate these exceptions and/or other status information. FE does not receive interrupts, but may raise exceptions.
  - 39-bit virtual PC causing the exception (should be aligned with PC bp\_fe\_queue\_s)
    - Specifies the PC of the illegal instruction, or the address (PC) causing exceptions.
  - Exception Code (cause)
    - In order of priority:
    - Instruction Address Misaligned
      - This has priority over a TLB miss because a itlb miss can have a side-effect, and presumably a misaligned instruction is a sign of anomalous execution.
    - itlb miss 
      - Page table walking can not occur in front end, because it writes the A bit in the page table entries; which means the instruction cache would have to support writes. Moreover, this bit is an architectural side effect, and is not allowed to be set speculatively. Only the backend can precisely commit architectural side-effects. For these reasons, itlb misses are handled by the backend.
    - This may also occur if translation is disabled. In this case, a itlb means that the physical page is not in the itlb and we don’t have the PMP/PMA information cached. The BE will not perform a page walk in this case; it will just return the PMP/PMA information.
    - Instruction access faults (i.e. permissions) must be checked by the FE because the interpretation of the L and X bits are determined by whether the system is in M mode or S and U mode. These bits will be stored in the itlb.
Illegal Instruction
  - Future possible extensions (or non-features for this version.)
    - Support for multiple fetch entries in a single packet. Only useful for multiple-issue BE implementations.

### BE->FE (fe\_cmd)
- Description: FE Command Queue (fe\_cmd) sends the following commands from the Back End to the Front End, using a single command queue containing structures of type bp\_fe\_cmd\_s. From the perspective of architectural and microarchitectural state, enqueuing a command onto the command queue is beyond the point of no return, although the side-effects are not guaranteed until after the fence line goes high. With the exception of the attaboy commands, the BE will not enqueue additional commands until all prior commands have been processed. The FE must dequeue attaboys immediately upon reception and should process other commands as quickly as possible. However, due to the fence line it is not an invariant that the FE processes other instructions within a single cycle. The Command Queue shall transmit a union data structure, bp\_fe\_cmd\_s which contains opcodes and operands.
- Interface
  - The FIFO should not need to support a clear operation (except for via a full reset), all things enqueued must be processed.
  - The FIFO should have a fence wire to indicate if all items have been absorbed from the FIFO, & all commands have been processed. Depending on implementation, the fence wire may be asserted multiple cycles after the FIFO is actually empty.
  - Commands that feature PC redirection or shadow state change will flush the FE Queue. The BE of the processor will wait on the FE cmd queue’s fence wire before reading new items from the FE queue or enqueing new items on the command queue.
- Available Commands
  - State reset
    - Standard operands
      - PC virtual address
    - Used after reset, or after coming out of power gating
    - Flush / invalidate all state
      - Instruction/Exception pipeline
      - itlb
      - L1 I$
      - Shadow U/S/M bit
      - ASIDs
    - Reset PC to X
  - PC redirection
    - Standard operands
      - PC virtual address
    - Subopcodes
      - URET, SRET, MRET
        - These return from a trap and will contain the PC to return to. They set the shadow privilege mode in the FE.  This is done because the EPC is architectural state and lives in the BE, but we want to track this to avoid speculative access of state (instruction cache line) that is guarded by a protection boundary.
      - Interrupt (no-fault PC redirection)
      - Branch mispredict (at-fault PC redirection)
        - In this case, the PC is the corrected target PC, not the PC of the branch
        - bp_fe_branch_metadata_fwd_s
        - Misprection reason (not a branch, wrong direction)
      - Trap (at-fault PC redirection, with potential change of permissions)
      - Context switch (no-fault PC redirection to new address space; see satp register)
        - ASID
        - Translation enabled / disabled
      - Simple FE implementations which do not track the ASID for each TLB entry will also perform an itlb fence operation, flushing the itlb.
      - More complex FE implementations will register the new ASID and not perform an itlb fence.
  - Icache fence
    - If icache is coherent with dcache, flush the icache pipeline.
    - Else, flush the icache pipeline and the icache as well.
  - Attaboy (no PC redirection, contains branch pred feedback information corresponding to correct prediction
    - bp\_fe\_branch\_metadata\_fwd\_s
  - Itlb fill response
    - Contains the information necessary to populate an itlb translation.
    - Standard operands:
      - PC virtual address
        - If translation is disabled, this will actually be a physical address
      - Page table entry leaf subfields
        - Physical address
        - Extent
        - U bit (user or supervisor)
          - Each page is executable by user or supervisor, but not both
        - G bit (global bit)
          - Protects entries from invalidation by sfence.VMA if they have ASID=0
        - L,X bits (PMP metadata)
      - Non-operands
        - D,W,R,V bits. The RSW field is unused.
    - Notes
      - The FE uses its own heuristics to decide what to evict
      - Eviction does not require writeback of information
  - Itlb fence
    - Issued upon sfence.VMA commit or when PMA/PMP bits are modified
    - Standard operands:
      - Virtual address
      - asid
      - All addresses flag
      - All asid flag
    - A simple implementation will flush the entire itlb

## Cache Service Interface

The Cache Service interface provides flexible connections between an (optionally) coherent cache and
a Cache Engine, which services misses, invalidations, coherence transactions, etc. The Cache Service
interface supports both coherent and non-coherent caches, and can be extended to support
both blocking and non-blocking caches. The interface is latency insensitive and may be optionally
routed through a FIFO. BlackParrot provides 3 types of Cache Engines:

- Local Cache Engines (LCE), which manages structures in the cache by responding to local misses and
  remote coherence messages.
- Cache Coherence Engines (CCE), which maintain a distributed set of directory tags and send messages to
  maintain coherence among caches.
- Unified Cache Engines (UCE), which respond to cache requests by directly managing data from
  memory. In this way, a UCE is a combination of an LCE and a CCE, optimized for size and complexity
  in order to service a single cache.

More details are provided about the LCE and CCE interface in the following section.

A UCE implementation must support the following operations:
- Service loads, stores and optionally amo operations
- Handle remote invalidations
- Handle both uncached and cached requests
- Support both write-through and write-back protocols
- Support credit-based flow control, to support fencing in the core

The request interface is ready-valid and uses a parameterized struct to pass arguments,
bp_cache_req_s, which contains the following fields.
- Message type
  - Load Miss
  - Store Miss
  - Uncached Load
  - Uncached Store
  - Writethrough Store
- Physical address
- Size (1B-64B)
- Data (For uncached stores or writethroughs)

Additionally, the Cache Engine may require some metadata in order to service cache misses. This metadata may not be available at the same time as the request, due to the nature of high performance caches. The handshake here is valid-only. If a Cache Engines needs metadata in order to service the miss, it needs to be ready to accept metadata at any cycle later than or equal to the original cache miss. The cache is required to eventually provide this data, although not in any particular cycle. The current metadata fields are:
- Dirty
- Replacement way

The fill interface is implemented as a set of ready-valid connections that provide read/write access
to memory structures in a typical cache. A single cache request may trigger a set of fill responses. To decouple cache logic from any particular fill strategy, there is an additional signal which is raised when a request is
completed. The three memory structures are a data memory, tag memory and status memory.

The data memory contains cache block data, and the packet format is:
- Opcode
  - Write data memory
  - Read data memory
  - Write uncached data memory
- Cacheline data
- Replacement way
- Replacement index

The tag memory contains tags and coherence state, and the packet format is:
- Opcode
  - Clear all tags in a set for a given index
  - Write tag memory
  - Read tag memory
- Tag data
- Coherence data
- Replacement way
- Replacement index

The stat memory contains LRU and dirty data for a block, and the packet format is:
- Opcode
  - Clear all dirty and LRU bits for a given index
  - Read stat memory
  - Clear dirty bit for given index and way id
- Stat data
- Replacement way
- Replacement index

When a transaction is completed, cache_req_complete_o will go high for one cycle.

## Memory Interface

The BlackParrot Memory Interface is a simple command / response interface used for communicating with memory or I/O devices. The goal is to provide a simple and understandable way to access any type of memory system, be it a shared bus or a more sophisticated network-on-chip scheme. The Memory Interface can easily be transduced to standard protocols such as AXI, AXI-lite or WishBone. Because there are a wide variety of components which connect using the Memory Interface, there is no specific handshake associated with it. However, all nodes should be latency-insensitive.

A memory command or response packet is composed of:
- Message type
  - Read request
  - Write request
  - Uncached read request
  - Uncached write request
  - Writeback
  - Prefetch
- Physical address
- Request Size
- Payload (A black-box to the command receiver, this is returned as-is along with the memory response)
  - An example payload for the CCE is:
  - Requesting LCE
  - Requesting way id
  - Coherence state
  - Whether this is a speculative request
- Data

## LCE-CCE Interface

The LCE-CCE Interface comprises the connections between the BlackParrot caches and the
memory system. The interface is implemented as a collection of networks, whose primary purpose is
to carry the memory access and cache coherence traffic between the L1 instruction and data caches
and the coherence directory and rest of the memory system. The two components that interact through
the interface are the Local Cache Engines (LCE) and Cache Coherence Engines (CCE).

A Local Cache Engine (LCE) is a coherence controller attached to each L1 entity in the system. The
most common L1 entities are the instruction and data caches in the Front End and Back End,
respectively, of a BlackParrot processor. The LCE is responsible for initiating coherence requests
and responding to coherence commands. A Cache Coherence Engine (CCE) is a coherence directory that
manages the coherence state of blocks cached in any of the LCEs. The CCEs have full control over
the coherence state of all cache blocks. Each CCE manages the coherence state of a subset of the
physical address space, and there may be many LCEs and CCEs in a multicore BlackParrot processor.

The LCE-CCE Interface comprises three networks: LCE Request, LCE Command, and LCE Response. An
LCE initiates a coherence request using the LCE Request network. The CCEs issue commands, such as
invalidations or tag and data commands to complete requests, on the LCE Command network while
processing an LCE Request. The LCEs respond to commands issued by the CCEs by sending messages
on the LCE Response network. Each of these networks is point-to-point ordered and input buffered.
The LCEs and CCEs must also be input buffered to conform to the handshaking of the networks.

Custom messages are also supported by the interface, and may their processing is dependent on
the LCE and CCE implementations. Only destination, message type, address, data length, and data
fields are required for custom messages.

The LCE-CCE Interface is defined in [bp\_common\_me\_if.vh](../bp_common/src/include/bp_common_me_if.vh)

### LCE Request Network

The LCE Request network carries coherence requests from the LCEs to the CCEs. Requests are initiated
when an LCE encounters a cache or coherence miss. Cache misses occur when the LCE does not contain
the desired cache block. A coherence miss occurs when the LCE contains a valid copy of the desired
cache block, but has insufficient permissions to perform the desired operation (e.g., trying to write
a cache block that the LCE has with read-only permissions). An LCE Request may also be sent to
perform an uncached load or store operation. Issuing an LCE Request initiates a new coherence
transaction, which is handled by one of the CCEs in the system.

#### LCE Request Messages

An LCE Request is sent from an LCE to a CCE when the LCE requests a new cache block, needs different
coherence permissions that it already has for a cache block, or needs to perform an uncached load
or store.

An LCE Request has the following fields:
* Destination ID - destination CCE ID
* Message Type - Load/Store, Cached/Uncached, Custom
* Data Length - Number of 64-bit data packets following header (only for custom messages)
* Source ID - requesting LCE ID
* Address - request address (must be naturally aligned if uncached request)
* Non-Exclusive Request Bit - 1 if LCE does not want Exclusive rights to cache block
* LRU Way ID - cache way within cache set that LCE wants miss filled to
* LRU Dirty Bit - 1 if LRU Way ID holds a currently dirty cache block
* Uncached Request Size - size of load or store, in bytes
* Data - data for uncached store or custom message payload

### LCE Command Network

The LCE Command network carries commands and data to the LCEs. Most messages on this network originate
at the CCEs. LCEs may also occasionally send LCE Command messages to perform LCE to LCE transfers
of cache block data, but only do so when commanded to by a CCE. Common LCE Commands include cache
block invalidation and writeback commands, data and tag commands that deliver a valid cache block
and coherence permissions to an LCE, and transfer commands that tell an LCE to send a cache block
to another LCE in the system.

#### LCE Command Messages

LCE Command Messages have two formats, one for commands that send data to an LCE and one that does
not send data. Not all fields in each of the messages are used by every command type. For example,
a Sync Command only requires the Destination ID, Message Type, and Source ID fields.

An LCE Command has the following fields:
* Destination ID - destination LCE ID
* Message Type - command message type (see below)
* Data Length - Number of 64-bit data packets following header (only for custom messages)
* Source ID - sending CCE ID
* Address - address
* Way ID - cache way within LCE's cache set (given by address) to operate on
* State - coherence state
* Target LCE - LCE ID that receiving LCE will send cache block data and tag to for Transfer Command
* Target Way ID - cache way within target LCE's cache set (determined by address) to fill data in
* Data - cache block data, uncached load data, or custom message payload

LCE Command Message Types:
* Sync - synchronization command during system initialization
* Set Clear - set clear command during system initialization
* Transfer - command an LCE to send cache block and tag to another LCE
* Writeback - command an LCE to writeback a (potentially) dirty cache block
* Set Tag - send tag and coherence state to an LCE, but no not wake up LCE
* Set Tag and Wakeup - send tag and coherence state to an LCE, and wake up the LCE
* Invalidate Tag - invalidate a specific cache block (given by address and way) in an LCE
* Uncached Store Done - inform LCE that an uncached store was completed by memory
* Data and Tag - send tag, coherence state, and cache block data to an LCE, and wake up the LCE
* Uncached Data - send uncached load data to an LCE

### LCE Response Network

The LCE Response network carries acknowledgement and data writeback messages from the LCEs to the
CCEs. The CCE must be able to sink any potential LCE Response that could be generated in the system
in order to prevent deadlock in the system. Sinking a message can be accomplished by processing
the message when it arrives or placing it into a buffer to consume it from the network. If
buffering is used, the buffer must be large enough to hold all possible response messages to the
CCE.

#### LCE Response Messages

An LCE Response message has the following fields:
* Destination ID - destination CCE ID
* Message Type - response type (see below)
* Data Length - Number of 64-bit data packets following header (only for custom messages)
* Source ID - sending LCE ID
* Address - cache block address
* Data - cache block data (if required) or custom message payload

LCE Response Message Types:
* Sync Ack - synchronization acknowledgement during system initialization
* Inv Ack - invalidation ack to acknowledge invalidation command has been processed
* Coh Ack - coherence ack to acknowledge end of coherence transaction
* Resp WB - cache block writeback response, with cache block data
* Resp Null WB - cache block writeback response, without cache block data

### Network Priorities

The three networks of the LCE-CCE Interface have a priority ordering, from highest to lowest, of
LCE Response, LCE Command, LCE Request. In other words, LCE Responses are the highest priority
messages, followed by LCE Commands, and lastly LCE Requests, which are the lowest priority. The
priority of messages across the networks is required to ensure deadlock free operation of the
coherence protocol. A message on a lower priority network may cause a message to be
sent on a higher priority network, but a higher priority message may not cause a lower priority
message to be sent. These priority restrictions prevent the presence of cycles between messages
on the three networks, the presence of which may lead to deadlock in the protocol.

### Cache Coherence Protocol Overview

The LCEs and CCEs operate cooperatively to implement the cache coherence protocol in a multicore
BlackParrot processor. The standard coherence protocol is a directory-based MESI protocol. The
coherence protocol implemented is similar to traditional directory-based coherence protocols, but
differs in a few subtle ways. First, all coherence state is managed exclusively by the CCEs
(coherence directories). Second, all state transitions in the LCE are atomic, and there are zero
transient states in the protocol. Third, the coherence directory mantains the full coherence state
of all blocks cached in the system, and the directories are fully inclusive of all LCEs.

A coherence transaction begins when an LCE sends an LCE Request to a CCE due to a read or write miss.
The CCE receives the LCE Request and begins processing it by reading the coherence directory. Based on
the current coherence state of the requested cache block, the CCE will send a sequence of LCE Commands
that will, if required, 1) invalidate the block from other LCEs, 2) writeback the cache block that
is being replaced in the requesting LCE, and 3) initiate an LCE to LCE transfer or fetch the requested
block from the next level of cache or memory. The coherence transaction closes when the requesting
LCE receives the new coherence state and any required data for the requested block and responds to the
CCE with a coherence acknowledgement message.

The LCE-CCE Interface described above carries the coherence protocol messages between LCEs and CCEs
in a BlackParrot multicore system.

### Tag Sets and Way Groups

Coherence information in a multicore BlackParrot system is maintained using Tag Sets and Way Groups.
A Tag Set Entry comprises an address tag and coherence state for a single cache
block in an LCE. A Tag Set is the collection of Tag Set Entries for all cache block blocks in a
single LCE cache set. There is one Tag Set per LCE cache set. Each LCE keeps a shadow copy of the
Tag Sets for every cache block associated with the LCE, while the CCEs store the true copies of the
Tag Sets. Only a CCE may modify the address or coherence state of a Tag Set Entry. Each LCE also
maintains management bits, such as a dirty bit, for each cache block / Tag Set Entry in the LCE's
cache.

A Way Group is a collection of Tag Sets from all LCEs in the system that map to the same set of
physical addresses. Way Groups are employed by CCEs to manage the coherence state
of all cache blocks across all LCE's in the system. Each way group has an associated Pending Bit
that tracks whether the way group already has an outstanding coherence transaction being processed.
In order to maintain correctness in the memory system, a CCE only processes a new LCE Request if
the pending bit is cleared for the way group associated with the request address. Requests
targeting unique way groups may be processed concurrently in the system in order to provide
concurrency in the memory system.

### Way Group Pending Bits

Each way group contains a Pending Bit that is used to order coherence requests for addresses
mapping to the way group. In practice, the pending bit is implemented as a small counter. This
counter is incremented when the CCE begins processing a new LCE Request and when the CCE sends
a command to memory while processing the request. The counter is decremented when the CCE
receives and processes responses from memory and the coherence acknowledgement from the LCE. The
protocol makes no assumptions about the latency of messages between the LCEs and CCEs or the CCEs
and memory, and a transaction is only complete when all memory commands have been completed and
the LCE has responded with a coherence acknowldegement, which may arrive before or after the last
memory response.

### LCE Request Processing

Each LCE Request is processed by a single CCE, and requests are processed in the order they arrive at
the CCE. When a new request arrives, the CCE performs a sequence of operations including reading
the coherence directory, checking the associated way group's pending bit, invalidating or downgrading
the block from LCEs, writing back the LRU block from the requesting LCE, and providing the cache block
data and tag to the requesting LCE. In order to preserve correctness of the coherence protocol, the CCE
must perform certain operations before others.

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

