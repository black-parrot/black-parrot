# BedRock - Network Specification

The BedRock Network Specification defines the on-chip networks used by the cache coherence
and memory system in the BlackParrot system. The cache coherence system keeps the data and
instruction caches of core coherent with eachother for shared-memory multicore designs. The protocols
also support integration of cache coherent accelerators.

The BedRock Interface is defined in [bp\_common\_bedrock\_if.svh](../bp_common/src/include/bp_common_bedrock_if.svh)
and [bp\_common\_bedrock\_pkgdef.svh](../bp_common/src/include/bp_common_bedrock_pkgdef.svh).
These files are the authoritative definitions for the interface in the event that this
document and the code are out-of-sync.

BedRock defines a common message format that is specialized to support both the on-chip
cache coherence system and the memory interface networks from a BlackParrot processor to memory.
The protocol can be easily transduced to standard protocols such as AXI, AXI-Lite, or WishBone.
BedRock messages are designed for use as a latency-insensitive interface. Although a particular
handshake is not required, ready&valid handshaking should be used whenever possible.

## BedRock Message Format

A BedRock message has the following fields:
- Message type
- Write Subop type (store, amoswap, amolr, amosc, amoadd, amoxor, amoand, amoor, amomin, amomax, amominu, amomaxu)
- Physical address
- Message Size
- Payload
- Data

The message type is a network specific message type. The write subop type specifies the type of\
write or atomic operation, which is required for those operations. The physical address is the
address of the requested data, aligned according to the message size field.
The message size field specifies the size of request or accompanying data as log2(size) bytes.
The payload is a network specific field used to communicate additional information between sender
and receiver, or used by the sender to attach information to the message that should be returned
unmodified by the receiver in the response. The data field contains (1 << message size) bytes for
messages that contain valid data.

## BedRock Protocols

BedRock defines three closely related protocols: Stream, Lite, and Burst. Each protocol carries
the same message information. They differ only in the specific header and data signals used
for protocol communication.

All three protocols support critical word first behavior, where a request for a specific word
in a cache or memory block is returned in the least-significant bits of the response message.
The critical data is provided first with the remaining words provided in sequential ordering,
wrapping around as required. THe following example requests illustrate this behavior:

Request: 0x0 [d c b a]<br>
Request: 0x2 [b a d c]

## BedRock Stream

The BedRock Stream protocol comprises the following signals:

* Header
* Data (64\*-bits)
* Valid
* Ready\_and
* Last

Each message is sent as one or more header plus data beats using a shared ready&valid handshake.
The last signal is raised with valid when the sender is transmitting the last header plus data beat.
The data field is typically 64-bits, but may be any 512/N-bits wide that is at least 64-bits.

When sending multiple beat messages, the sender must increment the address in the header by
data-width bits for each beat. Critical-word first behavior is easily supported by issuing the
first beat for the critical word, followed by successive data words in sequential order with wrap
around (e.g., [1, 0, 3, 2], left to right MSB to LSB, LSB arrives first). If the requested data size
is smaller than the data channel size,
the requested data is repeated to fill the channel. For example the data response for a 16-bit
request using a 64-bit channel for some data value A has a 64-bit data response of [A, A, A, A].

## BedRock Lite

BedRock Lite is a wide variant of BedRock Stream. BedRock Lite does not use the Last signal as
every message is a single header plus data beat. The data channel width is equal to the cache or
memory block width used by the sender and receiver. Critical word first is supported by the sender
issuing the request with the desired address and the receiver responding with memory block rotated
so the critical word is placed in the least significant bits.

Requests for data that smaller than the data channel width result in responses where the returned
data is replicated to fill the data channel width.

## BedRock Burst

BedRock Burst is similar to BedRock Stream, but sends only a single header message followed by
zero or more data beats. The BedRock Burst protocol has the following signals:

* Header
* Header\_valid
* Header\_ready\_and
* Has\_data
* Data (64\*-bits)
* Data\_valid
* Data\_ready\_and
* Last

In this protocol, the header and data channels have independent ready&valid handshakes. The header
is accompanied by a has\_data signal that is raised if the message has at least one data beats.
The data channel is accompanied by a last signal that is raised with data\_valid on the last data
beat. As with BedRock Stream, the data channel may is typically 64-bits wide, but may be any
512/N-bits wide that is at least 64-bits.

The sender contract is:
* May not wait for both header\_ready\_and and data\_ready\_and before sending header
* May wait for header\_ready\_and before starting a transaction
* May send data before header, but is not required to
* A minimal implementation may send header before data. More sophisticated implementations may
support sending data with or before header.

The receiver contract is:
* May not wait for both header\_valid and data\_valid before processing an incoming message
* May wait for header\_valid before processing an incoming message
* May consume data before header, but is not required to
* A minimal implementation may consume header before data. More sophisticated implementations may
consume data before or with header.

Sophisticated implementations of BedRock Burst channels may support overlapping transactions where
the sender may send a second header prior to sending all data associated with the first header.
The receiver must also support receiving additional headers prior to all data from prior transactions,
but is not required to support this feature. A sender or receiver that supports these features
will still be compatible with receivers/senders that support only the minimal contracts defined
above.

As with BedRock Stream, requests for data smaller than the data channel width result in a response
with data replicated to fill the data channel width.

