# BlackParrot Interface Specifications

BlackParrot is designed as a set of modular processor building blocks connected by intentionally designed, narrow, flexible interfaces. By standardizing these interfaces at a suitable level of abstraction, designers can easily understand differnt configurations composing a wide variety of implementations, write peripheral components, or even substitute their own optimized version of modules. BlackParrot currently has 5 standardized interfaces which are unlikely to significantly change.
- Front End to Back End (Core Interface, Issue Channel)
- Back End to Front End (Core Interface, Resolution Channel)
- Cache Engine (Cache Miss, Fill, and Coherence Interfaces)
- Local Cache Engine to Cache Coherence Engine (BedRock Interface, Coherence Channels)
- Memory Interface (BedRock Interface, DRAM and I/O Channels)


## FE-BE Interfaces

The Front End and Back End communicate using FIFO queues. There will be an unambiguous and uniform policy for priority between queues. The number of queues is minimized subject to correct functionality, to reduce the complexity of the interface. The Front End Queue sends information from the Front End to the Back End. The Command Queue sends information from the Back End to the Front End. All “true” architectural state lives in the backend, but the front end may have shadow state.

Logically, the BE controls the FE and may command the FE to flush all state, redirect the PC, etc. The FE uses its queue to supply the BE with (possibly speculative) instruction/PC pairs and inform the BE of any exceptions that have occurred within the unit (e.g., misaligned instruction fetch) so the BE may ensure all exceptions are taken precisely. The BE checks the PC in the instruction/PC pairs to make sure that the FE’s predictions correspond to correct architectural execution. On reset, the FE shall be in a quiescent state; not fetching.

If a queue is full, the unit wishing to send data should stall until a new entry can be enqueued in the appropriate queue to prevent information loss. The handshake shall conform to one of the three [BaseJump STL](http://cseweb.ucsd.edu/~mbtaylor/papers/Taylor\_DAC\_BaseJump\_STL\_2018.pdf) handshakes, most likely valid->ready on the consumer side, and ready->valid on the input. The queues shall be implemented with one of the BaseJump STL queue implementations. Each block is responsible for only issuing operations (e.g., translation requests, cache access, instruction execution, etc.) if it is capable of storing any possible exception information for that operation.

### FE->BE (fe\_queue)
Description: Front End Queue (FIFO) passes bp\_fe\_queue\_s comprising a message type and the message data:
 - e_itlb_miss
 - e_instr_page_fault
 - e_instr_access_fault
 - e_icache_miss
 - e_instr_partial_lower
 - e_instr_partial_upper
 - e_instr_fetch

Interface:
- BaseJump STL valid->ready on consumer and ready->valid on producer
- The FE Queue must support a "clear" operation (to support mispredicts)

Structures:
- `bp_fe_queue_s`
  - 39-bit PC (virtual address) of the instruction to fetch
  - 32-bit instruction data (or partial fetch data in the case of an incomplete misaligned fetch)

    Invariant. Although the PC may be speculative, the value of _instruction_ is correct for that PC. We make similar assertions for the itlb -- the itlb mappings made by the FE are not speculative, and are required to be correct at all times.
  - Branch prediction metadata (`bp_fe_branch_metadata_fwd_s`)

    This structure is for the branch predictor to update its internal data structures based on feedback from the BE as to whether this particular PC/instruction pair was correct. The "forward packet" capturing this data is included in "attaboy" and "redirect" commands from the backend, which notify the frontend of a correct and incorrect prediction respectively.

    The branch prediction metadata for our current frontend implementation contains:

    - Flags indicating what type of jump triggered this prediction (branch, JAL or JALR) as well as whether it appeared to be a call or return
    - Flags noting which internal branch prediction structures (BTB or RAS) were used to make this prediction
    - The global history vector and BTB/BHT pointers from the time this prediction was made, to enable rolling back to before this jump was predicted, undoing any speculative updates, or applying new updates in response to feedback

    The BE does not look at the metadata, since this would violate our intended separation of the three components (BE,FE,ME) via a clean interface. The BE implementation must not be tightly coupled to the front end implementation. The bit pattern of the packet is blindly forwarded, and the above data is considered private to the frontend.

    Branch predictor structures are often large and critical. For efficiency, they are often implemented as hardened RAMs, for which RMW cycles are expensive. Additionally, attaboys are allowed to be speculatively sent by the BE through early branch resolution. In certain implementations, this may result in redundant attaboys. One flexible way to prevent both of these behaviors from affecting predictor accuracy or throughput is to guarantee that branch metadata updates are idempotent, and more generally that resolution direction and branch metadata together are sufficient to construct the next written predictor value.

    For example, a two-bit saturating counter BHT implementation may store the index within the table used for a prediction and the old value from that entry in the table in the `bp_fe_branch_metadata_fwd_s` struct. In the event of an attaboy, it would use the index and old value to write a "strong" prediction of the same direction as used to be present back into the source BHT slot. In the case of a redirect (misprediction), it would overwrite that entry with a "weak" prediction, with direction flipped if the old value was already weak. In this case, the writes are performed in response to the attaboy or redirect, rather than at prediction time.

  - Future possible extensions (or non-features for this version.)
    - K-bit HART ID for multithreading. For now, we hold off on this, as we generally don’t want to add interfaces we don’t support. 
    - Process ID, Address Space ID, or thread ID (is this needed?) 
    - If any of these things are actually ISA concepts, seems like the best thing is to just say that the fetch unit must be flushed to prevent co-existence of these items, eliminating the need to disambiguate between them.

  Exceptions should be serviced inline with instructions. Otherwise we have no way of knowing if this exception is eclipsed by a preceding branch mispredict. Every instruction has a PC so that field can be reused. We can carry a bit-vector along inside `bp_fe_fetch_s` to indicate these exceptions and/or other status information. FE does not receive interrupts, but may raise exceptions.

  - 39-bit virtual PC causing the exception (should be aligned with PC `bp_fe_queue_s`)
    - Specifies the PC of the illegal instruction, or the address (PC) causing exceptions.
  - Exception Code (cause)
    - In order of priority:
    - Instruction Address Misaligned
      - This has priority over a TLB miss because a itlb miss can have a side-effect, and presumably a misaligned instruction is a sign of anomalous execution.
    - itlb miss 
      - Page table walking can not occur in front end, because it writes the A bit in the page table entries; which means the instruction cache would have to support writes. Moreover, this bit is an architectural side effect, and is not allowed to be set speculatively. Only the backend can precisely commit architectural side-effects. For these reasons, itlb misses are handled by the backend.
    - This may also occur if translation is disabled. In this case, a itlb means that the physical page is not in the itlb and we don’t have the PMP/PMA information cached. The BE will not perform a page walk in this case; it will just return the PMP/PMA information.
    - Instruction access faults (i.e. permissions) must be checked by the FE because the interpretation of the L and X bits are determined by whether the system is in M mode or S and U mode. These bits will be stored in the itlb.
    - Illegal Instruction
  - Future possible extensions (or non-features for this version.)
    - Support for multiple fetch entries in a single packet. Only useful for multiple-issue BE implementations.

### BE->FE (fe\_cmd)
Description: FE Command Queue (fe\_cmd) sends the following commands from the Back End to the Front End, using a single command queue containing structures of type bp\_fe\_cmd\_s. From the perspective of architectural and microarchitectural state, enqueuing a command onto the command queue is beyond the point of no return, although the side-effects are not guaranteed until after the fence line goes high. With the exception of the attaboy commands, the BE will not enqueue additional commands until all prior commands have been processed. The FE must dequeue attaboys immediately upon reception and should process other commands as quickly as possible. However, due to the fence line it is not an invariant that the FE processes other instructions within a single cycle. The Command Queue shall transmit a union data structure, bp\_fe\_cmd\_s which contains opcodes and operands.

Interface:
- The FIFO should not need to support a clear operation (except for via a full reset), all things enqueued must be processed.
- The FIFO should have a fence wire to indicate if all items have been absorbed from the FIFO, & all commands have been processed. Depending on implementation, the fence wire may be asserted multiple cycles after the FIFO is actually empty.
- Commands that feature PC redirection or shadow state change will flush the FE Queue. The BE of the processor will wait on the FE cmd queue’s fence wire before reading new items from the FE queue or enqueing new items on the command queue.

Available commands and their payloads:
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

  A redirection indicates an incorrect prediction ("at-fault") or an exceptional change of control flow due to interrupts or architectural state changes ("no-fault"). It requests that the frontend fetch the specified instruction and continue from there. 

  - Standard operands
    - PC virtual address of the _next_ instruction to be fetched
  - Subopcodes
    - URET, SRET, MRET
      - These return from a trap and will contain the PC to return to. They set the shadow privilege mode in the FE.  This is done because the EPC is architectural state and lives in the BE, but we want to track this to avoid speculative access of state (instruction cache line) that is guarded by a protection boundary.
    - Interrupt (no-fault PC redirection)
    - Branch mispredict (at-fault PC redirection)
      - The PC is the corrected target PC, not the PC of the branch
      - `bp_fe_branch_metadata_fwd_s` as described above, containing branch prediction metadata to correct predictor state
      - Misprediction reason ("not a branch", "wrong direction")
    - Trap (at-fault PC redirection, with potential change of permissions)
    - Context switch (no-fault PC redirection to new address space; see `satp` register)
      - ASID
      - Translation enabled / disabled
    - Simple FE implementations which do not track the ASID for each TLB entry will also perform an itlb fence operation, flushing the itlb.
    - More complex FE implementations will register the new ASID and not perform an itlb fence.
- Attaboy

  An attaboy signals a _correct_ prediction to the frontend, and thus there is no PC redirection expected. The provided PC is the address of the instruction following a correctly-predicted jump. The message contains branch prediction feedback information (`bp_fe_branch_metadata_fwd_s`) which was provided by the frontend when it originally made this prediction.

- Icache fill response
  - Determines when an I$ miss becomes non-speculative
- Icache fence
  - If icache is coherent with dcache, flush the icache pipeline.
  - Else, flush the icache pipeline and the icache as well.
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

## Cache Engine Interface

The Cache Engine interface provides flexible connections between an (optionally) coherent cache and
a Cache Engine, which services misses, invalidations, coherence transactions, etc. The Cache Engine
interface supports both coherent and non-coherent caches, and can be extended to support
both blocking and non-blocking caches. The interface is latency insensitive and may be optionally
routed through a FIFO. BlackParrot provides 3 types of Cache Engines:

- Local Cache Engines (LCE), which manages structures in the cache by responding to local misses and
  remote coherence messages. LCEs are attached to caches that participate in a cache coherence
  protocol.
- Cache Coherence Engines (CCE), which maintain a distributed set of directory tags and send messages to
  maintain coherence among caches. CCEs are the cache coherence directories.
- Unified Cache Engines (UCE), which respond to cache requests by directly managing data from
  memory. In this way, a UCE is a combination of an LCE and a CCE, optimized for size and complexity
  in order to service a single cache. The UCE is used in BlackParrot's unicore configurations.

Additionally, the BlackParrot HDK provides additional cache engines for connecting to external
memory systems.

More details are provided about the LCE and CCE interface in the following section.

A UCE implementation must support the following operations:
- Engine loads, stores and amo operations
- Handle remote invalidations
- Handle both uncached and cached requests
- Support both write-through and write-back protocols
- Support credit-based flow control, to support fencing in the core

The request interface is valid->yumi and uses a parameterized struct to pass arguments,
bp_cache_req_s, which contains the following fields.
- Message type
  - Load Miss
  - Store Miss
  - Uncached Load
  - Uncached Store
  - Cache flush
  - Cache clear
  - Atomic
- Physical address
- Size (1B-64B)
- Data (For uncached stores or writethroughs)
- Hit
- Subop type (amoswap, amolr, amosc, amoadd, amoxor, amoand, amoor, amomin, amomax, amominu, amomaxu)

Additionally, the Cache Engine may require some metadata in order to service cache misses. This
metadata may not be available at the same time as the request, due to the nature of high performance
caches. The handshake here is valid-only. If a Cache Engine needs metadata in order to service the
miss, it needs to be ready to accept metadata at any cycle later than or equal to the original cache
miss. The cache is required to eventually provide this data, although not in any particular cycle.
The latency between a cache request and its metadata must be a known constant for all message types,
under all backpressure conditions. The current metadata fields are:
- Dirty
- Hit or Replacement way

The fill interface is implemented as a set of valid->yumi connections that provide read/write access
to memory structures in a typical cache. A single cache request may trigger a set of fill responses.
To decouple cache logic from any particular fill strategy, there is an additional signal which is
raised when a request is completed. The three memory structures are a data memory, tag memory,
and status memory.

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

When the critical data of a transaction is being sent, cache_req_critical_data_o will go high.
When the critical tag of a transaction is being sent, cache_req_critical_tag_o will go high.
When a transaction is completed, cache_req_complete_o will go high for one cycle.

There are additional signals for available credits in the engine, used for fencing. Empty credits
signify all downstream transactions have completed, whereas full credits signify no more
transactions may be sent to the network.

## BedRock Interface

The BlackParrot memory and cache coherence networks rely on a common message format that can
is easily specialized for the specific network interface. A BedRock message includes a
header and zero or more bytes of data.

The BlackParrot BedRock Interfaces are defined in the following files:
- [bp\_common\_bedrock\_if.svh](../bp_common/src/include/bp_common_bedrock_if.svh)
- [bp\_common\_bedrock\_pkgdef.svh](../bp_common/src/include/bp_common_bedrock_pkgdef.svh)
- [bp\_common\_bedrock\_wormhole_defines.svh](../bp_common/src/include/bp_common_bedrock_wormhole_defines.svh)

A BedRock message header is composed of:
- Message type (available types depend on the specific network)
- Subop type (store, amolr, amosc, amoswap, amoadd, amoxor, amoand, amoor, amomin, amomax, amominu, amomaxu)
- Physical address
- Message Size (1 to 128 bytes, in powers of two; specifies request size or size of attached data)
- Payload (a black-box to the command receiver, this is returned as-is along with the memory response)

A BedRock message may also include data. The amount of data is specified by the message size field
in the message header. Alignment of the message address and data is specific to the network
implementation.

### Memory and I/O Interface

The BlackParrot Memory Interface is a simple command / response interface used for communicating
with memory or I/O devices. The goal is to provide a simple and understandable way to access any
type of memory system, be it a shared bus or a more sophisticated network-on-chip scheme.
The Memory Interface can easily be transduced to standard protocols such as AXI, AXI-lite or WishBone,
and is implemented using the BedRock network interfaces.

A memory command or response packet is composed of:
- Message type
  - Read request
  - Write request
  - Uncached read request
  - Uncached write request
  - Prefetch
  - Atomic operation
- Subop type (amoswap, amolr, amosc, amoadd, amoxor, amoand, amoor, amomin, amomax, amominu, amomaxu)
- Physical address
- Message/Request Size
- Payload (A black-box to the command receiver, this is returned as-is along with the memory response)
  - An example payload for the CCE is:
  - Requesting LCE
  - Requesting way id
  - Coherence state
  - Whether this is a speculative request
- Data (for memory write or uncached write operations)

Uncached accesses must be naturally aligned with the request size. Cached accesses are block-based
and return the cache block containing the requested address. Cached accesses return the critical
data word first (at LSB of data) and wrap around the requested block as follows:

- Request: 0x00, size=32B [D C B A]
- Request: 0x10, size=32B [B A D C]

### LCE-CCE Interface

The LCE-CCE Interface comprises the connections between the BlackParrot caches and coherence
directories in a cache-coherent BlackParrot multicore processor. These networks support the
BlackParrot BedRock coherence protocol implementation and utilize the common BedRock message
format described above. A full description of the LCE-CCE Interface and its implementation
can be found in the [BedRock Cache Coherence and Memory System Guide](bedrock_guide.md).

