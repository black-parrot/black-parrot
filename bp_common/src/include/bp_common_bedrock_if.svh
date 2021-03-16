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

`ifndef BP_COMMON_BEDROCK_IF_SVH
`define BP_COMMON_BEDROCK_IF_SVH

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
  // placed here for search: this macro defines types like bp_bedrock_cce_mem_msg_s
  `define declare_bp_bedrock_msg_s(addr_width_mp, payload_width_mp, data_width_mp, name_mp) \
    typedef struct packed                                                                   \
    {                                                                                       \
      logic [payload_width_mp-1:0]                 payload;                                 \
      bp_bedrock_msg_size_e                        size;                                    \
      logic [addr_width_mp-1:0]                    addr;                                    \
      bp_bedrock_wr_subop_e                        subop;                                   \
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
      bp_bedrock_wr_subop_e                        subop;                              \
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
   * BedRock Payload width macros
   *
   * Users should not need to call these directly and can instead use the BedRock Interface Macros
   * that are defined further below.
   */

  `define bp_bedrock_req_payload_width(lce_id_width_mp, cce_id_width_mp, lce_assoc_mp) \
    (cce_id_width_mp+lce_id_width_mp+$bits(bp_bedrock_req_non_excl_e)+$bits(bp_bedrock_wr_subop_e)+`BSG_SAFE_CLOG2(lce_assoc_mp))

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
    ($bits(bp_bedrock_msg_u)+$bits(bp_bedrock_wr_subop_e)+addr_width_mp+$bits(bp_bedrock_msg_size_e)+payload_width_mp)

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
    `declare_bp_bedrock_msg_s(addr_width_mp, $bits(bp_bedrock_``name_mp``_req_payload_s), data_width_mp, ``name_mp``_req); \
    `declare_bp_bedrock_msg_s(addr_width_mp, $bits(bp_bedrock_``name_mp``_cmd_payload_s), data_width_mp, ``name_mp``_cmd); \
    `declare_bp_bedrock_msg_s(addr_width_mp, $bits(bp_bedrock_``name_mp``_resp_payload_s), data_width_mp, ``name_mp``_resp);

  `define declare_bp_bedrock_mem_if_widths(addr_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp)       \
    `declare_bp_bedrock_mem_payload_width(lce_id_width_mp, lce_assoc_mp, name_mp)                                      \
    `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_mem_payload_width_lp, ``name_mp``_mem)  \
    `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_mem_payload_width_lp, data_width_mp, ``name_mp``_mem)

  `define declare_bp_bedrock_if_widths(addr_width_mp, payload_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp) \
    , localparam ``name_mp``_msg_payload_width_lp = payload_width_mp                                                   \
    `declare_bp_bedrock_msg_header_width(addr_width_mp, ``name_mp``_msg_payload_width_lp, ``name_mp``)                 \
    `declare_bp_bedrock_msg_width(addr_width_mp, ``name_mp``_msg_payload_width_lp, data_width_mp, ``name_mp``)

  `define declare_bp_bedrock_mem_if(addr_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp) \
    `declare_bp_bedrock_mem_payload_s(lce_id_width_mp, lce_assoc_mp, name_mp);                                         \
    `declare_bp_bedrock_msg_s(addr_width_mp, $bits(bp_bedrock_``name_mp``_mem_payload_s), data_width_mp, ``name_mp``_mem);

  `define declare_bp_bedrock_if(addr_width_mp, payload_width_mp, data_width_mp, lce_id_width_mp, lce_assoc_mp, name_mp) \
    `declare_bp_bedrock_msg_s(addr_width_mp, payload_width_mp, data_width_mp, ``name_mp``);

`endif

