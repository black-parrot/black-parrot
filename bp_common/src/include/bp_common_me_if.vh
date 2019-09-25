/**
 * bp_common_me_if.vh
 *
 * This file defines the interface between the CCEs and LCEs, and the CCEs and memory in the
 * BlackParrot coherence system. For ease of reuse and flexiblity, this interface is defined as a
 * collection of parameterized structs.
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
 * There are 5 logical networks/message types:
 * 1. LCE Request
 * 2. LCE Response
 * 3. LCE Data Response
 * 4. LCE Command
 * 5. LCE Data Command
 *
 * These five logical message types are carried on three networks:
 * 1. Request (low priority)
 * 2. Command (medium priority), LCE Commands and Data Commands
 * 3. Response (high priority), LCE Responses and Data Responses
 *
 * A Request message may cause a Command message, and a Command message may cause a Response.
 * A higher priority message may not cause a lower priority message to be sent, which avoids
 * a circular dependency between message classes.
 *
 * LCE Request Processing Flow:
 *  At a high level, a cache miss is handled by an LCE Request being sent to the CCE, followed by
 *  a series of commands and and responses that handle invalidating, evicting, and writing-back
 *  blocks as needed, sending data and tags to the LCE, and concluding with the LCE sending a response
 *  to the CCE managing the transaction. The length of a coherence transaction depends on the type of
 *  request (read- or write-miss), the current state of the requested block, and the current state of
 *  the cache way that the miss will be filled into.
 *
 *
 * Clients should use the declare_bp_me_if() macro to declare all of the interface structs at once.
 *
 */


/* TODO list

1. Align cache block data fields in Command and Response messages to physical network flit boundary

*/


/*
 * 
 * LCE-CCE Interface Macro
 *
 * This macro defines all of the lce-cce interface stucts and port widths at once as localparams
 *
 */

`define declare_bp_lce_cce_if(num_cce_mp, num_lce_mp, paddr_width_mp, lce_assoc_mp, data_width_mp, cce_block_width_mp) \
                                                                                                         \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [`bp_lce_req_pad(lce_assoc_mp, data_width_mp)-1:0]  pad;                                       \
    bp_lce_cce_lru_dirty_e                                    lru_dirty;                                 \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]                 lru_way_id;                                \
    bp_lce_cce_req_non_excl_e                                 non_exclusive;                             \
  }  bp_lce_cce_req_req_s;                                                                               \
                                                                                                         \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [data_width_mp-1:0]  data;                                                                     \
    bp_lce_cce_uc_req_size_e   uc_size;                                                                  \
  }  bp_lce_cce_req_uc_req_s;                                                                            \
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
 * lru_dirty indicates if the LRU way was dirty or clean when the miss request was sent                  \
 */                                                                                                      \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    union packed                                                                                         \
    {                                                                                                    \
      bp_lce_cce_req_req_s     req;                                                                      \
      bp_lce_cce_req_uc_req_s  uc_req;                                                                   \
    }                                        msg;                                                        \
    logic [paddr_width_mp-1:0]               addr;                                                       \
    bp_lce_cce_req_type_e                    msg_type;                                                   \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]  src_id;                                                     \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]  dst_id;                                                     \
  }  bp_lce_cce_req_s;                                                                                   \
                                                                                                         \
  // CCE to LCE Command                                                                                  \
  // This command does not include data                                                                  \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [`bp_lce_cmd_pad(num_cce_mp, num_lce_mp, lce_assoc_mp, paddr_width_mp, cce_block_width_mp)-1:0]\
                                                 pad;                                                    \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    target_way_id;                                          \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      target;                                                 \
    logic [`bp_coh_bits-1:0]                     state;                                                  \
    logic [paddr_width_mp-1:0]                   addr;                                                   \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      src_id;                                                 \
  }  bp_lce_cmd_cmd_s;                                                                                   \
                                                                                                         \
  // LCE Data and Tag Command                                                                            \
  // This command sends data and cache tag to an LCE                                                     \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [cce_block_width_mp-1:0]               data;                                                   \
    logic [`bp_coh_bits-1:0]                     state;                                                  \
    logic [paddr_width_mp-1:0]                   addr;                                                   \
  }  bp_lce_cmd_dt_s;                                                                                    \
                                                                                                         \
/**                                                                                                      \
 *  bp_lce_cmd_s is the generic message for LCE Command and LCE Data Command that is sent across the     \
 *  Command network from CCE to LCE.                                                                     \
 *  Although not required, It is designed to be sent through a wormhole routed network that will send    \
 *  the minimum number of flits required, based on the msg_type field.                                   \
 *  msg_type: indicates the type of message and implies the size of the message payload                  \
 */                                                                                                      \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    union packed                                                                                         \
    {                                                                                                    \
      bp_lce_cmd_dt_s                 dt_cmd;                                                            \
      bp_lce_cmd_cmd_s                cmd;                                                               \
    }                                            msg;                                                    \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;                                                 \
    bp_lce_cmd_type_e                            msg_type;                                               \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      dst_id;                                                 \
  } bp_lce_cmd_s;                                                                                        \
                                                                                                         \
/**                                                                                                      \
 *  bp_lce_cce_resp_s is the generic message for LCE Response and LCE Data Response messages on the      \
 *  Response network from LCE to CCE. The data field is only used for Data Response messages.            \
 */                                                                                                      \
  typedef struct packed                                                                                  \
  {                                                                                                      \
    logic [cce_block_width_mp-1:0]               data;                                                   \
    logic [paddr_width_mp-1:0]                   addr;                                                   \
    bp_lce_cce_resp_type_e                       msg_type;                                               \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      src_id;                                                 \
    logic [`BSG_SAFE_CLOG2(num_cce_mp)-1:0]      dst_id;                                                 \
  } bp_lce_cce_resp_s;                                                                                   \


/*
 * LCE-CCE Interface Enums
 *
 * These enums define the options for fields of the LCE-CCE Interface messages. Clients should use
 * the enums to set and compare fields of messages, rather than examining the bit pattern directly.
 */

/*
 * bp_lce_cce_req_type_e specifies whether the containing message is related to a read or write
 * cache miss request from and LCE.
 */
typedef enum bit [2:0]
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
typedef enum bit 
{
  e_lce_req_excl            = 1'b0 // exclusive cache line request (read-only, exclusive request)
  ,e_lce_req_non_excl       = 1'b1 // non-exclusive cache line request (read-only, shared request)
} bp_lce_cce_req_non_excl_e;


/*
 * bp_lce_cce_lru_dirty_e specifies whether the LRU way in an LCE request (bp_lce_cce_req_s)
 * contains a dirty cache block. The 
 */
typedef enum bit 
{
  e_lce_req_lru_clean       = 1'b0 // lru way from requesting lce's tag set is clean
  ,e_lce_req_lru_dirty      = 1'b1 // lru way from requesting lce's tag set is dirty
} bp_lce_cce_lru_dirty_e;

/*
 * bp_lce_cce_uc_req_size_e defines the size of a uncached load or store request, in bytes.
 *
 */
typedef enum bit [1:0]
{
  e_lce_uc_req_1  = 2'b00
  ,e_lce_uc_req_2 = 2'b01
  ,e_lce_uc_req_4 = 2'b10
  ,e_lce_uc_req_8 = 2'b11
} bp_lce_cce_uc_req_size_e;

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
typedef enum bit [2:0] 
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

`define bp_coh_bits $bits(bp_coh_states_e)

/*
 * bp_cce_lce_cmd_type_e defines the various commands that an CCE may issue to an LCE
 * e_lce_cmd_sync is used at the end of reset to direct the LCE to inform the CCE it is ready
 * e_lce_cmd_set_clear is sent by the CCE to invalidate an entire cache set in the LCE
 * e_lce_cmd_transfer is sent to command an LCE to transfer an entire cache block to another LCE
 * e_lce_cmd_set_tag is sent to update the tag and coherence state of a single cache line
 * e_lce_cmd_set_tag_wakeup is the same as e_lce_cmd_set_tag, plus it tells the LCE to wake up
 *   and resume normal execution. This is sent only when the CCE detects a write-miss request
 *   is actually an upgrade request.
 * e_lce_cmd_invalidate_tag is sent to invalidate a single cache entry. This command results in
 *   the coherence state of the specified entry being changed to Invalid (no read or write
 *   permissions)
 */
typedef enum bit [3:0] 
{
  e_lce_cmd_sync             = 4'b0000
  ,e_lce_cmd_set_clear       = 4'b0001
  ,e_lce_cmd_transfer        = 4'b0010
  ,e_lce_cmd_writeback       = 4'b0011
  ,e_lce_cmd_set_tag         = 4'b0100
  ,e_lce_cmd_set_tag_wakeup  = 4'b0101
  ,e_lce_cmd_invalidate_tag  = 4'b0110
  ,e_lce_cmd_uc_st_done      = 4'b0111
  ,e_lce_cmd_data            = 4'b1000 // cache block data to LCE, i.e., cache block fill
  ,e_lce_cmd_uc_data         = 4'b1001 // unached data to LCE, i.e, up to 64-bits data
  // 4'b1000 - 4'b1111 reserved / custom
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
typedef enum bit [2:0] 
{
  e_lce_cce_sync_ack         = 3'b000
  ,e_lce_cce_inv_ack         = 3'b001
  ,e_lce_cce_coh_ack         = 3'b010
  ,e_lce_cce_resp_wb         = 3'b011  // Normal Writeback Response (full data)
  ,e_lce_cce_resp_null_wb    = 3'b100  // Null Writeback Response (no data)
  // 3'b101 - 3'b111 reserved / custom
} bp_lce_cce_resp_type_e;

/*
 * Width macros for packed unions. Clients should not need to modify or use these.
 */

`define bp_lce_req_no_pad_width(lce_assoc_mp) \
  ($bits(bp_lce_cce_req_non_excl_e)+`BSG_SAFE_CLOG2(lce_assoc_mp)+$bits(bp_lce_cce_lru_dirty_e))

`define bp_lce_uc_req_width(data_width_mp) \
  (data_width_mp+$bits(bp_lce_cce_uc_req_size_e))

`define bp_lce_req_pad(lce_assoc_mp, data_width_mp)                                        \
  (`bp_lce_uc_req_width(data_width_mp)-`bp_lce_req_no_pad_width(lce_assoc_mp))

`define bp_lce_req_msg_u_width(data_width_mp) \
  (`bp_lce_uc_req_width(data_width_mp))

`define bp_lce_cmd_no_pad_width(num_cce_mp, num_lce_mp, lce_assoc_mp, paddr_width_mp)       \
  (`BSG_SAFE_CLOG2(num_cce_mp)+paddr_width_mp+`bp_coh_bits     \
   +`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_lce_cmd_pad(num_cce_mp, num_lce_mp, lce_assoc_mp, paddr_width_mp, cce_block_width_mp) \
  (cce_block_width_mp+paddr_width_mp+`bp_coh_bits \
   -`bp_lce_cmd_no_pad_width(num_cce_mp, num_lce_mp, lce_assoc_mp, paddr_width_mp))

`define bp_lce_cmd_msg_u_width(cce_block_width_mp, paddr_width_mp) \
  (cce_block_width_mp+paddr_width_mp+`bp_coh_bits)


/*
 * Width macros for LCE-CCE Message Networks
 */

`define bp_lce_cce_req_width(num_cce_mp, num_lce_mp, paddr_width_mp, data_width_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+$bits(bp_lce_cce_req_type_e) \
   +paddr_width_mp+`bp_lce_req_msg_u_width(data_width_mp))

`define bp_lce_cmd_width(num_lce_mp, lce_assoc_mp, paddr_width_mp, cce_block_width_mp) \
  (`BSG_SAFE_CLOG2(num_lce_mp)+$bits(bp_lce_cmd_type_e)+`BSG_SAFE_CLOG2(lce_assoc_mp) \
   +`bp_lce_cmd_msg_u_width(cce_block_width_mp, paddr_width_mp))

`define bp_lce_cce_resp_width(num_cce_mp, num_lce_mp, paddr_width_mp, cce_block_width_mp) \
  (`BSG_SAFE_CLOG2(num_cce_mp)+`BSG_SAFE_CLOG2(num_lce_mp)+$bits(bp_lce_cce_resp_type_e) \
   +paddr_width_mp+cce_block_width_mp)

`define declare_bp_lce_cce_if_widths(num_cce_mp, num_lce_mp, paddr_width_mp, lce_assoc_mp, data_width_mp, cce_block_width_mp) \
    , localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_mp                         \
                                                            ,num_lce_mp                        \
                                                            ,paddr_width_mp                    \
                                                            ,data_width_mp                     \
                                                            )                                  \
    , localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_mp                       \
                                                              ,num_lce_mp                      \
                                                              ,paddr_width_mp                  \
                                                              ,cce_block_width_mp              \
                                                              )                                \
    , localparam lce_cmd_width_lp=`bp_lce_cmd_width(num_lce_mp                                 \
                                                    ,lce_assoc_mp                              \
                                                    ,paddr_width_mp                            \
                                                    ,cce_block_width_mp                        \
                                                    )


`endif
