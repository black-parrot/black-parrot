
`ifndef BP_COMMON_BEDROCK_PKGDEF_SVH
`define BP_COMMON_BEDROCK_PKGDEF_SVH

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
    ,e_bedrock_mem_amo     = 4'b0101  // Atomic operation in L2/LLC
    // 4'b0101 - 4'b1111 reserved // custom
  } bp_bedrock_mem_type_e;

  /*
   * bp_bedrock_req_type_e specifies whether the containing message is related to a read or write
   * cache miss request from and LCE.
   */
  typedef enum logic [3:0]
  {
    e_bedrock_req_rd_miss    = 4'b0000 // Read-miss
    ,e_bedrock_req_wr_miss   = 4'b0001 // Write-miss
    ,e_bedrock_req_uc_rd     = 4'b0010 // Uncached Read
    ,e_bedrock_req_uc_wr     = 4'b0011 // Uncached Write
    ,e_bedrock_req_uc_amo    = 4'b0100 // AMO
    // 4'b0100 - 4'b1111 reserved / custom
  } bp_bedrock_req_type_e;

  /*
   * bp_bedrock_wr_subop_e specifies the type of store
   * Valid only for
   * req: e_bedrock_req_uc_wr, e_bedrock_req_uc_amo
   * mem_cmd: e_bedrock_mem_uc_wr, e_bedrock_mem_amo
   */
  typedef enum logic [3:0]
  {
    e_bedrock_store            = 4'b0000
    ,e_bedrock_amolr           = 4'b0001
    ,e_bedrock_amosc           = 4'b0010
    ,e_bedrock_amoswap         = 4'b0011
    ,e_bedrock_amoadd          = 4'b0100
    ,e_bedrock_amoxor          = 4'b0101
    ,e_bedrock_amoand          = 4'b0110
    ,e_bedrock_amoor           = 4'b0111
    ,e_bedrock_amomin          = 4'b1000
    ,e_bedrock_amomax          = 4'b1001
    ,e_bedrock_amominu         = 4'b1010
    ,e_bedrock_amomaxu         = 4'b1011
  } bp_bedrock_wr_subop_e;


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
  typedef union packed
  {
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

`endif

