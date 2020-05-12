/**
 * bp_common_me_if.vh
 *
 * This file defines the interface between the CCEs and LCEs in the BlackParrot coherence system.
 * The interface is defined as a set of parameterized structs.
 *
 */

`ifndef BP_COMMON_ME_IF_VH
`define BP_COMMON_ME_IF_VH

`include "bsg_defines.v"

/*
 *
 * LCE-CCE Interface
 *
 * The following enums and structs define the LCE-CCE Interface within a BlackParrot coherence
 * system.
 *
 * There are 3 message classes:
 * 1. LCE Request
 * 2. LCE Response
 * 3. LCE Command
 *
 * These three message types are carried on three physical networks:
 * 1. Request (low priority)
 * 2. Command (medium priority)
 * 3. Response (high priority)
 *
 * A Request message may cause a Command message, and a Command message may cause a Response.
 * A higher priority message may not cause a lower priority message to be sent, which avoids
 * a circular dependency between message classes, and prevents certain instances of deadlock.
 *
 * Users should use the declare_bp_lce_cce_if macro to declare all of the interface structs
 * at once. The declare_*_widths macros can be used to declare needed packet and header
 * widths in module parameter lists.
 *
 */

/*
 * 
 * LCE-CCE Interface Macro
 *
 * This macro defines all of the lce-cce interface stucts and port widths at once as localparams
 *
 */

`define declare_bp_lce_cce_if(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp, data_width_mp, cce_block_width_mp) \
                                                                                                         \
/*                                                                                                       \
 * bp_lce_cce_req_s defines an LCE request sent by an LCE to a CCE on a cache miss. An LCE enters        \
 *   a Stall state after sending a request, and it may not send another request until it is              \
 *   "woken up" by a Set Tag and Wakeup command from the CCE or after receiving a Set Tag command        \
 *   from a CCE and either a Write Data command from a CCE or an LCE to LCE Transfer from an LCE.        \
 * dst_id is the CCE responsible for the cache missing address                                           \
 * src_id is the requesting LCE                                                                          \
 * msg_type indicates if this is a read or write miss request                                            \
 * non_exclusive indicates if the requesting cache prefers non-exclusive read-access                     \
 * addr is the cache missing address                                                                     \
 * lru_way_id indicates the way within the target set that will be used to fill the miss in to           \
 */                                                                                                      \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    lru_way_id;                                             \
    bp_lce_cce_req_non_excl_e                    non_exclusive;                                          \
    logic [paddr_width_mp-1:0]                   addr;                                                   \
    logic [lce_id_width_mp-1:0]                  src_id;                                                 \
    bp_mem_msg_size_e                            size;                                                   \
    bp_lce_cce_req_type_e                        msg_type;                                               \
    logic [cce_id_width_mp-1:0]                  dst_id;                                                 \
  } bp_lce_cce_req_header_s;                                                                             \
                                                                                                         \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [data_width_mp-1:0]                    data;                                                   \
    bp_lce_cce_req_header_s                      header;                                                 \
  } bp_lce_cce_req_s;                                                                                    \
                                                                                                         \
/**                                                                                                      \
 *  bp_lce_cmd_s is the generic message for LCE Command and LCE Data Command that is sent across the     \
 *  Command network from CCE to LCE.                                                                     \
 *  Although not required, It is designed to be sent through a wormhole routed network that will send    \
 *  the minimum number of flits required, based on the size field.                                       \
 */                                                                                                      \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    bp_coh_states_e                              target_state;                                           \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    target_way_id;                                          \
    logic [lce_id_width_mp-1:0]                  target;                                                 \
    bp_coh_states_e                              state;                                                  \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;                                                 \
    logic [paddr_width_mp-1:0]                   addr;                                                   \
    logic [cce_id_width_mp-1:0]                  src_id;                                                 \
    bp_mem_msg_size_e                            size;                                                   \
    bp_lce_cmd_type_e                            msg_type;                                               \
    logic [lce_id_width_mp-1:0]                  dst_id;                                                 \
  } bp_lce_cmd_header_s;                                                                                 \
                                                                                                         \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [cce_block_width_mp-1:0]               data;                                                   \
    bp_lce_cmd_header_s                          header;                                                 \
  } bp_lce_cmd_s;                                                                                        \
                                                                                                         \
/**                                                                                                      \
 *  bp_lce_cce_resp_s is the generic message for LCE Response and LCE Data Response messages on the      \
 *  Response network from LCE to CCE. The data field is only used for Data Response messages.            \
 */                                                                                                      \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [paddr_width_mp-1:0]                   addr;                                                   \
    logic [lce_id_width_mp-1:0]                  src_id;                                                 \
    bp_mem_msg_size_e                            size;                                                   \
    bp_lce_cce_resp_type_e                       msg_type;                                               \
    logic [cce_id_width_mp-1:0]                  dst_id;                                                 \
  } bp_lce_cce_resp_header_s;                                                                            \
                                                                                                         \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [cce_block_width_mp-1:0]               data;                                                   \
    bp_lce_cce_resp_header_s                     header;                                                 \
  } bp_lce_cce_resp_s;                                                                                   \


/*
 * LCE-CCE Interface Enums
 *
 * These enums define the options for fields of the LCE-CCE Interface messages. Clients should use
 * the enums to set and compare fields of messages, rather than examining the bit pattern directly.
 */

/*
 * bp_mem_msg_size_e specifies the size, in bytes, of the request or data field
 * Request messages use the size field to specify the request size in bytes.
 * Command messages use the size field to specify the amount of valid data following the header.
 * Response messages use the size field to specify the amount of valid data following the header.
 */
typedef enum logic [2:0]
{
  e_mem_msg_size_1     = 3'b000  // 1 byte
  ,e_mem_msg_size_2    = 3'b001  // 2 bytes
  ,e_mem_msg_size_4    = 3'b010  // 4 bytes
  ,e_mem_msg_size_8    = 3'b011  // 8 bytes
  ,e_mem_msg_size_16   = 3'b100  // 16 bytes
  ,e_mem_msg_size_32   = 3'b101  // 32 bytes
  ,e_mem_msg_size_64   = 3'b110  // 64 bytes
  ,e_mem_msg_size_128  = 3'b111  // 128 bytes
} bp_mem_msg_size_e;

/*
 * bp_lce_cce_req_type_e specifies whether the containing message is related to a read or write
 * cache miss request from and LCE.
 */
typedef enum logic [2:0]
{
  e_lce_req_type_rd         = 3'b000 // Read-miss
  ,e_lce_req_type_wr        = 3'b001 // Write-miss
  ,e_lce_req_type_uc_rd     = 3'b010 // Uncached Read-miss
  ,e_lce_req_type_uc_wr     = 3'b011 // Uncached Write-miss
  // 3'b100 - 3'b111 reserved / custom
} bp_lce_cce_req_type_e;


/*
 * bp_lce_cce_req_non_excl_e specifies whether the requesting LCE would like a read-miss request
 * to be returned in an exclusive coherence state if possible or not. An I$, for example, should
 * set this bit to indicate that there is no benefit in the CCE granting a cache block in the E
 * state as opposed to the S state in a MESI protocol. The CCE treats this bit as a hint, and is
 * not required to follow it.
 */
typedef enum logic 
{
  e_lce_req_excl            = 1'b0 // exclusive cache line request (read-only, exclusive request)
  ,e_lce_req_non_excl       = 1'b1 // non-exclusive cache line request (read-only, shared request)
} bp_lce_cce_req_non_excl_e;

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
 * bp_cce_lce_cmd_type_e defines the various commands that an CCE may issue to an LCE
 * e_lce_cmd_sync is used at the end of reset to direct the LCE to inform the CCE it is ready
 * e_lce_cmd_set_clear is sent by the CCE to invalidate an entire cache set in the LCE
 */
typedef enum logic [3:0] 
{
  e_lce_cmd_sync             = 4'b0000 // sync/ready, respond with sync_ack
  ,e_lce_cmd_set_clear       = 4'b0001 // clear cache set of address field
  ,e_lce_cmd_inv             = 4'b0010 // invalidate block, respond with inv_ack
  ,e_lce_cmd_st              = 4'b0011 // set state
  ,e_lce_cmd_data            = 4'b0100 // data, adddress, and state to LCE, i.e., cache block fill
  ,e_lce_cmd_st_wakeup       = 4'b0101 // set state and wakeup
  ,e_lce_cmd_wb              = 4'b0110 // writeback block
  ,e_lce_cmd_st_wb           = 4'b0111 // set state and writeback block
  ,e_lce_cmd_tr              = 4'b1000 // transfer block
  ,e_lce_cmd_st_tr           = 4'b1001 // set state and transfer block
  ,e_lce_cmd_st_tr_wb        = 4'b1010 // set state, transfer, and writeback block
  ,e_lce_cmd_uc_data         = 4'b1011 // unached data to LCE, i.e, up to 64-bits data
  ,e_lce_cmd_uc_st_done      = 4'b1100 // uncached store complete
  // 4'b1101 - 4'b1111 reserved / custom
} bp_lce_cmd_type_e;

/* bp_lce_cce_resp_type_e defines the different LCE-CCE response messages
 * e_lce_cce_sync_ack acknowledges receipt and processing of a Sync command
 * e_lce_cce_inv_ack acknowledges that an LCE has processed an Invalidation command
 * e_lce_cce_coh_ack acknowledges than an LCE has received both a set tag command AND a data
 *   command, or a set tag and wakeup command from the CCE. The sending LCE considers itself woken
 *   up after sending this ACK.
 * e_lce_resp_wb indicates the data field (cache block data) is valid, and that the LCE ahd the
 *   cache block in a dirty state
 * e_lce_resp_null_wb indicates that the LCE never wrote to the cache block and the block is still
 *   clean. The data field should be 0 and is invalid.
 */
typedef enum logic [2:0] 
{
  e_lce_cce_sync_ack         = 3'b000
  ,e_lce_cce_inv_ack         = 3'b001
  ,e_lce_cce_coh_ack         = 3'b010
  ,e_lce_cce_resp_wb         = 3'b011  // Normal Writeback Response (full data)
  ,e_lce_cce_resp_null_wb    = 3'b100  // Null Writeback Response (no data)
  // 3'b101 - 3'b111 reserved / custom
} bp_lce_cce_resp_type_e;

/*
 * Width macros for headers. Users should not need to call these directly. Instead, use the message
 * width macros defined further below.
 */

`define bp_lce_cce_req_header_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp) \
  (cce_id_width_mp+$bits(bp_lce_cce_req_type_e)+$bits(bp_mem_msg_size_e)+lce_id_width_mp        \
   +paddr_width_mp+$bits(bp_lce_cce_req_non_excl_e)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_lce_cmd_header_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp)     \
  (cce_id_width_mp+$bits(bp_lce_cmd_type_e)+$bits(bp_mem_msg_size_e)+lce_id_width_mp            \
   +paddr_width_mp+(2*`BSG_SAFE_CLOG2(lce_assoc_mp))+(2*$bits(bp_coh_states_e))+lce_id_width_mp)

`define bp_lce_cce_resp_header_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp)              \
  (cce_id_width_mp+$bits(bp_lce_cce_resp_type_e)+$bits(bp_mem_msg_size_e)+lce_id_width_mp       \
   +paddr_width_mp)

`define declare_bp_lce_cce_if_header_widths(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp)                               \
    , localparam lce_cce_req_header_width_lp=`bp_lce_cce_req_header_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp) \
    , localparam lce_cmd_header_width_lp=`bp_lce_cmd_header_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp)         \
    , localparam lce_cce_resp_header_width_lp=`bp_lce_cce_resp_header_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp)

/*
 * Width macros for LCE-CCE Message Networks
 */

`define bp_lce_cce_req_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp, data_width_mp) \
  (`bp_lce_cce_req_header_width(cce_id_width_mp,lce_id_width_mp,paddr_width_mp,lce_assoc_mp)+data_width_mp)

`define bp_lce_cmd_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp, cce_block_width_mp) \
  (`bp_lce_cmd_header_width(cce_id_width_mp,lce_id_width_mp,paddr_width_mp,lce_assoc_mp)+cce_block_width_mp)

`define bp_lce_cce_resp_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, cce_block_width_mp) \
  (`bp_lce_cce_resp_header_width(cce_id_width_mp,lce_id_width_mp,paddr_width_mp)+cce_block_width_mp)

`define declare_bp_lce_cce_if_widths(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp, data_width_mp, cce_block_width_mp)    \
    , localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp, data_width_mp) \
    , localparam lce_cmd_width_lp=`bp_lce_cmd_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, lce_assoc_mp, cce_block_width_mp)    \
    , localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(cce_id_width_mp, lce_id_width_mp, paddr_width_mp, cce_block_width_mp)

`endif
