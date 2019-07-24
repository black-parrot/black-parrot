/**
 * bp_me_cce_mem_if.vh
 *
 * This file defines the interface between the CCE and memory.
 *
 */

`ifndef BP_ME_CCE_MEM_IF_VH
`define BP_ME_CCE_MEM_IF_VH

`include "bsg_defines.v"

/*
 *
 * CCE-Memory Interface
 *
 */

/*
 * bp_cce_mem_cmd_type_e specifies the memory command from the CCE
 */
typedef enum bit [3:0]
{
  e_cce_mem_rd       = 4'b0000  // Read-miss request
  ,e_cce_mem_wr      = 4'b0001  // Write-miss request
  ,e_cce_mem_uc_rd   = 4'b0010  // Uncached load
  ,e_cce_mem_uc_wr   = 4'b0011  // Uncached store
  ,e_cce_mem_wb      = 4'b0100  // Cache block Writeback
  ,e_mem_cce_inv     = 4'b0101  // Invalidate block (from Mem to CCE)
  // 4'b0110 - 4'b1111 reserved / custom
} bp_cce_mem_cmd_type_e;

`define bp_cce_mem_cmd_type_width $bits(bp_cce_mem_cmd_type_e)

typedef enum bit [2:0]
{
  e_mem_size_1     = 3'b000  // 1 byte
  ,e_mem_size_2    = 3'b001  // 2 bytes
  ,e_mem_size_4    = 3'b010  // 4 bytes
  ,e_mem_size_8    = 3'b011  // 8 bytes
  ,e_mem_size_16   = 3'b100  // 16 bytes
  ,e_mem_size_32   = 3'b101  // 32 bytes
  ,e_mem_size_64   = 3'b110  // 64 bytes
  // 3'b111 reserved / custom
} bp_cce_mem_req_size_e;

/*
 *
 * CCE to Mem Command
 *
 */

/*
 * bp_cce_mem_cmd_payload_s defines a payload that is sent to the memory system by the CCE as part
 * of bp_cce_mem_cmd_s and returned by the mem to the CCE in bp_mem_cce_data_resp_s. This data
 * is not required by the memory system to complete the request.
 *
 * lce_id is the LCE that sent the initial cache miss request
 * way_id is the way within the cache miss address target set to fill the data in to
 */

`define declare_bp_cce_mem_cmd_payload_s(num_lce_mp, lce_assoc_mp) \
  typedef struct packed                                       \
  {                                                           \
    logic [`BSG_SAFE_CLOG2(num_lce_mp)-1:0]      lce_id;      \
    logic [`BSG_SAFE_CLOG2(lce_assoc_mp)-1:0]    way_id;      \
  }  bp_cce_mem_cmd_payload_s


/*
 * bp_cce_mem_cmd_s is sent by a CCE to the Memory to request a cache block
 * msg_type indicates if this block is for a read or write cache miss
 * addr is the memory address from the cache miss
 * payload is data sent to mem and returned to cce unmodified
 */
`define declare_bp_cce_mem_cmd_s(addr_width_mp, data_width_mp)  \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
    bp_cce_mem_cmd_payload_s                     payload;       \
    bp_cce_mem_req_size_e                        size;          \
    logic [addr_width_mp-1:0]                    addr;          \
    bp_cce_mem_cmd_type_e                        msg_type;      \
  }  bp_cce_mem_cmd_s

/*
 *
 * Mem to CCE Response
 *
 */

/*
 * bp_mem_cce_resp_s is sent from the Memory to a CCE to acknowledge completion of a writeback
 * dst_id is the CCE that initiated the writeback request
 * src_id is the Memory that is responding
 * msg_type indicates if this block is for a read or write cache miss
 *
 */
`define declare_bp_mem_cce_resp_s(addr_width_mp, data_width_mp) \
  typedef struct packed                                         \
  {                                                             \
    logic [data_width_mp-1:0]                    data;          \
    bp_cce_mem_cmd_payload_s                     payload;       \
    bp_cce_mem_req_size_e                        size;          \
    logic [addr_width_mp-1:0]                    addr;          \
    bp_cce_mem_cmd_type_e                        msg_type;      \
  } bp_mem_cce_resp_s


/*
 * Width Macros
 */

// CCE-MEM Interface
`define bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp) \
  (`BSG_SAFE_CLOG2(num_lce_mp)+`BSG_SAFE_CLOG2(lce_assoc_mp))

`define bp_cce_mem_cmd_width(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_cce_mem_cmd_type_width+addr_width_mp+data_width_mp \
   +`bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp)\
   +$bits(bp_cce_mem_req_size_e))

`define bp_mem_cce_resp_width(addr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  (`bp_cce_mem_cmd_type_width+addr_width_mp+data_width_mp \
   +`bp_cce_mem_cmd_payload_width(num_lce_mp, lce_assoc_mp) \
   +$bits(bp_cce_mem_req_size_e))


/*
 *
 * Memory End Interface Macro
 *
 * This macro defines all of the memory end interface struct and port widths at once as localparams
 *
 */

`define declare_bp_me_if(paddr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  `declare_bp_cce_mem_cmd_payload_s(num_lce_mp, lce_assoc_mp);                    \
  `declare_bp_cce_mem_cmd_s(paddr_width_mp, data_width_mp);                       \
  `declare_bp_mem_cce_resp_s(paddr_width_mp, data_width_mp);

`define declare_bp_me_if_widths(paddr_width_mp, data_width_mp, num_lce_mp, lce_assoc_mp) \
  , localparam cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_mp                 \
                                                          ,data_width_mp                 \
                                                          ,num_lce_mp                    \
                                                          ,lce_assoc_mp)                 \
  , localparam mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_mp               \
                                                            ,data_width_mp               \
                                                            ,num_lce_mp                  \
                                                            ,lce_assoc_mp)               \


`endif
