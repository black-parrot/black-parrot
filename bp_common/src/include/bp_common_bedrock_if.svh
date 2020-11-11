/**
 * bp_common_bedrock_if.svh
 *
 * This file defines the BedRock interface for BlackParrot, which is used to implement the
 * coherence system between the CCEs and LCEs in BlackParrot and the networks between
 * the CCE and Memory.
 *
 * The interface is defined as a set of parameterized structs.
 *
 * Users should use the declare_bp_bedrock_[lce/mem]_if and declare_bp_bedrock_[lce/mem]_if_widths
 * macros to declare all of the widths and interface structs as needed for the LCE-CCE and MEM-CCE
 * channels.
 *
 */

`ifndef BP_COMMON_BEDROCK_IF_VH
`define BP_COMMON_BEDROCK_IF_VH

`include "bsg_defines.v"

/*
 *
 * BedRock Interface
 *
 * The following enums and structs define the BedRock Interface within a BlackParrot coherence
 * system.
 *
 * There are 4 message classes:
 * 1. Request
 * 2. Response
 * 3. Command
 * 4. Memory (Command and Response)
 *
 * The three LCE-CCE message types are carried on three physical networks:
 * 1. Request (low priority)
 * 2. Command (medium priority)
 * 3. Response (high priority)
 *
 * A Request message may cause a Command message, and a Command message may cause a Response.
 * A higher priority message may not cause a lower priority message to be sent, which avoids
 * a circular dependency between message classes, and prevents certain instances of deadlock.
 *
 * The two memory networks (Command and Response) are carried on two physical networks between
 * the UCE/CCE and Memory.
 *
 */


/*
 * bp_bedrock_***_msg_s is the generic message struct for BedRock messages
 *
 * msg_type is a union of the LCE-CCE Req, Cmd, and Resp message types and the Mem messages
 * addr is the address used by the message
 * size indicates the size in bytes of the message using the bp_bedrock_msg_size_e enum
 * payload is an opaque field to the network, that is network specific (Req, Cmd, Resp, Mem)
 *   and each endpoint will interpret the field as appropriate
 *
 */
`define declare_bp_bedrock_msg_s(addr_width_mp, payload_width_mp, data_width_mp, name_mp) \
  typedef struct packed                                                                   \
  {                                                                                       \
    logic [payload_width_mp-1:0]                 payload;                                 \
    bp_bedrock_msg_size_e                        size;                                    \
    logic [addr_width_mp-1:0]                    addr;                                    \
    bp_bedrock_msg_u                             msg_type;                                \
  } bp_bedrock_``name_mp``_msg_header_s;                                                  \
                                                                                          \
  typedef struct packed                                                                   \
  {                                                                                       \
    logic [data_width_mp-1:0]                    data;                                    \
    bp_bedrock_``name_mp``_msg_header_s          header;                                  \
  } bp_bedrock_``name_mp``_msg_s;                                                         \

/*
 * bp_bedrock_***_payload_s defines the payload for the various BedRock protocol channels
 *
 * Mem Payload:
 * lce_id is the LCE that sent the initial request to the CCE
 * way_id is the way within the cache miss address target set to fill the data in to
 * state is the fill coherence state (may be changed if request was speculative)
 * prefetch is set if the request was a prefetch from LCE (as opposed to CCE)
 * uncached is set if the request was an uncached request from LCE
 * speculative is set if the request was issued speculatively by the CCE
 */


`define declare_bp_bedrock_lce_payload_s(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp, name_mp) \
                                                                                     \
  typedef struct packed                                                              \
  {                                                                                  \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    lru_way_id;                         \
    bp_bedrock_req_non_excl_e                    non_exclusive;                      \
    logic [lce_id_width_mp-1:0]                  src_id;                             \
    logic [cce_id_width_mp-1:0]                  dst_id;                             \
  } bp_bedrock_``name_mp``_req_payload_s;                                            \
                                                                                     \
  typedef struct packed                                                              \
  {                                                                                  \
    bp_coh_states_e                              target_state;                       \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    target_way_id;                      \
    logic [lce_id_width_mp-1:0]                  target;                             \
    bp_coh_states_e                              state;                              \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;                             \
    logic [cce_id_width_mp-1:0]                  src_id;                             \
    logic [lce_id_width_mp-1:0]                  dst_id;                             \
  } bp_bedrock_``name_mp``_cmd_payload_s;                                            \
                                                                                     \
  typedef struct packed                                                              \
  {                                                                                  \
    logic [lce_id_width_mp-1:0]                  src_id;                             \
    logic [cce_id_width_mp-1:0]                  dst_id;                             \
  } bp_bedrock_``name_mp``_resp_payload_s;                                           \

`define declare_bp_bedrock_mem_payload_s(lce_id_width_mp, lce_assoc_mp, name_mp)     \
                                                                                     \
  typedef struct packed                                                              \
  {                                                                                  \
    bp_coh_states_e                              state;                              \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;                             \
    logic [lce_id_width_mp-1:0]                  lce_id;                             \
    logic                                        prefetch;                           \
    logic                                        uncached;                           \
    logic                                        speculative;                        \
  } bp_bedrock_``name_mp``_mem_payload_s;


/*
 * BedRock Interface Enum Definitions
 *
 * These enums define the options for fields of the BedRock Interface messages. Clients should use
 * the enums to set and compare fields of messages, rather than examining the bit pattern directly.
 */

/*
 * bp_bedrock_msg_size_e specifies the amount of data in the message, after the header
 */
typedef enum logic [2:0]
{
  e_bedrock_msg_size_1     = 3'b000  // 1 byte
  ,e_bedrock_msg_size_2    = 3'b001  // 2 bytes
  ,e_bedrock_msg_size_4    = 3'b010  // 4 bytes
  ,e_bedrock_msg_size_8    = 3'b011  // 8 bytes
  ,e_bedrock_msg_size_16   = 3'b100  // 16 bytes
  ,e_bedrock_msg_size_32   = 3'b101  // 32 bytes
  ,e_bedrock_msg_size_64   = 3'b110  // 64 bytes
  ,e_bedrock_msg_size_128  = 3'b111  // 128 bytes
} bp_bedrock_msg_size_e;

/*
 * bp_bedrock_mem_type_e specifies the memory command from the UCE/CCE
 *
 * There are three types of commands:
 * 1. Access to memory that should be cached in L2/LLC (rd/wr)
 * 2. Access to memory that should remain uncached by L2/LLC (uc_rd/uc_wr)
 * 3. Prefetch access to memory that should be cached in L2/LLC (pre)
 *
 * Cacheability of the data at the L1/LCE level is determined by the uncached bit within
 * the payload of the message, and is managed by the LCE/CCE. This information is not
 * exposed to memory/L2/LLC, allowing the CCE to maintain coherence for all required
 * blocks.
 *
 */
typedef enum logic [3:0]
{
  e_bedrock_mem_rd       = 4'b0000  // Cache block fetch / load / Get (cached in L2/LLC)
  ,e_bedrock_mem_wr      = 4'b0001  // Cache block write / writeback / store / Put (cached in L2/LLC)
  ,e_bedrock_mem_uc_rd   = 4'b0010  // Uncached load (uncached in L2/LLC)
  ,e_bedrock_mem_uc_wr   = 4'b0011  // Uncached store (uncached in L2/LLC)
  ,e_bedrock_mem_pre     = 4'b0100  // Pre-fetch block request from CCE, fill into L2/LLC if able
  // 4'b0101 - 4'b1111 reserved // custom
} bp_bedrock_mem_type_e;

/*
 * bp_bedrock_req_type_e specifies whether the containing message is related to a read or write
 * cache miss request from and LCE.
 */
typedef enum logic [3:0]
{
  e_bedrock_req_rd         = 4'b0000 // Read-miss
  ,e_bedrock_req_wr        = 4'b0001 // Write-miss
  ,e_bedrock_req_uc_rd     = 4'b0010 // Uncached Read-miss
  ,e_bedrock_req_uc_wr     = 4'b0011 // Uncached Write-miss
  // 4'b0100 - 4'b1111 reserved / custom
} bp_bedrock_req_type_e;

/*
 * bp_bedrock_cmd_type_e defines the various commands that an CCE may issue to an LCE
 * e_bedrock_cmd_sync is used at the end of reset to direct the LCE to inform the CCE it is ready
 * e_bedrock_cmd_set_clear is sent by the CCE to invalidate an entire cache set in the LCE
 */
typedef enum logic [3:0]
{
  e_bedrock_cmd_sync             = 4'b0000 // sync/ready, respond with sync_ack
  ,e_bedrock_cmd_set_clear       = 4'b0001 // clear cache set of address field
  ,e_bedrock_cmd_inv             = 4'b0010 // invalidate block, respond with inv_ack
  ,e_bedrock_cmd_st              = 4'b0011 // set state
  ,e_bedrock_cmd_data            = 4'b0100 // data, adddress, and state to LCE, i.e., cache block fill
  ,e_bedrock_cmd_st_wakeup       = 4'b0101 // set state and wakeup
  ,e_bedrock_cmd_wb              = 4'b0110 // writeback block
  ,e_bedrock_cmd_st_wb           = 4'b0111 // set state and writeback block
  ,e_bedrock_cmd_tr              = 4'b1000 // transfer block
  ,e_bedrock_cmd_st_tr           = 4'b1001 // set state and transfer block
  ,e_bedrock_cmd_st_tr_wb        = 4'b1010 // set state, transfer, and writeback block
  ,e_bedrock_cmd_uc_data         = 4'b1011 // uncached data to LCE
  ,e_bedrock_cmd_uc_st_done      = 4'b1100 // uncached store complete
  // 4'b1101 - 4'b1111 reserved / custom
} bp_bedrock_cmd_type_e;

/* bp_bedrock_resp_type_e defines the different LCE-CCE response messages
 * e_bedrock_resp_sync_ack acknowledges receipt and processing of a Sync command
 * e_bedrock_resp_inv_ack acknowledges that an LCE has processed an Invalidation command
 * e_bedrock_resp_coh_ack acknowledges than an LCE has received both a set tag command AND a data
 *   command, or a set tag and wakeup command from the CCE. The sending LCE considers itself woken
 *   up after sending this ACK.
 * e_bedrock_resp_wb indicates the data field (cache block data) is valid, and that the LCE ahd the
 *   cache block in a dirty state
 * e_bedrock_resp_null_wb indicates that the LCE never wrote to the cache block and the block is still
 *   clean. The data field should be 0 and is invalid.
 */
typedef enum logic [3:0]
{
  e_bedrock_resp_sync_ack    = 4'b0000
  ,e_bedrock_resp_inv_ack    = 4'b0001
  ,e_bedrock_resp_coh_ack    = 4'b0010
  ,e_bedrock_resp_wb         = 4'b0011  // Normal Writeback Response (full data)
  ,e_bedrock_resp_null_wb    = 4'b0100  // Null Writeback Response (no data)
  // 4'b0101 - 4'b1111 reserved / custom
} bp_bedrock_resp_type_e;

/*
 * bp_bedrock_msg_u is a union that holds the LCE-CCE Req, Cmd, and Resp message types
 */
typedef union packed {
  bp_bedrock_req_type_e    req;
  bp_bedrock_cmd_type_e    cmd;
  bp_bedrock_resp_type_e   resp;
  bp_bedrock_mem_type_e    mem;
} bp_bedrock_msg_u;

/*
 * bp_bedrock_req_non_excl_e specifies whether the requesting LCE would like a read-miss request
 * to be returned in an exclusive coherence state if possible or not. An I$, for example, should
 * set this bit to indicate that there is no benefit in the CCE granting a cache block in the E
 * state as opposed to the S state in a MESI protocol. The CCE treats this bit as a hint, and is
 * not required to follow it.
 */
typedef enum logic
{
  e_bedrock_req_excl            = 1'b0 // exclusive cache line request (read-only, exclusive request)
  ,e_bedrock_req_non_excl       = 1'b1 // non-exclusive cache line request (read-only, shared request)
} bp_bedrock_req_non_excl_e;

/*
 * bp_cce_coh_states_e defines the coherence states available in BlackParrot. Each bit represents
 * a property of the cache block as defined below:
 * 0: Shared (not Exclusive)
 * 1: Owned
 * 2: Potentially Dirty
 *
 * These properties are derived from "A Primer on Memory Consistency and Cache Coherence", and
 * they allow an easy definition for the common MOESIF coherence states.
 */
typedef enum logic [2:0]
{
  e_COH_I                   = 3'b000 // Invalid
  ,e_COH_S                  = 3'b001 // Shared - clean, not owned, shared (not exclusive)
  ,e_COH_E                  = 3'b010 // Exclusive - clean, owned, not shared (exclusive)
  ,e_COH_F                  = 3'b011 // Forward - clean, owned, shared (not exclusive)
  // unused                 = 3'b100 // potentially dirty, not owned, not shared (exclusive)
  // unused                 = 3'b101 // potentially dirty, not owned, shared (not exclusive)
  ,e_COH_M                  = 3'b110 // Modified - potentially dirty, owned, not shared (exclusive)
  ,e_COH_O                  = 3'b111 // Owned - potentially dirty, owned, shared (not exclusive)
} bp_coh_states_e;

`define bp_coh_shared_bit 0
`define bp_coh_owned_bit 1
`define bp_coh_dirty_bit 2


/*
 * BedRock Payload width macros
 *
 * Users should not need to call these directly and can instead use the BedRock Interface Macros
 * that are defined further below.
 */

`define bp_bedrock_req_payload_width(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp) \
  (cce_id_width_mp+lce_id_width_mp+$bits(bp_bedrock_req_non_excl_e)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_bedrock_cmd_payload_width(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp) \
  ((2*lce_id_width_mp)+cce_id_width_mp+(2*`BSG_SAFE_CLOG2(lce_assoc_mp))+(2*$bits(bp_coh_states_e)))

`define bp_bedrock_resp_payload_width(lce_id_width_mp, cce_id_width_mp) \
  (cce_id_width_mp+lce_id_width_mp)

`define bp_bedrock_mem_payload_width(lce_id_width_mp, lce_assoc_mp) \
  (3+lce_id_width_mp+`BSG_SAFE_CLOG2(lce_assoc_mp)+$bits(bp_coh_states_e))

`define declare_bp_bedrock_lce_payload_widths(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp, name_mp) \
  , localparam ``name_mp``_req_payload_width_lp = `bp_bedrock_req_payload_width(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp) \
  , localparam ``name_mp``_cmd_payload_width_lp = `bp_bedrock_cmd_payload_width(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp) \
  , localparam ``name_mp``_resp_payload_width_lp = `bp_bedrock_resp_payload_width(lce_id_width_mp, cce_id_width_mp)

`define declare_bp_bedrock_mem_payload_width(lce_id_width_mp, lce_assoc_mp, name_mp) \
  , localparam ``name_mp``_mem_payload_width_lp = `bp_bedrock_mem_payload_width(lce_id_width_mp, lce_assoc_mp)

/*
 * BedRock Message width macros
 *
 * Users should not need to call these directly and can instead use the BedRock Interface Macros
 * that are defined further below.
 */

`define bp_bedrock_msg_header_width(addr_width_mp, payload_width_mp) \
  ($bits(bp_bedrock_msg_u)+addr_width_mp+$bits(bp_bedrock_msg_size_e)+payload_width_mp)

`define bp_bedrock_msg_width(addr_width_mp, payload_width_mp, data_width_mp) \
  (`bp_bedrock_msg_header_width(addr_width_mp, payload_width_mp)+data_width_mp)

`define declare_bp_bedrock_msg_header_width(addr_width_mp, payload_width_mp, name_mp) \
  , localparam ``name_mp``_msg_header_width_lp = `bp_bedrock_msg_header_width(addr_width_mp, payload_width_mp)

`define declare_bp_bedrock_msg_width(addr_width_mp, payload_width_mp, data_width_mp, name_mp) \
  , localparam ``name_mp``_msg_width_lp = `bp_bedrock_msg_width(addr_width_mp, payload_width_mp, data_width_mp)

/*
 * BedRock Interface Macros
 */

`define declare_bp_bedrock_lce_if_widths(addr_width_mp, data_width_mp, lce_id_width_mp, cce_id_width_mp, lce_assoc_mp, name_mp) \
  `declare_bp_bedrock_lce_payload_widths(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp, name_mp)                               \
  `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_req_payload_width_lp, ``name_mp``_req)             \
  `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_cmd_payload_width_lp, ``name_mp``_cmd)             \
  `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_resp_payload_width_lp, ``name_mp``_resp)           \
  `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_req_payload_width_lp, data_width_mp, ``name_mp``_req)     \
  `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_cmd_payload_width_lp, data_width_mp, ``name_mp``_cmd)     \
  `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_resp_payload_width_lp, data_width_mp, ``name_mp``_resp)

`define declare_bp_bedrock_lce_if(addr_width_mp, data_width_mp, lce_id_width_mp, cce_id_width_mp, lce_assoc_mp, name_mp) \
  `declare_bp_bedrock_lce_payload_s(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp, name_mp);                            \
  `declare_bp_bedrock_msg_s(addr_width_mp, ``name_mp``_req_payload_width_lp, data_width_mp, ``name_mp``_req); \
  `declare_bp_bedrock_msg_s(addr_width_mp, ``name_mp``_cmd_payload_width_lp, data_width_mp, ``name_mp``_cmd); \
  `declare_bp_bedrock_msg_s(addr_width_mp, ``name_mp``_resp_payload_width_lp, data_width_mp, ``name_mp``_resp);

`define declare_bp_bedrock_mem_if_widths(addr_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp)       \
  `declare_bp_bedrock_mem_payload_width(lce_id_width_mp, lce_assoc_mp, name_mp)                                      \
  `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_mem_payload_width_lp, ``name_mp``_mem)             \
  `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_mem_payload_width_lp, data_width_mp, ``name_mp``_mem)

`define declare_bp_bedrock_if_widths(addr_width_mp, payload_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp) \
  , localparam ``name_mp``_msg_payload_width_lp = payload_width_mp                                                           \
  `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_msg_payload_width_lp, ``name_mp``)                         \
  `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_msg_payload_width_lp, data_width_mp, ``name_mp``)

`define declare_bp_bedrock_mem_if(addr_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp) \
  `declare_bp_bedrock_mem_payload_s(lce_id_width_mp, lce_assoc_mp, name_mp);                            \
  `declare_bp_bedrock_msg_s(addr_width_mp, ``name_mp``_mem_payload_width_lp, data_width_mp, ``name_mp``_mem);

`define declare_bp_bedrock_if(addr_width_mp, payload_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp) \
  `declare_bp_bedrock_msg_s(addr_width_mp, payload_width_mp, data_width_mp, ``name_mp``);

`endif // BP_COMMON_BEDROCK_IF_VH
